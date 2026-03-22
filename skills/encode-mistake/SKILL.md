---
name: encode-mistake
description: "Convert an agent mistake or recurring failure into a permanent guardrail — lint rule, structural test, hook, or doc rule. Implements Mitchell Hashimoto's principle: 'Every agent mistake is an encoding opportunity.' Complements /taste-encoder (which starts from patterns you dislike). Aliases: 编码错误, 固化规则, 错误学习, 经验编码, 防止复发"
user-invocable: true
argument-hint: "<description of what went wrong> [--hook-output]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Encode Mistake

> "Every agent mistake is an encoding opportunity. Each person's expertise becomes
> a multiplier for the entire team's agent fleet." — Mitchell Hashimoto

Turn a failure into a permanent guardrail. This skill systematically converts agent
mistakes, recurring `/verify` failures, or observed bad patterns into mechanical
enforcement — so the same mistake cannot happen twice.

**Difference from `/taste-encoder`:**
- `/taste-encoder` starts from a *pattern you dislike* (proactive taste encoding)
- `/encode-mistake` starts from a *specific failure that already happened* (reactive
  learning from incidents). Both produce the same output: a permanent enforcement rule.

## When to Use

- An agent made the same mistake twice despite documentation
- `/verify` shows a recurring test failure across multiple sessions
- `/harness-review` flagged slop that a linter should have caught automatically
- A hook fired but the agent worked around it or was confused by the error message
- A security issue was caught in review that should have been blocked earlier

## Task

Take the mistake description from `$ARGUMENTS` and create a permanent enforcement artifact.

If `--hook-output` flag is present, treat `$ARGUMENTS` as a raw hook error message
and parse it to understand what pattern was violated.

### Step 1: Understand the Mistake

Parse the input:
1. What exact bad pattern occurred? (specific code, file, import path, command)
2. What should have happened instead?
3. Has this happened before? (search git log for similar fixes)
4. Is this language/framework-specific or universal to all projects?

Ask clarifying questions if the input is ambiguous. Do not guess.

Classify the mistake type:
- `arch-violation` — layer boundary crossed or Providers bypassed
- `secret-leak` — hardcoded credential or token
- `slop` — duplicate logic, copy-paste artifact, over-engineering
- `doc-gap` — rule in docs but not mechanically enforced
- `missing-rule` — pattern never documented or enforced
- `bad-example` — existing code teaching the wrong pattern to future agents

### Step 2: Find the Root Cause in the Codebase

1. Search for existing instances of the bad pattern: use `Grep` on the codebase
2. Check `docs/LINTING.md` — is there already a TASTE rule for this? (gap in enforcement)
3. Check the relevant hook files — does a hook cover this? (misconfigured or missing)
4. Check if good examples exist that agents should have been following instead

**Root cause determines the fix strategy:**
- Pattern detectable by regex/string match → hook improvement or new hook pattern
- Language-specific structural issue → custom lint rule
- File convention (naming, size, location) → structural test
- Complex judgment call → doc rule + example, not mechanical

### Step 3: Choose Encoding Method

Select the **minimum viable enforcement** that reliably catches the pattern:

| Method | Use When | Reliability |
|--------|----------|-------------|
| Improve existing hook error message | Hook fired but agent was confused | Immediate |
| Add pattern to `safety-check.sh` | Security/credential pattern | Always-on |
| Add pattern to `arch-check.sh` | Import/layer violation | Always-on |
| Structural test | File convention (name, size, location) | CI + pre-commit |
| Custom lint rule | Language AST-level pattern | Always-on |
| Doc rule only | Too context-dependent for automation | Agent-dependent |

**Key rule**: prefer mechanical over doc-only. A doc rule that isn't enforced will be
violated again. "If you can articulate what code you dislike, you can write a lint rule."

### Step 4: Implement the Enforcement

#### Option A: Improve Hook Error Message

If the hook fired correctly but the agent was confused or worked around it:

