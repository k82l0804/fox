Perfect. Here's a comprehensive summary of the **Agent Client Protocol (ACP)** reference implementations relevant to building a VSCode extension:

---

## Agent Client Protocol (ACP) — Reference Implementations

**Protocol:** JSON-RPC 2.0 over `stdio` — think "LSP for AI coding agents"
**Official site:** [agentclientprotocol.com](https://agentclientprotocol.com)

---

### 🏛️ Core Protocol Repository

| Repo | Description |
|---|---|
| [agentclientprotocol/agent-client-protocol](https://github.com/agentclientprotocol/agent-client-protocol) | **The spec itself** — schemas, data models (Rust crates: `agent-client-protocol-schema` + `agent-client-protocol` runtime), and documentation |

---

### 🧩 VSCode Extension Implementations

| Repo | Description |
|---|---|
| [formulahendry/vscode-acp](https://github.com/formulahendry/vscode-acp) | **Most widely referenced** VSCode ACP client — TypeScript/Node.js, multi-agent support, chat UI, session management, JSON-RPC 2.0 over stdio |
| [gayanper/vscode-acp-provider](https://github.com/gayanper/vscode-acp-provider) | Experimental native VSCode chat session provider connecting external agent CLIs via ACP |
| [omercnet/vscode-acp](https://github.com/omercnet/vscode-acp) | Streamlined ACP chat client implementation for VSCode |

---

### 🗂️ Agent Registry (for discovering compatible agents)

| Resource | Description |
|---|---|
| [agentclientprotocol/registry](https://github.com/agentclientprotocol/registry) | The official curated registry of ACP-compatible agents (Claude Code, Gemini CLI, Codex CLI, GitHub Copilot CLI, Cline, Blackbox AI, etc.) |
| [Registry JSON index](https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json) | Live JSON endpoint — useful for your extension to enumerate available agents |

---

### 🔑 Key Technical Details for Your VSCode Extension

- **Transport:** `stdio` — spawn the agent as a child process
- **Protocol:** JSON-RPC 2.0 messages (requests, responses, notifications)
- **Roles:** VSCode = **client** (manages UI, file system, terminal), Agent = **server** (handles reasoning and tool execution)
- **TypeScript SDK:** Available in the core repo — the best starting point for a VSCode extension

---

### 💡 Recommendation

Start by studying **[formulahendry/vscode-acp](https://github.com/formulahendry/vscode-acp)** — it's the closest reference to what you're building (TypeScript, VSCode extension API, ACP client). Then cross-reference the protocol schema in the [core repo](https://github.com/agentclientprotocol/agent-client-protocol) for spec compliance.
