# Fox ACP Client Implementation Plan & Task List

> Step-by-step engineering roadmap for implementing the Fox ACP Client VSCode extension (`fox/fox-acp-client/`) based on the specifications in [`docs/fox-acp-client/specs/`](../specs/).

---

## 1. Roadmap Overview

```
Phase 1: Project Setup & Extension Manifest Skeleton
   │
   ▼
Phase 2: Executable Resolver & Process Supervisor (fox binary auto-discovery)
   │
   ▼
Phase 3: Stdio Transport & Connection Manager (@agentclientprotocol/sdk)
   │
   ▼
Phase 3b: Advanced Session Lifecycle (close/delete/fork/additionalDirs/state_update)
   │
   ▼
Phase 4: Core Session Manager & Notification Dispatcher (Lifecycle & History)
   │
   ▼
Phase 4b: Elicitation Handler & In-Session Auth (elicitation/create)
   │
   ▼
Phase 5: Client Capabilities - Filesystem & Terminal Handlers
   │
   ▼
Phase 6: Security & Permission Escalation Handling
   │
   ▼
Phase 7: Interactive Diff Review Subsystem (vscode.diff & fox-diff://)
   │
   ▼
Phase 8: Workspace MCP Server Discovery & Session Forwarding
   │
   ▼
Phase 9: Chat Webview UI & Component System (Streaming Markdown, Tools & Advanced UI)
   │
   ▼
Phase 10: Inline Autocomplete & Next Edit Suggestions (NES)
   │
   ▼
Phase 11: In-Process MCP-over-ACP Tool Server
   │
   ▼
Phase 12: End-to-End Verification, Local Proxy Testing, & Packaging
```

---

## 2. Detailed Task Breakdown

### Phase 1: Project Setup & Extension Manifest Skeleton (`fox/fox-acp-client/`)
*Spec: [01-architecture-overview.md](../specs/01-architecture-overview.md)*
- [ ] Initialize `fox/fox-acp-client/package.json`:
  - Name: `fox-acp-client`, displayName: `Fox ACP Client`.
  - VSCode engine target: `^1.85.0`.
  - Core dependencies: `@agentclientprotocol/sdk` (v0.21+), `preact` (v10.24+), `marked`, `highlight.js`.
  - Pruned: Exclude `@vscode/extension-telemetry` (strictly zero telemetry); exclude `react` / `react-dom` (replaced by Preact).
- [ ] Configure `package.json` contributes:
  - Activity Bar container: `fox-client` with custom Fox icon.
  - Views: `fox-sessions` (tree view) and `fox-chat` (webview view).
  - Commands: `fox.connect`, `fox.newConversation`, `fox.cancelTurn`, `fox.disconnect`, `fox.diff.accept`, `fox.diff.reject`, `fox.showTraffic`.
  - Configuration schema (`fox.executablePath`, `fox.autoConnect`, `fox.autoApprovePermissions`, `fox.diffReviewMode`, `fox.logTraffic`, `fox.mcpServers`).
- [ ] Setup `tsconfig.json` targeting ES2022, Node18, and strict type checking.
- [ ] Configure `webpack.config.js` with dual targets:
  - Target 1: Extension host bundle (`dist/extension.js`).
  - Target 2: Preact webview bundle (`dist/webview.js`) with `resolve.alias: { react: "preact/compat", "react-dom": "preact/compat" }`.
- [ ] Create `webview/tsconfig.json` with `jsx: "react-jsx"` and `jsxImportSource: "preact"`.
- [ ] Create `shared/types.ts` with typed `WebviewMessage` and `ExtensionMessage` discriminated unions.

---

### Phase 2: Executable Resolver & Process Supervisor (`src/core/`, `src/config/`)
*Spec: [02-agent-process-and-connection.md](../specs/02-agent-process-and-connection.md)*
- [ ] Implement `BinaryResolver`:
  - Check `fox.executablePath` from VSCode workspace settings.
  - Check workspace local `./bin/fox` and `./node_modules/.bin/fox`.
  - Perform system `PATH` lookup (`which fox` on Unix, `where.exe fox` on Windows).
  - Validate binary executable bit and test execution (`fox --version`).
  > **V1 Scope:** In multi-root workspaces, only the first workspace folder (`workspaceFolders[0]`) is used for binary resolution and session CWD. See [Spec 07 §2](../specs/07-mcp-forwarding-and-configuration.md) for the full multi-root scoping note.
