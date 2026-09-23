# Fox CLI Implementation Plan & Task List (SUPERSEDED / OBSOLETE)

> [!CAUTION]
> ## ⚠️ OBSOLETE PRE-FORK DESIGN PLAN — DO NOT IMPLEMENT
> **This document is preserved for historical reference only.**  
> It was drafted prior to forking Kilo Code into `fox-code-cli/` and describes a speculative, greenfield Node.js/yargs implementation that was never adopted. Fox Code CLI is built on **Bun + Effect TS** with monorepo packages (`packages/core`, `packages/llm`, `packages/schema`, etc.).  
>  
> For the active, canonical architectural roadmap, milestones, and task ledgers, refer exclusively to:  
> 👉 **[`fox-code-cli/docs/future/2026-09-21T06-12_plan-competitive-features-roadmap.md`](../../../fox-code-cli/docs/future/2026-09-21T06-12_plan-competitive-features-roadmap.md)**

---

## 1. Roadmap Overview

```
Phase 1: Project Setup & Foundation
   │
   ▼
Phase 2: Local Model Subsystem (OpenAI-compatible HTTP/SSE)
   │
   ▼
Phase 3: Persistence & Storage (SQLite / Sessions)
   │
   ▼
Phase 4: Core Built-in Developer Tools (FS, Shell, Search, Todo)
   │
   ▼
Phase 5: MCP Client Subsystem (Stdio / SSE / Dynamic ACP)
   │
   ▼
Phase 6: Core Agent Reasoning Engine (ReAct Loop & Context Compactor)
   │
   ▼
Phase 7: ACP Server Adapter (Agent Client Protocol over stdio)
   │
   ▼
Phase 8: Headless REST API Server (`fox serve` & SSE)
   │
   ▼
Phase 9: CLI Interface & Subcommands (`fox run`, `fox models`, `fox mcp`)
   │
   ▼
Phase 10: End-to-End Verification (Proxy & VSCode Extension Integration)
```

---

## 2. Detailed Task Breakdown

### Phase 1: Project Setup & Package Skeleton (`fox/fox-code-cli/`)
- [ ] Initialize `fox/fox-code-cli/package.json` with minimal dependencies:
  - `@agentclientprotocol/sdk` (ACP server)
  - `@modelcontextprotocol/sdk` (MCP client)
  - `better-sqlite3` (or `sqlite3` / Drizzle for embedded state)
  - `yargs` or `commander` (CLI parsing)
  - `zod` (schema validation)
- [ ] Configure `tsconfig.json` for ES2022 / Node16 module resolution.
- [ ] Create executable wrapper in `fox/fox-code-cli/bin/fox.js` with `#!/usr/bin/env node`.
- [ ] Setup initial source directory structure (`src/acp`, `src/agent`, `src/mcp`, `src/model`, `src/server`, `src/storage`, `src/tools`, `src/config`).
- [ ] Implement `src/config/` loader:
  - Zod schema for all Fox configuration fields.
  - Hierarchical merge: CLI flags → env vars → workspace config → global config → built-in defaults.
  - Validates and surfaces clear errors for malformed config files.
  - *(Required early — model subsystem and storage both depend on it.)*

### Phase 2: Local Model Subsystem (`src/model/`)
*Spec: [02-local-model-subsystem.md](../specs/02-local-model-subsystem.md)*
- [ ] Implement `LocalModelClient`:
  - `POST /v1/chat/completions` HTTP client with keep-alive.
  - Support `stream: true` using Server-Sent Events (SSE).
- [ ] Build SSE stream parser:
  - Parse `delta.content` chunks.
  - Intercept and normalize reasoning tokens (`<think>` tags and `delta.reasoning_content`).
  - Accumulate streaming `delta.tool_calls` deltas into structured tool invocations.
- [ ] Implement token estimation:
  - Fast BPE tokenizer or heuristic character ratio for prompt size monitoring.
- [ ] Implement model discovery test (`checkModelConnection` querying `GET /v1/models`).

### Phase 3: Persistence & Storage (`src/storage/`)
*Spec: [07-cli-interface-and-config.md](../specs/07-cli-interface-and-config.md)*
- [ ] Implement SQLite database initialization:
  - Default database path: `~/.fox/fox.db` (auto-create directories).
  - Enable WAL mode (`PRAGMA journal_mode = WAL`) and foreign keys.
- [ ] Execute database migrations:
  - Table `sessions` (`id`, `cwd`, `title`, timestamps).
  - Table `messages` (`id`, `session_id`, `role`, timestamps).
  - Table `parts` (`id`, `message_id`, `type`, `content`, `metadata_json`).
  - Table `todos` (`id`, `session_id`, `text`, `status`, timestamps).
- [ ] Implement repository functions for session CRUD, history appending, and retrieval.

### Phase 4: Core Built-in Tools (`src/tools/`)
*Spec: [05-agent-core-and-tools.md](../specs/05-agent-core-and-tools.md)*
- [ ] Implement unified `ToolRegistry`:
  - Registration, schema generation for OpenAI functions, and execution dispatcher.
