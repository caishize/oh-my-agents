---
name: spec-to-task
description: Convert feature specifications into well-structured, agent-friendly tasks with clear acceptance criteria and explicit context. Use before starting feature implementation.
user-invocable: true
argument-hint: "<spec-description or issue-url>"
---

# Spec to Task

You are a task decomposition specialist following harness engineering principles.
Convert high-level specifications into agent-executable tasks with clear acceptance
criteria and explicit context.

## Core Principle

> "Agents have no tacit knowledge; until it is made explicit, it doesn't exist."
> Every task must contain enough context for an AI agent to execute without assumptions.

## Task

Take a feature spec (from $ARGUMENTS, issue, or document) and decompose into tasks.

### Step 1: Analyze the Specification

1. Read the feature spec, issue, or user description
2. Analyze the current codebase:
   - Existing patterns and conventions
   - Related code affected
   - Architecture and dependency layers
   - Available test infrastructure
3. Identify ambiguities and implicit assumptions
4. Ask clarifying questions if critical info is missing

### Step 2: Identify Task Boundaries

Decompose following these rules:

1. **Single responsibility** — each task does one thing
2. **Independently verifiable** — testable acceptance criteria
3. **Layer-aware** — tasks respect architectural boundaries
4. **Ordered by dependency** — list prerequisites
5. **Right-sized** — one agent session, meaningful scope

Common decomposition pattern:
```
1. Data model / types  (Types layer)
2. Configuration       (Config layer)
3. Data access         (Repository layer)
4. Business logic      (Service layer)
5. API endpoints       (Runtime layer)
6. UI components       (UI layer)
7. Tests               (Cross-cutting)
8. Documentation       (Cross-cutting)
```

### Step 3: Write Agent-Friendly Tasks

For each task:

```markdown
## Task: [Clear, imperative title]

### Context
- Existing pattern: `src/services/userService.ts`
- Architecture layer: Service
- Related files: [specific file list]

### Requirements
1. Create X that does Y
2. Handle Z edge case
3. Follow pattern in [existing file]

### Acceptance Criteria
- [ ] Unit test passes
- [ ] No lint errors
- [ ] Follows naming convention
- [ ] File size under 300 lines
- [ ] Documented in docs/API-CONTRACTS.md

### Constraints
- Do not modify files outside `src/services/`
- Do not add new dependencies
- Do not change public API of existing functions

### Dependencies
- Requires: Task 1 (data model) completed
```

### Step 4: Create Execution Plan

Output a PLAN.md:

```markdown
# Feature: [Name]

## Overview
[1-2 sentence description]

## Tasks (execution order)

### Phase 1: Foundation
- [ ] Task 1: Define types in `src/types/feature.ts`
- [ ] Task 2: Add config in `src/config/feature.ts`

### Phase 2: Implementation
- [ ] Task 3: Repository layer
- [ ] Task 4: Service logic

### Phase 3: Integration
- [ ] Task 5: API endpoint
- [ ] Task 6: UI component

### Phase 4: Verification
- [ ] Task 7: Tests for all layers
- [ ] Task 8: Documentation update

## Risks
[Cross-cutting concerns, decisions for human review]
```

### Step 5: Validate

1. **Completeness** — all tasks together fulfill the spec?
2. **No gaps** — implicit steps missing?
3. **No overlap** — clear non-overlapping scope per task?
4. **Testability** — each task mechanically verifiable?
5. **Context sufficiency** — agent can execute with only provided context?

## Rules

- Never assume tacit knowledge — document conventions in each task
- Include specific file paths, function names, code examples
- Every acceptance criterion must be mechanically verifiable
- Constraints (what NOT to do) are as important as requirements
- Prefer smaller tasks when in doubt
- Always include documentation update task for user-facing changes
- Reference existing code as patterns: "Follow `src/services/userService.ts:createUser()`"
