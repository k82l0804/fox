# Spec 04: Client Capabilities & Security

> Technical specification for implementing ACP client-side capabilities: buffer-aware filesystem access, terminal process virtualization, and permission escalation security.

---

## 1. Overview & Protocol Interface

In the Agent Client Protocol, the **client** (VSCode extension) implements capability methods that the **server** (Fox CLI) invokes via reverse JSON-RPC requests.

The class `AcpClientImpl` implements the `Client` interface from `@agentclientprotocol/sdk`:

```typescript
import type {
  Client,
  RequestPermissionRequest,
  RequestPermissionResponse,
  SessionNotification,
  WriteTextFileRequest,
  WriteTextFileResponse,
  ReadTextFileRequest,
  ReadTextFileResponse,
  CreateTerminalRequest,
  CreateTerminalResponse,
  TerminalOutputRequest,
  TerminalOutputResponse,
  WaitForTerminalExitRequest,
  WaitForTerminalExitResponse,
  KillTerminalRequest,
  KillTerminalResponse,
  ReleaseTerminalRequest,
  ReleaseTerminalResponse,
} from "@agentclientprotocol/sdk";

export class AcpClientImpl implements Client {
  private agent: Agent | null = null;

  constructor(
    private readonly fsHandler: FileSystemHandler,
    private readonly terminalHandler: TerminalHandler,
    private readonly permissionHandler: PermissionHandler,
    private readonly sessionUpdateRouter: SessionUpdateRouter,
  ) {}

  /**
   * Called by the ClientSideConnection factory during connection setup.
   * Stores the Agent proxy for reverse RPC calls (server → client).
   */
  setAgent(agent: Agent): void {
    this.agent = agent;
  }

  // Dispatches to corresponding handlers...
}
```

---

## 2. File System Handler (`FileSystemHandler`)

The file system handler fulfills agent requests to read and write files within the workspace.

### 2.1. Buffer-Aware `readTextFile`
A critical flaw in basic file reading is querying disk contents directly when a developer has unsaved changes in their active VSCode editor tab.

Fox ACP Client implements **buffer-aware reading**:

```typescript
export class FileSystemHandler {
  async readTextFile(params: ReadTextFileRequest): Promise<ReadTextFileResponse> {
    const uri = vscode.Uri.file(params.path);

    // 1. Check if the file is currently open in VSCode memory with unsaved edits
    const openDoc = vscode.workspace.textDocuments.find(
      (doc) => doc.uri.fsPath === uri.fsPath
    );

    let content: string;
    if (openDoc) {
      content = openDoc.getText();
    } else {
      const raw = await vscode.workspace.fs.readFile(uri);
      content = Buffer.from(raw).toString("utf-8");
    }

    // 2. Handle optional line slicing (1-based index)
    if (params.line !== undefined || params.limit !== undefined) {
      const lines = content.split("\n");
      const startLine = (params.line ?? 1) - 1;
      const endLine = params.limit ? startLine + params.limit : lines.length;
      content = lines.slice(startLine, endLine).join("\n");
    }

    return { content };
  }
}
```

### 2.2. Safe `writeTextFile`
When the agent writes a file:
1. Verifies that the destination path resides within an allowed workspace directory (preventing directory traversal outside the project).
2. Recursively creates any missing parent directories via `vscode.workspace.fs.createDirectory`.
3. If **Diff Review Mode** is active (`fox.diffReviewMode = true`), routes the write to `DiffManager` (see [Spec 06](./06-diff-viewer-and-editor-integration.md)).
4. Otherwise, executes atomic write via `vscode.workspace.fs.writeFile`.
5. Opens the modified document in the background with `{ preview: true, preserveFocus: true }` so the developer immediately sees the changes.

> **ACP v2 Note:** In ACP v2, the agent owns its full execution environment. The `fs/*` and `terminal/*` client capabilities above are part of the v1 model where the client provides environmental access. In v2, the agent exposes these same facilities as MCP tools registered via `type: "acp"` transport, removing the need for the client to implement them directly. Fox ACP Client supports both models for backward compatibility.

---

## 3. Terminal Handler (`TerminalHandler`)

When an agent needs to run a build, run tests, or execute terminal commands, it requests terminal lifecycle operations via ACP.

