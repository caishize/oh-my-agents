---
name: harness-dashboard
description: "Harness health overview and metric analysis — session metrics, enforcement activity, plan progress, layer balance, trends. Supports deep-dive queries (layer-balance, violations, trends, export). Aliases: 仪表盘, 看板, 运行状态, 指标查询, 度量分析"
user-invocable: true
argument-hint: "[--days N] [--plan plan-id] [--json] [--query layer-balance|violations|trends|velocity|export]"
allowed-tools: Read, Glob, Grep, Bash
---

# Harness Dashboard

Harness health overview and deep-dive metric analysis in one skill.

## Arguments

Parse `$ARGUMENTS` for:
- `--days N` — Time range in days (default: 7)
- `--plan {plan-id}` — Show detailed view of a specific execution plan
- `--json` — Output raw JSON instead of formatted text
- `--query {type}` — Deep-dive query: `layer-balance`, `violations`, `trends`, `velocity`, `export`
  - `velocity` — cross-session DORA lens from `.claude/metrics/verify.jsonl` + `reviews.jsonl`:
    first-pass-GREEN rate per plan, verify→review p50, and a recurring-failure heatmap
    (test/error patterns that failed across 2+ sessions) to target `/encode-mistake`.

If `--query` is provided, skip the overview dashboard and run the deep-dive query instead.
For deep-dive queries, compute detailed analysis with charts, trends, and recommendations.
See [DEEP-DIVE.md](DEEP-DIVE.md) for query formats and output templates.

## Task

### Step 1: Gather Data

1. **Session metrics** — Read `.claude/metrics/session-*.jsonl` files for the requested
   date range. Each line is a JSON object with session data (timestamp, duration,
   tool calls, files modified, layer touched, violations, etc.).

2. **Execution plans** — Read `docs/exec-plans/active/` for in-progress plans and
   `docs/exec-plans/completed/` for recently finished ones. Each plan is a markdown
   file with task checklists.

3. **Legibility score** — Read `.claude/metrics/legibility-latest.json` for the current
   score and `.claude/metrics/legibility.jsonl` for the trend (`/legibility-score` writes
   both; absent ⇒ "Not assessed").

4. **Entropy findings** — Read `.claude/metrics/entropy-latest.json` for current counts
   and `.claude/metrics/entropy.jsonl` for the trend (`/entropy-sweep` writes both;
   absent ⇒ "No sweep yet").

5. **Harness config** — Read `.claude/harness.json` for project configuration and
   expected module list.

