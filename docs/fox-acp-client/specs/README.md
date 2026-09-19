# Fox ACP Client Specifications

> Design specifications for **Fox ACP Client** (`fox/fox-acp-client/`) — a privacy-preserving, local-first VSCode extension and ACP client paired with **Fox Code CLI**.

---

## 1. Context & Motivation

The **Agent Client Protocol (ACP)** is an open, standardized communication protocol modeled on the Language Server Protocol (LSP). It establishes a clean separation of concerns between code editors (**clients**) and autonomous AI coding agents (**servers**) over standard JSON-RPC 2.0 communication channels.

The Fox system architecture consists of two primary components:
1. **Fox Code CLI** (`fox/fox-code-cli/`): An ACP-compatible agent server, CLI, and headless daemon derived from Kilo Code CLI (`kilocode`), engineered for local-first execution.
2. **Fox ACP Client** (`fox/fox-acp-client/`): A VSCode extension that acts as the primary user interface and ACP client, derived from the open-source reference implementation [`vscode-acp`](https://github.com/formulahendry/vscode-acp).

While `vscode-acp` demonstrated the viability of connecting VSCode to ACP agents, it was built as a generic multi-agent client heavily geared toward remote cloud CLIs (GitHub Copilot, Claude Code, Gemini CLI), external telemetry, and remote CDN registries.

**Fox ACP Client is tailored for the Fox ecosystem and local-first AI development:**
- **Native Fox Integration**: First-class discovery, lifecycle supervision, and configuration for the local `fox` binary (`fox acp`), while retaining backwards compatibility with any standard ACP agent.
- **Zero Cloud & Zero Telemetry**: Complete excision of third-party telemetry, remote registry pings, and cloud account dependencies. Fox ACP Client functions completely air-gapped and offline.
- **Dynamic Workspace MCP Forwarding**: Discovers workspace MCP configurations (`.fox/mcp.json`) and VSCode settings, automatically mounting them into Fox CLI sessions via ACP session initialization.
- **Interactive Diff Review**: Elevates code modification safety by rendering side-by-side diff previews via `vscode.diff` before applying changes to disk.
- **Local Model UX Enhancements**: Specialized UI handling for streaming chain-of-thought (`<think>` blocks), local token metrics, and real-time execution checklists (`todo` updates).

---

## 2. Specification Document Index

| Spec Document | Title | Scope & Description |
|---|---|---|
| [**01-architecture-overview.md**](./01-architecture-overview.md) | **Architecture Overview & Upstream Delta** | High-level architecture, component topology, upstream comparison with `vscode-acp` (kept vs. pruned vs. adapted), target directory structure, and technology stack. Includes new subsystems: `UsageTracker`, `ElicitationHandler`, `InlineCompletionService`, and `InProcessMcpServer`. |
| [**02-agent-process-and-connection.md**](./02-agent-process-and-connection.md) | **Agent Process & Connection Subsystem** | Process supervisor, `fox` binary auto-detection, stdio transport, JSON-RPC 2.0 streaming via `@agentclientprotocol/sdk`, traffic logging, error recovery, elicitation capability advertisement, and `$/cancel_request` handling. |
| [**03-session-management-and-history.md**](./03-session-management-and-history.md) | **Session Management & History** | Full ACP session lifecycle — `newSession`, `loadSession`, `listSessions`, `cancel`, **`closeSession`**, **`deleteSession`**, and **`forkSession`**. Notification routing (`sessionUpdate`) including **`usage_update`** (context metering), **`notice`** (advisory banners), **`terminal_update`/`terminal_output_chunk`** (agent terminal streaming), and **`state_update`** (ACP v2 turn tracking). |
| [**04-client-capabilities-and-security.md**](./04-client-capabilities-and-security.md) | **Client Capabilities & Security** | ACP client capabilities: buffer-aware filesystem access, terminal virtualization, permission escalation policies, ACP v2 model note, and **`elicitation/create` handler** (`form` and `url` modes with `QuestionDock` rendering). |
| [**05-chat-webview-and-ui.md**](./05-chat-webview-and-ui.md) | **Chat Webview & UI Subsystem** | Preact webview sidebar architecture. Core components: `MarkdownContent`, `ThinkingBlock`, `ToolCard`, `PlanWidget`, `PermissionCard`, `Composer`, `AutocompletePopup`. **New components:** `ContextProgress` (token capacity bar), `QuestionDock` (elicitation forms), `NoticeBanner` (advisory toasts), `TerminalStreamView` (xterm.js agent terminal), and `ThoughtEffortPicker`. **New hook:** `useImageAttachments` (clipboard paste & drag-drop of images). Updated `postMessage` protocol with all new message types. |
| [**06-diff-viewer-and-editor-integration.md**](./06-diff-viewer-and-editor-integration.md) | **Diff Viewer & Editor Integration** | Interactive file review workflow, virtual document provider (`fox-diff://`), side-by-side diff comparisons, editor decorations, gutter indicators, and **§7 Next Edit Suggestions (NES)** — `InlineCompletionService` implementing `vscode.InlineCompletionItemProvider` for ghost-text predictions via ACP `nes/*` endpoints. |
| [**07-mcp-forwarding-and-configuration.md**](./07-mcp-forwarding-and-configuration.md) | **MCP Forwarding & Configuration** | Workspace MCP server discovery (`.fox/mcp.json`), dynamic session injection, **§4 MCP-over-ACP In-Process Server** (exposes VSCode diagnostics, symbol search, open files, and Git status via `transport: { type: "acp" }`), complete VSCode settings schema (including `fox.nes.*`), and offline guarantees. |

---

## 3. Guiding Principles

1. **Local-First & Offline**: Never make outbound network calls to cloud registries or telemetry services. The extension functions fully offline with local model servers.
2. **First-Class Fox Experience**: The extension works out-of-the-box when opening any workspace containing or referencing the `fox` CLI, with zero manual JSON configuration required for standard setups.
3. **Open Protocol Integrity**: Maintain strict compliance with standard **Agent Client Protocol (ACP)** specifications (as defined by the `@agentclientprotocol/sdk` v0.21.x series), ensuring any ACP-compliant agent can connect interchangeably.
4. **Safety & Transparency**: Every action proposed by the agent (shell execution, file writes, edits) is surfaced with clear visual diffs and configurable permission barriers.
5. **Lightweight & Responsive**: Native VSCode UI integration, efficient webview message serialization, and minimal memory footprint.
6. **Context Awareness, Not Cost Awareness**: Context window consumption (`usage_update` token counts) is prominently displayed to help developers understand model limitations. Cost tracking is intentionally omitted — Fox is designed for local models where cost is not a concern.
7. **Progressive Disclosure**: Advanced features (NES inline completions, session forking, elicitation forms, agent terminal views) are surfaced when needed without cluttering the default interface.
