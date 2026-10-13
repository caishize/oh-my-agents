---
name: gstack-sync
description: "Inspect an optional gstack installation and configure read-only artifact bridges for Codex. Use for integration status or explicit setup; never invokes Claude-only skills. gstack集成、兼容性检查。"
---

# gstack Sync

Arguments: `--status` (default), `--setup`, or `--contract-check`. This Codex plugin uses
external gstack artifacts as optional sensors; it does not install or invoke gstack's
Claude skills, hooks, Agent Teams or workflows. Read `docs/INTEGRATION.md`.

1. Resolve `PLUGIN_DIR` from this skill's installed path and source
   `"$PLUGIN_DIR/hooks/lib/common.sh"`. Call `gstack_detect`; reuse existing path/slug/gbrain
   detection instead of duplicating it. Honor GSTACK_HOME and explicit user configuration.
2. If absent, report optional integration unavailable and continue the Codex harness workflow.
   Never suggest a working Codex command merely because the Claude package exists.
3. Probe local VERSION and llms.txt, spec/design/test-plan archives, decisions.active.json,
   review logs, timeline and gbrain learnings. Read actual shapes; distinguish VERIFIED,
   ASSERTED, ABSENT and UNSUPPORTED. Avoid fetching external sources unless necessary.
4. `--setup` merges only verified bridges from `templates/integration.json` into
   `.codex/integration.json`. Preserve user settings. Do not enable network or telemetry,
   install services or mutate external gstack artifacts as an incidental side effect.
5. `--contract-check` compares consumers and current artifact schemas with the configured
   bridges. Report drift with producer/consumer paths. A Claude-era source version is not
   evidence that the same runtime works in Codex.

Consumers: spec archives → `$oh-my-agents:spec-to-task`; review verdict/findings → `$oh-my-agents:harness-review`;
timeline/report artifacts → `$oh-my-agents:harness-dashboard`; selected learning → `$oh-my-agents:encode-mistake`.
The plugin never writes gstack's files or assumes gstack shipping honors our gate.
