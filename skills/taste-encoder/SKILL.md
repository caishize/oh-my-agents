---
name: taste-encoder
description: "Encode team expertise into mechanical enforcement — custom lint rules, structural tests, bespoke code reviewers. Each expert's knowledge becomes a multiplier for the agent fleet. Integrates with nested CLAUDE.md and memory for cross-session persistence. Aliases: 品味编码, 规则编码, 编码规范, 知识固化, 团队规范, 自定义lint规则"
user-invocable: true
argument-hint: "<what-to-encode: pattern-description or code-example>"
allowed-tools: Read, Glob, Grep, Bash
---

# Taste Encoder

Turn human expertise and "taste" into mechanically-enforced rules. Based on a
key insight: **"If you can articulate what code you dislike, write that down"** as a
lint rule, structural test, or automated reviewer.

> **Mitchell Hashimoto's principle**: "Anytime you find an agent makes a mistake, you
> take the time to engineer a solution such that the agent never makes that mistake again."
>
> This is the core philosophy of taste encoding. Every mistake is an opportunity to
> permanently improve the entire agent fleet. The cost of encoding a rule is paid once;
> the benefit compounds across every future agent session.

> "Each person's expertise becomes a multiplier for the entire team's agent fleet."
> When a front-end expert joined OpenAI's team, they encoded React component architecture
> patterns (single-file hooks, small testable components). All agents immediately benefited.

This skill touches all **four pillars**:

1. **Architecture as Guardrails** — lint rules and structural tests are guardrails
2. **Documentation as System of Record** — rules are documented in docs/ and CLAUDE.md
3. **Observability & Legibility** — error messages make violations visible and fixable
4. **Entropy Management** — encoding prevents the same mistake from recurring

## Why This Matters

Without encoding, agents will:
- Create duplicate helper functions (real example: Codex kept creating duplicate
  concurrency helpers, but only one version connected to OpenTelemetry)
- Violate unwritten conventions that "everyone knows"
- Produce code that's technically correct but stylistically wrong ("slop")

With encoding, every agent inherits every team member's expertise automatically.

## Task

Take the user's description of a pattern, convention, or preference ($ARGUMENTS) and
encode it into mechanical enforcement.

### Step 1: Understand the Taste

Ask clarifying questions if needed:
1. **What's the bad pattern?** Show an example of code you dislike
2. **What's the good pattern?** Show the preferred alternative
3. **Why does it matter?** (observability, consistency, performance, security)
4. **How strict?** Error (block), warning (flag), or info (suggest)?

### Step 2: Choose the Encoding Method

Pick the right enforcement mechanism:

| Method | When to Use | Effort |
|--------|-------------|--------|
| **Custom lint rule** | Pattern is syntactically detectable | Medium |
| **Structural test** | Pattern involves file/module organization | Medium |
| **Pre-commit hook** | Pattern should be checked before every commit | Low |
| **Doc rule in CLAUDE.md** | Pattern is too nuanced for automation | Low |
| **Code review checklist** | Pattern requires judgment | Low |

### Step 3: Implement the Encoding

#### For Custom Lint Rules

Create a rule with **remediation instructions in the error message**. This is critical —
the error message doubles as agent context:

**ESLint example** (TypeScript/JavaScript):
```javascript
// eslint-rules/no-duplicate-concurrency-helpers.js
module.exports = {
  meta: {
    type: "problem",
    docs: { description: "Disallow defining concurrency helpers outside approved location" },
    messages: {
      noDuplicate: [
        "Do not define concurrency/async helper functions here.",
        "Use the approved implementation from 'src/utils/concurrency.ts' which",
        "includes OpenTelemetry instrumentation.",
        "Import: import { withRetry, withTimeout } from '@/utils/concurrency'",
        "Ref: docs/CONVENTIONS.md#concurrency-helpers"
      ].join("\n")
    }
  },
  create(context) {
    return {
      FunctionDeclaration(node) {
        if (isConcurrencyHelper(node) && !isApprovedLocation(context)) {
          context.report({ node, messageId: "noDuplicate" });
        }
      }
    };
  }
};
```

**Ruff/Python example**:
```python
# Add to pyproject.toml [tool.ruff.lint] or create custom flake8 plugin
# For simpler cases, use a structural test instead
```

#### For Structural Tests

```python
# tests/test_architecture.py
import ast
import glob

def test_concurrency_helpers_only_in_approved_location():
    """Only src/utils/concurrency.py may define retry/timeout helpers.
    All other modules must import from there.
    Rationale: The approved version includes OpenTelemetry instrumentation.
    Ref: docs/CONVENTIONS.md#concurrency-helpers"""
    violations = []
    for path in glob.glob("src/**/*.py", recursive=True):
        if path == "src/utils/concurrency.py":
            continue
        with open(path) as f:
            tree = ast.parse(f.read())
        for node in ast.walk(tree):
            if isinstance(node, ast.FunctionDef) and node.name in ("with_retry", "with_timeout"):
                violations.append(f"{path}:{node.lineno}")
    assert not violations, (
        f"Concurrency helpers defined outside approved location:\n"
        + "\n".join(violations)
        + "\nUse imports from src/utils/concurrency.py instead."
        + "\nRef: docs/CONVENTIONS.md#concurrency-helpers"
    )

def test_file_size_limits():
    """No source file should exceed 300 lines.
    Ref: docs/CONVENTIONS.md#file-size"""
    violations = []
    for path in glob.glob("src/**/*.py", recursive=True):
        with open(path) as f:
            lines = sum(1 for _ in f)
        if lines > 300:
            violations.append(f"{path}: {lines} lines (limit: 300)")
    assert not violations, (
        f"Files exceeding size limit:\n"
        + "\n".join(violations)
        + "\nRefactor: extract helpers into separate modules."
        + "\nRef: docs/CONVENTIONS.md#file-size"
    )
```

