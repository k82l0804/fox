# Spec 03: ACP Server Specification

> Technical specification for the Agent Client Protocol (ACP) server implementation in Fox CLI (`fox acp`).

---

## 1. Overview & Role in the Fox Architecture

The **Agent Client Protocol (ACP)** is an open standard designed to connect code editors (clients) with AI coding agents (servers) over standard JSON-RPC 2.0 communication channels.

In the Fox system architecture:
- **Fox ACP Client** (`fox/fox-acp-client/`, the VSCode extension) is the **client**.
- **Fox Code CLI** (`fox/fox-code-cli/`, invoked with `fox acp`) is the **server**.

```
┌─────────────────────────┐                            ┌─────────────────────────┐
│     VSCode Editor       │                            │      Fox Code CLI       │
│  (Fox ACP Extension)    │                            │      (ACP Server)       │
│                         │   stdin (JSON-RPC 2.0)     │                         │
│  Spawns `fox acp`       ├───────────────────────────►│  AgentSideConnection   │
│  Child Process          │◄───────────────────────────┤  @agentclientprotocol/  │
│                         │   stdout (JSON-RPC 2.0)    │  sdk                    │
└─────────────────────────┘                            └─────────────────────────┘
```

The CLI process handles all LLM communication, agent reasoning, tool dispatch, and MCP integrations, while the VSCode extension handles user interface rendering, chat input, file diff visualizations, and permission dialogs.

---

## 2. Process Lifecycle & Transport

### 2.1. Process Spawning & stdio Transport
When an editor activates Fox, it spawns the CLI executable:
```bash
fox acp --cwd /path/to/project
```
- Communication uses newline-delimited JSON-RPC 2.0 over standard I/O:
  - Requests & notifications from Editor ➔ `process.stdin`
  - Responses & session updates from Fox ➔ `process.stdout`
  - Internal debug logs & diagnostics ➔ `process.stderr` (never polluted on stdout)

### 2.2. SDK Binding
The server uses `@agentclientprotocol/sdk`:

```typescript
import { AgentSideConnection, ndJsonStream } from "@agentclientprotocol/sdk";
import { FoxACPAgent } from "./handler";

export async function runAcpServer() {
  // Readable: data flowing IN from the editor client via stdin
  const readable = new ReadableStream<Uint8Array>({
    start(controller) {
      process.stdin.on("data", (chunk: Buffer) => controller.enqueue(new Uint8Array(chunk)));
      process.stdin.on("end", () => controller.close());
      process.stdin.on("error", (err) => controller.error(err));
    },
  });

  // Writable: data flowing OUT to the editor client via stdout
  const writable = new WritableStream<Uint8Array>({
    write(chunk) {
      return new Promise((resolve, reject) => {
        process.stdout.write(chunk, (err) => (err ? reject(err) : resolve()));
      });
    },
  });

  const transport = ndJsonStream(readable, writable);
  const agent = new FoxACPAgent();

  new AgentSideConnection((conn) => agent.bindConnection(conn), transport);
  process.stdin.resume();
}
```

---

## 3. Protocol Methods & RPC Handlers

Fox CLI implements the full ACP agent interface (`Agent` type from `@agentclientprotocol/sdk`):

### 3.1. `initialize`
- **Request**: Client capabilities, client name, version, and protocol version.
- **Fox Response**:
  ```json
  {
    "protocolVersion": "0.21.0",
    "agentInfo": {
      "name": "fox-cli",
      "version": "0.1.0"
    },
    "capabilities": {
      "loadSession": true,
      "listSessions": true,
      "forkSession": true,
      "closeSession": true,
      "deleteSession": true,
      "promptStreaming": true,
      "mcpServers": true
    },
    "authMethods": []
  }
  ```

### 3.2. `authenticate`
- Because Fox is designed for local-first use, no cloud login is required.
- If requested, Fox immediately returns an empty/success authentication response.

### 3.3. `newSession`
- **Request**:
  - `cwd`: Root working directory of the workspace.
  - `mcpServers`: Optional array of client-configured MCP servers to mount for this session.
