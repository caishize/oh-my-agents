# Oh-My-Agents — Harness Engineering for Claude Code

Claude Code skills, agents, and hooks implementing OpenAI's harness engineering methodology.

## Quick Start

Copy `.claude/` into your project, or cherry-pick individual skills/agents/hooks.

## Skills (User-invocable)

| Command | Purpose |
|---------|---------|
| `/harness-init` | Initialize harness: CLAUDE.md, docs/, bootstrap, entry points |
| `/legibility-score` | Assess the 7-metric Agent Legibility Score |
| `/taste-encoder` | Encode team expertise into lint rules and structural tests |
| `/arch-guard` | Set up architectural constraint enforcement |
| `/entropy-sweep` | Scan for slop, doc drift, violations, dead code |
| `/harness-review` | Code review with "Say No to Slop" |
| `/spec-to-task` | Convert specs into agent-friendly tasks |

## Agents (Auto-dispatched, read-only)

| Agent | Purpose |
|-------|---------|
| `arch-guard-agent` | Background architectural compliance check |
| `entropy-sweep-agent` | Background entropy scan |
| `harness-reviewer` | Background code review |

## Hooks (Automatic)

| Hook | Event | Behavior |
|------|-------|----------|
| `arch-check.sh` | PreToolUse (Edit/Write) | Blocks layer violations |
| `doc-drift-check.sh` | Stop | Warns about documentation drift |

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Three pillars: Context Engineering, Architectural Constraints, Entropy Management.
