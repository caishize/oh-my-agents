# Development Workflow

Full development lifecycle following the **Research -> Plan -> Execute -> Verify** cycle.
This workflow integrates oh-my-agents (harness engineering) with gstack (development factory)
when both are installed. Each phase builds on the previous one's output through Claude Code's
conversation context — no explicit data handoff required.

## Lifecycle Overview

```
Ideate -> Plan -> Decompose -> Execute -> Verify -> Review -> Ship -> Docs -> Retro -> Guard
  |        |         |           |          |         |        |       |       |        |
office   plan-*    spec-to   [develop]   verify    review    ship   doc-    retro    encode
hours    review    task       + hooks              + harn-          release  + dash   mistake
                                                    review                  board   + sweep
|<---- gstack ---->|<- oh-my ->|<----- mixed ----->|<- gstack ->|<--- mixed --->|<- oh-my ->|
```

## Phase Details

### 1. Ideate (gstack)

**Command**: `/office-hours`
**Input**: Your idea or problem statement
**Output**: Design doc at `~/.gstack/projects/{slug}/`

Two modes:
- **Startup mode**: 6 forcing questions (demand reality, status quo, specificity, wedge, observation, future-fit)
- **Builder mode**: Design thinking brainstorm (coolest version, fastest path, differentiation)

**Next**: `/plan-ceo-review` or `/plan-eng-review`

### 2. Plan (gstack)

Run one or more review passes on the plan. Order by ambition level:

| Command | Perspective | When to Use |
|---------|-------------|-------------|
| `/plan-ceo-review` | CEO/founder | Scope expansion, strategy, 10-star product |
| `/plan-eng-review` | Eng manager | Architecture, data flow, edge cases, tests |
| `/plan-design-review` | Designer | 7-dimension design audit (IA, states, UX, slop, a11y) |

Each review produces structured findings. Address them before moving to decomposition.

**Next**: `/spec-to-task`

### 3. Decompose (oh-my-agents)

**Command**: `/spec-to-task <spec or design doc reference>`
**Input**: The design doc / plan from previous phases (Claude remembers it in session)
**Output**: Execution plan at `docs/exec-plans/active/{plan-id}.json` + companion `.md`

Key features:
- Layer-aware task ordering: Types -> Config -> Repo -> Service -> Runtime -> UI
- Failing tests designed first (RED -> GREEN -> IMPROVE)
- Each task has explicit `context` (files to read) and `constraints` (what NOT to do)
- Plan lifecycle: active -> completing -> completed (or stalled / abandoned)

Resume across sessions: `/spec-to-task --continue <plan-id>`

**Next**: Start implementing tasks

### 4. Execute (developer + hooks)

Implement tasks from the execution plan. During development:

- `arch-check.sh` hook **automatically blocks** layer violations on every Edit/Write
- `safety-check.sh` hook **automatically blocks** hardcoded secrets
- `session-metrics.sh` hook **silently records** tool usage to `.claude/metrics/`

Update task status in the execution plan JSON as you complete each task.

**Next**: `/verify`

### 5. Verify (oh-my-agents)

**Command**: `/verify [--plan <plan-id>]`
**Input**: Current working directory state
**Output**: Structured report (PASS/FAIL/WARN/SKIP per check)

Runs in order: **lint -> build -> test -> arch guard**

If `--plan` is provided, maps results to plan acceptance criteria.

- GREEN: All checks pass -> proceed to review
- RED: Fix failures first. Recurring failures? -> `/encode-mistake`
- YELLOW: Warnings present -> review before proceeding

**Next**: `/review` + `/harness-review`

### 6. Review (gstack + oh-my-agents)

Two complementary reviews on the same diff:

| Command | Focus | Catches |
|---------|-------|---------|
| `/review` (gstack) | Structural PR review | SQL injection, LLM trust boundaries, scope drift, enum completeness |
| `/harness-review` (oh-my-agents) | Four-pillar review | Slop, safety, layer violations, plan alignment, doc drift |

Run both. They check different dimensions with minimal overlap (both catch secrets, which is additive not conflicting).

**Next**: `/ship`

### 7. Ship (gstack)

**Command**: `/ship`
**Input**: Feature branch with all reviews passed
**Output**: Version bump, CHANGELOG entry, PR created

Key steps (automated):
1. Merge base branch
2. Run full test suite
3. Pre-landing review (inlined)
4. Version bump (auto for PATCH/MICRO, asks for MINOR/MAJOR)
5. CHANGELOG generation
6. Bisectable commits
7. Push + PR creation
8. Auto-invokes `/document-release`

**Next**: `/document-release` (auto) + `/retro` (periodic)

### 8. Document (gstack)

**Command**: `/document-release` (auto-invoked by `/ship`)
**Input**: Diff between base branch and HEAD
**Output**: Updated README, ARCHITECTURE, CLAUDE.md, CHANGELOG, TODOS

Auto-fixes factual corrections (paths, counts, tables). Asks before narrative changes.

### 9. Retro (gstack + oh-my-agents)

Two complementary retrospective views:

| Command | Dimension | Metrics |
|---------|-----------|---------|
| `/retro` (gstack) | Engineering velocity | Commits, LOC, test ratio, session patterns, per-author breakdown |
| `/harness-dashboard` (oh-my-agents) | Harness health | Layer distribution, violations, plan progress, entropy trends |

Run weekly or at sprint boundaries. Together they provide a complete engineering health picture.

### 10. Guard (oh-my-agents)

Continuous improvement through rule encoding:

| Command | Trigger | Output |
|---------|---------|--------|
| `/encode-mistake` | Agent made a recurring error | Permanent lint rule, hook, or structural test |
| `/taste-encoder` | Expert dislikes a pattern | Custom TASTE-NNN rule with enforcement |
| `/entropy-sweep` | Weekly / pre-release scan | Report on slop, drift, dead code, stale plans |

The key loop: **QA finds bug -> fix it -> `/encode-mistake` -> permanent guardrail -> never happens again**

## Quick Reference

### One-time setup
```
/harness-init -> /legibility-score -> /arch-guard
```

### Feature development
```
/office-hours -> /plan-eng-review -> /spec-to-task -> [develop] -> /verify -> /review -> /harness-review -> /ship
```

### When agents make mistakes
```
/encode-mistake "<what went wrong>"
```

### Weekly health check
```
/entropy-sweep -> /retro -> /harness-dashboard
```

## Plugin Detection

This workflow adapts based on installed plugins:
- **Both installed**: Full lifecycle (all commands available)
- **oh-my-agents only**: Decompose -> Execute -> Verify -> Review -> Guard (no ideate/plan/ship/retro)
- **gstack only**: Ideate -> Plan -> Review -> Ship -> Retro (no layer enforcement or entropy management)

The conversation context bridges all skills naturally — no explicit data handoff needed between
oh-my-agents and gstack commands in the same Claude Code session.
