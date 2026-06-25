---
name: lifecycle
description: "Full development lifecycle ROUTER (not an executor) — detects state, reads decision signals, and NAMES the next phase + exact remediation skill across Research→Plan→Execute→Verify→Review→Ship→Deploy→Retro→Improve, adapting to installed plugins. Never invokes delivery skills or advances a phase; worktree-aware. Aliases: 生命周期, 全流程, 开发流程"
user-invocable: true
argument-hint: "<phase> [--from-design <path>] [--plan <plan-id>] [--auto] [--emit-next] [--ux] [--with-codex] [--with-cso]"
allowed-tools: Read, Glob, Grep, Bash
---

# Lifecycle — Lifecycle Router (NOT an Orchestrator)

> **Anti-bloat anchor (v3.4+)**: this skill is a **router and reporter**, not an
> *executor* of workflow logic. gstack owns lifecycle orchestration via `/office-hours`,
> `/autoplan`, `/ship`, `/land-and-deploy`, `/canary`, `/retro`. We invoke them by name
> and route on their gates; we never re-implement a phase. If any logic here starts to
> *plan* or *deploy* on its own, it must be deleted or moved to the relevant gstack skill.

Routes through the complete lifecycle: reads decision signals, reports the next phase, and
names the **exact remediation skill** when a gate fails — so AI-driven flow doesn't stall. It
never invokes a delivery skill or advances a phase itself.

```
IDEATE → PLAN → DECOMPOSE → EXECUTE → VERIFY → REVIEW → SHIP → DEPLOY → CANARY → RETRO → IMPROVE
(gstk)   (gstk)  (harness)   (hooks)  (harness)  (both)  (gstk)  (gstk)  (gstk)  (both)  (harness)
```

## Task

Phase from `$ARGUMENTS`: `ideate`, `plan`, `decompose`, `execute`, `verify`, `review`,
`ship`, `deploy`, `canary`, `retro`, `improve`, `status`, `next`, `recover`

- `next` — Detect state, read the latest decision signal, and NAME the next phase + the
  exact skill to run. **Router only — it does NOT invoke the skill.** Delivery auto-advance
  is gstack's; multi-agent coordination is native Agent Teams'.
- `next --auto` — Project the full remaining gated path (read-only); mark a STOP at the
  first RED / YELLOW / NEEDS_HUMAN gate with the exact remediation skill. Names, never invokes.
- `recover` — Diagnose and recover from failed mid-lifecycle state

## Step 0: Detect Environment (worktree-aware)

```bash
GSTACK_PATH=""
for p in "$HOME/.claude/skills/gstack" ".claude/skills/gstack"; do
  [ -d "$p" ] && GSTACK_PATH="$p" && break
done
HARNESS_JSON=""
[ -f ".claude/harness.json" ] && HARNESS_JSON=".claude/harness.json"
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
ACTIVE_PLANS=$(ls docs/exec-plans/active/*.json 2>/dev/null | wc -l | tr -d ' ')
WORKTREE_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
PARALLEL_WT=0
[ -d ".gstack-worktrees" ] && PARALLEL_WT=$(ls -1 .gstack-worktrees 2>/dev/null | wc -l | tr -d ' ')
UI_TOUCHED=$(git diff --name-only 2>/dev/null | grep -Eic '\.(tsx|jsx|vue|svelte|css|html)$' || echo 0)
echo "GSTACK: ${GSTACK_PATH:-none} | HARNESS: ${HARNESS_JSON:-none} | PLANS: $ACTIVE_PLANS | WT: $WORKTREE_ROOT | PARALLEL: $PARALLEL_WT | UI: $UI_TOUCHED"
```

If `PARALLEL_WT > 0`, scope all subsequent verify/review/ship operations to **current
worktree only**; never cross-fire into sibling sprints.

## Phase Router

### `status` — Show lifecycle state and next phase

Show progress per phase based on artifact detection (design docs, plans,
verify results, review logs, ship/deploy/canary reports). Recommend next phase.

### `next` — Report the next phase (router only)

Detection logic (in order) — output the FIRST match as the recommended next step and STOP.
This skill NAMES the skill to run; the human, a native Agent Team lead, or gstack runs it:
1. No design doc + gstack → next: `/office-hours` (ideate)
2. No design doc + no gstack → next: `/spec-to-task` (decompose)
3. Design doc, no plan → next: `/spec-to-task` (decompose; auto-imports the design doc)
4. Plan with incomplete tasks → next: continue execution (show the next task)
5. All tasks done, no verify signal → next: `/verify`
6. Verify GREEN, no review → next: `/harness-review`
7. Review APPROVE + gstack → next: `/ship`
8. Shipped, no deploy report → next: `/land-and-deploy` (deploy)
9. Deployed, no canary report (and gstack canary present) → next: `/canary`
10. Canary GREEN → next: `/retro` + `/harness-dashboard`

