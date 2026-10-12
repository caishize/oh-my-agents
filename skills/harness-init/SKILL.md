---
name: harness-init
description: "Prepare an existing project for Codex with AGENTS.md, architecture constraints, verified commands and local quality gates. Use when the user asks to initialize a harness. 初始化、Codex项目设置。"
---

# Harness Init

Prepare the existing checkout for Codex. Treat the user's request as authorization for
ordinary setup; preserve existing instructions, hooks and user changes. Never create a
worktree unless explicitly requested. Arguments are the project path and optional `--quick`
in the user's message; Codex does not substitute an `$ARGUMENTS` variable.

1. Inspect AGENTS.md files, manifests, lockfiles, scripts, CI, documentation and Git status.
   Identify working build/test/lint commands by running relevant checks, not guessing them.
2. Resolve the installed plugin root from this SKILL.md: two parent directories above its
   skill directory. Assign that absolute path to `PLUGIN_DIR` for command snippets. Read
   `docs/CODEX.md` for host limitations; plugin root variables are guaranteed only in hooks.
3. Update root AGENTS.md with a concise commands table, actual layer boundaries, conventions
   and documentation links. Keep it under 60 lines when practical. Merge rather than replace.
   Add nested AGENTS.md only where module rules differ; honor the user's authorization and
   avoid generated repository overviews. Never rename existing user files blindly.
4. Create only missing project docs: architecture, conventions, testing, lint/TASTE rules,
   decisions, providers and workflow. Record known facts and unresolved decisions separately.
5. Adapt `templates/harness-config.json` to `.codex/harness.json`: canonical layer names map
   to actual directories; `sibling_layers` uses strings such as `service:runtime`.
   Copy `templates/integration.json` to `.codex/integration.json` only for requested gstack
   integration. Its external artifacts are optional and read-only.
6. Ensure `.codex/signals/` and `.codex/metrics/` are ignored. Preserve .gitignore entries.
7. Install architecture tests appropriate to the project's framework, using the Python or
   TypeScript references in this skill directory. Replace every placeholder with real
   assertions. Merge existing pre-commit/CI checks; never replace them or install a passing
   TODO workflow. A bootstrap script uses pinned tools and frozen lockfiles.
8. For local Codex installations with trusted hooks, the plugin registers its own checks.
   Do not copy Claude settings or declare prompt text a security boundary. For skills-only
   or cloud installations, document explicit checks and CI. See `docs/CODEX.md`.
9. Run the chosen commands. Report actual outcomes, file changes, remaining decisions and
   next skill. `--quick` additionally applies legibility scoring and architecture setup
   within the authorized scope; read those skills before following their procedures.

Do not claim initialization is complete while placeholder tests or commands remain.
