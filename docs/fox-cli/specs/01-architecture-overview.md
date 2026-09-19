# Spec 01: Architecture Overview & Upstream Delta

> High-level system architecture, component breakdown, upstream analysis of Kilo Code CLI, and structural decisions for Fox CLI.

---

## 1. System Context & Topology

Fox CLI is an autonomous coding agent designed to run locally on a developer's workstation. It can be operated in three modes:
1. **ACP Server (`fox acp`)**: Headless agent server spawned over `stdio` by an ACP client (e.g., Fox VSCode Extension, Zed).
2. **Interactive / One-Shot CLI (`fox run`)**: Command-line interface for direct terminal usage, automation scripts, and piped inputs.
3. **Headless REST API (`fox serve`)**: HTTP/SSE daemon providing remote or programmatic control of sessions and tool execution.

### High-Level Architecture Diagram

```
                             ┌──────────────────────────────────────┐
                             │        External Consumers            │
                             │  ┌───────────────┐ ┌───────────────┐ │
                             │  │ VSCode / Zed  │ │ CLI / Script  │ │
                             │  │ (ACP Client)  │ │ (Terminal)    │ │
                             │  └───────┬───────┘ └───────┬───────┘ │
                             └──────────┼─────────────────┼─────────┘
                                        │ stdio           │ stdin/stdout
                                        │ (JSON-RPC 2.0)  │
                                        ▼                 ▼
┌───────────────────────────────────────────────────────────────────────────┐
│                              FOX CODE CLI                                 │
│                                                                           │
│  ┌────────────────────────┐ ┌───────────────────┐ ┌────────────────────┐  │
│  │   ACP Server Adapter   │ │   CLI Subsystem   │ │  REST API Server   │  │
│  │ (AgentSideConnection)  │ │ (Commands & Run)  │ │  (HTTP / SSE)      │  │
│  └───────────┬────────────┘ └─────────┬─────────┘ └─────────┬──────────┘  │
│              │                        │                     │             │
│              └──────────────────┐     │     ┌───────────────┘             │
│                                 ▼     ▼     ▼                             │
│                     ┌───────────────────────────────┐                     │
│                     │       Core Agent Engine       │                     │
│                     │  - Session Orchestrator       │                     │
│                     │  - ReAct Execution Loop       │                     │
│                     │  - Context Window Compaction  │                     │
│                     │  - Permission Evaluator       │                     │
│                     └───────┬───────────────┬───────┘                     │
│                             │               │                             │
│               ┌─────────────┴─────┐   ┌─────┴─────────────┐               │
│               ▼                   │   │                   ▼               │
│  ┌──────────────────────────┐     │   │     ┌──────────────────────────┐  │
│  │  Local Model Subsystem   │     │   │     │   Tool Execution Engine  │  │
│  │  - OpenAI-Compatible API │     │   │     │  - Built-in Filesystem   │  │
│  │  - Streaming Parser      │     │   │     │  - Subprocess / Shell    │  │
│  │  - Local Token Estimator │     │   │     │  - Todo & Planning       │  │
│  └────────────┬─────────────┘     │   │     └─────────────┬────────────┘  │
│               │                   │   │                   │               │
│               │                   ▼   ▼                   │               │
│               │         ┌───────────────────────┐         │               │
│               │         │    Persistence Engine │         │               │
│               │         │  - SQLite Database    │         │               │
│               │         │  - Session & Parts    │         │               │
│               │         └───────────────────────┘         │               │
│               │                                           │               │
│               │                                           ▼               │
│               │                             ┌──────────────────────────┐  │
│               │                             │    MCP Client Manager    │  │
│               │                             │  - Transports: stdio/SSE │  │
│               │                             │  - Dynamic ACP Servers   │  │
│               │                             │  - Tool Registry Bridge  │  │
│               │                             └─────────────┬────────────┘  │
└───────────────┼───────────────────────────────────────────┼───────────────┘
                │ HTTP (localhost)                          │ stdio / SSE
                ▼                                           ▼
┌────────────────────────────────┐         ┌────────────────────────────────┐
│   Local Model Server (Proxy)   │         │    External MCP Servers        │
│  - Dev: openai-proxy (:8000)   │         │  - Local tools (e.g. git, db)  │
│  - Prod: Ollama / vLLM / etc.  │         │  - Injected by ACP Client      │
└────────────────────────────────┘         └────────────────────────────────┘
```

---

## 2. Upstream Analysis: Kilo Code CLI vs. Fox CLI

Kilo Code CLI (`packages/opencode` in the `Kilo-Org/kilocode` repository) was analyzed in depth. Below is the itemized evaluation of what Fox CLI **retains**, **prunes**, and **adapts**.

### Upstream Delta Matrix