1. Find the hook in `hooks/` that covers this pattern
2. Improve the error message to include:
   - **WHAT**: one sentence describing the violation
   - **WHERE**: exact file path or docs/ section with the correct pattern
   - **HOW**: specific, step-by-step fix (not "use the right pattern")
   - **REF**: `docs/LINTING.md#TASTE-NNN`
3. Do NOT change detection logic unless it has genuine false positives

#### Option B: Add Detection to Existing Hook

For new patterns in `safety-check.sh` (credentials) or `arch-check.sh` (imports):

1. Add a new detection block following the exact existing pattern structure
2. Include positive comment explaining what the pattern detects and why
3. Use `add_violation` helper with all four fields (risk_type, file, pattern, fix, ref)
4. Add to both comment-stripped and full content checks as appropriate

#### Option C: Add Structural Test

For file conventions (naming, size, location, import structure):

1. Check for `tests/test_architecture.py` or `tests/architecture.test.ts`
2. Add a new test function that asserts the convention holds
3. Test runs in ~1s; must pass before commit via pre-commit architecture guard
4. Annotate any pre-existing violations with `@pytest.mark.skip` / `test.skip` + reason

#### Option D: Custom Lint Rule

For language AST-level patterns (TypeScript, Python, etc.):

1. Create the rule in the appropriate linter (ESLint plugin, Ruff, etc.)
2. Ensure the error message follows the WHAT/WHERE/HOW/REF format
3. Add to the linter config (`.eslintrc`, `ruff.toml`, etc.)

### Step 5: Document in LINTING.md

**Always** add a new entry to `docs/LINTING.md`:

```markdown
## TASTE-[NNN]: [Short Rule Name]

**Status**: Active
**Severity**: error | warning
**Enforcement**: hook | lint-rule | structural-test | doc-only

### What
[One sentence: what pattern is prohibited]

### Why
[One sentence: why this pattern causes problems]
**Origin**: [brief description of the incident that prompted this rule]

### How to Fix
[Specific, actionable steps — not "use the right approach"]

### Examples

**Bad:**
```[language]
[concrete bad pattern example]
```

**Good:**
```[language]
[concrete correct pattern example]
```

### Detection
[Where enforced: hook filename / lint rule ID / test function name]
```

Assign the next TASTE number by reading the highest existing entry. Never reuse a
number — mark removed rules as `**Status**: Deprecated` instead.

### Step 6: Update Nested CLAUDE.md (if module-specific)

If the rule applies to one specific module:
1. Find or create `[module-dir]/CLAUDE.md`
2. Add to "Module Conventions": one-line summary + link to `docs/LINTING.md#TASTE-NNN`

### Step 7: Verify the Encoding

Before declaring complete:
1. **Positive test**: craft an example of the bad pattern — confirm enforcement catches it
2. **Negative test**: craft the correct version — confirm enforcement does NOT trigger
3. Report both results

## Output

```
=== Encode Mistake ===
Mistake: [brief description]
Type:    [arch-violation|secret-leak|slop|doc-gap|missing-rule|bad-example]
Root cause: [what allowed this to happen]

Encoding chosen: [method] — [one-sentence rationale]

Changes made:
  ✓ hooks/safety-check.sh — added pattern: [description]
  ✓ docs/LINTING.md — TASTE-042: [rule name]
  - [module]/CLAUDE.md — not needed (universal rule)

Verification:
  Positive test (bad pattern detected):  ✓
  Negative test (good pattern allowed):  ✓

Rule: TASTE-042
Prevents: [one sentence]

Future agents will see:
  "[preview of the enforcement error message]"
```

## Rules

- **Always implement mechanically** — a doc rule that isn't enforced will be violated again
- **Follow existing patterns exactly** — in hooks, lint config, and LINTING.md format
- **TASTE numbers are permanent** — never reuse; mark removed rules as Deprecated
- **Test before declaring done** — positive and negative tests are not optional
- **Minimum viable encoding** — start with an improved error message before adding new detection
- **Never weaken existing checks** to reduce noise — fix false positive detection, not threshold
- **Error messages must answer WHAT, WHERE, HOW, REF** — all four, always
- **One mistake = one TASTE rule** — don't bundle unrelated fixes into one encoding