With `--auto`: project the remaining path through the gates (read-only); **stop the
projection at the first RED/YELLOW/NEEDS_HUMAN gate** and print the **exact remediation
skill** (see Gate Failure Routing). It never advances delivery itself.

**Router invariant: `/lifecycle` NAMES the next skill and reads its decision signal; it
never invokes a delivery skill, mutates source, or advances a phase. The day it does, that
logic moves to gstack — anti-bloat rule 5 + the SIGNAL-not-ARTIFACT bright line.**

#### Structured next-step output (`--emit-next` / `--auto`, advisory)

With `--emit-next` (implied by `--auto`), also write the route just computed to
`.claude/signals/lifecycle-next.json` so a native **Dynamic Workflow / Agent Team** can
auto-load the next skill's args without re-parsing prose. This is **routing METADATA, not a
gate and not a command** — emitting it is still "naming", not invoking. Consumers CHOOSE to
act on it; `/lifecycle` never runs the named skill. (Schema note in docs/SIGNALS.md — it is
explicitly NOT one of the two default-deny decision signals.)

```bash
mkdir -p .claude/signals
# PHASE, SKILL, REASON, ARGS[], PREREQS[], GATES[], ABORT_ON[] come from the detection above.
# Build JSON with python3/jq/printf (correct escaping). advisory:true is mandatory.
# e.g. {"schema_version":1,"timestamp":"…","phase":"review","skill":"/harness-review",
#       "reason":"verify GREEN, no review yet",
#       "config_hints":{"args":["--plan","plan-…"],
#         "prerequisites":[".claude/signals/verify-latest.json"],
#         "gates":["verify-latest decision=GREEN"]},
#       "abort_on":["RED","YELLOW","NEEDS_HUMAN"],"advisory":true}
```

Absent file ⇒ no projection cached; a consumer falls back to running `/lifecycle next` itself.
Never default-deny on it — it is a convenience, not a gate.

### `ideate` — Requires gstack → `/office-hours`
### `plan` — Requires gstack → `/autoplan` or individual review passes
### `decompose` — Bridge design doc to `/spec-to-task`

Find most recent design doc from `~/.gstack/projects/{SLUG}/`, extract feature
description, technical decisions, scope. Recommend `/spec-to-task` with that context.

### `execute` — Guide through task execution from active plan

### `verify` — Recommend `/verify --plan {plan-id}`, then read its signal

`/verify` owns the decision and writes `.claude/signals/verify-latest.json` (schema in
docs/SIGNALS.md). Once `/verify` has run, read the signal and route on `decision` —
symmetric to the review gate:

- `GREEN` → proceed.
- `RED` → stop; route per Gate Failure table.
- `YELLOW` → ask the user.
- signal missing / malformed JSON / **unknown `schema_version`** → **default-deny**: treat as
  "re-run `/verify`"; do NOT advance under `--auto` (symmetric to the review gate; docs/SIGNALS.md).

### `review` — Composition-aware; reads decision signal

Recommend `/harness-review --plan {plan-id}`. Then conditionally:
- If `UI_TOUCHED > 0` and gstack present and not `--no-ux` → recommend `/design-review` (or invoke if `--ux`); `/devex-review` for DX-heavy changes
- If `--with-codex` and gstack present → recommend invoking `/codex` for cross-model audit
- If `--with-cso` and gstack present → recommend invoking `/cso` for deep security
- Merge findings via `/harness-review`'s dedup tags

After `/harness-review` has run, read `.claude/signals/review-latest.json` and route on
the **decision tag** (schema in docs/SIGNALS.md) — the flow-efficiency lever that
compresses "未决态":

```bash
SIGNAL=".claude/signals/review-latest.json"
# Default-deny: validate schema_version too, not just decision (docs/SIGNALS.md). An
# unrecognized version is treated as a hard halt, exactly like a missing/malformed signal.
KNOWN_SCHEMA=1
DECISION="NEEDS_HUMAN"   # default-deny: missing / malformed / unknown-version (Anti-Bloat rule 13)
if [ -f "$SIGNAL" ]; then
  DECISION=$(python3 -c "import json,sys; s=json.load(open('$SIGNAL')); sys.exit(1) if s.get('schema_version')!=$KNOWN_SCHEMA else print(s['decision'])" 2>/dev/null) || DECISION="NEEDS_HUMAN"
fi
echo "review-decision: $DECISION"
```

**Routing rules (the agent reading this router must obey):**

- `APPROVE` → the projected next step is `ship` (gstack `/ship`). Report it; do not invoke it.
- `REQUEST_CHANGES` → **end the projection**; surface `.claude/metrics/reviews.jsonl`
  P0/P1 findings; the next step is back to `execute` (after the user confirms).
- `NEEDS_HUMAN` → branch on `needs_human_kind` (set by `/harness-review`; see docs/SIGNALS.md):
  - `composition-skipped` → **auto-recoverable**: the next step is to re-run the skipped
    composition (`/codex` or `/cso`), NOT a human halt. Report it and continue the projection.
  - `arch-ambiguity` | `judgment-slop` (or `needs_human_kind` absent) → **halt unconditionally**;
    print the verbose review summary and yield to the user, regardless of `--auto`.