### Architecture: Dual Execution & Display
To balance programmatic output inspection with developer visibility, the `TerminalHandler` couples an underlying Node.js `ChildProcess` with a VSCode `Pseudoterminal`:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                             TerminalHandler                                 │
│                                                                             │
│                  ┌──────────────────────────────────────┐                   │
│                  │        spawn(command, args)          │                   │
│                  │        (Node ChildProcess)           │                   │
│                  └──────┬────────────────────────┬──────┘                   │
│                         │ stdout / stderr        │ stdout / stderr          │
│                         ▼                        ▼                          │
│  ┌──────────────────────────────┐      ┌──────────────────────────────────┐ │
│  │   Output Buffer (Memory)     │      │   vscode.Pseudoterminal          │ │
│  │   - Byte Limit Guard (1MB)   │      │   - Streaming text to VSCode     │ │
│  │   - Char boundary truncation │      │     integrated terminal window   │ │
│  │   - exitCode / exitSignal    │      │   - Preserved on releaseTerminal │ │
│  └──────────────┬───────────────┘      └──────────────────────────────────┘ │
│                 │                                                           │
│                 ▼                                                           │
│  ACP `terminal/output` Response                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Protocol Method Behaviors

| ACP Method | Behavior & Implementation Details |
|---|---|
| **`terminal/create`** | Spawns child process in `params.cwd` with merged environment variables. Creates VSCode integrated terminal tab (`ACP: <command>`). Allocates unique `terminalId` (`term_1`, `term_2`). |
| **`terminal/output`** | Returns accumulated output string. If output exceeded `outputByteLimit` (default 1MB), truncates cleanly from the front at a UTF-8 character boundary and sets `truncated: true`. Returns `exitStatus` if exited. |
| **`terminal/waitForExit`** | Returns a promise that awaits process exit, resolving with `{ exitCode, signal }`. |
| **`terminal/kill`** | Issues `SIGTERM` to the child process. Escalates to `SIGKILL` after 2 seconds if still alive. |
| **`terminal/release`** | Terminate child process if still executing, but **does not destroy the VSCode terminal panel**. Per ACP specification, terminal output remains visible in VSCode for developer inspection. |

---

## 4. Permission Handler & Safety Policies (`PermissionHandler`)

When Fox CLI executes potentially destructive actions (e.g. running a shell command or modifying configuration), it emits a `requestPermission` call to the client.

### Permission Request Format

```json
{
  "toolCall": {
    "title": "Execute Shell Command: npm test",
    "kind": "terminal/create"
  },
  "options": [
    { "optionId": "allow_once", "name": "Allow Once", "kind": "allow_once" },
    { "optionId": "allow_always", "name": "Always Allow in Session", "kind": "allow_always" },
    { "optionId": "reject", "name": "Reject Command", "kind": "reject" }
  ]
}
```

### Safety Policies Configuration (`fox.autoApprovePermissions`)

| Policy Setting | Auto-Approved ACP Permission Kinds | Prompted Permission Kinds |
|---|---|---|
| **`ask` (Default)** | *(None)* — always prompts for every action. | All kinds: `fs/readTextFile`, `fs/writeTextFile`, `terminal/create`, etc. |
| **`allowWorkspaceRead`** | `fs/readTextFile` — auto-approves read-only filesystem operations. | `fs/writeTextFile`, `terminal/create`, and all other mutating actions. |
| **`allowAll`** | All kinds — automatically selects the first available `allow` option. | *(None)* — designed for trusted or autonomous unattended runs. |

> **Note:** The permission `kind` values (e.g. `fs/readTextFile`, `terminal/create`) come from the ACP `requestPermission` payload's `toolCall.kind` field. These are ACP client capability identifiers, not Fox CLI tool names. Fox CLI tools like `grep_search` or `glob_find` do not generate separate permission requests — they invoke client capabilities internally.

### Presentation Modes

1. **Native VSCode QuickPick**:
   - Triggered with `ignoreFocusOut: true` to prevent accidental dismissal.
   - Shows action title, detail description, and clear action icons (`$(check)`, `$(x)`).
2. **In-Chat Approval Card**:
   - Renders directly in the active webview message stream.
   - Shows full tool command, affected file paths, and one-click action buttons.
   - Responding in the webview dispatches the selection directly to the pending promise.

