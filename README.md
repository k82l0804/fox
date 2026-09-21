# 🦊 Fox

> An autonomous, local-first AI coding agent ecosystem built on open standards, featuring **lossless tool token compression** (-52.3% to -76.4% context reduction), **stable KV-cache prefix retention**, and the **Agent Client Protocol (ACP)**.

[![Runtime: Bun](https://img.shields.io/badge/Runtime-Bun%201.2+-black.svg)](https://bun.sh/)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0+-blue.svg)](https://www.typescriptlang.org/)
[![Tests](https://img.shields.io/badge/Tests-309_Pass-brightgreen.svg)](fox-code-cli/README.md#testing)
[![Standard Test Suite](https://img.shields.io/badge/Standard_Suite-52_Golden_Fixtures-success.svg)](fox-code-cli/docs/fox-standard-test-suite-scoreboard.md)
[![Token Compression](https://img.shields.io/badge/Token_Savings-52.3%25_to_76.4%25-brightgreen.svg)](fox-code-cli/docs/fox-standard-test-suite-scoreboard.md)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> 📦 **Developer Quick Links**:
> - **CLI Engine & Architecture**: See the [**Fox Code CLI Guide (`fox-code-cli/README.md`)**](fox-code-cli/README.md) for package installation, CLI subcommands (`fox run`, `fox acp`), Effect TS decomposition, the 7 compression transforms, and the 5-tier testing suite.
> - **VS Code Extension**: See [**Fox ACP Client (`fox-acp-client/README.md`)**](fox-acp-client/README.md) for editor setup and Agent Client Protocol integration.

---

## 🌐 The Fox Ecosystem

Fox is an integrated, local-first AI developer ecosystem consisting of two primary components and two support services:

| Component | Directory | Purpose & Documentation |
|---|---|---|
| **Fox Code CLI** | [`fox-code-cli/`](fox-code-cli/README.md) | The autonomous TypeScript agent engine, ACP server, and OpenTUI interface. See [**Fox Code CLI README**](fox-code-cli/README.md) for package installation, CLI flags, Effect TS architecture, and development. |
| **Fox ACP Client** | [`fox-acp-client/`](fox-acp-client/README.md) | A companion VSCode extension implementing the Agent Client Protocol (ACP) for streaming chat, inline diffs, and editor integration. |
| **OpenAI Proxy** | [`openai-proxy/`](openai-proxy/README.md) | Local LiteLLM Docker container bridging local or cloud models to an OpenAI-compatible endpoint (`http://localhost:8000/v1`). |
| **Local GitLab** | [`gitlab/`](gitlab/README.md) | Local GitLab CE Docker environment for testing autonomous PR/MR creation and worktree isolation. |

---

## 🔌 Architecture: How They Fit Together

```
┌──────────────────────────────────────────────┐
│             VS Code Editor                   │
│        Fox ACP Client (Extension)            │
│            fox-acp-client/                   │
└──────────────────────┬───────────────────────┘
                       │
                       │  Agent Client Protocol (ACP)
                       │  JSON-RPC 2.0 over stdio
                       ▼
┌──────────────────────────────────────────────┐
│             Fox Code CLI                     │
│           fox-code-cli/                      │
│   • Autonomous Reasoning & Multi-turn Loop   │
│   • Lossless Tool Token Compression (LLTC)   │
│   • Effect TS Runtime & Instance Isolation   │
│   • Pure Local-First Models (LiteLLM/Ollama) │
└──────────────────────┬───────────────────────┘
                       │
                       │  OpenAI-compatible HTTP / SSE
                       ▼
┌──────────────────────────────────────────────┐
│          Local Model Provider                │
│    • openai-proxy/ (LiteLLM dev container)   │
│    • Ollama / vLLM / LM Studio               │
└──────────────────────────────────────────────┘
```

- **Standardized Protocol**: Communicates over the [Agent Client Protocol (ACP)](https://agentclientprotocol.com) — an open JSON-RPC 2.0 standard connecting AI agents to code editors ("LSP for AI agents").
- **Independent Distribution**: The extension and CLI are decoupled. Users can run Fox Code CLI as a standalone terminal application (`fox` / `fox run`) or pair it with VS Code via `fox acp`.
- **Zero Cloud Dependencies**: No proprietary cloud proxies, no remote telemetry, and zero mandatory third-party subscriptions.

---

## 🌟 Key Innovations

### 1. Lossless Tool Token Compression (LLTC)
Traditional agents blow out context windows by feeding raw Git outputs, massive lockfiles, and repetitive test logs directly to the model. Fox intercepts tool outputs at the execution boundary, compressing them by **52.3% to 76.4%** without losing error messages, stack traces, or patch lines:
- **Pre-Execution Git Rewrites**: Automatically optimizes `git status` $\to$ `-sb`, `git diff` $\to$ `-U1`, and `git log` $\to$ `--oneline -n 20`.
- **Render-Time Supersession**: Dynamically replaces obsolete earlier tool outputs with lightweight reference stubs.
- **Lockfile Collapsing**: Collapses 100+ line lockfile diffs (`package-lock.json`, `bun.lockb`) into concise summaries, saving 95%+ tokens.
- **Test Output Filtering**: Compresses passing test noise while preserving 100% of failure traces and diagnostics.
- **Structured Data Packing**: Packs JSON records into columnar arrays, saving 35–60% on tabular data.

> For the in-depth specification of each transform, see [Lossless Tool Token Compression in Fox Code CLI](fox-code-cli/README.md#compression).

### 2. Stable KV-Cache Prefix Preservation
Fox enforces **deterministic SHA-256 prompt prefix stability**. System prompts, agent identities, and immutable tool definitions generate identical hashes across turns, unlocking up to **75% prompt cache discounts** on supported backends.

### 3. Type-Safe Workflow Profiles
Compile-time validated compression bundles tailored for specific workloads:
- `swe` (Default): Full software engineering stack (Git rewrites, diff trimming, lockfile collapsing, test filtering).
- `data`: Columnar JSON packing, log deduplication, path normalization.
- `research`: High-fidelity text passthrough, path normalization.
- `shell`: DevOps & infrastructure with full raw log streaming.
- `none`: Safe Mode with raw uncompressed output.

### 4. Transactional Patch Engine (Atomic Multi-File Edits)
Fox introduces an **ACID-inspired transactional patch engine** featuring an in-memory pre-image journal and 4-tier match confidence scoring:
- **All-or-Nothing Atomicity**: Every patch or edit transaction either applies completely across all files and hunks or rolls back completely with zero disk residue.
- **In-Memory Pre-Image Journaling**: Captures raw byte buffers before writes; executes sub-millisecond rollback on any write failure or permission issue.
- **4-Tier Confidence Scoring**: Evaluates exact, normalized, sliding-context, and boundary-trimmed matches; rejects ambiguous or low-confidence matches before mutating files.
- **Unified Tooling**: Powers both multi-file unified diff patching (`apply_patch`) and surgical code replacement (`edit`).

> For full architectural details, see [Transactional Patch Engine in Fox Code CLI](fox-code-cli/README.md#transactional-patch-engine).

---

## 📊 Official Baseline Scoreboard (52 Golden Fixtures)

> Evaluated on Bun across all 52 fixtures using `bun run scoreboard` in `fox-code-cli/` (see [Full Scoreboard Report](fox-code-cli/docs/fox-standard-test-suite-scoreboard.md)).

| Corpus Category | Fixtures | Raw Tokens | Fox Tokens | Tokens Saved | Net Reduction | Invariant Status |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **`swe-bench-mini`** | 24 | 1,114 tok | 1,112 tok | +2 tok | 0.2% | **✔ 100% PASS** |
| **`gitops`** | 7 | 2,566 tok | 2,086 tok | +480 tok | **18.7%** | **✔ 100% PASS** |
| **`test-output`** | 6 | 2,967 tok | 1,381 tok | +1,586 tok | **53.5%** | **✔ 100% PASS** |
| **`diff`** | 6 | 4,847 tok | 512 tok | +4,335 tok | **89.4%** | **✔ 100% PASS** |
| **`shell-output`** | 5 | 18,308 tok | 9,210 tok | +9,098 tok | **49.7%** | **✔ 100% PASS** |
| **`document`** | 4 | 3,234 tok | 1,465 tok | +1,769 tok | **54.7%** | **✔ 100% PASS** |
| **CUMULATIVE TOTAL** | **52** | **33,036 tok** | **15,766 tok** | **+17,270 tok** | **52.3%** | **✔ 100% PASS** |

### Autonomous Multi-Turn SWE Benchmark (Fox vs Baseline)
- **100% Task Pass Rate (3/3)** across real-world multi-turn tasks (Job Queue engine, Pricing engine refactor, Rate Limiter bug).
- **-76.4% Cumulative Input Tokens** (202,485 tokens reduced to **47,813 tokens**).
- **Sub-Millisecond Overhead**: avg ~0.08 ms per tool call with **15,900+ chars/ms ROI**.

---

## 🥊 Competitive Landscape: Why Fox?

| Capability / Metric | **🦊 Fox** | **Claude Code** (Anthropic) | **Aider** (Paul Gauthier) | **Kilo Code** (Upstream) | **Goose** (Block) |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Core Runtime** | **Bun + Effect TS** | Node.js | Python 3 | Bun + Effect TS | Rust |
| **Local / Offline Inference** | **✅ 100% Local-First** | ❌ Anthropic API only | ⚠️ Via LiteLLM/Ollama | ⚠️ Cloud Catalog deps | ✅ Multi-provider |
| **Lossless Tool Token Compression** | **✅ Yes (-52% to -76%)** | ❌ None | ❌ None | ❌ None | ❌ None |
| **Standard Test Suite & Scoreboard** | **✅ Yes (52 Golden Fixtures)**| ❌ No | ❌ No | ❌ No | ❌ No |
| **KV-Cache Prefix Stability** | **✅ Deterministic sha256** | ⚠️ Cloud-managed | ⚠️ Heuristic | ❌ None | ❌ None |
| **Editor Integration Protocol** | **✅ ACP (JSON-RPC 2.0)** | ❌ Custom CLI only | ❌ Custom CLI only | ✅ ACP | ⚠️ MCP only |
| **Git Command Rewriting (`-sb`, `-U1`)** | **✅ Automatic** | ❌ Raw output | ❌ Raw output | ❌ Raw output | ❌ Raw output |
| **Lockfile Diff Collapsing** | **✅ Built-in (95%+ saved)** | ❌ Raw diffs | ❌ Raw diffs | ❌ Raw diffs | ❌ Raw diffs |
| **Type-Safe Workflow Profiles** | **✅ Yes (`swe`, `data`, etc.)**| ❌ No | ⚠️ Architect mode | ❌ No | ❌ No |
| **Cloud Telemetry & Tracking** | **✅ 100% Stripped & Clean** | ❌ Cloud telemetry | ✅ Clean | ⚠️ Remote checks | ✅ Clean |
| **Transactional Patch Engine** | **✅ Atomic + Journal Rollback** | ❌ None (Partial failure) | ❌ Git commit rollback | ❌ None | ❌ None |
| **Startup & Overhead Latency** | **⚡ Sub-5ms** | ~200ms | ~500ms–1s | ~50ms | ⚡ Fast (Rust) |

> Read the in-depth comparative analysis in [**Why Fox? Competitive Landscape**](docs/competitive-analysis.md).

---

## 🚀 Quick Start: Development Environment

### 1. Prerequisites
- **[Bun](https://bun.sh/)** $\ge 1.1.0$
- **Docker & Docker Compose** (for the optional local model proxy and GitLab testbed)

### 2. Start the Local Model Proxy
Fox works with any OpenAI-compatible provider. To use Google Gemini via LiteLLM during development:
```bash
cd openai-proxy
cp .env.example .env
# Edit .env and paste your GEMINI_API_KEY (https://aistudio.google.com/apikey)
make up
make health
```

### 3. Launch Fox Code CLI
```bash
cd ../fox-code-cli
bun install

# Start the interactive OpenTUI terminal
bun run dev

# Or run a quick autonomous headless task
bun ./bin/fox run "Create hello.txt with 'Hello from Fox', verify it, and exit" --auto
```

> For comprehensive CLI documentation, subcommands, Effect TS architecture, and configuration schemas, see the [**Fox Code CLI README**](fox-code-cli/README.md).

---

## 🧪 Testing & Verification

Fox enforces rigorous quality standards with a **5-Tier Testing Hierarchy**:
- **309 passing tests** across 31 test suites in `fox-code-cli/test/` (unit, integration, and prompt loop suites).
- **52 golden benchmark fixtures** evaluated in the [Fox Standard Test Suite Scoreboard](fox-code-cli/docs/fox-standard-test-suite-scoreboard.md) with 100% invariant preservation across 6 corpora.
- **Strict non-interactive test rules** (`CI=true`) and monorepo type safety (0 TypeScript diagnostics across 10 packages).

For executing specific test tiers, category suites, or smoke tests, refer to [**Testing & Verification in Fox Code CLI**](fox-code-cli/README.md#testing) and our [**Testing Rules**](.agents/rules/fox-cli-testing.md).

---

## 📑 Repository Structure

```
fox/
├── fox-code-cli/         # Fox Code CLI monorepo (@fox/cli) — ACP server & TUI
│   ├── packages/         # Core, schema, llm, server, tui, memory, sandbox
│   ├── src/              # Orchestration, decomposed prompt modules, CLI commands
│   ├── test/             # 31 test suites (309 unit & integration tests)
│   └── README.md         # Detailed CLI documentation & developer guide
├── fox-acp-client/       # Fox ACP Client — VSCode extension (Preact + JSON-RPC)
├── openai-proxy/         # LiteLLM Docker proxy (OpenAI-compatible -> Gemini)
├── gitlab/               # Local GitLab CE Docker testing container
├── docs/                 # Ecosystem-wide architectural plans & research
│   ├── fox-architecture.md # High-level system architecture
│   ├── competitive-analysis.md # Detailed competitor comparison
│   ├── reproduction-guide.md   # Benchmark verification guide
│   └── future/           # Strategic feature roadmap
└── README.md             # Ecosystem overview (you are here)
```

---

## 📚 Documentation Index

- 📖 [**Fox Code CLI Guide & Reference**](fox-code-cli/README.md) — CLI commands, Effect TS architecture, configuration schema, testing tiers
- 🔌 [**Fox ACP Client Extension**](fox-acp-client/README.md) — VS Code extension implementing Agent Client Protocol
- 🏗️ [**System Architecture**](docs/fox-architecture.md) — Multi-process design, session management, tool registries
- 🥊 [**Why Fox? Competitive Analysis**](docs/competitive-analysis.md) — In-depth breakdown vs Claude Code, Aider, Kilo Code, Goose
- 📊 [**Fox Standard Test Suite Scoreboard**](fox-code-cli/docs/fox-standard-test-suite-scoreboard.md) — 52-fixture token compression metrics
- ⚡ [**Independent Benchmark Replication Guide**](docs/reproduction-guide.md) — Step-by-step verification instructions
- 🔬 [**Autonomous SWE Multi-Turn Benchmark Report**](fox-code-cli/docs/research/report-realworld-autonomous-swe-benchmark.md) — Real-world task evaluation
- 🗺️ [**Competitive Features Roadmap**](fox-code-cli/docs/future/plan-competitive-features-roadmap.md) — Next-gen execution engine & patch transaction roadmap

---

## 📄 License

MIT License. See [`LICENSE`](LICENSE) for details.
