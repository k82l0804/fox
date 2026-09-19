# Spec 05: Chat Webview & UI Subsystem

> Technical specification for the VSCode Webview chat panel, built with **Preact** for component-based rendering, hooks-driven state management, and efficient streaming UI updates.

---

## 1. Overview & Architecture

The **Chat Webview** is the primary visual interface of Fox ACP Client. It is implemented as a VSCode `WebviewViewProvider` docked in the Activity Bar sidebar (`fox-chat`).

The webview frontend is built with **Preact** (~3KB runtime), providing a declarative component model that maps naturally to the complex, stateful UI elements of a streaming AI chat interface. Preact is API-compatible with React, allowing use of familiar JSX/TSX syntax and hooks patterns while maintaining a minimal bundle footprint suitable for VSCode webview loading constraints.

### Why Preact (Not Vanilla DOM or React)

| Concern | Vanilla TS (upstream approach) | Preact | React |
|---|---|---|---|
| **Runtime size** | 0KB | **~3KB** min+gz | ~45KB min+gz |
| **Component model** | Manual `createElement` / `innerHTML` | JSX/TSX components | JSX/TSX components |
| **Streaming state** | Manual DOM patching, error-prone | `useState` + virtual DOM diffing | `useState` + virtual DOM diffing |
| **Maintainability** | Upstream is 87KB monolith | Modular `.tsx` components | Modular `.tsx` components |
| **React ecosystem** | N/A | `preact/compat` alias | Native |
| **CSP compatibility** | Compatible | Compatible (nonce-based `script-src`) | Compatible (nonce-based `script-src`) |

### UI Layout

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Fox ACP Webview Panel                                 │
│                                                                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Header: 🦊 Fox Code  [● Connected: gpt-4o]       [+ New] [⚙ Settings] │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Toolbar: Mode: [Code ▼]  Model: [Default Proxy (:8000) ▼]  Effort: [High]│
│  └───────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Message Stream Container                                              │  │
│  │                                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │ User Bubble: "Implement health check endpoint in src/server.ts"   │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │ Assistant Turn:                                                 │  │  │
│  │  │  ┌───────────────────────────────────────────────────────────┐  │  │  │
│  │  │  │ ▼ Thinking (2.4s) - DeepSeek / Local Model Reasoning      │  │  │  │
│  │  │  │   Examining server router to determine appropriate port...│  │  │  │
│  │  │  └───────────────────────────────────────────────────────────┘  │  │  │
│  │  │                                                                 │  │  │
│  │  │  ┌───────────────────────────────────────────────────────────┐  │  │  │
│  │  │  │ 📋 Plan Progress (2/3 tasks completed)                    │  │  │  │
│  │  │  │  ☑ 1. Inspect existing routes                             │  │  │  │
│  │  │  │  ▶ 2. Add /v1/health handler in src/server.ts             │  │  │  │
│  │  │  │  ☐ 3. Run unit tests                                      │  │  │  │
│  │  │  └───────────────────────────────────────────────────────────┘  │  │  │
│  │  │                                                                 │  │  │
│  │  │  ┌───────────────────────────────────────────────────────────┐  │  │  │
│  │  │  │ 🔧 Tool: read_file (src/server.ts)                [Success]│  │  │  │
│  │  │  └───────────────────────────────────────────────────────────┘  │  │  │
│  │  │                                                                 │  │  │
│  │  │  I will add the `/v1/health` endpoint to `src/server.ts`:       │  │  │
│  │  │  ```typescript                                                  │  │  │
│  │  │  app.get('/v1/health', (req, res) => res.json({ status: 'ok' }))│  │  │
│  │  │  ```                                                            │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │ Composer Input Area                                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │ Ask Fox or type '/' for commands...                             │  │  │
│  │  │                                                                 │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │  [📎 Attach] [@ Symbol]                 [Turn Active: Stop (Esc)] [▲] │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Preact Application Architecture

### Component Tree

