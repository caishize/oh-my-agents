---
name: encode-mistake
description: "Convert agent mistakes or expert preferences into permanent guardrails — lint rules, structural tests, hooks. Two modes: reactive (from failures) and proactive (from patterns you dislike). Aliases: 编码错误, 固化规则, 错误学习, 品味编码, 规则编码"
user-invocable: true
argument-hint: "<description> [--proactive] [--hook-output] [--from-investigation <id>] [--from-gbrain [type] [n]]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Encode Mistake

> "Every agent mistake is an encoding opportunity. Each person's expertise becomes
> a multiplier for the entire team's agent fleet." — Mitchell Hashimoto

Turn failures or expert preferences into permanent guardrails. Two modes:

- **Reactive** (default): A specific failure happened — encode it so it can't recur
- **Proactive** (`--proactive`): You dislike a pattern — encode your taste as enforcement

Both modes produce the same output: a permanent TASTE rule (lint, test, hook, or doc).

## When to Use

- An agent made the same mistake twice despite documentation
- `/verify` shows a recurring test failure across multiple sessions
- `/harness-review` flagged slop that a linter should have caught
- You see a code pattern you dislike and want to prevent it permanently
- A security issue was caught in review that should have been blocked earlier

## Task

Take the description from `$ARGUMENTS` and create a permanent enforcement artifact.

**Flags:**
- `--proactive` — Encode a preference/taste (no failure needed, just a pattern you dislike)
- `--hook-output` — Treat input as raw hook error message
- `--from-investigation <id>` — Auto-populate from gstack `/investigate` artifact in
  `.claude/metrics/investigations.jsonl`
- `--from-gbrain [<type>] [<n>]` — Scan gstack GBrain memory for unencoded
  observations and propose TASTE rules. `type` ∈ {`learning` (default), `eureka`,
  `retro`, `all`}; `n` defaults to 5. See **Step 0** below.
- `--from-gstack-learnings [<n>]` — Deprecated alias for `--from-gbrain learning [<n>]`,
  kept for backward compatibility.

### Step 0 (optional): Ingest from gstack GBrain memory

When invoked with `--from-gbrain` (or its deprecated alias `--from-gstack-learnings`),
surface the most recent unencoded *observations* from gstack and turn each into a
candidate TASTE rule. gstack writes *observations* (what happened), this skill writes
*enforcement* (what cannot happen again) — two distinct layers; never collapse them.

> **"taste" is an overloaded word — keep the two senses apart.** gstack's
> `gstack-taste-update` learns *soft, decaying design preferences* (≈5%/week half-life)
> — that is the **observation** layer. The harness `TASTE-NNN` rule is a *permanent,
> human-gated, mechanical guardrail* — the **enforcement** layer. They are not the same
> thing and must never be equated in logs or prose: gstack-taste is a candidate *feed*
> for a harness TASTE-NNN rule, the way any observation feeds enforcement. The grep
> token `TASTE-NNN` stays distinct; the hazard is purely in human/agent wording.

**Source priority** (capability-first, glob-fallback):

1. **`gbrain` CLI present** (v1.26+) → `gbrain search --type <type> --since 30d --limit <n>`
   gives federated, queryable results across machines.
2. **GBrain worktree present** → `tail` the matching JSONL at `~/.gstack-artifacts-worktree/`
   (current path only; legacy `gstack-brain*` dropped in the v3.6.0 sunset).
3. **Per-project log fallback** → `~/.gstack/projects/$SLUG/*-learnings-*.jsonl`.
4. **None** → print "no gbrain source available; skip" and exit 0 (graceful).

**Argument parsing**: from `$ARGUMENTS`, extract the token after `--from-gbrain`
as `TYPE` (default `learning`), and the next token as `LIMIT` (default `5`).
The deprecated alias `--from-gstack-learnings <n>` sets `TYPE=learning, LIMIT=<n>`.

