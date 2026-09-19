# 🦊 Fox Architecture

> High-level architecture and design decisions for the Fox agent system: Fox Code CLI and Fox ACP Client.

---

## 1. System Vision & Core Tenets

Fox is an open-standard, privacy-preserving, local-first AI coding agent pairing:
1. **Fox Code CLI** (`fox/fox-code-cli/`): An ACP-compatible agent server, CLI, and headless daemon based on [Kilo Code CLI](https://github.com/Kilo-Org/kilocode).
2. **Fox ACP Client** (`fox/fox-acp-client/`): A VSCode extension that acts as an ACP client, based on [vscode-acp](https://github.com/formulahendry/vscode-acp).

```
┌─────────────────────────────────────────────────────────┐
│                    VSCode Workspace                     │
│  ┌───────────────────────────────────────────────────┐  │
│  │           Fox ACP Client (Extension)              │  │
│  │  - Chat UI & Webview Panel                        │  │
│  │  - Diff Viewer & File Decorations                 │  │
│  │  - Permission Modals (allow once, always, reject) │  │
│  │  - Workspace MCP Server Injector                  │  │
│  └─────────────────────────┬─────────────────────────┘  │
└────────────────────────────┼────────────────────────────┘
                             │ stdio (JSON-RPC 2.0 / ACP)
                             ▼
┌─────────────────────────────────────────────────────────┐
│              Fox Code CLI (Agent Process)               │
│  ┌───────────────────────────────────────────────────┐  │
│  │                ACP Server Adapter                 │  │
│  │              (@agentclientprotocol/sdk)           │  │
│  └─────────────────────────┬─────────────────────────┘  │
│                            │                            │
│                            ▼                            │
│  ┌───────────────────────────────────────────────────┐  │
│  │               Core Agent Engine                   │  │
│  │  - ReAct Execution Loop & Prompt Assembly         │  │
│  │  - Context Window Compactor & Doom Loop Guard     │  │
│  │  - Permission Rule Evaluator                      │  │
│  └───────────┬───────────────────────────┬───────────┘  │
│              │                           │              │
│              ▼                           ▼              │
│  ┌────────────────────────┐  ┌───────────────────────┐  │
│  │ Local Model Subsystem  │  │  Tool Execution Engine│  │
│  │ (OpenAI-Compatible /v1)│  │  - Built-in FS/Shell  │  │
│  │ - openai-proxy (:8000) │  │  - MCP Client Pool    │  │
│  │ - Ollama / vLLM        │  │    (stdio, sse)       │  │
│  └───────────┬────────────┘  └───────────┬───────────┘  │
└──────────────┼───────────────────────────┼──────────────┘
               │ HTTP                      │ stdio / SSE
               ▼                           ▼
┌───────────────────────────┐  ┌───────────────────────────┐
│ Local Model Inference     │  │ External MCP Servers      │
│ (Proxy, Ollama, vLLM)     │  │ (sqlite, git, custom)     │
└───────────────────────────┘  └───────────────────────────┘
```

### Core Tenets
1. **Local-First & Zero Cloud Lock-in**: Never depend on closed cloud APIs, cloud billing, or cloud telemetry.
2. **Open Standards**: Strict adherence to the **Agent Client Protocol (ACP)** for editor communication and the **Model Context Protocol (MCP)** for tool extensibility.
3. **Decoupled Packaging**: The CLI and VSCode extension are developed and versioned cleanly, communicating purely over the ACP protocol.

---

## 2. Package Architecture Decisions

### 2.1. Fox Code CLI (`fox/fox-code-cli/`)
- **Language & Runtime**: Modern Node.js (>=20) with TypeScript.
- **Protocol Server**: Implements ACP JSON-RPC 2.0 over `stdio` using `@agentclientprotocol/sdk`.
- **Model Integration**: Single, unified OpenAI-compatible client targeting local endpoints (defaulting to `http://localhost:8000/v1`).
- **Tooling**: Built-in developer tools (`read_file`, `write_file`, `edit_file`, `shell`, `grep_search`, `glob_find`, `todo`) plus dynamic tools loaded via `@modelcontextprotocol/sdk`.
- **Persistence**: SQLite database storing sessions, message turns, tool calls, and tasks.
- **Detailed Specifications**: See [`docs/fox-cli/specs/`](./fox-cli/specs/).
- **Implementation Plan**: See [`docs/fox-cli/plans/`](./fox-cli/plans/).

### 2.2. Fox ACP Client (`fox/fox-acp-client/`)
- **Role**: ACP Client running inside VSCode's extension host.
- **Process Management**: Automatically locates or prompts to install `fox`, spawns `fox acp --cwd <workspace>` as a child process, and pipes `stdin`/`stdout`.
- **User Interface**: VSCode Webview-based chat panel, streaming response renderer, interactive diff editor integration for file edits, and permission approval dialogs.
- **MCP Forwarding**: Gathers workspace-configured MCP servers and passes them to Fox CLI during session creation.
- **Detailed Specifications**: See [`docs/fox-acp-client/specs/`](./fox-acp-client/specs/).
- **Implementation Plan**: See [`docs/fox-acp-client/plans/`](./fox-acp-client/plans/).

---

## 3. Upstream Analysis Summary: What Fox Changed from Kilo

| Component | Kilo Code CLI Upstream | Fox Code CLI Decision |
|---|---|---|
| **Model Backends** | 20+ cloud providers (Bedrock, Vertex, Anthropic, Azure, Groq, Mistral, etc.) | **Single local OpenAI-compatible endpoint** (`http://localhost:8000/v1`, Ollama, vLLM) |
| **Cloud Auth & Billing** | AWS STS, GCP ADC, OAuth, Kilo accounts, credits gateway | **Pruned completely** |
| **Model Registry** | Dynamic remote fetching from `models.dev` | **Pruned**; models configured locally or queried via `/v1/models` |
| **ACP Protocol** | Supported via `@agentclientprotocol/sdk` | **Retained & Refined** as the primary editor communication channel |
| **MCP Client** | Supported via `@modelcontextprotocol/sdk` | **Retained & Streamlined** for tool extensibility |
| **REST Server** | Heavy Effect-TS HTTP server with complex routes | **Retained as lightweight `fox serve` daemon** |
| **Built-in Tools** | Core file tools, shell, plus web scrapers and PR tools | **Retained core developer tools**; pruned web scrapers and GitHub PR bloat |
| **Architecture** | Monorepo across 35 packages with deep Effect-TS coupling | **Modular TypeScript architecture** in `fox/fox-code-cli/` |

---

## 4. Reference Documents

### Fox Code CLI
- [Spec Index (docs/fox-cli/specs/README.md)](./fox-cli/specs/README.md)
- [Spec 01: Architecture Overview & Upstream Delta](./fox-cli/specs/01-architecture-overview.md)
- [Spec 02: Local Model Subsystem](./fox-cli/specs/02-local-model-subsystem.md)
- [Spec 03: ACP Server Specification](./fox-cli/specs/03-acp-server.md)
- [Spec 04: MCP Client Subsystem](./fox-cli/specs/04-mcp-client.md)
- [Spec 05: Agent Core & Tool Engine](./fox-cli/specs/05-agent-core-and-tools.md)
- [Spec 06: REST API & Headless Server](./fox-cli/specs/06-rest-api-server.md)
- [Spec 07: CLI Interface, Storage & Configuration](./fox-cli/specs/07-cli-interface-and-config.md)
- [CLI Implementation Plan](./fox-cli/plans/cli-implementation-plan.md)

### Fox ACP Client
- [Spec Index (docs/fox-acp-client/specs/README.md)](./fox-acp-client/specs/README.md)
- [Spec 01: Architecture Overview & Upstream Delta](./fox-acp-client/specs/01-architecture-overview.md)
- [Spec 02: Agent Process & Connection Subsystem](./fox-acp-client/specs/02-agent-process-and-connection.md)
- [Spec 03: Session Management & History](./fox-acp-client/specs/03-session-management-and-history.md)
- [Spec 04: Client Capabilities & Security](./fox-acp-client/specs/04-client-capabilities-and-security.md)
- [Spec 05: Chat Webview & UI Subsystem](./fox-acp-client/specs/05-chat-webview-and-ui.md)
- [Spec 06: Diff Viewer & Editor Integration](./fox-acp-client/specs/06-diff-viewer-and-editor-integration.md)
- [Spec 07: MCP Forwarding & Configuration](./fox-acp-client/specs/07-mcp-forwarding-and-configuration.md)
- [ACP Client Implementation Plan](./fox-acp-client/plans/acp-client-implementation-plan.md)
