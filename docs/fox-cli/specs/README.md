# Fox CLI Specifications

> Design specifications for **Fox CLI** — a lean, modular, local-first AI coding agent CLI and ACP server derived from Kilo Code CLI.

---

## 1. Context & Motivation

Fox is an open-standard AI coding assistant consisting of two components:
1. **Fox Code CLI** (`fox/fox-code-cli/`): An ACP-compatible agent server and standalone CLI, based on the architecture of [Kilo Code CLI (`kilocode`)](https://github.com/Kilo-Org/kilocode).
2. **Fox ACP Client** (`fox/fox-acp-client/`): A VSCode extension (and general ACP client), based on `vscode-acp`.

While Kilo Code CLI provides a battle-tested agent loop, rich ACP server implementation, MCP client support, and an internal REST API, it carries substantial complexity:
- Over 20+ internet frontier model providers (Anthropic, Bedrock, Vertex, Google, Azure, Mistral, Groq, Cerebras, Cohere, DeepInfra, Alibaba, GitLab, Venice, xAI, OpenRouter, etc.).
- Complex cloud authentication mechanisms (AWS STS credentials, GCP Application Default Credentials, GitLab tokens, OAuth flows).
- Dynamic remote model registry sync (`models.dev`), token billing, and gateway proxies.
- Cloud telemetry, remote analytics, and proprietary memory services.

**Fox CLI is engineered specifically for local-first, privacy-preserving, and offline environments.** It extracts the core agentic reasoning engine, ACP protocol support, MCP client subsystem, and headless REST server while eliminating all external cloud dependencies in favor of a single, robust **OpenAI-compatible local model integration** (`http://localhost:8000/v1` default).

---

## 2. Specification Document Index

| Spec Document | Title | Scope & Description |
|---|---|---|
| [**01-architecture-overview.md**](./01-architecture-overview.md) | **Architecture Overview & Upstream Delta** | High-level system architecture, component topology, comparison with Kilo CLI (kept vs. pruned vs. adapted), technology stack, and directory structure. |
| [**02-local-model-subsystem.md**](./02-local-model-subsystem.md) | **Local Model Subsystem** | OpenAI-compatible local model provider specification, endpoint routing, fallback behavior, streaming handling, and context window limits for local LLMs (Ollama, vLLM, LM Studio, `openai-proxy`). |
| [**03-acp-server.md**](./03-acp-server.md) | **ACP Server Specification** | Agent Client Protocol (JSON-RPC 2.0 over `stdio`) server implementation, session lifecycle, client-driven permissions, bidirectional streaming, and VSCode extension integration. |
| [**04-mcp-client.md**](./04-mcp-client.md) | **MCP Client Subsystem** | Model Context Protocol client implementation, transport layers (`stdio`, `sse`, `streamableHttp`), dynamic ACP session registration, tool/resource discovery, and security boundaries. |
| [**05-agent-core-and-tools.md**](./05-agent-core-and-tools.md) | **Agent Core & Tool Engine** | Iterative agent reasoning loop, prompt composition, tool dispatch, core built-in tools (`read`, `write`, `edit`, `shell`, `grep`, `glob`, `todo`), and permission evaluator. |
| [**06-rest-api-server.md**](./06-rest-api-server.md) | **REST API & Headless Server** | HTTP REST & SSE/WebSocket server (`fox serve`), OpenAPI-aligned routes for sessions, messages, models, MCP servers, and health checks. |
| [**07-cli-interface-and-config.md**](./07-cli-interface-and-config.md) | **CLI Interface, Storage & Config** | Command-line UX (`fox acp`, `fox run`, `fox serve`, `fox mcp`, `fox models`, `fox config`), SQLite schema, and configuration hierarchy. |

---

## 3. Guiding Principles

1. **Local-First & Offline**: Never make outbound network calls to cloud LLM providers, analytics services, or proprietary backends. All LLM traffic routes through OpenAI-compatible local endpoints.
2. **Protocol Compatibility**: Maintain strict compliance with standard **Agent Client Protocol (ACP)** and **Model Context Protocol (MCP)** specifications.
3. **Simplicity & Maintainability**: Favor clean, readable TypeScript with explicit dependencies. Avoid sprawling monorepos and unnecessary indirection.
4. **Fast Startup & Low Footprint**: Minimize initialization overhead and idle memory footprint, ensuring responsive invocation when spawned by editor clients.
