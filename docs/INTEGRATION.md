# Optional gstack integration

The Codex branch integrates artifact contracts, not Claude runtime APIs.
`gstack_detect()` in hooks/lib/common.sh probes existing `.agents/skills` and external
`.claude/skills` installs, honors GSTACK_HOME, derives a sanitized project slug, and exposes
gbrain/timeline paths. Absence is graceful. No credentials or installation are required
for the standard Codex harness tests and gates.

`templates/integration.json` retains upstream bridge metadata and its Claude-era source
verification date for provenance; that date does not establish Codex command compatibility.
`$oh-my-agents:gstack-sync --setup` merges only verified bridges into target `.codex/integration.json`.
Existing user configuration is preserved. Unknown optional artifacts stay unknown.

| Producer artifact | Reader |
|---|---|
| Project spec archive with spec_branch | `$oh-my-agents:spec-to-task` |
| Design/test-plan archive | Planning/review context |
| Current review verdict and findings | `$oh-my-agents:harness-review` reconciliation |
| timeline.jsonl and deploy/canary reports | `$oh-my-agents:harness-dashboard` labeled proxies |
| Selected gbrain learning | Explicit `$oh-my-agents:encode-mistake --from-gbrain` |

Never write external gstack files, install its hooks, enable telemetry or infer that it
consumes `.codex/signals/`. Check current file shapes and freshness before use. Opposite
fresh review conclusions require a visible unresolved evaluation decision.

External `.claude/gstack-rendered/` remains a gstack-owned enclave, excluded from source
quality sweeps. Our harness ledgers moved to `.codex/`; existing Claude signal files are not
copied or trusted as new evidence. Runtime integration beyond these sensors needs explicit
support in gstack itself.
