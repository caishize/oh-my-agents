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

## Four Pillars

### 1. Architecture as Guardrails

Mechanical enforcement of boundaries so agents can't accidentally violate rules.

- **Rigid layered architecture**: Types → Config → Repo → Service → Runtime → UI
- **Providers interface**: Cross-cutting concerns (auth, telemetry, feature flags)
  channeled through a single interface — never accessed directly
- **Custom linters with remediation in error messages** — error messages are agent context
- **Structural tests** validating layer boundaries, naming, file sizes
- **"Taste invariants"** — encoding team expertise into mechanical rules

Implemented by: `/arch-guard`, `/encode-mistake --proactive`, `arch-check.sh`

### 2. Documentation as System of Record

Making the codebase legible to agents through structured documentation.

- **CLAUDE.md as table of contents** (~100 lines, progressive disclosure)
- **docs/ as system of record** (structured, machine-readable, in-repo)
- **Structured formats > prose** (agents comply better with JSON/YAML rules)
- **No tacit knowledge** — if it's not in the repo, it doesn't exist

Implemented by: `/harness-init`, `/legibility-score`, `/spec-to-task`

### 3. Observability & Legibility

Agents and humans can see what happened, why it happened, and where the system stands.

- **Session metrics** — tool usage, layer activity, enforcement events tracked per session
- **Harness dashboard** — aggregated health overview and trend analysis
- **Shift-handoff** — session observer writes structured summaries to agent memory
- **Nested CLAUDE.md** — module-level context for agent navigation

Implemented by: `/harness-dashboard`, `/harness-dashboard --query`, `session-observer-agent`,
`session-metrics.sh`

### 4. Entropy Management ("Garbage Collection")

Continuous detection and repair of codebase degradation.

- **"Say No to Slop"** — maintain strict review standards, never lower the bar
- **Automated scanning** — evolved from manual Friday cleanup to scheduled agent sweeps
- **Documentation drift detection** — verify docs match reality
- **Missing enforcement detection** — rules without lint/test enforcement are suggestions

Implemented by: `/entropy-sweep`, `/harness-review`, `doc-drift-check.sh`, `/encode-mistake`

## Mapping to the Planner / Generator / Evaluator topology

