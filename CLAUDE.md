# Oh-My-Agents — Harness Engineering Plugin for Claude Code

Implements OpenAI's harness engineering methodology (four pillars) adapted for Claude Code.
Deep integration with [gstack](https://github.com/garrytan/gstack.git) for full-lifecycle coverage.

## Skills (User-invocable)

### Core Harness Skills

| Command | Pillar | Purpose |
|---------|--------|---------|
| `/harness-init` | All | Initialize harness: nested CLAUDE.md, docs/, bootstrap, config |
| `/legibility-score` | All | 10-metric Agent Legibility Score (0-30) |
| `/spec-to-task` | Documentation | Convert specs to execution plans with lifecycle (auto-imports gstack design docs) |
| `/verify` | Architecture | Post-execution check: build, test, lint, arch guard + gstack readiness signal |
| `/encode-mistake` | Entropy | Convert agent mistakes into permanent lint/hook rules |
| `/arch-guard` | Architecture | Enforce architectural constraints and Providers |
| `/taste-encoder` | Architecture | Encode expertise into lint rules and tests (proactive) |
| `/entropy-sweep` | Entropy | Scan for slop, drift, violations, dead code, stale plans |
| `/harness-review` | Entropy | Code review: slop, safety, architecture, plan alignment |
| `/harness-dashboard` | Observability | Session metrics, plan progress, harness health + gstack metrics |
| `/harness-metrics` | Observability | Detailed metric queries and analysis |

### gstack Integration Skills

| Command | Purpose |
|---------|---------|
| `/gstack-sync` | Detect gstack, configure artifact bridges, sync metrics |
| `/unified-review` | Dual-system review: harness + structural in one pass |
| `/lifecycle` | Full lifecycle orchestrator: guides through all phases |

## Agents (Read-only background)

| Agent | Pillar | Purpose |
|-------|--------|---------|
| arch-guard-agent | Architecture | Background compliance checking |
| entropy-sweep-agent | Entropy | Background entropy scanning |
| harness-reviewer | Entropy | Background code review |
| session-observer-agent | Observability | Session tracking and shift-handoff |
| doc-gardening-agent | Documentation | Background documentation gardening and drift repair |
| gstack-bridge-agent | Integration | Cross-system artifact health monitoring |

## Hooks (Automatic enforcement)

| Hook | Event | Pillar | Behavior |
|------|-------|--------|----------|
| arch-check.sh | PreToolUse | Architecture | Blocks layer violations, Providers bypass, sibling layer support |
| safety-check.sh | PreToolUse | Entropy | Blocks hardcoded secrets and risk patterns |
| bash-safety-check.sh | PreToolUse | Entropy | Blocks credential leaks in bash commands |
| self-verify-check.sh | PostToolUse | Architecture | Warns on type/syntax errors after edit (TS, Python, JS, Rust, Go) |
| session-metrics.sh | PostToolUse | Observability | Records tool usage, hook performance, and effectiveness metrics |
| doc-drift-check.sh | Stop | Documentation | Warns about documentation drift |

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
   `/office-hours` → `/autoplan` → `/spec-to-task` → develop → `/verify` → `/unified-review` → `/ship`

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
- `/unified-review` orchestrates both review systems with deduplication
- `/harness-dashboard` includes gstack metrics (skills, reviews, lifecycle coverage)
- `/investigate` → `/encode-mistake` closes the feedback loop permanently
- `/lifecycle` orchestrates the full cycle regardless of which plugins are installed
