---
name: harness-review
description: "Code review following OpenAI's harness engineering philosophy: Say No to Slop, check architectural compliance, evaluate harness impact, ensure agent context quality."
user-invocable: true
argument-hint: "[PR-number or file-path]"
---

# Harness Review

Code review based on OpenAI's harness engineering principles. Two key philosophies:

> **"Say No to Slop"**: Maintain strict review standards. Lowering the bar creates
> compounding technical debt. Agents replicate whatever patterns they see — bad patterns
> in the codebase multiply across every future agent-generated PR.

> **"Engineers delegate the initial code review to an agent, but own the final review
> and merge process."** This is the initial agent pass — providing high-signal,
> actionable feedback for the human engineer's final decision.

## Task

Review the current changes (staged/unstaged diff, or PR via $ARGUMENTS).

### Review 1: Say No to Slop

The most important check. Agent-generated code often produces "slop" — technically
correct but harmful to codebase quality:

1. **Duplicate logic** — Does this duplicate existing helpers? (OpenAI's real failure:
   agents creating duplicate concurrency helpers without OTel instrumentation)
2. **Pattern inconsistency** — Does it follow the established patterns, or introduce
   a slightly-different way of doing the same thing?
3. **Unnecessary abstraction** — Does it over-engineer simple operations?
4. **Copy-paste artifacts** — Generic comments, misleading variable names from templates?
5. **Missing taste** — Would a senior engineer accept this in a manual PR?

### Review 2: Architectural Compliance

Check changes against the layer model and constraints:

1. **Layer violations** — Do new imports respect the dependency flow?
   (Types → Config → Repo → Service → Runtime → UI)
2. **Provider bypass** — Does it access auth/telemetry/feature-flags directly
   instead of through the Providers interface?
3. **Module boundaries** — Are internal implementation details leaking?
4. **New dependencies** — Are cross-module dependencies justified?

### Review 3: Harness Impact

Does this change strengthen or weaken the harness?

1. **Documentation impact**:
   - Does this change require updates to CLAUDE.md or docs/?
   - Are new patterns/conventions introduced without documentation?
   - Would an agent encountering this code for the first time be confused?

2. **Enforcement impact**:
   - Do changes bypass lint rules (`eslint-disable`, `noqa`, `nolint`)?
   - Are bypasses justified with a comment explaining why?
   - Should a new lint rule be created for a pattern this change introduces?

3. **Test impact**:
   - Are new code paths covered by tests?
   - Do tests verify behavior, not just implementation?
   - Are structural tests still passing (layer boundaries, naming)?

4. **Context quality**:
   - Would an AI agent understand this code without human explanation?
   - Are non-obvious decisions documented with "why"?
   - Are error messages actionable (include remediation instructions)?

### Review 4: Code Quality (by priority)

**P0 — Must Fix (blocks merge)**:
- Logic errors, off-by-one, null reference risks
- Security: injection, XSS, auth bypass, secrets in code
- Data loss risks, race conditions
- Slop that would be replicated by future agents

**P1 — Should Fix**:
- Missing error handling at system boundaries
- Performance issues (N+1, unbounded loops)
- Missing observability (logging, metrics, spans)
- Weak or missing tests

**P2 — Consider**:
- Unclear naming (but don't nitpick what linters should catch)
- Potential for future confusion
- Opportunities for better patterns

## Output Format

```markdown
## Harness Review

### Verdict: [APPROVE / SLOP — REQUEST CHANGES / REQUEST CHANGES / DISCUSS]

### Slop Check
[Pass / Fail — list any slop patterns found]

### Architectural Impact
[Layer compliance, new dependencies, provider usage]

### Harness Impact
[Docs needing update, enforcement gaps, missing tests]

### Issues

**P0 — Must Fix**
- `file.ts:42` — [issue]. Fix: [specific suggestion]

**P1 — Should Fix**
- `file.ts:88` — [issue]. Fix: [suggestion]

**P2 — Consider**
- `file.ts:15` — [note]

### Checklist
- [ ] No slop (no duplicates, consistent patterns, no over-engineering)
- [ ] Architectural constraints respected
- [ ] Documentation updated if needed
- [ ] Tests cover new code paths
- [ ] Error messages include remediation context
- [ ] No secrets or credentials in code
- [ ] Lint/structural tests still pass
```

## Rules

- **Say No to Slop** — this is the #1 priority, above even bugs
- "If it's technically correct but you wouldn't accept it from a human, reject it"
- Be specific — exact file:line, concrete fix suggestions
- Be concise — high-signal, not verbose
- One pass — catch everything in a single review
- Don't nitpick style that linters should enforce
- Flag when a new lint rule should be created via `/taste-encoder`
- Remember: bad patterns in the codebase multiply via every future agent PR
