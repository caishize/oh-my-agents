---
name: spec-to-task
description: "Convert feature specs into agent-executable tasks with a layer-aware execution plan — failing tests first, explicit context per task, JSON progress tracking, and full plan lifecycle management. Turn any idea into a structured, dependency-ordered plan that agents can execute reliably. Aliases: 需求拆分, 任务分解, 规格转任务, 拆解需求, 创建执行计划"
user-invocable: true
argument-hint: "<spec-description or issue-url> [--continue <plan-id>] [--status]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Spec to Task v2.0

Decompose specifications into agent-executable tasks with full lifecycle management.
Based on OpenAI's finding that **planning before execution** is essential — agents waste
effort without well-scoped, context-rich task definitions.

> "Agents have no tacit knowledge; until it is made explicit, it doesn't exist."

## Key Principles

1. **Separate planning and execution phases** — Never let agents start implementing
   before the task is fully specified with failing tests
2. **JSON > Markdown for progress tracking** — Agents less frequently overwrite
   structured data. Use JSON execution plans to enable "shift handoff" where new
   sessions quickly understand prior work state
3. **Layer-aware decomposition** — Tasks respect Types -> Config -> Repo -> Service ->
   Runtime -> UI dependency flow
4. **Explicit context and constraints** — Each task includes files to pre-read (context)
   and what NOT to do (constraints). No tacit knowledge allowed
5. **Four pillars alignment** — Every plan addresses Architecture as Guardrails,
   Documentation as System of Record, Observability & Legibility, and Entropy Management

## Task

Take a feature spec (from `$ARGUMENTS`) and decompose into agent-ready tasks with a
managed execution plan.

### Step 1: Analyze the Specification

1. Read the feature spec, issue URL, or user description from `$ARGUMENTS`
2. **Check for gstack upstream artifacts** — gstack owns intent→spec (`/spec`, v1.47:
   5-phase, codex quality gate) and design/plan docs (`/office-hours`, `/autoplan`).
   `/spec-to-task` is the clean DOWNSTREAM that turns a spec into a layer-aware exec-plan
   JSON. Probe for any of them (glob — gstack reorganizes; absence = graceful degrade):
   ```bash
   SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
   GSTACK_PROJECTS="$HOME/.gstack/projects/$SLUG"
   if [ -d "$GSTACK_PROJECTS" ]; then
     echo "=== gstack /spec artifacts ===";  ls -lt "$GSTACK_PROJECTS/"*-spec-*.md   2>/dev/null | head -5
     echo "=== gstack Design Docs ===";       ls -lt "$GSTACK_PROJECTS/"*-design-*.md 2>/dev/null | head -5
     echo "=== gstack Test Plans ===";        ls -lt "$GSTACK_PROJECTS/"*-test-plan-*.md 2>/dev/null | head -5
   fi
   ```
   > **Path note:** gstack `/spec` may file its output as a GitHub issue rather than a
   > stable `*-spec-*.md` file — confirm the artifact location against `<gstack_root>/llms.txt`
   > and the live `~/.gstack/projects/$SLUG/` before relying on the glob; never hard-parse.
   If any upstream artifact exists, read the most recent and extract:
   - Feature description and scope (from the spec / design doc)
   - Technical decisions (especially from Eng Review sections)
   - Test requirements (from Test Plan artifacts)
   - Review findings that should become plan constraints
   - Consensus tables (if /autoplan was used — cross-validated decisions are higher confidence)
   Incorporate these into the plan as `spec_source` and pre-populate `decisions` array.
3. Analyze the current codebase:
   - Read `CLAUDE.md` for architecture overview and module map
   - Read `docs/ARCHITECTURE.md` for layer model and boundaries
   - Read `docs/CONVENTIONS.md` for patterns to follow
   - Read `.claude/harness.json` for layer directory mappings (if exists)
   - Identify related existing code and patterns
4. **Ambiguity resolution (only when there is no upstream gstack `/spec`)** — `/spec`'s
   codex quality gate already blocks ambiguous specs upstream, so when the source IS a
   gstack `/spec` artifact, trust it and proceed. Otherwise (inline spec, or no gstack),
   surface ambiguities + implicit assumptions and ask clarifying questions before
   decomposing — do not guess.

### Step 2: Check for Existing Plans

Check `docs/exec-plans/active/` for existing execution plans.

**If `--status` flag is present:**
Show a summary of all plans:
```
Active Plans:
  plan-20260315-auth-system.json — Auth System (3/8 tasks done, updated 2h ago)
  plan-20260310-search-api.json  — Search API (0/5 tasks done, updated 8 days ago) [STALLED]

Completed Plans:
  plan-20260301-user-profiles.json — User Profiles (6/6 tasks done)
```
Then stop — do not create a new plan.

