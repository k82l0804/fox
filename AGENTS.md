# Fox Workspace — Agent Instructions

## Shell Execution & Anti-Hang Rules (CRITICAL)

To prevent terminal commands from hanging, deadlocking, or overflowing console buffers, all agents must strictly follow these rules:

### 1. Non-Interactive Execution Only
- **Never trigger interactive prompts:** Run all shell operations in non-interactive/headless mode.
- **Git credentials:** ALWAYS prefix git commands with `GIT_TERMINAL_PROMPT=0` to prevent git from blocking indefinitely on credential or SSH prompts.
- **Tests:** Always run tests non-interactively with `CI=true` (e.g. `CI=true bun test ...`). Never run test runners in watch mode (`--watch`).
- **Interactive TUI / CLI:** NEVER run `bun run dev` or bare `bun ./src/index.ts` without subcommands. These launch the interactive OpenTUI terminal interface which blocks waiting for keyboard input. Always pass explicit subcommands or flags (e.g. `bun ./src/index.ts --help`, `bun ./src/index.ts db path`).
- **Network commands:** Always specify explicit connect/read timeouts (e.g. `nc -w 2 -zv host port`, `curl -m 10`). Unbounded network commands will stall if a port is unreachable.
- **Docker commands:** Avoid commands with large streaming output (e.g. raw `docker images`); use `docker compose ps` or `docker stats --no-stream` instead.

### 2. Timeouts Scaled to the Task
Prefix long-running execution tasks, test suites, and builds with the Linux `timeout` command to establish a guaranteed safety ceiling against hangs. Scale the timeout appropriately to the operation:
- **Fast unit / category tests:** `timeout 30s bun run test:patch` (or `test:edit`, `test:config`)
- **Typecheck:** `timeout 45s bun run typecheck`
- **Smoke test suite:** `timeout 60s bun run test:smoke`
- **Monorepo build:** `timeout 60s bun run build`
- **Full test suite:** `timeout 180s bun run test`

*(Note: Do not use an overly aggressive timeout like 5s for builds or typechecks; monorepo compilation requires 15–30s under normal operation.)*

### 3. Tool-First Search & File Operations
- **Prefer built-in agent tools:** Use `grep_search` for code/text search and `view_file` for inspecting files. Built-in tools are faster, safely capped, respect `.gitignore`, and will never hang on circular symlinks.
- **Never run raw recursive traversals:** NEVER run unconstrained `find .` or `grep -r` from the workspace root. They traverse `node_modules/`, `.git/`, circular symlinks, and build artifacts, which will crash or hang the terminal.
- **When shell search is necessary:**
  - Finding files by pattern: `git ls-files "pattern*"`
  - Finding text in git files: `git grep "search_term"`
- **Large output management:** If a command generates high-volume output (e.g. full test suites or logs >50 lines), redirect stdout/stderr to `/tmp/` (e.g. `> /tmp/test_run.log 2>&1`) instead of cluttering the workspace or terminal buffer. Inspect the log using `tail` or `view_file`.

### CRITICAL: Code Modification Tooling Rules
When making multi-file edits, complex refactors, or parsing diagnostic logs (like typecheck/linter outputs), do not use `sed`, `awk`, or `grep` for code manipulation. 

You must automatically write and execute a temporary Python script (`bash -c "python3 script.py"`) if any of the following conditions are met:
1. Multi-line matching: The change requires modifying code across multiple lines that standard regex cannot safely capture.
2. Log Parsing: You need to parse a tool's compiler/linter output (e.g., TypeScript/Python typecheck logs) to find specific filenames, line numbers, and errors to apply targeted fixes.
3. Multi-file synchronization: A variable, import, or type definition change needs to be synchronized identically across 3 or more files.
4. Escaping hell: The replacement string contains a mix of single quotes, double quotes, backticks, and regex characters that would require excessive escaping in `sed`.

Always choose Python over `sed`/`awk` when these conditions apply. Ensure the temporary script self-terminates cleanly.

### 4. Working Directory
- Set the command working directory explicitly via tool arguments (`Cwd`) or chain with `&&` within a subshell.

---

## Repository Layout
```
fox/
├── fox-code-cli/         # Main TypeScript monorepo — Bun runtime
│   ├── src/              # Application source (alias: @/*)
│   ├── packages/         # Internal packages (see aliases below)
│   └── package.json      # name: @fox/cli  version: 0.1.0
├── fox-acp-client/       # VSCode extension — ACP client (Preact, JSON-RPC 2.0)
├── openai-proxy/         # LiteLLM Docker proxy → Gemini (http://localhost:8000/v1)
└── gitlab/               # GitLab CE Docker — FOR FOX CLI TESTING ONLY (not fox source control)
```

**Source control for fox itself:** GitHub at `https://github.com/k82l0804/fox.git` — never push fox code to the local GitLab.

---

## Key Commands (all run inside `fox-code-cli/`)
```bash
bun run typecheck         # Full monorepo type check (tsc --noEmit)
bun run build             # Build dist/ (Bun target, external packages)
bun run dev               # Run interactive TUI (= bun run ./src/index.ts) [MANUAL USE ONLY]
bun run test              # Full test suite: typecheck + all packages + app tests
bun run test:smoke        # Quick smoke: typecheck + patch + edit + config (~30s)
```