```
<App>
├── <Header />                    — Connection status, New/Fork/Settings buttons
├── <ContextProgress />           — Context window capacity bar (usage_update)
├── <NoticeBanner />              — Advisory notice toast (notice event)
├── <Toolbar />                   — Mode, Model, ThoughtEffort, Config dropdowns
├── <MessageStream>               — Scrollable message container
│   ├── <UserMessage />           — User prompt bubble (text + image chips)
│   └── <AssistantTurn>           — Full agent response turn
│       ├── <ThinkingBlock />     — Collapsible <think> reasoning with timer
│       ├── <PlanWidget />        — Interactive task checklist
│       ├── <ToolCard />          — Tool call lifecycle card (×N)
│       ├── <TerminalStreamView />— Agent-owned xterm.js terminal panel
│       ├── <PermissionCard />    — In-chat approval buttons
│       └── <MarkdownContent />   — Streaming markdown response
├── <QuestionDock />              — Elicitation form dock (elicitation/create)
├── <Composer>                    — Input area
│   ├── <AutocompletePopup />     — Slash command suggestions
│   └── <ImageAttachmentChips /> — Image thumbnail chips with remove buttons
```

### Application Root

```tsx
// webview/src/main.tsx
import { render } from "preact";
import { App } from "./App";

// Mount Preact app into the webview DOM
const root = document.getElementById("app")!;
render(<App />, root);
```

### Top-Level State Management

State flows through Preact's built-in hooks — no external state library is needed. The `useSession` hook bridges the `postMessage` channel into reactive Preact state:

```tsx
// webview/src/hooks/useSession.ts
import { useState, useEffect } from "preact/hooks";
import type { SessionInfo } from "../../shared/types";

interface SessionState {
  session: SessionInfo | null;
  isConnected: boolean;
  turnInProgress: boolean;
}

/** Subscribes to Extension Host messages and provides reactive session state. */
export function useSession(): SessionState {
  const [state, setState] = useState<SessionState>({
    session: null,
    isConnected: false,
    turnInProgress: false,
  });

  useEffect(() => {
    const handler = (event: MessageEvent) => {
      const msg = event.data;
      switch (msg.type) {
        case "sessionState":
          setState((prev) => ({
            ...prev,
            session: msg.session,
            isConnected: msg.isConnected,
          }));
          break;
        case "turnCompleted":
        case "turnCancelled":
          setState((prev) => ({ ...prev, turnInProgress: false }));
          break;
        // ... other message types
      }
    };
    window.addEventListener("message", handler);
    return () => window.removeEventListener("message", handler);
  }, []);

  return state;
}
```

### Streaming Markdown Hook

The `useStreaming` hook accumulates `agentDelta` tokens and renders incrementally:

```tsx
// webview/src/hooks/useStreaming.ts
import { useState, useEffect, useCallback } from "preact/hooks";

export function useStreaming() {
  const [buffer, setBuffer] = useState("");
  const [isStreaming, setIsStreaming] = useState(false);

  useEffect(() => {
    const handler = (event: MessageEvent) => {
      const msg = event.data;
      if (msg.type === "agentDelta") {
        setBuffer((prev) => prev + msg.text);
        setIsStreaming(true);
      } else if (msg.type === "turnCompleted" || msg.type === "turnCancelled") {
        setIsStreaming(false);
      }
    };
    window.addEventListener("message", handler);
    return () => window.removeEventListener("message", handler);
  }, []);

  const reset = useCallback(() => {
    setBuffer("");
    setIsStreaming(false);
  }, []);

  return { buffer, isStreaming, reset };
}
```

---

## 3. Webview Security & Content Security Policy (CSP)

To comply with VSCode extension security guidelines, the Webview applies strict Content Security Policy headers.

### CSP Definition

```html
<meta http-equiv="Content-Security-Policy" content="
  default-src 'none';
  img-src ${webview.cspSource} https: data:;
  script-src 'nonce-${nonce}';
  style-src ${webview.cspSource} 'unsafe-inline';
  font-src ${webview.cspSource};
">
```
- JavaScript is loaded exclusively from packaged Preact bundles with cryptographic nonces.
- Outbound network requests from the webview are disabled (`default-src 'none'`); all data flows through `vscode.postMessage`.
- Inline styles are allowed for dynamic height calculations, theme property overrides, and Preact's runtime style attribute binding.