- [ ] Implement `ProcessSupervisor`:
  - Spawn `fox acp --cwd <workspace>` with `stdio: ["pipe", "pipe", "pipe"]`.
  - Set `windowsHide: true` and inherit sanitized environment variables.
  - Pipe child process `stderr` to the **Fox Output Channel** for debugging.
  - Listen for process `exit`, `error`, and unexpected crash events.
  - Implement graceful shutdown: ACP `cancel` ➔ `SIGTERM` ➔ 3-second grace ➔ `SIGKILL`.

---

### Phase 3: Stdio Transport & Connection Manager (`src/core/`, `src/utils/`)
*Spec: [02-agent-process-and-connection.md](../specs/02-agent-process-and-connection.md)*
- [ ] Implement stream conversion:
  - Convert Node.js `process.stdout` to `ReadableStream<Uint8Array>` (`Readable.toWeb`).
  - Convert Node.js `process.stdin` to `WritableStream<Uint8Array>` (`Writable.toWeb`).
  - Instantiate `ndJsonStream(writable, readable)`.
- [ ] Implement non-blocking Protocol Traffic Tap:
  - Transform stream capturing outgoing requests (`send`) and incoming events (`recv`).
  - Format formatted JSON-RPC messages to the **Fox Protocol Traffic** output channel.
- [ ] Bind `ClientSideConnection`:
  - Use the factory pattern: `new ClientSideConnection((agent) => { client.setAgent(agent); return client; }, stream)`.
  - Perform handshake: `connection.initialize({ protocolVersion: PROTOCOL_VERSION, ... })`.
  - Inspect `capabilities` (`loadSession`, `listSessions`, `mcpServers`).
- [ ] Implement disposal chain (see [Spec 02 §7](../specs/02-agent-process-and-connection.md)): register all disposables via `context.subscriptions`.

---

### Phase 3b: Advanced Session Lifecycle (`src/core/`)
*Spec: [03-session-management-and-history.md §3.5–3.8](../specs/03-session-management-and-history.md)*
- [ ] Implement `closeSession(sessionId)` — calls `connection.sessionClose({ sessionId })`, removes from active map.
- [ ] Implement `deleteSession(sessionId)` — shows confirmation modal, calls `connection.sessionDelete({ sessionId })`, purges cache.
- [ ] Implement `forkSession(sessionId, cwd)` — calls `connection.sessionFork({ sessionId, cwd })`, re-injects MCP servers, switches to new session.
- [ ] Implement `additionalDirectories` in `newSession`/`loadSession` (V1: empty, wired for V2 multi-root).
- [ ] Update `SessionUpdateRouter` to handle new notification types:
  - `state_update` → tracks turn state (`running`, `requires_action`, `idle`); drives `turnInProgress` flag.
  - `usage_update` → extracts `{ used, size }` (ignores cost fields), emits `usageUpdate` postMessage.
  - `notice` → emits `notice` postMessage for `NoticeBanner`.
  - `terminal_update` / `terminal_output_chunk` → emits `terminalUpdate` / `terminalOutputChunk` postMessages.
- [ ] Update `sendPrompt` to follow ACP v2 immediate-ack model: treat `session/prompt` response as `{}`, track completion via `state_update { state: "idle" }`.
- [ ] Update `sendPrompt` to support `ContentBlock::Image` (base64 `ImageAttachment` from webview).

---

### Phase 4: Core Session Manager & Notification Dispatcher (`src/core/`)
*Spec: [03-session-management-and-history.md](../specs/03-session-management-and-history.md)*
- [ ] Implement `SessionManager`:
  - Maintain session map (`sessions: Map<string, SessionInfo>`).
  - Implement `newSession({ cwd, mcpServers })` and `cancel({ sessionId })`.
  - Implement `setMode`, `setModel`, and modern `setConfigOption`.
