---
name: spec-to-task
description: "Convert feature specs into agent-executable tasks with a layer-aware execution plan — failing tests first, explicit context per task, JSON progress tracking, and full plan lifecycle management. Turn any idea into a structured, dependency-ordered plan that agents can execute reliably. Aliases: 需求拆分, 任务分解, 规格转任务, 拆解需求, 创建执行计划"
user-invocable: true
argument-hint: "<spec-description or issue-url> [--continue <plan-id>] [--status]"
model: sonnet
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
2. Analyze the current codebase:
   - Read `CLAUDE.md` for architecture overview and module map
   - Read `docs/ARCHITECTURE.md` for layer model and boundaries
   - Read `docs/CONVENTIONS.md` for patterns to follow
   - Read `.claude/harness.json` for layer directory mappings (if exists)
   - Identify related existing code and patterns
3. Surface ambiguities and implicit assumptions
4. Ask clarifying questions if critical info is missing — do not guess

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
The plan ID format is: `plan-YYYYMMDD-feature-name` (lowercase, hyphens).
Schema reference: `templates/execution-plan.json` in the oh-my-agents plugin.

```json
{
  "$schema": "execution-plan-v2",
  "id": "plan-YYYYMMDD-feature-name",
  "feature": "Feature Name",
  "status": "active",
  "created": "2026-03-17T00:00:00Z",
  "updated": "2026-03-17T00:00:00Z",
  "spec_source": "issue URL, file path, or inline description",
  "overview": "1-2 sentences describing what this feature does and why",
  "risks": [
    {
      "id": "R1",
      "description": "Description of the risk",
      "mitigation": "How to mitigate it",
      "status": "open"
    }
  ],
  "decisions": [
    {
      "id": "D1",
      "question": "What needs to be decided?",
      "decision": "What was decided",
      "alternatives": ["Alternative A", "Alternative B"],
      "rationale": "Why this decision was made"
    }
  ],
  "test_plan": {
    "unit": [
      "test_feature_creates_thing",
      "test_feature_rejects_invalid_input"
    ],
    "integration": [
      "test_feature_api_endpoint",
      "test_feature_persists_data"
    ],
    "structural": [
      "Files follow naming convention",
      "No layer boundary violations",
      "No file exceeds size limit"
    ]
  },
  "tasks": [
    {
      "id": 1,
      "title": "Define types in src/types/feature.ts",
      "layer": "types",
      "phase": 1,
      "status": "pending",
      "files": ["src/types/feature.ts"],
      "depends_on": [],
      "acceptance": [
        "test_feature_types passes",
        "Lint passes with no new warnings"
      ],
      "constraints": [
        "Do not import from service or runtime layers",
        "Do not add runtime logic to type definitions"
      ],
      "context": [
        "docs/ARCHITECTURE.md — layer model section",
        "src/types/existing-similar.ts — follow this pattern",
        "docs/CONVENTIONS.md — naming rules"
      ]
    },
    {
      "id": 2,
      "title": "Add config in src/config/feature.ts",
      "layer": "config",
      "phase": 1,
      "status": "pending",
      "files": ["src/config/feature.ts"],
      "depends_on": [],
      "acceptance": [
        "test_feature_config passes",
        "Config validates all required fields"
      ],
      "constraints": [
        "Do not hardcode values — use environment variables",
        "Do not import from layers above config"
      ],
      "context": [
        "src/config/existing-config.ts — follow this pattern",
        "docs/CONVENTIONS.md — config patterns"
      ]
    },
    {
      "id": 3,
      "title": "Repository layer src/repo/feature.ts",
      "layer": "repo",
      "phase": 2,
      "status": "pending",
      "files": ["src/repo/feature.ts"],
      "depends_on": [1],
      "acceptance": [
        "test_feature_repo passes",
        "Uses parameterized queries (no SQL injection)"
      ],
      "constraints": [
        "Do not contain business logic — that belongs in service layer",
        "Do not import from service, runtime, or ui layers"
      ],
      "context": [
        "src/repo/existing-repo.ts — follow this pattern",
        "src/types/feature.ts — use these types"
      ]
    },
    {
      "id": 4,
      "title": "Service logic src/services/feature.ts",
      "layer": "service",
      "phase": 3,
      "status": "pending",
      "files": ["src/services/feature.ts"],
      "depends_on": [1, 3],
      "acceptance": [
        "test_feature_service passes",
        "Cross-cutting concerns use Providers interface"
      ],
      "constraints": [
        "Do not access storage directly — use repo layer",
        "Do not import from runtime or ui layers",
        "Do not bypass Providers for auth/telemetry/flags"
      ],
      "context": [
        "src/services/existing-service.ts — follow this pattern",
        "docs/PROVIDERS.md — cross-cutting concern patterns"
      ]
    },
    {
      "id": 5,
      "title": "API endpoint src/api/feature.ts",
      "layer": "runtime",
      "phase": 4,
      "status": "pending",
      "files": ["src/api/feature.ts"],
      "depends_on": [4],
      "acceptance": [
        "test_feature_api passes",
        "Input validation on all parameters",
        "Error responses don't leak internals"
      ],
      "constraints": [
        "Do not contain business logic — delegate to service",
        "Do not import from repo layer directly"
      ],
      "context": [
        "src/api/existing-endpoint.ts — follow this pattern",
        "docs/CONVENTIONS.md — API response format"
      ]
    },
    {
      "id": 6,
      "title": "Verification: all tests pass, docs updated, observability added",
      "layer": "cross-cutting",
      "phase": 5,
      "status": "pending",
      "files": [],
      "depends_on": [1, 2, 3, 4, 5],
      "acceptance": [
        "All unit tests pass",
        "All integration tests pass",
        "All structural tests pass",
        "Lint clean",
        "docs/ updated if new patterns introduced",
        "Observability: logging/metrics added per docs/OBSERVABILITY.md"
      ],
      "constraints": [
        "Do not skip failing tests — fix the implementation",
        "Do not weaken lint rules to pass"
      ],
      "context": [
        "docs/TESTING.md — coverage requirements",
        "docs/OBSERVABILITY.md — logging and metrics patterns"
      ]
    }
  ],
  "metrics": {
    "tasks_total": 6,
    "tasks_done": 0,
    "tasks_blocked": 0
  }
}
```

Each task `status` transitions: `pending` -> `in_progress` -> `done` (or `blocked`).
New sessions read this file to understand prior work state ("shift handoff").

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
