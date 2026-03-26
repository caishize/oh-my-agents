# gstack ↔ oh-my-agents Integration Guide

## Philosophy

**gstack** accelerates delivery: design → ship → deploy → monitor.
**oh-my-agents** enforces quality: architecture → entropy → observability → documentation.

Together they form a complete AI engineering stack. Neither plugin modifies the other's
files or state — integration happens through structured artifact consumption and shared
metric namespaces.

## Complementary Strengths

| Dimension | gstack | oh-my-agents | Combined |
|-----------|--------|-------------|----------|
| Ideation | /office-hours (YC-style) | — | Design doc → execution plan |
| Planning | /autoplan (triple-voice) | — | Consensus tables → plan constraints |
| Decomposition | — | /spec-to-task (layer-aware) | Design doc auto-imported |
| Execution | /guard (freeze/careful) | hooks (arch/safety/metrics) | Dual hook systems coexist |
| Verification | — | /verify (lint→build→test→arch) | Readiness signal for /ship |
| Review | /review (structural) | /harness-review (four-pillar) | /unified-review orchestrates both |
| Shipping | /ship (version/changelog/PR) | — | Consumes verify + review data |
| Deployment | /land-and-deploy + /canary | — | Readiness gates include harness data |
| Documentation | /document-release | doc-drift-check hook | Auto-sync + drift detection |
| Retrospective | /retro (velocity) | /harness-dashboard (governance) | Unified metrics view |
| Debugging | /investigate (root cause) | /encode-mistake (permanent rule) | Investigate → encode loop |
| Quality | /qa + /design-review | /entropy-sweep + /taste-encoder | QA findings → taste rules |
| Security | /cso (OWASP/STRIDE) | safety hooks (secrets) | Audit + real-time blocking |
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
/unified-review ────────→ dual findings
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

## Artifact Bridges

| Source | Artifact | Location | Consumer |
|--------|----------|----------|----------|
| /office-hours | Design doc | `~/.gstack/projects/$SLUG/*-design-*.md` | /spec-to-task (auto) |
| /plan-eng-review | Test plan | `~/.gstack/projects/$SLUG/*-test-plan-*.md` | /spec-to-task (auto) |
| /autoplan | Consensus tables | In plan file | /spec-to-task (extracted) |
| /spec-to-task | Exec plan JSON | `docs/exec-plans/active/*.json` | /verify --plan |
| /verify | Results JSONL | `.claude/metrics/verify.jsonl` | /ship (readiness) |
| /unified-review | Findings JSONL | `.claude/metrics/reviews.jsonl` | /ship, /harness-dashboard |
| /review | Review log | `~/.gstack/projects/$SLUG/*-reviews.jsonl` | /ship (readiness gate) |
| session-metrics.sh | Tool usage | `.claude/metrics/session-*.jsonl` | /harness-dashboard, /retro |
| /qa | Test outcome | `~/.gstack/projects/$SLUG/*-test-outcome-*.md` | /harness-dashboard |
| /investigate | Root cause | Session context | /encode-mistake |
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
/office-hours → /autoplan → /spec-to-task → [develop] → /verify → /unified-review → /ship → /land-and-deploy → /retro + /harness-dashboard → /encode-mistake
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
/verify (readiness signal) → /unified-review (dual findings) → /ship (consumes both)
```

### Investigate → Encode Loop
```
/investigate (root cause found) → /encode-mistake (permanent guardrail created)
```

### QA → Taste Loop
```
/qa (UI bug found) → /design-review (pattern identified) → /taste-encoder (rule encoded)
```

### Retro → Improve Loop
```
/retro + /harness-dashboard (metrics analysis) → /entropy-sweep (cleanup) → /encode-mistake (rules)
```

## Principles

1. **Read-only bridge** — oh-my-agents reads gstack artifacts but never writes to gstack paths
2. **Graceful degradation** — all features work when either plugin is absent
3. **No duplicate data** — reference original files, don't copy metrics
4. **Conversation + artifacts** — within a session, context flows naturally; across sessions, structured artifacts provide continuity
5. **Rippable integration** — if either plugin updates, the bridge adapts; no tight coupling to specific versions
