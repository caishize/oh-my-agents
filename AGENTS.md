# Oh My Agents for Codex

This branch ships a Codex plugin: 11 skills, native command hooks, and decision signals.
The Claude Code implementation remains on `main`; do not reintroduce its runtime APIs here.

## Development

- Prerequisites: Bash, Git, jq, Python 3.10+, Node 22+ for the optional Codex CLI smoke test.
- Run `bash tests/test-hooks.sh` and `python3 -m unittest discover -s tests -p 'test_*.py'`.
- Run `bash tests/test-plugin-install.sh` with Codex CLI 0.162.1+ on PATH for real installation.
- Inspect `git status --short` before and after changes. Preserve user work.
- Cloud tasks already have isolated checkouts; do not create a worktree unless requested.
- Keep each SKILL.md under 400 lines. Put contracts in docs, not duplicated skill prose.
- Skills use `$skill-name`; Codex reads AGENTS.md and `agents/openai.yaml` metadata.
- Hooks receive `apply_patch` as `tool_input.command`; the adapter checks every affected file.
- Shell writes and cloud hosts without trusted command hooks require project tests and CI.
- Gate decisions default to denial for missing, malformed, unknown, or stale evidence.
- A review requires an independent evaluator; report NEEDS_HUMAN when none is available.
- Optional gstack integration reads artifacts only. Never invoke Claude-only commands.

Read [architecture](docs/ARCHITECTURE.md), [signals](docs/SIGNALS.md),
[compatibility](docs/CODEX.md), and [testing](docs/TESTING.md) for details.
