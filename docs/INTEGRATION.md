# gstack ↔ oh-my-agents Integration Guide

## Philosophy

**gstack** accelerates delivery: design → ship → deploy → monitor.
**oh-my-agents** enforces quality: architecture → entropy → observability → documentation.

Together they form a complete AI engineering stack. Neither plugin modifies the other's
files or state — integration happens through structured artifact consumption and shared
metric namespaces.

## Complementary Strengths (v0.18 baseline)

| Dimension | gstack | oh-my-agents | Combined |
|-----------|--------|-------------|----------|
| Ideation | /office-hours (YC-style) | — | Design doc → execution plan |
| Planning | /autoplan (triple-voice) | — | Consensus tables → plan constraints |
| Decomposition | — | /spec-to-task (layer-aware) | Design doc auto-imported |
| Execution | /guard (freeze/careful) | hooks (arch/safety/metrics) | Dual hook systems coexist |
| Verification | — | /verify (lint→build→test→arch) | **Emits .claude/signals/verify-latest.json** for /ship pre-flight |
| Review (structural) | /review | — | Composed by /harness-review, tag `[STRUCTURAL]` |
| Review (architecture/entropy) | — | /harness-review | Owns four-pillar + dedup orchestration |
| Review (cross-model) | /codex | — | Composed when `--with-codex`, tag `[CROSS-MODEL]` |
| Review (security deep) | /cso (OWASP/STRIDE) | safety hooks (secrets) | Hooks block at edit-time; /cso owns deep audit, tag `[SECURITY]` |
| Review (UX) | /ux-audit (v0.17+) | — | Auto-suggested when UI files touched, tag `[UX]` |
| Shipping | /ship (version/changelog/PR) | — | Reads verify signal + review JSONL |
| Deployment | /land-and-deploy | — | Readiness gates include harness data |
| Monitoring | /canary | — | Health report → /harness-dashboard quality trend |
| Multi-session | conductor.json + .gstack-worktrees/ | **worktree-aware** verify/hooks | No cross-fire across sibling sprints |
| Confusion (v0.18) | Confusion Protocol | session-metrics + /harness-dashboard | Signals → .claude/metrics/confusion.jsonl |
| Documentation | /document-release | doc-drift-check hook | Auto-sync + drift detection |
| Retrospective (velocity) | /retro | — | — |
| Retrospective (governance) | — | /harness-dashboard | DORA-proxy + dual-review rate |
| Debugging | /investigate (root cause) | /encode-mistake (permanent rule) | Investigate → encode loop |
| Quality | /qa + /design-review | /entropy-sweep + /encode-mistake --proactive | QA findings → encoded rules |
| Performance | /benchmark + /canary | — | Baseline tracking + monitoring |

## Artifact Flow

```
/office-hours ──────────→ design doc
                             │ (~/.gstack/projects/$SLUG/*-design-*.md)
                             ↓
/autoplan ──────────────→ consensus tables + test plan
                             │ (~/.gstack/projects/$SLUG/*-test-plan-*.md)
                             ↓ (auto-discovered by /spec-to-task)
/spec-to-task ──────────→ exec plan + companion MD
                             │ (docs/exec-plans/active/*.json)
                             ↓ (guides development)
[develop] + hooks ──────→ session metrics
                             │ (.claude/metrics/*.jsonl)
                             ↓ (verified)
/verify ────────────────→ verify report + readiness signal
                             │ (.claude/metrics/verify.jsonl)
                             ↓ (reviewed)
/harness-review ────────→ dual findings
                             │ (.claude/metrics/reviews.jsonl)
                             │ (~/.gstack/projects/$SLUG/*-reviews.jsonl)
                             ↓ (shipped)
/ship ──────────────────→ VERSION + CHANGELOG + PR
                             │
                             ↓ (deployed)
/land-and-deploy ───────→ deploy report
                             │ (.gstack/deploy-reports/)
                             ↓ (monitored)
/canary ────────────────→ health report
                             │ (.gstack/canary-reports/)
                             ↓ (retrospected)
/retro + /harness-dashboard → unified metrics
                             │
                             ↓ (improved)
/encode-mistake + /entropy-sweep → permanent guardrails
```

