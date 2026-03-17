# Oh-My-Agents — Harness Engineering Plugin for Claude Code

Implements OpenAI's harness engineering methodology (four pillars) adapted for Claude Code.

## Skills (User-invocable)

| Command | Pillar | Purpose |
|---------|--------|---------|
| `/harness-init` | All | Initialize harness: nested CLAUDE.md, docs/, bootstrap, config |
| `/legibility-score` | All | 10-metric Agent Legibility Score (0-30) |
| `/spec-to-task` | Documentation | Convert specs to execution plans with lifecycle |
| `/arch-guard` | Architecture | Enforce architectural constraints and Providers |
| `/taste-encoder` | Architecture | Encode expertise into lint rules and tests |
| `/entropy-sweep` | Entropy | Scan for slop, drift, violations, dead code, stale plans |
| `/harness-review` | Entropy | Code review: slop, safety, architecture, plan alignment |
| `/harness-dashboard` | Observability | Session metrics, plan progress, harness health |
| `/harness-metrics` | Observability | Detailed metric queries and analysis |

## Agents (Read-only background)

| Agent | Pillar | Purpose |
|-------|--------|---------|
| arch-guard-agent | Architecture | Background compliance checking |
| entropy-sweep-agent | Entropy | Background entropy scanning |
| harness-reviewer | Entropy | Background code review |
| session-observer-agent | Observability | Session tracking and shift-handoff |

## Hooks (Automatic enforcement)

| Hook | Event | Pillar | Behavior |
|------|-------|--------|----------|
| arch-check.sh | PreToolUse | Architecture | Blocks layer violations and Providers bypass |
| safety-check.sh | PreToolUse | Entropy | Blocks hardcoded secrets and risk patterns |
| session-metrics.sh | PostToolUse | Observability | Records tool usage metrics |
| doc-drift-check.sh | Stop | Documentation | Warns about documentation drift |

## Four Pillars

1. **Architecture as Guardrails** — Layer model, Providers, mechanical enforcement
2. **Documentation as System of Record** — Nested CLAUDE.md, exec-plans, progressive disclosure
3. **Observability & Legibility** — Session metrics, dashboard, shift-handoff
4. **Entropy Management** — Slop detection, doc-gardening, golden principles

## Workflow

1. `/harness-init` -> `/legibility-score` (one-time setup)
2. `/spec-to-task` -> develop -> `/harness-review` (daily cycle)
3. `/entropy-sweep` (weekly or pre-release)
4. `/harness-dashboard` (anytime — check harness health)
