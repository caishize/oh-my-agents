---
name: harness-dashboard
description: "Summarize measured verification, review, architecture and legibility health from local ledgers. Use for project health, trends or a metrics query. 仪表盘、健康指标、趋势。"
---

# Harness Dashboard

Resolve the project root; read `.codex/metrics/`, `.codex/signals/`, active plans and config.
This is a read-only report. Arguments may select a `--query` dimension or time window.
Read DEEP-DIVE.md for the query rubric, then apply only supported dimensions.

- Verification: actual counts, decisions, first-pass evidence and repeated failure reasons.
- Review: confirmed severities, decisions and typed finding remedies.
- Architecture: layer balance from `session-*.jsonl`; metrics cover native apply_patch edits
  only, so label missing shell/cloud edits. Do not present edit counts as productivity.
- Legibility/entropy: trends only with timestamped comparable assessments; otherwise unknown.
- Plan progress: acceptance-confirmed done vs pending/in-progress/skipped.
- Optional gstack timeline/report artifacts: read-only observations with exact provenance;
  DORA approximations must be labeled proxies, not real deployment/service measurements.

Every row identifies the file and window it used. Distinguish zero from missing records,
malformed records, unsupported telemetry and unexecuted checks. Never infer passing gates
from an empty directory; use freshness from `docs/SIGNALS.md`. Do not write artifacts just
so a dashboard has data. Return a compact table and evidence-based next actions.
