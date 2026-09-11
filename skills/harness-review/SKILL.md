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

**Scope vs related skills** — the slop check is shared by design with `/entropy-sweep`
(weekly GC) and `/harness-audit` (release governance): same taxonomy, different trigger.
`/harness-review` is the **per-PR / pre-ship** gate that writes `review-latest.json`.
Canonical moments table: [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md#three-reviewaudit-moments).
Run one per context — don't stack all three on the same diff.

## Task

Review the current changes (staged/unstaged diff, or PR via $ARGUMENTS).

### Blind evaluation protocol (Anthropic evaluator-blindness pattern; MANDATORY)

Findings and the Decision derive ONLY from: the artifact (diff + files on disk), the
plan's acceptance criteria, the fixed rubric (docs/LINTING.md slop taxonomy), the decision
signals, and gstack's read-only artifacts — **NEVER** the generating session's transcript,
scratch notes, or self-assessment. Where feasible, run behavior (tests, the plan's
`acceptance` commands) rather than trusting narration. If this review runs in the SAME
session that generated the change, STATE SO in the output and delegate the judging step to
a fresh-context read-only subagent — the Agent tool with the built-in `Explore` type
(cannot Write/Edit; a native primitive, no agent file of ours) — handing it ONLY the diff,
the plan's acceptance criteria and the rubric, never this session's reasoning or
self-assessment (the auto-mode classifier strips exactly that so the agent cannot talk the
judge into a bad call). `/harness-audit` already complies by construction.

### Review 1: Say No to Slop

The most important check. Agent-generated code often produces "slop" — technically
correct but harmful to codebase quality. Classify findings against the **canonical slop
taxonomy** in [docs/LINTING.md](../../docs/LINTING.md#slop-taxonomy-canonical) — duplicate
logic · pattern inconsistency · copy-paste artifacts · over-engineering · inconsistent
naming · security slop · missing taste. It is the same definition `/entropy-sweep` Sweep 1
and `/harness-audit` use, so a given finding earns the same severity in every pass.

For each slop finding, note the **agent replication risk** (defined there): bad patterns
multiply via every future agent-generated PR. "Three retry implementations exist — an
agent encountering this codebase will create a 4th."

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

### Review 6: Generic code quality — DELEGATED, not duplicated

Logic errors, N+1s, race conditions, weak tests and unused dependencies already have
owners: gstack `/review` (8 specialists — testing, maintainability, security, performance,
data migration, API contract, design, simplification) and `/cso` per Review 7's matrix,
and, if available, native `/code-review` (invoke it as `/code-review` — never `/review`,
whose alias collides with gstack's; it runs in THIS context, not an isolated one). This
pass does not re-run them; it reads their output and applies the severity ladder:
**P0** blocks merge (logic/data-loss/security/replicable slop) · **P1** should fix ·
**P2** consider. A skipped delegation is NOT a halt and never reuses `composition-skipped`
(pinned to `/codex` and `/cso`). With neither gstack nor `/code-review` present, Review 7's
structural fallback checklist covers the floor.

### Review 7: gstack Composition (auto-detected, dedupe-first)

Unless `--no-gstack` is passed, probe gstack and compose its complementary reviews:

```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && gstack_detect || true
echo "GSTACK: ${GSTACK_PATH:-not_found}"
UI_TOUCHED=$(git diff --name-only 2>/dev/null | grep -Eic '\.(tsx|jsx|vue|svelte|css|html)$' || true)
```

**Codex-default recalibration (v1.61+, probe-gated)**: gstack v1.61 reportedly made
cross-model review default-on (`codex_reviews`) — a changelog-summarized, UNVERIFIED
claim. Probe locally: installed `VERSION >= 1.61.0.0` AND (a `codex_reviews` config
switch OR observed `*-codex-*.md` artifacts). ONLY when the probe confirms, treat a
skipped codex composition as the flagged anomaly (`composition-skipped`); otherwise keep
the current opt-in framing.

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

**gstack decision-layer read (v1.57.5+, READ-ONLY)** — if present, capture gstack's own
verdict so Review 8 can reconcile (full rule in docs/SIGNALS.md). Read-only glob; absent ⇒ skip.

```bash
GD="$GSTACK_PROJECTS"   # from gstack_detect above
# Review verdict: accept BOTH the tail-1 JSONL `.status` form AND gstack's prose
# verdict-line form; a parse failure reports LOUD ('verdict-unparsed'), never silent.
LAST_REVIEW=$(ls -t "$GD"/*-reviews.jsonl 2>/dev/null | head -1 | xargs -I{} tail -1 {} 2>/dev/null || echo "")
GSTACK_REVIEW_STATUS=$(printf '%s' "$LAST_REVIEW" | python3 -c "
import sys, json, re
raw = sys.stdin.read().strip()
if not raw: print(''); raise SystemExit
try:
    print(json.loads(raw).get('status', 'verdict-unparsed'))
except Exception:
    m = re.search(r'\b(clean|issues_found)\b', raw)   # prose verdict-line form
    print(m.group(1) if m else 'verdict-unparsed')
" 2>/dev/null || echo "verdict-unparsed")
# CURRENCY (gstack v1.79): review records are content-addressed — gstack-review-log stamps
# `wtree` (working-tree fingerprint from bin/gstack-wtree; untracked source counts, a
# same-content commit does not). A record is CURRENT only when its wtree equals the live
# one; a stale verdict is treated as ABSENT, loudly. Fallback when the binary is missing:
# compare `commit_full`/`commit` to HEAD.
GSTACK_VERDICT_CURRENCY="unknown"
if [ -x "$GSTACK_PATH/bin/gstack-wtree" ]; then
  LIVE_WTREE=$("$GSTACK_PATH/bin/gstack-wtree" 2>/dev/null || echo "")
  REC_WTREE=$(printf '%s' "$LAST_REVIEW" | python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('wtree',''))" 2>/dev/null || echo "")
  [ -n "$LIVE_WTREE" ] && { [ "$LIVE_WTREE" = "$REC_WTREE" ] && GSTACK_VERDICT_CURRENCY="current" || GSTACK_VERDICT_CURRENCY="stale"; }
fi
[ "$GSTACK_VERDICT_CURRENCY" = "stale" ] && GSTACK_REVIEW_STATUS="verdict-stale (wtree changed since gstack /review)"
echo "gstack-verdict: status=${GSTACK_REVIEW_STATUS:-none} currency=${GSTACK_VERDICT_CURRENCY}"
```

`decisions.active.json` is NOT read (v3.10.0): it is a bare JSON array and gstack documents
it as a rebuildable cache whose reader returns `[]` when missing or corrupt, so any count
taken from the file is a plausible-looking wrong number, and "unresolved" is not a gstack
concept. `decisions_unresolved` is DEPRECATED-optional in `gstack_context` (never produced;
consumers must tolerate its absence). If a rule ever needs active decisions, the supported
surface is `bin/gstack-decision-search --json` — pending the unmade read-only-CLI policy.

If a value is found, set `gstack_context` (Review 8) to e.g.
`{"present":true,"review_status":"issues_found","currency":"current","source":"gstack-review-log"}`
and surface gstack's verdict next to ours in the report. **Advisory only** — it never
mechanically rewrites our decision; it can only trigger the divergence halt in Review 8.
A `verdict-stale` or `verdict-unparsed` status never triggers the halt — it is reported as
absent, with the reason.

**If gstack is not installed**: apply this lightweight structural checklist as fallback:
- Security: SQL injection, XSS, command injection, hardcoded secrets
- Data integrity: race conditions, missing transactions, unvalidated input
- Breaking changes: API signature changes without migration
- Resource leaks: unclosed handles, unbounded growth

Log review results to `.claude/metrics/reviews.jsonl` (the HISTORY record — Review 8
defines its shape). Reference (don't copy) any gstack report paths via
`gstack_reports: [...]` field in the JSONL entry.

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

**Signal file** — write at end of skill, even on early exit. The full schema lives in
**docs/SIGNALS.md — do not restate it**. Review-specific notes: `needs_human_kind` is set
HERE, never inferred downstream; `gstack_context` comes from Review 7 (read-only, `null`
when absent); `commit` = `git rev-parse HEAD` at derivation time (freshness predicate);
`tags_present` is the subset of composition tags actually used this run.

**gstack verdict reconciliation (when `gstack_context.present`)** — the decision stays
derived from OUR four pillars; gstack's verdict is advisory (full rule: docs/SIGNALS.md):
- **Agree** (both block, or both allow) ⇒ emit our `decision` unchanged.
- **Diverge** (we'd `APPROVE` but gstack `review_status=issues_found`, or vice-versa) ⇒
  emit `decision=NEEDS_HUMAN`, `needs_human_kind=judgment-slop`, name it in `reason`.
- Never aggregate, never rewrite our decision mechanically, never write gstack paths.

```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh"
ROOT=$(harness_root)   # never a bare .claude/ path
mkdir -p "$ROOT/.claude/signals"
COMMIT=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo unknown)   # freshness predicate stamp
# Compute fields above, then write JSON (include "commit": "$COMMIT"). Use python3 / jq /
# printf to ensure valid escaping; do NOT use unquoted heredocs with literal placeholders.
# HISTORY record = the signal object + `findings[]` (below), through the ONE tested writer:
append_history_record "$ROOT/.claude/metrics" reviews.jsonl "$HISTORY_JSON"
```

**`findings[]` — the typed shape a `REQUEST_CHANGES` hands to the next Generator turn**
(history record only, NEVER in the ≤500-byte signal; docs/SIGNALS.md § history logs):
`{"fingerprint":"<file>:<line>:<dimension>","severity":"P0|P1|P2","tag":"[HARNESS]|…",
"fix":"<≤80 chars>"}` — capped at the 10 highest-severity items, ≤4 KB. `dimension` is
our four-pillar vocabulary (`slop|arch|docs|observ|contract|reconcile`, the same
`/harness-audit` returns), never gstack's `CRITICAL|INFORMATIONAL`. `/lifecycle` routes
`REQUEST_CHANGES` on this list instead of a count.

The verbose markdown report stays in `reviews.jsonl` and the agent's stdout. Per
Osmani's "success silence, failure verbosity": when `decision=APPROVE`, downstream
consumers do nothing extra; when `REQUEST_CHANGES` or `NEEDS_HUMAN`, the verbose
stdout drives the human or next agent turn.

## Output Format

```markdown
## Harness Review

### Decision: [APPROVE | REQUEST_CHANGES | NEEDS_HUMAN]    ← also written to .claude/signals/review-latest.json

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

- **Say No to Slop** (#1, above even bugs); **safety is P0**; "if you wouldn't accept it
  from a human, reject it" — bad patterns multiply via every future agent PR
- Be specific (file:line + concrete fix), concise, one pass; don't nitpick what linters
  enforce — flag a missing rule via `/encode-mistake --proactive` instead
- "Waiting is expensive, correction is cheap" — don't block trivial changes
- **Composition over duplication**: auto-detect gstack; delegate slop-deep to `/codex`,
  security-deep to `/cso`, UX to `/design-review`, generic quality to `/review` /
  `/code-review`; never re-run what they just ran (`--no-gstack` / `--no-codex` / `--no-cso`)
- Tag every finding (`[HARNESS]` … `[BOTH+]`); ≥2 systems on one issue → severity +1
- Log to `reviews.jsonl` for `/harness-dashboard` + `/lifecycle`; reference gstack report
  paths, never copy contents; the pre-`/ship` read is our-side convention (SIGNALS.md)
- **Always emit the decision signal** (`review-latest.json`: `schema_version`, `decision`,
  `needs_human_kind` when `NEEDS_HUMAN`) — consumers default-deny anything else
- **Success silence, failure verbosity**: on `APPROVE` collapse each pillar to one line;
  on `REQUEST_CHANGES` / `NEEDS_HUMAN` keep full verbosity — it drives the next turn
