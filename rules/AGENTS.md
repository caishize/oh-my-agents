---
trigger: always_on
description: Core oh-my-agents harness rules, architecture layer boundaries, and verification gates
---

# oh-my-agents — Antigravity Harness Rules

## Architecture & Layer Dependency Order

Enforce strict unidirectional dependencies across the 6 canonical layers:
`Types (0) -> Config (1) -> Repo (2) -> Service (3) -> Runtime (4) -> UI (5)`

- A module at layer `N` may only import from layers `<= N`.
- Cross-cutting concerns (auth, logging, telemetry, feature flags) enter through the single `Providers` interface configured in `.claude/harness.json`.

## Antigravity CLI Tool Mapping & Slash Skills

- **Skills** are invoked directly as `/<skill-name>` in Antigravity CLI (not `/oh-my-agents:<skill-name>`):
  `/harness-init`, `/legibility-score`, `/spec-to-task`, `/verify`, `/encode-mistake`, `/arch-guard`, `/entropy-sweep`, `/harness-review`, `/harness-dashboard`, `/gstack-sync`, `/lifecycle`.
- **Native Tools**:
  - File inspection: `read_file` / `view_file`, `grep_search`, `find_by_name`
  - File edits (guarded by `PreToolUse` and recorded by `PostToolUse`): `write_file`, `edit_file`, `write_to_file`, `replace_file_content`, `multi_replace_file_content`
  - Shell execution (guarded by `PreToolUse`): `run_command`
  - Subagent delegation: `invoke_subagent` (read-only `research` subagent for independent verification/audit)
- **Plugin & Project Root Resolution**: Antigravity does not set `CLAUDE_PLUGIN_ROOT`. Always resolve `hooks/lib/common.sh` explicitly with non-empty, non-`/` candidate checks (including `git rev-parse --show-toplevel` for subdirectory invocations) and fail closed before any write if unavailable; use `ROOT=$(harness_root) && ensure_harness_dir "$ROOT" ...` so state is written only to the validated project root.

## Gate API & Safety Invariants

- Never hardcode credentials, tokens, passwords, or private keys in file edits or `run_command` calls.
- Never bypass or auto-approve permission gates (`auto_approve` and `permissionOverrides` are prohibited).
- Decision signals live under `.claude/signals/{verify,review}-latest.json` (`schema_version: 1`, default-deny when absent, unknown schema, or stale commit/worktree).
- `workflows/harness-audit.js` is a Claude Code Dynamic Workflow and is not loaded as a native Antigravity CLI slash workflow; in Antigravity CLI, run `/harness-review` (using `invoke_subagent` with read-only `research` subagents for multi-pillar fan-out) and persist only via the accountable-writer recipe in `docs/SIGNALS.md`.
