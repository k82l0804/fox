# Spec 05: Agent Core & Tool Engine

> Technical specification for the Fox CLI autonomous reasoning loop, prompt engineering, context management, and built-in tools.

---

## 1. Agent Reasoning Loop (ReAct Engine)

Fox CLI executes an autonomous **ReAct (Reason + Act)** cycle. The engine iteratively gathers context, queries the local LLM, dispatches requested tools, observes results, and determines whether the goal is satisfied.

### Execution Flowchart

```
┌────────────────────────────────────────────────────────┐
│                   User Prompt Received                 │
└───────────────────────────┬────────────────────────────┘
                            │
                            ▼
               ┌────────────────────────┐
               │ Assemble Prompt Context │
               │ (System + Rules + Hist)│
               └────────────┬───────────┘
                            │
                            ▼
               ┌────────────────────────┐
               │    Local LLM Stream    │◄─────────────────────────┐
               │   (OpenAI /v1/chat)    │                          │
               └────────────┬───────────┘                          │
                            │                                      │
              Tool Calls?   │   Finished Response?                 │
             ┌──────────────┴──────────────┐                       │
             │                             │                       │
             ▼                             ▼                       │
   ┌───────────────────┐         ┌───────────────────┐             │
   │ Evaluate Security │         │ Emit Final Text   │             │
   │   & Permissions   │         │ Complete Session  │             │
   └─────────┬─────────┘         └───────────────────┘             │
             │                                                     │
             ▼                                                     │
   ┌───────────────────┐                                           │
   │   Dispatch Tool   │                                           │
   │ (Built-in or MCP) │                                           │
   └─────────┬─────────┘                                           │
             │                                                     │
             ▼                                                     │
   ┌───────────────────┐                                           │
   │ Append Tool Result│                                           │
   │  to Conversation  ├───────────────────────────────────────────┘
   └───────────────────┘
```

### Loop Guards & Termination Criteria
To ensure local models do not fall into infinite loops or burn CPU cycles indefinitely:
1. **`maxSteps` (Default: 25)**: Caps the maximum number of consecutive tool iterations per user prompt.
2. **Doom Loop Detection**: If the agent attempts the exact same tool call with identical arguments 3 consecutive times with an error, execution is halted and the error is surfaced to the user.
3. **Graceful Cancellation**: Every iteration checks the session `AbortSignal`. If cancelled by the user (or ACP client), execution terminates immediately.

---

## 2. Prompt Architecture for Local Models

Local models (8B to 32B parameters) require clear, concise system prompts without superfluous prose or conflicting directives.

### Prompt Components
1. **Role Definition**: Senior autonomous software engineer working strictly within the designated workspace.
2. **Behavioral Rules**:
   - Always inspect files before editing (`read_file`, `grep_search`).
   - Prefer surgical edits (`edit_file`) over rewriting large files.
   - Use `todo` to organize tasks when handling multi-step requests.
   - Never run unbounded destructive commands without explicit instruction.
3. **Workspace Instructions**: Automatically injects content from:
   - `FOX.md` or `.fox/rules.md` (Fox-specific project guidelines).
   - `AGENTS.md` (Generic agent guidelines in the repo).
4. **Tool Definitions**: Concise JSON function schemas for all active tools.

---

## 3. Core Built-in Tools

Fox CLI provides 7 essential built-in tools tailored for developer workflows:

### 3.1. `read_file`
Reads file contents with line numbers and slicing to prevent context window overflow.
```typescript
{
  name: "read_file",
  description: "Read text contents of a file with line numbers",
  parameters: {
    type: "object",
    properties: {
      path: { type: "string", description: "Relative path to file" },
      startLine: { type: "integer", description: "1-indexed start line (optional)" },
      endLine: { type: "integer", description: "1-indexed end line (optional)" }
    },
    required: ["path"]
  }
}
```
*Guard*: Outputs larger than 32 KB are truncated with a warning notice prompting the agent to read in smaller line slices.

### 3.2. `write_file`
Creates or replaces an entire file. Automatically creates any missing parent directories.
```typescript
{
  name: "write_file",
  description: "Write full text content to a file",
  parameters: {
    type: "object",
    properties: {
      path: { type: "string", description: "Relative path to file" },
      content: { type: "string", description: "Full content to write" }
    },
    required: ["path", "content"]
  }
}
```

