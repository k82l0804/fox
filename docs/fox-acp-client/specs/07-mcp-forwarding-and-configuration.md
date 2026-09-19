# Spec 07: MCP Forwarding & Configuration

> Technical specification for discovering workspace Model Context Protocol (MCP) servers, forwarding them to Fox CLI via ACP, extension settings schema, and offline guarantees.

---

## 1. Overview & Role

The Model Context Protocol (MCP) enables AI coding agents to discover and invoke external tools (e.g. SQLite query tools, Git operations, web fetchers, Docker managers).

In the Fox system architecture:
- **Fox ACP Client** gathers workspace MCP configurations from local files and VSCode settings.
- During ACP `newSession` and `loadSession`, the client dynamically packages these servers into the `mcpServers` parameter.
- **Fox Code CLI** mounts these MCP servers, queries their tools via `@modelcontextprotocol/sdk`, and makes them available to the agent loop.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          VSCode Workspace                                   │
│                                                                             │
│   ┌─────────────────────┐   ┌─────────────────────┐   ┌──────────────────┐  │
│   │   .fox/mcp.json     │   │  .vscode/mcp.json   │   │  VSCode Settings │  │
│   └──────────┬──────────┘   └──────────┬──────────┘   └─────────┬────────┘  │
│              │                         │                        │           │
│              └──────────────────┐      │     ┌──────────────────┘           │
│                                 ▼      ▼     ▼                              │
│                    ┌──────────────────────────────────┐                     │
│                    │         McpConfigLoader          │                     │
│                    │  - Merges sources                │                     │
│                    │  - Resolves ${workspaceFolder}   │                     │
│                    │  - Validates schema              │                     │
│                    └─────────────────┬────────────────┘                     │
│                                      │                                      │
│                                      ▼                                      │
│                    ┌──────────────────────────────────┐                     │
│                    │    SessionManager.newSession()   │                     │
│                    │    `mcpServers: [ ... ]`         │                     │
│                    └─────────────────┬────────────────┘                     │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │ ACP stdio (newSession)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Fox Code CLI Process                               │
│                         `McpClientManager`                                  │
│  ┌─────────────────────────┐  ┌─────────────────────────┐                   │
│  │   sqlite (uvx mcp-...)  │  │   git (npx @mcp/git)    │                   │
│  └─────────────────────────┘  └─────────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Workspace MCP Discovery (`McpConfigLoader`)

The `McpConfigLoader` checks the following locations in order of precedence:

1. **Workspace `.fox/mcp.json`** (Recommended Fox standard):
   - Version-controlled configuration shared across the engineering team.
2. **Workspace `.vscode/mcp.json`** (VSCode convention):
   - Standard VSCode MCP configuration file.
3. **VSCode Settings (`fox.mcpServers`)**:
   - User or workspace settings managed through the VSCode Settings UI.

### Configuration Schema

```json
{
  "mcpServers": {
    "sqlite": {
      "command": "uvx",
      "args": ["mcp-server-sqlite", "--db-path", "${workspaceFolder}/dev.db"],
      "env": {}
    },
    "git": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git"],
      "env": {}
    },
    "local-docs": {
      "url": "http://localhost:8080/sse",
      "transport": "sse"
    }
  }
}
```

### Variable Substitution
All arguments and environment values undergo variable resolution:
- `${workspaceFolder}`: Path to the current workspace root. In multi-root workspaces, this resolves to the **first workspace folder** (`vscode.workspace.workspaceFolders[0]`).
- `${workspaceFolderBasename}`: Folder name (basename) of the resolved workspace root.
- `${env:VAR_NAME}`: Value of the host environment variable `VAR_NAME`.

> **V1 Scope — Multi-Root Workspaces:** Fox ACP Client V1 supports only a single workspace root for MCP discovery, binary resolution, and session CWD. The first workspace folder is used in all cases. Multi-root support (scanning all workspace folders, per-folder MCP configs) is deferred to a future release.

---

## 3. Dynamic Session Injection

During `newSession` and `loadSession` RPC calls, the client converts discovered configurations into the standard ACP `McpServerConfig` format:

```typescript
export interface McpServerConfig {
  name: string;
  command?: string;
  args?: string[];
  env?: Record<string, string>;
  url?: string;
  transport?: "stdio" | "sse" | "streamableHttp";
}
```

### Injection Payload in `newSession`

```json
{
  "cwd": "/home/developer/workarea/project",
  "mcpServers": [
    {
      "name": "sqlite",
      "command": "uvx",
      "args": ["mcp-server-sqlite", "--db-path", "/home/developer/workarea/project/dev.db"],
      "env": {}
    },
    {
      "name": "git",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-git"],
      "env": {}
    }
  ]
}
```