The multi-agent harness pattern (InfoQ, 2026-04) decomposes long-running coding work
into three roles — **Planner**, **Generator**, **Evaluator** — connected by structured
handoff artifacts and context resets. As of **Feb 2026, Claude Code ships this topology
natively** as **Agent Teams** (a team-lead session coordinating peer sessions via a
shared task list + mailbox; gated behind `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). gstack
adds the same kind of parallelism through Conductor workspaces.

oh-my-agents does **not** reimplement this coordination — that is now a platform/gstack
concern. Instead, oh-my-agents is the **per-role guardrail + evidence layer that a team
runs *inside***: it constrains the Generator (PreToolUse hooks), supplies the Evaluator
its decision artifacts (`verify-latest.json`, `review-latest.json` — exactly what a
team-lead routes on), and persists memory between context resets (TASTE rules, nested
CLAUDE.md). This is the narrative anchor for *where a concern belongs*.

| Role | What oh-my-agents contributes | gstack / native counterpart | Handoff artifact |
|------|-------------------------------|-----------------------------|------------------|
| **Coordination** | — (deliberately none) | **native Agent Teams**; gstack Conductor | shared task list / mailbox |
| **Planner** | `/spec-to-task` (layer-aware decomposition) | `/office-hours`, `/autoplan` | `docs/exec-plans/active/*.json` |
| **Generator constraints** | `arch-check`, `safety-check`, `bash-safety-check` (PreToolUse hooks) | `/guard` (freeze/careful) | hook block + remediation message in agent context |
| **Evaluator** | `/verify` + `/harness-review` (decision signals) | `/codex`, `/cso`, `/design-review`, `/qa` | `.claude/signals/verify-latest.json`, `.claude/signals/review-latest.json` |
| **Memory between resets** | nested CLAUDE.md, `docs/LINTING.md` (TASTE rules) | GBrain (`learnings-log`, `timeline-log`, `eureka`) | one-direction bridge: observation → enforcement |
| **Loop closure** | `/encode-mistake --from-gbrain` (human-gated) | `/investigate`, `/retro` | TASTE-NNN rule with `taste_id` ↔ learning-id back-reference |

**Key implication**: when adding capability, ask *which role does this serve, and is it
already served by the platform or gstack?* If coordination — defer to native Agent Teams.
If a role gstack covers — defer to gstack. oh-my-agents only owns the constraint + evidence
surfaces that are repo-local and mechanical.

## Mapping the Four Pillars to OpenAI's harness-engineering components

OpenAI's published harness-engineering writeup (openai.com, Feb 2026) names ~six
components. Our Four Pillars cover four of them directly; the other two are **delegated
to gstack by composition** rather than reimplemented. This table makes coverage —
and deliberate non-coverage — auditable:

| OpenAI component | Four-Pillar / harness home | Owner |
|------------------|----------------------------|-------|
| Architectural constraints (mechanical rules + structural tests) | Pillar 1 — Architecture as Guardrails | **oh-my-agents** (hooks, arch-guard, TASTE) |
| Documentation as System of Record | Pillar 2 — Documentation as System of Record | **oh-my-agents** (`/harness-init`, docs/) |
| Observability integration (logs/metrics/spans) | Pillar 3 — Observability & Legibility | **oh-my-agents** (session-metrics, dashboard) |
| Entropy / quality maintenance | Pillar 4 — Entropy Management | **oh-my-agents** (`/entropy-sweep`, `/encode-mistake`) |
| **Structured feedback loops** (PR / CI) | decision signals (`verify-latest.json`, `review-latest.json`) + CI template | **shared** — harness emits signals; gstack `/ship` consumes; CI via `templates/github-actions-harness.yml` |
| **Isolated testing** (reproduce bugs in isolation) | *not reimplemented* | **gstack** `/investigate` + `/qa` (delegated) |

The role-shift OpenAI describes — engineers move from *implementing code* to *specifying
intent and giving structured feedback* — is realized as `/spec-to-task` (intent capture)
plus the decision-signal gates (structured, machine-readable feedback that drives the
next agent turn without a human round-trip).

## Plugin Structure

```
.claude-plugin/
├── plugin.json                           # Plugin manifest
├── marketplace.json                      # Marketplace definition for distribution
skills/                                   # User-invocable slash commands (11 skills)
├── harness-init/SKILL.md                 # Initialize the harness
├── legibility-score/SKILL.md             # 10-metric readiness assessment
├── spec-to-task/SKILL.md                 # Task decomposition with execution plans
├── verify/SKILL.md                       # Post-execution verification (build/test/lint/arch)
├── encode-mistake/SKILL.md               # Convert agent mistakes into guardrails (--proactive for taste encoding)
├── arch-guard/SKILL.md                   # Set up constraint enforcement
├── entropy-sweep/SKILL.md                # Scan for entropy
├── harness-review/SKILL.md               # Harness-aware code review (auto-detects gstack for dual review)
├── harness-dashboard/SKILL.md            # Session metrics and health overview (--query for deep-dive)
├── gstack-sync/SKILL.md                  # Detect gstack, configure bridges, sync metrics
└── lifecycle/SKILL.md                    # Full lifecycle orchestrator
agents/                                   # Read-only background subagents (2 agents)
├── session-observer-agent.md             # Session tracking and shift-handoff
└── doc-gardening-agent.md                # Documentation gardening and repair
hooks/                                    # Event hook scripts (6 hooks + shared lib)
├── hooks.json                            # Hook event bindings (${CLAUDE_PLUGIN_ROOT})
├── lib/common.sh                         # Shared utilities (JSON parsing, layer resolution)
├── arch-check.sh                         # PreToolUse (Edit|Write): layer boundary check
├── safety-check.sh                       # PreToolUse (Edit|Write): hardcoded secrets detection
├── bash-safety-check.sh                  # PreToolUse (Bash): credential leak detection
├── self-verify-check.sh                  # PostToolUse (Edit|Write): syntax/type self-verification
├── session-metrics.sh                    # PostToolUse (Edit|Write|Bash): JSONL activity logging
└── doc-drift-check.sh                    # Stop: documentation drift warning
docs/                                     # Template docs for target projects
├── ARCHITECTURE.md                       # Layer model, boundaries, decisions
├── CONVENTIONS.md                        # Naming, size, patterns
├── TESTING.md                            # Test strategy, structural tests
├── LINTING.md                            # Lint rule registry (TASTE-NNN)
├── DECISIONS.md                          # Architecture Decision Records
├── PROVIDERS.md                          # Cross-cutting interface definition
├── OBSERVABILITY.md                      # Logging, metrics, tracing strategy
├── WORKFLOW.md                           # Full development lifecycle
└── INTEGRATION.md                        # gstack integration guide and artifact bridges
templates/                                # Starter templates for target projects
├── harness-config.json                   # .claude/harness.json template
├── execution-plan.json                   # Execution plan schema
└── github-actions-harness.yml            # CI/CD enforcement workflow
tests/                                    # Plugin self-tests
├── test-hooks.sh                         # Unit tests for all hooks
└── test-skills.sh                        # Smoke tests for skill quality
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
| `background: true` | session-observer-agent | Run scans without blocking the main conversation |
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
