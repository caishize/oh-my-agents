---
name: spec-to-task
description: Convert feature specs into agent-executable tasks with explicit context, acceptance criteria, and layer-aware decomposition. Based on OpenAI's planning-before-execution methodology.
user-invocable: true
argument-hint: "<spec-description or issue-url>"
---

# Spec to Task

Decompose specifications into agent-executable tasks. Based on OpenAI's finding that
**planning before execution** is essential — agents waste effort without well-scoped,
context-rich task definitions.

> "Agents have no tacit knowledge; until it is made explicit, it doesn't exist."

## Key Insight from OpenAI

Their team found three critical patterns:

1. **Separate planning and execution phases** — Never let agents start implementing
   before the task is fully specified with failing tests
2. **Slack-to-codebase pattern** — When technical decisions happen in chat, immediately
   encode them: "When someone had a technical decision in Slack, they would tag Codex:
   '@codex please add guardrails to our codebase' and get 4 PRs in 15 minutes"
3. **JSON > Markdown for progress tracking** — Anthropic found that JSON feature tracking
   is superior to Markdown because agents less frequently overwrite structured data.
   Use JSON progress files to enable "shift handoff" where new sessions quickly understand
   prior work state

## Task

Take a feature spec (from $ARGUMENTS) and decompose into agent-ready tasks.

### Step 1: Analyze the Specification

1. Read the feature spec, issue, or user description
2. Analyze the current codebase:
   - Read CLAUDE.md for architecture overview
   - Read docs/ARCHITECTURE.md for layer model and boundaries
   - Read docs/CONVENTIONS.md for patterns to follow
   - Identify related existing code and patterns
3. Surface ambiguities and implicit assumptions
4. Ask clarifying questions if critical info is missing

### Step 2: Design Failing Tests First

Before any implementation tasks, define the tests that prove the feature works.
This is the "generate feature lists with explicit test steps initially marked as failing"
approach:

```markdown
## Test Plan (write these FIRST)

### Unit Tests
- [ ] `test_[feature]_creates_[thing]` — verifies core creation logic
- [ ] `test_[feature]_rejects_invalid_input` — verifies validation
- [ ] `test_[feature]_handles_edge_case` — verifies edge case

### Integration Tests
- [ ] `test_[feature]_api_endpoint` — verifies API contract
- [ ] `test_[feature]_persists_data` — verifies storage

### Structural Tests
- [ ] New files follow naming convention
- [ ] New modules respect layer boundaries
- [ ] No file exceeds size limit
```

### Step 3: Decompose by Architecture Layer

Each task maps to a specific architecture layer, following the dependency flow:

```
Phase 1: Types → Config (no dependencies, can parallelize)
Phase 2: Repository (depends on Types)
Phase 3: Service (depends on Repo + Types)
Phase 4: Runtime/API (depends on Service)
Phase 5: UI (depends on Runtime)
Phase 6: Cross-cutting (tests, docs, observability)
```

### Step 4: Write Agent-Friendly Task Definitions

Each task must include everything an agent needs — no tacit knowledge:

```markdown
## Task [N]: [Imperative title]

**Layer**: [Types|Config|Repo|Service|Runtime|UI]
**Estimated scope**: [number of files to create/modify]

### Context
- Architecture: this feature lives in the [X] layer
- Pattern to follow: `src/[existing-similar-file]` (read this first)
- Related code: [specific files the agent will need]
- Constraints from docs/ARCHITECTURE.md: [relevant constraints]

### Requirements
1. [Specific, unambiguous requirement]
2. [Another requirement with concrete example]
3. Error handling: [follow pattern in existing file]
4. Observability: [logging/metrics via Providers interface]

### Acceptance Criteria
- [ ] Test `test_[name]` passes (write test first, verify it fails, then implement)
- [ ] Lint passes with no new warnings
- [ ] No layer boundary violations
- [ ] File under 300 lines
- [ ] Cross-cutting concerns use Providers (not direct access)

### Constraints (what NOT to do)
- Do not modify files outside [scope]
- Do not add new dependencies without justification
- Do not duplicate logic from [existing helper]
- Do not bypass the Providers interface for [auth/telemetry/etc]

### Pre-read (context the agent needs before starting)
1. `docs/ARCHITECTURE.md#[relevant-section]`
2. `src/[pattern-file]` — follow this pattern
3. `docs/CONVENTIONS.md#[relevant-rules]`
```

### Step 5: Create Execution Plan

```markdown
# Implementation Plan: [Feature Name]

## Overview
[1-2 sentences]

## Test Plan
[Tests to write first — they should fail initially]

## Tasks (ordered by dependency)

### Phase 1: Foundation (parallelizable)
- [ ] Task 1: Define types in `src/types/[feature].ts`
- [ ] Task 2: Add config in `src/config/[feature].ts`

### Phase 2: Core Logic
- [ ] Task 3: Repository layer `src/repo/[feature].ts`
- [ ] Task 4: Service logic `src/services/[feature].ts`

### Phase 3: Integration
- [ ] Task 5: API endpoint `src/api/[feature].ts`
- [ ] Task 6: UI component `src/ui/[feature]/`

### Phase 4: Verification
- [ ] Task 7: Run all tests, verify passing
- [ ] Task 8: Update docs (CLAUDE.md if needed, docs/API-CONTRACTS.md)
- [ ] Task 9: Add observability (logging, metrics via Providers)

## ADR (if needed)
If this feature introduces a new pattern or technology choice, add an ADR to
docs/DECISIONS.md: "We chose X over Y because..."

## Risks
- [Decisions that need human input]
- [Ambiguities that couldn't be resolved from docs]
```

## Rules

- **Tests first** — every feature starts with failing tests, then implementation
- **No tacit knowledge** — if a convention isn't in docs/, add it to the task context
- Each task must reference specific files and patterns to follow
- Constraints (what NOT to do) are as important as requirements
- Prefer smaller tasks — one per architecture layer
- Slack-to-codebase: if a decision was made verbally, add an ADR
- Layer-aware: tasks must respect Types → Config → Repo → Service → Runtime → UI
