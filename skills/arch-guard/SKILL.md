---
name: arch-guard
description: "Set up and manage architectural enforcement — custom linters, structural tests, dependency layer validation. Reads .claude/harness.json. Integrates with nested CLAUDE.md. Use /harness-review for per-PR review instead. Aliases: 架构检查, 架构守卫, 依赖检查, 分层检查, 架构约束, 架构合规"
user-invocable: true
argument-hint: "[scope: full|layers|naming|size|providers]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Arch Guard

Set up mechanical enforcement of architectural boundaries. Based on the principle
that **"agents are most effective in environments with strict boundaries and
predictable structure"** — tech stacks and structures are chosen for
"harness-friendliness" rather than flexibility.

> "These constraints are enforced mechanically via custom linters and structural tests."
> "When the agent struggles, treat it as a signal: identify what is missing — tools,
> guardrails, documentation — and feed it back into the repository."

This skill operates across all **four pillars**:

1. **Architecture as Guardrails** — the core of this skill: layers, providers, enforcement
2. **Documentation as System of Record** — keeping ARCHITECTURE.md and CLAUDE.md in sync
3. **Observability & Legibility** — nested CLAUDE.md for module-level visibility
4. **Entropy Management** — detecting and preventing architectural drift

## Task

Analyze the repository and create or improve architectural constraint enforcement.

### Step 1: Read Project Configuration

Before scanning the codebase, check for project-specific configuration:

1. **Check `.claude/harness.json`** — If this file exists, it contains project-specific
   layer definitions, provider configuration, and enforcement preferences. Use these
   values instead of defaults. A typical `harness.json` might define:
   ```json
   {
     "layers": ["types", "config", "data", "domain", "application", "ui"],
     "layerPaths": {
       "types": "src/types/",
       "config": "src/config/",
       "data": "src/data/",
       "domain": "src/domain/",
       "application": "src/app/",
       "ui": "src/ui/"
     },
     "providers": {
       "auth": "src/providers/auth.ts",
       "telemetry": "src/providers/telemetry.ts",
       "featureFlags": "src/providers/flags.ts",
       "logger": "src/providers/logger.ts"
     },
     "fileSizeLimit": 300,
     "enforcementLevel": "strict"
   }
   ```
2. If no `harness.json` exists, use defaults and infer from the codebase.
3. Read root CLAUDE.md and docs/ARCHITECTURE.md for documented constraints.

### Step 2: Discover Architecture

1. Scan the codebase to identify:
   - Module/package boundaries
   - Dependency relationships between modules
   - Layer structure (e.g., Types -> Config -> Repo -> Service -> Runtime -> UI)
   - Import patterns and violations
   - Shared vs. private code
2. Read existing docs (docs/ARCHITECTURE.md, CLAUDE.md)
3. Identify existing linters, CI checks, pre-commit hooks

### Step 3: Define Dependency Layers

Based on the analysis (or `harness.json` if present), define a clear dependency flow:

```
Types -> Config -> Repository -> Service -> Runtime -> UI
```

Rules:
- Each layer may only import from layers to its left (unidirectional)
- No circular dependencies between layers
- Shared types belong in the Types layer
- Configuration must not depend on runtime code
- **Cross-cutting concerns (auth, telemetry, feature flags) flow through a single
  "Providers" interface** — never accessed directly from business logic

### Step 4: Set Up Providers Interface

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

### Step 5: Enhanced Providers Enforcement

Beyond basic "use Providers, not direct access," detect subtler bypass patterns
that agents frequently introduce:

**Auth library leakage:**
- Direct imports of auth libraries (e.g., `import jwt from 'jsonwebtoken'`,
  `from jose import jwt`) outside the auth provider file
- Inline token validation instead of calling the auth provider
- Session/cookie access outside the auth provider

**Telemetry/logging bypass:**
- Direct calls to telemetry SDKs (e.g., `opentelemetry`, `datadog`, `newrelic`)
  outside the telemetry provider
- `console.log` / `console.error` in production code instead of the logger provider
- Direct metric emission bypassing the telemetry provider

**Feature flag bypass:**
- Direct calls to feature flag SDKs (e.g., `launchdarkly`, `unleash`, `split`)
  outside the feature flag provider
- Hardcoded boolean flags that should go through the feature flag system
- Environment variable checks used as feature flags outside the provider

For each violation, explain why the provider pattern matters: it creates a single
point of control. When you need to swap auth providers, add telemetry, or change
flag systems, you change one file instead of hundreds.

### Step 6: Create Enforcement Mechanisms

Create appropriate enforcement for the project's language/framework:

**For TypeScript/JavaScript**: ESLint rules (import/no-restricted-paths, boundaries plugin)
**For Python**: import-linter rules or custom `scripts/check_imports.py`
**For Go**: depguard rules or architecture validation tests
**For any project**: `scripts/arch-check.sh` for CI + pre-commit hook config

### Step 7: Create Custom Linters ("Taste Invariants")

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

### Step 8: Nested CLAUDE.md Integration

Check whether directory-level CLAUDE.md files accurately reflect architectural reality.
This is where the Documentation and Architecture pillars intersect — module docs
that contradict the architecture actively mislead agents.

1. **Audit existing nested CLAUDE.md files**:
   - Does each module's CLAUDE.md declare which layer it belongs to?
   - Do the declared allowed imports match the actual layer rules?
   - Are there contradictions between module CLAUDE.md and root CLAUDE.md?

2. **Suggest new nested CLAUDE.md for violation hotspots**:
   - If a module has 3+ architectural violations, a nested CLAUDE.md with explicit
     layer rules can prevent future violations
   - Template for module CLAUDE.md:
     ```markdown
     # [Module Name]

     Layer: [service|ui|config|etc.]
     Allowed imports: [list of layers this module may import from]

     ## Purpose
     [One sentence]

     ## Conventions
     - [Module-specific rules]

     ## Key Files
     - [file.ts] — [purpose]
     ```

3. **Flag inconsistencies**: If a nested CLAUDE.md says "this is a service-layer module"
   but the code imports from UI, flag both the violation and the misleading docs.

### Step 9: Create Structural Tests

Write tests that validate architectural compliance:

- `test_no_circular_dependencies` — no circular imports
- `test_layer_boundaries` — each layer only imports from allowed layers
- `test_file_size_limits` — no file exceeds limit
- `test_naming_conventions` — all files follow conventions

### Step 10: Update Documentation

- Update docs/ARCHITECTURE.md with defined layers and rules
- Add enforcement instructions to CLAUDE.md
- Document how to add new modules/layers
- Update nested CLAUDE.md files for modules with new constraints

## Rules

- Every constraint must be mechanically enforced (not just documented)
- Error messages must include remediation instructions and doc links
- Constraints should be "rippable" — easy to update as the project evolves
- Start simple: a pre-commit hook is more impactful than complex middleware
- Run architectural checks in CI — violations should block merges
- Read `.claude/harness.json` first — project-specific config overrides defaults
- Nested CLAUDE.md files must agree with architectural constraints
