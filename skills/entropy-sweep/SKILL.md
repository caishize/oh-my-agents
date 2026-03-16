---
name: entropy-sweep
description: Detect and fix entropy - documentation drift, constraint violations, dead code, inconsistencies
triggers:
  - entropy sweep
  - garbage collection
  - docs drift
  - codebase cleanup
  - consistency check
---

# Entropy Sweep

You are an entropy management specialist following harness engineering principles. Your job is to detect and fix the gradual degradation that happens in codebases — documentation drift, constraint violations, dead code, naming inconsistencies, and pattern deviations.

## Core Principle

> "The bottleneck was never the agent's ability to write code, but rather the lack of structure, tools, and feedback mechanisms surrounding it." Entropy management is the continuous process of fighting codebase degradation.

## Task

Perform a comprehensive entropy sweep of the repository:

### Step 1: Documentation Consistency

Check for documentation drift:

1. **CLAUDE.md / AGENTS.md accuracy**:
   - Do the quick start instructions actually work? (Try running them)
   - Do file paths referenced in docs actually exist?
   - Are described APIs/interfaces still accurate?
   - Are listed dependencies still in package.json / requirements.txt / go.mod?

2. **docs/ directory freshness**:
   - Compare code structure against docs/ARCHITECTURE.md
   - Check if documented conventions match actual code patterns
   - Verify API contracts match implementations
   - Look for TODOs or FIXMEs that reference completed work

3. **Inline documentation**:
   - Find comments that contradict the code they describe
   - Identify outdated TODO/FIXME/HACK comments
   - Check that function signatures match their doc comments

### Step 2: Architectural Constraint Violations

Scan for violations of documented constraints:

1. **Dependency layer violations** — imports crossing architectural boundaries
2. **Circular dependencies** — modules that import each other
3. **Naming convention violations** — files, functions, variables not matching patterns
4. **File size violations** — files exceeding documented limits
5. **Pattern deviations** — code that doesn't follow established patterns (e.g., inconsistent error handling, mixed logging styles)

### Step 3: Dead Code and Unused Dependencies

Identify entropy in the form of dead weight:

1. **Unused exports** — functions/classes exported but never imported elsewhere
2. **Unused dependencies** — packages in manifest but not imported in code
3. **Orphaned files** — files not imported or referenced anywhere
4. **Dead feature flags** — flags that are always on/off
5. **Commented-out code** — code blocks commented out with no explanation

### Step 4: Consistency Analysis

Check for inconsistencies that create confusion:

1. **Mixed patterns** — e.g., some files use async/await, others use callbacks
2. **Inconsistent naming** — camelCase mixed with snake_case in the same layer
3. **Duplicate logic** — similar functions in different places
4. **Inconsistent error handling** — some modules throw, others return errors
5. **Configuration sprawl** — config values duplicated or contradicting

### Step 5: Generate Report and Fix

For each issue found:

1. **Categorize** by severity:
   - **P0**: Incorrect documentation that would mislead an agent
   - **P1**: Architectural violations that break boundaries
   - **P2**: Dead code and unused dependencies
   - **P3**: Style inconsistencies and minor drift

2. **Auto-fix** what can be safely fixed:
   - Update stale documentation references
   - Remove clearly dead code
   - Fix naming inconsistencies
   - Update outdated comments

3. **Report** what requires human decision:
   - Architectural changes
   - Dependency removals that might affect optional features
   - Pattern choices where multiple valid options exist

## Output Format

Present findings as:

```
## Entropy Sweep Report

### P0 — Critical (misleading documentation)
- [ ] docs/ARCHITECTURE.md references `src/services/` but directory is `src/service/`
- [ ] CLAUDE.md says "run `npm test`" but project uses `pnpm test`

### P1 — Architectural Violations
- [ ] `ui/dashboard.ts` imports from `service/internal/auth` (layer violation)
- [ ] Circular dependency: `utils/format` ↔ `utils/validate`

### P2 — Dead Weight
- [ ] `src/helpers/legacy.ts` — not imported anywhere
- [ ] `lodash` in package.json — not imported in any source file

### P3 — Inconsistencies
- [ ] Mixed error handling: 5 files throw, 3 files return Result<T>
- [ ] Naming: `getUserData()` vs `fetch_user_profile()` in same module

### Auto-fixed
- ✅ Updated 3 stale file paths in docs/ARCHITECTURE.md
- ✅ Removed 2 outdated TODO comments
- ✅ Fixed naming in `utils/helpers.ts` to match conventions
```

## Rules

- Never delete code you're not certain is unused — flag it for human review
- Always verify documentation claims by actually running commands
- Prioritize P0 fixes — misleading docs are the most dangerous entropy
- Make fixes incrementally — one concern per commit
- Update the entropy sweep date in a comment so teams know when it last ran
- This skill should be run periodically (weekly or before major releases)
