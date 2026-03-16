# Architecture

## Overview

oh-my-agents implements OpenAI's harness engineering methodology as Claude Code
skills, agents, and hooks. The harness is the set of constraints, documentation,
feedback loops, and entry points that make AI coding agents work reliably.

## Origin

Based on OpenAI's internal experiment:
- 3 engineers, ~1M lines of production code, ~1,500 PRs in 5 months
- Zero hand-written code — all agent-generated
- Key insight: "The bottleneck was never the agent's ability to write code, but the
  lack of structure, tools, and feedback mechanisms surrounding it."

## Three Pillars

### 1. Context Engineering

Making the codebase legible to agents through structured documentation.

- **CLAUDE.md as table of contents** (~100 lines, progressive disclosure)
- **docs/ as system of record** (structured, machine-readable, in-repo)
- **Structured formats > prose** (agents comply better with JSON/YAML rules)
- **No tacit knowledge** — if it's not in the repo, it doesn't exist

Implemented by: `/harness-init`, `/legibility-score`

### 2. Architectural Constraints

Mechanical enforcement of boundaries so agents can't accidentally violate rules.

- **Rigid layered architecture**: Types → Config → Repo → Service → Runtime → UI
- **Providers interface**: Cross-cutting concerns (auth, telemetry, feature flags)
  channeled through a single interface — never accessed directly
- **Custom linters with remediation in error messages** — error messages are agent context
- **Structural tests** validating layer boundaries, naming, file sizes
- **"Taste invariants"** — encoding team expertise into mechanical rules

Implemented by: `/arch-guard`, `/taste-encoder`, `arch-guard-agent`, `arch-check.sh`

### 3. Entropy Management ("Garbage Collection")

Continuous detection and repair of codebase degradation.

- **"Say No to Slop"** — maintain strict review standards, never lower the bar
- **Automated scanning** — evolved from manual Friday cleanup to scheduled agent sweeps
- **Documentation drift detection** — verify docs match reality
- **Missing enforcement detection** — rules without lint/test enforcement are suggestions

Implemented by: `/entropy-sweep`, `/harness-review`, `entropy-sweep-agent`,
`harness-reviewer`, `doc-drift-check.sh`

## Plugin Structure

```
.claude/
├── settings.json                         # Hook event bindings
├── skills/                               # User-invocable slash commands
│   ├── harness-init/SKILL.md             # Initialize the harness
│   ├── legibility-score/SKILL.md         # 7-metric readiness assessment
│   ├── taste-encoder/SKILL.md            # Encode expertise into rules
│   ├── arch-guard/SKILL.md               # Set up constraint enforcement
│   ├── entropy-sweep/SKILL.md            # Scan for entropy
│   ├── harness-review/SKILL.md           # Harness-aware code review
│   └── spec-to-task/SKILL.md             # Task decomposition
├── agents/                               # Read-only background subagents
│   ├── arch-guard-agent/AGENT.md         # Architectural compliance
│   ├── entropy-sweep-agent/AGENT.md      # Entropy detection
│   └── harness-reviewer/AGENT.md         # Code review
└── hooks/                                # Event hook scripts
    ├── arch-check.sh                     # PreToolUse: layer boundary check
    └── doc-drift-check.sh                # Stop: documentation drift warning
```

## Design Decisions

### Skills vs Agents for the same concern

Skills are interactive and user-invoked — they can modify files and set things up.
Agents are read-only background workers — they report but never modify. This matches
OpenAI's principle: "Engineers own the final review and merge process."

### Read-only agents

All agents have `disallowedTools: Write, Edit, NotebookEdit`. Since agents may be
auto-dispatched, they must never accidentally modify code. They report findings for
human decision.

### Shell-based hooks

Shell hooks are portable across project types and run deterministically outside the
LLM. Error messages from hooks inject remediation instructions into agent context,
following OpenAI's pattern of "custom linter error messages that double as
remediation instructions."

### Progressive disclosure

CLAUDE.md is the table of contents (~100 lines); docs/ contains the full details.
OpenAI found that one massive instruction file failed — context is scarce and crowds
out actual task details.
