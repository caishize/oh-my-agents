# Observability

Runtime observability configuration for agent-driven development.

## App Bootstrap
<!-- How to start the app for verification -->
```bash
[startup command]
```

### Health Check
- URL: [health endpoint]
- Expected: [response]
- Startup time target: [ms]

## Logging
- Logger: [pino/winston/etc]
- Format: structured JSON
- Access via Providers interface (never direct console.log)

## Metrics Collection
Session metrics are automatically collected by the `session-metrics.sh` hook.
Stored in `.claude/metrics/session-{date}.jsonl` at the **project root** — one ledger per
project, addressed off the resolved root rather than the session's current directory, so a
monorepo does not accumulate a per-package copy that no dashboard reads.
View with `/harness-dashboard` or `/harness-dashboard --query`.

## Verification Patterns
- API endpoint test: `curl localhost:PORT/health`
- Visual verification: Use Playwright MCP for screenshots
- Log verification: `tail -f logs/app.log | grep ERROR`
