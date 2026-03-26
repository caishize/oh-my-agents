---
name: unified-review
description: "Orchestrate dual code review: gstack /review (structural PR review) + oh-my-agents /harness-review (four-pillar harness review) in a single pass, producing a unified report with deduplicated findings and combined severity. Aliases: 统一评审, 双重评审, 联合审查, 综合代码审查"
user-invocable: true
argument-hint: "[--branch <branch>] [--plan <plan-id>]"
allowed-tools: Read, Glob, Grep, Bash
---

# Unified Review — Dual-System Code Review Orchestration

Run both gstack's structural review and oh-my-agents' four-pillar review in a single
orchestrated pass. The unified review catches more issues than either system alone:

- **gstack /review**: SQL injection, LLM trust boundaries, scope drift, enum completeness,
  design consistency, Greptile integration, test coverage
- **oh-my-agents /harness-review**: Slop detection (priority 1), layer violations, provider
  bypass, plan alignment, doc drift, entropy indicators

## Task

Perform a unified dual-system review on the current branch changes.

If `$ARGUMENTS` contains `--branch`, review that branch's diff.
If `$ARGUMENTS` contains `--plan`, also check alignment with execution plan.

## Step 0: Prerequisites Check

```bash
# Check gstack availability
GSTACK_PATH=""
for p in "$HOME/.claude/skills/gstack" ".claude/skills/gstack"; do
  [ -d "$p" ] && GSTACK_PATH="$p" && break
done
echo "GSTACK: ${GSTACK_PATH:-not_found}"

# Check current branch
BRANCH=$(git branch --show-current 2>/dev/null)
BASE_BRANCH=$(git rev-parse --abbrev-ref HEAD@{upstream} 2>/dev/null | sed 's|origin/||' || echo "main")
echo "BRANCH: $BRANCH"
echo "BASE: $BASE_BRANCH"

# Get diff stats
DIFF_STAT=$(git diff --stat "$BASE_BRANCH"...HEAD 2>/dev/null || git diff --stat HEAD~1 2>/dev/null)
echo "DIFF_STAT:"
echo "$DIFF_STAT"

# Count changed files
CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null)
echo "CHANGED_FILES:"
echo "$CHANGED_FILES"
```

## Step 1: Phase 1 — Harness Review (oh-my-agents)

Run the four-pillar harness review. This is the oh-my-agents native review:

### 1a: Slop Detection (Priority 1 — "Say No to Slop")

Review every changed file for slop indicators:
- **Vague names**: `data`, `info`, `result`, `temp`, `handle`, `process`, `manager`
- **Magic numbers/strings**: unlabeled constants, hardcoded URLs, raw status codes
- **Dead code**: commented-out blocks, unreachable branches, unused imports
- **Copy-paste**: duplicated logic across files (3+ similar lines)
- **Missing error context**: bare `catch(e)`, generic error messages, swallowed errors
- **Oversized files**: any file exceeding the configured `file_size_limit`
- **Vague comments**: `// fix this`, `// TODO`, `// hack` without explanation

### 1b: Architecture Compliance

Check changed files against the layer model:
- Read `.claude/harness.json` for layer definitions
- For each changed file, resolve its layer
- Check all imports — flag any that cross layer boundaries upward
- Check for direct cross-cutting access (should use Providers)
- Check naming conventions match layer expectations

### 1c: Plan Alignment (if --plan provided)

If a plan ID is given, read the execution plan and verify:
- Are changes implementing tasks in the plan?
- Are there changes NOT covered by any plan task?
- Are plan acceptance criteria met?

### 1d: Documentation Drift

Check if changes require documentation updates:
- New public APIs without doc updates
- Changed behavior without CLAUDE.md updates
- New modules without nested CLAUDE.md

### 1e: Entropy Indicators

Quick entropy scan on changed files:
- File size trends (growing past limits?)
- Import complexity (too many imports?)
- Dependency direction (any new upward dependencies?)

## Step 2: Phase 2 — Structural Review (gstack-delegated or checklist)

**If gstack is installed** (`GSTACK_PATH` is set from Step 0):
Invoke gstack's `/review` skill for the structural pass. gstack's /review performs
deeper structural analysis including Greptile integration, enum completeness checking,
and design consistency validation. Capture its findings and merge them in Step 3.

**If gstack is NOT installed**, apply the structural review checklist manually:

### 2a: Critical Findings (must fix)

