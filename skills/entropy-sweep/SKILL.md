---
name: entropy-sweep
description: "Scan for and fix codebase entropy across all four pillars: Architecture as Guardrails, Documentation as System of Record, Observability & Legibility, Entropy Management. Covers slop, doc drift, arch violations, dead code, missing enforcement, exec plan health, and nested CLAUDE.md drift. Aliases: 熵扫描, 代码清理, 死代码清理, 代码垃圾回收, 代码腐化检查, 文档过期检查"
user-invocable: true
argument-hint: "[scope: full|docs|slop|arch|dead-code|plans|claude-md]"
allowed-tools: Read, Glob, Grep, Bash
---

# Entropy Sweep

Perform the "garbage collection" that keeps agent-generated codebases healthy. Based on
the discovery that manual Friday cleanup of "AI slop" doesn't scale, leading to
automated recurring agent tasks that scan for pattern violations and open targeted
cleanup PRs.

> "The bottleneck was never the agent's ability to write code, but the lack of structure,
> tools, and feedback mechanisms surrounding it."

The sweep is organized around the **four pillars**:

1. **Architecture as Guardrails** — layer violations, provider bypass, dead weight
2. **Documentation as System of Record** — doc drift, stale references
3. **Observability & Legibility** — nested CLAUDE.md health, logging gaps
4. **Entropy Management** — execution plan health, missing enforcement, slop

