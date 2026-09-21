# Fox CLI Testing — Agent Rule

## MANDATORY: Run Tests During Refactoring

When creating implementation plans or making code changes to `fox-code-cli`, you MUST include verification steps that run the appropriate tests according to the **5-Tier Testing Hierarchy**.

---

## 5-Tier Testing Hierarchy (All run inside `fox-code-cli/`)

```
Tier 1: Targeted Module Test   (~200ms)  ──► On every edit / save
Tier 2: Category Suite         (~1-2s)   ──► After editing a specific subsystem
Tier 3: Quick Smoke            (~15s)    ──► Before staging (git add)
Tier 4: App & Invariant Suite  (~2s)     ──► Pre-commit verification (all 29 suites + invariants)
Tier 5: Full Monorepo + Build  (~45s)    ──► Before pushing or finishing a major plan
```

### Tier 1 — Targeted Module Tests (~200ms)
Fast, focused sub-second tests for rapid iteration:
```bash
# Session & Prompt Monolith Subsystems
bun test test/session/prompt-loop.test.ts
bun test test/session/prompt-shell.test.ts
bun test test/session/prompt-command.test.ts
bun test test/session/prompt-attachment.test.ts
bun test test/session/prompt-orphan.test.ts
bun test test/session/prompt-structured.test.ts

# LLM Stream Adapter & Reducer
bun test test/session/llm-adapter.test.ts
bun test test/session/reducer.test.ts
bun test test/session/subagent-data.test.ts
bun test test/session/permission-flow.test.ts

# Context, Compaction & Guardrails
bun test test/session/compaction.test.ts
bun test test/session/overflow.test.ts
bun test test/session/doom-loop.test.ts

# Subsystem & Schema Tests
bun test test/foxcode/daemon-schema.test.ts
bun test test/foxcode/background-process-schema.test.ts
bun test test/foxcode/lsp-validate.test.ts
bun test test/foxcode/goal-action.test.ts
bun test test/tool/mcp-docker.test.ts
```

### Tier 2 — Category Suites (~1–2s)
Run when modifying specific functional areas:
| Area Being Changed | Command | Typical Time |
|---|---|:---:|
| Patch parser / `apply_patch` | `bun run test:patch` | ~1s |
| Edit tool / replacers / fuzzy matching | `bun run test:edit` | ~1s |
| Config merging / loading / precedence | `bun run test:config` | ~1s |
| Lossless tool token compression | `bun run test:compress` | ~1s |
| Schema stability / wire formats | `bun run test:schema-stability` | ~1s |

### Tier 3 — Quick Smoke Test (~15s)
Run after code edits to verify TypeScript compilation and core invariants:
```bash
bun run test:smoke    # typecheck + patch + edit + config + compress (~15s)
```

### Tier 4 — App & Invariant Verification (~2s)
Run before staging (`git add`) to guarantee zero regressions across all orchestration and agent components:
```bash
bun run test:app            # All 281 tests across 29 suites in test/ (~1s)
bun run test:standard-suite # Fox Standard Test Suite (6 invariant categories, ~1s)
```

### Tier 5 — Full Monorepo Build & Package Tests (~45s)
Run before committing or completing an implementation plan:
```bash
bun run test          # typecheck + all 6 internal packages + all app tests (~45s)
bun run build         # Bundle production dist/ via bun build
```

---

## Per-Package Tests

Run when changing code within `packages/*`:
```bash
cd packages/fox-memory            && bun test --timeout 30000
cd packages/sandbox               && bun test --timeout 30000
cd packages/effect-drizzle-sqlite && bun test --timeout 30000
cd packages/http-recorder         && bun test --timeout 30000
cd packages/tui                   && bun test --timeout 30000 --only-failures
cd packages/core                  && bun test --timeout 30000
```

---

## Test Coverage Summary

| Area / Subsystem | Test Files | What It Covers |
|---|:---:|---|
| **Session & Orchestration** | 14 suites | `toLLMEvents` stream adapter, turn loop, shell execution, command parsing, attachments, structured tools, doom-loop, overflow, compaction, reducer, subagent tabs, permission flows |
| **Foxcode & Daemon** | 4 suites | Daemon schemas (Network/State/Status), background process schema & lifecycle, LSP binary SHA-256 validation, goal action classification |
| **Tools & Sandbox** | 3 suites | MCP Docker `--rm` injection, sandbox filesystem & process policies, web search |
| **Editing & Patching** | 3 suites | Patch parser, hunk applicator, heredocs, 8 replacer strategies, line ending & BOM normalization |
| **Config & Compression** | 5 suites | Config precedence, JSONC merging, lossless tool token compression pipeline (path relativization, diff trimming, git rewriting, test filtering) |
| **Standard Invariants** | 1 suite | 6 baseline categories: patch, edit, config, compress, memory, sandbox |
| **Internal Packages** | 6 packages | `fox-memory` (167 tests), `sandbox` (61 tests), `core` (100+ tests), `http-recorder` (35 tests), `tui` (274 tests), `sqlite` (8 tests) |

---

## Integration Into Implementation Plans

Every implementation plan's **Verification Plan** section MUST specify:
1. **Tier 1 / Category tests** for the specific files modified.
2. **Tier 3 Smoke test** (`bun run test:smoke`) during development iterations.
3. **Typecheck** (`bun run typecheck`) with a scaled timeout (`timeout 45s`).
4. **Tier 4 App tests** (`bun run test:app`) and **Tier 5 Full suite** (`bun run test`) before final sign-off.
