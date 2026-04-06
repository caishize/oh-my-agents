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

## Query: `export`

Export all metrics as a single JSON object with keys:
`exportDate`, `dateRange`, `sessions`, `plans`, `legibility`, `entropy`, `enforcement`