### Preact CSP Compatibility
Preact does not use `eval()`, `new Function()`, or inline `<script>` injection, making it fully compatible with strict CSP policies. All Preact code is pre-bundled via Webpack and loaded through a single nonce-tagged `<script>` element.

---

## 4. Communication Bridge (`postMessage` Protocol)

All communication between the Extension Host and the Preact webview frontend passes across a strongly typed JSON message bus. The `postMessage` contract is framework-agnostic — the Extension Host does not know or care that Preact runs inside the webview.

### Webview → Extension Host Messages

| Message `type` | Payload | Purpose |
|---|---|---|
| `sendPrompt` | `{ text: string, images?: ImageAttachment[] }` | User submits prompt; images are base64-encoded `ContentBlock::Image` data. |
| `cancelTurn` | `{}` | User cancels currently executing agent turn. |
| `setMode` | `{ modeId: string }` | User selects new agent operational mode. |
| `setModel` | `{ modelId: string }` | User switches active LLM model. |
| `setConfigOption` | `{ configId: string, value: string }` | User updates a generic session config option (includes `thought_level`). |
| `executeCommand` | `{ command: string }` | Invokes a VSCode command (e.g. open file diff). |
| `permissionResponse`| `{ optionId: string }` | User responds to in-chat permission request. |
| `elicitationResponse` | `{ outcome: "accept" \| "decline"; content?: Record<string, unknown> }` | User submits or skips an elicitation form. |
| `forkSession` | `{}` | User requests a session fork (branch from current conversation). |
| `deleteSession` | `{ sessionId: string }` | User removes a session from history. |
| `ready` | `{}` | Preact application mounted and ready to receive state. |

### Extension Host → Webview Messages

| Message `type` | Payload | Purpose |
|---|---|---|
| `sessionState` | `{ session: SessionInfo, isConnected: boolean }` | Synchronizes active session, modes, and options. |
| `agentDelta` | `{ text: string }` | Streams Markdown token chunk to active message. |
| `thoughtDelta` | `{ text: string }` | Streams reasoning tokens into thinking block. |
| `toolCallStart` | `{ id: string, name: string, input: unknown }` | Mounts pending tool invocation card. |
| `toolCallUpdate` | `{ id: string, outputDelta: string }` | Streams tool execution output. |
| `toolCallComplete` | `{ id: string, status: string, output: unknown }` | Sets tool card state to success or failure. |
| `planUpdate` | `{ entries: PlanEntry[] }` | Refreshes active execution plan checklist. |
| `usageUpdate` | `{ used: number, size: number }` | Updates `ContextProgress` bar with current token utilization. |
| `notice` | `{ level: string, message: string }` | Displays a dismissible advisory `NoticeBanner`. |
| `terminalUpdate` | `{ terminalId: string, cols: number, rows: number }` | Creates or resizes xterm.js terminal panel. |
| `terminalOutputChunk` | `{ terminalId: string, data: string }` | Writes base64-decoded VT100 bytes into xterm buffer. |
| `elicitationRequest` | `{ message: string, schema?: object, url?: string }` | Renders `QuestionDock` or URL consent dialog. |
| `turnCompleted` | `{}` | Re-enables input composer and resets cancel button. |
| `turnCancelled` | `{}` | Marks active turn as cancelled in the UI. |

### Shared Type Definitions

To ensure type safety across the Extension Host / Webview boundary, message types are defined in a shared module importable by both bundles:

```typescript
// shared/types.ts — imported by both src/ and webview/src/
export type WebviewMessage =
  | { type: "sendPrompt"; text: string; images?: ImageAttachment[] }
  | { type: "cancelTurn" }
  | { type: "setMode"; modeId: string }
  | { type: "setConfigOption"; configId: string; value: string }
  | { type: "permissionResponse"; optionId: string }
  | { type: "elicitationResponse"; outcome: "accept" | "decline"; content?: Record<string, unknown> }
  | { type: "forkSession" }
  | { type: "deleteSession"; sessionId: string }
  | { type: "ready" };

export type ExtensionMessage =
  | { type: "sessionState"; session: SessionInfo; isConnected: boolean }
  | { type: "agentDelta"; text: string }
  | { type: "thoughtDelta"; text: string }
  | { type: "toolCallStart"; id: string; name: string; input: unknown }
  | { type: "toolCallUpdate"; id: string; outputDelta: string }
  | { type: "toolCallComplete"; id: string; status: string; output: unknown }
  | { type: "planUpdate"; entries: PlanEntry[] }
  | { type: "usageUpdate"; used: number; size: number }
  | { type: "notice"; level: string; message: string }
  | { type: "terminalUpdate"; terminalId: string; cols: number; rows: number }
  | { type: "terminalOutputChunk"; terminalId: string; data: string }
  | { type: "elicitationRequest"; message: string; schema?: object; url?: string }
  | { type: "turnCompleted" }
  | { type: "turnCancelled" };

export interface ImageAttachment {
  mediaType: "image/png" | "image/jpeg" | "image/gif" | "image/webp";
  data: string;   // base64-encoded image bytes
  preview: string; // data: URL for thumbnail display
}
```

---

## 5. Preact UI Components

### 5.1. Streaming Markdown Renderer (`<MarkdownContent />`)

```tsx
// webview/src/components/MarkdownContent.tsx
import { useMemo } from "preact/hooks";
import { marked } from "marked";
import hljs from "highlight.js";

interface Props {
  content: string;
  isStreaming: boolean;
}

export function MarkdownContent({ content, isStreaming }: Props) {
  const html = useMemo(() => {
    marked.setOptions({
      breaks: true,        // GitHub Flavored Markdown
      highlight: (code, lang) =>
        lang && hljs.getLanguage(lang)
          ? hljs.highlight(code, { language: lang }).value
          : hljs.highlightAuto(code).value,
    });
    return marked.parse(content);
  }, [content]);

  return (
    <div
      class={`markdown-body ${isStreaming ? "streaming" : ""}`}
      dangerouslySetInnerHTML={{ __html: html }}
    />
  );
}
```

- Uses `marked` with GitHub Flavored Markdown (GFM) enabled (`breaks: true`).
- Code blocks are highlighted via `highlight.js` with theme matching the active VSCode color theme (`vscode-dark`, `vscode-light`).
- Each code block renders a **Copy Code** button in its header.
- `useMemo` ensures the markdown is only re-parsed when the content buffer changes, not on every render cycle.

### 5.2. Collapsible Reasoning / Thinking Container (`<ThinkingBlock />`)

Local reasoning models (e.g. DeepSeek-R1, Qwen-2.5-Coder with reasoning enabled) output extended chains of thought before generating code.

```tsx
// webview/src/components/ThinkingBlock.tsx
import { useState, useEffect, useRef } from "preact/hooks";

interface Props {
  content: string;
  isStreaming: boolean;
}

export function ThinkingBlock({ content, isStreaming }: Props) {
  const [expanded, setExpanded] = useState(true);
  const [elapsed, setElapsed] = useState(0);
  const startTime = useRef(Date.now());

  // Live timer while streaming
  useEffect(() => {
    if (!isStreaming) return;
    const interval = setInterval(() => {
      setElapsed((Date.now() - startTime.current) / 1000);
    }, 100);
    return () => clearInterval(interval);
  }, [isStreaming]);

  // Auto-collapse when streaming finishes
  useEffect(() => {
    if (!isStreaming && content.length > 0) {
      setExpanded(false);
    }
  }, [isStreaming]);

  return (
    <div class={`thinking-block ${isStreaming ? "pulse" : ""}`}>
      <button class="thinking-header" onClick={() => setExpanded(!expanded)}>
        <span>{expanded ? "▼" : "▶"} Thinking ({elapsed.toFixed(1)}s)</span>
        {isStreaming && <span class="pulse-dot" />}
      </button>
      {expanded && (
        <pre class="thinking-content">{content}</pre>
      )}
    </div>
  );
}
```

- Displays as a sleek, collapsible card: `▼ Thinking (3.2s)`.
- Features an animated pulse indicator while reasoning tokens are streaming.
- Auto-collapses when the final response begins streaming, preserving clean readability while remaining expandable for inspection.