## Artifact Bridges (v1.1 manifest)

All bridges are **read-only**, **glob-based**, and **gracefully degrade** when absent.
See `.claude/integration.json` for the canonical list.

| Source | Artifact | Location | Consumer |
|--------|----------|----------|----------|
| /office-hours | Design doc | `~/.gstack/projects/$SLUG/*-design-*.md` | /spec-to-task (auto) |
| /plan-eng-review | Test plan | `~/.gstack/projects/$SLUG/*-test-plan-*.md` | /spec-to-task (auto) |
| /autoplan | Consensus tables | In plan file | /spec-to-task (extracted) |
| /spec-to-task | Exec plan JSON | `docs/exec-plans/active/*.json` | /verify --plan |
| /verify | Results JSONL | `.claude/metrics/verify.jsonl` | /harness-dashboard |
| /verify | **Readiness signal** | `.claude/signals/verify-latest.json` | /ship pre-flight |
| /harness-review | Findings JSONL | `.claude/metrics/reviews.jsonl` | /ship, /harness-dashboard |
| /review | Review log | `~/.gstack/projects/$SLUG/*-reviews.jsonl` | /ship, /harness-review (dedup) |
| /codex (v0.15+) | Cross-model report | `~/.gstack/projects/$SLUG/*-codex-*.md` | /harness-review (`[CROSS-MODEL]`) |
| /cso | Security audit | `~/.gstack/projects/$SLUG/*-cso-*.md` | /harness-review (`[SECURITY]`) |
| /ux-audit (v0.17+) | UX report | `~/.gstack/projects/$SLUG/*-ux-audit-*.md` | /harness-review (`[UX]`) |
| /qa | Test outcome | `~/.gstack/projects/$SLUG/*-test-outcome-*.md` | /harness-dashboard |
| /canary | Health report | `.gstack/canary-reports/*.json` | /harness-dashboard (quality trend) |
| /land-and-deploy | Deploy report | `.gstack/deploy-reports/*.json` | /harness-dashboard (DORA proxy) |
| conductor (v0.16+) | Multi-session state | `conductor.json` | /verify, hooks (worktree-aware) |
| worktrees | Parallel sprint dirs | `.gstack-worktrees/` | /verify, hooks (scope guard) |
| /investigate | Root cause | Session context | /encode-mistake |
| session-metrics.sh | Tool usage | `.claude/metrics/session-*.jsonl` | /harness-dashboard, /retro |
| Confusion Protocol (v0.18+) | Uncertainty signals | `.claude/metrics/confusion.jsonl` | /harness-dashboard (legibility input) |
| gstack analytics | Skill usage | `~/.gstack/analytics/skill-usage.jsonl` | /harness-dashboard |
| gstack analytics | Eureka moments | `~/.gstack/analytics/eureka.jsonl` | /harness-dashboard |

## Setup

### First-time integration

```bash
# 1. Install both plugins
# gstack: follow https://github.com/garrytan/gstack setup
# oh-my-agents: follow README.md installation

# 2. Initialize harness (detects gstack automatically)
/harness-init --quick

# 3. Configure integration bridges
/gstack-sync --setup
```

### Verify integration

```bash
/gstack-sync --status    # Shows full integration health report
```

## Workflow Modes

### Full Lifecycle (both installed)

```
/lifecycle next    # Auto-guided through all phases
```

Or manually:
```
/office-hours → /autoplan → /spec-to-task → [develop] → /verify → /harness-review → /ship → /land-and-deploy → /retro + /harness-dashboard → /encode-mistake
```

### oh-my-agents Only

```
/spec-to-task → [develop] → /verify → /harness-review → /encode-mistake
```

### gstack Only

```
/office-hours → /autoplan → [develop] → /review → /ship → /land-and-deploy → /retro
```

## Hook Coexistence

Both hook systems run independently and check different dimensions:

| Event | oh-my-agents Hook | gstack Hook | Conflict? |
|-------|-------------------|-------------|-----------|
| PreToolUse (Edit/Write) | arch-check.sh (layers) | check-freeze.sh (boundaries) | No — different checks |
| PreToolUse (Edit/Write) | safety-check.sh (secrets) | — | No overlap |
| PreToolUse (Bash) | bash-safety-check.sh | check-careful.sh (destructive) | No — different checks |
| PostToolUse (Edit/Write) | self-verify-check.sh | — | No overlap |
| PostToolUse (Edit/Write/Bash) | session-metrics.sh | — | No overlap |
| Stop | doc-drift-check.sh | — | No overlap |

## Key Integration Loops

### Design → Plan → Execute Loop
```
/office-hours → design doc → /spec-to-task auto-imports → exec plan → [develop with hooks]
```

### Verify → Review → Ship Loop
```
/verify (readiness signal) → /harness-review (dual findings) → /ship (consumes both)
```

### Investigate → Encode Loop
```
/investigate (root cause found) → /encode-mistake (permanent guardrail created)
```

### QA → Taste Loop
```
/qa (UI bug found) → /design-review (pattern identified) → /encode-mistake --proactive (rule encoded)
```

### Retro → Improve Loop
```
/retro + /harness-dashboard (metrics analysis) → /entropy-sweep (cleanup) → /encode-mistake (rules)
```

## Composition Principles & Skill Ownership

Decided in [Team Discussion 2026-04](TEAM-DISCUSSION-2026-04.md). The core rule:
**composition over duplication**. oh-my-agents does only what gstack cannot, and
defers cross-cutting concerns that gstack already owns.

| Capability | Owner | Composer behavior |
|------------|-------|-------------------|
| Layer / arch enforcement | oh-my-agents (hooks + arch-guard) | always-on |
| Secrets / bash safety | oh-my-agents (hooks) | edit-time blocking |
| Entropy & encode rules | oh-my-agents (entropy-sweep + encode-mistake) | weekly + on-demand |
| Doc drift | oh-my-agents (doc-drift-check) | session end |
| Legibility scoring | oh-my-agents (legibility-score) | on-demand |
| Lifecycle orchestration | gstack | oh-my-agents `/lifecycle` only routes & reports gates |
| Slop deep-check | **gstack /codex** | /harness-review delegates, never duplicates |
| Security deep-audit | **gstack /cso** | /harness-review delegates; hooks are backstop |
| UX audit | **gstack /ux-audit** | /harness-review auto-suggests on UI diffs |
| Cross-model verification | **gstack /codex** | opt-in via `--with-codex` |
| Ship/Deploy/Canary | gstack | reads `.claude/signals/verify-latest.json` |
| Velocity retro | gstack /retro | — |
| Governance retro | oh-my-agents /harness-dashboard | DORA proxy + dual-review rate |

## Anti-Bloat Constraints (hard rules)

1. **No new skills** for integration purposes; modify existing skills only.
2. **SKILL.md ≤ 400 lines** per skill; over-budget triggers `/entropy-sweep` follow-up.
3. **Glob over exact path** for every gstack bridge; gstack reorganizes frequently.
4. **Loose version match**: probe artifact presence, not version strings.
5. **Read-only bridge**: never write to `~/.gstack/`.
6. **Quarterly contract review** (`/gstack-sync --contract-check`) — verify assumptions still hold.
7. Every integration rule must answer: *"Will this still hold after gstack's next release?"*
   If no — replace with capability detection.

## Foundational Principles

1. **Read-only bridge** — oh-my-agents reads gstack artifacts but never writes to gstack paths
2. **Graceful degradation** — all features work when either plugin is absent
3. **No duplicate data** — reference original files, don't copy metrics
4. **Conversation + artifacts** — within a session, context flows naturally;
   across sessions, structured artifacts provide continuity
5. **Rippable integration** — if either plugin updates, the bridge adapts; no tight coupling
6. **Composition over duplication** — defer to gstack when gstack already covers the concern
7. **Capability detection over version pinning** — probe artifact surface, not version numbers
8. **Worktree awareness** — never operate across `.gstack-worktrees/` siblings