1. **Security**: SQL injection, XSS, command injection, hardcoded secrets, LLM trust boundaries
2. **Data integrity**: Race conditions, missing transactions, unvalidated input at boundaries
3. **Breaking changes**: API signature changes, removed fields, changed behavior without migration
4. **Resource leaks**: Unclosed handles, missing cleanup, unbounded growth

### 2b: Informational Findings (should fix)

1. **Error handling**: Missing error cases, generic catches, no retry logic for network calls
2. **Testing gaps**: New code paths without tests, changed behavior without updated tests
3. **Scope drift**: Changes unrelated to the stated purpose (PR title, plan, branch name)
4. **Enum completeness**: Switch/match without exhaustive handling
5. **Naming consistency**: Mixed conventions within the same module
6. **Performance**: O(n²) in hot paths, unnecessary allocations, missing indexes
7. **Accessibility**: Missing ARIA labels, keyboard navigation gaps (if UI)
8. **Documentation**: Stale comments, missing JSDoc/docstrings for public APIs

## Step 3: Deduplicate and Merge

Compare findings from both phases:
- Merge identical findings (same file, same line, same category)
- Keep the more specific description when merging
- Combine severity: if both flag it, escalate severity by one level
- Tag source: `[HARNESS]`, `[STRUCTURAL]`, or `[BOTH]`

## Step 4: Generate Unified Report

```
══════════════════════════════════════════════════════
  Unified Code Review — {BRANCH}
  Reviewed: {file count} files, {line count} lines changed
══════════════════════════════════════════════════════

Summary: {TOTAL} findings ({CRITICAL} critical, {HIGH} high, {MEDIUM} medium, {LOW} low)
  Harness-only:    {count} findings
  Structural-only: {count} findings
  Both systems:    {count} findings (cross-validated)

─── CRITICAL ──────────────────────────────────────
{For each critical finding:}
  [{SOURCE}] {file}:{line} — {description}
    Category: {category}
    Fix: {suggested action}

─── HIGH ──────────────────────────────────────────
{For each high finding:}
  [{SOURCE}] {file}:{line} — {description}
    Category: {category}

─── MEDIUM ─────────────────────────────────────────
{...}

─── LOW ────────────────────────────────────────────
{...}

─── Four Pillars Assessment ────────────────────────
  Architecture:    {PASS/WARN/FAIL} — {1-line summary}
  Documentation:   {PASS/WARN/FAIL} — {1-line summary}
  Observability:   {PASS/WARN/FAIL} — {1-line summary}
  Entropy:         {PASS/WARN/FAIL} — {1-line summary}

─── Scope Check ────────────────────────────────────
  {CLEAN / DRIFT DETECTED / REQUIREMENTS MISSING}
  {If drift: list unrelated changes}

─── Plan Alignment (if applicable) ─────────────────
  Tasks completed:  {N}/{M}
  Acceptance met:   {N}/{M}
  Unplanned changes: {list if any}

─── Recommendations ────────────────────────────────
  1. {Most impactful action}
  2. {Second most impactful}
  3. {Third most impactful}

Verdict: {SHIP IT / FIX AND RESHIP / NEEDS REWORK}
══════════════════════════════════════════════════════
```

## Step 5: Log Review Result

If `.claude/integration.json` exists, log the review result:

```bash
BRANCH=$(git branch --show-current)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mkdir -p .claude/metrics
echo "{\"skill\":\"unified-review\",\"timestamp\":\"$TIMESTAMP\",\"branch\":\"$BRANCH\",\"findings\":{TOTAL},\"critical\":{CRITICAL},\"verdict\":\"{VERDICT}\"}" >> .claude/metrics/reviews.jsonl
```

Also log to gstack's review system if available:

```bash
if [ -n "$GSTACK_PATH" ] && [ -x "$GSTACK_PATH/bin/gstack-review-log" ]; then
  "$GSTACK_PATH/bin/gstack-review-log" \
    --skill unified-review \
    --status "{VERDICT}" \
    --findings "{TOTAL}" \
    --critical "{CRITICAL}" 2>/dev/null || true
fi
```

## Rules

- **Read-only** — this skill never modifies source code; it only reports findings
- **Slop is priority 1** — always check slop before anything else (OpenAI principle)
- **Deduplicate, don't duplicate** — merged findings appear once with combined source tags
- **Cross-validation escalates** — when both systems flag the same issue, it's more certain
- **Graceful without gstack** — structural review categories still apply without gstack installed
- **Log to both systems** — metrics go to oh-my-agents JSONL and gstack review log (if available)
- **Verdict is actionable** — SHIP IT / FIX AND RESHIP / NEEDS REWORK, never ambiguous