| Subsystem / Feature | Status in Kilo CLI | Decision for Fox CLI | Rationale |
|---|---|---|---|
| **ACP Server (`kilo acp`)** | Full support via `@agentclientprotocol/sdk` (JSON-RPC over stdio). | **Retained & Refined** | Core requirement for integrating with VSCode extension (`fox/fox-acp-client`). |
| **MCP Client Subsystem** | Full client (`@modelcontextprotocol/sdk`) supporting `stdio`, `sse`, and `streamableHttp`. | **Retained & Streamlined** | Required for extensibility. Allows users and ACP clients to inject specialized tools dynamically. |
| **Model Providers** | 20+ cloud providers (Bedrock, Vertex, Anthropic, Azure, OpenAI, Groq, Mistral, etc.). | **Pruned (Replaced with Single Local Provider)** | Fox is strictly local-first and offline. Replaced with single OpenAI-compatible provider targeting local endpoints. |
| **Cloud Authentication** | AWS STS, GCP ADC, OAuth token refresh, GitLab token exchange. | **Pruned** | Completely unnecessary for local models (`localhost:8000` or Ollama). |
| **Model Registry Sync** | Dynamic fetch from `models.dev` & Kilo remote endpoints. | **Pruned** | No internet calls. Local models are configured via config/env or queried via `/v1/models`. |
| **REST API Server (`kilo serve`)** | Effect-based HTTP API with WebSocket and OpenAPI export. | **Retained & Simplified** | Provides headless daemon mode and clean decoupled architecture. Re-architected with minimal routes. |
| **Agent Execution Loop** | Multi-step ReAct loop with context compaction and streaming. | **Retained** | The core reasoning loop is proven and effective. Simplified to remove telemetry and cloud token quotas. |
| **Built-in Tools** | `read`, `write`, `edit`, `patch`, `shell`, `glob`, `grep`, `task`, `todo`. | **Retained (core set); `patch` and `task` dropped** | `patch` is redundant with `edit_file` surgical replacements. `task` is subsumed by `todo` which provides richer status tracking. Fox ships `read_file`, `write_file`, `edit_file`, `shell`, `grep_search`, `glob_find`, `todo`. |
| **Web Tools** | `websearch`, `webfetch`, `mcp-websearch`, `repo_clone`. | **Pruned / Optional Minimal `webfetch`** | Fox operates offline. Cloud search is omitted; basic HTTP `webfetch` can be enabled only for local network URLs. |
| **Kilo Cloud Account & SaaS** | Kilo user accounts, cloud credits, gateway proxy, cloud telemetry. | **Pruned** | Fox has no cloud accounts, billing, or phone-home telemetry. |
| **Interactive Terminal UI (TUI)** | Complex Solid/OpenTUI terminal interface (`@opentui`). | **Deferred / Simple CLI First** | Phase 1 focuses on ACP server, `fox run` CLI, and `fox serve` REST API. Complex TUI is out of scope for initial core. |
| **Persistence / Storage** | SQLite via Drizzle ORM storing sessions, messages, and parts. | **Retained & Streamlined** | Clean relational storage for session state, replayability, and ACP session resume. |

---

## 3. Subsystem Architecture

### 3.1. Local Model Subsystem
Instead of loading dozens of provider SDKs dynamically, Fox CLI implements a unified **Local Model Provider**:
- Direct client targeting OpenAI-compatible `chat/completions` APIs.
- Built-in support for streaming Server-Sent Events (SSE) with standard token chunking and tool call deltas.
- Default connection to `http://localhost:8000/v1` (the `openai-proxy` development environment or standard local LLM servers like Ollama, vLLM, LM Studio, and llama.cpp).
- Configurable via environment variables (`OPENAI_BASE_URL`, `OPENAI_API_KEY`, `FOX_MODEL`) and configuration files.

### 3.2. ACP Server Subsystem
- Compliant with **Agent Client Protocol 0.21+**.
- Communicates over process `stdin` / `stdout` using newline-delimited JSON-RPC 2.0 streams.
- Translates ACP protocol requests (`initialize`, `newSession`, `prompt`, `cancel`, `loadSession`, `setSessionMode`) into core agent actions.
- Bridges permission questions back to the ACP client via `connection.requestPermission` ("allow_once", "allow_always", "reject").
- Ingests client-provided `mcpServers` dynamically and registers them into the active session's MCP registry.

### 3.3. MCP Client Subsystem
- Implements MCP client capabilities using `@modelcontextprotocol/sdk`.
- Supports three transports: `stdio` (local subprocesses), `sse` (Server-Sent Events), and `streamableHttp`.
- Two configuration pathways:
  1. **Static / Workspace configuration**: Loaded from `.fox/mcp.json` or `~/.config/fox/mcp.json`.
  2. **Dynamic session configuration**: Passed per-session by ACP clients during `newSession` / `loadSession`.
- Exposes discovered tools into the agent's prompt catalog and executes calls through the MCP transport.

### 3.4. Core Agent Engine
- Executes an iterative ReAct cycle: `User Prompt` ➔ `Context Assembly` ➔ `LLM Generation` ➔ `Tool Call Dispatch` ➔ `Output Parsing` ➔ `Loop Evaluation`.
- Manages conversational history with structured parts (`TextPart`, `ToolCallPart`, `ToolResultPart`).
- Performs local context compaction (summarizing older turns when context window limits are reached).
- Enforces strict safety permissions before executing any destructive tool (shell commands, file writes/edits).