**Scope vs related skills** — Sweep 1's slop detection is shared by design with
`/harness-review` (per-PR gate) and `/harness-audit` (release governance): same taxonomy,
different trigger. `/entropy-sweep` is the **weekly / scheduled** GC scan. Canonical
moments table: [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md#three-reviewaudit-moments).
Pick the one matching your moment.

## What Is Entropy?

In agent-driven codebases, entropy accumulates faster because:
- Agents replicate whatever patterns they see (including bad ones)
- Agents have no taste — they'll produce functionally-correct but poorly-maintainable code
- Documentation drifts as code changes outpace doc updates
- Duplicate helpers and inconsistent patterns multiply
- Execution plans go stale as reality diverges from the plan

This is **"slop"** — technically correct code that degrades codebase quality.

## Task

Perform a comprehensive entropy sweep. Use $ARGUMENTS to scope (default: full).

**Scan exclusion**: `.claude/gstack-rendered/` is a gstack-OWNED enclave (v1.57.9
`gen-skill-docs` output inside our namespace) — never scan or flag it as entropy.

### Sweep 1: Say No to Slop

**Pillar: Entropy Management**

The #1 rule: **maintain strict review standards. Lowering the bar creates
compounding technical debt.** Classify against the **canonical slop taxonomy**
([docs/LINTING.md](../../docs/LINTING.md#slop-taxonomy-canonical)) — the same definition
`/harness-review` Review 1 and `/harness-audit` use. Scan for:

1. **Duplicate helpers** — Same logic implemented in multiple places
   (Real example: duplicate concurrency helpers where only one had OTel)
2. **Pattern drift** — Similar operations done differently across files
   (e.g., 5 files use async/await, 3 use callbacks)
3. **Unnecessary abstraction** — Over-engineered code for simple operations
4. **Inconsistent naming** — Same concept with different names across modules
5. **Copy-paste artifacts** — Comments, variable names, or logic from unrelated code
6. **Security Slop** — Hardcoded secrets, API keys, or tokens committed to source.
   Check for string literals matching common secret patterns (e.g., `sk-`, `ghp_`,
   `AKIA`, `Bearer`, API key assignments). These should use environment variables
   or a secrets manager, never literal values in code.

### Sweep 2: Documentation Drift

**Pillar: Documentation as System of Record**

Documentation is the system of record. When it drifts, agents get wrong context and
produce wrong code. Check every claim in CLAUDE.md and docs/:

1. **Commands that don't work** — Run each documented command, verify it succeeds
2. **Dead file references** — Paths mentioned in docs that don't exist
3. **Stale API descriptions** — Function signatures that changed since docs were written
4. **Outdated dependency lists** — Packages mentioned but not in manifest
5. **Contradictory docs** — CLAUDE.md says one thing, docs/ says another

**Note:** Dead imports (imported but never called) belong in Sweep 4 (Dead Weight),
not here. Documentation Drift covers only actual documentation issues — commands that
don't work, dead file references in docs, stale API descriptions, outdated dependency
lists, and contradictory docs.

### Sweep 3: Architectural Violations

**Pillar: Architecture as Guardrails**

Check against the layer model (Types -> Config -> Repo -> Service -> Runtime -> UI):

1. **Layer boundary crossings** — Imports going the wrong direction
2. **Circular dependencies** — Modules importing each other
3. **Provider bypass** — Code accessing auth/telemetry/feature-flags directly
   instead of through the Providers interface
4. **Leaking internals** — Private/internal code exposed to other modules

### Sweep 4: Dead Weight

**Pillar: Entropy Management**

1. **Unused exports** — Functions/classes exported but never imported
2. **Unused dependencies** — Packages in manifest not used in code
3. **Orphaned files** — Files not imported by anything
4. **Stale TODOs/FIXMEs** — References to completed issues or old PRs
5. **Commented-out code** — Dead code left as comments
6. **Dead imports** — Modules or symbols imported but never referenced in the file.
   These accumulate quickly in agent-generated code.
7. **Deprecated dependencies** — Packages known to be deprecated or in maintenance
   mode (e.g., `moment.js`, `request`, `tslint`, `node-uuid`). Flag and suggest
   modern replacements.
8. **Zero test files** — If a test runner is configured in dependencies (jest,
   vitest, mocha, pytest, etc.) but zero test files exist in the project, flag
   this as a significant gap. A configured-but-unused test runner signals an
   abandoned testing practice.

### Sweep 5: Missing Enforcement

**Pillar: Architecture as Guardrails**

Check if documented rules actually have mechanical enforcement:

1. For each rule in docs/CONVENTIONS.md — is there a lint rule or test?
2. For each constraint in docs/ARCHITECTURE.md — is there a structural test?
3. For each taste invariant in docs/LINTING.md — is there a lint rule?

Rules without enforcement are just suggestions agents will ignore. This is the
gap between "we document conventions" and "we enforce conventions." Only enforcement
scales.

### Sweep 6: Execution Plan Health

**Pillar: Entropy Management**

If `docs/exec-plans/` exists, check the health of active plans. Execution plans
that go stale become misleading — agents following an outdated plan create work
that conflicts with reality.

Check `docs/exec-plans/active/` for:

1. **Stale active plans** — Plans with no file modifications in N+ days
   (default 7; configurable via `plan_stale_days` in `.claude/harness.json`).
   Use file modification dates to detect. A plan that hasn't been touched
   is either completed (move to `completed/`) or blocked (needs attention).
2. **Blocked tasks with no progress** — Plans where tasks are marked blocked
   but no resolution steps are documented. Blocked work should either have
   a path forward or be descoped.
3. **Completed tasks not marked done** — Cross-reference plan task lists
   against actual code changes. If the code exists but the task isn't checked
   off, the plan is misleading.
4. **Ghost references** — Plans referencing files, modules, or APIs that no
   longer exist. This happens when code evolves but plans aren't updated.

If `docs/exec-plans/` does not exist at all, skip this sweep silently.
If `docs/exec-plans/` exists but `docs/exec-plans/active/` is empty or missing,
report this as a finding: "Execution plans directory exists but contains no active
plans — either the directory structure is vestigial (clean it up) or active plans
are missing (create them)."

### Sweep 7: Nested CLAUDE.md Drift

**Pillar: Documentation as System of Record / Observability & Legibility**

Nested CLAUDE.md files give agents module-specific context, but they rot just like
any other documentation. Stale module docs are worse than no docs because they
give agents confident but wrong instructions.

1. **Missing coverage** — Modules with 5+ source files that lack a CLAUDE.md.
   These are blind spots where agents have no module-specific guidance.
2. **Ghost references** — Nested CLAUDE.md files referencing source files that
   have been moved or deleted. Check every file path mentioned.
3. **Layer rule inconsistency** — Nested CLAUDE.md claiming different layer rules
   than the root CLAUDE.md or docs/ARCHITECTURE.md. For example, a module
   CLAUDE.md saying "this module may import from service/" when the root says
   it's a types-layer module.
4. **Oversized module docs** — Nested CLAUDE.md files exceeding 50 lines.
   Module docs should be concise pointers, not encyclopedias. If a module
   CLAUDE.md is too long, it's trying to do too much — extract to docs/.
5. **Root CLAUDE.md accuracy** — When a root CLAUDE.md exists, verify its
   content is still accurate. Check that: Module Map entries reference
   directories/files that still exist, documented commands actually work
   (e.g., `npm test`, `npm run build`), listed dependencies match the
   current manifest, and architectural claims match the actual code
   structure. A root CLAUDE.md that exists but contains stale information
   is worse than a missing one — agents will follow its instructions
   confidently.

## Output Format

```markdown
## Entropy Sweep Report — [date]

### Slop (fix immediately)
- `src/utils/retry.ts` + `src/helpers/async-retry.ts` — duplicate retry logic
  Only `src/utils/retry.ts` has OTel instrumentation. Delete the duplicate.
- 5 files use `logger.info()`, 3 use `console.log()` — mixed logging

### Documentation Drift
- CLAUDE.md:15 says `npm test` but project uses `pnpm test`
- docs/ARCHITECTURE.md references `src/services/` but directory is `src/service/`

### Architectural Violations
- `src/ui/dashboard.ts:15` imports `src/service/internal/auth` (layer violation)
- `src/api/users.ts:42` calls `getFeatureFlag()` directly (bypass Providers)

### Dead Weight
- `src/helpers/legacy.ts` — imported by nothing
- `lodash` in package.json — not imported in any source file

### Missing Enforcement
- docs/CONVENTIONS.md says "max 300 lines per file" — no lint rule or test
- docs/ARCHITECTURE.md defines layers — no structural test validates them

### Execution Plan Health
- `docs/exec-plans/active/migration-v2.md` — last modified 12 days ago (stale)
- `docs/exec-plans/active/auth-refactor.md` — references `src/auth/legacy.ts` (deleted)
- `docs/exec-plans/active/api-v3.md` — 4 tasks appear complete but unmarked

### Nested CLAUDE.md Drift
- `src/services/` (12 files) — missing CLAUDE.md
- `src/auth/CLAUDE.md:8` references `src/auth/middleware.ts` (moved to `src/middleware/auth.ts`)
- `src/utils/CLAUDE.md` — 67 lines (exceeds 50 line limit)

### Auto-fixed
- Updated 3 stale paths in docs/ARCHITECTURE.md
- Removed 2 stale TODO comments referencing closed issues

### Summary
| Category              | Count | Severity   |
|-----------------------|-------|------------|
| Slop                  |     N | Fix now    |
| Documentation drift   |     N | Fix soon   |
| Architectural         |     N | Fix soon   |
| Dead weight           |     N | Clean up   |
| Missing enforcement   |     N | Add rules  |
| Exec plan health      |     N | Review     |
| Nested CLAUDE.md      |     N | Update     |
```

### Metric write (mandatory final step — accountable-writer, /verify pattern)

The sweep that derived the findings writes them (read-only stays true for all project
code and gstack paths; own-namespace metrics are the accountable-writer exception
`/verify` established). Write `.claude/metrics/entropy-latest.json` (≤500 bytes: finding
counts per category, timestamp, commit) AND append the same record as one line to
`.claude/metrics/entropy.jsonl` (trend history — `/harness-dashboard` reads both):

```bash
mkdir -p .claude/metrics
python3 -c "import json,subprocess,datetime; s={'findings':{'slop':N1,'docs':N2,'arch':N3,'dead':N4,'enforcement':N5,'plans':N6,'claude_md':N7},'total':T,'timestamp':datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),'commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()}; open('.claude/metrics/entropy-latest.json','w').write(json.dumps(s)); open('.claude/metrics/entropy.jsonl','a').write(json.dumps(s)+'\n')"
```

## Rules

- **Say No to Slop** — never lower review standards, even to ship faster
- **Deduplication** — each finding appears in exactly one category. Dead imports and unused code belong in Dead Weight, not Documentation Drift. Documentation Drift is only for actual documentation issues (stale docs, broken references, contradictory docs).
- Verify documentation claims by actually running commands
- Never delete code you're not certain is unused — flag for human review
- When a pattern is violated, also check if enforcement is missing
- For each finding, include the specific file:line and actionable fix
- Recommend `/encode-mistake --proactive` for patterns that need mechanical enforcement
- Recommend `/harness-dashboard` for tracking entropy trends over time
- This sweep should run weekly or before every major release