- [ ] Implement `SessionUpdateRouter`:
  - Route `agent_message_delta` and `thought_message_delta` to active message.
  - Route `tool_call_start`, `tool_call_update`, and `tool_call_complete` to tool cards.
  - Route `plan_update` to the interactive plan checklist.
- [ ] Implement microtask notification race guard (`drainPending`):
  - Buffer notifications arriving before `newSession` resolves and drain immediately upon registration.
- [ ] Implement `HistoryStore`:
  - Cache session metadata in VSCode `workspaceState`.
  - Integrate with Fox CLI SQLite database via `session/list` and `session/load`.

---

### Phase 4b: Elicitation Handler (`src/handlers/`)
*Spec: [04-client-capabilities-and-security.md §5](../specs/04-client-capabilities-and-security.md)*
- [ ] Implement `ElicitationHandler` for `elicitation/create`:
  - `mode: "form"`: parse `requestedSchema`, forward as `elicitationRequest` postMessage to webview.
  - Await `elicitationResponse` postMessage from `QuestionDock` (accept/decline).
  - Return `{ outcome: "accept", content: { ... } }` or `{ outcome: "decline" }` to Fox CLI.
  - Handle `$/cancel_request` dismissal — reject outstanding elicitation promise, return `{ outcome: "cancel" }`.
  - `mode: "url"`: show VSCode consent dialog with domain name; call `vscode.env.openExternal` on accept.

---

### Phase 5: Client Capabilities - Filesystem & Terminal Handlers (`src/handlers/`)
*Spec: [04-client-capabilities-and-security.md](../specs/04-client-capabilities-and-security.md)*
- [ ] Implement `FileSystemHandler`:
  - Implement buffer-aware `readTextFile`: check `vscode.workspace.textDocuments` first for dirty editor buffers before reading disk.
  - Implement line slicing (`line` and `limit` parameters with 1-based indexing).
  - Implement safe `writeTextFile`: verify workspace confinement, auto-create parent directories.
- [ ] Implement `TerminalHandler`:
  - Implement `createTerminal`: spawn child process and mirror to a VSCode `Pseudoterminal` tab.
  - Implement `terminalOutput`: buffer stdout/stderr up to 1MB with clean character boundary truncation.
  - Implement `waitForTerminalExit`, `killTerminal`, and `releaseTerminal`.
  - Ensure releasing terminal does not destroy the VSCode terminal panel.

---

### Phase 6: Security & Permission Handling (`src/handlers/`)
*Spec: [04-client-capabilities-and-security.md](../specs/04-client-capabilities-and-security.md)*
- [ ] Implement `PermissionHandler`:
  - Handle `requestPermission` from Fox CLI.
  - Support auto-approval policies from `fox.autoApprovePermissions` (`ask`, `allowWorkspaceRead`, `allowAll`).
  - Render interactive VSCode QuickPick with `allow_once`, `allow_always`, and `reject` options.
  > **Implementation Note:** Phase 6 initially implements only the native QuickPick path. The in-chat interactive permission card (rendered inside the webview) is wired during Phase 9 after the webview message bus is available.

---

### Phase 7: Interactive Diff Review Subsystem (`src/diff/`)
*Spec: [06-diff-viewer-and-editor-integration.md](../specs/06-diff-viewer-and-editor-integration.md)*
- [ ] Implement `FoxDiffDocumentProvider`:
  - Register `TextDocumentContentProvider` for the `fox-diff://` URI scheme.
  - Provide in-memory staged contents for proposed file modifications.
- [ ] Implement `DiffManager`:
  - Check `fox.diffReviewMode` (`always`, `onCollision`, `never`).
  - Open side-by-side diff via `vscode.commands.executeCommand('vscode.diff', ...)`.
  - Implement `fox.diff.accept`: write staged buffer to disk and close diff.
  - Implement `fox.diff.reject`: discard staged buffer and return rejection to agent.
  - Register editor title bar buttons and status bar review indicator.

