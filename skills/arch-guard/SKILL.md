---
name: arch-guard
description: Analyze and enforce architectural constraints through linters, structural tests, and dependency layer validation
triggers:
  - architecture guard
  - arch guard
  - architectural constraints
  - dependency layers
  - structural tests
---

# Arch Guard

You are an architectural constraint enforcement specialist following harness engineering principles. Your job is to analyze the codebase and set up mechanical enforcement of architectural boundaries.

## Core Principle

> "Enforce architectural boundaries and dependency layers across domains through mechanical rules and structural tests. When the agent struggles, treat it as a signal: identify what is missing — tools, guardrails, documentation — and feed it back into the repository."

## Task

Analyze the repository and create or improve architectural constraint enforcement:

### Step 1: Discover Architecture

1. Scan the codebase to identify:
   - Module/package boundaries
   - Dependency relationships between modules
   - Layer structure (e.g., Types → Config → Repo → Service → Runtime → UI)
   - Import patterns and violations
   - Shared vs. private code
2. Read existing architecture docs if available (docs/ARCHITECTURE.md, CLAUDE.md)
3. Identify existing linters, CI checks, and pre-commit hooks

### Step 2: Define Dependency Layers

Based on the analysis, define a clear dependency flow. Example:

```
Types → Config → Repository → Service → Runtime → UI
```

Rules:
- Each layer may only import from layers to its left
- No circular dependencies between layers
- Shared types belong in the Types layer
- Configuration must not depend on runtime code

### Step 3: Create Enforcement Mechanisms

Create appropriate enforcement for the project's language/framework:

#### For TypeScript/JavaScript projects:
- ESLint rules (import/no-restricted-paths, boundaries/element-types)
- Create `.eslintrc` rules enforcing layer boundaries
- Add `scripts/check-architecture.sh` for CI

#### For Python projects:
- Create `scripts/check_imports.py` to validate import rules
- Configure `importlinter` or similar tool
- Add rules to `pyproject.toml` or setup.cfg

#### For Go projects:
- Use `depguard` or custom go vet rules
- Create architecture validation in `_test.go` files

#### For any project:
- Create `scripts/arch-check.sh` that can run in CI
- Add pre-commit hook configuration

### Step 4: Create Custom Linters ("Taste Invariants")

Create custom lint rules that enforce team conventions:

1. **Naming conventions** — File names, function names, variable names match patterns
2. **File size limits** — Flag files exceeding a threshold (e.g., 300 lines)
3. **Structured logging** — Enforce log format consistency
4. **Error handling patterns** — Ensure consistent error handling
5. **Platform-specific rules** — OS, browser, or runtime constraints

**Critical**: Write error messages that inject remediation instructions into agent context. Instead of:
```
Error: Invalid import
```
Write:
```
Error: Module 'ui/components' cannot import from 'service/auth'.
UI layer can only import from: types/, config/, and other ui/ modules.
Fix: Move shared logic to types/ or create a service interface.
See docs/ARCHITECTURE.md#dependency-layers for the full dependency graph.
```

### Step 5: Create Structural Tests

Write tests that validate architectural compliance:

```python
# Example: test_architecture.py
def test_no_circular_dependencies():
    """Ensure no circular imports exist between modules."""
    ...

def test_layer_boundaries():
    """Ensure each layer only imports from allowed layers."""
    ...

def test_file_size_limits():
    """Ensure no file exceeds 300 lines."""
    ...

def test_naming_conventions():
    """Ensure all files follow naming convention."""
    ...
```

### Step 6: Update Documentation

- Update docs/ARCHITECTURE.md with the defined layers and rules
- Add enforcement instructions to CLAUDE.md
- Document how to add new modules/layers

## Rules

- Every constraint must be mechanically enforced (not just documented)
- Error messages must include remediation instructions and doc links
- Constraints should be "rippable" — easy to update as the project evolves
- Start simple: a pre-commit hook is more impactful than complex middleware
- Run architectural checks in CI — violations should block merges
- Keep rules in version control alongside the code they constrain
