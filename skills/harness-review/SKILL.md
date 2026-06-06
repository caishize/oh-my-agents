---
name: harness-review
description: "Four-pillar code review with composition-based gstack integration. Owns architecture/layer/entropy review; delegates deep slop & security to gstack /codex and /cso when available. Auto-deduplicates findings across [HARNESS]/[STRUCTURAL]/[CROSS-MODEL]/[SECURITY]/[UX]/[BOTH+] tags. Aliases: harness审查, 统一评审, 双重评审, 四支柱审查"
user-invocable: true
argument-hint: "[PR-number or file-path] [--plan <plan-id>] [--no-gstack] [--no-codex] [--no-cso] [--ux]"
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

**Scope vs related skills** — the slop taxonomy in Review 1 is **shared by design** with
`/entropy-sweep` Sweep 1 (same definition, different trigger), not accidental duplication.
Pick the one that matches the moment: `/harness-review` = **per-PR / pre-ship** (the review
gate that writes `review-latest.json`); `/entropy-sweep` = **weekly / scheduled** GC scan;
`/harness-audit` = **fanned-out at repo scale** for release/governance audits. Run one per
context — don't stack all three on the same diff.

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

For each slop finding, note the **agent replication risk**: bad patterns in the codebase
multiply via every future agent-generated PR. Example: "Three retry implementations
exist — an agent encountering this codebase will create a 4th."

### Review 2: Risk & Safety (P0)

**Composition rule (v3.2+)**: deep STRIDE/OWASP analysis is owned by gstack `/cso`.
This pass does only the **fast secrets + boundary** check; if `/cso` is available
(detected via gstack presence) and `--no-cso` is not set, recommend (or invoke when
allowed) `/cso` for any non-trivial security surface. Do not duplicate its work.

**Always-on local checks (cheap, high-signal):**
- **Secrets in diff** — API keys, tokens, connection strings, `.env`, hardcoded passwords
  (even in tests). Hooks already block most of these; this is a backstop.
- **Obvious unsafe patterns** — string-concatenated SQL, `eval()` of user input,
  `dangerouslySetInnerHTML` from untrusted source.
- **New external dependencies** — flag for human review; do not approve unmaintained
  or unaudited packages.

**Delegate to gstack `/cso` when present:**
- STRIDE threat modeling, OWASP Top 10 deep coverage, auth/authz bypass patterns,
  trust-boundary analysis, deserialization risks. Tag delegated findings as `[SECURITY]`.

**If gstack absent**, run the legacy full-checklist (auth bypass, input validation,
deserialization, network calls) inline as fallback.

### Review 3: Architectural Compliance

Check changes against the layer model and constraints:

1. **Layer violations** — Do new imports respect the dependency flow?
   (Types -> Config -> Repo -> Service -> Runtime -> UI)
2. **Provider bypass** — Does it access auth/telemetry/feature-flags directly
   instead of through the Providers interface? *(Graceful degrade: if the target has no
   Providers config — `providers_path` is null in `.claude/harness.json` — skip this check
   and note "no providers configured"; do not flag.)*
3. **Module boundaries** — Are internal implementation details leaking?
4. **New dependencies** — Are cross-module dependencies justified?
5. **Direct instantiation** — Check for direct instantiation of services in
   route/controller files (e.g., `new UserService()`). Direct instantiation prevents
   dependency injection, makes testing harder, and couples layers. Flag as P1.

### Review 4: Execution Plan Alignment

If `docs/exec-plans/active/` exists, check whether changes align with active plans.
This matters because agents working outside a plan's scope create unplanned complexity
that other agents (and humans) aren't expecting.

1. **Plan consistency** — Are changes consistent with an active execution plan?
2. **Scope creep** — Are changes touching files outside the plan's defined scope?
3. **Unplanned work** — If no plan covers this change, should one exist?

If no execution plans directory exists, note this as a process gap and recommend
which findings (if any) warrant creating an execution plan via `/spec-to-task`.

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
- Unused dependencies in package.json/requirements.txt that are never imported in
  source code. Unused dependencies increase bundle size and supply-chain attack surface.

### Review 7: gstack Composition (auto-detected, dedupe-first)

