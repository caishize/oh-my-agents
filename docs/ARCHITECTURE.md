# Architecture

## Overview

oh-my-agents is a Claude Code plugin that provides skills, agents, and hooks implementing
OpenAI's harness engineering methodology. It is designed to be copied into any project's
`.claude/` directory to instantly gain harness engineering capabilities.

## Plugin Structure

```
.claude/
├── settings.json              # Hook event bindings
├── skills/                    # User-invocable slash commands
│   ├── context-engineer/      # /context-engineer — set up docs structure
│   ├── arch-guard/            # /arch-guard — enforce architecture
│   ├── entropy-sweep/         # /entropy-sweep — detect codebase entropy
│   ├── harness-review/        # /harness-review — code review
│   └── spec-to-task/          # /spec-to-task — task decomposition
├── agents/                    # Auto-dispatched subagents
│   ├── arch-guard-agent/      # Read-only arch compliance checker
│   ├── entropy-sweep-agent/   # Read-only entropy scanner
│   └── harness-reviewer/      # Read-only code reviewer
└── hooks/                     # Event hook scripts
    ├── arch-check.sh          # PreToolUse — layer boundary check
    └── doc-drift-check.sh     # Stop — documentation drift detection
```

## Harness Engineering Pillars

### 1. Context Engineering (skills/context-engineer)

Sets up the documentation layer:
- CLAUDE.md as a concise table of contents (~100 lines)
- Structured `docs/` directory as the system of record
- Machine-readable, actionable documentation

### 2. Architectural Constraints (skills/arch-guard + agents + hooks)

Three enforcement levels:
- **Hooks** (arch-check.sh): Real-time blocking on Edit/Write if layer violated
- **Agent** (arch-guard-agent): Deep read-only compliance scan
- **Skill** (/arch-guard): Interactive setup and audit of constraints

### 3. Entropy Management (skills/entropy-sweep + agents)

Two operation modes:
- **Agent** (entropy-sweep-agent): Background periodic scan
- **Skill** (/entropy-sweep): Interactive comprehensive sweep

## Dependency Layer Model

The default layer model enforced by arch-check.sh:

```
Types(0) → Config(1) → Repository(2) → Service(3) → Runtime(4) → UI(5)
```

Each layer may only import from layers with lower numbers (to its left).
Customize in `.claude/hooks/arch-check.sh` by editing the `get_layer()` function.

## Design Decisions

### Why read-only agents?

Agents run in background and may be dispatched automatically. Making them read-only
(disallowing Write/Edit) ensures they can never accidentally modify code — they only
report findings for human review.

### Why both skills and agents for the same concern?

Skills are interactive and user-invoked — they can modify files and set things up.
Agents are background workers that report findings without modification. This matches
the harness engineering principle: "Engineers own the final review and merge."

### Why shell-based hooks?

Shell hooks are portable across all project types (TypeScript, Python, Go, etc.)
and run outside the LLM, providing deterministic enforcement. They also inject
remediation instructions into agent context when violations are found.
