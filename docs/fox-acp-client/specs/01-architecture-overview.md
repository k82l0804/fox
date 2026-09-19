# Spec 01: Architecture Overview & Upstream Delta

> High-level system architecture, component breakdown, upstream analysis of `vscode-acp`, and structural decisions for Fox ACP Client.

---

## 1. System Context & Topology

Fox ACP Client is a Visual Studio Code extension running in the editor's Extension Host process. It serves as the primary visual interface and ACP client for **Fox Code CLI** (or any ACP-compliant agent server).

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            VSCode Window                                    │
│                                                                             │
│  ┌───────────────────────┐  ┌───────────────────────┐  ┌─────────────────┐  │
│  │   Primary Editor      │  │   Diff Editor         │  │   Activity Bar  │  │
│  │   - Active Buffers    │  │   - vscode.diff       │  │   - Fox Sidebar │  │
│  │   - Diagnostics       │  │   - fox-diff:// URI   │  │     Icon        │  │
│  └───────────▲───────────┘  └───────────▲───────────┘  └────────┬────────┘  │
│              │                          │                       │           │
│              │                          │                       ▼           │
│  ┌───────────┴──────────────────────────┴────────────────────────────────┐  │
│  │                     Fox ACP Client Extension Host                     │  │
│  │                                                                       │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    Webview Chat Provider (Preact)               │  │  │
│  │  │  - Preact Component Tree (App, MessageStream, Composer)        │  │  │
│  │  │  - Hooks: useSession, useStreaming (postMessage bridge)        │  │  │
│  │  │  - TSX Components: MarkdownContent, ThinkingBlock, ToolCard   │  │  │
│  │  │  - Interactive Plan Checklist & Permission Cards               │  │  │
│  │  └────────────────────────────────┬────────────────────────────────┘  │  │
│  │                                   │ postMessage / RPC                 │  │
│  │                                   ▼                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                     Core Session Manager                        │  │  │
│  │  │  - Multi-Session Lifecycle (new/load/close/delete/fork)        │  │  │
│  │  │  - Notification Dispatcher (sessionUpdate Router)               │  │  │
│  │  │  - Session History Store (workspaceState + Fox SQLite Sync)      │  │  │
│  │  │  - UsageTracker: usage_update → context window metering         │  │  │
│  │  │  - ElicitationHandler: elicitation/create → QuestionDock UI    │  │  │
│  │  └───────────────┬─────────────────────────────────┬───────────────┘  │  │
│  │                  │                                 │                  │  │
│  │                  ▼                                 ▼                  │  │
│  │  ┌───────────────────────────────┐ ┌───────────────────────────────┐  │  │
│  │  │      Client Capabilities      │ │   MCP Forwarding & Config     │  │  │
│  │  │  - FileSystemHandler (Buffers)│ │  - .fox/mcp.json Reader       │  │  │
│  │  │  - TerminalHandler (PTY)      │ │  - Dynamic Session Injection  │  │  │
│  │  │  - PermissionHandler (Modals) │ │  - Settings & Binary Resolver │  │  │
│  │  │  - InlineCompletionService   │ │  - InProcessMcpServer (ACP)   │  │  │
│  │  └───────────────┬───────────────┘ └───────────────┬───────────────┘  │  │
│  │                  │                                 │                  │  │
│  │                  └────────────────┬────────────────┘                  │  │
│  │                                   ▼                                   │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                   Connection Manager & Supervisor               │  │  │
│  │  │  - Binary Auto-Discovery (PATH / workspace / config)            │  │  │
│  │  │  - Child Process Spawner (`fox acp --cwd <workspace>`)          │  │  │
│  │  │  - ClientSideConnection & ndJsonStream (@agentclientprotocol)   │  │  │
│  │  │  - Traffic Inspection Channel & Health Watchdog                 │  │  │
│  │  │  - Disposal Chain (see Spec 02 §7)                             │  │  │
│  │  └────────────────────────────────┬────────────────────────────────┘  │  │
│  └───────────────────────────────────┼───────────────────────────────────┘  │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │ stdio (JSON-RPC 2.0)
                                       │ stdin: Requests, Responses, Inlined FS
                                       │ stdout: Responses, sessionUpdate stream
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Fox Code CLI Process                               │
│                         (`fox acp --cwd <workspace>`)                       │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                        AgentSideConnection                            │  │
│  │                     (@agentclientprotocol/sdk)                        │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
│                                      │                                      │
│                                      ▼                                      │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │               Agent Orchestrator, Tools, & Local Model Subsystem      │  │
│  └───────────────────────────────────┬───────────────────────────────────┘  │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │ HTTP / SSE
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                   Local Model Inference (`localhost:8000`)                   │
│                       (openai-proxy, Ollama, vLLM)                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Upstream Analysis: `vscode-acp` vs. Fox ACP Client

