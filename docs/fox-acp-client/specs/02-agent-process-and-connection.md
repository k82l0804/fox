# Spec 02: Agent Process & Connection Subsystem

> Technical specification for locating, spawning, supervising, and communicating with the Fox Code CLI agent process over stdio.

---

## 1. Overview & Role

The **Agent Process & Connection Subsystem** manages the physical execution lifecycle of the underlying agent server process (`fox acp`) and establishes the JSON-RPC 2.0 communication transport over standard input/output (`stdio`).

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Fox ACP Client Extension Host                            │
│                                                                             │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │                        BinaryResolver                                │  │
│   │   1. Check `fox.executablePath` setting                             │  │
│   │   2. Check Workspace `./bin/fox` or `./node_modules/.bin/fox`        │  │
│   │   3. Scan System `PATH` (`which fox` / `where fox.exe`)              │  │
│   └──────────────────────────────────┬───────────────────────────────────┘  │
│                                      │ Resolved Path                        │
│                                      ▼                                      │
│   ┌──────────────────────────────────────────────────────────────────────┐  │
│   │                       ProcessSupervisor                              │  │
│   │   - Spawns `fox acp --cwd <workspace>`                               │  │
│   │   - Monitors exit codes, crashes, & unhandled stderr                 │  │
│   │   - Handles SIGTERM / SIGKILL teardown                               │  │
│   └───────────────┬──────────────────────────────────────▲───────────────┘  │
│                   │ stdout / stdin                       │                  │
│                   ▼                                      │ Status Events    │
│   ┌──────────────────────────────────────────────────────┴───────────────┐  │
│   │                      ConnectionManager                               │  │
│   │   - Node Streams -> Web Streams (`Readable.toWeb`)                   │  │
│   │   - Bi-directional Traffic Tap (Log to Output Channel)               │  │
│   │   - `ClientSideConnection` (@agentclientprotocol/sdk)                │  │
│   │   - Handshake: `initialize({ protocolVersion: "0.21.0", ... })`      │  │
│   └──────────────────────────────────┬───────────────────────────────────┘  │
└──────────────────────────────────────┼──────────────────────────────────────┘
                                       │ stdio (JSON-RPC 2.0)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       Fox Code CLI Subprocess                               │
│                         `fox acp --cwd ...`                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Executable Discovery Strategy (`BinaryResolver`)

To provide an effortless developer experience, Fox ACP Client locates the `fox` CLI automatically without requiring manual configuration in the typical workflow.

### Precedence Hierarchy

1. **User Setting (`fox.executablePath`)**:
   - If non-empty, use the explicitly specified path.
   - If the path is relative, resolve it relative to the currently open workspace root.
   - Verify that the target file exists and is executable (`fs.constants.X_OK`).
2. **Workspace Local Binary**:
   - Check `<workspaceRoot>/bin/fox` (common in Fox development checkouts).
   - Check `<workspaceRoot>/node_modules/.bin/fox` (common in npm-managed workspaces).
3. **System `PATH`**:
   - Execute a PATH lookup across all directories in `process.env.PATH`.
   - On Linux/macOS: `which fox`.
   - On Windows: check `where.exe fox`, appending `.cmd` or `.exe` if missing.
4. **Fallback / Installation Prompt**:
   - If not found, display a notification:
     > `Fox CLI executable not found. Please install Fox or set "fox.executablePath" in settings.`
   - Provide actions: **Install Guide**, **Configure Path**, **Retry**.

### TypeScript Interface

```typescript
export interface BinaryResolutionResult {
  found: boolean;
  executablePath?: string;
  source?: "settings" | "workspace" | "path";
  version?: string;
  error?: string;
}

export class BinaryResolver {
  static async resolve(workspaceRoot?: string): Promise<BinaryResolutionResult>;
  static async validateBinary(executablePath: string): Promise<string | null>; // Returns version string
}
```

---

## 3. Process Spawning & Lifecycle (`ProcessSupervisor`)

Once resolved, the agent process is spawned as a child process using Node.js `child_process.spawn`.

### Spawn Configuration

```typescript
import { spawn, ChildProcess } from "node:child_process";

export interface SpawnOptions {
  executablePath: string;
  args?: string[];
  cwd: string;
  env?: Record<string, string>;
}

export function spawnAgentProcess(options: SpawnOptions): ChildProcess {
  const mergedEnv = {
    ...process.env,
    ...options.env,
    FOX_INVOKED_BY: "vscode-acp",
    FORCE_COLOR: "0", // Disable ANSI escape pollution on stdout
  };

  const args = options.args || ["acp", "--cwd", options.cwd];

  const child = spawn(options.executablePath, args, {
    cwd: options.cwd,
    env: mergedEnv,
    stdio: ["pipe", "pipe", "pipe"],
    windowsHide: true,
    detached: false,
  });

  return child;
}
```