Unless `--no-gstack` is passed, probe gstack and compose its complementary reviews:

```bash
GSTACK_PATH=""
for p in "$HOME/.claude/skills/gstack" ".claude/skills/gstack"; do
  [ -d "$p" ] && GSTACK_PATH="$p" && break
done
echo "GSTACK: ${GSTACK_PATH:-not_found}"
UI_TOUCHED=$(git diff --name-only 2>/dev/null | grep -Eic '\.(tsx|jsx|vue|svelte|css|html)$' || true)
```

**Composition matrix (do not duplicate gstack's work):**

| gstack skill | When to delegate | Tag | Flag to skip |
|--------------|------------------|-----|--------------|
| `/review` | structural analysis (SQL injection, enums, design consistency) | `[STRUCTURAL]` | `--no-gstack` |
| `/codex` | adversarial / cross-model slop & taste verification | `[CROSS-MODEL]` | `--no-codex` |
| `/cso` | OWASP Top 10 + STRIDE deep security audit | `[SECURITY]` | `--no-cso` |
| `/design-review` | UI / interaction quality (auto-suggest if UI files touched; `/devex-review` for DX) | `[UX]` | omit `--ux` to skip |

**If gstack is installed**: recommend (or invoke if user opted in) the relevant
gstack reviews. Merge findings with the harness pass. Apply tags above.
Cross-validated findings (flagged by ≥2 systems) escalate one severity level
and get tag `[BOTH+]`. **Never re-run a check that gstack just ran** — defer to
gstack's output and reference its report path.

**If gstack is not installed**: apply this lightweight structural checklist as fallback:
- Security: SQL injection, XSS, command injection, hardcoded secrets
- Data integrity: race conditions, missing transactions, unvalidated input
- Breaking changes: API signature changes without migration
- Resource leaks: unclosed handles, unbounded growth

Log review results to `.claude/metrics/reviews.jsonl`. Reference (don't copy) any
gstack report paths via `gstack_reports: [...]` field in the JSONL entry.

### Review 8: Decision Signal (mandatory; flow-efficiency lever)

Every `/harness-review` invocation MUST end with exactly one decision and write
`.claude/signals/review-latest.json` so consumers advance without human polling.

> **Contract: [docs/SIGNALS.md](../../docs/SIGNALS.md) is the source of truth** —
> `schema_version`, the `needs_human_kind` sub-enum, enum stability (append-only), the
> ≤500-byte cap, default-deny, and the consumer list (gstack `/ship`, `/lifecycle`,
> Dynamic Workflow stages, Agent Teams). Conform; do not restate.

**Decision tags (pick one):**

| Tag | Meaning | Lifecycle effect |
|-----|---------|------------------|
| `APPROVE` | No P0 issues; P1/P2 may exist but are non-blocking. Safe to ship. | next step: ship |
| `REQUEST_CHANGES` | At least one P0, OR multiple cross-validated `[BOTH+]` findings. | next step: back to execute |
| `NEEDS_HUMAN` | Set `needs_human_kind` (below). | halts UNLESS recoverable |

**`needs_human_kind` (mandatory when `decision=NEEDS_HUMAN`; set it HERE, never inferred downstream):**

| Value | When | Effect |
|-------|------|--------|
| `composition-skipped` | `/codex` or `/cso` was skipped (e.g. `--no-gstack`) | auto-recoverable — `/lifecycle` re-runs the skipped composition instead of halting |
| `arch-ambiguity` | architectural call needs a human | hard halt |
| `judgment-slop` | judgment-dependent slop / taste call | hard halt |

**Signal file schema** — write at end of skill, even on early exit (full reference in docs/SIGNALS.md):

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | integer | Contract version — write `1` |
| `timestamp` | string (ISO-8601 UTC) | When the review concluded |
| `decision` | enum | `APPROVE` \| `REQUEST_CHANGES` \| `NEEDS_HUMAN` |
| `needs_human_kind` | enum \| null | `composition-skipped` \| `arch-ambiguity` \| `judgment-slop` (only when NEEDS_HUMAN) |
| `merge_recommendation` | enum | `TRIVIAL` \| `STANDARD` \| `COMPLEX` |
| `p0_count` / `p1_count` / `p2_count` | integer | Issue counts by severity |
| `tags_present` | string[] | Subset of `[HARNESS]` / `[STRUCTURAL]` / `[CROSS-MODEL]` / `[SECURITY]` / `[UX]` / `[BOTH+]` |
| `gstack_composed` | boolean | True if any gstack skill was composed |
| `plan_id` | string \| null | Active exec-plan id, if any |
| `reason` | string (≤120 chars) | One-line rationale for the decision |

```bash
mkdir -p .claude/signals
# Compute fields above, then write JSON. Use python3 / jq / printf to ensure valid
# escaping; do NOT use unquoted heredocs with literal placeholders.
```

The verbose markdown report stays in `reviews.jsonl` and the agent's stdout. Per
Osmani's "success silence, failure verbosity": when `decision=APPROVE`, downstream
consumers do nothing extra; when `REQUEST_CHANGES` or `NEEDS_HUMAN`, the verbose
stdout drives the human or next agent turn.

## Output Format

```markdown
## Harness Review

### Decision: [APPROVE | REQUEST_CHANGES | NEEDS_HUMAN]    ← also written to .claude/signals/review-latest.json

### Verdict (legacy): [APPROVE / SLOP — REQUEST CHANGES / SAFETY — REQUEST CHANGES / REQUEST CHANGES / DISCUSS]

### Merge Recommendation: [TRIVIAL / STANDARD / COMPLEX]

> **TRIVIAL**: Single-file, low-risk change (docs-only, config tweaks, test additions
> with no logic changes). Auto-merge candidate if CI passes.
>
> **STANDARD**: Multi-file but focused change. 1-minute human review sufficient.
>
> **COMPLEX**: Cross-module, architectural, or security-impacting. Deep review required.

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
<!-- [x] = passed, [ ] = FAILED — mark each item accordingly -->
- [x] No slop (no duplicates, consistent patterns, no over-engineering)
- [x] No security/safety risks (secrets, auth bypass, unvalidated input)
- [x] Architectural constraints respected
- [ ] Aligned with active execution plan (if applicable) — FAILED: [reason]
- [x] Documentation updated if needed (including nested CLAUDE.md)
- [x] Tests cover new code paths
- [x] Error messages include remediation context
- [x] Lint/structural tests still pass
```

## Rules

- **Say No to Slop** — this is the #1 priority, above even bugs
- **Safety is P0** — secrets and auth issues are as urgent as slop
- "If it's technically correct but you wouldn't accept it from a human, reject it"
- Be specific — exact file:line, concrete fix suggestions
- Be concise — high-signal, not verbose
- One pass — catch everything in a single review
- Don't nitpick style that linters should enforce
- Flag when a new lint rule should be created via `/encode-mistake --proactive`
- Remember: bad patterns in the codebase multiply via every future agent PR
- "Waiting is expensive, correction is cheap" — don't block trivial changes
- Auto-detect gstack for composition; `--no-gstack` / `--no-codex` / `--no-cso` to opt out
- **Composition over duplication**: delegate slop-deep to `/codex`, security-deep to `/cso`,
  UX to `/design-review`; never re-run what gstack just ran
- Deduplicate cross-system findings; ≥2 systems flagging the same issue → severity +1, tag `[BOTH+]`
- Tag every finding: `[HARNESS]` / `[STRUCTURAL]` / `[CROSS-MODEL]` / `[SECURITY]` / `[UX]` / `[BOTH+]`
- Log results for both `/harness-dashboard` and gstack's `/ship` consumption
- Reference gstack report paths in JSONL — never copy contents
- **Always emit the decision signal** — `.claude/signals/review-latest.json` with
  `schema_version`, `decision`, and (when `NEEDS_HUMAN`) `needs_human_kind`. It is the Gate
  API per docs/SIGNALS.md; consumers default-deny a missing/unknown-version signal
- **Success silence, failure verbosity** (Osmani 2026): on `APPROVE`, the verbose
  per-pillar checklist may collapse to one line each; on `REQUEST_CHANGES` or
  `NEEDS_HUMAN`, keep full verbosity to drive the next turn