The reference repository `ext-repo/acp-client/vscode-acp` (authored by FormulaHendry) was inspected in detail. It implements the essential ACP JSON-RPC client protocol, but carries assumptions and external dependencies that do not fit a secure, local-first architecture.

### Upstream Delta Matrix

| Subsystem / Feature | Status in `vscode-acp` | Decision for Fox ACP Client | Rationale |
|---|---|---|---|
| **Default Agent Focus** | Preconfigured with multiple cloud/remote agents (`npx @github/...`, `claude-agent-acp`, `gemini-cli`, etc.). | **First-Class Fox Code CLI pairing** | Fox ACP Client is designed specifically as the companion UI for `fox`. It detects and manages `fox acp` automatically, while still permitting arbitrary ACP agents. |
| **Process Management** | Simple spawn via `npx` or system command from settings; no binary auto-discovery. | **Smart Binary Discovery & Supervisor** | Automatically searches `PATH`, `./bin/fox`, and `node_modules/.bin/fox`, validates binary version, and monitors process health. |
| **Telemetry & Analytics** | Uses `@vscode/extension-telemetry` to transmit usage metrics to Azure Application Insights. | **Completely Pruned (Zero Telemetry)** | Fox is strictly local-first and privacy-preserving. No telemetry reporters, no phone-home pings. |
| **Agent Registry Sync** | Dynamically fetches remote agent lists from `cdn.agentclientprotocol.com`. | **Pruned / Offline-First** | Eliminates external HTTP dependencies. Agent configurations are driven locally by workspace and user settings. |
| **MCP Forwarding** | Hardcoded to send empty `mcpServers: []` in `conn.newSession()`. | **Dynamic Workspace MCP Discovery + MCP-over-ACP** | Ingests `.fox/mcp.json`, `.vscode/mcp.json`, and extension settings, forwarding MCP servers to Fox CLI. Also hosts an in-process MCP server exposing VSCode diagnostics/search tools via ACP transport. |
| **File Editing & Diffing** | Directly writes files via `fs.writeFile` and calls `showTextDocument`. | **Interactive Diff Review (`vscode.diff`) + NES** | Inspect proposed file modifications side-by-side using virtual document URIs (`fox-diff://`). Next Edit Suggestions (`nes/*`) deliver inline ghost-text code completions in the editor. |
| **Local Model UI Polish** | Basic message rendering; simple thinking animation. | **Enhanced Local Model UI** | `<think>` parsing with duration timer, context window capacity bar (`usage_update`), interactive task checklist, image paste/attach support, advisory notice banners, and inline elicitation forms. |
| **Session Persistence** | Stores session metadata in VSCode `workspaceState`; loads history only if agent supports `session/load`. | **Dual-Tier State Synchronization + Full Lifecycle** | Connects with Fox CLI's embedded SQLite database via `session/list` and `session/load`. Supports `session/close`, `session/delete`, and `session/fork` for full session lifecycle control. |
| **Chat Webview Architecture** | Single monolithic 87KB TypeScript file embedding raw HTML/CSS/JS strings. | **Preact Component Subsystem** | Declarative TSX components with hooks-based state management, bundled via Webpack with `preact/compat` alias. ~3KB runtime overhead. |
| **Context Window Metering** | Not implemented. | **`ContextProgress` Bar** | A 3-segment capacity bar (used / reserved / available) derived from ACP `usage_update` events, color-shifting to amber/red at high utilization. Token counts displayed on hover. Cost tracking omitted by design. |
| **Multimodal Inputs** | Text only. | **Image Paste & Drag-and-Drop** | `useImageAttachments` hook captures clipboard paste and drag-and-drop events, encoding images as `ContentBlock::Image` base64 data URIs and displaying thumbnail chips in the composer. |
| **Structured Elicitation** | Not implemented. | **`QuestionDock` Elicitation UI** | Handles `elicitation/create` with `mode: "form"` (single/multi-choice and text inputs) and `mode: "url"` (browser open with consent prompt), all rendered inline above the composer. |

