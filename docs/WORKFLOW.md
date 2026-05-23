# Development Workflow

Full development lifecycle following the **Research -> Plan -> Execute -> Verify** cycle.
This workflow integrates oh-my-agents (harness engineering) with gstack (development factory)
when both are installed. Each phase builds on the previous one's output through both
Claude Code's conversation context and structured artifact handoffs.

## Lifecycle Overview

```
┌─────────┐    ┌──────┐    ┌───────────┐    ┌─────────┐    ┌────────┐
│ IDEATE  │───→│ PLAN │───→│ DECOMPOSE │───→│ EXECUTE │───→│ VERIFY │
│ (gstack)│    │(gstk)│    │ (harness) │    │ (hooks) │    │(harness)│
└─────────┘    └──────┘    └───────────┘    └─────────┘    └────────┘
                                                                │
┌─────────┐    ┌──────┐    ┌──────┐    ┌────────┐    ┌─────────┐│
│ IMPROVE │←───│RETRO │←───│DEPLOY│←───│  SHIP  │←───│ REVIEW  │←┘
│(harness)│    │(both)│    │(gstk)│    │(gstack)│    │ (both)  │
└─────────┘    └──────┘    └──────┘    └────────┘    └─────────┘
```

**Orchestrator**: `/lifecycle` guides through phases automatically.
**Integration hub**: `/gstack-sync` manages cross-system artifact bridges.

## Phase Details

### 1. Ideate (gstack)

**Command**: `/office-hours`
**Input**: Your idea or problem statement
**Output**: Design doc at `~/.gstack/projects/{slug}/`

Two modes:
- **Startup mode**: 6 forcing questions (demand reality, status quo, specificity, wedge, observation, future-fit)
- **Builder mode**: Design thinking brainstorm (coolest version, fastest path, differentiation)

**Artifact produced**: `{user}-{branch}-design-{datetime}.md` → consumed by `/spec-to-task`

**Next**: `/plan-ceo-review` or `/plan-eng-review` or `/lifecycle plan`

### 2. Plan (gstack)

Run one or more review passes on the plan. Order by ambition level:

| Command | Perspective | When to Use |
|---------|-------------|-------------|
| `/autoplan` | All three | Auto-run CEO → Design → Eng with 6 decision principles |
| `/plan-ceo-review` | CEO/founder | Scope expansion, strategy, 10-star product |
| `/plan-eng-review` | Eng manager | Architecture, data flow, edge cases, tests |
| `/plan-design-review` | Designer | 7-dimension design audit (IA, states, UX, slop, a11y) |

Each review produces structured findings with consensus tables (especially `/autoplan`
which uses dual-voice Codex + Claude subagent). Address findings before decomposition.

**Artifacts produced**:
- Updated plan file with review sections
- Test plan: `{user}-{branch}-test-plan-{datetime}.md`
- Decision Audit Trail
- Review logs: `{branch}-reviews.jsonl`

**Next**: `/spec-to-task` or `/lifecycle decompose`

### 3. Decompose (oh-my-agents)

**Command**: `/spec-to-task <spec or design doc reference>`
**Input**: Design doc from gstack (auto-discovered) or inline spec
**Output**: Execution plan at `docs/exec-plans/active/{plan-id}.json` + companion `.md`

**gstack integration**: `/spec-to-task` now automatically:
- Scans `~/.gstack/projects/{slug}/` for recent design docs
- Extracts decisions from `/autoplan` consensus tables
- Imports test requirements from eng review test plans
- Converts review findings into plan task constraints

Key features:
- Layer-aware task ordering: Types -> Config -> Repo -> Service -> Runtime -> UI
- Failing tests designed first (RED -> GREEN -> IMPROVE)
- Each task has explicit `context` (files to read) and `constraints` (what NOT to do)
- Plan lifecycle: active -> completing -> completed (or stalled / abandoned)
- JSON plan includes `gstack_design_doc` and `gstack_test_plan` source references

Resume across sessions: `/spec-to-task --continue <plan-id>`

**Next**: Start implementing tasks or `/lifecycle execute`

### 4. Execute (developer + hooks)

Implement tasks from the execution plan. During development:

**oh-my-agents hooks (automatic)**:
- `arch-check.sh` **blocks** layer violations on every Edit/Write
- `safety-check.sh` **blocks** hardcoded secrets
- `bash-safety-check.sh` **blocks** credential leaks in bash
- `session-metrics.sh` **records** tool usage to `.claude/metrics/`
- `self-verify-check.sh` **warns** on type/syntax errors after edit

**gstack hooks (if guard mode active)**:
- `check-freeze.sh` **blocks** edits outside freeze boundary
- `check-careful.sh` **warns** before destructive commands

Both hook systems coexist without conflict — they check different dimensions.