```typescript
export class PermissionHandler {
  async requestPermission(params: RequestPermissionRequest): Promise<RequestPermissionResponse> {
    const config = vscode.workspace.getConfiguration("fox");
    const policy = config.get<string>("autoApprovePermissions", "ask");

    // Auto-approve evaluation
    if (policy === "allowAll") {
      const allowOpt = params.options.find(o => o.kind.startsWith("allow"));
      if (allowOpt) {
        return { outcome: { outcome: "selected", optionId: allowOpt.optionId } };
      }
    }

    // Display interactive QuickPick
    const items = params.options.map(opt => ({
      label: opt.kind.startsWith("allow") ? `$(check) ${opt.name}` : `$(x) ${opt.name}`,
      description: opt.kind,
      optionId: opt.optionId,
    }));

    const selection = await vscode.window.showQuickPick(items, {
      title: "Fox Security Permission Required",
      placeHolder: params.toolCall?.title || "Agent requested permission to perform an action",
      ignoreFocusOut: true,
    });

    if (!selection) {
      return { outcome: { outcome: "cancelled" } };
    }

    return { outcome: { outcome: "selected", optionId: selection.optionId } };
  }
}
```

---

## 5. Elicitation Handler (`ElicitationHandler`)

The ACP `elicitation/create` request allows the agent to ask the user structured questions mid-turn without abandoning the active session. Fox ACP Client handles two elicitation modes:

### 5.1. `mode: "form"` — Structured JSON Schema Forms

The agent provides a JSON Schema describing the expected response. Fox ACP Client renders this as an inline `QuestionDock` UI above the Composer:

```typescript
interface ElicitationRequest {
  sessionId: string;
  message: string;          // Human-readable question text
  requestedSchema: {        // JSON Schema for the expected response
    type: "object";
    properties: Record<string, { type: string; enum?: string[]; description?: string }>;
    required?: string[];
  };
}

interface ElicitationResponse {
  outcome: "accept" | "decline" | "cancel";
  content?: Record<string, unknown>;  // Present when outcome is "accept"
}
```

**Supported field types rendered by `QuestionDock`:**

| JSON Schema Pattern | Rendered UI Control |
|---|---|
| `{ type: "string", enum: [...] }` | Radio button group (single-choice) |
| `{ type: "array", items: { enum: [...] } }` | Checkbox group (multi-choice) |
| `{ type: "string" }` | Single-line text input |
| `{ type: "string", format: "textarea" }` | Multi-line textarea |
| `{ type: "boolean" }` | Toggle/checkbox |

**Lifecycle:**
1. Agent emits `elicitation/create`.
2. `ElicitationHandler` forwards to webview via `elicitationRequest` postMessage.
3. `QuestionDock` renders above the Composer, blocking further input.
4. User fills the form and clicks **Submit** → `outcome: "accept"` with `content: { ... }`.
5. User clicks **Skip** → `outcome: "decline"`.
6. Agent cancels via `$/cancel_request` → `outcome: "cancel"`, UI dismissed.

### 5.2. `mode: "url"` — Browser URL Opens

The agent requests the client open a URL in the system browser (e.g. for OAuth flows or documentation):

```typescript
interface UrlElicitationRequest {
  sessionId: string;
  message: string;
  url: string;
}
```

**Behavior:**
1. Displays a consent dialog: `The agent wants to open: ${domain}. Allow?` with **Open** and **Cancel** buttons.
2. If the user clicks **Open**: calls `vscode.env.openExternal(vscode.Uri.parse(url))`, returns `{ outcome: "accept" }`.
3. If the user clicks **Cancel**: returns `{ outcome: "decline" }`.
4. Never silently opens URLs — explicit user consent is always required for security.

---

## 6. Error Handling

### File System Error Contracts

| Operation | Error Condition | Behavior |
|---|---|---|
| `readTextFile` | Path outside workspace roots | Return JSON-RPC error with code `-32602` (Invalid params): `Access denied: path is outside workspace.` |
| `readTextFile` | File does not exist | Return JSON-RPC error: `File not found: ${path}`. |
| `readTextFile` | File is binary / not decodable as UTF-8 | Return JSON-RPC error: `File is not a text file: ${path}`. |
| `writeTextFile` | Path traversal outside workspace (`../../../etc/passwd`) | Reject with error: `Directory traversal denied.` Do not write. |
| `writeTextFile` | Disk full or permission denied | Return OS error message. Log to Fox Output Channel. |

### Terminal Error Contracts

| Operation | Error Condition | Behavior |
|---|---|---|
| `terminal/create` | Command not found on PATH | Spawn will fail; capture `ENOENT` error. Return error with exit status. |
| `terminal/output` | Terminal ID does not exist | Return JSON-RPC error: `Unknown terminal: ${terminalId}`. |
| `terminal/waitForExit` | Process already exited | Return immediately with cached `{ exitCode, signal }`. |
| `terminal/kill` | Process already exited | No-op. Return success. |