### Stderr Handling & Diagnostics
- **`stdout`** is strictly reserved for JSON-RPC 2.0 messages.
- **`stderr`** is monitored for debug output, stack traces, and runtime warnings from Fox CLI.
- All stderr chunks are piped to the **Fox Output Channel** (`[Fox CLI Stderr] ...`).
- If the child process exits with a non-zero exit code, the last 50 lines of stderr are captured and displayed in a user error notification.

### Graceful Termination & Cleanup
When the user disconnects, closes the workspace, or reloads VSCode:
1. Extension sends ACP `cancel` RPC if an active turn is running.
2. Extension sends `SIGTERM` to the child process.
3. Supervisor starts a 3-second grace timer.
4. If the process has not terminated after 3 seconds, supervisor issues `SIGKILL`.
5. On Windows, `taskkill /pid <PID> /T /F` is used to ensure any spawned subprocesses (shell tools) are cleanly terminated.

---

## 4. Stdio Transport & Web Streams (`ConnectionManager`)

The Agent Client Protocol SDK (`@agentclientprotocol/sdk`) operates on standard Web Streams (`ReadableStream<Uint8Array>` and `WritableStream<Uint8Array>`).

### Stream Conversion

```typescript
import { Readable, Writable } from "node:stream";
import { ClientSideConnection, ndJsonStream, PROTOCOL_VERSION } from "@agentclientprotocol/sdk";
import type { Agent } from "@agentclientprotocol/sdk";
import type { Stream } from "@agentclientprotocol/sdk/dist/stream.js";

export function createAcpStream(process: ChildProcess): Stream {
  if (!process.stdout || !process.stdin) {
    throw new Error("Agent process missing stdio streams");
  }

  // Convert Node.js streams to standard Web Streams
  const readable = Readable.toWeb(process.stdout) as ReadableStream<Uint8Array>;
  const writable = Writable.toWeb(process.stdin) as WritableStream<Uint8Array>;

  return ndJsonStream(writable, readable);
}
```

### ClientSideConnection Factory Pattern

The ACP SDK's `ClientSideConnection` constructor requires a **factory function** that receives the `Agent` proxy (the handle for calling methods on the server) and returns the client implementation:

```typescript
// Create connection — factory receives the Agent proxy for server-side calls
const connection = new ClientSideConnection(
  (agent: Agent) => {
    client.setAgent(agent);  // Store agent proxy for reverse RPC calls
    return client;           // Return the Client implementation
  },
  tappedStream,
);
```

The `AcpClientImpl` must expose a `setAgent()` method to receive this proxy. This is critical because `connection.requestPermission` and other server-to-client interactions depend on the client having a reference to the agent object. See [Spec 04 §1](./04-client-capabilities-and-security.md) for the full `AcpClientImpl` interface.

### Protocol Traffic Logging (Tap Stream)
To facilitate debugging and protocol inspection, all outgoing requests and incoming responses/notifications pass through a non-blocking `TransformStream`:

```typescript
function tapStream(stream: Stream, logger: (direction: "send" | "recv", message: unknown) => void): Stream {
  const sendTap = new TransformStream({
    transform(chunk, controller) {
      logger("send", chunk);
      controller.enqueue(chunk);
    },
  });

  const recvTap = new TransformStream({
    transform(chunk, controller) {
      logger("recv", chunk);
      controller.enqueue(chunk);
    },
  });

  // IMPORTANT: Attach .catch() to prevent unhandled promise rejections
  // when the agent process exits or the pipe breaks unexpectedly.
  void sendTap.readable.pipeTo(stream.writable).catch(e => logError("Traffic tap send pipe error", e));
  void stream.readable.pipeTo(recvTap.writable).catch(e => logError("Traffic tap recv pipe error", e));

  return {
    writable: sendTap.writable,
    readable: recvTap.readable,
  };
}
```

The logger formats messages into the **Fox Protocol Traffic** output channel with clear visual markers:
- `[SEND Request #1] initialize`
- `[RECV Response #1] 200 OK`
- `[RECV Notification] sessionUpdate (agent_message_delta)`

---

## 5. Handshake & Initialization

Immediately upon establishing the transport, the client issues the ACP `initialize` RPC request.

### `initialize` Request Payload

> **Note:** The `protocolVersion` value is sourced from the `PROTOCOL_VERSION` constant exported by `@agentclientprotocol/sdk`, not hardcoded. The example below reflects the ACP v0.21.x series; the actual wire value evolves with the SDK.

```typescript
import { PROTOCOL_VERSION } from "@agentclientprotocol/sdk";
import { version as extensionVersion } from "../../package.json";

const initResponse = await connection.initialize({
  protocolVersion: PROTOCOL_VERSION, // SDK constant (e.g. "0.21.0")
  clientInfo: {
    name: "fox-acp-client",
    version: extensionVersion,
  },
  clientCapabilities: {
    fs: {
      readTextFile: true,
      writeTextFile: true,
    },
    terminal: true,
    elicitation: {
      form: {},   // Supports JSON Schema-driven form elicitation
      url: {},    // Supports URL-open elicitation with user consent
    },
  },
});
```