Update task status in the execution plan JSON as you complete each task.

**Next**: `/verify` or `/lifecycle verify`

### 5. Verify (oh-my-agents)

**Command**: `/verify [--plan <plan-id>]`
**Input**: Current working directory state
**Output**: Structured report (PASS/FAIL/WARN/SKIP per check) + decision signal

Runs in order: **lint -> build -> test -> arch guard**

**Decision signal (the gate)**: `/verify` writes `.claude/signals/verify-latest.json`
with a `decision` enum (`GREEN` / `YELLOW` / `RED`) — the canonical artifact `/lifecycle`
and gstack's `/ship` pre-flight read. A missing/stale signal means "re-run `/verify`"
(mirrors the review gate's default-deny). It also appends each run to
`.claude/metrics/verify.jsonl` (history for recurring-failure detection + dashboard velocity).

**gstack context (advisory only)**: prior-review / QA presence is surfaced in the report
text for `/ship`, never folded into the decision and never blocking.

- GREEN: All checks pass -> proceed to review
- RED: Fix failures first. Root cause unclear? -> `/investigate` (gstack). Recurring? -> `/encode-mistake`
- YELLOW: Warnings present -> review before proceeding

**Next**: `/harness-review` (auto-detects gstack for dual review)

### 6. Review (both systems)

**Recommended**: `/harness-review` — auto-detects gstack and orchestrates both systems in a single pass:

| System | Focus | Catches |
|--------|-------|---------|
| oh-my-agents (harness) | Four-pillar review | Slop (priority 1), layer violations, plan alignment, doc drift, entropy |
| gstack (structural) | PR structural review | SQL injection, LLM trust boundaries, scope drift, enum completeness |

When gstack is detected, `/harness-review` automatically:
- Runs both review passes
- Deduplicates findings (same file + line → merge)
- Cross-validates: issues found by both systems get escalated severity
- Tags each finding with source: `[HARNESS]`, `[STRUCTURAL]`, or `[BOTH]`
- Logs to both `.claude/metrics/reviews.jsonl` and gstack's review system

Without gstack, `/harness-review` runs the four-pillar harness review only.

**Next**: `/ship` or `/lifecycle ship`

### 7. Ship (gstack)

**Command**: `/ship`
**Input**: Feature branch with all reviews passed
**Output**: Version bump, CHANGELOG entry, PR created

**oh-my-agents integration**: The `/ship` pre-flight now can access:
- Verify results from `.claude/metrics/verify.jsonl`
- Unified review findings from `.claude/metrics/reviews.jsonl`
- Architecture compliance status from harness hooks

Key steps (automated):
1. Merge base branch
2. Run full test suite
3. Pre-landing review (inlined) — reads harness review data if available
4. Version bump (auto for PATCH/MICRO, asks for MINOR/MAJOR)
5. CHANGELOG generation
6. Bisectable commits
7. Push + PR creation
8. Auto-invokes `/document-release`

**Next**: `/land-and-deploy` or `/document-release` (auto) + `/retro`

### 8. Deploy (gstack)

**Command**: `/land-and-deploy`
**Input**: PR number + production URL
**Output**: Deploy report with timing, CI status, canary health

Pre-merge readiness gate includes:
- Review staleness check
- Test results (including harness verify data)
- PR body accuracy
- Document-release check

Post-deploy verification adapts by diff scope (docs-only → skip, config → smoke, backend+ → full canary).

**Next**: `/canary` (for extended monitoring) or `/retro`

### 9. Document (gstack)

**Command**: `/document-release` (auto-invoked by `/ship`)
**Input**: Diff between base branch and HEAD
**Output**: Updated README, ARCHITECTURE, CLAUDE.md, CHANGELOG, TODOS

Auto-fixes factual corrections (paths, counts, tables). Asks before narrative changes.
Cross-doc consistency pass ensures README ↔ CLAUDE.md ↔ ARCHITECTURE stay aligned.

### 10. Retro (both systems)

Two complementary retrospective views:

| Command | Dimension | Key Metrics |
|---------|-----------|-------------|
| `/retro` (gstack) | Engineering velocity | Commits, LOC, test ratio, session patterns, per-author breakdown, hotspots |
| `/harness-dashboard` (oh-my-agents) | Harness & governance health | Layer distribution, violations, plan progress, entropy trends, gstack integration |

**Unified metrics** (via `/harness-dashboard` gstack integration section):
- Dual review rate (what % of reviews used both systems)
- Investigate→encode rate (root causes converted to permanent rules)
- Lifecycle phase coverage (which phases were used/skipped)
- Eureka moments (logged insights from gstack sessions)

Run weekly or at sprint boundaries. Together they provide a complete engineering health picture.

### 11. Improve (oh-my-agents)

Continuous improvement through rule encoding and entropy management:

| Command | Trigger | Output |
|---------|---------|--------|
| `/encode-mistake` | Agent made a recurring error | Permanent lint rule, hook, or structural test |
| `/encode-mistake --proactive` | Expert dislikes a pattern | Custom TASTE-NNN rule with enforcement |
| `/entropy-sweep` | Weekly / pre-release scan | Report on slop, drift, dead code, stale plans |

**gstack integration loop**:
- `/investigate` (gstack) finds root cause → `/encode-mistake` (oh-my-agents) makes it permanent
- `/qa` (gstack) finds bugs → fix → `/encode-mistake` → never happens again
- `/design-review` (gstack) finds UI issues → `/encode-mistake --proactive` → design rules encoded

The key loop: **Bug found → root cause → fix → encode → permanent guardrail → never happens again**

## Artifact Flow Map

```
/office-hours ──→ design doc (~/. gstack/projects/$SLUG/)
       │                    │
       ↓                    ↓ (auto-discovered)
/autoplan ──→ consensus tables + test plan
       │                    │
       ↓                    ↓ (consumed)
/spec-to-task ──→ exec plan (docs/exec-plans/active/)
       │                    │
       ↓                    ↓ (guides tasks)
[develop] + hooks ──→ session metrics (.claude/metrics/)
       │                    │
       ↓                    ↓ (verified)
/verify ──→ verify report + gstack readiness signal
       │                    │
       ↓                    ↓ (reviewed)
/harness-review ──→ dual findings (reviews.jsonl + gstack review log)
       │                    │
       ↓                    ↓ (shipped)
/ship ──→ VERSION + CHANGELOG + PR
       │                    │
       ↓                    ↓ (deployed)
/land-and-deploy ──→ deploy report
       │                    │
       ↓                    ↓ (monitored)
/canary ──→ health report
       │
       ↓ (retrospected)
/retro + /harness-dashboard ──→ unified metrics
       │
       ↓ (improved)
/encode-mistake + /entropy-sweep ──→ permanent guardrails
```

## Quick Reference

### One-time setup
```
/harness-init --quick          # oh-my-agents: init + legibility + arch-guard
/gstack-sync --setup           # Integration: detect gstack, configure bridges
```

### Feature development (full lifecycle with gstack)
```
/lifecycle next                # Auto-detect and guide through phases
# OR manually:
/office-hours → /autoplan → /spec-to-task → [develop] → /verify → /harness-review → /ship
```

### Feature development (oh-my-agents only)
```
/spec-to-task → [develop] → /verify → /harness-review
```

### Feature development (minimal with lifecycle orchestrator)
```
/lifecycle ideate → /lifecycle plan → /lifecycle decompose → ... → /lifecycle ship
```

### When agents make mistakes
```
/investigate "<error>"         # gstack: find root cause
/encode-mistake "<what>"       # oh-my-agents: make it permanent
```

### Weekly health check
```
/entropy-sweep → /retro → /harness-dashboard
/gstack-sync --metrics         # Cross-system metrics report
```

### Integration status
```
/gstack-sync --status          # Check integration health
/lifecycle status              # Check lifecycle phase progress
```

## Rippable Harness Principle

> "If you over-engineer the control flow, the next model update will break your system."
> — OpenAI Harness Engineering

Constraints should be **rippable** — easy to remove when models improve. Review your harness
quarterly or with each major model update:

1. **Review hook false-positive rate** — Check `.claude/metrics/` for `blocked_by` events.
   If a hook blocks more false positives than real violations, simplify or remove it.
2. **Simplify graduating constraints** — If models reliably handle a pattern (e.g., import
   ordering), remove the lint rule and trust the model. Start with doc rules, graduate to
   lint rules only when models fail repeatedly.
3. **Remove stale TASTE rules** — Rules in `docs/LINTING.md` that haven't triggered in 3+
   months may be obsolete. Archive rather than delete (move to `docs/LINTING-archive.md`).
4. **Test harness evolution** — After removing a constraint, monitor for regression via
   `/entropy-sweep`. If violations return, re-add the constraint.

The goal is the **minimum harness that produces correct output** — not the maximum.

## Plugin Detection

This workflow adapts based on installed plugins:
- **Both installed**: Full lifecycle (all phases, all commands, artifact bridges active)
- **oh-my-agents only**: Decompose → Execute → Verify → Review → Improve (no ideate/plan/ship/deploy/retro)
- **gstack only**: Ideate → Plan → Review → Ship → Deploy → Retro (no layer enforcement, entropy management, or plan decomposition)

The conversation context bridges all skills naturally within a session. For cross-session
handoffs, structured artifacts (design docs, exec plans, review JSONL, metrics) provide
continuity. Use `/gstack-sync --status` to verify artifact bridges are healthy.
