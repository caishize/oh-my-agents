---
name: harness-metrics
description: "Deep-dive metric queries (use /harness-dashboard for the overview) — query and analyze harness engineering metrics: layer balance, plan progress, enforcement history, development patterns. Use for detailed metric analysis beyond what the dashboard shows. Aliases: 指标查询, 指标分析, 度量分析, 数据查询, 层级分析"
user-invocable: true
argument-hint: "<query: layer-balance|plan-detail|violations|trends|export>"
model: sonnet
allowed-tools: Read, Glob, Grep, Bash
---

# Harness Metrics

Deep-dive metric queries for harness engineering analysis. While `/harness-dashboard`
gives the overview, this skill answers specific questions about development patterns,
enforcement effectiveness, and plan execution.

> "What gets measured gets managed. What gets measured *well* gets managed *well*."

## Arguments

Parse `$ARGUMENTS` for the query type:
- `layer-balance` — Edit distribution across architecture layers
- `plan-detail {plan-id}` — Detailed execution plan analysis
- `violations` — Enforcement violation history and trends
- `trends` — Time-series analysis of all metrics
- `export` — Export all metrics as structured JSON

If no argument provided, show usage help listing each query type with a one-line
description.

## Data Sources

All data lives in the repository:
- `.claude/metrics/session-*.jsonl` — Session activity logs (one JSON object per line)
- `.claude/metrics/legibility-*.json` — Legibility score snapshots
- `.claude/metrics/entropy-*.json` — Entropy sweep results
- `docs/exec-plans/active/` — In-progress execution plans
- `docs/exec-plans/completed/` — Finished execution plans
- `.claude/harness.json` — Project configuration

## Query: `layer-balance`

Analyze edit distribution across architecture layers over time.

### What to Compute

1. **Overall distribution** — Total edits per layer across all sessions in range
2. **Per-session distribution** — Layer breakdown for each session
3. **Concentration index** — Herfindahl-style measure: if one layer dominates, the
   index is high (1.0 = all edits in one layer, 0.125 = perfectly balanced across 8 layers)
4. **Blind spots** — Layers with zero or near-zero activity
5. **Coupling signals** — Layers that always change together (possible tight coupling)

### Output Format

```
## Layer Balance Analysis — [date range]

### Distribution
  types:    ██░░░░░░░░  12%  (N edits across N files)
  config:   █░░░░░░░░░   4%  (N edits across N files)
  repo:     ███░░░░░░░  18%  (N edits across N files)
  service:  █████░░░░░  32%  (N edits across N files)
  runtime:  ██░░░░░░░░  10%  (N edits across N files)
  ui:       ████░░░░░░  20%  (N edits across N files)
  docs:     █░░░░░░░░░   2%  (N edits across N files)
  test:     ██░░░░░░░░   2%  (N edits across N files)

### Concentration Index: 0.XX
[Interpretation: balanced / moderately concentrated / highly concentrated]

### Blind Spots
- `test` layer: 0 edits — tests may not be keeping up with changes
- `docs` layer: 2% — documentation likely drifting

### Coupling Signals
- `service` + `repo` change together in 80% of sessions — expected or tight coupling?
- `types` + `config` change together in 60% of sessions — normal for schema changes

### Recommendations
- [Actionable items based on findings]
```

## Query: `plan-detail {plan-id}`

Deep analysis of a specific execution plan.

### What to Compute

1. **Task completion rate** — Done vs total tasks, with percentage
2. **Time per task** — Average and per-task duration from session timestamps
3. **Blocked items** — Tasks marked blocked with reasons
4. **Session history** — Which sessions touched this plan, what they accomplished
5. **Velocity** — Tasks per session, trending up or down
6. **Risk assessment** — Based on blocked items, velocity trends, remaining complexity

### Output Format

```
## Plan Detail: {plan-id} — {title}

### Progress: N/M tasks (X%)
[██████████░░░░░░░░░░]

### Completion Timeline
| Task | Status | Started | Completed | Duration |
|------|--------|---------|-----------|----------|
| Define types | done | Mar 10 | Mar 10 | 0.5h |
| Implement repo | done | Mar 10 | Mar 11 | 3.2h |
| Service layer | in-progress | Mar 12 | — | — |
| Tests | pending | — | — | — |

### Velocity
Sessions: N | Avg tasks/session: X.X | Trend: [improving/stable/declining]

### Blocked Items
- Task 5: "Waiting on API spec" — blocked since Mar 13 (4 days)

### Risk Assessment
[Low/Medium/High] — [explanation based on velocity, blocks, remaining work]

### Session History
- session-0310a (Mar 10): Completed tasks 1-2
- session-0311a (Mar 11): Completed task 2, started task 3
- session-0312a (Mar 12): Progressed task 3

### Recommendations
- [Specific actions to unblock or accelerate]
```

## Query: `violations`

Enforcement violation history and effectiveness analysis.

### What to Compute