- [ ] Implement `read_file`:
  - Line-numbered output, `startLine`/`endLine` slicing, and 32 KB safety truncation.
- [ ] Implement `write_file`:
  - Full file write with automatic parent directory creation.
- [ ] Implement `edit_file`:
  - Search-and-replace anchored to an optional `startLine`/`endLine` range to reduce LLM hallucination mismatches.
  - Exact match validation within the anchored range; on failure return a structured error with surrounding context to help the model self-correct.
  - *(See improvement notes — this is intentionally better than the upstream Kilo approach.)*
- [ ] Implement `shell`:
  - Subprocess execution in workspace directory with timeout, streaming output, and SIGINT handling.
- [ ] Implement `grep_search`:
  - Fast pattern matching with line numbers and file glob filtering.
- [ ] Implement `glob_find`:
  - File tree exploration respecting `.gitignore` and common exclusions.
- [ ] Implement `todo`:
  - In-session task checklist (`list`, `add`, `update`, `clear`).

### Phase 5: MCP Client Subsystem (`src/mcp/`)
*Spec: [04-mcp-client.md](../specs/04-mcp-client.md)*
- [ ] Implement `McpClientManager`:
  - Support `stdio` transport using `child_process.spawn` (with `windowsHide: true`).
  - Support `sse` and `streamableHttp` transports.
- [ ] Implement configuration loader:
  - Read `.fox/mcp.json` (workspace) and `~/.config/fox/mcp.json` (global).
- [ ] Implement dynamic ACP session registration:
  - Ingest `mcpServers` passed during ACP `newSession`/`loadSession`.
- [ ] Implement tool discovery & namespacing:
  - Prefix discovered tools as `mcp__{server}__{tool}`.
  - Bridge tool definitions into `ToolRegistry`.
  - Handle `tools/list_changed` notifications.

### Phase 6: Core Agent Engine (`src/agent/`)
*Spec: [05-agent-core-and-tools.md](../specs/05-agent-core-and-tools.md)*
- [ ] Implement `AgentOrchestrator`:
  - ReAct execution cycle: Assemble Prompt ➔ Call Model ➔ Execute Tools ➔ Repeat.
  - Loop termination guard: `maxSteps` (25) and doom-loop detector (3 repeated errors).
- [ ] Implement prompt builder:
  - System prompt optimized for local models.
  - Automatic injection of `FOX.md` or `AGENTS.md` project rules.
  - Conversational history formatting.
- [ ] Implement context window compactor:
  - Trigger at 80% context window capacity.
  - Truncate older tool output payloads while preserving summaries and active todos.
- [ ] Implement permission evaluator:
  - Tiered safety policies (Tier 1 auto-approve, Tier 3 confirmation).

### Phase 7: ACP Server Adapter (`src/acp/`)
*Spec: [03-acp-server.md](../specs/03-acp-server.md)*
- [ ] Setup `AgentSideConnection` with `ndJsonStream` over `stdin`/`stdout`.
- [ ] Implement protocol request handlers:
  - `initialize`: Return capabilities (`loadSession: true`, `listSessions: true`, `forkSession: true`, `deleteSession: true`, `promptStreaming: true`, `mcpServers: true`) and agent metadata.
  - `authenticate`: Return immediate local success.
  - `newSession` / `loadSession` / `listSessions`: Manage SQLite state and mount MCP servers.
  - `closeSession`: Mark active session as closed in SQLite and flush in-memory state.
  - `deleteSession`: Purge target session, messages, parts, and todos completely from SQLite database.
  - `prompt`: Run `AgentOrchestrator` and stream events to `connection.sessionUpdate`.
  - `cancel`: Abort active session `AbortController` and kill running child processes.
  - `setSessionConfigOption` / `setSessionMode` / `setSessionModel`: Support live configuration switching.
- [ ] Implement token utilization tracking (`usage_update`):
  - Extract prompt and completion token counts from local model response (or estimate locally via tokenizer).
  - Emit `sessionUpdate: "usage_update"` with `{ used: number, size: number }` to feed the client's context progress bar.
- [ ] Implement reasoning effort configuration (`thought_level`):
  - Expose available reasoning variants (e.g., `low`, `medium`, `high`) under `category: "thought_level"` in session `configOptions`.
- [ ] Bridge permission escalation:
  - Map internal tool permission prompts to `connection.requestPermission`.
  - Handle `allow_once`, `allow_always`, and `reject`.

### Phase 8: Headless REST API Server (`src/server/`)
*Spec: [06-rest-api-server.md](../specs/06-rest-api-server.md)*
- [ ] Implement lightweight HTTP listener (default `127.0.0.1:4096`):
  - Optional Bearer token validation for external/LAN binds.
