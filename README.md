# 🦊 Fox

> An AI agent CLI and VSCode extension pair built on open standards.

Fox is a two-part project:

| Package | Directory | Description |
|---|---|---|
| **Fox Code CLI** | `fox/fox-code-cli/` | A TypeScript agent CLI — an ACP-compatible agent server, based on [Kilo-Org/kilocode](https://github.com/Kilo-Org/kilocode) |
| **Fox ACP Client** | `fox/fox-acp-client/` | A VSCode extension that acts as an ACP client — based on [formulahendry/vscode-acp](https://github.com/formulahendry/vscode-acp) |

The two components communicate over the **Agent Client Protocol (ACP)** — JSON-RPC 2.0 over `stdio`, the emerging standard for connecting AI agents to editors ("LSP for AI agents"). See [agentclientprotocol.com](https://agentclientprotocol.com).

---

## How They Fit Together

```
┌─────────────────────────────────┐        stdio / JSON-RPC 2.0
│        VSCode Editor             │  ◄────────────────────────────►  Fox Code CLI
│   Fox ACP Client (Extension)     │                                  (ACP server)
│   fox/fox-acp-client/            │                                  fox/fox-code-cli/
└─────────────────────────────────┘
```

- **Fox Code CLI** (`fox/fox-code-cli/`) is the **ACP server** — it handles AI reasoning, tool execution, and agentic tasks. Users install it as a standalone CLI tool.
- **Fox ACP Client** (`fox/fox-acp-client/`) is the **ACP client** — it manages the VSCode UI (chat panel, file diffs, terminal integration) and spawns the CLI as a child process to communicate over `stdio`.
- The two are **distributed separately** — the extension detects or prompts the user to install the CLI.

---

## Repository Layout

```
fox/
├── fox-code-cli/         # Fox Code CLI — TypeScript ACP agent server
├── fox-acp-client/       # Fox ACP Client — VSCode extension (ACP client)
├── openai-proxy/         # Dev/test proxy: Google Gemini behind an OpenAI-compatible API
│   ├── docker-compose.yml
│   ├── litellm_config.yaml
│   ├── Makefile
│   └── scripts/          # health-check, list-models, test-chat, test-streaming
├── docs/
│   ├── architecture.md   # High-level system architecture & design decisions
│   ├── specs/            # Detailed component specifications (01–07)
│   ├── plans/            # Implementation plans
│   ├── research/         # Upstream reference notes
│   └── reviews/          # Review notes & handoff docs
└── README.md             # ← you are here
```

---

## External Reference Repos

These upstream projects are studied for architecture and implementation patterns. They will be cloned locally for reference.

### Fox Code CLI upstream — Kilo Code CLI
- **Repo:** [Kilo-Org/kilocode](https://github.com/Kilo-Org/kilocode)
- **CLI path in monorepo:** `packages/cli/`
- **ACP entrypoint:** `kilo acp` (spawnable ACP server)
- **Docs:** [kilo.ai/docs/cli](https://kilo.ai/docs/cli)

### Fox ACP Client upstream — vscode-acp
- **Repo:** [formulahendry/vscode-acp](https://github.com/formulahendry/vscode-acp)
- TypeScript/Node.js, multi-agent support, chat UI, session management, JSON-RPC 2.0 over stdio
- **Protocol spec:** [agentclientprotocol/agent-client-protocol](https://github.com/agentclientprotocol/agent-client-protocol)
- **Agent registry:** [ACP Registry JSON](https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json)

---

## Local Model Proxy (Dev / Test)

Fox is designed for **offline / local-first use** — the CLI and ACP client talk only to locally-hosted models via the OpenAI-compatible API (`http://localhost:8000/v1`). On a machine without a local GPU, the `openai-proxy/` Docker service simulates this by routing requests to Google Gemini behind the scenes.

### Model Mapping

| Model name (used by Fox) | Backed by in dev | Character |
|---|---|---|
| `gpt-4o-mini` | Gemini 3.6 Flash | Fast — default for most tasks |
| `gpt-4o` | Gemini 3.1 Pro Preview | Smart — complex reasoning |

> **In production**, swap `litellm_config.yaml` to point at a real local model (Ollama, vLLM, LM Studio, etc.) — zero application code changes needed.

### Quick Start

```bash
cd openai-proxy/
cp .env.example .env
# Edit .env — paste your GEMINI_API_KEY (https://aistudio.google.com/apikey)
make up
```

### Test Scripts

```bash
# from openai-proxy/scripts/
./health-check.sh              # verify proxy is alive
./list-models.sh               # show registered model names
./test-chat.sh                 # smoke-test both models (non-streaming)
./test-chat.sh gpt-4o-mini     # test a specific model
PROMPT="Write a haiku" ./test-chat.sh   # custom prompt
./test-streaming.sh            # test SSE streaming
```

### Using the Proxy from Application Code

Any OpenAI SDK client just needs these two env vars:

```bash
export OPENAI_BASE_URL=http://localhost:8000/v1
export OPENAI_API_KEY=local-dev
```

See [`openai-proxy/README.md`](openai-proxy/README.md) for full details.

---

## Build Roadmap

Work is sequenced: **CLI first, then the VSCode extension**.

| Phase | Status | Description |
|---|---|---|
| 1. Clone reference repos | ✅ Done | Cloned `kilocode` and `vscode-acp` locally in `ext-repo/` |
| 2. Architecture doc & Specs | ✅ Done | Wrote `docs/architecture.md` and complete specifications in `docs/specs/` |
| 3. Plan & todo list | ✅ Done | Wrote detailed implementation plan in `docs/plans/cli-implementation-plan.md` |
| 4. Build Fox Code CLI | ✅ Done | Ported Kilo Code CLI: strictly local inference, zero cloud dependencies, verified headless and interactive TUI |
| 5. Build Fox ACP Client | 🔲 In Progress | Implement `fox/fox-acp-client/` based on `vscode-acp` patterns |

---

## Fox Code CLI — Overview & Status

Fox Code CLI (`fox-code-cli/`) is fully ported, compiled, and verified. It provides **strictly local LLM inference** and an autonomous developer toolchain with **zero cloud dependencies**.

### Key Architectural Highlights

- **Strictly Local LLM Inference:** Built to connect with any OpenAI-compatible base URL (Docker LiteLLM proxy, Ollama, vLLM, LM Studio) without hardcoded endpoints or cloud subscriptions.
- **Stripped Cloud Gateways & Telemetry:** Removed all background catalog fetches (`models.dev`), cloud authentication loops, telemetry beacons, and remote gateway hooks.
- **Resilient Network Handling:** Reduced request timeouts from 5 minutes to 30 seconds and eliminated interactive desktop reconnection wait loops on offline ports.
- **Dual Execution Modes:**
  - **Interactive Terminal UI (`fox`):** Powered by OpenTUI and SolidJS with full terminal layout, syntax rendering, prompt history, model badges, and slash commands (`/exit`, `/help`).
  - **Headless & Autonomous (`fox run`):** Direct command-line prompt execution with support for autonomous tool approval (`--auto`).
- **Agent Server Protocol:** Implements ACP (`fox acp`) over `stdio` for integration with VSCode and editor clients.
- **Flexible Configuration:** Supports `fox.json` and `fox.jsonc` (project root and `.fox/` directory) with full backward compatibility for `opencode.json` and `kilo.json`.

### CLI Commands & Usage

The CLI binary `fox` is installed at `~/.local/bin/fox` and repository root:

```bash
# Start the interactive OpenTUI terminal interface
fox

# Run a headless query and stream output directly to terminal
fox run "What is 3 * 7? Answer in one word."

# Run headless with autonomous tool approval (file edits, terminal commands)
fox run "Create hello.txt with 'Hello from Fox', then verify it" --auto

# Manage Model Context Protocol (MCP) servers
fox mcp list
fox mcp add <name>

# Start the ACP server for editor/extension connection
fox acp
```

### Configuration (`fox.json`)

Configure your local LLM provider in `fox.json` (or `~/.config/fox/fox.json`):

```json
{
  "$schema": "https://opencode.ai/config.json",
  "model": "local/my-model",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local LLM",
      "options": {
        "baseURL": "http://localhost:8000/v1",
        "apiKey": "local-dev"
      },
      "models": {
        "my-model": {
          "id": "gpt-4o-mini",
          "name": "Local Proxy Model",
          "tools": true
        }
      }
    }
  }
}
```

### Verification & Testing Highlights

- **TypeScript Compilation:** Monorepo builds with **0 errors** on Bun.
- **Headless Prompt Execution:** Verified streaming responses against the local Docker proxy.
- **Autonomous Tool Execution:** Verified creating, writing, and reading files locally via agent tools.
- **Interactive OpenTUI:** Verified interactive prompt submission, model metadata badge display, and clean session exit in real terminal.

---

## Prerequisites

- Node.js 20+
- TypeScript
- VSCode (for extension development)
- Docker + Docker Compose (for `openai-proxy/` dev environment)

---

## Contributing

This is a new project — contribution guidelines will be added after the initial architecture is settled.

---

## License

TBD
