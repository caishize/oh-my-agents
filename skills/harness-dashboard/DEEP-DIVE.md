# Deep-Dive Metric Queries

Reference for `/harness-dashboard --query <type>` deep-dive analysis.

## Query: `layer-balance`

Analyze edit distribution across architecture layers:
- Overall distribution with bar chart (block characters, 10-char width)
- Concentration index (Herfindahl-style: 1.0 = all in one layer, 0.125 = balanced)
- Blind spots (layers with zero activity)
- Coupling signals (layers that always change together)

## Query: `violations`

Enforcement violation history:
- Counts by type (arch-check, safety-check, doc-drift)
- Resolution rate per type
- Repeat offenders (files with 2+ violations)
- Trend direction (increasing/decreasing/stable)

## Query: `trends`

Time-series across five categories (need 3+ data points):
1. **Legibility** — Score over time, CLAUDE.md coverage
2. **Enforcement** — Violations/session, resolution rate
3. **Throughput** — Tasks/session, plan completion time
4. **Entropy** — Sweep findings, doc drift warnings
5. **Safety** — Block counts, risk pattern frequency

Use sparkline visualization with block characters.

## Query: `velocity`

Delivery-quality leading indicators (DORA 2025/2026 + Faros/DX consensus), computed only
from data that EXISTS; every row prints `n=<sample>` and "insufficient data" below 3:

| Indicator | Source | Why it leads |
|-----------|--------|--------------|
| First-pass GREEN rate | `.claude/metrics/verify.jsonl` (`first_pass`) | rework before review |
| Re-verify count per plan_id (+ same-`reason` streaks) | `verify.jsonl` | non-converging loops; the Stop hook trips at 3 |
| Verify→review p50 | `verify.jsonl` + `reviews.jsonl` timestamps | lead-time leak between gates |
| Gate-block rate (`blocked_by` per 100 edits) | `session-*.jsonl` (needs `hook_results`; prints `present in N of M`, hidden at 0) | constraints catching defects at edit time |
| Lifecycle coverage | gstack `projects/<slug>/timeline.jsonl` (always-on) | phases skipped |
| Recurring-failure heatmap | `verify.jsonl` failing-test names across 2+ sessions | `/encode-mistake` targets |

Not computed (no data source): change failure rate beyond the deploy/canary `.md` proxy,
PR revert rate, review-load metrics — name them as gaps, never print a zero.

## Query: `export`

Export all metrics as a single JSON object with keys:
`exportDate`, `dateRange`, `sessions`, `plans`, `legibility`, `entropy`, `enforcement`