- [ ] Implement routes:
  - `GET /v1/health`
  - `GET /v1/models`
  - `POST /v1/sessions` & `GET /v1/sessions`
  - `POST /v1/sessions/:id/prompt` (with SSE streaming or JSON sync response)
  - `POST /v1/sessions/:id/cancel`
  - `GET /v1/sessions/:id/events` (persistent SSE stream for a session)
  - `GET /v1/mcp`
  - `POST /v1/mcp/reload`
  - `GET /v1/openapi.json`

### Phase 9: CLI Interface & Commands (`src/cli/`)
*Spec: [07-cli-interface-and-config.md](../specs/07-cli-interface-and-config.md)*
- [ ] Implement CLI router:
  - `fox acp`: Start ACP server.
  - `fox run [prompt]`: Non-interactive CLI runner with terminal streaming and pipe support.
  - `fox serve`: Run headless daemon.
  - `fox mcp [list|test|add]`: Manage MCP servers.
  - `fox models`: Check connection and print active model status.
  - `fox config [show|init]`: Display or initialize config files.

### Phase 10: End-to-End Verification

#### Happy-Path
- [ ] Verify `fox models` connectivity against running `openai-proxy` (`http://localhost:8000/v1`).
- [ ] Test `fox run "Read README.md and summarize it"` via command line.
- [ ] Verify `fox run` with piped stdin: `cat docs/specs/README.md | fox run "Summarize this"`.
- [ ] Verify ACP protocol flow by connecting via a mock ACP test script or `fox/fox-acp-client/` extension.
- [ ] Verify `session/delete` purges records cleanly from SQLite without orphaned child rows.
- [ ] Verify `usage_update` notifications are emitted with accurate context token counts.
- [ ] Verify MCP tool invocation using a local SQLite or Git MCP server.
- [ ] Verify `fox serve` REST API: create session, submit prompt, stream SSE events.

#### Edge-Case & Safety
- [ ] Verify doom loop guard: stub a tool to return repeated errors and confirm execution halts at 3 consecutive identical failures with a clear user-facing message.
- [ ] Verify context compaction: feed a task requiring many large `read_file` calls and confirm the agent continues coherently after compaction without losing task state.
- [ ] Verify `fox serve` auth enforcement: bind with `--host 0.0.0.0` and confirm requests without a valid `Authorization: Bearer <token>` are rejected with `401`.
- [ ] Verify `edit_file` line-anchored error handling: attempt an edit where `oldString` doesn't match and confirm the structured error hint is returned (not a silent no-op).
- [ ] Verify graceful shutdown: send `SIGTERM` to `fox acp` mid-task and confirm all MCP child processes are cleaned up within 3 seconds.

---

## 3. Future Roadmap (Fox CLI V2 / Post-V1)

The following advanced capabilities are tracked for Fox CLI V2 to match upcoming features in the Fox ACP Client and evolving protocol standards:

### 3.1. Next Edit Suggestions (NES) Engine
- **Concept:** Provide low-latency (200–300ms) ghost-text inline completions in the editor based on cursor position and recent edit history.
- **Architectural Need:** Requires a dedicated Fill-In-The-Middle (FIM) local model pipeline and debounced endpoint (`nes/request` or `/v1/edit`), decoupled from the heavy multi-step ReAct agent loop to prevent GPU saturation.
- **Client Alignment:** Unlocks Phase 10 (`InlineCompletionService`) in `fox/fox-acp-client`.

### 3.2. In-Process MCP-over-ACP Reverse Tunneling (`transport: "acp"`)
- **Concept:** Allow the ACP client (e.g. VSCode extension) to inject in-process IDE tools (diagnostics, open tabs, symbol lookup, git status) without spawning external subprocesses.
- **Architectural Need:** Implement a JSON-RPC duplex multiplexer inside the ACP Server adapter that intercepts tool calls targeting `transport: "acp"` servers and tunnels them back through the ACP `stdio` connection to the client.
- **Client Alignment:** Unlocks Phase 11 (`InProcessMcpServer`) in `fox/fox-acp-client`. *(V1 workaround: client mounts tools via stdio script or localhost HTTP/SSE).*

### 3.3. Multi-Root Workspace Support (`additionalDirectories`)
- **Concept:** Allow a single agent session to span multi-root VSCode workspaces.
- **Architectural Need:** Update `newSession` / `loadSession` to ingest `additionalDirectories`, and adjust path resolution across all built-in tools (`read_file`, `write_file`, `grep_search`, `glob_find`) and workspace file watchers.

### 3.4. Agent-Owned Terminal Protocol (ACP v2 Terminal Model)
- **Concept:** Transition from streaming shell output inside `tool_call_update` to native ACP v2 `terminal_update` and `terminal_output_chunk` notifications.
- **Architectural Need:** Expose virtual terminal PTY IDs and base64-encoded output chunks to enable rich client-side xterm.js rendering and interactive stdin forwarding.

### 3.5. Interactive Elicitation API (`elicitation/create`)
- **Concept:** Allow the agent to solicit structured multi-field user input forms or URL confirmations during complex tasks.
- **Architectural Need:** Implement `elicitation/create` request dispatcher and awaiting mechanism in the agent loop.
