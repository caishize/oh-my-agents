# Oh-My-Agents — Harness Engineering Toolkit

A Claude Code plugin that implements OpenAI's harness engineering best practices:
structured documentation, mechanical constraint enforcement, and entropy management.

## Quick Start

Copy `.claude/` directory into your project root, or selectively copy individual
skills/agents/hooks you need.

## Architecture

This plugin provides three layers matching the harness engineering pillars:

1. **Context Engineering** → `context-engineer` skill, CLAUDE.md conventions
2. **Architectural Constraints** → `arch-guard` skill + agent + hooks
3. **Entropy Management** → `entropy-sweep` skill + agent

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for full design details.

## Skills (User-invocable slash commands)

| Command | Purpose |
|---------|---------|
| `/context-engineer` | Set up CLAUDE.md + structured docs/ directory |
| `/arch-guard` | Analyze and enforce architectural constraints |
| `/entropy-sweep` | Detect docs drift, dead code, constraint violations |
| `/harness-review` | Code review with harness impact analysis |
| `/spec-to-task` | Convert specs into agent-friendly task breakdowns |

## Agents (Auto-dispatched subagents)

| Agent | Purpose |
|-------|---------|
| `arch-guard-agent` | Background architectural compliance checker |
| `entropy-sweep-agent` | Background entropy scanner |
| `harness-reviewer` | Code review agent with restricted tools |

## Hooks

| Hook | Event | Purpose |
|------|-------|---------|
| `arch-check.sh` | PreToolUse (Edit/Write) | Validate layer boundaries before file changes |
| `doc-drift-check.sh` | Stop | Check for documentation drift after changes |

## Key Principles

- Make tacit knowledge explicit — agents have no tribal knowledge
- Enforce mechanically — rules not checked by linters/tests don't exist
- Error messages are context — lint errors must include remediation instructions
- Start simple — good CLAUDE.md + pre-commit hooks beat complex middleware
- Build rippable harnesses — keep constraints easy to update as models improve