- signal absent / malformed JSON / unknown `schema_version` → **default-deny**: treat as a
  hard `NEEDS_HUMAN` halt (per docs/SIGNALS.md). Never advance on a missing/unreadable signal.

### `ship` — Requires gstack → `/ship` (or guide manual PR)

Pre-flight reads `.claude/signals/verify-latest.json` and `.claude/metrics/reviews.jsonl`.

### `deploy` — Requires gstack → `/land-and-deploy`

### `canary` — Requires gstack → `/canary` (post-deploy monitoring window)

If absent in gstack version → skip with notice; not a gate failure.

### `retro` — Invoke `/harness-dashboard`, suggest gstack `/retro`

### `improve` — Guide through feedback encoding

Scan `investigations.jsonl` for unencoded entries; suggest `/encode-mistake` for each.

### `recover` — Diagnose failed state (always safe)

Check for: orphaned VERSION bumps, uncommitted changes, failed verify signal,
stalled plans (7+ days), worktree drift. Recommend recovery actions; never destructive.

## Gate Failure Routing (flow-efficiency table)

When a gate fails in `next --auto`, print **exactly one** of these next-step lines
so the developer (or the next agent invocation) doesn't have to search:

| Failed gate | Symptom | Remediation skill |
|-------------|---------|-------------------|
| verify (lint) | lint errors | run formatter; if recurring → `/encode-mistake` |
| verify (build) | build broken | fix; if env issue → `/investigate` (gstack) |
| verify (test) | test red | fix; if flaky → `/encode-mistake` for retry policy |
| verify (arch) | layer violation | refactor per `/arch-guard` output |
| verify (no decision) | `verify-latest.json` missing / malformed / unknown `schema_version` | default-deny: re-run `/verify`; never advance under `--auto` (docs/SIGNALS.md) |
| review (slop) | duplicates / over-engineering | refactor; if pattern → `/encode-mistake --proactive` |
| review (security) | secrets / OWASP issue | run `/cso` (gstack) for deep audit; fix root cause |
| review (UX) | UI quality flag | run `/design-review` (gstack); apply suggestions |
| review (cross-model) | `/codex` disagrees | reconcile; if model preference issue → discuss in `/retro` |
| ship (CI red) | PR build failed | `/investigate` (gstack); then re-`/verify` |
| deploy | smoke failed | `/canary` (gstack) if available; rollback decision |
| canary | regression detected | `/investigate` → `/encode-mistake` to prevent recurrence |
| any (unknown) | confusion signal raised (gstack v0.18+ Confusion Protocol) | log to `.claude/metrics/confusion.jsonl`; surface in next `/harness-dashboard` |
| review (no decision) | signal missing / malformed / unknown `schema_version` | default-deny: hard `NEEDS_HUMAN` halt; never advance (docs/SIGNALS.md) |
| review (`NEEDS_HUMAN`: `composition-skipped`) | `/codex` or `/cso` was skipped | auto-recoverable: next step is re-run the skipped composition; not a human halt |
| review (`NEEDS_HUMAN`: `arch-ambiguity` / `judgment-slop`) | architectural ambiguity or judgment-dependent slop | halt; surface verbose `reviews.jsonl` for user |

## Rules

- Phase ordering is advisory — users can skip, but warn about gaps
- Artifact handoffs are automatic — design docs flow into spec-to-task; verify writes signal
- Both plugins optional — adapts to what's installed
- NAME, don't invoke — `next` reports the next skill + reads its signal; it never runs a
  delivery skill or advances a phase (the one place this plugin used to actually orchestrate)
- `--auto` projects the remaining gated path (read-only); **stop the projection on the first
  RED/YELLOW/NEEDS_HUMAN** and emit the Gate Failure routing line
- `recover` is always safe — diagnoses only, never destructive
- **Worktree-aware**: never operate across `.gstack-worktrees/` siblings
- **Composition over duplication**: defer slop-deep / security-deep / UX to gstack skills
- **Capability detection over version pinning**: probe artifact presence, not version strings
- Confusion signals (gstack v0.18+) are first-class legibility input — always logged
- **Router, never executor**: this skill names the next skill to run; if it starts
  *implementing* a phase (e.g. drafting a CHANGELOG), that logic belongs in gstack
- **Review decision signal is mandatory**: `next` will not auto-advance past `review`
  without `.claude/signals/review-latest.json`; missing signal ⇒ `NEEDS_HUMAN`
- **`lifecycle-next.json` is advisory metadata, NOT a gate** — `--emit-next`/`--auto` may
  write it for workflow convenience (`advisory:true`); emitting it is still NAMING. Consumers
  choose to act; `/lifecycle` never invokes the named skill. Never default-deny on its absence.
