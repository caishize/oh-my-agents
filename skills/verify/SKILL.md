---
name: verify
description: "Post-execution verification — runs build, test, lint, and architecture checks, then writes a GREEN/YELLOW/RED decision signal (.claude/signals/verify-latest.json) that /lifecycle and gstack /ship gate on. Implements the Verify phase of Research→Plan→Execute→Verify. Use after completing a task before /harness-review. Aliases: 验证, 验收, 构建检查, 测试验证, 全量检查"
user-invocable: true
argument-hint: "[scope: all|build|test|lint|arch] [--plan <plan-id>]"
allowed-tools: Read, Glob, Grep, Bash
---

# Verify

Run the full validation suite and report results in structured, agent-readable format.

This implements the **Verify** phase of OpenAI's Research → Plan → Execute → **Verify**
cycle. Verification closes the feedback loop — agents must confirm their own changes work
before requesting review.

> "When the agent struggles, treat it as an environment design problem."
> Persistent failures here are encoding opportunities — run `/encode-mistake` to convert
> them into permanent guardrails.

## Task

Run checks based on scope from `$ARGUMENTS` (default: `all`).

### Step 1: Load Project Config

Read `CLAUDE.md` for entry point commands:
- `build` command — compile/bundle
- `test` command — run test suite
- `lint` command — lint with auto-fix
- `check` command — combined (prefer this if it exists)

Read `.claude/harness.json` for:
- `file_size_limit` — line limit for architecture checks
- `layer_dirs` — directory-to-layer mappings

If `--plan <plan-id>` is given, read `docs/exec-plans/active/<plan-id>.json` to
load the task acceptance criteria for verification mapping.

### Step 2: Run Checks

Run each check for the given scope. Record exit code and output for each.

Result states: **PASS** (exit 0, clean output), **FAIL** (exit non-zero or errors found),
**WARN** (exit 0 but warnings present), **SKIP** (tool not installed or out of scope).

**Scopes:**
- `all` — run all four checks in dependency order (lint → build → test → arch)
- `build` — compile only
- `test` — test suite only
- `lint` — lint and format only
- `arch` — architecture guard only (structural tests or direct file scan)

#### Check 1: Lint & Format (run first — fastest feedback)

```
Run: [lint command from CLAUDE.md]
Expected: Exit 0, zero errors
```

Extract: error count, warning count, specific errors (file:line, rule, message).

#### Check 2: Build

```
Run: [build command from CLAUDE.md]
Expected: Exit 0
```

Extract: error file:line, error type, actionable message.

#### Check 3: Test Suite

```
Run: [test command from CLAUDE.md]
Expected: Exit 0, all tests pass
```

Extract: total/passed/failed/skipped counts, failing test names and messages,
coverage percentage if reported.

#### Check 4: Architecture Guard

If `tests/test_architecture.py` or `tests/architecture.test.ts` exists:
```
Run: pytest tests/test_architecture.py -x -q
  or npx jest tests/architecture.test.ts --passWithNoTests
```

If no test file exists, perform a direct scan of recently modified files:
- File size: check against `file_size_limit` from harness.json (default 300 lines)
- Layer violations: check imports against layer model from harness.json

### Step 3: Map to Plan Acceptance Criteria (if --plan provided)

For each task in the plan with status `in_progress` or `done`:
- Read the task's `acceptance` array
- Map each criterion to the check results (passed/failed)
- Report: which criteria are confirmed met, which are unconfirmed or failing

### Step 3b: Write the Decision Signal + History Log (mandatory)

Verify is a **gate**: downstream consumers (`/lifecycle`, gstack `/ship` pre-flight,
Dynamic Workflow stages, Agent Teams) read the outcome without re-deriving it from raw
output. After the Step 2 checks complete, compute the overall **decision** and write the
canonical signal.

> **Contract: [docs/SIGNALS.md](../../docs/SIGNALS.md) is the source of truth** for both
> signals — `schema_version`, enum stability (append-only), the ≤500-byte cap, the
> default-deny rule (missing/malformed/unknown-version ⇒ `RED`), and the consumer list.
> Conform to it; do not restate it.

Decision from the check results:

- **GREEN** — every in-scope check PASS (WARN allowed)
- **YELLOW** — no FAIL, but at least one WARN
- **RED** — any in-scope check FAILED

```bash
mkdir -p .claude/signals .claude/metrics
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)
BRANCH=$(git branch --show-current 2>/dev/null || echo unknown)
# Compute DECISION (GREEN|YELLOW|RED), per-check LINT/BUILD/TEST/ARCH (PASS|FAIL|WARN|SKIP),
# PLAN_ID (from --plan or null), and REASON (≤120 chars) from Step 2 results.
# first_pass = true when no prior RED exists for this plan/branch in verify.jsonl
# during the current plan cycle (grep verify.jsonl before writing).
# Build the JSON with python3 / jq / printf for correct escaping — never an
# unquoted heredoc with literal placeholders.
```

