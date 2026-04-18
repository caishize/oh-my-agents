# Oh-My-Agents — Harness Engineering Plugin for Claude Code

**v3.2.0** — Implements OpenAI's harness engineering methodology (four pillars)
adapted for Claude Code. **Composition-based** integration with
[gstack](https://github.com/garrytan/gstack.git) v0.18 — slop-deep / security-deep /
UX audits delegated to gstack skills; architecture, entropy, legibility owned here.

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
| `/harness-review` | Entropy | Four-pillar review; composes gstack `/codex`, `/cso`, `/ux-audit` with dedup tags |
| `/harness-dashboard` | Observability | Metrics overview + DORA-proxy + deep-dive queries |

### gstack Integration Skills

| Command | Purpose |
|---------|---------|
| `/gstack-sync` | Detect gstack, configure bridges, sync metrics, `--contract-check` for quarterly drift review |
| `/lifecycle` | Full lifecycle orchestrator with canary phase, worktree awareness, Gate Failure Routing |

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

Key integration points (composition-based, read-only, glob-based, rippable):
- Design docs from `/office-hours` auto-feed into `/spec-to-task`
- `/verify` emits readiness signal (`.claude/signals/verify-latest.json`) for `/ship` pre-flight
- `/harness-review` delegates slop-deep → `/codex`, security-deep → `/cso`, UX → `/ux-audit`;
  tags findings `[HARNESS]`/`[STRUCTURAL]`/`[CROSS-MODEL]`/`[SECURITY]`/`[UX]`/`[BOTH+]`
- `/harness-dashboard` includes gstack metrics (skills, reviews, lifecycle, DORA proxy)
- `/investigate` → `/encode-mistake` closes the feedback loop permanently
- `/lifecycle` orchestrates full cycle + Gate Failure Routing (names exact remediation skill);
  worktree-aware, never cross-fires across `.gstack-worktrees/` siblings
- Confusion Protocol (gstack v0.18+) → `.claude/metrics/confusion.jsonl` → legibility input

Full rationale: [docs/TEAM-DISCUSSION-2026-04.md](docs/TEAM-DISCUSSION-2026-04.md).
Full bridge manifest: [docs/INTEGRATION.md](docs/INTEGRATION.md).
