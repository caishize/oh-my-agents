---
name: lifecycle
description: "Full development lifecycle orchestrator — guides through the complete Research→Plan→Execute→Verify→Review→Ship cycle, adapting to installed plugins (gstack + oh-my-agents). Tracks phase transitions, ensures artifact handoffs, and prevents phase skipping. Aliases: 生命周期, 全流程, 开发流程, 工作流引导, 完整周期"
user-invocable: true
argument-hint: "<phase> [--from-design <path>] [--plan <plan-id>] [--skip-ideate]"
allowed-tools: Read, Glob, Grep, Bash
---

# Lifecycle — Full Development Cycle Orchestrator

Guides developers through the complete development lifecycle, ensuring proper artifact
handoffs between gstack and oh-my-agents at each phase transition. This is the "single
command to rule them all" — it knows which skill to invoke next, what artifacts to pass,
and what gates must pass before proceeding.

> "The lifecycle is the product. Each phase feeds the next. Skip a phase, and entropy
> finds the gap."

## Lifecycle Phases

```
┌─────────┐    ┌──────┐    ┌───────────┐    ┌─────────┐    ┌────────┐
│ IDEATE  │───→│ PLAN │───→│ DECOMPOSE │───→│ EXECUTE │───→│ VERIFY │
│ (gstack)│    │(gstk)│    │ (harness) │    │ (hooks) │    │(harness)│
└─────────┘    └──────┘    └───────────┘    └─────────┘    └────────┘
                                                                │
┌─────────┐    ┌──────┐    ┌──────┐    ┌────────┐    ┌─────────┐│
│ IMPROVE │←───│RETRO │←───│DEPLOY│←───│  SHIP  │←───│ REVIEW  │←┘
│(harness)│    │(both)│    │(gstk)│    │(gstack)│    │ (both)  │
└─────────┘    └──────┘    └──────┘    └────────┘    └─────────┘
```

## Task

Guide through the lifecycle phase specified in `$ARGUMENTS`.

Valid phases: `ideate`, `plan`, `decompose`, `execute`, `verify`, `review`, `ship`,
`deploy`, `retro`, `improve`, `status`, `next`, `recover`

Special arguments:
- `status` — Show current lifecycle state and next recommended phase
- `next` — Auto-detect AND EXECUTE the next appropriate phase (not just recommend)
- `next --auto` — Chain multiple phases automatically: verify→review→ship without pauses when gates pass
- `recover` — Detect and recover from failed mid-lifecycle state (orphaned version bumps, partial ships)
- `--from-design <path>` — Start decompose phase with existing design doc
- `--plan <plan-id>` — Resume from existing execution plan
- `--skip-ideate` — Start from plan phase (for well-defined tasks)

**CRITICAL: `/lifecycle next` EXECUTES the next phase directly.** It does not just print
instructions telling the user to run another command. The whole point of the lifecycle
orchestrator is to reduce context-switching cost. When you determine the next phase,
immediately invoke the corresponding skill (e.g., call `/verify`, `/unified-review`,
`/harness-dashboard`) rather than printing "Run: /verify".

## Step 0: Detect Environment

```bash
# Detect gstack
GSTACK_PATH=""
for p in "$HOME/.claude/skills/gstack" ".claude/skills/gstack"; do
  [ -d "$p" ] && GSTACK_PATH="$p" && break
done

# Detect harness
HARNESS_JSON=""
for h in ".claude/harness.json" "../.claude/harness.json"; do
  [ -f "$h" ] && HARNESS_JSON="$h" && break
done

# Current branch and state
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
HAS_UNCOMMITTED=$(git status --porcelain 2>/dev/null | head -1)
COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo 0)

# Check for existing artifacts
SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
DESIGN_DOCS=$(ls "$HOME/.gstack/projects/$SLUG/"*-design-*.md 2>/dev/null | wc -l | tr -d ' ')
ACTIVE_PLANS=$(ls docs/exec-plans/active/*.json 2>/dev/null | wc -l | tr -d ' ')
REVIEW_LOGS=$(ls "$HOME/.gstack/projects/$SLUG/"*-reviews.jsonl 2>/dev/null | wc -l | tr -d ' ')

echo "GSTACK: ${GSTACK_PATH:-none}"
echo "HARNESS: ${HARNESS_JSON:-none}"
echo "BRANCH: $BRANCH"
echo "HAS_UNCOMMITTED: ${HAS_UNCOMMITTED:+yes}"
echo "DESIGN_DOCS: $DESIGN_DOCS"
echo "ACTIVE_PLANS: $ACTIVE_PLANS"
echo "REVIEW_LOGS: $REVIEW_LOGS"
```

## Step 1: Phase Router

Based on `$ARGUMENTS`, route to the appropriate phase:

### Phase: `status`