### 3.3. `edit_file`
Performs surgical search-and-replace edits. Verifies that `oldString` exists uniquely in the file before applying `newString`.
```typescript
{
  name: "edit_file",
  description: "Replace exact string match in an existing file",
  parameters: {
    type: "object",
    properties: {
      path: { type: "string", description: "Relative path to file" },
      oldString: { type: "string", description: "Exact character sequence to replace" },
      newString: { type: "string", description: "Replacement string" }
    },
    required: ["path", "oldString", "newString"]
  }
}
```

### 3.4. `shell`
Executes bash/sh commands in the workspace directory.
```typescript
{
  name: "shell",
  description: "Execute a shell command in the project root",
  parameters: {
    type: "object",
    properties: {
      command: { type: "string", description: "The shell command line to execute" },
      timeoutMs: { type: "integer", description: "Timeout in milliseconds (default: 60000)" }
    },
    required: ["command"]
  }
}
```
*Features*: Streams stdout/stderr in real-time, supports SIGINT cancellation, and sanitizes dangerous interactive prompts.

### 3.5. `grep_search`
Fast recursive regex or literal search using `ripgrep` (bundled or system) with line numbers and file paths.
```typescript
{
  name: "grep_search",
  description: "Search workspace for pattern or regex match",
  parameters: {
    type: "object",
    properties: {
      query: { type: "string", description: "Search query or regex" },
      caseInsensitive: { type: "boolean" },
      includePattern: { type: "string", description: "Glob to filter files (e.g. '*.ts')" }
    },
    required: ["query"]
  }
}
```

### 3.6. `glob_find`
Finds files matching glob patterns, automatically ignoring `.git`, `node_modules`, `dist`, and binaries.
```typescript
{
  name: "glob_find",
  description: "Find file paths in project matching a pattern",
  parameters: {
    type: "object",
    properties: {
      pattern: { type: "string", description: "Glob pattern (e.g. 'src/**/*.tsx')" }
    },
    required: ["pattern"]
  }
}
```

### 3.7. `todo`
Interactive task checklist manager. Helps local models maintain plan state across multiple reasoning turns.
```typescript
{
  name: "todo",
  description: "Update the session task list",
  parameters: {
    type: "object",
    properties: {
      action: { type: "string", enum: ["list", "add", "update", "clear"] },
      id: { type: "string" },
      text: { type: "string" },
      status: { type: "string", enum: ["pending", "in_progress", "done"] }
    },
    required: ["action"]
  }
}
```

---

## 4. Context Window Compaction & Memory Strategy

Because local models have limited context budgets (typically 16k to 32k tokens), Fox enforces strict context pruning:

### Compaction Rules
1. **Trigger Condition**: When cumulative token count exceeds 80% of `contextWindow`.
2. **Trimming Historical Tool Outputs**:
   - Previous tool outputs from turns older than 3 steps are replaced with compact stub lines:
     `[Tool output from 'read_file(src/index.ts)' (1,240 tokens) omitted; status: success]`.
3. **Summarization Turn**:
   - If trimming outputs is insufficient, Fox runs a fast background summarization call:
     *"Summarize the key architectural discoveries and modifications made so far."*
   - Older conversational turns are replaced with the generated summary checkpoint.
4. **Never Truncated**:
   - System prompt & project rules (`FOX.md`).
   - Current user prompt.
   - The active `todo` list.
   - The most recent 2 conversation turns.

---

## 5. Security & Permission Evaluation

Tools are classified into three safety tiers:

| Tier | Category | Tools | Default Behavior |
|---|---|---|---|
| **Tier 1: Read-Only** | Information gathering | `read_file`, `grep_search`, `glob_find`, `todo` | Auto-approved |
| **Tier 2: Modification** | Workspace file changes | `write_file`, `edit_file` | Prompts for approval by default; bypassed with `--yes` flag |
| **Tier 3: Execution** | Arbitrary code execution | `shell`, external MCP tools | Prompts user for approval via ACP `requestPermission` or terminal prompt |

Users can customize auto-approval rules in `.fox/config.json`:
```json
{
  "permissions": {
    "autoApprove": ["read_file", "grep_search", "glob_find", "todo", "edit_file"],
    "promptOn": ["shell"]
  }
}
```