---

## 3. Subsystem Architecture

### 3.1. Process Supervisor & Connection Manager
- Resolves the `fox` binary path using a configurable precedence chain:
  1. Setting `fox.executablePath` (if explicitly provided).
  2. Workspace relative path (`./bin/fox` or `./node_modules/.bin/fox`).
  3. System `PATH` (`which fox` / `where fox.exe`).
- Spawns `fox acp --cwd <workspaceRoot>` using Node.js `child_process.spawn`.
- Connects standard I/O via `@agentclientprotocol/sdk` using Web Streams converted from Node streams (`Readable.toWeb(process.stdout)` and `Writable.toWeb(process.stdin)`).
- Wraps streams with a bi-directional traffic interceptor that logs formatted JSON-RPC messages to a dedicated **Fox Protocol Traffic** output channel.

### 3.2. Session Management & Notification Dispatcher
- Manages the full ACP session lifecycle: `newSession`, `loadSession`, `listSessions`, `cancel`, `closeSession`, `deleteSession`, `forkSession`.
- Supports `additionalDirectories` in `newSession`/`loadSession` for multi-root workspaces.
- Synchronizes with Fox CLI's session capabilities:
  - Supports dynamic **Session Config Options** (model selection, reasoning effort, temperature, `thought_level`).
  - Supports agent **Modes** (e.g., `code`, `architect`, `ask`).
  - Supports agent **Available Commands** (slash commands like `/help`, `/compact`, `/clear`).
- Dispatches streaming updates (`sessionUpdate`) to the webview:
  - Text generation deltas (`agent_message_delta`).
  - Reasoning/thought tokens (`thought_message_delta`).
  - Tool execution lifecycles (`tool_call_start`, `tool_call_update`, `tool_call_complete`).
  - Plan/checklist modifications (`plan_update`).
  - Context window metering (`usage_update` → `used` and `size` token counts).
  - Advisory notices (`notice` → `NoticeBanner` UI).
  - Agent-owned terminal streams (`terminal_update`, `terminal_output_chunk` → `TerminalStreamView`).
  - Turn state transitions (`state_update` → `"running"`, `"requires_action"`, `"idle"`).

### 3.3. Client Capabilities & Safety Handlers
- **File System**:
  - `fs/readTextFile`: Inspects `vscode.workspace.textDocuments` first to return unsaved dirty editor contents, falling back to disk read.
  - `fs/writeTextFile`: Can write directly to disk or stage changes into the Diff Review subsystem.
  - > **ACP v2 Note:** The agent may own its execution environment and surface tools via MCP instead. See §3.5 and [Spec 07 §4](./07-mcp-forwarding-and-configuration.md) for MCP-over-ACP tunneling.
- **Terminal Execution**:
  - `terminal/create`, `terminal/output`, `terminal/waitForExit`, `terminal/kill`, `terminal/release`.
  - Spawns underlying child processes for stdout/stderr capture while simultaneously mirroring output into a VSCode `Pseudoterminal` for developer visibility.
- **Permission Escalation**:
  - Bridges agent permission requests (`connection.requestPermission`) to native VSCode QuickPicks and in-chat confirmation cards.
  - Configurable safety tiers: `ask` (always prompt), `allowWorkspaceRead` (auto-allow read-only operations), `allowAll` (bypass prompts).
