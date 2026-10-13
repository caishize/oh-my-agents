# Codex compatibility and migration

This branch targets Codex. The original Claude Code plugin remains on `main`.
Compatibility was checked against Codex CLI **0.162.1** and official openai/codex source
commit **27e6192** during this migration. Version support should be established by the
installation smoke test rather than assumed from a version string alone.

## Native package

- `.codex-plugin/plugin.json`: plugin metadata, skills path and explicit hooks path.
- `.agents/plugins/marketplace.json`: local marketplace `oh-my-agents-codex`.
- `skills/<name>/SKILL.md`: name/description plus Codex instructions.
- `skills/<name>/agents/openai.yaml`: interface metadata and implicit-invocation policy.
- `AGENTS.md`: contributor instructions, scoped by Codex's directory precedence. Plugin
  installation does not inject this root file into arbitrary target projects; `$oh-my-agents:harness-init`
  merges target instructions on explicit request.

Supported installation commands are `codex plugin marketplace add` and `codex plugin add`.
A local marketplace installs the current checkout contents. Reinstall/refresh after plugin
source changes. For remote installation, the `codex` branch must first exist on GitHub.
This change does not publish, push, or update a user's global Codex configuration.

For skills-only installation, put the entire checkout under the project's
`.agents/skills/oh-my-agents/`. Codex recursively discovers its skills. Keep the shared docs,
hooks and templates alongside skills. No automatic hooks are registered by this method.

## Hooks and trust

A local Codex host must support and trust command hooks. Review the commands before trust
approval; marketplace installation alone does not establish that hooks execute. Plugin hook
commands receive `PLUGIN_ROOT`; quote it. `PLUGIN_ROOT` is not guaranteed in arbitrary skill
shells: resolve `PLUGIN_DIR` from the installed SKILL.md location instead.

Codex's hook-facing `apply_patch` input is `{tool_input: {command: "*** Begin Patch..."}}`.
The adapter reconstructs each updated file, including multi-file, move and EOF hunks, then
runs the deterministic existing checks. It does not apply the patch. Invalid or uninspectable
patches fail before edits with a generic error that never echoes payloads. Large patches
must be split at the 8 MiB input limit. PostToolUse uses affected paths for metrics.
Shell execution currently uses the hook name `Bash` and `tool_input.command`; the shell
check also understands `exec_command`/`shell_command` matchers and `tool_input.cmd`.

`HARNESS_PROJECT_DIR` is an optional explicit root override, not a platform-injected value.
Otherwise resolve the Git root from hook cwd, then markers from the affected file.
A shell may write source without using apply_patch; hooks are not a complete sandbox or
security boundary. Run structural tests and CI to cover those writes. Regex import checks
are intentionally lightweight and cannot replace language-aware architecture tests.

Cloud/executor hosts may decline unsigned command hooks, lack subprocess execution, or
omit lifecycle events. Do not claim those hosts enforce edits automatically. Skills,
`$oh-my-agents:verify`, `$oh-my-agents:lifecycle` and `scripts/gate.sh` provide explicit checks, subject to available
filesystem/tool permissions. No localhost web preview or runtime service is needed.

## Behavior changes

| Claude concept | Codex implementation |
|---|---|
| Claude manifest/marketplace | Native Codex manifest and .agents marketplace |
| CLAUDE.md | AGENTS.md with existing instructions preserved |
| allowed-tools | Removed; host sandbox/tool permissions enforce access |
| disable-model-invocation | `policy.allow_implicit_invocation: false` |
| `$ARGUMENTS` substitution | Read arguments in the invoking user message |
| Edit/Write content | Normalize native apply_patch per affected file |
| CLAUDE_PLUGIN_ROOT | PLUGIN_ROOT in hook commands; resolved skill path elsewhere |
| Explore/Agent tool | Fresh native evaluator when available; NEEDS_HUMAN otherwise |
| Dynamic Workflow audit | `$oh-my-agents:harness-review --audit` with explicit skeptical verification |
| .claude signals and metrics | .codex signals and metrics; no automatic evidence migration |
| gstack slash-command composition | Optional read-only artifact bridges |

## Source references

Official source used for payloads and loading contracts:
- [plugin manifest](https://github.com/openai/codex/blob/27e6192/codex-rs/core-plugins/src/manifest.rs)
- [marketplace](https://github.com/openai/codex/blob/27e6192/codex-rs/core-plugins/src/marketplace.rs)
- [hook tool names](https://github.com/openai/codex/blob/27e6192/codex-rs/core/src/tools/hook_names.rs)
- [apply_patch payload](https://github.com/openai/codex/blob/27e6192/codex-rs/core/src/tools/handlers/apply_patch.rs)
- [hook environment](https://github.com/openai/codex/blob/27e6192/codex-rs/hooks/src/engine/discovery.rs)
- [skill metadata](https://github.com/openai/codex/blob/27e6192/codex-rs/ext/skills/src/loader/metadata.rs)

An installation smoke test validates package loading, not authenticated model execution or
universal cloud hook admission. Report those separately.