- **Fox Behavior**:
  1. Initializes a new session in the local SQLite database.
  2. Resolves local workspace configuration (`.fox/config.json`).
  3. Registers any passed `mcpServers` dynamically into the session's MCP registry.
  4. Returns a unique `sessionId` and session `configOptions` (including model, mode, and reasoning effort under `category: "thought_level"`).

### 3.4. `loadSession` & `listSessions`
- **`listSessions({ cwd })`**: Queries SQLite for previous sessions started in the given directory; returns session summaries, timestamps, and message counts.
- **`loadSession({ sessionId, cwd, mcpServers })`**:
  1. Rehydrates conversation history, tool calls, and todo state from SQLite.
  2. Re-mounts client-provided MCP servers.
  3. Emits prior message history to the client via `sessionUpdate` events.

### 3.5. `prompt`
- **Request**:
  - `sessionId`: The target session ID.
  - `prompt`: User prompt content (text parts, attached file references, images).
- **Fox Behavior**:
  1. Appends the user message to the session state.
  2. Instantiates an `AbortController` linked to this session.
  3. Starts the iterative ReAct agent loop.
  4. Emits continuous progress notifications to the client via `connection.sessionUpdate`.
  5. Returns `PromptResponse` when the agent has completed all steps.

### 3.6. `cancel`
- **Request**: `{ sessionId: string }`
- **Fox Behavior**:
  - Immediately aborts the active `AbortController`.
  - Terminates any ongoing child processes (e.g., shell command execution).
  - Sends a session cancellation event to `sessionUpdate` and resets state to idle.

### 3.7. `setSessionMode` & `setSessionModel`
- Allows the editor to switch between operational modes (e.g. `code`, `architect`, `ask`) or change the local model selection on the fly (e.g. switching between `gpt-4o-mini` for speed and `gpt-4o` for deep reasoning).

### 3.8. `closeSession` & `deleteSession`
- **`closeSession({ sessionId })`**: Concludes the active turn, releases associated in-memory resources/processes, and marks the session as closed in SQLite.
- **`deleteSession({ sessionId })`**: Completely purges the session row and its associated messages, parts, and todos from the SQLite database (`~/.fox/fox.db`).

---

## 4. Client Permission Escalation

Security is critical when executing shell commands or editing workspace files. Fox CLI delegates interactive permission decisions directly to the ACP client editor.

### Permission Flow

```
[Agent Core]                         [ACP Server]                     [VSCode / ACP Client]
     │                                    │                                    │
     │ 1. Attempt tool 'shell'            │                                    │
     ├───────────────────────────────────►│                                    │
     │                                    │ 2. connection.requestPermission()  │
     │                                    ├───────────────────────────────────►│
     │                                    │    { tool: "shell", command: ... } │ 3. Shows permission
     │                                    │                                    │    prompt to user
     │                                    │ 4. Response: "allow_once"          │
     │                                    │◄───────────────────────────────────┤
     │ 5. Approval confirmed              │                                    │
     │◄───────────────────────────────────┤                                    │
     │                                    │                                    │
     ▼ 6. Execute shell command           │                                    │
```

### Permission Options
Fox offers three standardized options:
1. `allow_once`: Execute this specific invocation only.
2. `allow_always`: Allow this tool (or command pattern) for the duration of the session without prompting again.
3. `reject`: Refuse execution; the agent receives a permission-denied tool error and adjusts its plan.

---

## 5. Bidirectional Session Streaming (`sessionUpdate`)

All agent events are pushed to the client using `connection.sessionUpdate({ sessionId, update })`:

### Event Types
1. **`agent_message_delta`**: Incremental text chunk generated by the local LLM.
2. **`thought_message_delta`**: Internal reasoning/thinking tokens (displayed in collapsible UI containers).
3. **`tool_call_start`**: Agent initiates a tool call with tool name, ID, and preliminary arguments.
4. **`tool_call_update`**: Real-time progress updates (e.g., streaming stdout from a running shell command).
5. **`tool_call_complete`**: Tool execution finished with output payload and status code.
6. **`plan_update`**: Updated todo list or execution roadmap.
7. **`status_change`**: Transition between `idle`, `thinking`, `executing_tool`, and `error`.
8. **`usage_update`**: Context window utilization chunk containing `{ used: number, size: number }` tokens, driving the client's `ContextProgress` meter.