**If `--continue <plan-id>` flag is present:**
Load the specified plan, show current status, identify the next actionable task(s),
and resume from where the previous session left off. Update the `updated` timestamp.

**If active plans exist and no flags specified:**
Show existing active plans and ask:
> "Found existing active plan(s). Would you like to:
> 1. Continue an existing plan (specify which)
> 2. Create a new plan for this spec
> 3. See full status of all plans"

**Plan lifecycle states:**
- `active` — Currently being worked on
- `completing` — All tasks done, awaiting final verification
- `completed` — Verified and moved to `docs/exec-plans/completed/`
- `stalled` — No updates in N+ days (default 7; configurable via `plan_stale_days` in `.claude/harness.json`)
- `abandoned` — Explicitly marked as no longer pursued

When all tasks reach `done` status, transition plan to `completing`. After final
verification passes, move the JSON file from `active/` to `completed/`.
Plans with no updates in 7+ days should be flagged as `stalled` in status reports.

### Step 3: Design Failing Tests First

Before any implementation tasks, define the tests that prove the feature works.
These tests must FAIL initially — that's the signal they're real tests, not rubber stamps.

```markdown
## Test Plan (write these FIRST)

### Unit Tests
- [ ] `test_[feature]_creates_[thing]` — verifies core creation logic
- [ ] `test_[feature]_rejects_invalid_input` — verifies validation
- [ ] `test_[feature]_handles_[edge_case]` — verifies edge case handling

### Integration Tests
- [ ] `test_[feature]_api_[endpoint]` — verifies API contract
- [ ] `test_[feature]_persists_[data]` — verifies storage round-trip
- [ ] `test_[feature]_[integration_point]` — verifies cross-module interaction

### Structural Tests
- [ ] New files follow naming convention from docs/CONVENTIONS.md
- [ ] New modules respect layer boundaries from docs/ARCHITECTURE.md
- [ ] No file exceeds file_size_limit from harness.json
- [ ] No forbidden imports in new code
```

### Step 4: Decompose by Architecture Layer

Each task maps to a specific architecture layer, following the dependency flow:

```
Phase 1: Types -> Config    (no dependencies, can parallelize)
Phase 2: Repo               (depends on Types)
Phase 3: Service            (depends on Repo + Types)
Phase 4: Runtime/API        (depends on Service)
Phase 5: UI                 (depends on Runtime)
Phase 6: Cross-cutting      (tests, docs, observability, entropy checks)
```

For each task, determine:
- Which layer it belongs to
- Which phase it falls in (based on dependencies)
- Which specific files need to be created or modified
- Which existing files the agent must read first (context)
- What the agent must NOT do (constraints)

### Step 5: Write Execution Plan JSON

Write the execution plan to `docs/exec-plans/active/{plan-id}.json`.
Plan ID format: `plan-YYYYMMDD-feature-name` (lowercase, hyphens).

**Schema source of truth**: `templates/execution-plan.json` in the oh-my-agents
plugin. Read it once, then conform — do not paraphrase from memory.

Required top-level fields:
- `$schema` = `"execution-plan-v2"`, `id`, `feature`, `status`, `created`, `updated`
- `spec_source` (issue URL, file, or inline)
- `gstack_design_doc`, `gstack_test_plan` (if derived via Step 1)
- `overview` (1–2 sentences)
- `risks[]` — each `{ id, description, mitigation, status }`
- `decisions[]` — each `{ id, question, decision, alternatives, rationale }`
- `test_plan` — `{ unit[], integration[], structural[] }`
- `tasks[]` — see below
- `metrics` — `{ tasks_total, tasks_done, tasks_blocked }`

Each task object:
```
{ id, title, layer, phase, status, files[], depends_on[], acceptance[], constraints[], context[] }
```
- `status` transitions: `pending` → `in_progress` → `done` (or `blocked`)
- `acceptance[]` — explicit pass criteria (test names, lint clean, etc.)
- `constraints[]` — things the agent must NOT do (just as important as requirements)
- `context[]` — files the agent must read first (no tacit knowledge)

Layer order (also defines `phase` numbering):
```
phase 1: types, config        (parallelizable, no deps)
phase 2: repo                 (depends on types)
phase 3: service              (depends on repo + types)
phase 4: runtime              (depends on service)
phase 5: ui                   (depends on runtime)
phase 6: cross-cutting        (verification: tests, docs, observability)
```

Concrete per-layer constraint cheatsheet:
- **types**: no imports from service/runtime; no runtime logic
- **config**: no hardcoded values (env vars); no imports from layers above
- **repo**: no business logic (belongs in service); no imports from service/runtime/ui
- **service**: no direct storage access (use repo); use Providers for auth/telemetry/flags
- **runtime**: no business logic (delegate to service); no direct repo imports
- **cross-cutting**: never skip failing tests; never weaken lint rules to pass

