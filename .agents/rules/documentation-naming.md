# Documentation Naming & Organization Rule

## Rule: ISO 8601 Timestamp Prefix for Markdown Documents in `docs/`

To prevent confusion about document recency, ensure automatic chronological sorting across file trees, and eliminate ambiguity between current specifications and historical artifacts:

### 1. Mandatory Naming Format
Every Markdown (`.md`) file created in or moved into `fox-code-cli/docs/` (including all subdirectories: `future/`, `handoffs/`, `archived/`, etc.) **MUST** be prefixed with an ISO 8601 date-time timestamp in the following format:

```
YYYY-MM-DDTHH-MM_<descriptive-name>.md
```

**Example valid names:**
- `2026-09-22T15-54_fox-challenge-ladder-report.md`
- `2026-09-22T15-16_daemon-architecture.md`
- `2026-09-21T06-12_plan-competitive-features-roadmap.md`
- `2026-09-22T16-24_phase-1-remaining.md`

### 2. Exception: Directory Entrypoint READMEs
Directory index files named `README.md` (e.g. `docs/README.md`, `docs/archived/README.md`) are **exempt** from the timestamp prefix so that GitHub, IDEs, and documentation generators render them as the canonical folder landing page.

### 3. Archiving Superseded Documents
When an existing document in `docs/` is superseded by a newer implementation, an expanded benchmark harness, or a reconciled roadmap:
- Move the document into `docs/archived/` (or an appropriate subfolder under `docs/archived/`) via `git mv`.
- Ensure it retains its ISO timestamp prefix so it sorts chronologically in the archive.
- Update `docs/archived/README.md` with an entry explaining what superseded it and why.
- Update `docs/README.md` to keep the active documentation index clean and accurate.
- Grep and update any cross-references across the workspace so no broken links are introduced.
