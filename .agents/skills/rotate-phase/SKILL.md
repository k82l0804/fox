---
name: rotate-phase
description: >-
  Use this skill to rotate between development phases: archive completed plans to
  docs/completed-plans/, record finished tasks in done-tasks.md, promote the next
  phase from future-tasks.md to current-tasks.md, initialize current-plans/, and
  generate new implementation plans with refinement.
---

# Rotate Phase

Use this skill to execute the **phase rotation lifecycle** when transitioning from a completed phase to the next batch of tasks. It codifies the archival, promotion, plan generation, and refinement sequence used across development phases.

## When to Activate

- All tasks in `docs/master-plan/current-tasks.md` are implemented, reviewed, tested, and committed.
- You are ready to draw the next batch of tasks from `docs/master-plan/future-tasks.md`.
- Transitioning between roadmap milestones or subphases (e.g., Phase 2A → 2B, Phase 2B → 2C).

---

## Phase Rotation Workflow

### Step 1: Pre-Rotation Verification

Before rotating, confirm the current phase is genuinely complete:
1. Verify all automated tests pass (`timeout 60s bun run test:smoke` or `timeout 180s bun run test`).
2. Verify all code changes for current tasks are committed and clean in git (`git status`).
3. Check `docs/current-plans/README.md` to ensure no incomplete tasks remain.

---

### Step 2: Archive the Completed Phase

1. **Move plan files to `docs/completed-plans/`**:
   - Move all plan files from `fox-code-cli/docs/current-plans/` (excluding `README.md`) into `fox-code-cli/docs/completed-plans/`.
   - Use `git mv` for tracked files; use standard `mv` for untracked files.
   - Retain the original ISO 8601 timestamp prefix on each file (per Rule 8 in `AGENTS.md`).

2. **Update `docs/completed-plans/README.md`**:
   - Add a new section at the top of the phase list:
     ```markdown
     ## Phase <X> — <Phase Name> (<YYYY-MM-DD>)
     - [`<timestamp>_<slug>.md`](./<timestamp>_<slug>.md) — Task <N>: <Task Title>
     ```
   - Ensure all relative links resolve correctly.

3. **Append to `docs/master-plan/done-tasks.md`**:
   - Append a `## Phase <X> — <Phase Name>` section at the end of the document.
   - List each completed task with a checked box `- [x]`, concise summary of what was delivered, and reference commits or verification notes.

---

### Step 3: Promote the Next Phase

1. **Identify the next batch** in `docs/master-plan/future-tasks.md`:
   - Determine which phase or subphase is next in the dependency sequence.

2. **Update `docs/master-plan/current-tasks.md`**:
   - Replace the previous phase content with the newly promoted tasks.
   - Update the **Phase Flow** header breadcrumbs (e.g. `... → Phase Previous (✅) → **Phase Next** 🔧 → Phase Future ...`).
   - Format tasks with checkboxes: `- [ ] **<Task Number>. <Task Title>** — <Description>`.
   - Add recommended execution order (e.g. `Order: Task A → Task B → Task C`).
   - Include links to architectural references or prior designs.

3. **Update `docs/master-plan/future-tasks.md`**:
   - Remove the promoted phase section.
   - Update the **Phase Flow** header to show the promoted phase as `(🔧 current)`.

4. **Reconcile Scope (Rule 7)**:
   - Ensure every task in the master plan exists in **exactly one** of:
     - `current-tasks.md`
     - `future-tasks.md`
     - `done-tasks.md`
     - `deferred-tasks.md`
   - No task should be duplicated across files or lost during promotion.

---

### Step 4: Initialize Current Plans Directory

1. **Reset `docs/current-plans/README.md`**:
   - Update title: `# Current Plans — Phase <Next>: <Phase Name>`
   - State the target implementer and recommended execution order.
   - Initialize a status table listing all promoted tasks:
     ```markdown
     | Plan | Task | Status |
     |------|------|--------|
     | [Task <N>: <Title>](<timestamp>_<task-slug>.md) | <Brief summary> | ⏳ Pending |
     ```

---

### Step 5: Research & Generate Implementation Plans

For each task in `current-tasks.md`:

1. **Conduct targeted codebase research**:
   - Use `grep_search` and `view_file` to find touchpoints, existing patterns, and integration anchors.
   - Identify which files will be created, modified, or deleted.

2. **Create implementation plan in `docs/current-plans/`**:
   - Name format: `YYYY-MM-DDTHH-MM_<task-slug>.md` (must have current ISO 8601 prefix per Rule 8).
   - Structure:
     - **Goal / Problem Statement**
     - **Key Code Locations & Touchpoints**
     - **Proposed Changes & API Contracts**
     - **Edge Cases & Failure Modes**
     - **Verification Plan** (unit tests, smoke tests, typechecks)

---

### Step 6: Refine Each Plan

1. Activate the `refine-plan` skill (`.agents/skills/refine-plan/SKILL.md`) on each newly generated plan.
2. Run through the 4 refinement checks:
   - Rename ripple analysis
   - Audit completeness
   - Constraint specificity
   - Abstraction boundary precision
3. Update each plan with necessary adjustments and stamp it with the refinement outcome.
4. Ensure the plan links in `docs/current-plans/README.md` point to the exact filenames created.

---

### Step 7: Checkpoint & Source Control

1. Verify there are no broken links in `docs/current-plans/README.md`, `docs/completed-plans/README.md`, and `docs/master-plan/current-tasks.md`.
2. Stage and commit all changes with a standardized message:
   ```bash
   GIT_TERMINAL_PROMPT=0 git add docs/ .agents/skills/
   GIT_TERMINAL_PROMPT=0 git commit -m "docs(phase): rotate Phase <X> → Phase <Y>"
   GIT_TERMINAL_PROMPT=0 git push
   ```
