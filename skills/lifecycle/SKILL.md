---
name: lifecycle
description: "Full development lifecycle orchestrator — guides through the complete Research→Plan→Execute→Verify→Review→Ship cycle, adapting to installed plugins (gstack + oh-my-agents). Tracks phase transitions, ensures artifact handoffs, and prevents phase skipping. Aliases: 生命周期, 全流程, 开发流程, 工作流引导, 完整周期"
user-invocable: true
argument-hint: "<phase> [--from-design <path>] [--plan <plan-id>] [--skip-ideate]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
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
`deploy`, `retro`, `improve`, `status`, `next`

Special arguments:
- `status` — Show current lifecycle state and next recommended phase
- `next` — Auto-detect and execute the next appropriate phase
- `--from-design <path>` — Start decompose phase with existing design doc
- `--plan <plan-id>` — Resume from existing execution plan
- `--skip-ideate` — Start from plan phase (for well-defined tasks)

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

Auto-detect the next phase based on artifact presence:
1. No design doc → suggest `ideate` (if gstack) or `decompose` (if not)
2. Design doc exists, no plan → suggest `decompose`
3. Plan exists with incomplete tasks → suggest `execute`
4. All tasks done, no verify → suggest `verify`
5. Verify passed, no review → suggest `review`
6. Review passed → suggest `ship`
7. Shipped, not deployed → suggest `deploy`
8. Deployed → suggest `retro`

Then execute that phase.

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

Run oh-my-agents' /verify and prepare for review:

```
The VERIFY phase runs: lint → build → test → arch check

Run: /verify --plan {active-plan-id}

Gate: All checks must PASS before proceeding to review.
If RED: Fix failures. Recurring failures? → /encode-mistake
If YELLOW: Review warnings before proceeding.

Next phase: /lifecycle review
```

### Phase: `review`

Orchestrate dual review:

```
The REVIEW phase uses both systems for comprehensive coverage:

Option 1 (recommended): /unified-review --plan {plan-id}
  Runs both harness and structural review in one pass.

Option 2 (manual):
  1. /harness-review    — Four-pillar harness review
  2. /review            — Structural PR review (gstack)

Both reviews must pass before shipping.

Next phase: /lifecycle ship
```

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

Run combined retrospective:

```
The RETRO phase measures what happened.

Run both:
  1. /retro                — Engineering velocity metrics (gstack)
  2. /harness-dashboard    — Governance health metrics (oh-my-agents)

Together they answer:
  - How fast did we ship? (retro)
  - How well did we maintain quality? (dashboard)
  - What patterns emerged? (both)

Next phase: /lifecycle improve
```

### Phase: `improve`

Close the feedback loop:

```
The IMPROVE phase converts lessons into permanent guardrails.

Review the retro findings and for each issue:
  1. /encode-mistake "{description}" — Convert failures to rules
  2. /taste-encoder                  — Encode preferences to lint rules
  3. /entropy-sweep                  — Scan for accumulated entropy

This completes the lifecycle. Start a new cycle with:
  /lifecycle ideate (or /lifecycle decompose for the next feature)
```

## Rules

- **Phase ordering is advisory, not mandatory** — users can skip phases, but warn about gaps
- **Artifact handoffs are automatic** — design docs flow into spec-to-task without manual copy
- **Both plugins optional** — lifecycle adapts to what's installed (full vs reduced)
- **Never block on missing gstack** — offer oh-my-agents-only alternatives for each phase
- **State is inferrable** — detect phase from artifacts, don't require explicit state tracking
- **One command to continue** — `next` always knows what to do based on current state
