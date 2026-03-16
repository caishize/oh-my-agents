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
.claude-plugin/
├── plugin.json                           # Plugin manifest
├── marketplace.json                      # Marketplace definition for distribution
skills/                                   # User-invocable slash commands
├── harness-init/SKILL.md                 # Initialize the harness
├── legibility-score/SKILL.md             # 7-metric readiness assessment
├── taste-encoder/SKILL.md                # Encode expertise into rules
├── arch-guard/SKILL.md                   # Set up constraint enforcement
├── entropy-sweep/SKILL.md                # Scan for entropy
├── harness-review/SKILL.md               # Harness-aware code review
└── spec-to-task/SKILL.md                 # Task decomposition
agents/                                   # Read-only background subagents
├── arch-guard-agent.md                   # Architectural compliance
├── entropy-sweep-agent.md                # Entropy detection
└── harness-reviewer.md                   # Code review
hooks/                                    # Event hook scripts
├── hooks.json                            # Hook event bindings (${CLAUDE_PLUGIN_ROOT})
├── arch-check.sh                         # PreToolUse: layer boundary check
└── doc-drift-check.sh                    # Stop: documentation drift warning
docs/                                     # Template docs for target projects
├── ARCHITECTURE.md                       # Layer model, boundaries, decisions
├── CONVENTIONS.md                        # Naming, size, patterns
├── TESTING.md                            # Test strategy, structural tests
├── LINTING.md                            # Lint rule registry (TASTE-NNN)
├── DECISIONS.md                          # Architecture Decision Records
└── PROVIDERS.md                          # Cross-cutting interface definition
```

## Claude Code Features Used

This plugin leverages specific Claude Code capabilities:

| Feature | Where Used | Why |
|---------|-----------|-----|
| `.claude-plugin/plugin.json` | Plugin root | Standard plugin manifest for install/update |
| `marketplace.json` | Plugin root | Distribution via `/plugin marketplace add` |
| `${CLAUDE_PLUGIN_ROOT}` | hooks.json, hook scripts | Portable path resolution within plugin |
| `allowed-tools` | legibility-score, harness-review, entropy-sweep | Enforce read-only behavior for review/scan skills |
| `memory: project` | All agents | Accumulate findings across sessions |
| `background: true` | arch-guard-agent, entropy-sweep-agent | Run scans without blocking the main conversation |
| `disallowedTools` | All agents | Prevent agents from modifying code |
| `PreToolUse` hooks | arch-check.sh | Block layer violations before Edit/Write |
| `Stop` hooks | doc-drift-check.sh | Advisory warnings after session ends |
| `$ARGUMENTS` | All skills | Pass user arguments to skill content |

## Design Decisions

### Skills vs Agents for the same concern

Skills are interactive and user-invoked — they can modify files and set things up.
Agents are read-only background workers — they report but never modify. This matches
OpenAI's principle: "Engineers own the final review and merge process."

### Read-only agents with persistent memory

All agents have `disallowedTools: Write, Edit, NotebookEdit, Agent` — they cannot
modify code or spawn sub-agents. They use `memory: project` to accumulate findings
across sessions, building institutional knowledge about architectural patterns,
recurring violations, and entropy trends. The `background: true` flag on scanning
agents lets them run without blocking the main conversation.

### Shell-based hooks

Shell hooks are portable across project types and run deterministically outside the
LLM. Error messages from hooks inject remediation instructions into agent context,
following OpenAI's pattern of "custom linter error messages that double as
remediation instructions."

### Progressive disclosure

CLAUDE.md is the table of contents (~100 lines); docs/ contains the full details.
OpenAI found that one massive instruction file failed — context is scarce and crowds
out actual task details.