- **Elicitation**:
  - Handles `elicitation/create` requests from the agent: renders structured `QuestionDock` forms (single/multi-choice, text inputs) or triggers browser URL opens with explicit user consent.
- **Inline Completion (NES)**:
  - `InlineCompletionService` implements VSCode's `InlineCompletionItemProvider`, communicating with ACP `nes/*` endpoints to deliver ghost-text next-edit suggestions directly in the code editor.

### 3.4. Diff Review & Editor Integration
- Proposed edits can be previewed in VSCode's native side-by-side diff editor (`vscode.diff`).
- Virtual Document Provider registered under the `fox-diff` URI scheme renders original vs. proposed file versions without dirtying the disk prematurely.
- Interactive Accept / Reject buttons in the editor title bar and webview card commit the staged changes or discard them.

### 3.5. MCP Forwarding Subsystem
- Scans for MCP configurations in `.fox/mcp.json`, `.vscode/mcp.json`, and VSCode user settings (`fox.mcpServers`).
- Formats MCP server definitions (`name`, `command`, `args`, `env`, `url`) into the ACP `newSession` / `loadSession` payload.
- Allows Fox CLI to load external MCP tools without requiring separate manual configuration on both sides.

### 3.6. In-Process MCP-over-ACP Server
- Fox ACP Client can host an **in-process MCP server** registered with transport `type: "acp"`, tunneling over the existing stdio pipe.
- Exposes VSCode-native information to the agent without shell processes: workspace diagnostics (`vscode.languages.getDiagnostics`), workspace symbol search, open file contents, and `git status`.
- See [Spec 07 §4](./07-mcp-forwarding-and-configuration.md) for the full specification.

---

## 4. Target Package Directory Layout (`fox/fox-acp-client/`)

