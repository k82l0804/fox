# Spec 06: REST API & Headless Server

> Technical specification for the Fox CLI headless REST API server (`fox serve`), OpenAPI endpoints, and Server-Sent Events (SSE) streaming protocol.

---

## 1. Overview & Motivation

The `fox serve` command launches a lightweight HTTP/REST daemon providing programmatic access to the Fox agent engine.

### Key Use Cases
1. **Remote GPU Workstations**: Run the Fox agent server on a dedicated local machine or LAN workstation with high-end GPUs (running vLLM/Ollama) while controlling it remotely from a laptop.
2. **Headless Automation & CI/CD**: Integrate Fox agent sessions into automated test suites, pre-commit checks, or build pipelines.
3. **Decoupled Architecture**: Both the CLI (`fox run`) and web/custom clients can communicate with the same persistent agent instance.

---

## 2. Server Configuration & Security

### 2.1. Network Binding
- **Default Host**: `127.0.0.1` (Strict loopback isolation).
- **Default Port**: `4096` (Configurable via `--port` or `FOX_PORT`).
- **External Binding**: When bound to `0.0.0.0` or a LAN interface, token authentication is mandatory.

### 2.2. Authentication
- Secured via standard Bearer token:
  ```
  Authorization: Bearer <FOX_SERVER_TOKEN>
  ```
- If running on `127.0.0.1` without a token configured, requests are allowed by default for local developer ergonomics.

---

## 3. REST API Endpoints

All endpoints are versioned under `/v1`.

### 3.1. Health & Discovery

#### `GET /v1/health`
Returns server operational health, memory footprint, and local model connectivity.
```json
{
  "status": "healthy",
  "version": "0.1.0",
  "uptimeSeconds": 1420,
  "modelBackend": {
    "url": "http://localhost:8000/v1",
    "model": "gpt-4o-mini",
    "reachable": true,
    "latencyMs": 35
  }
}
```

#### `GET /v1/models`
Returns the active model configuration and available models discovered at the local model endpoint.
```json
{
  "activeModel": "gpt-4o-mini",
  "availableModels": ["gpt-4o-mini", "gpt-4o", "qwen2.5-coder:14b"]
}
```

#### `GET /v1/openapi.json`
Returns the full OpenAPI 3.0 specification schema for the server.

---

### 3.2. Session Management

#### `POST /v1/sessions`
Creates a new isolated agent session.
- **Request Body**:
  ```json
  {
    "cwd": "/home/user/workarea/fox",
    "title": "Fix auth bug",
    "systemPrompt": "Optional custom instructions override"
  }
  ```
- **Response**: `201 Created`
  ```json
  {
    "id": "sess_01jb9x8...",
    "cwd": "/home/user/workarea/fox",
    "createdAt": "2026-09-17T15:30:00Z"
  }
  ```

#### `GET /v1/sessions`
Lists active and archived sessions with message counts and timestamps.

#### `GET /v1/sessions/:id`
Retrieves full session state, conversation history, tool calls, and active todo list.

#### `DELETE /v1/sessions/:id`
Deletes the session and associated database records.

---

### 3.3. Prompting & Execution

#### `POST /v1/sessions/:id/prompt`
Submits a user prompt to the session.
- **Request Body**:
  ```json
  {
    "prompt": "Inspect package.json and run npm test",
    "stream": true
  }
  ```
- **Behavior**:
  - If `stream: true` (default): Returns `Content-Type: text/event-stream` with live SSE progress.
  - If `stream: false`: Blocks until the agent turn completes and returns the final JSON response.

#### `POST /v1/sessions/:id/cancel`
Aborts any active reasoning, tool invocation, or shell command execution in the specified session.
- **Response**: `200 OK`
  ```json
  {
    "status": "cancelled",
    "sessionId": "sess_01jb9x8..."
  }
  ```

#### `GET /v1/sessions/:id/events`
Opens a persistent Server-Sent Events stream for a session. Emits all agent events (message deltas, tool calls, status transitions) in real time. The connection stays open until the session goes idle or the client disconnects.
- **Response**: `200 OK`, `Content-Type: text/event-stream`

---

### 3.4. Model Context Protocol (MCP)

#### `GET /v1/mcp`
Lists configured MCP servers, transport types, and discovered tools.
```json
{
  "servers": [
    {
      "name": "sqlite",
      "transport": "stdio",
      "status": "active",
      "toolCount": 2,
      "tools": ["mcp__sqlite__query", "mcp__sqlite__schema"]
    }
  ]
}
```

#### `POST /v1/mcp/reload`
Restarts all MCP connections and re-scans for available tools.

---

## 4. Server-Sent Events (SSE) Streaming Format

When connecting to `POST /v1/sessions/:id/prompt` with `stream: true` (or `GET /v1/sessions/:id/events`), events are emitted in standard SSE format:

```
event: message_delta
data: {"text": "I will examine the "}

event: thought_delta
data: {"text": "Checking if test script exists in package.json..."}

event: tool_start
data: {"id": "call_1", "tool": "read_file", "arguments": {"path": "package.json"}}

event: tool_output
data: {"id": "call_1", "output": "{\n  \"scripts\": { \"test\": \"jest\" }\n}", "success": true}

event: message_delta
data: {"text": "Found Jest test script. Running tests now..."}

event: tool_start
data: {"id": "call_2", "tool": "shell", "arguments": {"command": "npm test"}}

event: status
data: {"state": "executing_tool"}

event: tool_output
data: {"id": "call_2", "output": "PASS test/index.test.js\n1 passed", "success": true}

event: done
data: {"finishReason": "completed", "totalTokens": 620}
```

---

## 5. Implementation Stack

The server is built with Node.js built-in HTTP module or a lightweight router (such as `Hono` or `Polka`) with zero native binary bloat:
- **No Heavy Frameworks**: No massive NestJS or Express overhead.
- **Fast Startup**: Boot time under 50ms.
- **Direct Engine Hook**: Invokes the exact same `AgentOrchestrator` used by `fox acp` and `fox run`.
