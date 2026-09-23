# 🦊 Fox Standard Test Suite & Scoreboard — Replication Guide

> This guide explains how to independently replicate and verify the **Fox Standard Test Suite**, the **Baseline Scoreboard**, and the **Lossless Token Compression** milestones.

For the comprehensive test suite and challenge ladder runner, see [`fox-code-cli/test/challenge-ladder/README.md`](../fox-code-cli/test/challenge-ladder/README.md) and [`fox-code-cli/docs/2026-09-22T15-54_fox-challenge-ladder-report.md`](../fox-code-cli/docs/2026-09-22T15-54_fox-challenge-ladder-report.md).

---

## Quick Replication (Deterministic, Offline)

Run from the `fox-code-cli` directory:

```bash
cd fox-code-cli

# 1. Run the modern Challenge Ladder (334 fixtures, 4 tiers, 100% pass)
bun run test:challenge

# 2. Run the quick smoke test suite (typecheck + patch + edit + config)
bun run test:smoke

# 3. Run the full test suite (monorepo packages + app tests)
bun run test

# 4. View deterministic challenge snapshots
bun run challenge:snapshot
```

## Summary Scoreboard Baseline (334 Fixtures)
See [2026-09-22T15-54_fox-challenge-ladder-report.md](../fox-code-cli/docs/2026-09-22T15-54_fox-challenge-ladder-report.md) for full telemetry.

## Core Documentation References

- 🏆 [Master Benchmark Report (Challenge Ladder v1.1)](../fox-code-cli/docs/2026-09-22T15-54_fox-challenge-ladder-report.md)
- 🧗 [Challenge Ladder Test Harness Guide](../fox-code-cli/test/challenge-ladder/README.md)
- 📜 [Archived Baseline 52-Fixture Scoreboard](../fox-code-cli/docs/archived/2026-09-20T19-32_fox-standard-test-suite-scoreboard.md)
- 📦 [Archived Reproduction Guide (52 Fixtures)](../fox-code-cli/docs/archived/2026-09-20T19-32_reproduction-guide.md)
