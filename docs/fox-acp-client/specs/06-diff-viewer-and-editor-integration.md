# Spec 06: Diff Viewer & Editor Integration

> Technical specification for inspecting, reviewing, and approving proposed agent file modifications using VSCode's native Diff Editor and virtual document providers.

---

## 1. Context & Motivation

In upstream `vscode-acp`, the `writeTextFile` capability blindly wrote content directly to the physical filesystem via `vscode.workspace.fs.writeFile`. If a local model made erroneous edits or hallucinated file contents, developers had to manually revert the filesystem using Git or local file history.

**Fox ACP Client introduces an Interactive Diff Review Subsystem:**
1. Allows developers to preview proposed modifications side-by-side against their current editor buffer before changes hit disk.
2. Leverages VSCode's native `vscode.diff` command, providing familiar syntax highlighting, inline diff hunks, and word-level change highlighting.
3. Provides one-click **Accept** and **Reject** actions directly from the editor tab header and chat webview cards.

---

## 2. Architecture & Workflow

```
[Fox Code CLI]                       [FileSystemHandler]                      [DiffManager]                     [VSCode Window]
      │                                       │                                     │                                  │
      │ 1. writeTextFile(path, content)       │                                     │                                  │
      ├──────────────────────────────────────►│                                     │                                  │
      │                                       │ 2. Check `diffReviewMode`           │                                  │
      │                                       ├────────────────────────────────────►│                                  │
      │                                       │                                     │ 3. Stage proposed content in RAM │
      │                                       │                                     │    Create virtual URI            │
      │                                       │                                     │    `fox-diff://modified/<path>`  │
      │                                       │                                     │                                  │
      │                                       │                                     │ 4. Open native diff editor       │
      │                                       │                                     │    `vscode.diff(orig, proposed)` │
      │                                       │                                     ├─────────────────────────────────►│
      │                                       │                                     │                                  │ Shows side-by-side
      │                                       │                                     │                                  │ diff with Accept/Reject
      │                                       │                                     │ 5. User clicks "Accept"          │ buttons
      │                                       │                                     │◄─────────────────────────────────┤
      │                                       │ 6. Commit to disk                   │                                  │
      │                                       │◄────────────────────────────────────┤                                  │
      │ 7. Response {} (Success)              │                                     │                                  │
      │◄──────────────────────────────────────┤                                     │                                  │
```

---

## 3. Virtual Document Provider (`fox-diff://`)

VSCode requires two `Uri` objects to display a diff. Because the proposed modification does not yet exist on disk, it is served by an in-memory `TextDocumentContentProvider`.

### URI Scheme Definition
- Original file URI: `file:///workspace/src/app.ts` (or the active dirty editor buffer).
- Proposed file URI: `fox-diff:///staged/src/app.ts?rev=<timestamp>`

### Implementation

```typescript
import * as vscode from "vscode";

export class FoxDiffDocumentProvider implements vscode.TextDocumentContentProvider {
  public static readonly scheme = "fox-diff";
  private onDidChangeEmitter = new vscode.EventEmitter<vscode.Uri>();
  public readonly onDidChange = this.onDidChangeEmitter.event;

  private stagedFiles: Map<string, string> = new Map();

  setStagedContent(uri: vscode.Uri, content: string): void {
    this.stagedFiles.set(uri.toString(), content);
    this.onDidChangeEmitter.fire(uri);
  }

  provideTextDocumentContent(uri: vscode.Uri): string {
    return this.stagedFiles.get(uri.toString()) || "";
  }

  clearStagedContent(uri: vscode.Uri): void {
    this.stagedFiles.delete(uri.toString());
  }
}
```

---

## 4. Diff Manager (`DiffManager`)

The `DiffManager` coordinates the lifecycle of pending edits and registers the editor commands for user review.

### Review Actions & Commands

| Command | Identifier | Description |
|---|---|---|
| **Accept Proposed Edit** | `fox.diff.accept` | Writes the staged content to disk, closes the diff editor, and updates the chat card status to `Accepted`. |
| **Reject Proposed Edit** | `fox.diff.reject` | Discards the staged in-memory content, closes the diff editor, and returns an error/rejected status to Fox CLI. |
| **Open Diff View** | `fox.diff.open` | Focuses or re-opens the side-by-side diff for a specific file. |

### Code Implementation