---

### Phase 8: Workspace MCP Server Discovery & Session Forwarding (`src/mcp/`)
*Spec: [07-mcp-forwarding-and-configuration.md](../specs/07-mcp-forwarding-and-configuration.md)*
- [ ] Implement `McpConfigLoader`:
  - Discover configurations from `.fox/mcp.json`, `.vscode/mcp.json`, and VSCode setting `fox.mcpServers`.
  - Resolve `${workspaceFolder}` and `${env:VAR_NAME}` variables.
  - Validate and normalize server configs into standard ACP `McpServerConfig` format.
- [ ] Forward discovered MCP servers in ACP payloads:
  - Inject servers into `newSession({ cwd, mcpServers })` and `loadSession({ sessionId, cwd, mcpServers })`.

---

### Phase 9: Chat Webview UI & Preact Component System (`webview/`)
*Spec: [05-chat-webview-and-ui.md](../specs/05-chat-webview-and-ui.md)*
- [ ] Build Webview Shell & CSP:
  - HTML shell (`webview/index.html`) with strict Content Security Policy, nonce-based `script-src`, and `<div id="app">` mount point.
  - VSCode theme-aware CSS variables (`--vscode-editor-background`, etc.).
- [ ] Setup Preact Application Root:
  - `webview/src/main.tsx`: Mount `<App />` via `render()` from Preact.
  - `webview/src/App.tsx`: Top-level layout composing Header, ContextProgress, NoticeBanner, Toolbar, MessageStream, QuestionDock, and Composer.
- [ ] Implement Preact Hooks:
  - `useSession`: Subscribes to `postMessage` events, provides reactive `SessionState` (session, isConnected, turnInProgress, usageStats).
  - `useStreaming`: Accumulates `agentDelta` / `thoughtDelta` tokens into streaming buffers.
  - `useImageAttachments`: Handles clipboard paste and drag-drop image encoding into `ImageAttachment` objects.
- [ ] Implement Core Preact TSX Components:
  - `<MarkdownContent />`: Streaming `marked` + `highlight.js` renderer with `useMemo` optimization.
  - `<ThinkingBlock />`: Collapsible `<think>` reasoning container with live timer and animated pulse indicator.
  - `<ToolCard />`: Tool call lifecycle card with pending/running/completed/failed states and expandable I/O.
  - `<PlanWidget />`: Interactive plan/todo checklist widget synced with `plan_update`.
  - `<PermissionCard />`: In-chat approval buttons (wiring the Phase 6 permission handler into the webview).
  - `<AutocompletePopup />`: Slash command popup from `session.availableCommands`.
  - `<Toolbar />`: Mode, Model, ThoughtEffort, and Session Config Options dropdowns.
  - `<Composer />`: Auto-expanding textarea, submit/cancel, image attachment chips, prompt history recall.
- [ ] Implement Advanced Preact TSX Components:
  - `<ContextProgress />`: 3-segment token capacity bar (used/reserved/available) bound to `usageUpdate` messages. Color shifts green→amber→red at utilization thresholds. **No cost display.**
  - `<QuestionDock />`: Inline elicitation form above Composer; renders from JSON Schema (radio groups, checkboxes, text inputs); Submit/Skip actions dispatch `elicitationResponse`.
  - `<NoticeBanner />`: Dismissible advisory toast for `notice` events with level-appropriate color coding.
  - `<TerminalStreamView />`: `@xterm/xterm` terminal panel with `@xterm/addon-fit` for responsive resize; decodes base64 VT100 chunks via `terminalOutputChunk` messages.
  - `<ThoughtEffortPicker />`: Segmented `[Low] [Medium] [High]` control in `<Toolbar />`; only shown when session `configOptions` includes `id: "thought_level"`.

---

### Phase 10: Inline Autocomplete & Next Edit Suggestions (NES) (`src/services/`)
*Spec: [06-diff-viewer-and-editor-integration.md §7](../specs/06-diff-viewer-and-editor-integration.md)*

