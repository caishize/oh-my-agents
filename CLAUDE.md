# Oh-My-Agents — Harness Engineering Plugin for Claude Code

Implements OpenAI's harness engineering methodology (four pillars) adapted for Claude Code.
Deep integration with [gstack](https://github.com/garrytan/gstack.git) for full-lifecycle coverage.

## Skills (User-invocable)

### Core Harness Skills

| Command | Pillar | Purpose |
|---------|--------|---------|
| `/harness-init` | All | Initialize harness: CLAUDE.md, docs/, bootstrap, config |
| `/legibility-score` | All | 10-metric Agent Legibility Score (0-30) |
| `/spec-to-task` | Documentation | Convert specs to execution plans with lifecycle |
| `/verify` | Architecture | Post-execution check: build, test, lint, arch guard |
| `/encode-mistake` | Entropy | Convert mistakes OR expert taste into permanent rules |
| `/arch-guard` | Architecture | Enforce architectural constraints and Providers |
| `/entropy-sweep` | Entropy | Scan for slop, drift, violations, dead code |
| `/harness-review` | Entropy | Code review with auto gstack dual-review integration |
| `/harness-dashboard` | Observability | Metrics overview + deep-dive queries |

### gstack Integration Skills

| Command | Purpose |
|---------|---------|
| `/gstack-sync` | Detect gstack, configure artifact bridges, sync metrics |
| `/lifecycle` | Full lifecycle orchestrator: guides through all phases |

## Agents (Read-only background)

| Agent | Purpose |
|-------|---------|
| session-observer-agent | Session tracking and shift-handoff |
| doc-gardening-agent | Documentation gardening and drift repair |

## Hooks (Automatic enforcement)

| Hook | Event | Behavior |
|------|-------|----------|
| arch-check.sh | PreToolUse | Blocks layer violations, Providers bypass |
| safety-check.sh | PreToolUse | Blocks hardcoded secrets and risk patterns |
| bash-safety-check.sh | PreToolUse | Blocks credential leaks in bash commands |
| self-verify-check.sh | PostToolUse | Warns on type/syntax errors after edit |
| session-metrics.sh | PostToolUse | Records tool usage and hook performance |
| doc-drift-check.sh | Stop | Warns about documentation drift |

## Four Pillars

1. **Architecture as Guardrails** — Layer model, Providers, mechanical enforcement
2. **Documentation as System of Record** — Nested CLAUDE.md, exec-plans, progressive disclosure
3. **Observability & Legibility** — Session metrics, dashboard, shift-handoff
4. **Entropy Management** — Slop detection, doc-gardening, golden principles

## Workflow

Full lifecycle details: [docs/WORKFLOW.md](docs/WORKFLOW.md)

**One-time setup:**
1. `/harness-init --quick` + `/gstack-sync --setup`

**Daily cycle (with gstack — full lifecycle):**
2. `/lifecycle next` (auto-guides) or manually:
   `/office-hours` → `/autoplan` → `/spec-to-task` → develop → `/verify` → `/harness-review` → `/ship`

**Daily cycle (oh-my-agents only):**
3. `/spec-to-task` → develop → `/verify` → `/harness-review`

**When agents make mistakes:**
4. `/investigate` (gstack) → `/encode-mistake` (oh-my-agents) → permanent guardrail

**Weekly / pre-release:**
5. `/entropy-sweep` → `/retro` + `/harness-dashboard` → `/gstack-sync --metrics`

## gstack Integration

oh-my-agents and gstack are complementary:
- **gstack** accelerates delivery: ideation → planning → review → shipping → deployment → monitoring
- **oh-my-agents** enforces quality: architecture → entropy → observability → documentation

Key integration points:
- Design docs from `/office-hours` auto-feed into `/spec-to-task`
- `/verify` emits readiness signals consumed by gstack's `/ship`
- `/harness-review` auto-detects gstack for dual-review with deduplication
- `/harness-dashboard` includes gstack metrics (skills, reviews, lifecycle coverage)
- `/investigate` → `/encode-mistake` closes the feedback loop permanently
- `/lifecycle` orchestrates the full cycle regardless of which plugins are installed
