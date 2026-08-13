---
name: verify
description: "Post-execution verification — runs build, test, lint, and architecture checks, then writes a GREEN/YELLOW/RED decision signal (.claude/signals/verify-latest.json) that /lifecycle routes on and the pre-ship convention checks. Implements the Verify phase of Research→Plan→Execute→Verify. Use after completing a task before /harness-review. Aliases: 验证, 验收, 构建检查, 测试验证, 全量检查"
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
load the task acceptance criteria for verification mapping. If `--plan` is OMITTED,
auto-detect: glob `docs/exec-plans/active/*.json` — exactly ONE match ⇒ use it as the
plan; zero or >1 matches ⇒ skip plan mapping with a one-line note (graceful).

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

### Step 3: Enforce Plan Acceptance Criteria (sprint contract — GATING, not reporting)

For each task in the plan with status `in_progress` or `done`:
- Read the task's `acceptance` (a runnable command or named test — the plan schema
  forbids prose)
- RUN it (or map it to a check result already produced in Step 2)
- **Gate rule (fail-any, no averaging — see the fence in docs/SIGNALS.md):** any `done`
  task whose acceptance criterion fails, or cannot be confirmed by running it, **caps the
  decision at `YELLOW`** with reason `acceptance unconfirmed: <task-id>`. RED conditions
  are unchanged; a cap never upgrades a RED.

### Step 3b: Write the Decision Signal + History Log (mandatory)

Verify is a **gate**: downstream consumers (`/lifecycle`, the pre-`/ship` convention
check, Dynamic Workflow stages, Agent Teams) read the outcome without re-deriving it
from raw output. After the Step 2 checks complete, compute the overall **decision** and write the
canonical signal.

> **Contract: [docs/SIGNALS.md](../../docs/SIGNALS.md) is the source of truth** for both
> signals — `schema_version`, enum stability (append-only), the ≤500-byte cap, the
> default-deny rule (missing/malformed/unknown-version ⇒ `RED`), and the consumer list.
> Conform to it; do not restate it.

Decision from the check results:

- **GREEN** — every in-scope check PASS (WARN allowed) AND no acceptance cap (Step 3)
- **YELLOW** — no FAIL, but at least one WARN — or a `done` task's acceptance is
  unconfirmed (contract-unmet cap; fail-any, no averaging)
- **RED** — any in-scope check FAILED

```bash
mkdir -p .claude/signals .claude/metrics
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)
BRANCH=$(git branch --show-current 2>/dev/null || echo unknown)
COMMIT=$(git rev-parse HEAD 2>/dev/null || echo unknown)   # freshness predicate stamp
# Compute DECISION (GREEN|YELLOW|RED), per-check LINT/BUILD/TEST/ARCH (PASS|FAIL|WARN|SKIP),
# PLAN_ID (from --plan or auto-detected, else null), and REASON (≤120 chars).
# first_pass = true when no prior RED exists for this plan/branch in verify.jsonl
# during the current plan cycle (grep verify.jsonl before writing).
# Build the JSON with python3 / jq / printf for correct escaping — never an
# unquoted heredoc with literal placeholders. Include "commit": "$COMMIT".
```

**Canonical signal** — `.claude/signals/verify-latest.json` (latest only, ≤500 bytes).
The full schema lives in **docs/SIGNALS.md — do not restate it**. Verify-specific notes:
`scope` mirrors `$ARGUMENTS`; `first_pass` is computed from `verify.jsonl` history;
`commit` = HEAD at derivation time (freshness predicate); `reason` names the first
blocking item (e.g. `3 tests failed`, `acceptance unconfirmed: task-3`).

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
  `schema_version` + `decision` + `commit`) is mandatory, even on early exit. It is the
  Gate API per docs/SIGNALS.md; consumers default-deny a missing/stale/unknown-version
  signal. The ship gate is an OUR-SIDE convention (docs/SIGNALS.md pre-ship check) — no
  doc may claim gstack reads this signal as verified fact.
- **Log results for cross-system use** — append each run to `.claude/metrics/verify.jsonl`
  so both `/harness-dashboard` (first-pass-GREEN, verify→review) and recurring-failure
  detection can reference them; the signal is latest-only, the jsonl is history
