# Spec 07: CLI Interface, Storage & Configuration

> Technical specification for the Fox CLI user interface, command options, SQLite persistence schema, and hierarchical configuration.

---

## 1. CLI Commands & Usage

Fox CLI provides a focused set of subcommands engineered for everyday developer ergonomics, editor integration, and scripting:

```
Usage: fox <command> [options]

Commands:
  fox acp             Start the Agent Client Protocol (ACP) server over stdio
  fox run [prompt]    Execute an agent prompt non-interactively or from stdin
  fox serve           Start the headless HTTP/REST agent daemon
  fox mcp <command>   Manage Model Context Protocol (MCP) servers
  fox models          Check connection and list models at the local endpoint
  fox config          View or modify Fox CLI configuration

Options:
  -v, --version       Show version number
  -h, --help          Show help
```

---

## 2. Command Details

### 2.1. `fox acp`
Spawns the Agent Client Protocol server on `stdin`/`stdout`.
- **Options**:
  - `--cwd <path>`: Initial working directory (defaults to `process.cwd()`).
- **Use Case**: Invoked automatically by the Fox VSCode Extension (`fox/fox-acp-client`) or any ACP-compliant editor (Zed, Neovim ACP).

### 2.2. `fox run [prompt]`
Executes an agent task directly from the terminal or via unix pipelines.
- **Options**:
  - `--model <name>`: Override model selection (e.g., `--model gpt-4o`).
  - `--cwd <path>`: Working directory for tool execution.
  - `-y, --yes`: Auto-approve all tool operations without prompting.
  - `--stream`: Stream tokens and tool execution to terminal (default: `true`).
- **Examples**:
  ```bash
  # Direct prompt argument
  fox run "Write unit tests for src/auth.ts"

  # Piped input from command or file
  cat bug_report.log | fox run "Analyze this crash dump and propose a fix"
  ```

### 2.3. `fox serve`
Launches the headless REST & SSE daemon.
- **Options**:
  - `--port <number>`: Port to listen on (default: `4096`).
  - `--host <address>`: Bind address (default: `127.0.0.1`).
  - `--token <secret>`: Bearer token for API authentication.

### 2.4. `fox mcp`
Subcommands for managing external MCP servers:
```bash
fox mcp list                # List all configured servers and tools
fox mcp test <name>         # Test ping and tool enumeration for a server
fox mcp add --name <n> ...  # Add a server definition to .fox/mcp.json
```

### 2.5. `fox models`
Tests connectivity to the configured OpenAI-compatible endpoint, verifies latency, and displays available models.

### 2.6. `fox config`
Inspects or initializes configuration files:
```bash
fox config show             # Display effective resolved configuration
fox config init             # Generate a starter .fox/config.json in current directory
```

---

## 3. Configuration Hierarchy & Schema

Fox resolves configuration values using a strict order of precedence (highest to lowest):
1. **CLI Command Flags** (e.g. `--model gpt-4o`)
2. **Environment Variables** (e.g. `OPENAI_BASE_URL`, `FOX_MODEL`)
3. **Workspace Configuration** (`<cwd>/.fox/config.json`)
4. **Global User Configuration** (`~/.config/fox/config.json`)
5. **Built-in Defaults**

### Configuration Schema (`config.json`)

```json
{
  "$schema": "./schemas/config.json",
  "model": {
    "baseUrl": "http://localhost:8000/v1",
    "apiKey": "local-dev",
    "defaultModel": "gpt-4o-mini",
    "temperature": 0.1,
    "contextWindow": 32768,
    "timeoutMs": 120000
  },
  "permissions": {
    "autoApprove": [
      "read_file",
      "grep_search",
      "glob_find",
      "todo"
    ],
    "promptOn": [
      "shell",
      "write_file",
      "edit_file"
    ]
  },
  "tools": {
    "shellTimeoutMs": 60000,
    "maxFileSizeReadBytes": 40960
  }
}
```

---

## 4. SQLite Persistence Schema

Fox stores session history, message parts, and task states in a local embedded SQLite database.
- **Database Path**:
  - User Global: `~/.fox/fox.db`
  - Workspace Override (optional): `<cwd>/.fox/session.db`

### Relational Schema

```sql
-- Sessions table
CREATE TABLE IF NOT EXISTS sessions (
    id TEXT PRIMARY KEY,
    cwd TEXT NOT NULL,
    title TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
);

-- Messages table (user, assistant, system)
CREATE TABLE IF NOT EXISTS messages (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    role TEXT NOT NULL CHECK(role IN ('system', 'user', 'assistant')),
    created_at INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

-- Message parts (text, reasoning, tool calls, tool results)
CREATE TABLE IF NOT EXISTS parts (
    id TEXT PRIMARY KEY,
    message_id TEXT NOT NULL,
    type TEXT NOT NULL CHECK(type IN ('text', 'reasoning', 'tool_call', 'tool_result')),
    content TEXT NOT NULL,
    metadata JSON,
    created_at INTEGER NOT NULL,
    FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- Active todo tasks per session
CREATE TABLE IF NOT EXISTS todos (
    id TEXT PRIMARY KEY,
    session_id TEXT NOT NULL,
    text TEXT NOT NULL,
    status TEXT NOT NULL CHECK(status IN ('pending', 'in_progress', 'done')),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE
);

-- Indices for fast retrieval
CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id);
CREATE INDEX IF NOT EXISTS idx_parts_message ON parts(message_id);
CREATE INDEX IF NOT EXISTS idx_todos_session ON todos(session_id);
```

---

## 5. Exit Codes & Error Handling

Fox CLI adheres to standard Unix exit codes:

| Exit Code | Name | Description |
|---|---|---|
| `0` | `SUCCESS` | Command completed successfully. |
| `1` | `GENERAL_ERROR` | Runtime failure or unexpected exception. |
| `2` | `USAGE_ERROR` | Invalid arguments or command flags. |
| `10` | `MODEL_UNREACHABLE` | Local model endpoint (`localhost:8000`) connection refused or timeout. |
| `11` | `TOOL_PERMISSION_DENIED` | Required tool was rejected by user or policy. |
| `130` | `CANCELLED` | Execution interrupted by user (`Ctrl+C` / `SIGINT`). |