1. **Violation counts by type** — arch-check, safety-check, doc-drift, lint, etc.
2. **Resolution rate** — Percentage of violations that were resolved in the same session
3. **Repeat offenders** — Files or patterns that trigger violations repeatedly
4. **Trend direction** — Are violations increasing, decreasing, or stable?
5. **Enforcement gaps** — Rules that exist but never trigger (possibly misconfigured)

### Output Format

```
## Violation Analysis — [date range]

### By Type
| Violation | Count | Resolved | Rate | Trend |
|-----------|-------|----------|------|-------|
| arch-check | N | N | X% | [arrow] |
| safety-check | N | N | X% | [arrow] |
| doc-drift | N | N | X% | [arrow] |

### Repeat Offenders
| File | Violations | Types |
|------|-----------|-------|
| src/service/auth.ts | 5 | arch-check (3), safety (2) |
| src/api/handler.ts | 3 | arch-check (3) |

### Enforcement Effectiveness
- Rules with high resolution rate (>80%): agents self-correct well
- Rules with low resolution rate (<50%): may need clearer error messages
- Rules that never trigger: verify they are correctly configured

### Trend Analysis
[Description of whether violations are trending up/down/stable, with interpretation]

### Recommendations
- [Specific actions based on findings]
```

## Query: `trends`

Time-series analysis across all metric categories.

### The Five Measurement Categories

Track these categories, based on OpenAI's harness engineering metrics:

1. **Legibility** — Agent Legibility Score over time, nested CLAUDE.md coverage trend
2. **Enforcement** — Hook violations per session, resolution rate over time
3. **Throughput** — Tasks completed per session, plan completion time
4. **Entropy** — Sweep finding counts over time, doc drift warning trends
5. **Safety** — Safety-check block counts, risk pattern frequency

### What to Compute

For each category with 3+ data points:
- Current value, previous value, delta
- Direction (improving, stable, declining)
- Sparkline visualization using block characters
- Notable inflection points

### Output Format

```
## Metric Trends — [date range]

### Legibility
  Score: 22/30 -> 25/30  [improving]
  CLAUDE.md coverage: 60% -> 75%  [improving]
  Sparkline: [_._.__---^^^]

### Enforcement
  Violations/session: 3.2 -> 1.8  [improving]
  Resolution rate: 65% -> 82%  [improving]
  Sparkline: [^^^---__._._ ]

### Throughput
  Tasks/session: 2.1 -> 2.4  [stable]
  Avg plan duration: 5.2 days -> 4.8 days  [improving]
  Sparkline: [__--^^--^^--]

### Entropy
  Findings: 12 -> 8  [improving]
  Doc drift: 5 -> 3  [improving]
  Sparkline: [^^^--__._.__]

### Safety
  Blocks: 1 -> 0  [stable]
  Risk patterns: 2 -> 1  [improving]
  Sparkline: [_^_._._.__. ]

### Overall Harness Health
[Composite assessment: is the harness getting better, worse, or holding steady?]
```

If fewer than 3 data points exist for a category, show current value and note
"Insufficient data for trend analysis (need 3+ data points)".

## Query: `export`

Export all metrics as structured JSON for external tools, dashboards, or analysis.

### Output

A single JSON object:

```json
{
  "exportDate": "2026-03-17",
  "dateRange": { "start": "...", "end": "..." },
  "sessions": [
    { "id": "...", "date": "...", "duration": 0, "toolCalls": 0, "filesModified": [], "layers": {}, "violations": [] }
  ],
  "plans": [
    { "id": "...", "title": "...", "status": "...", "tasksTotal": 0, "tasksDone": 0, "lastUpdated": "..." }
  ],
  "legibility": [
    { "date": "...", "score": 0, "breakdown": {} }
  ],
  "entropy": [
    { "date": "...", "findings": 0, "breakdown": {} }
  ],
  "enforcement": {
    "totalViolations": 0,
    "resolved": 0,
    "byType": {}
  }
}
```

## Handling Sparse Data

Early-stage projects will have limited metrics. Handle gracefully:

- If a query has no data at all: explain what data is needed and how to generate it
  (e.g., "Run 3+ sessions with the session-metrics hook active for trend analysis")
- If data is partial: show what exists, clearly mark gaps
- Never fabricate data or extrapolate from insufficient points
- Suggest `/harness-dashboard` for overview when detailed data is lacking

## Rules

- **Read-only** — never create, modify, or delete any files
- Handle sparse data honestly — no fabrication or extrapolation
- Show trends only when 3+ data points exist
- Every analysis section must end with actionable recommendations
- Reference `/harness-dashboard` for overview, this skill is for deep-dives
- Reference specific skills for each recommendation (e.g., `/entropy-sweep`, `/arch-guard`)
- Use consistent date formatting throughout (Mon DD or YYYY-MM-DD)
- Round all percentages to whole numbers
- Sort tables by most relevant column (count, severity, or date)
