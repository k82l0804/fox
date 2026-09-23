---
name: refine-plan
description: >-
  Use this skill after writing an implementation plan to perform a targeted
  refinement pass. Catches rename ripple effects, audit completeness gaps,
  ambiguous state-transition rules, and coarse abstraction boundaries.
---

# Refine Plan

After creating or updating an implementation plan, perform a **targeted refinement pass** to catch common plan-quality issues. This is a lightweight self-review, not a full adversarial audit.

## When to Activate

- Immediately after writing a new implementation plan
- After a major revision to an existing plan
- When a plan involves renaming symbols, auditing sets of items, or defining state-transition rules

## Refinement Checklist

Work through each category. For each, either fix the plan or note "N/A" if the category doesn't apply.

### 1. Rename Ripple Analysis

If the plan renames any symbol, key, variable, or config field:

1. `grep` the codebase for **all references** to the old name.
2. For each reference found, determine whether it refers to the old semantic meaning (needs updating) or is coincidental (safe to leave).
3. List every callsite that needs updating in the plan. Pay special attention to:
   - Permission/config inheritance chains (e.g., `agents.oldName.permission`)
   - Test assertions that reference the old name
   - Documentation and comments

### 2. Audit Completeness

If the plan audits or categorizes a group of related items (tools, fields, config keys, etc.):

1. List **every member** of the group explicitly — do not use glob patterns like `notebook_*` without expanding them.
2. For each member, state its categorization and rationale.
3. Confirm no member was skipped.

### 3. Constraint Specificity

If the plan defines state-transition rules, permission boundaries, or behavioral constraints:

1. For each rule, state what **should happen** AND what **should NOT happen**.
2. Check for ambiguous phrases like "only X transitions" — clarify whether this means "only items currently at X" or "only items whose original state was X."
3. If there is a guard field (like `original` in a state object), explicitly state whether and how it should be checked.

### 4. Abstraction Boundary Precision

If the plan says "use X for Y" where Y is a compound concept:

1. Break Y into its sub-components and verify X is correct for each.
2. Example: "use original tier for warnings" — does this mean the warning *trigger*, the warning *message content*, or both? Be explicit.

## Output

After completing the checklist, update the plan with any fixes found. If no issues were found, add a brief note at the bottom:

```markdown
> **Refinement pass**: Completed [date]. No issues found.
```

If issues were fixed, add:

```markdown
> **Refinement pass**: Completed [date]. Fixed: [brief list of what changed].
```
