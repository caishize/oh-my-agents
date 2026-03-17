---
name: harness-review
description: "Code review following harness engineering philosophy across four pillars: Architecture as Guardrails, Documentation as System of Record, Observability & Legibility, Entropy Management. Say No to Slop, check safety, evaluate harness impact, ensure agent context quality."
user-invocable: true
argument-hint: "[PR-number or file-path]"
allowed-tools: Read, Glob, Grep, Bash
---

# Harness Review

Code review based on harness engineering principles, organized around the **four pillars**:

1. **Architecture as Guardrails** — layers, providers, mechanical enforcement
2. **Documentation as System of Record** — CLAUDE.md, docs/, nested CLAUDE.md per module
3. **Observability & Legibility** — can agents (and humans) see what happened and why?
4. **Entropy Management** — does this change increase or decrease codebase entropy?

Two guiding philosophies:

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

**Duplicate logic** (highest signal):
- Same function implemented in 2+ places (especially helpers, utils)
- Real example: duplicate concurrency helpers where only one had OpenTelemetry

**Pattern inconsistency:**
- 5 files use async/await, 3 use callbacks for the same thing
- Mixed logging: some `logger.info()`, some `console.log()`
- Different error handling approaches in the same layer

**Copy-paste artifacts:**
- Generic comments ("This function does X") that add no value
- Variable names from a template that don't match the context
- Leftover TODOs from scaffolding

**Over-engineering:**
- Abstract factory for a single implementation
- Generic type parameters used in only one place
- Configuration for behavior that never varies

**Missing taste** — would a senior engineer accept this in a manual PR?

### Review 2: Risk & Safety (P0 — alongside Slop)

Security and safety issues compound just like slop. An agent that sees an insecure
pattern will replicate it everywhere. Check for:

**Secrets in code:**
- API keys, passwords, tokens, or connection strings committed to source
- `.env` files or credentials accidentally included in the diff
- Hardcoded secrets even in test files (use fixtures or env vars instead)

**Auth/authz bypass patterns:**
- Endpoints missing authentication middleware
- Authorization checks skipped or commented out
- Permission escalation through parameter manipulation
- JWT validation disabled or weakened

**Unvalidated input at system boundaries:**
- HTTP request bodies, query params, or headers used without validation
- File paths constructed from user input without sanitization
- Database queries built with string concatenation
- Deserialization of untrusted data without schema validation

**New external dependencies or network calls:**
- New packages added — are they maintained, audited, necessary?
- New outbound HTTP calls — are they to trusted endpoints?
- New database queries — are they parameterized?
- New file system access — is the scope appropriately restricted?

### Review 3: Architectural Compliance

Check changes against the layer model and constraints:

1. **Layer violations** — Do new imports respect the dependency flow?
   (Types -> Config -> Repo -> Service -> Runtime -> UI)
2. **Provider bypass** — Does it access auth/telemetry/feature-flags directly
   instead of through the Providers interface?
3. **Module boundaries** — Are internal implementation details leaking?
4. **New dependencies** — Are cross-module dependencies justified?

### Review 4: Execution Plan Alignment

If `docs/exec-plans/active/` exists, check whether changes align with active plans.
This matters because agents working outside a plan's scope create unplanned complexity
that other agents (and humans) aren't expecting.

1. **Plan consistency** — Are changes consistent with an active execution plan?
2. **Scope creep** — Are changes touching files outside the plan's defined scope?
3. **Unplanned work** — If no plan covers this change, should one exist?

If no execution plans directory exists, skip this review silently.

### Review 5: Harness Impact

Does this change strengthen or weaken the harness?

1. **Documentation impact**:
   - Does this change require updates to CLAUDE.md or docs/?
   - Are new patterns/conventions introduced without documentation?
   - Would an agent encountering this code for the first time be confused?

2. **Nested CLAUDE.md impact**:
   - Does this change modify a module that has its own CLAUDE.md?
   - If so, does the module CLAUDE.md need updating to reflect new patterns,
     exports, or conventions introduced by this change?
   - If this change creates a new module with 5+ files, suggest creating a
     nested CLAUDE.md for it.

3. **Enforcement impact**:
   - Do changes bypass lint rules (`eslint-disable`, `noqa`, `nolint`)?
   - Are bypasses justified with a comment explaining why?
   - Should a new lint rule be created for a pattern this change introduces?

4. **Test impact**:
   - Are new code paths covered by tests?
   - Do tests verify behavior, not just implementation?
   - Are structural tests still passing (layer boundaries, naming)?

5. **Context quality**:
   - Would an AI agent understand this code without human explanation?
   - Are non-obvious decisions documented with "why"?
   - Are error messages actionable (include remediation instructions)?

### Review 6: Code Quality (by priority)

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

### Verdict: [APPROVE / SLOP — REQUEST CHANGES / SAFETY — REQUEST CHANGES / REQUEST CHANGES / DISCUSS]

### Merge Recommendation: [TRIVIAL / STANDARD / COMPLEX]

> **Trivial**: Docs-only, config tweaks, test additions with no logic changes.
> If CI passes, consider auto-merging. "Waiting is expensive, correction is cheap."
>
> **Standard**: Single-concern changes with clear scope. 1-minute human review.
>
> **Complex**: Multi-module changes, new patterns, architectural shifts. Deep review needed.

### Slop Check
[Pass / Fail — list any slop patterns found]

### Risk & Safety
[Pass / Fail — secrets, auth bypass, unvalidated input, new dependencies]

### Architectural Impact
[Layer compliance, new dependencies, provider usage]

### Execution Plan Alignment
[Aligned with plan X / No active plans / Out of scope — details]

### Harness Impact
[Docs needing update, nested CLAUDE.md impact, enforcement gaps, missing tests]

### Issues

**P0 — Must Fix**
- `file.ts:42` — [issue]. Fix: [specific suggestion]

**P1 — Should Fix**
- `file.ts:88` — [issue]. Fix: [suggestion]

**P2 — Consider**
- `file.ts:15` — [note]

### Checklist
- [ ] No slop (no duplicates, consistent patterns, no over-engineering)
- [ ] No security/safety risks (secrets, auth bypass, unvalidated input)
- [ ] Architectural constraints respected
- [ ] Aligned with active execution plan (if applicable)
- [ ] Documentation updated if needed (including nested CLAUDE.md)
- [ ] Tests cover new code paths
- [ ] Error messages include remediation context
- [ ] Lint/structural tests still pass
```

## Rules

- **Say No to Slop** — this is the #1 priority, above even bugs
- **Safety is P0** — secrets and auth issues are as urgent as slop
- "If it's technically correct but you wouldn't accept it from a human, reject it"
- Be specific — exact file:line, concrete fix suggestions
- Be concise — high-signal, not verbose
- One pass — catch everything in a single review
- Don't nitpick style that linters should enforce
- Flag when a new lint rule should be created via `/taste-encoder`
- Remember: bad patterns in the codebase multiply via every future agent PR
- "Waiting is expensive, correction is cheap" — don't block trivial changes