```bash
# In openai-proxy/
make up            # Start LiteLLM proxy (OPENAI_BASE_URL=http://localhost:8000/v1, key=local-dev)
make health
make test

# In gitlab/
make up            # Start GitLab CE (http://localhost:8929, SSH :2222)
make root-password # Initial root password
make create-token  # Creates glpat-fox-local-dev-token-12345 for root
make health
make down
```

---

## Testing (`fox-code-cli/`)

See `.agents/rules/fox-cli-testing.md` for full testing rules, coverage tables, and per-package commands.

```bash
bun run test:smoke        # Quick smoke: typecheck + patch + edit + config (~30s)
bun run test              # Full test suite: typecheck + all packages + app tests (~60s)
bun run test:patch        # Patch parser & application
bun run test:edit         # Edit tool replacers + encoding
bun run test:config       # Config merge & utilities
bun run test:app          # All app-level tests (test/)
```

---

## Package Aliases (tsconfig paths)
| Alias | Location |
|---|---|
| `@/*` | `src/*` |
| `@opencode-ai/core` | `packages/core/src/` |
| `@opencode-ai/llm` | `packages/llm/src/` |
| `@opencode-ai/schema` | `packages/schema/src/` |
| `@opencode-ai/server` | `packages/server/src/` |
| `@opencode-ai/tui` | `packages/tui/src/` |
| `@foxcode/sdk` | `packages/sdk/src/` |
| `@foxcode/plugin` | `packages/plugin/src/` |
| `@foxcode/sandbox` | `packages/sandbox/src/` |
| `@foxcode/memory` | `packages/fox-memory/src/` |
| `@foxcode/indexing` | `packages/fox-indexing/src/` |

---

## Architectural Rules (must follow these, no exceptions)

### 1. Tool Architecture (`packages/core/src/tool/`)
- `tool.ts` → canonical `Tool.make(...)` (opaque, do not bypass)
- `tools.ts` → `Tools.Service` for Location-scoped producers
- `application-tools.ts` → process-scoped tools
- Built-ins register via `Tools.Service.register(...)`; Location-scoped registrations **override** application ones.
- Do not make `ToolRegistry.Service` process-global.

### 2. HttpApi Routes (`src/server/routes/instance/httpapi/`)
- Use `HttpApiBuilder.group(...)`. Yield stable services once when building handler layers; close over them in endpoints.
- SSE streams: return `HttpServerResponse.stream(...)`, annotate with `HttpApiSchema.asText({ contentType: "text/event-stream" })`.
- **Never** `Effect.provide(Layer)` inside request handlers.

### 3. Session LLM (`src/session/llm/`)
- `src/session/llm.ts` orchestrates auth, config, and runtime selection.
- Default runtime: AI SDK (`ai-sdk.ts`). Native runtime opt-in: `KILO_EXPERIMENTAL_NATIVE_LLM=true`.
- Both runtimes converge on `@opencode-ai/llm` `LLMEvent` streams.
- `native-request.ts` is the **only** adapter allowed to construct `@opencode-ai/llm` requests/parts.

### 4. Database (`packages/effect-drizzle-sqlite`)
- Keep generic: no domain tables, migrations, or fox-specific APIs here.
- Depend on `SqlClient`, not concrete SQLite drivers.

### 5. Config (`src/foxcode/config/config.ts`)
- Config files in precedence order: `fox.jsonc`, `fox.json`, `kilo.jsonc`, `kilo.json`, `opencode.jsonc`, `opencode.json`
- Config directory suffixes (preferred update-target order): `.fox`, `.kilo`, `.kilocode`
- State stored in: `~/.local/state/fox/kv.json` and `~/.local/share/fox/`

### 6. Plugin System (`src/plugin/index.ts`)
- Internal plugins run sequentially before external plugins.
- `GitlabAuthPlugin` is a stub (local GitLab provider auth is via `GITLAB_TOKEN` env var).
- External plugins loaded from `cfg.plugin_origins`; skip when `--pure` flag is set.

---

## GitLab Local Testing Environment
- **Purpose:** Test Fox CLI's GitLab provider, PR/MR linking, and worktree workflows only.
- **Web:** `http://localhost:8929` | **SSH:** `localhost:2222`
- **Token:** `glpat-fox-local-dev-token-12345` (root user, full API access)
- **Test Repo:** `root/fox-test-repo` (project ID `1`) at `http://localhost:8929/root/fox-test-repo`
- **Fox PR detection for local GitLab:** Auto-detection only works for `github.com`. For local GitLab, use `fox pr link <mr-url>` explicitly.
- **Environment vars for Fox CLI → local GitLab:**
  ```bash
  GITLAB_INSTANCE_URL=http://localhost:8929
  GITLAB_TOKEN=glpat-fox-local-dev-token-12345
  ```
- `fox pr checkout <N>` for GitLab requires the `glab` CLI — not installed; use `fox pr link <url>` instead.
