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
- **Language & Runtime**: Bun (>=1.1) with Effect TS and native ESM modules.
- **Protocol Server**: Implements ACP JSON-RPC 2.0 over `stdio` and Unix domain sockets (`fox daemon`).
- **Model Integration**: Unified local model client targeting local endpoints (defaulting to `http://localhost:8000/v1` via `openai-proxy` or Ollama/vLLM) with Model Capability Tiering (Tiers S, A, B, C, D).
- **Tooling**: Built-in developer tools (`bash`, `read`, `edit`, `write`, `rewrite_file`, `grep`, `glob`, `todowrite`, `task`, `skill`) with Lossless Token Compression (LLTC) and tier-based tool filtering.
- **Persistence**: SQLite database via `@foxcode/effect-drizzle-sqlite` storing sessions, message turns, tool calls, and tasks.
- **Canonical Architecture & Specs**: See [`fox-code-cli/docs/README.md`](../fox-code-cli/docs/README.md).
- **Master Roadmap & Blueprints**: See [`fox-code-cli/docs/future/2026-09-21T06-12_plan-competitive-features-roadmap.md`](../fox-code-cli/docs/future/2026-09-21T06-12_plan-competitive-features-roadmap.md).
- **Pre-Fork Historical Specs (Archived)**: See [`docs/archived/fox-cli/`](./archived/fox-cli/).

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
| **Model Backends** | 20+ cloud providers (Bedrock, Vertex, Anthropic, Azure, Groq, Mistral, etc.) | **Single local OpenAI-compatible endpoint** (`http://localhost:8000/v1`, Ollama, vLLM) with Model Capability Tiers |
| **Cloud Auth & Billing** | AWS STS, GCP ADC, OAuth, Kilo accounts, credits gateway | **Pruned completely** |
| **Model Registry** | Dynamic remote fetching from `models.dev` | **Pruned**; models configured locally or queried via `/v1/models` |
| **ACP Protocol** | Supported via `@agentclientprotocol/sdk` | **Retained & Refined** as the primary editor communication channel |
| **MCP Client** | Supported via `@modelcontextprotocol/sdk` | **Retained & Streamlined** for tool extensibility |
| **REST Server & Daemon** | Heavy Effect-TS HTTP server with complex routes | **Retained as lightweight `fox daemon` / `fox serve`** |
| **Built-in Tools** | Core file tools, shell, plus web scrapers and PR tools | **Retained core developer tools**; added Lossless Token Compression, tier-filtering, `rewrite_file` |
| **Architecture** | Monorepo across 35 packages with deep Effect-TS coupling | **Streamlined Bun + Effect TS monorepo** in `fox/fox-code-cli/` |

---

## 4. Reference Documents

### Fox Code CLI (Active Documentation)
- [Fox CLI Documentation Hub (`fox-code-cli/docs/README.md`)](../fox-code-cli/docs/README.md)
- [Master Roadmap & Phased Milestones](../fox-code-cli/docs/future/2026-09-21T06-12_plan-competitive-features-roadmap.md)
- [Daemon Architecture & IPC Spec](../fox-code-cli/docs/2026-09-22T15-16_daemon-architecture.md)
- [Master Benchmark Report (Challenge Ladder)](../fox-code-cli/docs/2026-09-22T15-54_fox-challenge-ladder-report.md)
- [Pre-Fork Historical Specs (Archived)](./archived/fox-cli/specs/README.md)

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