```
═══════════════════════════════════════
  Lifecycle Status — {BRANCH}
═══════════════════════════════════════

Phase Progress:
  [✓] Ideate     — {design doc path or "skipped/not started"}
  [✓] Plan       — {review status or "skipped/not started"}
  [→] Decompose  — {plan ID and status or "not started"}
  [ ] Execute    — {task progress or "not started"}
  [ ] Verify     — {last verify result or "not started"}
  [ ] Review     — {review status or "not started"}
  [ ] Ship       — {ship status or "not started"}
  [ ] Deploy     — {deploy status or "not started"}
  [ ] Retro      — {retro status or "not started"}
  [ ] Improve    — {encode-mistake count or "not started"}

Artifacts:
  Design docs:    {count} in ~/.gstack/projects/{SLUG}/
  Exec plans:     {count} active, {count} completed
  Review logs:    {count} entries
  Harness metrics: {summary}

Next recommended: /lifecycle {next-phase}
Reason: {why this phase is next}
═══════════════════════════════════════
```

### Phase: `next`

Auto-detect the next phase based on artifact presence, then **immediately execute it**:

1. No design doc AND gstack installed → **execute** `ideate` phase
2. No design doc AND no gstack → **execute** `decompose` phase (ask for spec inline)
3. Design doc exists, no plan → **execute** `decompose` phase (auto-import design doc)
4. Plan exists with incomplete tasks → **execute** `execute` phase (show next task)
5. All tasks done, no verify → **execute** `verify` phase (run /verify --plan {id})
6. Verify passed, no review → **execute** `review` phase (run /unified-review)
7. Review passed → **execute** `ship` phase (run /ship or guide manual PR)
8. Shipped, not deployed → **execute** `deploy` phase (run /land-and-deploy)
9. Deployed → **execute** `retro` phase (run /harness-dashboard)

**With `--auto` flag**: After completing each phase, if the gate passes (e.g., verify
returns GREEN), immediately proceed to the next phase without waiting. This enables
the common `verify → review → ship` fast path in a single invocation. Stop auto-chaining
at any RED gate or phase requiring user input (ideate, plan, execute).

**Do NOT just print "Run: /verify". Actually invoke the skill.**

### Phase: `ideate`

**Requires gstack.** Guide the user to run `/office-hours`:

```
The IDEATE phase uses gstack's /office-hours to structure your thinking.
Two modes available:
  • Startup mode — 6 forcing questions for product validation
  • Builder mode — Design thinking for hackers and builders

Run: /office-hours

After completion, a design doc will be saved to:
  ~/.gstack/projects/{SLUG}/{user}-{branch}-design-{datetime}.md

Next phase: /lifecycle plan
```

If gstack is not installed, suggest the user describe their feature and proceed
directly to `decompose`.

### Phase: `plan`

**Requires gstack.** Guide through review passes:

```
The PLAN phase refines your design through structured review.

Recommended sequence:
  1. /autoplan          — Auto-run all review passes (fastest)
  OR run individually:
  1. /plan-ceo-review   — Strategy & scope review
  2. /plan-design-review — Design & UX review (if UI work)
  3. /plan-eng-review   — Architecture & engineering review

After reviews, your plan file will be updated with findings.

Next phase: /lifecycle decompose --from-design {path}
```

### Phase: `decompose`

Bridge gstack's design doc to oh-my-agents' execution plan:

1. **Find the design doc:**
   - If `--from-design` specified, use that path
   - Otherwise, search `~/.gstack/projects/{SLUG}/` for the most recent design doc
   - If no design doc found, ask the user for a feature spec

2. **Read the design doc** and extract:
   - Feature description
   - Technical decisions
   - Scope boundaries
   - Test requirements

3. **Invoke /spec-to-task** with the extracted context:
   ```
   The design doc at {path} describes: {summary}
   Key technical decisions: {list}
   Scope: {boundaries}

   Convert this into a layer-aware execution plan.
   ```

4. Report the plan ID and next steps.

### Phase: `execute`

Guide the developer through task execution:

1. Read the active execution plan
2. Show the next incomplete task
3. Remind about active hooks (arch-check, safety-check)
4. After each task completion, suggest updating the plan status

### Phase: `verify`

**Directly invoke /verify.** Find the active plan ID and run verification:

1. Find the active exec-plan: `ls docs/exec-plans/active/*.json | head -1`
2. Extract the plan ID from the filename
3. **Invoke /verify --plan {plan-id}** — actually run the verification, don't just print instructions
4. After verify completes, evaluate the result:
   - **GREEN**: Announce "Verify passed" and if `--auto`, immediately proceed to `review` phase
   - **RED**: Stop and report failures. Suggest `/encode-mistake` for recurring failures
   - **YELLOW**: Show warnings and ask whether to proceed to review

### Phase: `review`

**Directly invoke /unified-review.** Run the dual-system review:

