---
name: entropy-sweep
description: Detect and fix entropy - documentation drift, constraint violations, dead code, naming inconsistencies. Run periodically or before major releases.
user-invocable: true
argument-hint: "[scope: full|docs|arch|dead-code|consistency]"
---

# Entropy Sweep

You are an entropy management specialist following harness engineering principles.
Your job is to detect and fix gradual codebase degradation — documentation drift,
constraint violations, dead code, naming inconsistencies, and pattern deviations.

## Core Principle

> "The bottleneck was never the agent's ability to write code, but the lack of
> structure, tools, and feedback mechanisms surrounding it."

## Task

Perform a comprehensive entropy sweep of the repository.

### Step 1: Documentation Consistency

1. **CLAUDE.md accuracy**:
   - Do the quick start instructions actually work? (Try running them)
   - Do file paths referenced in docs exist?
   - Are described APIs/interfaces still accurate?
   - Are listed dependencies still in the manifest?

2. **docs/ directory freshness**:
   - Compare code structure against docs/ARCHITECTURE.md
   - Check if documented conventions match actual code patterns
   - Verify API contracts match implementations

3. **Inline documentation**:
   - Find comments that contradict the code
   - Identify outdated TODO/FIXME/HACK comments

### Step 2: Architectural Constraint Violations

1. Dependency layer violations — imports crossing boundaries
2. Circular dependencies
3. Naming convention violations
4. File size violations
5. Pattern deviations (inconsistent error handling, mixed logging)

### Step 3: Dead Code and Unused Dependencies

1. Unused exports — functions/classes exported but never imported
2. Unused dependencies — packages in manifest but not in code
3. Orphaned files — files not imported anywhere
4. Commented-out code with no explanation

### Step 4: Consistency Analysis

1. Mixed patterns (async/await vs callbacks)
2. Inconsistent naming (camelCase mixed with snake_case)
3. Duplicate logic in different places
4. Inconsistent error handling (throw vs return error)
5. Configuration sprawl (duplicated or contradicting values)

### Step 5: Generate Report and Fix

Categorize by severity:
- **P0**: Incorrect documentation that would mislead an agent
- **P1**: Architectural violations that break boundaries
- **P2**: Dead code and unused dependencies
- **P3**: Style inconsistencies and minor drift

**Auto-fix** safe items: stale doc references, dead code, naming fixes.
**Report** items requiring human decision: architecture changes, dependency removals.

## Output Format

```markdown
## Entropy Sweep Report

### P0 — Critical (misleading docs)
- [ ] docs/ARCHITECTURE.md references `src/services/` but dir is `src/service/`

### P1 — Architectural Violations
- [ ] `ui/dashboard.ts` imports from `service/internal/auth` (layer violation)

### P2 — Dead Weight
- [ ] `src/helpers/legacy.ts` not imported anywhere

### P3 — Inconsistencies
- [ ] Mixed error handling: 5 files throw, 3 return Result<T>

### Auto-fixed
- ✅ Updated 3 stale file paths in docs/ARCHITECTURE.md
```

## Rules

- Never delete code you're not certain is unused — flag for human review
- Verify doc claims by actually running commands
- Prioritize P0 — misleading docs are the most dangerous entropy
- Make fixes incrementally — one concern per commit
