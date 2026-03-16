---
name: entropy-sweep
description: Scan for and fix codebase entropy — documentation drift, AI slop accumulation, constraint violations, dead code. Based on OpenAI's "garbage collection" pillar and their evolution from manual Friday cleanup to automated agent scanning.
user-invocable: true
argument-hint: "[scope: full|docs|slop|arch|dead-code]"
allowed-tools: Read, Glob, Grep, Bash
---

# Entropy Sweep

Perform the "garbage collection" that keeps agent-generated codebases healthy. Based on
OpenAI's discovery that their initial approach (manual Friday cleanup of "AI slop")
didn't scale, leading them to automate recurring agent tasks that scan for pattern
violations and open targeted cleanup PRs.

> "The bottleneck was never the agent's ability to write code, but the lack of structure,
> tools, and feedback mechanisms surrounding it."

## What Is Entropy?

In agent-driven codebases, entropy accumulates faster because:
- Agents replicate whatever patterns they see (including bad ones)
- Agents have no taste — they'll produce functionally-correct but poorly-maintainable code
- Documentation drifts as code changes outpace doc updates
- Duplicate helpers and inconsistent patterns multiply

OpenAI calls this **"slop"** — technically correct code that degrades the codebase quality.

## Task

Perform a comprehensive entropy sweep. Use $ARGUMENTS to scope (default: full).

### Sweep 1: Say No to Slop

OpenAI's #1 rule: **maintain strict review standards. Lowering the bar creates
compounding technical debt.** Scan for:

1. **Duplicate helpers** — Same logic implemented in multiple places
   (OpenAI's real example: duplicate concurrency helpers where only one had OTel)
2. **Pattern drift** — Similar operations done differently across files
   (e.g., 5 files use async/await, 3 use callbacks)
3. **Unnecessary abstraction** — Over-engineered code for simple operations
4. **Inconsistent naming** — Same concept with different names across modules
5. **Copy-paste artifacts** — Comments, variable names, or logic from unrelated code

### Sweep 2: Documentation Drift

Check every claim in CLAUDE.md and docs/:

1. **Commands that don't work** — Run each documented command, verify it succeeds
2. **Dead file references** — Paths mentioned in docs that don't exist
3. **Stale API descriptions** — Function signatures that changed since docs were written
4. **Outdated dependency lists** — Packages mentioned but not in manifest
5. **Contradictory docs** — CLAUDE.md says one thing, docs/ says another

### Sweep 3: Architectural Violations

Check against the layer model (Types → Config → Repo → Service → Runtime → UI):

1. **Layer boundary crossings** — Imports going the wrong direction
2. **Circular dependencies** — Modules importing each other
3. **Provider bypass** — Code accessing auth/telemetry/feature-flags directly
   instead of through the Providers interface
4. **Leaking internals** — Private/internal code exposed to other modules

### Sweep 4: Dead Weight

1. **Unused exports** — Functions/classes exported but never imported
2. **Unused dependencies** — Packages in manifest not used in code
3. **Orphaned files** — Files not imported by anything
4. **Stale TODOs/FIXMEs** — References to completed issues or old PRs
5. **Commented-out code** — Dead code left as comments

### Sweep 5: Missing Enforcement

Check if documented rules actually have mechanical enforcement:

1. For each rule in docs/CONVENTIONS.md — is there a lint rule or test?
2. For each constraint in docs/ARCHITECTURE.md — is there a structural test?
3. For each taste invariant in docs/LINTING.md — is there a lint rule?

Rules without enforcement are just suggestions agents will ignore.

## Output Format

```markdown
## Entropy Sweep Report — [date]

### 🔴 Slop (fix immediately)
- `src/utils/retry.ts` + `src/helpers/async-retry.ts` — duplicate retry logic
  Only `src/utils/retry.ts` has OTel instrumentation. Delete the duplicate.
- 5 files use `logger.info()`, 3 use `console.log()` — mixed logging

### 🟡 Documentation Drift
- CLAUDE.md:15 says `npm test` but project uses `pnpm test`
- docs/ARCHITECTURE.md references `src/services/` but directory is `src/service/`

### 🟠 Architectural Violations
- `src/ui/dashboard.ts:15` imports `src/service/internal/auth` (layer violation)
- `src/api/users.ts:42` calls `getFeatureFlag()` directly (bypass Providers)

### ⚪ Dead Weight
- `src/helpers/legacy.ts` — imported by nothing
- `lodash` in package.json — not imported in any source file

### 🔵 Missing Enforcement
- docs/CONVENTIONS.md says "max 300 lines per file" — no lint rule or test
- docs/ARCHITECTURE.md defines layers — no structural test validates them

### Auto-fixed
- ✅ Updated 3 stale paths in docs/ARCHITECTURE.md
- ✅ Removed 2 stale TODO comments referencing closed issues

### Summary
| Category              | Count | Severity |
|-----------------------|-------|----------|
| Slop                  |     N | Fix now  |
| Documentation drift   |     N | Fix soon |
| Architectural         |     N | Fix soon |
| Dead weight           |     N | Clean up |
| Missing enforcement   |     N | Add rules|
```

## Rules

- **Say No to Slop** — never lower review standards, even to ship faster
- Verify documentation claims by actually running commands
- Never delete code you're not certain is unused — flag for human review
- When a pattern is violated, also check if enforcement is missing
- For each finding, include the specific file:line and actionable fix
- Recommend `/taste-encoder` for patterns that need mechanical enforcement
- This sweep should run weekly or before every major release
