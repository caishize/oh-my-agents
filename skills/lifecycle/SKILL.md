---
name: lifecycle
description: "Full development lifecycle orchestrator — guides through Research→Plan→Execute→Verify→Review→Ship→Deploy→Retro→Improve, adapting to installed plugins. Tracks phase transitions, enforces artifact handoffs, names the exact remediation skill on every gate failure, and is worktree-aware. Aliases: 生命周期, 全流程, 开发流程"
user-invocable: true
argument-hint: "<phase> [--from-design <path>] [--plan <plan-id>] [--auto] [--ux] [--with-codex] [--with-cso]"
allowed-tools: Read, Glob, Grep, Bash
---

# Lifecycle — Full Development Cycle Orchestrator

Guides through the complete lifecycle, ensuring artifact handoffs and naming the
**exact remediation skill** when a gate fails — so AI-driven flow doesn't stall.

```
IDEATE → PLAN → DECOMPOSE → EXECUTE → VERIFY → REVIEW → SHIP → DEPLOY → CANARY → RETRO → IMPROVE
(gstk)   (gstk)  (harness)   (hooks)  (harness)  (both)  (gstk)  (gstk)  (gstk)  (both)  (harness)
```

## Task

Phase from `$ARGUMENTS`: `ideate`, `plan`, `decompose`, `execute`, `verify`, `review`,
`ship`, `deploy`, `canary`, `retro`, `improve`, `status`, `next`, `recover`

- `next` — Auto-detect AND EXECUTE the next phase (not just recommend)
- `next --auto` — Chain phases automatically when gates pass
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

### `next` — Auto-execute the next phase

Detection logic (in order):
1. No design doc + gstack → execute `ideate`
2. No design doc + no gstack → execute `decompose`
3. Design doc, no plan → execute `decompose` (auto-import design doc)
4. Plan with incomplete tasks → execute `execute` (show next task)
5. All tasks done, no verify signal → invoke `verify`
6. Verify GREEN, no review → invoke `review`
7. Review SHIP IT + gstack → invoke `ship`
8. Shipped, no deploy report → invoke `deploy`
9. Deployed, no canary report (and gstack canary present) → invoke `canary`
10. Canary GREEN → invoke `retro`

With `--auto`: chain phases when gates pass; **stop at any RED/YELLOW gate** and
print the **exact remediation skill** (see Gate Failure Routing).

**CRITICAL: `/lifecycle next` EXECUTES the next skill directly, not just prints instructions.**

### `ideate` — Requires gstack → `/office-hours`
### `plan` — Requires gstack → `/autoplan` or individual review passes
### `decompose` — Bridge design doc to `/spec-to-task`

Find most recent design doc from `~/.gstack/projects/{SLUG}/`, extract feature
description, technical decisions, scope. Invoke `/spec-to-task` with context.

### `execute` — Guide through task execution from active plan

### `verify` — Invoke `/verify --plan {plan-id}`

GREEN → write `.claude/signals/verify-latest.json`, proceed.
RED → stop, route per Gate Failure table. YELLOW → ask user.

### `review` — Composition-aware

Always invoke `/harness-review --plan {plan-id}`. Then conditionally:
- If `UI_TOUCHED > 0` and gstack present and not `--no-ux` → recommend `/ux-audit` (or invoke if `--ux`)
- If `--with-codex` and gstack present → recommend invoking `/codex` for cross-model audit
- If `--with-cso` and gstack present → recommend invoking `/cso` for deep security
- Merge findings via `/harness-review`'s dedup tags

SHIP IT → proceed. FIX AND RESHIP → stop. NEEDS REWORK → back to `execute`.

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
| review (slop) | duplicates / over-engineering | refactor; if pattern → `/encode-mistake --proactive` |
| review (security) | secrets / OWASP issue | run `/cso` (gstack) for deep audit; fix root cause |
| review (UX) | UI quality flag | run `/ux-audit` (gstack); apply suggestions |
| review (cross-model) | `/codex` disagrees | reconcile; if model preference issue → discuss in `/retro` |
| ship (CI red) | PR build failed | `/investigate` (gstack); then re-`/verify` |
| deploy | smoke failed | `/canary` (gstack) if available; rollback decision |
| canary | regression detected | `/investigate` → `/encode-mistake` to prevent recurrence |
| any (unknown) | confusion signal raised (gstack v0.18+ Confusion Protocol) | log to `.claude/metrics/confusion.jsonl`; surface in next `/harness-dashboard` |

## Rules

- Phase ordering is advisory — users can skip, but warn about gaps
- Artifact handoffs are automatic — design docs flow into spec-to-task; verify writes signal
- Both plugins optional — adapts to what's installed
- EXECUTE, don't recommend — invoke skills directly when called via `next`
- `--auto` chains phases; **stop on first RED/YELLOW** and emit Gate Failure routing line
- `recover` is always safe — diagnoses only, never destructive
- **Worktree-aware**: never operate across `.gstack-worktrees/` siblings
- **Composition over duplication**: defer slop-deep / security-deep / UX to gstack skills
- **Capability detection over version pinning**: probe artifact presence, not version strings
- Confusion signals (gstack v0.18+) are first-class legibility input — always logged
