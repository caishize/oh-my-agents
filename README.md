# oh-my-agents

Claude Code skills collection based on OpenAI's **Harness Engineering** principles — the discipline of designing environments, constraints, and feedback loops that make AI coding agents work reliably.

## Background

OpenAI's harness engineering framework identifies three core pillars for effective AI-assisted development:

1. **Context Engineering** — Structured documentation that gives agents the right information at the right time
2. **Architectural Constraints** — Mechanical enforcement of boundaries through linters, structural tests, and CI
3. **Entropy Management** — Continuous detection and repair of documentation drift, constraint violations, and dead code

## Skills

| Skill | Description |
|-------|-------------|
| `context-engineer` | Set up CLAUDE.md as a table of contents with structured `docs/` directory |
| `arch-guard` | Analyze and enforce architectural constraints through linters and structural tests |
| `entropy-sweep` | Detect docs drift, constraint violations, dead code, and inconsistencies |
| `harness-review` | Code review evaluating architectural compliance and harness impact |
| `spec-to-task` | Convert feature specs into agent-friendly tasks with explicit context |

## Usage

### Install as Claude Code plugin

```bash
claude plugins add /path/to/oh-my-agents
```

### Use skills directly

Copy any `skills/*/SKILL.md` into your project's `.claude/skills/` directory:

```bash
# Example: add the context-engineer skill
mkdir -p .claude/skills/context-engineer
cp oh-my-agents/skills/context-engineer/SKILL.md .claude/skills/context-engineer/
```

### Quick start

1. **New project?** Start with `context-engineer` to set up your documentation structure
2. **Existing project?** Run `entropy-sweep` to find what needs fixing
3. **Adding features?** Use `spec-to-task` to break specs into agent-friendly tasks
4. **Reviewing code?** Use `harness-review` for harness-aware code review
5. **Enforcing rules?** Use `arch-guard` to set up mechanical constraint enforcement

## Principles

These skills follow key harness engineering principles:

- **Make tacit knowledge explicit** — Agents have no tribal knowledge; document everything
- **Enforce mechanically** — Rules that aren't enforced by linters/tests don't exist
- **Error messages are context** — Lint errors should include remediation instructions
- **Start simple** — A good CLAUDE.md and pre-commit hooks beat complex middleware
- **Build rippable harnesses** — Keep constraints easy to update as models improve
- **Documentation lives in the repo** — Not in Slack, not in wikis, in the repository

## References

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)
- [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [OpenAI: Building an AI-Native Engineering Team](https://developers.openai.com/codex/guides/build-ai-native-engineering-team/)