```typescript
export class DiffManager {
  private pendingReviews: Map<string, StagedDiff> = new Map();
  private static readonly REVIEW_TIMEOUT_MS = 5 * 60 * 1000; // 5 minutes (configurable)

  async stageAndReview(filePath: string, proposedContent: string): Promise<boolean> {
    const fileUri = vscode.Uri.file(filePath);
    const diffUri = vscode.Uri.parse(
      `${FoxDiffDocumentProvider.scheme}:///staged/${encodeURIComponent(filePath)}?t=${Date.now()}`
    );

    this.provider.setStagedContent(diffUri, proposedContent);

    const title = `${path.basename(filePath)} (Fox Proposed Changes)`;

    // Open side-by-side diff
    await vscode.commands.executeCommand("vscode.diff", fileUri, diffUri, title, {
      preview: true,
      preserveFocus: false,
    });

    // Await user decision via Promise with timeout guard.
    // IMPORTANT: This promise blocks the writeTextFile RPC response.
    // A timeout prevents the agent from hanging indefinitely if the user
    // ignores or navigates away from the diff editor.
    return new Promise((resolve) => {
      const timeoutHandle = setTimeout(() => {
        // On timeout, auto-reject to unblock the agent turn.
        // The staged content remains accessible via the session tree
        // for later manual review.
        this.reject(filePath);
        vscode.window.showWarningMessage(
          `Fox diff review for ${path.basename(filePath)} timed out after 5 minutes. Edit was not applied.`
        );
      }, DiffManager.REVIEW_TIMEOUT_MS);

      this.pendingReviews.set(filePath, {
        fileUri,
        diffUri,
        proposedContent,
        resolve,
        timeoutHandle,
      });
    });
  }

  async accept(filePath: string): Promise<void> {
    const review = this.pendingReviews.get(filePath);
    if (!review) return;

    clearTimeout(review.timeoutHandle);

    // Write to physical filesystem
    await vscode.workspace.fs.writeFile(
      review.fileUri,
      Buffer.from(review.proposedContent, "utf-8")
    );

    this.provider.clearStagedContent(review.diffUri);
    this.pendingReviews.delete(filePath);
    review.resolve(true);
  }

  async reject(filePath: string): Promise<void> {
    const review = this.pendingReviews.get(filePath);
    if (!review) return;

    clearTimeout(review.timeoutHandle);

    this.provider.clearStagedContent(review.diffUri);
    this.pendingReviews.delete(filePath);
    review.resolve(false);
  }
}
```

> **Design Note — Blocking vs. Async Resolution:** The `stageAndReview` method intentionally blocks the `writeTextFile` RPC response until the user accepts or rejects (or the timeout fires). This is the simplest model that maintains ACP protocol correctness — the agent knows definitively whether its write succeeded before proceeding. An alternative async model (respond immediately with "pending", notify later) would require ACP protocol extensions not currently standardized. The 5-minute timeout is configurable via a future `fox.diffReviewTimeout` setting.

---

## 5. Configuration Modes (`fox.diffReviewMode`)

The developer can control how aggressively proposed edits trigger the diff editor:

| Mode Value | Behavior |
|---|---|
| **`always` (Default)** | Every `writeTextFile` or surgical edit opens the diff editor and awaits user approval. |
| **`onCollision`** | Direct writes occur automatically unless the file already has unsaved edits in the editor buffer, in which case diff review is triggered to prevent overwriting user work. |
| **`never`** | Edits are applied immediately to disk without opening the diff editor (equivalent to upstream behavior). |

---

## 6. Editor Title Bar Actions & Decorations

When a diff editor is active for a `fox-diff` URI:
1. Two primary action buttons appear in the top-right editor title bar:
   - `$(check) Accept Fox Changes` (`command:fox.diff.accept`)
   - `$(x) Reject Changes` (`command:fox.diff.reject`)
2. The Status Bar shows a badge:
   - `$(git-compare) 1 Pending Fox Edit`
   - Clicking the badge focuses the open diff editor.
3. In the Chat Webview, the corresponding tool card reflects review progress:
   - `🔧 write_file: src/app.ts — Awaiting Review [View Diff] [Accept] [Reject]`

---

## 7. Next Edit Suggestions (NES) — Inline Completions

> **Reference implementation:** [`NextEditInlineCompletionProvider.ts`](file:///home/k82l0804/workarea/fox/ext-repo/agent-cli/kilocode/packages/kilo-vscode/src/services/autocomplete/next-edit/NextEditInlineCompletionProvider.ts) in Kilo Code's VSCode extension.
>
> **Fox CLI Dependency & Phasing Note:** NES relies on a dedicated, low-latency Fill-In-The-Middle (FIM) local model endpoint, which is tracked on the [Fox CLI V2 Roadmap](../../fox-cli/plans/cli-implementation-plan.md#31-next-edit-suggestions-nes-engine). For Fox ACP Client V1, NES is disabled by default (`fox.nes.enabled: false`) and strictly guarded by checking the `initialize` capabilities response so the extension degrades gracefully when running against Fox CLI V1.

### Overview

Next Edit Suggestions (NES) integrate Fox's AI capabilities directly into the VSCode editor as **inline ghost-text completions**. As the developer edits code, Fox proactively predicts the *next* edit they are likely to make and renders it as a translucent suggestion that can be accepted with `Tab`.

This is distinct from the diff review workflow — NES operates in the background, triggered by edit history, and provides single-file, single-location predictions without requiring an active chat turn.

### Architecture

```
[VSCode Editor]                [InlineCompletionService]             [Fox CLI via ACP]
      │                                   │                                 │
      │ 1. User edits file                │                                 │
      ├──────────────────────────────────►│                                 │
      │                                   │ 2. Track edit history           │
      │                                   │    (EditHistoryTracker)         │
      │                                   │                                 │
      │ 3. provideInlineCompletions()     │                                 │
      ├──────────────────────────────────►│                                 │
      │                                   │ 4. connection.nesRequest(...)   │
      │                                   ├────────────────────────────────►│
      │                                   │ 5. NES prediction response      │
      │                                   │◄────────────────────────────────┤
      │ 6. Ghost-text inline suggestion   │                                 │
      │◄──────────────────────────────────┤                                 │
      │                                   │                                 │
      │ 7a. Tab → accept suggestion       │                                 │
      │ 7b. Esc → dismiss suggestion      │                                 │
