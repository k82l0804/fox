## Kilo Code CLI — GitHub Repo & Docs

> **Important note:** The Kilo Code CLI is **not a separate repo**. It lives as a package inside the main monorepo.

### 📦 Repository

**Clone URL:**
```bash
git clone https://github.com/Kilo-Org/kilocode.git
```

- **Monorepo:** [Kilo-Org/kilocode](https://github.com/Kilo-Org/kilocode)
- **CLI package path:** `packages/cli/` (or `packages/opencode/`) inside the monorepo
- **Releases (prebuilt binaries):** [github.com/Kilo-Org/kilocode/releases](https://github.com/Kilo-Org/kilocode/releases)
- **npm package:** [`@kilocode/cli`](https://www.npmjs.com/package/@kilocode/cli)

### 📚 Documentation

| Resource | URL |
|---|---|
| CLI Overview | [kilo.ai/docs/cli](https://kilo.ai/docs/cli) |
| CLI Platform page | [kilo.ai/docs/code-with-ai/platforms/cli](https://kilo.ai/docs/code-with-ai/platforms/cli) |
| All Docs | [kilo.ai/docs](https://kilo.ai/docs) |
| Issues / Bug Reports | [github.com/Kilo-Org/kilocode/issues](https://github.com/Kilo-Org/kilocode/issues) |

### 🔗 ACP Relevance

Kilo Code CLI is an **ACP-compatible agent server** — it exposes an ACP endpoint via:
```bash
kilo acp
```
This is exactly what our VSCode ACP client extension would spawn as a child process and communicate with over JSON-RPC 2.0 / stdio. It's listed in the [official ACP Registry](https://cdn.agentclientprotocol.com/registry/v1/latest/registry.json), making it a great real-world target to test your client against.