> **Fox CLI V2 Dependency & Scoping:** NES requires a specialized low-latency Fill-In-The-Middle (FIM) local model pipeline and debounced endpoint on Fox CLI, which is tracked on the [Fox CLI V2 Roadmap](../../fox-cli/plans/cli-implementation-plan.md#31-next-edit-suggestions-nes-engine). For V1, `InlineCompletionService` will be implemented with `fox.nes.enabled: false` by default, strictly guarded by checking the `initialize` capabilities response, and will gracefully remain dormant if Fox CLI does not advertise NES support.

- [ ] Implement `InlineCompletionService`:
  - Register `vscode.languages.registerInlineCompletionItemProvider` for all file patterns.
  - Track per-file edit history ring buffer (up to `fox.nes.maxHistoryEntries` edits).
  - Implement `provideInlineCompletions()`: check capability flag; call `connection.nesRequest()` with cursor position and edit history context.
  - Implement `nes/start` (on session connect) and `nes/stop` (on session disconnect/close).
  - Send `nes/accept` when the user accepts a ghost-text suggestion via `Tab`.
  - Wire `onDidChangeTextDocument`, `onDidChangeActiveTextEditor`, `onDidCloseTextDocument` event listeners.
- [ ] Respect `fox.nes.enabled` and `fox.nes.triggerDelay` configuration settings.
- [ ] Add NES toggle button to the status bar (disabled/hidden when server lacks NES capability).

---

### Phase 11: In-Process MCP Tool Server (`src/mcp/`)
*Spec: [07-mcp-forwarding-and-configuration.md §4](../specs/07-mcp-forwarding-and-configuration.md)*

> **Transport Compatibility & V1 Strategy:** In-stream MCP-over-ACP reverse tunneling (`transport: "acp"`) is tracked on the [Fox CLI V2 Roadmap](../../fox-cli/plans/cli-implementation-plan.md#32-in-process-mcp-over-acp-reverse-tunneling-transport-acp). Because Fox CLI V1 supports `stdio` and `sse` MCP transports (Spec 04), `InProcessMcpServer` provides a dual-mode transport architecture:
> - **V1 Fallback Mode:** The extension spins up a lightweight localhost HTTP/SSE endpoint on loopback (`http://127.0.0.1:<ephemeral-port>/sse`) and passes standard `{ name: "vscode", url: "http://127.0.0.1:.../sse" }` into `mcpServers`. This allows Fox CLI V1 to call VSCode IDE tools immediately without changes.
> - **V2 Native Mode:** If Fox CLI advertises `mcpCapabilities: { acp: true }`, the client switches to direct in-stream tunneling `{ name: "vscode", transport: "acp" }`.

- [ ] Implement `InProcessMcpServer`:
  - `get_diagnostics(path?)`: query `vscode.languages.getDiagnostics()` for typed errors and warnings.
  - `search_symbols(query)`: invoke `vscode.executeWorkspaceSymbolProvider` command.
  - `get_open_files()`: return `vscode.workspace.textDocuments` fsPath list.
  - `git_status()`: query the built-in `vscode.git` extension API for branch, ahead/behind, and change lists.
- [ ] Implement dual-mode server registration:
  - Default to local SSE endpoint on loopback for Fox CLI V1 compatibility.
  - Fall back to / upgrade to `{ "name": "vscode", "transport": { "type": "acp" } }` when server advertises ACP MCP transport capability.
- [ ] Handle `callTool` dispatch when Fox CLI invokes `vscode.*` MCP tools.
- [ ] Wrap all tool implementations in try/catch — return `{ error: "..." }` on failure without crashing the session.

---

### Phase 12: End-to-End Verification & Extension Packaging
*Spec: [README.md](../specs/README.md)*

#### Happy-Path Verification Scenarios
- [ ] **Binary Discovery & Connect**: Open a workspace with `fox` in PATH; verify automatic process spawn and status bar indicator showing connected state.
- [ ] **Chat & Local Model Streaming**: Submit a coding prompt; verify Markdown streaming, `<think>` reasoning collapse, and prompt completion.
- [ ] **Context Window Bar**: Verify `ContextProgress` updates after each turn; confirm amber/red color shifts at 70%/90% utilization.
- [ ] **Buffer-Aware File Reading**: Modify a file in the editor without saving; prompt Fox to read it; verify Fox receives the dirty in-memory buffer content.
- [ ] **Interactive Diff Review**: Prompt Fox to edit a file; verify side-by-side diff editor opens; click **Accept** and verify disk write.
- [ ] **Terminal Execution**: Prompt Fox to run a build or test command; verify terminal output streams in both the webview tool card and the VSCode integrated terminal.
- [ ] **Agent Terminal Streaming**: Verify `TerminalStreamView` renders xterm.js panel when `terminal_update` arrives; confirm VT100 output renders correctly.
- [ ] **Image Attachment**: Paste an image into the Composer; verify thumbnail chip appears; submit prompt; verify `ContentBlock::Image` is sent to Fox CLI.
- [ ] **Elicitation Form**: Trigger an agent that uses `elicitation/create`; verify `QuestionDock` renders with correct field types; submit and verify response reaches agent.
- [ ] **Session Fork**: Click **Fork Session** from the session tree; verify a new branched session appears; confirm conversation history is cloned.
- [ ] **Session Delete**: Delete a session from the tree; confirm modal appears; confirm session removed from tree and cache.
- [ ] **Notice Banner**: Trigger a `notice` event; verify `NoticeBanner` appears above Composer; verify auto-dismiss for `info` level.
- [ ] **NES Ghost Text**: Edit a file; verify ghost-text suggestion appears after `fox.nes.triggerDelay` ms; accept with `Tab`.
- [ ] **In-Process MCP**: Confirm Fox CLI can call `vscode.get_diagnostics` and receive live TypeScript error data.
- [ ] **MCP Tool Invocation**: Configure an MCP server in `.fox/mcp.json`; verify Fox mounts the tool and invokes it during session turns.
- [ ] **Session Restoration**: Close and re-open VSCode; click a prior session in the session tree; verify conversation history rehydrates from Fox CLI's SQLite database.

#### Edge-Case & Safety Scenarios
- [ ] **Graceful Cancellation**: Trigger a long-running shell command; hit `Escape`; verify child processes terminate immediately and state resets to idle.
- [ ] **Process Crash Recovery**: Kill the `fox acp` process externally (`kill -9`); verify extension surfaces a restart button without crashing the extension host.
- [ ] **Air-Gap Privacy Check**: Run a network packet capture; confirm zero outbound HTTP/DNS requests to external domains (zero telemetry, zero remote CDN calls).
- [ ] **Elicitation Cancel**: Send `$/cancel_request` during an active elicitation; verify `QuestionDock` dismisses and `outcome: "cancel"` is returned.
- [ ] **Packaging Verification**: Run `@vscode/vsce package` to compile and produce a standalone `.vsix` installer artifact.

---

### Testing Strategy

#### Unit Test Framework
- [ ] Configure **Vitest** (or Mocha if aligning with upstream) as the test runner.
- [ ] Set up test infrastructure in `src/test/` matching the upstream directory structure.

#### Mocking Approach
- [ ] Create a mock `ClientSideConnection` and `Agent` proxy for testing handlers without a live process.
- [ ] Create a mock `vscode` API shim (using `@vscode/test-electron` or a lightweight stub) for testing `FileSystemHandler`, `TerminalHandler`, and `PermissionHandler` in isolation.
- [ ] Reference the upstream test helpers in `ext-repo/acp-client/vscode-acp/src/test/` and `ext-repo/agent-cli/kilocode/packages/opencode/test/cli/acp/acp-test-client.ts` for ACP protocol mocking patterns.

#### CI Pipeline
- [ ] Add a CI job that runs `npm run lint && npm run test && npm run build` to verify clean compilation and test passage.
- [ ] Add a packaging step that produces a `.vsix` artifact for manual smoke testing.
