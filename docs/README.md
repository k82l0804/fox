# 🦊 Fox Umbrella Documentation Hub

Welcome to the documentation library for the **Fox** repository.

Fox is an open-standard, local-first AI software engineering system comprising:
1. **Fox Code CLI** (`fox-code-cli/`): Autonomous SWE coding agent, terminal interface, and ACP server daemon.
2. **Fox ACP Client** (`fox-acp-client/`): VS Code extension implementing the Agent Client Protocol (JSON-RPC 2.0).
3. **Local Inference Proxy** (`openai-proxy/`): LiteLLM proxy routing local model requests.

---

## 🧭 Documentation Map

### 1. 🦊 Fox Code CLI (Active & Canonical Documentation)
All production architecture specifications, benchmarks, roadmaps, and execution handoffs for the CLI are actively maintained inside **[`fox-code-cli/docs/`](../fox-code-cli/docs/README.md)**:

- 📖 **[Documentation Hub (`fox-code-cli/docs/README.md`)](../fox-code-cli/docs/README.md)** — Master index for all CLI documentation.
- 🗺️ **[Strategic Roadmap v1.7.0 (`docs/future/`)](../fox-code-cli/docs/future/2026-09-21T06-12_plan-competitive-features-roadmap.md)** — Phased milestones, blueprints, and traceability ledger.
- 🏆 **[Challenge Ladder Benchmark Report (334 fixtures)](../fox-code-cli/docs/2026-09-22T15-54_fox-challenge-ladder-report.md)** — Master benchmark validation.
- 📊 **[Competitor Reports (`docs/reports/`)](../fox-code-cli/docs/reports/2026-09-23T09-38_competitive-benchmark-aider-goose-kilo.md)** — Empirical benchmarks and product feature analysis vs Aider, Goose, and Kilo.
- ⚙️ **[Daemon Architecture](../fox-code-cli/docs/2026-09-22T15-16_daemon-architecture.md)** — IPC client and background server specification.

### 2. 🔌 Fox ACP Client (VS Code Extension)
- **[Fox ACP Client Specs](./fox-acp-client/specs/README.md)** — ACP client architecture, chat webview, diff viewer, and connection manager.
- **[ACP Client Implementation Plan](./fox-acp-client/plans/acp-client-implementation-plan.md)** — Phased roadmap for the VS Code extension.

### 3. 🏛️ High-Level Umbrella Architecture
- **[Fox System Architecture](./fox-architecture.md)** — System vision, core tenets, and cross-package communication topology.
- **[Reproduction & Verification Guide](./reproduction-guide.md)** — Replication guide for the test suites and baseline scoreboards.

### 4. 🗄️ Historical & Pre-Fork Archive
- **[Archived Pre-Fork Specs & Plans](./archived/fox-cli/)** — Early conceptual specifications drafted prior to the Kilo Code fork. Preserved for historical context; superseded by active docs in `fox-code-cli/docs/`.
