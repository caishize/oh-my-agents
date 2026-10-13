# Observability

The harness records evidence whose readers are explicit:

| Record | Writer | Reader |
|---|---|---|
| .codex/metrics/session-<date>.jsonl | PostToolUse adapter → session-metrics.sh | dashboard layer balance |
| .codex/metrics/verify.jsonl | accountable $oh-my-agents:verify, locked append | lifecycle, dashboard, recurrence sensor |
| .codex/metrics/reviews.jsonl | accountable $oh-my-agents:harness-review, locked append | lifecycle, dashboard, typed fixes |
| .codex/metrics/legibility.jsonl | requested scoring run | dashboard comparisons |
| .codex/signals/*-latest.json | verifier/reviewer | gate ladder, lifecycle, explicit gate |

Session metrics are UTC timestamp/tool/file/layer observations. They cover native patch
edits only; shell writes and hosts without command hooks are incomplete coverage. Counts
are not a productivity score. Codex's own telemetry is separate and is never enabled by
this plugin. Missing or malformed data is unknown, not zero or passing.

Optional gstack timeline and deployment reports are read-only sources; report approximations
as proxies with provenance. Do not copy credential values or command payloads into metrics.
