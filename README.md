# oh-my-agents

Claude Code skills, agents, and hooks implementing OpenAI's **Harness Engineering** — the
discipline of designing environments, constraints, and feedback loops that make AI coding
agents work reliably.

## Background

OpenAI's harness engineering framework identifies three pillars:

1. **Context Engineering** — Structured documentation giving agents the right info at the right time
2. **Architectural Constraints** — Mechanical enforcement of boundaries via linters, tests, and CI
3. **Entropy Management** — Continuous detection and repair of documentation drift and violations

## Project Structure

```
.claude/
├── settings.json              # Hook event bindings
├── skills/                    # User-invocable slash commands (/skill-name)
│   ├── context-engineer/      # Set up CLAUDE.md + docs/ structure
│   ├── arch-guard/            # Enforce architectural constraints
│   ├── entropy-sweep/         # Detect docs drift and dead code
│   ├── harness-review/        # Code review with harness analysis
│   └── spec-to-task/          # Convert specs into agent-friendly tasks
├── agents/                    # Background subagents (auto-dispatched)
│   ├── arch-guard-agent/      # Read-only architectural compliance checker
│   ├── entropy-sweep-agent/   # Read-only entropy scanner
│   └── harness-reviewer/      # Read-only code review agent
└── hooks/                     # Event hook scripts
    ├── arch-check.sh          # Block Edit/Write on layer violations
    └── doc-drift-check.sh     # Warn about documentation drift
```

## Installation

### Option 1: Copy entire .claude/ directory

```bash
# Clone this repo
git clone https://github.com/caishize/oh-my-agents.git

# Copy .claude/ into your project
cp -r oh-my-agents/.claude/ /path/to/your-project/
```

### Option 2: Cherry-pick specific components

```bash
# Copy just one skill
mkdir -p .claude/skills/entropy-sweep
cp oh-my-agents/.claude/skills/entropy-sweep/SKILL.md .claude/skills/entropy-sweep/

# Copy just one agent
mkdir -p .claude/agents/arch-guard-agent
cp oh-my-agents/.claude/agents/arch-guard-agent/AGENT.md .claude/agents/arch-guard-agent/

# Copy hooks (remember to chmod +x)
mkdir -p .claude/hooks
cp oh-my-agents/.claude/hooks/arch-check.sh .claude/hooks/
chmod +x .claude/hooks/arch-check.sh
```

### Option 3: Use as reference

Read the SKILL.md and AGENT.md files for inspiration and adapt to your project's needs.

## Skills (Slash Commands)

| Command | When to Use |
|---------|-------------|
| `/context-engineer` | Starting a new project or improving docs for AI agents |
| `/arch-guard` | Setting up or auditing architectural constraint enforcement |
| `/entropy-sweep` | Periodic codebase health check (weekly or pre-release) |
| `/harness-review` | Reviewing PRs or staged changes |
| `/spec-to-task` | Before implementing a feature — decompose specs into tasks |

## Agents (Auto-dispatched)

| Agent | What It Does |
|-------|--------------|
| `arch-guard-agent` | Read-only scan for layer violations, naming issues, boundary breaks |
| `entropy-sweep-agent` | Read-only scan for doc drift, dead code, inconsistencies |
| `harness-reviewer` | Read-only code review focused on harness impact |

All agents are **read-only** (Write/Edit disabled) — they report findings but never modify code.

## Hooks (Automatic)

| Hook | Event | Behavior |
|------|-------|----------|
| `arch-check.sh` | PreToolUse (Edit/Write) | **Blocks** edits that violate dependency layer boundaries |
| `doc-drift-check.sh` | Stop | **Warns** if source changes may have caused documentation drift |

## Quick Start Guide

1. **New project?** → Run `/context-engineer` to set up documentation
2. **Existing project?** → Run `/entropy-sweep` to find what's broken
3. **Adding features?** → Run `/spec-to-task` to plan agent-friendly tasks
4. **Reviewing code?** → Run `/harness-review` on your changes
5. **Enforcing rules?** → Run `/arch-guard` to set up mechanical enforcement

## Key Principles

- **Make tacit knowledge explicit** — Agents have no tribal knowledge; document everything
- **Enforce mechanically** — Rules not checked by linters/tests don't exist
- **Error messages are context** — Lint errors must include remediation instructions
- **Start simple** — A good CLAUDE.md + pre-commit hooks beat complex middleware
- **Build rippable harnesses** — Keep constraints easy to update as models improve
- **Docs live in the repo** — Not in Slack, not in wikis, in the repository

## References

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)
- [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [OpenAI: Building an AI-Native Engineering Team](https://developers.openai.com/codex/guides/build-ai-native-engineering-team/)
- [InfoQ: OpenAI Harness Engineering](https://www.infoq.com/news/2026/02/openai-harness-engineering-codex/)