---

## 4. Extension Configuration Schema (`package.json`)

The following settings are contributed to VSCode under the `fox.*` namespace:

```json
{
  "contributes": {
    "configuration": {
      "title": "Fox ACP Client",
      "properties": {
        "fox.executablePath": {
          "type": "string",
          "default": "",
          "description": "Explicit path to the Fox CLI executable. If left empty, Fox will auto-detect from workspace ./bin/fox or system PATH."
        },
        "fox.autoConnect": {
          "type": "boolean",
          "default": true,
          "description": "Automatically spawn and connect to Fox Code CLI when opening a workspace."
        },
        "fox.autoApprovePermissions": {
          "type": "string",
          "enum": ["ask", "allowWorkspaceRead", "allowAll"],
          "default": "ask",
          "description": "Policy for handling agent permission requests: 'ask' prompts for every action, 'allowWorkspaceRead' auto-approves read-only tools, 'allowAll' approves all actions."
        },
        "fox.diffReviewMode": {
          "type": "string",
          "enum": ["always", "onCollision", "never"],
          "default": "always",
          "description": "Controls when proposed agent file writes open in the side-by-side diff editor: 'always' reviews all edits, 'onCollision' reviews only edits to dirty buffers, 'never' writes directly to disk."
        },
        "fox.logTraffic": {
          "type": "boolean",
          "default": true,
          "description": "Log all ACP JSON-RPC protocol traffic to the 'Fox Protocol Traffic' output channel."
        },
        "fox.mcpServers": {
          "type": "object",
          "default": {},
          "description": "Additional MCP servers to forward to Fox CLI sessions."
        },
        "fox.nes.enabled": {
          "type": "boolean",
          "default": true,
          "description": "Enable inline Next Edit Suggestions (ghost-text code completions) powered by Fox CLI."
        },
        "fox.nes.triggerDelay": {
          "type": "number",
          "default": 500,
          "description": "Milliseconds after the last keystroke before Fox requests a Next Edit Suggestion."
        },
        "fox.customAgents": {
          "type": "object",
          "default": {},
          "markdownDescription": "**Reserved for future use.** Additional custom ACP agents. Each entry specifies command, args, and env. This setting is not functional in V1 — use `fox.executablePath` to configure the primary agent."
        }
      }
    }
  }
}
```

---

## 4. MCP-over-ACP In-Process Server

### Overview

Beyond forwarding *external* MCP servers to Fox CLI, Fox ACP Client can also **host its own in-process MCP server** that is accessible to the agent. This enables the agent to query VSCode-native information — diagnostics, open files, workspace symbol search, and Git status — directly from the editor environment.