1. Find the active plan ID (same as verify phase)
2. **Invoke /unified-review --plan {plan-id}** — actually run the unified review
3. If gstack is not installed, **invoke /harness-review** instead
4. After review completes, evaluate the verdict:
   - **SHIP IT**: Announce "Review passed" and if `--auto`, proceed to `ship` phase
   - **FIX AND RESHIP**: Stop, list critical findings, suggest fixing then re-running
   - **NEEDS REWORK**: Stop, list all findings, suggest going back to `execute` phase

### Phase: `ship`

**Requires gstack.** Invoke the ship workflow:

```
The SHIP phase creates a release-ready PR.

Pre-flight checks:
  ✓ All verify checks passed
  ✓ Both reviews completed
  ✓ Plan tasks completed
  ✓ No uncommitted changes

Run: /ship

This will: merge base → run tests → bump VERSION → update CHANGELOG →
           create PR → invoke /document-release

Next phase: /lifecycle deploy (after PR merge)
```

If gstack is not installed, guide the user through manual PR creation.

### Phase: `deploy`

**Requires gstack.** Guide through deployment:

```
The DEPLOY phase lands and monitors your change.

Run: /land-and-deploy

This will: merge PR → wait for CI → deploy → canary verify

Next phase: /lifecycle retro
```

### Phase: `retro`

**Directly invoke /harness-dashboard.** Run the harness health dashboard:

1. **Invoke /harness-dashboard** — shows session metrics, plan progress, gstack integration
2. If gstack is installed, inform the user they can also run `/retro` for velocity metrics
3. Summarize key findings and suggest next actions

### Phase: `improve`

Guide through the feedback encoding loop:

1. Review the dashboard/retro findings from the previous phase
2. For each significant issue or pattern:
   - If it's a recurring agent mistake → suggest `/encode-mistake "{description}"`
   - If it's a disliked code pattern → suggest `/taste-encoder "{pattern}"`
   - If it's accumulated entropy → suggest `/entropy-sweep`
3. After improvements are encoded, announce lifecycle completion:
   ```
   Lifecycle complete. Permanent guardrails created: {count}
   Start a new cycle: /lifecycle next
   ```

### Phase: `recover`

Detect and recover from failed mid-lifecycle state:

```bash
echo "=== Recovery Diagnostics ==="

# Check for orphaned version bump (VERSION changed but no PR)
if git diff HEAD~1 --name-only 2>/dev/null | grep -q "^VERSION$"; then
  OPEN_PRS=$(git log --oneline HEAD~1..HEAD | head -1)
  echo "VERSION_CHANGED: yes (commit: $OPEN_PRS)"
else
  echo "VERSION_CHANGED: no"
fi

# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
echo "UNCOMMITTED_FILES: $UNCOMMITTED"

# Check for failed verify
if [ -f ".claude/metrics/verify.jsonl" ]; then
  LAST_VERIFY=$(tail -1 .claude/metrics/verify.jsonl 2>/dev/null)
  echo "LAST_VERIFY: $LAST_VERIFY"
fi

# Check exec-plan state
for plan in docs/exec-plans/active/*.json; do
  [ -f "$plan" ] && echo "ACTIVE_PLAN: $(basename "$plan")" || true
done

# Check for stalled plans
find docs/exec-plans/active -name "*.json" -mtime +7 2>/dev/null | while read f; do
  echo "STALLED_PLAN: $(basename "$f")"
done
```

Based on diagnostics, recommend recovery actions:

| State | Recovery |
|-------|----------|
| VERSION bumped, no PR | Either create PR manually or `git revert` the version commit |
| Uncommitted changes after failed /ship | Stage and commit changes, then re-run `/lifecycle ship` |
| Last verify RED | Fix failing checks, then `/lifecycle verify` |
| Stalled plans (7+ days) | Review and either `/spec-to-task --continue {id}` or mark as abandoned |
| Merge conflict on base branch | Run `git merge {base}` and resolve, then resume |

## Rules

- **Phase ordering is advisory, not mandatory** — users can skip phases, but warn about gaps
- **Artifact handoffs are automatic** — design docs flow into spec-to-task without manual copy
- **Both plugins optional** — lifecycle adapts to what's installed (full vs reduced)
- **Never block on missing gstack** — offer oh-my-agents-only alternatives for each phase
- **State is inferrable** — detect phase from artifacts, don't require explicit state tracking
- **One command to continue** — `next` always knows what to do based on current state
- **EXECUTE, don't recommend** — `/lifecycle next` invokes the next skill directly; it does not
  print "Run: /skill-name" and wait. The user invoked /lifecycle to avoid typing individual
  commands. Honor that intent by actually running the skills.
- **`--auto` chains phases** — when a gate passes (verify GREEN, review SHIP IT), immediately
  proceed to the next phase without pausing. Stop at RED gates or user-input-required phases.
- **`recover` is always safe** — it diagnoses but never takes destructive action automatically.
  It recommends actions and lets the user confirm before executing.
