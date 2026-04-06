---
name: lifecycle
description: "Full development lifecycle orchestrator — guides through Research→Plan→Execute→Verify→Review→Ship, adapting to installed plugins. Tracks phase transitions and ensures artifact handoffs. Aliases: 生命周期, 全流程, 开发流程"
user-invocable: true
argument-hint: "<phase> [--from-design <path>] [--plan <plan-id>] [--auto]"
allowed-tools: Read, Glob, Grep, Bash
---

# Lifecycle — Full Development Cycle Orchestrator

Guides through the complete lifecycle, ensuring artifact handoffs between phases.

```
IDEATE → PLAN → DECOMPOSE → EXECUTE → VERIFY → REVIEW → SHIP → DEPLOY → RETRO → IMPROVE
(gstk)   (gstk)  (harness)   (hooks)  (harness)  (both)  (gstk)  (gstk)  (both)  (harness)
```

## Task

Phase from `$ARGUMENTS`: `ideate`, `plan`, `decompose`, `execute`, `verify`, `review`,
`ship`, `deploy`, `retro`, `improve`, `status`, `next`, `recover`

- `next` — Auto-detect AND EXECUTE the next phase (not just recommend)
- `next --auto` — Chain phases automatically when gates pass
- `recover` — Diagnose and recover from failed mid-lifecycle state

## Step 0: Detect Environment

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
echo "GSTACK: ${GSTACK_PATH:-none} | HARNESS: ${HARNESS_JSON:-none} | PLANS: $ACTIVE_PLANS"
```

## Phase Router

### `status` — Show lifecycle state and next phase

Show progress for each phase based on artifact detection (design docs, plans,
verify results, review logs). Recommend the next phase.

### `next` — Auto-execute the next phase

Detection logic:
1. No design doc + gstack → execute `ideate`
2. No design doc + no gstack → execute `decompose`
3. Design doc, no plan → execute `decompose` (auto-import design doc)
4. Plan with incomplete tasks → execute `execute` (show next task)
5. All tasks done, no verify → invoke `/verify`
6. Verify passed, no review → invoke `/harness-review`
7. Review passed + gstack → invoke `/ship`
8. Deployed → invoke `retro`

With `--auto`: chain phases when gates pass. Stop at RED gates.

**CRITICAL: `/lifecycle next` EXECUTES the next skill directly, not just prints instructions.**

### `ideate` — Requires gstack → `/office-hours`
### `plan` — Requires gstack → `/autoplan` or individual review passes
### `decompose` — Bridge design doc to `/spec-to-task`

Find most recent design doc from `~/.gstack/projects/{SLUG}/`, extract feature
description, technical decisions, scope. Invoke `/spec-to-task` with context.

### `execute` — Guide through task execution from active plan
### `verify` — Invoke `/verify --plan {plan-id}`

GREEN → proceed. RED → stop, suggest `/encode-mistake`. YELLOW → ask user.

### `review` — Invoke `/harness-review --plan {plan-id}`

SHIP IT → proceed. FIX AND RESHIP → stop. NEEDS REWORK → back to execute.

### `ship` — Requires gstack → `/ship` (or guide manual PR)
### `deploy` — Requires gstack → `/land-and-deploy`
### `retro` — Invoke `/harness-dashboard`, suggest gstack `/retro`
### `improve` — Guide through feedback encoding

Scan `investigations.jsonl` for unencoded entries, suggest `/encode-mistake` for each.

### `recover` — Diagnose failed state

Check for: orphaned VERSION bumps, uncommitted changes, failed verify,
stalled plans (7+ days). Recommend recovery actions without taking destructive action.

## Rules

- Phase ordering is advisory — users can skip, but warn about gaps
- Artifact handoffs are automatic — design docs flow into spec-to-task
- Both plugins optional — adapts to what's installed
- EXECUTE, don't recommend — invoke skills directly
- `--auto` chains phases when gates pass
- `recover` is always safe — diagnoses only, never destructive
