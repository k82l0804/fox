# Documentation Naming & Organization Rule

## Rule: ISO 8601 Timestamp Prefix for Markdown Documents in `docs/`

To prevent confusion about document recency, ensure automatic chronological sorting across file trees, and eliminate ambiguity between current specifications and historical artifacts:

### 1. Mandatory Naming & Modification Format
Every Markdown (`.md`) file created in, moved into, or **modified within** `fox-code-cli/docs/` (including all subdirectories: `future/`, `handoffs/`, `archived/`, `reports/`, etc.) **MUST** be prefixed with an ISO 8601 date-time timestamp in the following format:

```
YYYY-MM-DDTHH-MM_<descriptive-name>.md
```

**Timestamp Update on Modification (MANDATORY):**
- **Any time an existing document is modified**, its prepended timestamp **MUST be updated to the current date and time** (renaming the file via `git mv`).
- Updating the timestamp on modification ensures that:
  1. File tree sorting (`ls`, file explorers) naturally reflects the **latest modification order**.
  2. Developers and agents immediately know when the document was last updated.
  3. Stale documents are easily distinguished from actively maintained ones.
- **Reference Integrity**: Whenever a file is renamed to update its modification timestamp, the agent **MUST** immediately grep and update all cross-references across `docs/` (such as in `docs/README.md`, roadmap links, index tables, and other referring markdown files) so that no broken links are introduced.

**Example valid names:**
- `2026-09-23T10-35_fox-challenge-ladder-report.md`
- `2026-09-23T09-18_competitive-analysis-fox-aider-goose.md`
- `2026-09-22T15-16_daemon-architecture.md`
- `2026-09-21T06-12_plan-competitive-features-roadmap.md`

### 2. Exception: Directory Entrypoint READMEs
Directory index files named `README.md` (e.g. `docs/README.md`, `docs/archived/README.md`) are **exempt** from the timestamp prefix so that GitHub, IDEs, and documentation generators render them as the canonical folder landing page.

### 3. Archiving Superseded Documents
When an existing document in `docs/` is superseded by a newer implementation, an expanded benchmark harness, or a reconciled roadmap:
- Move the document into `docs/archived/` (or an appropriate subfolder under `docs/archived/`) via `git mv`.
- Ensure it retains its ISO timestamp prefix so it sorts chronologically in the archive.
- Update `docs/archived/README.md` with an entry explaining what superseded it and why.
- Update `docs/README.md` to keep the active documentation index clean and accurate.
- Grep and update any cross-references across the workspace so no broken links are introduced.