```
fox/fox-acp-client/
├── package.json                 # Extension manifest, contributes, & dependencies
├── tsconfig.json                # TypeScript configuration targeting Node18/ES2022
├── webpack.config.js            # Dual bundle: extension host + webview assets
├── resources/
│   ├── icon.svg                 # Fox activity bar icon
│   └── icons/                   # Status and toolbar icons
├── src/
│   ├── extension.ts             # Extension activation entrypoint & command wiring
│   │
│   ├── core/                    # Core ACP Client & Connection Management
│   │   ├── AcpClientImpl.ts     # Implementation of ACP Client interface
│   │   ├── ProcessSupervisor.ts # Process spawning, PATH discovery & health monitor
│   │   ├── ConnectionManager.ts # Stdio streams, ndJsonStream, & traffic tapping
│   │   ├── SessionManager.ts    # Session state machine, commands, & config options
│   │   └── HistoryStore.ts      # WorkspaceState cache & ACP session retrieval
│   │
│   ├── handlers/                # Capability Request Handlers
│   │   ├── FileSystemHandler.ts # Unsaved buffer read & file writes
│   │   ├── TerminalHandler.ts   # PTY terminal manager & process exit tracker
│   │   ├── PermissionHandler.ts # Permission prompts & safety policies
│   │   └── SessionUpdateRouter.ts# Notification event emitter & demuxer
│   │
│   ├── diff/                    # Diff Review Subsystem
│   │   ├── DiffManager.ts       # Manages staged modifications & diff editor
│   │   └── VirtualDocProvider.ts# 'fox-diff://' TextDocumentContentProvider
│   │
│   ├── mcp/                     # MCP Forwarding Subsystem
│   │   ├── McpConfigLoader.ts   # Reads .fox/mcp.json and VSCode settings
│   │   └── McpTypes.ts          # Schema validation for MCP server definitions
│   │
│   ├── ui/                      # VSCode Tree Views & Status Bar
│   │   ├── SessionTreeProvider.ts# Agents and session history tree
│   │   ├── StatusBarManager.ts  # Active model, state, and quick-connect indicator
│   │   └── ChatWebviewProvider.ts# Bridge between extension host and webview panel
│   │
│   ├── config/                  # Configuration & Executable Discovery
│   │   ├── FoxConfig.ts         # VSCode settings accessor & validator
│   │   └── BinaryResolver.ts    # Locates fox binary on PATH or in workspace
│   │
│   └── utils/                   # Logging & Diagnostics
│       ├── Logger.ts            # Output channels (Fox Log, Fox Traffic)
│       └── StreamUtils.ts       # Web Streams <-> Node Streams utilities
│
├── shared/                      # Shared Types (imported by both src/ and webview/)
│   └── types.ts                 # WebviewMessage, ExtensionMessage, SessionInfo
│
└── webview/                     # Preact Webview Frontend (Bundled separately)
    ├── index.html               # HTML shell with CSP, nonce, and <div id="app">
    ├── tsconfig.json            # JSX: react-jsx, jsxImportSource: preact
    ├── src/
    │   ├── main.tsx             # Preact application root (render <App />)
    │   ├── App.tsx              # Top-level layout (Header, Toolbar, Messages, Composer)
    │   ├── hooks/
    │   │   ├── useSession.ts    # Reactive session state from postMessage bridge
    │   │   └── useStreaming.ts  # Streaming delta buffer accumulator
    │   ├── components/
    │   │   ├── MarkdownContent.tsx  # Streaming marked.js renderer with highlight.js
    │   │   ├── ThinkingBlock.tsx    # Collapsible <think> reasoning with timer
    │   │   ├── ToolCard.tsx         # Tool call lifecycle card (pending/running/done)
    │   │   ├── PlanWidget.tsx       # Interactive plan/checklist from plan_update
    │   │   ├── PermissionCard.tsx   # In-chat approval buttons
    │   │   ├── Composer.tsx         # Input textarea, submit, cancel, file chips
    │   │   ├── Toolbar.tsx          # Mode, model, and config option dropdowns
    │   │   └── AutocompletePopup.tsx # Slash command autocomplete
    │   └── styles/
    │       ├── main.css         # VSCode theme-aware CSS variables & layout
    │       ├── chat.css         # Message cards, bubbles, and animations
    │       └── tools.css        # Collapsible cards, diff previews, terminal blocks
```

---

## 5. Technology Stack & Key Dependencies

| Dependency | Version / Target | Role & Justification |
|---|---|---|
| **VSCode Engine** | `^1.85.0` | Minimum supported VSCode version (ensures broad compatibility with modern editor releases). |
| **`@agentclientprotocol/sdk`** | `^0.21.1` | Official ACP TypeScript SDK providing `ClientSideConnection`, `ndJsonStream`, `PROTOCOL_VERSION`, protocol interfaces, and types. |
| **`preact`** | `^10.24.0` | Lightweight (~3KB) React-compatible UI framework for the chat webview. Provides JSX/TSX components, hooks-based state management, and efficient virtual DOM diffing for streaming updates. |
| **`marked`** | `^15.0.0` | High-performance, compliant Markdown parser for rendering assistant responses in the Preact chat webview. |
| **`highlight.js`** | `^11.9.0` | Syntax highlighting for code blocks inside rendered Markdown. |
| **`@xterm/xterm`** | `^5.5.0` | Terminal emulator for rendering agent-owned terminal streams (`terminal_update`, `terminal_output_chunk`) in the `TerminalStreamView` webview panel. Paired with `@xterm/addon-fit` for responsive resizing. |
| **Webpack** | `^5.95.0` | Bundler for producing clean, single-file artifacts (`dist/extension.js` and `dist/webview.js`). Configured with `preact/compat` alias for React API compatibility. |
| **TypeScript** | `^5.5.0` | Strict type checking, Node18 module resolution, ES2022 output, and JSX support (`jsxImportSource: "preact"`). |
| **Pruned Dependencies** | *(Removed)* | `@vscode/extension-telemetry` (pruned for privacy); remote registry fetchers (pruned for offline operation); `react` / `react-dom` (replaced by Preact). |