6. **gstack metrics (if available)** — Check for gstack integration data. Each
   probe is presence-based — never required.

   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && gstack_detect || true
   ROOT=$(harness_root)   # `.gstack/…` globs are rooted here, never at the shell cwd

   # Usage: projects/<slug>/timeline.jsonl is ALWAYS written by gstack-skill-start/-end
   # ({skill,event:started|completed,branch,outcome,duration_s,ts}); skill-usage.jsonl is
   # telemetry-gated (default off) and is NOT read. Lifecycle coverage comes from here.
   [ -f "$GSTACK_TIMELINE" ] && \
     echo "Timeline entries: $(wc -l < "$GSTACK_TIMELINE") — skills completed (7d): $(grep -h '"completed"' "$GSTACK_TIMELINE" | grep -oE '"skill":"[^"]+"' | sort | uniq -c | sort -rn | head -8)"

   # Project artifacts
   if [ -d "$GSTACK_PROJECTS" ]; then
     echo "Reviews:    $(cat $GSTACK_PROJECTS/*-reviews.jsonl 2>/dev/null | wc -l)"
     echo "Designs:    $(ls $GSTACK_PROJECTS/*-design-*.md 2>/dev/null | wc -l)"
     echo "Test plans: $(ls $GSTACK_PROJECTS/*-test-plan-*.md 2>/dev/null | wc -l)"
     echo "QA:         $(ls $GSTACK_PROJECTS/*-test-outcome-*.md 2>/dev/null | wc -l)"
     echo "Landings:   $(ls $GSTACK_PROJECTS/*-landing-*.md 2>/dev/null | wc -l)"
   fi

   # Local-repo deploy artifacts — markdown, not JSON (`.gstack/landing-reports/` never existed)
   DEPLOY_LOCAL=$(ls "$ROOT"/.gstack/deploy-reports/*.md 2>/dev/null | wc -l)
   CANARY_LOCAL=$(ls "$ROOT"/.gstack/canary-reports/*.md 2>/dev/null | wc -l)
   echo "Deploy reports (local):  $DEPLOY_LOCAL    Canary reports (local): $CANARY_LOCAL"

   # gbrain (paths from gbrain_detect: ~/.gstack-brain-worktree + projects/<slug>/learnings.jsonl)
   [ -n "$GBRAIN_WT" ] && echo "GBrain worktree:  $GBRAIN_WT"
   echo "Learnings: $(cat $GBRAIN_LEARNINGS 2>/dev/null | wc -l) — unencoded (no taste_id, proposable to /encode-mistake): $(grep -hv '"taste_id"' $GBRAIN_LEARNINGS 2>/dev/null | wc -l)"
   [ -n "$GBRAIN_CLI" ] && echo "gbrain CLI: present"

   [ -f "$GSTACK_ANALYTICS/eureka.jsonl" ] && \
     echo "Eureka moments: $(wc -l < "$GSTACK_ANALYTICS/eureka.jsonl")"
   ```

7. **Unified review logs** — Read `.claude/metrics/reviews.jsonl` for combined review data.

### Step 2: Aggregate

Compute these from the raw data:

**Session Activity**:
- Total sessions in range
- Average session duration (minutes)
- Total tool calls across sessions
- Total files modified

**Layer Activity** — distribution of edits across architecture layers:
- Count file modifications per layer (types, config, repo, service, runtime, ui, docs, test)
- Show as horizontal bar chart using block characters
- Flag if any layer has 0 activity (possible blind spot)
- Flag if one layer has >50% of all activity (possible imbalance)

**Enforcement** — from violation records in metrics:
- Architecture check violations (total, resolved count)
- Safety check blocks
- Doc drift warnings
- Hook execution failures

**Velocity** — delivery-quality leading indicators (drives continuous improvement; full
table in [DEEP-DIVE.md](DEEP-DIVE.md#query-velocity)):
- Tasks completed per session (from exec-plan JSON transition timestamps)
- Average verify-to-review time (from verify.jsonl and reviews.jsonl timestamps)
- First-pass verify success rate (% of verify runs that return GREEN on first try)
- **Re-verify count per plan_id** (RED→…→GREEN attempts; rework before review — DORA's
  "shift AI feedback to the author phase") — from verify.jsonl
- **Gate-block rate** — `blocked_by` events per 100 edits from session-*.jsonl; prints the
  LOUD degrade `hook_results present in N of M samples` and suppresses the row at N=0
- Lifecycle coverage — which gstack phases ran, from the always-on `timeline.jsonl`
- Week-over-week trend arrows: ↑ improving, → stable, ↓ declining; 4-week sparkline when available
- Panel-wide: print `n=<sample>` and `insufficient data` below 3 samples — never a confident 0

These metrics directly drive behavior: a declining first-pass success rate signals
the need for better hooks or more `/encode-mistake` usage.

**Plan Progress** — for each active plan:
- Plan ID and title
- Tasks completed vs total
- Current status (active, blocked, stale)
- Last updated timestamp
- Flag plans not updated in 3+ days as stale

**Health Indicators**:
- Most recent legibility score (out of 30) with date
- Most recent entropy finding count with date
- Nested CLAUDE.md coverage: count of modules with their own CLAUDE.md vs total modules
- Count of stale plans (not updated in 7+ days)

### Step 3: Recommendations

Generate the top 3 actionable recommendations based on the data:

- If legibility score is below 15 -> recommend `/legibility-score` for a fresh assessment
- If entropy findings > 10 -> recommend `/entropy-sweep` for cleanup
- If a layer has 0 activity -> note potential blind spot
- If a layer has >50% activity -> note potential imbalance, check architecture
- If stale plans exist -> recommend reviewing or closing them
- If no metrics exist -> recommend activating the session-metrics hook
- If enforcement violations are trending up -> recommend `/arch-guard` review
- If doc drift warnings > 3 -> recommend `/entropy-sweep docs` scope
- If nested CLAUDE.md coverage < 50% -> recommend `/harness-init` for modules
- If gstack installed but no dual reviews -> recommend `/harness-review` for next PR
- If design docs exist without matching plans -> recommend `/spec-to-task --from-design`
- If unencoded gbrain candidates exist (candidate queue per `/lifecycle improve`) ->
  recommend `/encode-mistake --from-gbrain` (the old investigate→encode rate was circular
  — `investigations.jsonl` is the encode PROVENANCE LEDGER, not a candidate source)
- If a TASTE-NNN rule (docs/LINTING.md) has matched 0 violations in 30+ days of session
  metrics -> note it as an **evidence-gated sunset candidate** (human-reviewed, never auto-removed)
- If first-pass-GREEN rate is declining while a TASTE rule keeps matching -> the rule works;
  if the same violation recurs *despite* a rule, the enforcement is weak -> recommend `/arch-guard`
- If unencoded learnings > 5 -> recommend `/encode-mistake --from-gbrain learning`
- If a plan's re-verify count ≥ 3 with the same reason -> the loop is not converging; recommend `/investigate` (gstack) then `/encode-mistake`
- If gstack version < integration.json min_supported -> recommend `/gstack-sync --contract-check`
- If landing reports exist but DORA shows [proxy] only -> note the mapping is wired
- If lifecycle phases are skipped -> recommend `/lifecycle status` to identify gaps

### Step 4: Output

If `--json` flag is set, output all aggregated data as a single JSON object with keys:
`dateRange`, `sessions`, `layers`, `enforcement`, `velocity`, `plans`, `health`, `recommendations`.

If `--plan {id}` flag is set, show a detailed plan view:

```
## Execution Plan: {plan-id}

### Progress: N/M tasks (X%)
[Progress bar visualization]

### Tasks
| # | Task | Status | Session | Date |
|---|------|--------|---------|------|
| 1 | Implement auth types | done | session-0312a | Mar 12 |
| 2 | Add validation layer | done | session-0312a | Mar 12 |
| 3 | Wire up service | in-progress | session-0314a | Mar 14 |
| 4 | Integration tests | blocked | — | — |

### Blocked Items
- Task 4: Waiting on task 3 completion

### Session History
- session-0312a: Completed tasks 1-2, started task 3
- session-0314a: Progressed task 3, hit blocker on auth config
```

Otherwise, output the standard dashboard:

```
## Harness Dashboard — [start date] to [end date]

### Session Activity
Sessions: N | Avg duration: Xmin | Total tool calls: N | Files modified: N

### Layer Activity
  types:    ██░░░░░░░░  12%  (N edits)
  config:   █░░░░░░░░░   4%  (N edits)
  repo:     ███░░░░░░░  18%  (N edits)
  service:  █████░░░░░  32%  (N edits)
  runtime:  ██░░░░░░░░  10%  (N edits)
  ui:       ████░░░░░░  20%  (N edits)
  docs:     █░░░░░░░░░   2%  (N edits)
  test:     ░░░░░░░░░░   0%  (N edits)  <-- blind spot

### Enforcement
  arch-check violations: N (N resolved)
  safety-check blocks: N
  doc-drift warnings: N
  hook failures: N

### Active Execution Plans
| Plan | Progress | Status | Last Updated |
|------|----------|--------|--------------|
| plan-auth-refactor | 4/6 tasks | active | 2 days ago |
| plan-api-v2 | 1/8 tasks | stale | 9 days ago |

### Velocity (n={samples}; "insufficient data" below 3)
  Tasks/session:     {N} avg (↑↓→ vs last week)
  Verify→review:     {N}min avg
  First-pass GREEN:  {N}% (↑↓→ vs last week)
  Re-verify/plan:    {N} avg (RED attempts before GREEN)
  Gate-block rate:   {N} per 100 edits   (hook_results present in {n} of {m} samples; hidden at 0)
  Cycle time:        {N}h avg (plan start → verify pass)

### Harness Health
  Legibility Score: N/30 (last assessed: [date])
  Entropy Findings: N issues (last sweep: [date])
  Nested CLAUDE.md coverage: N% (N/M modules)
  Stale plans: N

### gstack Integration (if available)
  Status: {CONNECTED / NOT INSTALLED / NOT CONFIGURED}
  gstack version: {X.Y.Z.W}    min_supported: {V}    {OK | DRIFT}
  Skills completed (7d): {from projects/<slug>/timeline.jsonl — always-on}
  Reviews: {N} gstack + {N} harness = {N} total ({N} dual-reviewed)
  Design docs: {N} available
  Lifecycle coverage: {phases used} / {total phases}   (source: timeline.jsonl)
  TASTE rules encoded:     {count from docs/LINTING.md registry — "0 (registry empty — ratchet has never fired)" is a valid, honest line} (+{N} unencoded gbrain candidates)
  Deploy reports (7d):     {N}    Canary reports (7d): {N}    (.gstack/*-reports/*.md)

### DORA proxy
  deployment_frequency:    {N/week}        [proxy — count of .gstack/deploy-reports/*.md files, nothing more]
  change_failure_rate:     {N%}            [proxy — canary reports mentioning a regression / deploys]
  Note: lead_time and MTTR are NOT reported — the markdown reports carry no plan-id or
  incident-duration field we can read (deleted v3.10.0 rather than shown as structural zeros).

### Recommendations
1. [Most impactful recommendation] — run `/skill-name`
2. [Second recommendation] — run `/skill-name`
3. [Third recommendation] — run `/skill-name`
```

## Handling Missing Data

New projects will not have metrics yet. Handle gracefully:

- If no `.claude/metrics/` directory exists:
  Output a welcome message explaining the dashboard needs metrics data, and recommend
  ensuring the `session-metrics.sh` hook is active (check `hooks/hooks.json`).

- If metrics exist but are sparse:
  Show what is available, mark missing sections as "No data yet", and note the minimum
  data needed (e.g., "3+ sessions needed for trend analysis").

- If no execution plans exist:
  Skip the plans section, recommend `/spec-to-task` for creating plans from specs.

- If no legibility score exists:
  Show "Not assessed" and recommend running `/legibility-score`.

## Rules

- **Read-only** — never create, modify, or delete any files
- Handle missing data gracefully — new projects will have few or no metrics
- Keep output concise — this is a dashboard, not a report
- Every recommendation must name a specific skill to run
- Use relative dates ("2 days ago") for readability
- Bar charts use 10-character width: filled blocks + empty blocks = 10
- Round percentages to whole numbers
- Sort plans by last-updated date (most recent first)
- Use `--query` flag for deep-dive analysis (layer-balance, violations, trends, export)
