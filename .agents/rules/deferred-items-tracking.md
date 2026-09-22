# Deferred Items Tracking & Roadmap Reconciliation — Agent Rule

## Core Principle: Zero Loss of Deferred Scope

Engineering sessions often require deferring certain non-critical scope, complex sub-tasks, or invasive refactors to keep a PR focused, safe, and shippable. **It is acceptable to defer scope, provided that deferred items are never lost.**

Every agent operating in this workspace must follow this rule without exception.

---

## 1. Recording Deferrals in Walkthroughs & Plans

When deferring any capability or sub-task in an `implementation_plan.md` or `walkthrough.md`:
- Always include a dedicated **"Deferred Items"** section.
- For each item, explicitly record:
  1. **Item Name / Scope**: Concise, clear technical description.
  2. **Deferral Rationale**: Why it was deferred (e.g., dependency on separate subsystem, needs invasive PR, out of scope for current sprint).
  3. **Target Destination**: Which roadmap blueprint, milestone, or follow-up plan owns it.

---

## 2. Immediate Reconciliation with Master Roadmap

Deferred items must **not** remain stranded inside ephemeral session walkthroughs. At the conclusion of a session where items are deferred (or when reconciling plans):

1. **Reconcile into Roadmap**: Ensure every deferred item is explicitly incorporated into [`fox-code-cli/docs/future/plan-competitive-features-roadmap.md`](file:///home/k82l0804/workarea/fox/fox-code-cli/docs/future/plan-competitive-features-roadmap.md) (or the corresponding future plan document).
2. **Link the Originating Session**: The target blueprint must link directly to the originating walkthrough artifact (e.g., `[<session-id>](../../.gemini/antigravity-ide/brain/<session-id>/walkthrough.md)`).
3. **Update the Traceability Ledger**: Add an entry into the **Master Deferred Items Traceability Ledger** table in the roadmap document specifying:
   - Deferred Item Name
   - Originating Walkthrough & Session ID
   - Original Deferral Rationale
   - Assigned Blueprint
   - Target Phase / Milestone
   - Configuration Surface / Key
   - Tracking Status (Planned / In Progress / Completed)

---

## 3. Anti-Pattern: Partial Implementation Amnesia

Never implement a feature partially, mark it as done, and forget the deferred components. If a feature is only partially landed:
- State clearly in commit messages and documentation that it is **partially implemented** (e.g., "infrastructure landed; live execution deferred to Phase 2").
- Ensure the remaining items are tracked with assigned phase milestones so they are scheduled for execution.