```

### `InlineCompletionService` Implementation

The `InlineCompletionService` class implements VSCode's `vscode.InlineCompletionItemProvider` interface and registers it for all supported languages:

```typescript
// src/services/InlineCompletionService.ts
import * as vscode from "vscode";
import type { SessionManager } from "../core/SessionManager";

export class InlineCompletionService implements vscode.InlineCompletionItemProvider {
  private editHistory: Map<string, EditEntry[]> = new Map();
  private readonly MAX_HISTORY = 10;

  constructor(
    private readonly sessionManager: SessionManager,
    private readonly context: vscode.ExtensionContext,
  ) {
    // Register as VSCode inline completion provider
    context.subscriptions.push(
      vscode.languages.registerInlineCompletionItemProvider(
        { pattern: "**" }, // All files
        this,
      ),
    );

    // Track document edits for history context
    context.subscriptions.push(
      vscode.workspace.onDidChangeTextDocument((e) => {
        this.trackEdits(e.document.uri.fsPath, e.contentChanges);
      }),
    );
  }

  async provideInlineCompletions(
    document: vscode.TextDocument,
    position: vscode.Position,
    context: vscode.InlineCompletionContext,
    token: vscode.CancellationToken,
  ): Promise<vscode.InlineCompletionList | null> {
    const session = this.sessionManager.getActiveSession();
    if (!session || !this.isNesEnabled()) return null;

    const editContext = this.buildEditContext(document, position);
    try {
      const result = await session.connection.nesRequest({
        sessionId: session.sessionId,
        filePath: document.uri.fsPath,
        content: document.getText(),
        cursorLine: position.line,
        cursorCol: position.character,
        editHistory: this.editHistory.get(document.uri.fsPath) ?? [],
      });

      if (token.isCancellationRequested || !result.suggestion) return null;

      return {
        items: [
          new vscode.InlineCompletionItem(
            result.suggestion.text,
            new vscode.Range(
              new vscode.Position(result.suggestion.startLine, result.suggestion.startCol),
              new vscode.Position(result.suggestion.endLine, result.suggestion.endCol),
            ),
          ),
        ],
      };
    } catch {
      return null;
    }
  }

  private trackEdits(filePath: string, changes: readonly vscode.TextDocumentContentChangeEvent[]): void {
    const history = this.editHistory.get(filePath) ?? [];
    for (const change of changes) {
      history.push({ range: change.range, text: change.text, timestamp: Date.now() });
    }
    // Keep only the most recent N edits
    this.editHistory.set(filePath, history.slice(-this.MAX_HISTORY));
  }
}
```

### ACP NES Protocol (`nes/*`)

| ACP Method | Direction | Payload | Description |
|---|---|---|---|
| `nes/start` | Client → Server | `{ sessionId }` | Opt in to receiving NES predictions for the session. |
| `nes/request` | Client → Server | `{ sessionId, filePath, content, cursorLine, cursorCol, editHistory }` | Request a next-edit prediction at the current cursor position with edit history for context. |
| `nes/stop` | Client → Server | `{ sessionId }` | Opt out and release server-side NES resources. |
| `nes/accept` | Client → Server | `{ sessionId, suggestionId }` | Signal that the user accepted a suggestion (enables server-side reinforcement). |

### Document Sync Events

In addition to `provideInlineCompletions`, the `InlineCompletionService` subscribes to:

| VSCode Event | Handler Behavior |
|---|---|
| `onDidChangeTextDocument` | Appends content changes to per-file edit history ring buffer. |
| `onDidChangeActiveTextEditor` | Sends `nes/focus` notification (if supported) to pre-warm prediction for the newly active file. |
| `onDidCloseTextDocument` | Evicts the file's edit history from memory to prevent stale context. |

### Configuration

| Setting | Default | Description |
|---|---|---|
| `fox.nes.enabled` | `true` | Enable/disable inline Next Edit Suggestions globally. |
| `fox.nes.triggerDelay` | `500` | Milliseconds after last keystroke before requesting a suggestion. |
| `fox.nes.maxHistoryEntries` | `10` | Maximum number of recent edits to include as context. |
