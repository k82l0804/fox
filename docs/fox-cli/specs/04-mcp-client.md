# Spec 04: MCP Client Subsystem

> Technical specification for Fox CLI's Model Context Protocol (MCP) client implementation, server connection pooling, tool discovery, and dynamic ACP bridging.

---

## 1. Overview & Architectural Role

The **Model Context Protocol (MCP)** is an open standard created by Anthropic that allows AI agents to securely connect to external tools, data sources, and services.

In Fox CLI, Fox acts as an **MCP Client**. Rather than hardcoding specialized integrations (e.g., database clients, Docker controllers, or GitHub APIs) into the core agent codebase, Fox relies on MCP servers to provide domain-specific capabilities.

```
┌────────────────────────────────────────────────────────────┐
│                        FOX CODE CLI                        │
│                                                            │
│   ┌────────────────────────────────────────────────────┐   │
│   │                 MCP Client Manager                 │   │
│   │                                                    │   │
│   │  - Config Loader (.fox/mcp.json)                   │   │
│   │  - Dynamic ACP Server Injector                     │   │
│   │  - Connection Pool (stdio, sse, streamableHttp)    │   │
│   │  - Tool Registry Bridge                            │   │
│   └──────────┬──────────────────┬──────────────────┬───┘   │
└──────────────┼──────────────────┼──────────────────┼───────┘
               │ stdio            │ stdio            │ sse
               ▼                  ▼                  ▼
      ┌────────────────┐ ┌────────────────┐ ┌────────────────┐
      │  Local Python  │ │  Node MCP CLI  │ │ Remote / Host  │
      │  MCP Tool      │ │  (e.g. sqlite) │ │ MCP Server     │
      └────────────────┘ └────────────────┘ └────────────────┘
```

---

## 2. Server Sources & Configuration

Fox discovers MCP servers through two distinct pathways:

### 2.1. Static Workspace & User Configuration
Static MCP servers are configured in JSON files. Fox searches the following locations in order of priority:
1. Workspace configuration: `.fox/mcp.json` or `.mcp.json` in the active project directory.
2. User global configuration: `~/.config/fox/mcp.json`.

#### Configuration Schema (`mcp.json`)
```json
{
  "mcpServers": {
    "sqlite": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sqlite", "--db-path", "./test.db"],
      "env": {
        "DEBUG": "mcp:*"
      }
    },
    "git": {
      "command": "uvx",
      "args": ["mcp-server-git", "--repository", "."]
    },
    "local-metrics": {
      "url": "http://127.0.0.1:9090/sse",
      "headers": {
        "Authorization": "Bearer local-secret"
      }
    }
  }
}
```

### 2.2. Dynamic ACP-Injected MCP Servers
When spawned as an ACP server (`fox acp`), the editor client (e.g. Fox VSCode Extension) can pass server definitions directly in the `newSession` or `loadSession` RPC payload:

```typescript
// ACP payload from editor
{
  "sessionId": "sess_123",
  "cwd": "/home/user/project",
  "mcpServers": [
    {
      "name": "vscode-ide-tools",
      "command": "node",
      "args": ["/path/to/vscode-extension/mcp-server.js"]
    }
  ]
}
```
Fox registers these servers dynamically for that specific session and disposes of them when the session closes.

---

## 3. Transports & Connection Management

The client utilizes the official `@modelcontextprotocol/sdk`:

### 3.1. Supported Transports
1. **`stdio` (Default for local processes)**:
   - Spawns the command as a child process using Node.js `child_process.spawn`.
   - Communicates over standard input/output using JSON-RPC messages.
   - Sets `windowsHide: true` on Windows to avoid flashing cmd windows.
2. **`sse` (Server-Sent Events)**:
   - Connects to long-running HTTP endpoints streaming events via SSE.
   - Sends client requests using standard HTTP POST calls.
3. **`streamableHttp`**:
   - Modern bidirectional HTTP transport for next-gen MCP servers.

### 3.2. Connection Pool & Process Isolation
- **Lazy Initialization**: Connections to configured MCP servers are established upon the first agent turn or when tools are enumerated.
- **Auto-Restart & Health Tracking**: If a stdio child process crashes, Fox detects the exit code, logs the failure, and attempts a single graceful restart upon the next invocation.
- **Graceful Teardown**: Upon CLI termination (`SIGINT`, `SIGTERM`) or ACP session closure, all active child processes receive `SIGTERM` followed by a 3-second `SIGKILL` timeout.

---

## 4. Tool Discovery & Registry Bridge

### 4.1. Namespacing & Conflict Avoidance
MCP servers provide tools with arbitrary names (e.g., `read_file`, `query`, `commit`). To prevent naming collisions with Fox built-in tools or between different MCP servers, tools are automatically namespaced:

Tool names are constructed as:

```
mcp__{serverName}__{toolName}
```

*Example*: Tool `query` from server `sqlite` becomes:
```
mcp__sqlite__query
```

### 4.2. Schema Transformation
Discovered MCP tools are transformed into OpenAI-compatible function schemas:

```typescript
export function mcpToolToOpenAIFunction(serverName: string, tool: MCPTool): OpenAITool {
  return {
    type: "function",
    function: {
      name: `mcp__${serverName}__${tool.name}`,
      description: `[MCP: ${serverName}] ${tool.description ?? ""}`,
      parameters: tool.inputSchema ?? { type: "object", properties: {} },
    },
  };
}
```

### 4.3. Dynamic Tool List Updates
Fox listens for the `notifications/tools/list_changed` event from all connected MCP servers. When received:
1. Re-queries `tools/list` on the reporting server.
2. Updates the session's active tool registry.
3. Notifies the ACP client (if attached) of the updated tool capabilities.

---

## 5. Tool Execution & Output Normalization

When the local LLM generates a tool call targeting an MCP tool:
1. **Lookup**: Fox parses the server name and tool name from `mcp__{server}__{tool}`.
2. **Client Invocation**: Dispatches `client.callTool({ name, arguments })` to the designated MCP client.
3. **Result Normalization**:
   - Content items (text, images, embedded resources) are extracted from `CallToolResult`.
   - String representations are combined and returned to the agent execution loop.
   - Any runtime error is captured and formatted cleanly as a tool error message so the LLM can self-correct.

---

## 6. CLI Management Commands (`fox mcp`)

Fox includes subcommands to inspect and verify MCP servers from the terminal:

```bash
# List all configured MCP servers and their active status
fox mcp list

# Test connectivity and inspect available tools on a specific server
fox mcp test sqlite

# Add an MCP server to the workspace .fox/mcp.json
fox mcp add --name sqlite --command npx --args "-y" "@modelcontextprotocol/server-sqlite"
```

### Example Output (`fox mcp list`)
```
Configured MCP Servers:
────────────────────────────────────────────────────────────────────────
Name      Transport   Target                     Status    Tools
────────────────────────────────────────────────────────────────────────
sqlite    stdio       npx @modelcontext...       ACTIVE    query, list_tables
git       stdio       uvx mcp-server-git         ACTIVE    git_status, git_diff
metrics   sse         http://localhost:9090/sse  OFFLINE   -
────────────────────────────────────────────────────────────────────────
```