### 5.3. Tool Execution Cards (`<ToolCard />`)

Tool calls (`read_file`, `write_file`, `shell`, `edit_file`, MCP tools) are rendered with clear visual states:

```tsx
// webview/src/components/ToolCard.tsx
import { useState } from "preact/hooks";

interface Props {
  id: string;
  name: string;
  input: unknown;
  status: "pending" | "running" | "completed" | "failed";
  output?: string;
}

export function ToolCard({ id, name, input, status, output }: Props) {
  const [expanded, setExpanded] = useState(false);
  const icon = {
    pending: "⏳", running: "⚙️", completed: "✅", failed: "❌"
  }[status];

  return (
    <div class={`tool-card tool-${status}`}>
      <button class="tool-header" onClick={() => setExpanded(!expanded)}>
        <span>{icon} {name}</span>
        <span class="tool-badge">{status}</span>
      </button>
      {expanded && (
        <div class="tool-detail">
          <pre class="tool-input">{JSON.stringify(input, null, 2)}</pre>
          {output && <pre class="tool-output">{output}</pre>}
        </div>
      )}
      {status === "completed" && name.startsWith("write_file") && (
        <button class="tool-action" onClick={() => postViewDiff(id)}>
          View Diff
        </button>
      )}
    </div>
  );
}
```

- **Pending/Running**: Animated spinner with tool name and parameter summary.
- **Completed**: Green checkmark with expandable input arguments and output payload.
- **Failed / Denied**: Red warning badge with error message.
- **File Diff Action**: If the tool call modified a file, includes a one-click `[View Diff]` link invoking `vscode.diff`.

### 5.4. Interactive Plan / Todo Checklist Widget (`<PlanWidget />`)