```bash
SLUG=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null || echo "unknown")
TYPE="${TYPE:-learning}"       # learning | eureka | retro | all (set by parsing above)
LIMIT="${LIMIT:-5}"
PROJ_DIR="$HOME/.gstack/projects/$SLUG"

# GBrain worktree — current path only (legacy gstack-brain* sunset in v3.6.0).
GBRAIN_WT=""
[ -d "$HOME/.gstack-artifacts-worktree" ] && GBRAIN_WT="$HOME/.gstack-artifacts-worktree"

# Prefer CLI when present (v1.26+).
if command -v gbrain >/dev/null 2>&1; then
  if [ "$TYPE" = "all" ]; then
    gbrain search --since 30d --limit "$LIMIT" 2>/dev/null
  else
    gbrain search --type "$TYPE" --since 30d --limit "$LIMIT" 2>/dev/null
  fi
elif [ -n "$GBRAIN_WT" ]; then
  case "$TYPE" in
    learning) PATTERN="learnings-*.jsonl" ;;
    eureka)   PATTERN="eureka-*.jsonl" ;;
    retro)    PATTERN="retro-*.jsonl" ;;
    all)      PATTERN="*-*.jsonl" ;;
    *)        PATTERN="learnings-*.jsonl" ;;
  esac
  LOG=$(ls -t $GBRAIN_WT/$PATTERN 2>/dev/null | head -1)
  [ -n "$LOG" ] && tail -200 "$LOG" | grep -v '"taste_id"' | tail -"$LIMIT"
elif [ "$TYPE" = "learning" ] && [ -d "$PROJ_DIR" ]; then
  LOG=$(ls -t $PROJ_DIR/*-learnings-*.jsonl 2>/dev/null | head -1)
  [ -n "$LOG" ] && tail -200 "$LOG" | grep -v '"taste_id"' | tail -"$LIMIT"
else
  echo "No gbrain source available — skipping ingest"
fi
```

For each candidate observation, propose a TASTE rule (Steps 1–7 below) and **always
ask the user to confirm before writing files** — auto-generation has been shown to
hurt agent performance (ETH Zurich, 2026). **Never modify the source log** — it is a
read-only sensor. After encoding, record `taste_id: TASTE-NNN` in the LINTING.md
entry's "Origin" field to make the link traceable, but do not write back to gbrain.

### Step 1: Understand the Pattern

**Reactive mode** (default): Parse the failure — what bad pattern occurred, what should
have happened instead, has it happened before?

**Proactive mode** (`--proactive`): Parse the preference — what code pattern do you
dislike, what's the preferred alternative, why does it matter?

Ask clarifying questions if needed:
1. **Bad pattern** — Show an example of what's wrong or disliked
2. **Good pattern** — Show the preferred alternative
3. **Why it matters** — observability, consistency, performance, security
4. **Severity** — Error (block), warning (flag), or info (suggest)

Classify the type:
- `arch-violation` — layer boundary crossed or Providers bypassed
- `secret-leak` — hardcoded credential or token
- `slop` — duplicate logic, copy-paste artifact, over-engineering
- `doc-gap` — rule in docs but not mechanically enforced
- `missing-rule` — pattern never documented or enforced
- `taste` — expert preference not yet encoded (proactive mode)

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
- **Log investigations** — when used with `/investigate`, write structured results to
  `.claude/metrics/investigations.jsonl` with fields: `id`, `timestamp`, `error`,
  `root_cause`, `files_involved`, `suggested_rule`, `encoded` (true/false). This enables
  the investigate-to-encode artifact handoff and dashboard tracking of encode rates.
- **Auto-scan on improve** — `/lifecycle improve` should scan `investigations.jsonl` for
  entries where `encoded` is false and suggest encoding each one
- **Proactive mode is equally valid** — encoding expert taste before failures occur is
  more efficient than waiting for mistakes; use `--proactive` for preemptive encoding