### `initialize` Response Ingestion
The client parses the server's `InitializeResponse`:
- **`agentInfo`**: Extracts agent name (`fox-cli`), title, and version.
- **`protocolVersion`**: Verifies protocol version compatibility (major version matches).
- **`capabilities`**: Discovers server capabilities:
  - `loadSession`: agent supports rehydrating historical sessions.
  - `listSessions`: agent supports enumerating prior workspace sessions.
  - `promptStreaming`: agent supports streaming text and tool deltas.
  - `mcpServers`: agent supports client-injected MCP server definitions.
  - `elicitation`: agent may emit `elicitation/create` requests; client advertised `form` and `url` support above.
- **`authMethods`**: Inspected for authentication requirements. Because Fox is local-first, `authMethods` is typically empty. If non-empty (e.g. when connecting to a remote ACP agent), the client triggers the interactive authentication modal.

### JSON-RPC Cancellation (`$/cancel_request`)
The client respects `$/cancel_request` notifications from the server to abort in-flight client-side operations (e.g., a permission dialog or elicitation form). Outstanding promises are rejected with an `AbortError`, and any open UI elements are dismissed.

---

## 6. Connection State Machine

The client connection transitions through well-defined lifecycle states:

```
  ┌──────────────┐
  │ Disconnected │◄────────────────────────┐
  └──────┬───────┘                         │
         │ connect()                       │ Error / Process Exit
         ▼                                 │
  ┌──────────────┐                         │
  │  Connecting  ├─────────────────────────┤
  └──────┬───────┘                         │
         │ initialize OK                   │
         ▼                                 │
  ┌──────────────┐                         │
  │  Connected   │                         │
  └──────┬───────┘                         │
         │ disconnect() / crash            │
         ▼                                 │
  ┌──────────────┐                         │
  │ Disconnecting├─────────────────────────┘
  └──────────────┘
```

### Auto-Reconnection & Error Recovery
- If the agent process exits unexpectedly while idle:
  - Status bar updates to **Disconnected (Unexpected Exit)**.
  - Chat panel displays a banner: `Agent process terminated unexpectedly (exit code: ${code}).`
  - A **Restart Fox Agent** action button is displayed.
- If the agent process exits while a prompt turn is in flight:
  - Active turn is marked as failed with the crash reason.
  - Partial assistant output is preserved in the chat history.
  - Auto-restart prompt is offered to the user.

---

## 7. Error Handling & Recovery

The connection subsystem defines the following error handling contracts:

### Process Spawn Failures
| Error Condition | Behavior |
|---|---|
| Binary not found (all resolution strategies exhausted) | Show notification with **Install Guide**, **Configure Path**, and **Retry** actions. Status bar shows `$(alert) Fox: Not Found`. |
| Binary found but not executable (`EACCES`) | Show error: `Fox binary at <path> is not executable. Check file permissions.` |
| Binary found but version check fails | Show warning: `Fox CLI version could not be verified. Attempting connection anyway.` |
| Spawn fails (`ENOENT`, `EPERM`, etc.) | Show error notification with the OS error message. Log full error to Fox Output Channel. |

### Protocol Handshake Failures
| Error Condition | Behavior |
|---|---|
| `initialize` RPC times out (>10s) | Terminate child process. Show: `Fox agent did not respond to initialization handshake.` |
| `initialize` returns incompatible protocol version | Show error: `Protocol version mismatch (client: ${ours}, server: ${theirs}). Update Fox CLI.` |
| Agent returns `authMethods` but user cancels auth | Disconnect cleanly. Show: `Authentication cancelled.` Status bar shows `Disconnected`. |

### Runtime Transport Failures
| Error Condition | Behavior |
|---|---|
| JSON-RPC parse error on `stdout` | Log the malformed message to Fox Output Channel. Skip the message; do not crash the connection. |
| `stderr` emits stack trace | Capture and display in Fox Output Channel. Do not surface to user unless process exits. |
| Pipe broken (`EPIPE` / stream close) | Transition to `Disconnected` state. Surface restart button. |

### Cleanup & Disposal

When the extension deactivates (workspace close, VSCode reload, or explicit disconnect), the following disposal chain executes in order:

1. Cancel any active agent turn via ACP `cancel` RPC.
2. Terminate the agent child process (SIGTERM → 3s grace → SIGKILL).
3. Dispose all `TerminalHandler` child processes and release pseudoterminals.
4. Clear all pending `DiffManager` reviews and dispose `TextDocumentContentProvider` registration.
5. Flush `HistoryStore` cache to `workspaceState`.
6. Close output channels (Fox Log, Fox Protocol Traffic).

All disposables are registered via `context.subscriptions.push(disposable)` during activation to ensure VSCode's built-in disposal lifecycle handles cleanup even on unexpected extension host crashes.