#### For Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: check-approved-patterns
        name: Check approved patterns
        entry: scripts/check-patterns.sh
        language: script
        types: [python]  # or [javascript], [typescript], etc.
```

### Step 4: Error Message Quality Checklist

Every error message produced by an encoded rule must pass this checklist. Error
messages are agent context — a bad error message means the agent will struggle to
fix the violation, and may introduce new slop trying to work around it.

Each error message MUST include:

1. **What the violation is** — Clear, specific description of what went wrong.
   Bad: "Invalid import." Good: "Module 'ui/dashboard' imports from 'service/internal/auth'."

2. **Where the correct pattern lives** — Point to the approved location or reference.
   "Use the approved implementation from 'src/utils/concurrency.ts'."

3. **How to fix it** — Concrete remediation steps, not just "fix this."
   "Import: `import { withRetry } from '@/utils/concurrency'`"

4. **Reference to docs** — Link to the convention, ADR, or architecture doc.
   "Ref: docs/CONVENTIONS.md#concurrency-helpers"

If an error message is missing any of these four elements, the encoding is incomplete.
An agent seeing a bad error message will either ignore it or produce a worse fix.

### Step 5: Document the Rule

Add an entry to `docs/LINTING.md` or `docs/CONVENTIONS.md`:

```markdown
## Concurrency Helpers (TASTE-001)

**Rule**: Only `src/utils/concurrency.ts` may define retry/timeout helpers.
**Enforced by**: ESLint rule `no-duplicate-concurrency-helpers`
**Rationale**: The approved version includes OpenTelemetry instrumentation.
Duplicates lose observability.
**Added by**: [name] on [date]
**Good example**: `import { withRetry } from '@/utils/concurrency'`
**Bad example**: `function withRetry(fn) { ... }` in any other file
```

### Step 6: Update Nested CLAUDE.md

After creating a rule, check whether the relevant module's CLAUDE.md should be
updated. This is where the Documentation pillar intersects with enforcement —
an agent reading a module's CLAUDE.md should see the conventions that apply to
that module.

1. **Identify the affected module** — Which directory does this rule primarily affect?
2. **Check if a nested CLAUDE.md exists** for that module.
   - If yes: Add the new convention to the module's "Conventions" section.
   - If no, and the module has 5+ files: Suggest creating one with the convention included.
3. **Keep it concise** — Add one line describing the rule, not the full documentation.
   Example: `- Use @/utils/concurrency for all retry/timeout logic (TASTE-001)`
4. **Verify consistency** — Ensure the nested CLAUDE.md doesn't contradict the root
   CLAUDE.md or docs/CONVENTIONS.md.

### Step 7: Memory Integration

When encoding a taste, suggest saving to Claude Code memory for cross-session
persistence. Lint rules and structural tests persist in the repo, but CLAUDE.md
rules and team conventions benefit from memory reinforcement.

**Suggest the following pattern to the user**:

> Consider saving this convention to Claude Code memory so it persists across sessions:
>
> "Convention encoded on [date] by [who]: [one-line description]. Enforced by [method].
> Reason: [why]. See docs/CONVENTIONS.md#[section] and [module]/CLAUDE.md."

This is especially valuable for:
- Conventions that are documented in CLAUDE.md but not mechanically enforced
- Patterns that are nuanced and require judgment
- Team preferences that span multiple modules

Memory complements mechanical enforcement — enforcement catches violations at
commit time, while memory helps agents avoid violations during code generation.

### Step 8: Verify the Encoding

1. Write a test case that triggers the violation — confirm it's caught
2. Write a test case that follows the pattern — confirm it passes
3. Run the full lint/test suite — no false positives
4. Verify the error message passes the quality checklist (Step 4)
5. Verify nested CLAUDE.md is updated if applicable (Step 6)

## Rules

- Error messages MUST pass the quality checklist (what, where, how, ref)
- Every rule needs a reference to documentation (docs/ file + section)
- Rules must have 100% test coverage (both positive and negative cases)
- Start simple — a doc rule in CLAUDE.md is better than no rule at all
- Rules should be "rippable" — easy to update or remove as needs change
- Tag each rule with an ID (TASTE-001) for tracking
- Include "Added by" and date so the team knows who owns the expertise
- Update nested CLAUDE.md when a rule affects a specific module
- Suggest memory integration for conventions that benefit from cross-session persistence
- Remember Mitchell Hashimoto: every agent mistake is an encoding opportunity