### 3.5. Headless REST API Server
- Lightweight HTTP server (`fox serve`) listening on `127.0.0.1:4096` (configurable).
- Exposes JSON endpoints for session creation, state inspection, tool execution, and MCP configuration.
- Supports Server-Sent Events (SSE) on `/v1/sessions/:id/events` for real-time streaming of assistant messages and tool progress.

---

## 4. Package Directory Layout (`fox/fox-code-cli/`)

The Fox CLI codebase is organized into a clean, modular TypeScript project:

```
fox/fox-code-cli/
├── bin/
│   └── fox.js                   # CLI executable entrypoint
├── package.json                 # Minimal dependencies (no cloud SDKs)
├── tsconfig.json
├── src/
│   ├── index.ts                 # CLI parser & command router (Yargs / Commander)
│   │
│   ├── acp/                     # Agent Client Protocol Subsystem
│   │   ├── server.ts            # ACP stdio transport & AgentSideConnection setup
│   │   ├── handler.ts           # Protocol request handlers (initialize, prompt, etc.)
│   │   ├── permissions.ts       # Bridge between internal permissions & ACP client
│   │   └── mapper.ts            # Protocol data mapping (ACP <-> Internal Schema)
│   │
│   ├── mcp/                     # Model Context Protocol Subsystem
│   │   ├── client-manager.ts    # MCP client lifecycle & transport pool
│   │   ├── dynamic-registry.ts  # Session-specific ACP-injected MCP servers
│   │   └── config.ts            # Local mcp.json loader & validator
│   │
│   ├── model/                   # Local Model Subsystem
│   │   ├── provider.ts          # OpenAI-compatible HTTP/SSE client
│   │   ├── tokenizer.ts         # Fast token estimation for local models
│   │   └── types.ts             # Model config, messages, and streaming events
│   │
│   ├── agent/                   # Core Agent Engine
│   │   ├── orchestrator.ts      # Main agent reasoning loop (prompt -> tool -> loop)
│   │   ├── context.ts           # Prompt context builder & system prompt
│   │   ├── compaction.ts        # History trimming and summarization
│   │   └── permissions.ts       # Security policy & tool approval rules
│   │
│   ├── tools/                   # Built-in Tool Implementations
│   │   ├── registry.ts          # Unified tool registry (built-in + MCP)
│   │   ├── file-read.ts         # Read file contents with line slices
│   │   ├── file-write.ts        # Write full file contents
│   │   ├── file-edit.ts         # Surgical search-and-replace / diff edits
│   │   ├── shell.ts             # Subprocess execution with timeout & PTY
│   │   ├── grep.ts              # Fast regex/text code search
│   │   ├── glob.ts              # File tree discovery
│   │   └── todo.ts              # Task list tracker
│   │
│   ├── server/                  # Headless REST API Server
│   │   ├── http-server.ts       # HTTP listener & router
│   │   ├── routes/              # REST routes (sessions, prompt, mcp, health)
│   │   └── sse.ts               # SSE event broadcasting
│   │
│   ├── storage/                 # Persistence Layer
│   │   ├── db.ts                # SQLite database connection & migrations
│   │   ├── schema.ts            # Tables: sessions, messages, parts, config
│   │   └── repository.ts        # Queries & transactions
│   │
│   └── config/                  # Configuration Management
│       ├── loader.ts            # Merges env vars, global config, workspace config
│       └── schema.ts            # Zod validation schema for Fox configuration
└── test/                        # Unit and integration tests
    ├── acp/
    ├── mcp/
    ├── model/
    └── agent/
```

---

## 5. Technology Stack & Key Dependencies

| Component | Upstream Choice (Kilo) | Fox CLI Decision | Justification |
|---|---|---|---|
| **Runtime** | Bun + Node.js dual runtime with Effect-TS | **Node.js (>=20) & TypeScript** | Maximizes ecosystem compatibility and simplifies packaging across developer environments without requiring specialized native runtimes. |
| **Concurrency / Architecture** | Heavy Effect-TS framework across 35 packages | **Clean Modular TypeScript / Async-Await** | Dramatically lowers architectural complexity and build overhead while maintaining strict error handling and typing. |
| **ACP SDK** | `@agentclientprotocol/sdk` (v0.21) | `@agentclientprotocol/sdk` (v0.21+) | Official standard implementation of Agent Client Protocol. |
| **MCP SDK** | `@modelcontextprotocol/sdk` (v1.2+) | `@modelcontextprotocol/sdk` (v1.2+) | Official standard implementation of Model Context Protocol. |
| **LLM Client** | `@ai-sdk/*` (20+ providers) | **`@ai-sdk/openai-compatible` or standard OpenAI client** | Lightweight, rock-solid support for all local OpenAI-compatible backends. |
| **Embedded Database** | Drizzle ORM + Bun SQLite / Node SQLite | **SQLite (via `better-sqlite3` or Drizzle SQLite)** | Reliable embedded transactional storage for sessions and conversation history. |
| **CLI Argument Parser** | Yargs / Custom Effect-Cmd | **Yargs or Commander** | Standard, battle-tested CLI framework with auto-help and tab completion. |