> **Transport Compatibility & V1 Strategy:** In-stream MCP-over-ACP reverse tunneling (`transport: "acp"`) is an emerging ACP standard scheduled for the [Fox CLI V2 Roadmap](../../fox-cli/plans/cli-implementation-plan.md#32-in-process-mcp-over-acp-reverse-tunneling-transport-acp). Because Fox CLI V1 supports `stdio` and `sse` MCP transports (Spec 04), `InProcessMcpServer` provides a dual-mode transport:
> - **V1 Fallback Mode (Default):** The extension starts a lightweight local HTTP/SSE listener on loopback (`http://127.0.0.1:<port>/sse`) and passes standard `{ "name": "vscode", "url": "http://127.0.0.1:<port>/sse" }` into `mcpServers`. Fox CLI V1 connects to this endpoint immediately using its standard MCP client subsystem without requiring protocol modifications.
> - **V2 Native Mode:** If Fox CLI advertises `mcpCapabilities: { acp: true }`, the client seamlessly switches to in-stream reverse tunneling:
>   ```json
>   {
>     "cwd": "/workspace",
>     "mcpServers": [
>       {
>         "name": "vscode",
>         "transport": { "type": "acp" }
>       }
>     ]
>   }
>   ```
>   When Fox CLI supports `transport.type: "acp"`, it routes MCP tool calls directly back through the ACP connection to the client, which handles them in-process without any loopback network sockets.

### `InProcessMcpServer` Implementation

```typescript
// src/mcp/InProcessMcpServer.ts
export class InProcessMcpServer {
  readonly name = "vscode";

  /** Called by the ACP SDK when Fox CLI invokes a vscode:// MCP tool */
  async callTool(toolName: string, params: unknown): Promise<unknown> {
    switch (toolName) {
      case "get_diagnostics":    return this.getDiagnostics(params);
      case "search_symbols":     return this.searchSymbols(params);
      case "get_open_files":     return this.getOpenFiles();
      case "git_status":         return this.getGitStatus();
      default:
        throw new Error(`Unknown vscode MCP tool: ${toolName}`);
    }
  }

  private async getDiagnostics(params: { path?: string }): Promise<object> {
    const uris = params.path
      ? [vscode.Uri.file(params.path)]
      : vscode.workspace.textDocuments.map(d => d.uri);
    const result: Record<string, object[]> = {};
    for (const uri of uris) {
      result[uri.fsPath] = vscode.languages.getDiagnostics(uri).map(d => ({
        severity: vscode.DiagnosticSeverity[d.severity].toLowerCase(),
        message: d.message,
        range: { start: d.range.start, end: d.range.end },
        source: d.source,
        code: d.code,
      }));
    }
    return result;
  }

  private async searchSymbols(params: { query: string }): Promise<object[]> {
    const symbols = await vscode.commands.executeCommand<vscode.SymbolInformation[]>(
      "vscode.executeWorkspaceSymbolProvider",
      params.query,
    );
    return (symbols ?? []).map(s => ({
      name: s.name,
      kind: vscode.SymbolKind[s.kind],
      location: { uri: s.location.uri.fsPath, range: s.location.range },
      containerName: s.containerName,
    }));
  }

  private getOpenFiles(): string[] {
    return vscode.workspace.textDocuments
      .filter(d => !d.isUntitled)
      .map(d => d.uri.fsPath);
  }

  private async getGitStatus(): Promise<object> {
    const gitExt = vscode.extensions.getExtension("vscode.git")?.exports;
    const repo = gitExt?.getAPI(1)?.repositories?.[0];
    if (!repo) return { error: "No git repository found" };
    const state = repo.state;
    return {
      branch: state.HEAD?.name,
      ahead: state.HEAD?.ahead,
      behind: state.HEAD?.behind,
      modified: state.workingTreeChanges.map((c: { uri: vscode.Uri }) => c.uri.fsPath),
      staged: state.indexChanges.map((c: { uri: vscode.Uri }) => c.uri.fsPath),
      untracked: state.untrackedChanges?.map((c: { uri: vscode.Uri }) => c.uri.fsPath) ?? [],
    };
  }
}
```

### Available In-Process MCP Tools

| Tool Name | Parameters | Returns | Description |
|---|---|---|---|
| `get_diagnostics` | `{ path?: string }` | `Record<string, Diagnostic[]>` | TypeScript/ESLint errors and warnings. Scoped to one file or all open documents. |
| `search_symbols` | `{ query: string }` | `SymbolInfo[]` | Workspace symbol search (functions, classes, types) using VSCode's symbol provider. |
| `get_open_files` | *(none)* | `string[]` | List of all currently open file paths in the editor. |
| `git_status` | *(none)* | `GitStatus` | Current branch, modified/staged/untracked files via the built-in Git extension. |

> **Privacy note:** The in-process MCP server only serves data from the active workspace. It never reads files outside the workspace root or transmits data over the network.

---

## 5. Offline Privacy & Security Guarantees

1. **Zero External Network Connections**:
   - The extension makes zero outbound HTTP/HTTPS requests to external services, analytics collectors, or cloud registries.
   - All communication is bound strictly to `stdio` processes on the local machine.
2. **Environment Variable Sanitization**:
   - Secrets and environment variables specified in `.fox/mcp.json` are passed directly to subprocesses without being mirrored to disk or telemetry channels.
   - Traffic logging masks sensitive authorization headers (e.g. `Bearer ******`).
3. **Workspace Isolation**:
   - Agent filesystem operations are constrained to the active workspace roots unless the user explicitly grants cross-directory permissions.

---

## 6. Error Handling

### MCP Configuration Error Contracts

| Error Condition | Behavior |
|---|---|
| `.fox/mcp.json` contains invalid JSON | Log parse error to Fox Output Channel. Show warning notification: `Failed to parse .fox/mcp.json: ${parseError}`. Proceed with remaining valid sources. |
| MCP server entry missing required `command` field (for stdio transport) | Skip the invalid entry. Log warning: `MCP server "${name}" is missing 'command'. Skipping.` |
| `${env:VAR_NAME}` references undefined environment variable | Replace with empty string. Log warning: `Environment variable ${VAR_NAME} is not defined.` |
| `${workspaceFolder}` used but no workspace is open | Skip variable substitution. Log error: `Cannot resolve \${workspaceFolder}: no workspace open.` |
| Duplicate MCP server names across sources | Last-wins precedence (VSCode settings > `.vscode/mcp.json` > `.fox/mcp.json`). Log info: `MCP server "${name}" overridden by higher-priority source.` |
| In-process MCP tool call fails (e.g. Git extension not available) | Return `{ error: "..." }` in the tool response. Do not crash the session. Log warning to Fox Output Channel. |
