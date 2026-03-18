---
name: harness-dashboard
description: "High-level harness health overview (use /harness-metrics for deep-dive queries) — aggregates session metrics, enforcement activity, execution plan progress, and entropy/legibility trends. Use when you want to see how the harness is performing, check plan status, or understand development patterns. Aliases: 仪表盘, 看板, 运行状态, 健康检查, harness概览"
user-invocable: true
argument-hint: "[--days N] [--plan plan-id] [--json]"
allowed-tools: Read, Glob, Grep, Bash
---

# Harness Dashboard

The Observability pillar's primary user-facing skill. Aggregates harness metrics into
an actionable overview — session activity, layer balance, enforcement history,
execution plan progress, and health indicators.

> "If the harness is the immune system, the dashboard is the vital signs monitor."

## Arguments

Parse `$ARGUMENTS` for:
- `--days N` — Time range in days (default: 7)
- `--plan {plan-id}` — Show detailed view of a specific execution plan
- `--json` — Output raw JSON instead of formatted text

## Task

### Step 1: Gather Data

1. **Session metrics** — Read `.claude/metrics/session-*.jsonl` files for the requested
   date range. Each line is a JSON object with session data (timestamp, duration,
   tool calls, files modified, layer touched, violations, etc.).

2. **Execution plans** — Read `docs/exec-plans/active/` for in-progress plans and
   `docs/exec-plans/completed/` for recently finished ones. Each plan is a markdown
   file with task checklists.

3. **Legibility score** — Check for the most recent legibility score output in
   `.claude/metrics/legibility-*.json` or agent memory.

4. **Entropy findings** — Check for the most recent entropy sweep report in
   `.claude/metrics/entropy-*.json` or agent memory.

5. **Harness config** — Read `.claude/harness.json` for project configuration and
   expected module list.

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

**Plan Progress** — for each active plan:
- Plan ID and title
- Tasks completed vs total
- Current status (active, blocked, stale)
- Last updated timestamp
- Flag plans not updated in 3+ days as stale

**Health Indicators**:
- Most recent legibility score (out of 21) with date
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

### Step 4: Output

If `--json` flag is set, output all aggregated data as a single JSON object with keys:
`dateRange`, `sessions`, `layers`, `enforcement`, `plans`, `health`, `recommendations`.

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

### Harness Health
  Legibility Score: N/21 (last assessed: [date])
  Entropy Findings: N issues (last sweep: [date])
  Nested CLAUDE.md coverage: N% (N/M modules)
  Stale plans: N

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
- Reference `/harness-metrics` for users who want deeper analysis
