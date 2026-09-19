# TypeScript noUnusedLocals / noUnusedParameters Cleanup Rules

## When to Apply
When adding noUnusedLocals/noUnusedParameters to tsconfig.json and fixing TS6133/TS6192/TS6196 errors.

## Correct Fix Strategy Per Error Kind

| Error Kind | Fix | Notes |
|---|---|---|
| Unused named import | Remove name from destructure, or delete whole line if sole import | Python regex |
| Entire import line unused (TS6192) | Delete the whole line | |
| Unused parameter | Prefix with _ (e.g. _name) | TS suppresses _-prefixed params |
| Unused local const/let/var | DELETE the declaration entirely | _-prefix does NOT suppress TS6133 for locals |
| Unused function declaration | DELETE the entire function body | Must use brace-matching, not single-line deletion |
| Unused type alias | DELETE the type X = ... line | Usually single-line |

## CRITICAL: Multi-Line Declaration Deletion

Never delete just the first line of a multi-line construct.
Orphaned closing braces cause TS1128/TS1109 syntax errors.

Use brace-counting to find the full extent before deleting:

    def find_block_end(lines, start_idx):
        depth = 0
        for i in range(start_idx, len(lines)):
            opens = lines[i].count('{') + lines[i].count('(') + lines[i].count('[')
            closes = lines[i].count('}') + lines[i].count(')') + lines[i].count(']')
            depth += opens - closes
            if depth <= 0 and i > start_idx:
                return i
        return start_idx  # single-line

Then delete lines[start_idx : block_end + 1] as a unit.

## Common Pitfall: as Aliases in Imports

    import { tool as aiTool, type ModelMessage }

When removing aiTool, match the FULL alias pattern `tool as aiTool,` not just `aiTool`.
Naive removal leaves `tool as type ModelMessage` which is a syntax error.

## Verifying Pre-Existing vs Introduced Errors

After adding noUnused flags, unexpected TS2322/TS2345 errors may appear.
Confirm pre-existing (not from your fix script) with:

    git stash && timeout 60s bun run typecheck 2>&1 | grep -c 'error TS' && git stash pop

If count is 0 with stash, errors were introduced by the script (likely deleted a used import).

## Fix Script Workflow

1. bun run typecheck 2>&1 > /tmp/typecheck.log
2. Parse log with Python: extract (file, lineno, colno, name, error_code)
3. Group by file; process in REVERSE LINE ORDER to avoid index shifts after deletions
4. Imports: regex-remove name from destructure
5. Locals/functions: brace-match to find full extent, delete the block
6. Params: regex-prefix with _
7. Re-run typecheck; fix any TS2304 Cannot find name from over-aggressive import deletion