When Fox CLI emits `plan_update` notifications (driven by the agent's `todo` tool):

```tsx
// webview/src/components/PlanWidget.tsx
interface PlanEntry {
  id: string;
  title: string;
  status: "todo" | "in_progress" | "completed";
}

export function PlanWidget({ entries }: { entries: PlanEntry[] }) {
  const completed = entries.filter((e) => e.status === "completed").length;
  const pct = Math.round((completed / entries.length) * 100);

  return (
    <div class="plan-widget">
      <div class="plan-header">
        📋 Plan Progress ({completed}/{entries.length} tasks — {pct}%)
      </div>
      <div class="plan-progress-bar">
        <div class="plan-fill" style={{ width: `${pct}%` }} />
      </div>
      <ul class="plan-list">
        {entries.map((entry) => (
          <li key={entry.id} class={`plan-item plan-${entry.status}`}>
            <span class="plan-icon">
              {entry.status === "completed" ? "☑" :
               entry.status === "in_progress" ? "▶" : "☐"}
            </span>
            {entry.title}
          </li>
        ))}
      </ul>
    </div>
  );
}
```

- Items feature real-time status icons (`☑` Completed, `▶` In Progress with pulsing accent border, `☐` Pending).
- Displays a progress bar: `2 / 5 tasks completed (40%)`.

### 5.5. Slash Command Autocomplete (`<AutocompletePopup />`)
- When the user types `/` in the composer, an autocomplete popup appears.
- Populated dynamically from `session.availableCommands` advertised by Fox CLI.
- Fully keyboard-accessible:
  - `Arrow Up` / `Arrow Down` navigates options.
  - `Tab` or `Enter` inserts command.
  - `Escape` closes popup.

### 5.6. Composer (`<Composer />`)
- Auto-expanding `<textarea>` with placeholder text: `Ask Fox or type '/' for commands...`.
- Submit on `Enter`, newline on `Shift+Enter`.
- Image attachment chips rendered as thumbnails with remove (`✕`) buttons.
- File paste and drag-and-drop handled by `useImageAttachments` hook (see §5.10).
- Cancel button visible when `turnInProgress` is true.
- Recalls previous prompts on `Up Arrow` in empty input.

### 5.7. Context Window Progress Bar (`<ContextProgress />`)

Inspired directly by Kilo Code's [`ContextProgress.tsx`](file:///home/k82l0804/workarea/fox/ext-repo/agent-cli/kilocode/packages/kilo-vscode/webview-ui/src/components/chat/ContextProgress.tsx), this component visualizes token consumption from `usage_update` events:

```tsx
// webview/src/components/ContextProgress.tsx
interface Props {
  used: number;    // Tokens consumed so far
  size: number;    // Total context window size
}

export function ContextProgress({ used, size }: Props) {
  const pct = Math.min(100, Math.round((used / size) * 100));
  const remaining = size - used;
  // reserved = ~15% headroom for output tokens
  const reserved = Math.round(size * 0.15);
  const usedPct = Math.round((used / size) * 100);
  const reservedPct = 15;
  const availPct = Math.max(0, 100 - usedPct - reservedPct);

  const color = pct >= 90 ? "var(--vscode-charts-red)"
              : pct >= 70 ? "var(--vscode-charts-yellow)"
              : "var(--vscode-charts-green)";

  return (
    <div class="context-progress" title={`${used.toLocaleString()} / ${size.toLocaleString()} tokens used (${pct}%)`}>
      <div class="ctx-bar">
        <div class="ctx-used" style={{ width: `${usedPct}%`, background: color }} />
        <div class="ctx-reserved" style={{ width: `${reservedPct}%` }} />
        <div class="ctx-avail" style={{ width: `${availPct}%` }} />
      </div>
      <span class="ctx-label">{pct}% context used</span>
    </div>
  );
}
```

- Three-segment bar: **used** (color-coded) / **reserved** (15% output headroom, muted) / **available** (green).
- Color shifts: green → amber (≥70%) → red (≥90%).
- Hover tooltip shows exact token counts: `42,340 / 128,000 tokens used (33%)`.
- **Cost fields from `usage_update` are intentionally ignored** — only `used` and `size` are read.
- Displayed below the `<Header />` at all times during an active session.

### 5.8. Elicitation Question Dock (`<QuestionDock />`)

Renders inline above the Composer when the agent emits an `elicitation/create` request:

```tsx
// webview/src/components/QuestionDock.tsx
interface Props {
  message: string;
  schema?: ElicitationSchema;   // JSON Schema describing form fields
  onSubmit: (content: Record<string, unknown>) => void;
  onDecline: () => void;
}

export function QuestionDock({ message, schema, onSubmit, onDecline }: Props) {
  // Renders dynamically from JSON Schema field types:
  // string + enum  → <RadioGroup />
  // array + enum   → <CheckboxGroup />
  // string         → <input type="text" />
  // boolean        → <input type="checkbox" />
}
```

- Blocks the Composer input while active (user must respond or skip).
- **Submit** button collects all field values and calls `onSubmit`.
- **Skip** button calls `onDecline` (sends `outcome: "decline"` to agent).
- Supports `$/cancel_request` dismissal — dock disappears and sends `outcome: "cancel"`.

### 5.9. Notice Banner (`<NoticeBanner />`)

A dismissible advisory toast rendered above the Composer for `notice` events:

```tsx
// webview/src/components/NoticeBanner.tsx
interface Props {
  level: "info" | "warning" | "error";
  message: string;
  onDismiss: () => void;
}

export function NoticeBanner({ level, message, onDismiss }: Props) {
  const icon = { info: "ℹ️", warning: "⚠️", error: "🚫" }[level];
  return (
    <div class={`notice-banner notice-${level}`}>
      <span>{icon} {message}</span>
      <button class="notice-dismiss" onClick={onDismiss} aria-label="Dismiss">✕</button>
    </div>
  );
}
```

- `level: "info"` → blue tint, `"warning"` → amber tint, `"error"` → red tint.
- Auto-dismisses after 10 seconds for `info` notices; `warning` and `error` require explicit user dismissal.

### 5.10. Agent-Owned Terminal (`<TerminalStreamView />`)

Rendered inside `<AssistantTurn>` when the agent emits `terminal_update` notifications:

- Hosts an [`@xterm/xterm`](https://github.com/xtermjs/xterm.js) `Terminal` instance within the webview.
- `@xterm/addon-fit` is used for responsive column/row resizing when the panel is resized.
- `terminal_output_chunk` data (base64-encoded VT100 bytes) is decoded and written via `terminal.write(data)`.
- The panel is collapsible (click header to minimize) and shows an `[Exited]` badge when the terminal session ends.
- Multiple concurrent terminal instances are supported, each identified by `terminalId`.

### 5.11. Image Attachments Hook (`useImageAttachments`)

Adapted from Kilo Code's [`useImageAttachments.ts`](file:///home/k82l0804/workarea/fox/ext-repo/agent-cli/kilocode/packages/kilo-vscode/webview-ui/src/hooks/useImageAttachments.ts):

```tsx
// webview/src/hooks/useImageAttachments.ts
export function useImageAttachments() {
  const [images, setImages] = useState<ImageAttachment[]>([]);

  // Handle clipboard paste (Ctrl+V with image on clipboard)
  const onPaste = useCallback((e: ClipboardEvent) => {
    const items = Array.from(e.clipboardData?.items ?? []);
    for (const item of items) {
      if (item.type.startsWith("image/")) {
        const blob = item.getAsFile();
        if (blob) encodeAndAppend(blob);
      }
    }
  }, []);

  // Handle drag-and-drop of image files onto the Composer
  const onDrop = useCallback((e: DragEvent) => {
    e.preventDefault();
    const files = Array.from(e.dataTransfer?.files ?? []);
    files.filter(f => f.type.startsWith("image/")).forEach(encodeAndAppend);
  }, []);

  const remove = (index: number) =>
    setImages(prev => prev.filter((_, i) => i !== index));

  return { images, onPaste, onDrop, remove };
}
```

- Reads image blobs as `ArrayBuffer`, encodes to base64, and constructs `ImageAttachment` objects.
- Thumbnail preview URLs generated via `URL.createObjectURL` for display in chips.
- Images are appended to `sendPrompt` payload as `ContentBlock::Image` entries in the ACP request.
- Supported media types: `image/png`, `image/jpeg`, `image/gif`, `image/webp`.

### 5.12. Thought Effort Picker (`<ThoughtEffortPicker />`)

A dropdown rendered in the `<Toolbar />` for controlling the `thought_level` session config option:

- Only rendered when the active session's `configOptions` includes an option with `id: "thought_level"`.
- Renders as a compact segmented control: `[Low] [Medium] [High]`.
- Selecting a value calls `setConfigOption({ configId: "thought_level", value: "low" | "medium" | "high" })`.
- Visual indicator: brain icon (`🧠`) with current level label.

---

## 6. Webpack Configuration for Preact

The Webpack config produces two bundles from the dual-target setup:

```javascript
// webpack.config.js (webview target excerpt)
{
  target: "web",
  entry: "./webview/src/main.tsx",
  output: {
    filename: "webview.js",
    path: path.resolve(__dirname, "dist"),
  },
  resolve: {
    extensions: [".tsx", ".ts", ".js"],
    alias: {
      // Preact compatibility layer — allows importing "react" packages
      "react": "preact/compat",
      "react-dom": "preact/compat",
    },
  },
  module: {
    rules: [
      {
        test: /\.tsx?$/,
        use: "ts-loader",
        exclude: /node_modules/,
      },
      {
        test: /\.css$/,
        use: ["style-loader", "css-loader"],
      },
    ],
  },
}
```

### TypeScript Configuration for JSX

```json
// webview/tsconfig.json
{
  "compilerOptions": {
    "jsx": "react-jsx",
    "jsxImportSource": "preact",
    "target": "ES2022",
    "module": "ES2022",
    "moduleResolution": "bundler",
    "strict": true
  }
}
```

---

## 7. Keyboard Shortcuts & User Controls

| Keybinding | Scope | Action |
|---|---|---|
| `Ctrl+Shift+A` (`Cmd+Shift+A`) | Global Editor | Focuses or toggles the Fox Chat Webview panel. |
| `Escape` | Global when turn active | Cancels the active agent turn (`cancelTurn`). |
| `Enter` | Composer Input | Submits prompt. |
| `Shift+Enter` | Composer Input | Inserts newline without submitting. |
| `Up Arrow` (in empty composer) | Composer Input | Recalls previous submitted prompt from history. |
