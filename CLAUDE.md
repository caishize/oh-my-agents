# Oh-My-Agents — Harness Engineering Plugin for Claude Code

Claude Code plugin implementing OpenAI's harness engineering methodology.
Install via `/plugin install oh-my-agents` or copy components manually.

## Skills (User-invocable)

| Command | Purpose |
|---------|---------|
| `/oh-my-agents:harness-init` | Initialize harness: CLAUDE.md, docs/, bootstrap, entry points |
| `/oh-my-agents:legibility-score` | Assess the 7-metric Agent Legibility Score |
| `/oh-my-agents:taste-encoder` | Encode team expertise into lint rules and structural tests |
| `/oh-my-agents:arch-guard` | Set up architectural constraint enforcement |
| `/oh-my-agents:entropy-sweep` | Scan for slop, doc drift, violations, dead code |
| `/oh-my-agents:harness-review` | Code review with "Say No to Slop" |
| `/oh-my-agents:spec-to-task` | Convert specs into agent-friendly tasks |

## Agents (Read-only, dispatched by Claude)

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

## Workflow

1. `/oh-my-agents:harness-init` → `/oh-my-agents:legibility-score` → `/oh-my-agents:arch-guard` (one-time setup)
2. `/oh-my-agents:taste-encoder` (ongoing: encode team expertise into rules)
3. `/oh-my-agents:spec-to-task` → develop → `/oh-my-agents:harness-review` (daily cycle)
4. `/oh-my-agents:entropy-sweep` (weekly or pre-release)

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

Three pillars: Context Engineering, Architectural Constraints, Entropy Management.
