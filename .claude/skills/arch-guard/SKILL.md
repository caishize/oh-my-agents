---
name: arch-guard
description: Analyze and enforce architectural constraints through custom linters, structural tests, and dependency layer validation. Based on OpenAI's rigid layered architecture + Providers pattern where agents are restricted to operate within defined layers.
user-invocable: true
argument-hint: "[scope: full|layers|naming|size|providers]"
---

# Arch Guard

Set up mechanical enforcement of architectural boundaries. Based on OpenAI's approach
where **"agents are most effective in environments with strict boundaries and
predictable structure"** — they chose tech stacks and structures for "harness-friendliness"
rather than flexibility.

> "These constraints are enforced mechanically via custom linters and structural tests."
> "When the agent struggles, treat it as a signal: identify what is missing — tools,
> guardrails, documentation — and feed it back into the repository."

## Task

Analyze the repository and create or improve architectural constraint enforcement.

### Step 1: Discover Architecture

1. Scan the codebase to identify:
   - Module/package boundaries
   - Dependency relationships between modules
   - Layer structure (e.g., Types → Config → Repo → Service → Runtime → UI)
   - Import patterns and violations
   - Shared vs. private code
2. Read existing docs (docs/ARCHITECTURE.md, CLAUDE.md)
3. Identify existing linters, CI checks, pre-commit hooks

### Step 2: Define Dependency Layers

Based on the analysis, define a clear dependency flow:

```
Types → Config → Repository → Service → Runtime → UI
```

Rules:
- Each layer may only import from layers to its left (unidirectional)
- No circular dependencies between layers
- Shared types belong in the Types layer
- Configuration must not depend on runtime code
- **Cross-cutting concerns (auth, telemetry, feature flags) flow through a single
  "Providers" interface** — never accessed directly from business logic

### Step 3: Set Up Providers Interface

Channel cross-cutting concerns through a single interface. This prevents agents
from scattering auth checks, telemetry calls, and feature flag reads throughout
the codebase:

```
// src/providers/index.ts (or equivalent)
export interface Providers {
  auth: AuthProvider;
  telemetry: TelemetryProvider;
  featureFlags: FeatureFlagProvider;
  logger: LoggerProvider;
}
```

All service/runtime code accesses these through Providers, never directly. This is
critical because agents will replicate whatever access pattern they see — if one file
calls `getFeatureFlag()` directly, agents will do it everywhere.

### Step 4: Create Enforcement Mechanisms

Create appropriate enforcement for the project's language/framework:

**For TypeScript/JavaScript**: ESLint rules (import/no-restricted-paths, boundaries plugin)
**For Python**: import-linter rules or custom `scripts/check_imports.py`
**For Go**: depguard rules or architecture validation tests
**For any project**: `scripts/arch-check.sh` for CI + pre-commit hook config

### Step 5: Create Custom Linters ("Taste Invariants")

Create custom lint rules that enforce:

1. **Naming conventions** — files, functions, variables match patterns
2. **File size limits** — flag files exceeding threshold (e.g., 300 lines)
3. **Structured logging** — enforce log format consistency
4. **Error handling patterns** — consistent error handling
5. **Platform-specific rules** — OS, browser, runtime constraints

**Critical**: Error messages must inject remediation instructions:
```
BAD:  Error: Invalid import
GOOD: Error: Module 'ui/components' cannot import from 'service/auth'.
      UI layer can only import from: types/, config/, and other ui/ modules.
      Fix: Move shared logic to types/ or create a service interface.
      See docs/ARCHITECTURE.md#dependency-layers
```

### Step 6: Create Structural Tests

Write tests that validate architectural compliance:

- `test_no_circular_dependencies` — no circular imports
- `test_layer_boundaries` — each layer only imports from allowed layers
- `test_file_size_limits` — no file exceeds limit
- `test_naming_conventions` — all files follow conventions

### Step 7: Update Documentation

- Update docs/ARCHITECTURE.md with defined layers and rules
- Add enforcement instructions to CLAUDE.md
- Document how to add new modules/layers

## Rules

- Every constraint must be mechanically enforced (not just documented)
- Error messages must include remediation instructions and doc links
- Constraints should be "rippable" — easy to update as the project evolves
- Start simple: a pre-commit hook is more impactful than complex middleware
- Run architectural checks in CI — violations should block merges
