# Fox CLI Testing — Agent Rule

## MANDATORY: Run Tests During Refactoring

When creating implementation plans that involve refactoring or adding features to `fox-code-cli`, you MUST include a verification step that runs the appropriate tests. Use the category-specific commands to match the area being changed.

## Test Commands (all run inside `fox-code-cli/`)

### By Category
| Area Being Changed | Command |
|---|---|
| Patch parser / apply_patch | `bun run test:patch` |
| Edit tool / replacers / fuzzy matching | `bun run test:edit` |
| Config merging / loading / precedence | `bun run test:config` |
| All app-level tests | `bun run test:app` |
| Any package in `packages/` | `cd packages/<name> && bun test --timeout 30000` |

### Quick Smoke Test (after any change)
```bash
bun run test:smoke    # typecheck + patch + edit + config (~30s)
```

### Full Suite (before committing or finishing a plan)
```bash
bun run test          # typecheck + all packages + app tests (~60s)
```

## Per-Package Tests
```bash
cd packages/fox-memory            && bun test --timeout 30000
cd packages/sandbox               && bun test --timeout 30000
cd packages/effect-drizzle-sqlite && bun test --timeout 30000
cd packages/http-recorder         && bun test --timeout 30000
cd packages/tui                   && bun test --timeout 30000 --only-failures
cd packages/core                  && bun test --timeout 30000
```

## When to Run Tests During Development
| Scenario | Command | Time |
|---|---|---|
| Refactoring patch/edit logic | `bun run test:patch` or `bun run test:edit` | ~1s |
| Changing config system | `bun run test:config` | ~1s |
| After any code change (quick check) | `bun run test:smoke` | ~30s |
| Before committing | `bun run test` | ~60s |
| Changing a specific package | `cd packages/<name> && bun test --timeout 30000` | varies |

## Integration Into Plans

Every implementation plan verification section MUST include:
1. **Category tests** for the specific areas being modified
2. **Smoke test** (`bun run test:smoke`) as a minimum baseline
3. **Typecheck** (`bun run typecheck`) — always
4. **Full test suite** (`bun run test`) at the end of multi-phase plans

## Test File Locations

- App-level tests: `fox-code-cli/test/` (patch, edit, config, bom, encoding)
- Core package tests: `fox-code-cli/packages/core/test/`
- Other package tests: `fox-code-cli/packages/<name>/test/`

## Test Coverage Summary
| Area | Tests | Coverage |
|---|---|---|
| App: patch parser & application | 30 | `parsePatch`, `deriveNewContentsFromChunks`, `maybeParseApplyPatch` |
| App: edit tool replacers | 36 | All 8 replacer generators, `replace()`, `trimDiff`, `buildFileDiff` |
| App: line endings & encoding | 12 | `normalizeLineEndings`, `detectLineEnding`, `convertToLineEnding`, `isDisproportionateMatch` |
| App: config merge | 36 | `mergeConfig`, `stripNulls`, `unsetPaths`, `isConfigDir`, `mergeAgentMarkdown` |
| App: BOM utility | 8 | `split`, `join` |
| Core: tool system | 16 | `Tool.validateName`, `Tool.make`, `Tool.settle`, `Tool.withPermission` |
| TUI (existing) | 274 | UI rendering, keymaps, prompts, sessions, diffs, plugins |
| Memory (existing) | 167 | Indexing, recall, capture, decisions, text |
| Sandbox (existing) | 61 | File system guards, network policies, context |
| SQLite (existing) | 8 | Queries, transactions, migrations |
| HTTP Recorder (existing) | 35 | Record/replay for test fixtures |

## Testing Philosophy
- **Test pure functions, not wiring.** The tests target parsers, replacers, mergers, and validators — where bugs live during refactoring.
- **Typecheck catches structural regressions.** Effect service orchestration is validated by `bun run typecheck`.
- **No tests yet for:** session/LLM layer, HTTP API server, MCP integration, plugin loading, git operations. These rely on the typecheck as a safety net.

## What Is NOT Tested (use typecheck only)

Session/LLM orchestration, HTTP API server, MCP integration, plugin loading, git operations — no unit tests exist for these areas. Breaking changes here are caught by `bun run typecheck` only.
