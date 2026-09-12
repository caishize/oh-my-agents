# Deep-Dive Metric Queries

Reference for `/harness-dashboard --query <type>` deep-dive analysis.

## Query: `layer-balance`

Analyze edit distribution across architecture layers:
- Overall distribution with bar chart (block characters, 10-char width)
- Concentration index (Herfindahl-style: 1.0 = all in one layer, 0.125 = balanced)
- Blind spots (layers with zero activity)
- Coupling signals (layers that always change together)

## Query: `trends`

Time-series across three categories (need 3+ data points):
1. **Legibility** — Score over time, CLAUDE.md coverage
2. **Throughput** — Tasks/session, plan completion time
3. **Entropy** — Sweep findings, doc drift warnings

Use sparkline visualization with block characters.

## Query: `velocity`

Delivery-quality leading indicators (DORA 2025/2026 + Faros/DX consensus), computed only
from data that EXISTS; every row prints `n=<sample>` and "insufficient data" below 3:

| Indicator | Source | Why it leads |
|-----------|--------|--------------|
| First-pass GREEN rate | `.claude/metrics/verify.jsonl` (`first_pass`) | rework before review |
| Re-verify count per plan_id (+ same-`reason` streaks) | `verify.jsonl` | non-converging loops; the Stop hook trips at 3 |
| Verify→review p50 | `verify.jsonl` + `reviews.jsonl` timestamps | lead-time leak between gates |
| Lifecycle coverage | gstack `projects/<slug>/timeline.jsonl` (always-on) | phases skipped |
| Recurring-failure heatmap | `verify.jsonl` `failures[].id` across 2+ sessions (typed) | `/encode-mistake` targets |

Not computed (no data source): change failure rate beyond the deploy/canary `.md` proxy,
PR revert rate, review-load metrics — name them as gaps, never print a zero.

## Query: `export`

Export all metrics as a single JSON object with keys:
`exportDate`, `dateRange`, `sessions`, `plans`, `legibility`, `entropy`, `enforcement`