**Canonical signal** — `.claude/signals/verify-latest.json` (latest only, ≤500 bytes;
full field reference in docs/SIGNALS.md):

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | integer | Contract version — write `1` |
| `timestamp` | string (ISO-8601 UTC) | When verify concluded |
| `decision` | enum | `GREEN` \| `YELLOW` \| `RED` |
| `scope` | string | `all` \| `build` \| `test` \| `lint` \| `arch` |
| `lint` / `build` / `test` / `arch` | enum | `PASS` \| `FAIL` \| `WARN` \| `SKIP` |
| `first_pass` | boolean | GREEN on the first verify for this plan/branch |
| `plan_id` | string \| null | Active exec-plan id, if `--plan` given |
| `branch` | string | Current git branch |
| `reason` | string (≤120 chars) | One-line rationale, e.g. `3 tests failed` |

**History log** — append the same record (plus failing-test names) as one line to
`.claude/metrics/verify.jsonl`. This is the history that recurring-failure detection
(Step 4) and `/harness-dashboard` velocity metrics (first-pass-GREEN rate,
verify→review time) read — both already assume this writer exists.

**gstack readiness (advisory, only if gstack present)**: surface prior-review and QA
presence — and, if gstack v1.57.5+ ships a decision layer, whether
`~/.gstack/projects/<slug>/decisions.active.json` has unresolved decisions — in the report
*text* for `/ship` context. Read-only. Never block on it and never fold it into the
decision signal: verify owns the build/test/lint/arch decision; the review-domain
reconciliation of gstack's verdict belongs to `/harness-review` (docs/SIGNALS.md).

### Step 4: Report Results

```
=== Verify Report ===
Project:   [name from CLAUDE.md]
Scope:     [all|build|test|lint|arch]
Timestamp: [ISO 8601]

┌─────────────────────────────────────────────┐
│ CHECK    STATUS   DETAILS                   │
├─────────────────────────────────────────────┤
│ LINT     PASS     0 errors, 2 warnings      │
│ BUILD    PASS     Compiled in 4.2s          │
│ TEST     FAIL     47 passed, 3 failed       │
│ ARCH     PASS     No violations             │
└─────────────────────────────────────────────┘

Overall: RED (1 check failed)

Issues Found:
  TEST:
    - test_auth_service_creates_user
      AssertionError: expected 201, got 401
      Hint: auth.service.ts:89 — token validation skipped in test setup
    - test_feature_repo_persists_data
      Error: DB connection refused — is the test database running?

[If --plan plan-id provided:]
Plan Acceptance — plan-20260319-auth-feature:
  Task 1 (types):    ✓ lint clean, ✓ test_feature_types passes
  Task 3 (repo):     ✗ test_feature_repo_persists_data FAILING
  Task 4 (service):  ? test_feature_service not yet run

gstack Readiness (if available):
  Review status:     {reviewed / not reviewed}
  QA reports:        {N} available
  Benchmark baseline: {exists / none}

Next Steps:
  [GREEN]  All checks pass. Run /harness-review to complete the cycle.
  [RED]    Fix failing checks before review.
           Priority: lint → build → test → arch

Recurring Failure Detection:
  {Scan the last 5 entries in .claude/metrics/verify.jsonl for the same failing
   test names or error patterns. If a test has failed 2+ times across different
   sessions, flag it as RECURRING and auto-suggest:}
  ⚠ RECURRING: {test_name} has failed {N} times across {N} sessions.
    → If root cause is unclear, run /investigate (gstack) for isolated reproduction.
    → Then run /encode-mistake "{test_name} fails due to {pattern}" to create a permanent guardrail.
  [YELLOW] Warnings present. Review before proceeding.
  [SHIP]   When ready: /ship (gstack) or create PR manually.
```

### Step 5: Update Plan If Completing (if --plan provided)

If ALL tasks in the plan are confirmed done via acceptance criteria, update the plan:
- Set plan `status` from `active` to `completing`
- Update the `updated` timestamp

Do NOT mark individual tasks done automatically — acceptance criteria interpretation
requires human confirmation.

## Rules

- **Run checks in order**: lint → build → test → arch — earlier failures block later checks
  only if they indicate environment problems (e.g., build failure may invalidate test results)
- **Report actual tool output** — include real error messages, not summaries
- **SKIP is only valid** when a tool is genuinely not installed or out of scope
- **Every FAIL must have a next step** — point to the specific file:line or docs/ section
- **Recurring failures = encoding opportunity** — after 2+ sessions of the same failure,
  recommend `/encode-mistake` to convert the pattern into a permanent guardrail
- **Never editorialize** — report what the tools say; don't soften failures
- **Run from project root** — ensure commands run from the directory containing CLAUDE.md
- **gstack readiness is advisory** — emit review/QA/benchmark status for `/ship` consumption
  but never block verify on gstack data; verify is oh-my-agents' domain
- **Always write the decision signal** — `.claude/signals/verify-latest.json` (with
  `schema_version` + `decision`) is mandatory, even on early exit. It is the Gate API per
  docs/SIGNALS.md; consumers default-deny a missing/stale/unknown-version signal.
- **Log results for cross-system use** — append each run to `.claude/metrics/verify.jsonl`
  so both `/harness-dashboard` (first-pass-GREEN, verify→review) and recurring-failure
  detection can reference them; the signal is latest-only, the jsonl is history
