# 🦊 Fox Standard Test Suite & Scoreboard — Replication Guide

> This guide explains how to independently replicate and verify the **Fox Standard Test Suite**, the **Baseline Scoreboard**, and the **Lossless Token Compression** milestones.

For the full detailed document, see [`fox-code-cli/docs/reproduction-guide.md`](../fox-code-cli/docs/reproduction-guide.md).

---

## Quick Replication (Deterministic, Offline)

Run from the `fox-code-cli` directory:

```bash
cd fox-code-cli

# 1. Run the full invariant verification test suite (52 fixtures, 6 corpora, 356 assertions)
CI=true bun run test:standard-suite

# 2. Recompute and display the live ANSI baseline scoreboard
bun run scoreboard

# 3. View machine-readable JSON telemetry
bun run scoreboard --json

# 4. Inspect SWE-bench Mini benchmark tasks
bun ./bin/fox standard-suite tasks

# 5. Display the CLI scoreboard
bun ./bin/fox standard-suite scoreboard
```

## Summary Scoreboard Baseline

| Corpus Category | Fixtures | Raw Tokens | Fox Tokens | Tokens Saved | Net Savings | Invariants Verified |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **`swe-bench-mini`** | 24 | 1,114 | 1,112 | +2 | **0.2%** | ✔ 100% PASS |
| **`gitops`** | 7 | 2,566 | 2,086 | +480 | **18.7%** | ✔ 100% PASS |
| **`test-output`** | 6 | 2,967 | 1,381 | +1,586 | **53.5%** | ✔ 100% PASS |
| **`diff`** | 6 | 4,847 | 512 | +4,335 | **89.4%** | ✔ 100% PASS |
| **`shell-output`** | 5 | 18,308 | 9,210 | +9,098 | **49.7%** | ✔ 100% PASS |
| **`document`** | 4 | 3,234 | 1,465 | +1,769 | **54.7%** | ✔ 100% PASS |
| **OVERALL TOTAL** | **52** | **33,036** | **15,766** | **+17,270** | **52.3%** | **✔ 100% PASS** |

## Core Documentation References

- 📋 [Fox Standard Test Suite Specification](../fox-code-cli/docs/research/std-test-suite-sort-of.md)
- 📊 [Official Baseline Scoreboard Document](../fox-code-cli/docs/fox-standard-test-suite-scoreboard.md)
- 🔬 [Autonomous SWE Benchmark Report](../fox-code-cli/docs/research/report-realworld-autonomous-swe-benchmark.md)
- 📖 [Comprehensive Replication Guide](../fox-code-cli/docs/reproduction-guide.md)