New sessions read the JSON to understand prior work state — this is "shift handoff".

### Step 6: Generate Human-Readable Markdown Summary

Create a companion markdown file at `docs/exec-plans/active/{plan-id}.md` alongside
the JSON plan:

```markdown
# Execution Plan: [Feature Name]

**Plan ID**: `plan-YYYYMMDD-feature-name`
**Status**: active
**Created**: YYYY-MM-DD
**Spec Source**: [issue URL or description]

## Overview
[1-2 sentences]

## Risks
| ID | Risk | Mitigation | Status |
|----|------|-----------|--------|
| R1 | [description] | [mitigation] | open |

## Decisions
| ID | Question | Decision | Rationale |
|----|----------|----------|-----------|
| D1 | [question] | [decision] | [rationale] |

## Test Plan (write these FIRST — they must fail initially)

### Unit Tests
- [ ] `test_feature_creates_thing`
- [ ] `test_feature_rejects_invalid_input`

### Integration Tests
- [ ] `test_feature_api_endpoint`
- [ ] `test_feature_persists_data`

### Structural Tests
- [ ] Files follow naming convention
- [ ] No layer boundary violations

## Tasks (ordered by phase and dependency)

### Phase 1: Foundation (parallelizable)
- [ ] **Task 1**: Define types in `src/types/feature.ts` [Types]
- [ ] **Task 2**: Add config in `src/config/feature.ts` [Config]

### Phase 2: Data Access
- [ ] **Task 3**: Repository layer `src/repo/feature.ts` [Repo]

### Phase 3: Business Logic
- [ ] **Task 4**: Service logic `src/services/feature.ts` [Service]

### Phase 4: Interface
- [ ] **Task 5**: API endpoint `src/api/feature.ts` [Runtime]

### Phase 5: Verification
- [ ] **Task 6**: All tests pass, docs updated, observability added [Cross-cutting]

## ADR (if needed)
If this feature introduces a new pattern or technology choice, add an ADR to
docs/DECISIONS.md: "We chose X over Y because..."

## Progress
- Tasks total: [N]
- Tasks done: [N]
- Tasks blocked: [N]
- Last updated: [date]
```

### Step 7: Plan Lifecycle Management

After writing the plan, explain the lifecycle to the user:

```
Plan created: docs/exec-plans/active/plan-YYYYMMDD-feature-name.json
Companion:    docs/exec-plans/active/plan-YYYYMMDD-feature-name.md

Lifecycle:
  active      — Work in progress (current)
  completing  — All tasks done, awaiting final verification
  completed   — Verified, will be moved to docs/exec-plans/completed/
  stalled     — Flagged if no updates in 7+ days
  abandoned   — Explicitly marked as no longer pursued

To continue this plan in a new session:
  /spec-to-task --continue plan-YYYYMMDD-feature-name

To check status of all plans:
  /spec-to-task --status

When all tasks are done:
  1. Plan transitions to "completing"
  2. Run final verification (all tests, lint, structural checks)
  3. Plan moves to docs/exec-plans/completed/
```

## Rules

- **Tests first** — every feature starts with failing tests, then implementation
- **No tacit knowledge** — if a convention isn't in docs/, add it to the task context explicitly
- **Each task must reference specific files and patterns to follow** — the `context` array
  tells the agent exactly what to read before starting
- **Constraints (what NOT to do) are as important as requirements** — the `constraints` array
  prevents agents from taking harmful shortcuts
- **Prefer smaller tasks** — one per architecture layer, each independently verifiable
- **Layer-aware**: tasks must respect Types -> Config -> Repo -> Service -> Runtime -> UI
- **JSON is the source of truth** — the markdown summary is for humans; the JSON plan is
  what agents read and update for shift handoff
- **Execution plans go in `docs/exec-plans/`** — not in `.claude/plans/` or any other location
- **Slack-to-codebase**: if a decision was made verbally, encode it in the plan's `decisions`
  array and add an ADR to docs/DECISIONS.md
- **Four pillars in every plan** — Architecture (layer boundaries), Documentation (context
  arrays), Observability (logging/metrics tasks), Entropy (structural tests and constraints)
- **Stale plans get flagged** — plans with no updates in 7+ days are marked `stalled` to
  prevent silent abandonment
- **gstack upstream artifacts are first-class input** — `/spec-to-task` is the downstream
  of gstack's intent→spec (`/spec`, v1.47) and design/plan (`/office-hours`, `/autoplan`).
  If any exists, use it as the spec source and extract decisions, scope, and test
  requirements rather than asking the user to repeat them. Clean handoff, not duplication:
  gstack does intent→spec; we do spec→layer-aware exec-plan JSON (verify/harness-review gate on it)
- **gstack review findings become constraints** — findings from `/plan-eng-review` that
  flag architectural risks should become task constraints in the execution plan
