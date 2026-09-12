#!/usr/bin/env bash
#
# Smoke tests for oh-my-agents skills.
# Validates skill frontmatter, required fields, file sizes, and structural integrity.
# Run: bash tests/test-skills.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../skills"

PASS=0
FAIL=0
TOTAL=0

# --- Test harness ---

assert_true() {
    local name="$1"
    local condition="$2"
    TOTAL=$((TOTAL + 1))
    if eval "$condition"; then
        PASS=$((PASS + 1))
        echo "PASS: $name"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $name"
    fi
}

assert_contains() {
    local name="$1"
    local file="$2"
    local pattern="$3"
    TOTAL=$((TOTAL + 1))
    if grep -qE "$pattern" "$file" 2>/dev/null; then
        PASS=$((PASS + 1))
        echo "PASS: $name"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $name (pattern not found: $pattern)"
    fi
}

echo "=== oh-my-agents Skill Tests ==="
echo ""

# --- Required skills ---
EXPECTED_SKILLS="harness-init legibility-score spec-to-task verify encode-mistake arch-guard entropy-sweep harness-review harness-dashboard gstack-sync lifecycle"

echo "--- Skill existence ---"
for skill in $EXPECTED_SKILLS; do
    assert_true "skill exists: $skill" "[ -f '${SKILLS_DIR}/${skill}/SKILL.md' ]"
done

# --- Frontmatter validation ---
echo ""
echo "--- Frontmatter required fields ---"

for skill in $EXPECTED_SKILLS; do
    SKILL_FILE="${SKILLS_DIR}/${skill}/SKILL.md"
    [ ! -f "$SKILL_FILE" ] && continue

    # Required fields
    assert_contains "frontmatter: $skill has name" "$SKILL_FILE" "^name:"
    assert_contains "frontmatter: $skill has description" "$SKILL_FILE" "^description:"
    assert_contains "frontmatter: $skill has user-invocable" "$SKILL_FILE" "^user-invocable:"
    assert_contains "frontmatter: $skill has argument-hint" "$SKILL_FILE" "^argument-hint:"
    assert_contains "frontmatter: $skill has allowed-tools" "$SKILL_FILE" "^allowed-tools:"
done

# --- File size check ---
echo ""
echo "--- File size limits ---"

for skill in $EXPECTED_SKILLS; do
    SKILL_FILE="${SKILLS_DIR}/${skill}/SKILL.md"
    [ ! -f "$SKILL_FILE" ] && continue
    LINE_COUNT=$(wc -l < "$SKILL_FILE" | tr -d ' ')
    TOTAL=$((TOTAL + 1))
    if [ "$LINE_COUNT" -le 400 ]; then
        PASS=$((PASS + 1))
        echo "PASS: size: $skill ($LINE_COUNT lines <= 400, rule skill-line-cap)"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: size: $skill ($LINE_COUNT lines > 400 — rule skill-line-cap)"
    fi
done

# Root CLAUDE.md ≤ 60 lines (rule skill-line-cap, root clause — the cap drifted to 69 while
# it lived only inside the file it governs; evidence: ETH Zurich 2602.11988, HumanLayer <60)
ROOT_CLAUDE="${SCRIPT_DIR}/../CLAUDE.md"
TOTAL=$((TOTAL + 1))
ROOT_LINES=$(wc -l < "$ROOT_CLAUDE" | tr -d ' ')
if [ "$ROOT_LINES" -le 60 ]; then
    PASS=$((PASS + 1)); echo "PASS: size: root CLAUDE.md ($ROOT_LINES lines <= 60)"
else
    FAIL=$((FAIL + 1)); echo "FAIL: size: root CLAUDE.md ($ROOT_LINES lines > 60 — rule skill-line-cap)"
fi

# --- Description quality ---
echo ""
echo "--- Description quality ---"

for skill in $EXPECTED_SKILLS; do
    SKILL_FILE="${SKILLS_DIR}/${skill}/SKILL.md"
    [ ! -f "$SKILL_FILE" ] && continue

    # Description should include Chinese aliases for i18n support
    # Note: grep -P for Unicode not available on macOS; check for "Aliases:" keyword instead
    assert_contains "i18n: $skill has aliases" "$SKILL_FILE" "Aliases:"

    # Description should be under 500 chars (for context window efficiency)
    DESC_LEN=$(grep "^description:" "$SKILL_FILE" | head -1 | wc -c | tr -d ' ')
    TOTAL=$((TOTAL + 1))
    if [ "$DESC_LEN" -le 500 ]; then
        PASS=$((PASS + 1))
        echo "PASS: desc-len: $skill ($DESC_LEN chars <= 500)"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: desc-len: $skill ($DESC_LEN chars > 500 limit)"
    fi
done

# --- Structural checks ---
echo ""
echo "--- Structural integrity ---"

# Verify YAML frontmatter is properly closed (starts and ends with ---)
for skill in $EXPECTED_SKILLS; do
    SKILL_FILE="${SKILLS_DIR}/${skill}/SKILL.md"
    [ ! -f "$SKILL_FILE" ] && continue
    TOTAL=$((TOTAL + 1))
    FENCE_COUNT=$(head -10 "$SKILL_FILE" | grep -c "^---$" || true)
    if [ "$FENCE_COUNT" -ge 2 ]; then
        PASS=$((PASS + 1))
        echo "PASS: yaml-fenced: $skill"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: yaml-fenced: $skill (found $FENCE_COUNT --- markers, expected 2)"
    fi
done

# Verify each skill has a task instruction (## Task, ## Arguments, or ## The N Metrics)
for skill in $EXPECTED_SKILLS; do
    SKILL_FILE="${SKILLS_DIR}/${skill}/SKILL.md"
    [ ! -f "$SKILL_FILE" ] && continue
    assert_contains "has-task-section: $skill" "$SKILL_FILE" "^## (Task|Arguments|The [0-9]+ Metrics)"
done

# --- Cross-reference checks ---
echo ""
echo "--- Cross-references ---"

# Verify CLAUDE.md lists all skills
CLAUDE_MD="${SCRIPT_DIR}/../CLAUDE.md"
if [ -f "$CLAUDE_MD" ]; then
    for skill in $EXPECTED_SKILLS; do
        assert_contains "CLAUDE.md mentions: $skill" "$CLAUDE_MD" "$skill"
    done
fi

# --- Gate API contract (docs/SIGNALS.md) ---
echo ""
echo "--- Gate API contract ---"

SIGNALS_MD="${SCRIPT_DIR}/../docs/SIGNALS.md"
assert_true "docs/SIGNALS.md exists" "[ -f '$SIGNALS_MD' ]"

if [ -f "$SIGNALS_MD" ]; then
    # Enum stability is append-only: every current enum value MUST stay documented.
    # If someone removes or repurposes one, this fails (the regression guard).
    assert_contains "SIGNALS: schema_version documented" "$SIGNALS_MD" "schema_version"
    assert_contains "SIGNALS: verify enum GREEN" "$SIGNALS_MD" "GREEN"
    assert_contains "SIGNALS: verify enum YELLOW" "$SIGNALS_MD" "YELLOW"
    assert_contains "SIGNALS: verify enum RED" "$SIGNALS_MD" "RED"
    assert_contains "SIGNALS: review enum APPROVE" "$SIGNALS_MD" "APPROVE"
    assert_contains "SIGNALS: review enum REQUEST_CHANGES" "$SIGNALS_MD" "REQUEST_CHANGES"
    assert_contains "SIGNALS: review enum NEEDS_HUMAN" "$SIGNALS_MD" "NEEDS_HUMAN"
    assert_contains "SIGNALS: needs_human_kind composition-skipped" "$SIGNALS_MD" "composition-skipped"
    assert_contains "SIGNALS: needs_human_kind arch-ambiguity" "$SIGNALS_MD" "arch-ambiguity"
    assert_contains "SIGNALS: needs_human_kind judgment-slop" "$SIGNALS_MD" "judgment-slop"
    assert_contains "SIGNALS: default-deny rule stated" "$SIGNALS_MD" "[Dd]efault-deny"
fi

# Producers must carry schema_version and reference the single source of truth.
VERIFY_MD="${SKILLS_DIR}/verify/SKILL.md"
REVIEW_MD="${SKILLS_DIR}/harness-review/SKILL.md"
assert_contains "verify writes schema_version" "$VERIFY_MD" "schema_version"
assert_contains "verify references SIGNALS.md" "$VERIFY_MD" "SIGNALS.md"
assert_contains "harness-review writes schema_version" "$REVIEW_MD" "schema_version"
assert_contains "harness-review references SIGNALS.md" "$REVIEW_MD" "SIGNALS.md"
assert_contains "harness-review sets needs_human_kind" "$REVIEW_MD" "needs_human_kind"

# --- Dynamic Workflows (anti-bloat rule single-workflow) ---
echo ""
echo "--- Workflows (rule single-workflow) ---"

# v3.11.0: the workflow lives at the PLUGIN ROOT `workflows/` (the platform's default, no manifest
# field) ⇒ /oh-my-agents:harness-audit on every install. A plugin's `.claude/workflows/` is never
# scanned by the platform, and a copy there could never silently become workflow #2.
WF_DIR="${SCRIPT_DIR}/../workflows"
WF_COUNT=$(ls "$WF_DIR"/*.js 2>/dev/null | wc -l | tr -d ' ')
TOTAL=$((TOTAL + 1))
if [ "$WF_COUNT" -le 1 ] && [ "$WF_COUNT" -ge 1 ]; then
    PASS=$((PASS + 1)); echo "PASS: single-workflow cap: $WF_COUNT workflow(s) at the plugin root (<= 1)"
else
    FAIL=$((FAIL + 1)); echo "FAIL: single-workflow cap: $WF_COUNT workflows at workflows/ (expected exactly 1)"
fi
assert_true "single-workflow: no .claude/workflows/ directory (moved to the plugin root v3.11.0)" \
    "[ ! -d '${SCRIPT_DIR}/../.claude/workflows' ]"
assert_true "plugin.json: no workflows field (the default workflows/ dir is scanned without it)" \
    "! grep -q '\"workflows\"' '${SCRIPT_DIR}/../.claude-plugin/plugin.json'"

AUDIT_WF="${WF_DIR}/harness-audit.js"
if [ -f "$AUDIT_WF" ]; then
    assert_contains "single-workflow: harness-audit keeps its meta.name" "$AUDIT_WF" "name: 'harness-audit'"
    # Read-only guarantee: audit/verify agents must use the Explore agentType.
    assert_contains "single-workflow: harness-audit uses Explore agents" "$AUDIT_WF" "agentType: 'Explore'"
    # No delivery orchestration / mutation (SIGNAL-not-ARTIFACT bright line).
    for forbidden in "git commit" "git push" "/ship" "/land-and-deploy" "/canary"; do
        TOTAL=$((TOTAL + 1))
        if grep -qF "$forbidden" "$AUDIT_WF" 2>/dev/null; then
            FAIL=$((FAIL + 1)); echo "FAIL: single-workflow no-delivery: harness-audit references '$forbidden'"
        else
            PASS=$((PASS + 1)); echo "PASS: single-workflow no-delivery: harness-audit free of '$forbidden'"
        fi
    done
    # Accountable-writer: the workflow RETURNS a signal rather than relay-writing it.
    assert_contains "single-workflow: harness-audit returns a signal" "$AUDIT_WF" "return \{"
fi

# --- v3.9.0: shared gstack_detect() usable from skill context (item: dedupe) ---
echo ""
echo "--- hooks/lib/common.sh gstack_detect() ---"

COMMON_SH="${SCRIPT_DIR}/../hooks/lib/common.sh"
TOTAL=$((TOTAL + 1))
if OUT=$(bash -c "set -u; source '$COMMON_SH'; gstack_detect || true; echo \"SLUG=\$SLUG GSTACK=\${GSTACK_PATH:-none} PROJ=\${GSTACK_PROJECTS:-none}\"" 2>&1); then
    if echo "$OUT" | grep -q "SLUG="; then
        PASS=$((PASS + 1)); echo "PASS: gstack_detect() sources and sets SLUG/GSTACK_PATH/GSTACK_PROJECTS ($OUT)"
    else
        FAIL=$((FAIL + 1)); echo "FAIL: gstack_detect() ran but vars missing: $OUT"
    fi
else
    FAIL=$((FAIL + 1)); echo "FAIL: gstack_detect() errored: $OUT"
fi

# CLAUDE_PLUGIN_ROOT unset must not break the documented two-line snippet pattern
TOTAL=$((TOTAL + 1))
if bash -c "set -u; unset CLAUDE_PLUGIN_ROOT 2>/dev/null; source '$COMMON_SH'; gstack_detect || true" >/dev/null 2>&1; then
    PASS=$((PASS + 1)); echo "PASS: gstack_detect() safe with CLAUDE_PLUGIN_ROOT unset"
else
    FAIL=$((FAIL + 1)); echo "FAIL: gstack_detect() breaks with CLAUDE_PLUGIN_ROOT unset"
fi

# Exactly ONE detection implementation: no skill may keep its own gstack dir-probe loop
TOTAL=$((TOTAL + 1))
STRAY=$(grep -rln 'for p in .*skills/gstack' "${SCRIPT_DIR}/../skills" 2>/dev/null || true)
if [ -z "$STRAY" ]; then
    PASS=$((PASS + 1)); echo "PASS: no stray gstack detection loops in skills/"
else
    FAIL=$((FAIL + 1)); echo "FAIL: stray gstack detection in: $STRAY"
fi

# No skill may create or write a `.claude/` path relative to the shell cwd — a build step
# may have left the session in a subdirectory, and a signal or metric written there is one
# the Stop hook and /harness-dashboard never find (issue #22, write side).
TOTAL=$((TOTAL + 1))
BARE=$(grep -rn "mkdir -p \.claude\|open('\.claude/\|open(\"\.claude/\|>> \.claude/" \
    "${SCRIPT_DIR}/../skills" 2>/dev/null || true)
if [ -z "$BARE" ]; then
    PASS=$((PASS + 1)); echo "PASS: no skill writes a cwd-relative .claude/ path"
else
    FAIL=$((FAIL + 1)); echo "FAIL: cwd-relative .claude/ write in: $BARE"
fi

# Every skill that writes into `.claude/` anchors on harness_root() from the shared lib.
TOTAL=$((TOTAL + 1))
UNANCHORED=""
for sk in verify harness-review entropy-sweep legibility-score; do
    f="${SCRIPT_DIR}/../skills/${sk}/SKILL.md"
    [ -f "$f" ] || continue
    grep -q 'harness_root' "$f" || UNANCHORED="${UNANCHORED} ${sk}"
done
if [ -z "$UNANCHORED" ]; then
    PASS=$((PASS + 1)); echo "PASS: signal/metric writers anchor on harness_root()"
else
    FAIL=$((FAIL + 1)); echo "FAIL: writers not anchored:$UNANCHORED"
fi

# =============================================
# v3.10.0 — constitution enforced in CI (docs/TEAM-DISCUSSION-2026-09-04.md)
# =============================================

echo ""
echo "--- v3.10.0: history writer, slug identity, declared artifacts, anti-regression ---"

# append_history_record: one tested writer for verify.jsonl / reviews.jsonl (rule one-writer)
AHR_TMP=$(mktemp -d)
TOTAL=$((TOTAL + 1))
if bash -c "source '$COMMON_SH'; append_history_record '$AHR_TMP/m' verify.jsonl '{\"decision\":\"GREEN\",\"reason\":\"ok\"}'" 2>/dev/null \
   && [ "$(wc -l < "$AHR_TMP/m/verify.jsonl" | tr -d ' ')" = "1" ] \
   && python3 -m json.tool "$AHR_TMP/m/verify.jsonl" >/dev/null 2>&1; then
    PASS=$((PASS + 1)); echo "PASS: append_history_record writes exactly one valid JSONL line"
else
    FAIL=$((FAIL + 1)); echo "FAIL: append_history_record writes exactly one valid JSONL line"
fi
TOTAL=$((TOTAL + 1))
if ! bash -c "source '$COMMON_SH'; append_history_record '$AHR_TMP/m' verify.jsonl 'not json'" 2>/dev/null \
   && [ "$(wc -l < "$AHR_TMP/m/verify.jsonl" | tr -d ' ')" = "1" ]; then
    PASS=$((PASS + 1)); echo "PASS: append_history_record refuses invalid JSON (LOUD, nothing appended)"
else
    FAIL=$((FAIL + 1)); echo "FAIL: append_history_record refuses invalid JSON"
fi
rm -rf "$AHR_TMP"

# Slug identity: gstack-slug prints `SLUG=…` + `BRANCH=…` — only the SLUG= line is the slug,
# and GSTACK_PROJECTS resolves under $GSTACK_HOME/projects/<slug> ({SLUG} templated).
SLUG_TMP=$(mktemp -d)
mkdir -p "$SLUG_TMP/gs/bin"
printf '#!/bin/sh\necho "SLUG=owner-repo"\necho "BRANCH=main"\n' > "$SLUG_TMP/gs/bin/gstack-slug"
chmod +x "$SLUG_TMP/gs/bin/gstack-slug"
TOTAL=$((TOTAL + 1))
SLUG_OUT=$(bash -c "set -u; source '$COMMON_SH'; GSTACK_PATH='$SLUG_TMP/gs'; unset GSTACK_PROJECT_SLUG; resolve_project_slug; GSTACK_HOME='$SLUG_TMP/home' resolve_gstack_paths; printf '%s|%s' \"\$PROJECT_SLUG\" \"\$GSTACK_PROJECTS\"" 2>/dev/null || echo "")
if [ "$SLUG_OUT" = "owner-repo|$SLUG_TMP/home/projects/owner-repo" ]; then
    PASS=$((PASS + 1)); echo "PASS: slug identity: SLUG= line parsed, GSTACK_HOME honored, {SLUG} templated ($SLUG_OUT)"
else
    FAIL=$((FAIL + 1)); echo "FAIL: slug identity: got '$SLUG_OUT'"
fi
TOTAL=$((TOTAL + 1))
if bash -c "set -u; source '$COMMON_SH'; GSTACK_PROJECT_SLUG=env-slug resolve_project_slug; [ \"\$PROJECT_SLUG\" = env-slug ]" 2>/dev/null; then
    PASS=$((PASS + 1)); echo "PASS: slug identity: GSTACK_PROJECT_SLUG env override wins"
else
    FAIL=$((FAIL + 1)); echo "FAIL: slug identity: GSTACK_PROJECT_SLUG env override"
fi
rm -rf "$SLUG_TMP"

INTEGRATION_JSON="${SCRIPT_DIR}/../.claude/integration.json"
INTEGRATION_MD="${SCRIPT_DIR}/../docs/INTEGRATION.md"
TOTAL=$((TOTAL + 1))
if ! grep -q 'projects/oh-my-agents' "$INTEGRATION_JSON" && grep -q '{SLUG}' "$INTEGRATION_JSON"; then
    PASS=$((PASS + 1)); echo "PASS: integration.json bridges are {SLUG}-templated (no baked literal slug)"
else
    FAIL=$((FAIL + 1)); echo "FAIL: integration.json carries a literal slug or no {SLUG} placeholder"
fi

# Rule declared-artifact: every .claude/metrics|signals basename a hook or skill writes must
# be declared in docs/INTEGRATION.md (bridge table) or .claude/integration.json bridges —
# or listed here as write-only-by-design WITH a reason. The failure message IS the rule.
WRITE_ONLY_BY_DESIGN="investigations.jsonl"   # encode provenance ledger, read only by --from-investigation (declared too)
TOTAL=$((TOTAL + 1))
UNDECLARED=""
for name in $(grep -rhoE '\.claude/(metrics|signals)/[A-Za-z0-9_.*<>{}$-]+\.(json|jsonl)' "${SCRIPT_DIR}/../hooks" "${SCRIPT_DIR}/../skills" 2>/dev/null \
              | sed -E 's#.*/##' | sort -u); do
    stem=$(printf '%s' "$name" | sed -E 's/[-*<>{}$].*//')   # session-<date>.jsonl -> session ; verify.jsonl -> verify.jsonl
    if grep -qF "$name" "$INTEGRATION_MD" "$INTEGRATION_JSON" 2>/dev/null \
       || { [ -n "$stem" ] && grep -qE "$stem[-*]" "$INTEGRATION_MD" "$INTEGRATION_JSON" 2>/dev/null; } \
       || printf '%s' " $WRITE_ONLY_BY_DESIGN " | grep -qF " $name "; then
        continue
    fi
    UNDECLARED="${UNDECLARED} ${name}"
done
if [ -z "$UNDECLARED" ]; then
    PASS=$((PASS + 1)); echo "PASS: declared-artifact: every written .claude/metrics|signals file names its reader"
else
    FAIL=$((FAIL + 1)); echo "FAIL: declared-artifact: undeclared artifact(s):$UNDECLARED — declare the consumer in docs/INTEGRATION.md or add to WRITE_ONLY_BY_DESIGN with a reason"
fi

# Anti-regression greps: gstack shapes VERIFIED dead at v1.79 (docs/TEAM-DISCUSSION-2026-09-04.md)
# must not reappear in code or the bridge manifest. Council minutes are history, not surface.
echo "--- v3.10.0: dead gstack shapes (verified against v1.79 source) ---"
# v3.11.0 additions: the top-level `*-spec-*.md` glob (gstack /spec archives to projects/<slug>/specs/),
# and the hook_results / hook_durations / blocked_by sensor (not a PostToolUse input field).
DEAD_PATTERNS='\$HOME/\.gstack-artifacts-worktree|landing-reports/\*\.json|canary-reports/\*\.json|deploy-reports/\*\.json|\*-learnings-\*\.jsonl|learnings-\*\.jsonl|\.get\(.unresolved.|/find-decisions|-spec-\*\.md|hook_results|hook_durations|blocked_by'
for target in "${SCRIPT_DIR}/../skills" "${SCRIPT_DIR}/../hooks" "$INTEGRATION_JSON"; do
    TOTAL=$((TOTAL + 1))
    HITS=$(grep -rnE "$DEAD_PATTERNS" "$target" 2>/dev/null | grep -vE 'never existed|zero hits|CI-grepped|NEVER existed|has ZERO|never probed|deleted in v3\.1[01]|were deleted|never had a producer|DEPRECATED' || true)
    if [ -z "$HITS" ]; then
        PASS=$((PASS + 1)); echo "PASS: no dead gstack shape in $(basename "$target")"
    else
        FAIL=$((FAIL + 1)); echo "FAIL: dead gstack shape reintroduced in $(basename "$target"): $HITS"
    fi
done
TOTAL=$((TOTAL + 1))
if ! grep -qE 'landing-reports/\*\.json|canary-reports/\*\.json|deploy-reports/\*\.json|~/\.gstack-artifacts-worktree/' "$INTEGRATION_MD"; then
    PASS=$((PASS + 1)); echo "PASS: docs/INTEGRATION.md bridge table carries no dead gstack shape"
else
    FAIL=$((FAIL + 1)); echo "FAIL: docs/INTEGRATION.md still declares a dead gstack shape"
fi

# Anti-bloat citations by kebab-case NAME, never number — scoped to code/tests/workflows
echo "--- v3.10.0: rule citations by name ---"
TOTAL=$((TOTAL + 1))
NUMERIC=$(grep -rnE '\b[Rr]ule[- ]?1[0-9]\b|\brule17\b|Rule-17' "${SCRIPT_DIR}/../skills" "${SCRIPT_DIR}/../hooks" "${SCRIPT_DIR}/../tests" "${SCRIPT_DIR}/../workflows" 2>/dev/null | grep -v 'rule citations by name' | grep -v "NUMERIC=" || true)
if [ -z "$NUMERIC" ]; then
    PASS=$((PASS + 1)); echo "PASS: anti-bloat rules cited by kebab-case name in skills/hooks/tests/workflows"
else
    FAIL=$((FAIL + 1)); echo "FAIL: numeric rule citation (cite by kebab-case name): $NUMERIC"
fi

# The one workflow must parse (node) — SKIP, not FAIL, when node is absent
TOTAL=$((TOTAL + 1))
if command -v node >/dev/null 2>&1; then
    if node --check "$AUDIT_WF" 2>/dev/null; then
        PASS=$((PASS + 1)); echo "PASS: harness-audit.js parses (node --check)"
    else
        FAIL=$((FAIL + 1)); echo "FAIL: harness-audit.js does not parse"
    fi
else
    PASS=$((PASS + 1)); echo "SKIP: node not installed — harness-audit.js syntax not checked (counted as pass)"
fi

# BINDING 1 decided 2026-09-11: the NEXT: JSON tail line is RETIRED (zero consumers in two cycles).
TOTAL=$((TOTAL + 1))
if ! grep -q 'NEXT: {' "${SKILLS_DIR}/lifecycle/SKILL.md" "$SIGNALS_MD"; then
    PASS=$((PASS + 1)); echo "PASS: NEXT: tail line retired v3.11.0 (re-add only with a consumer test in the same PR)"
else
    FAIL=$((FAIL + 1)); echo "FAIL: NEXT: tail line re-appeared — re-add only with a consumer test in the same PR"
fi
assert_contains "harness-review: typed findings[] fingerprint documented" "$REVIEW_MD" "fingerprint"
assert_contains "harness-review: decisions.active.json no longer parsed for a count" "$REVIEW_MD" "is NOT read"
assert_contains "verify: history log via append_history_record" "$VERIFY_MD" "append_history_record"
assert_contains "harness-review: history log via append_history_record" "$REVIEW_MD" "append_history_record"
assert_contains "harness-init: gstack verify marker emitted only in the confirmed-command branch" "${SKILLS_DIR}/harness-init/SKILL.md" "human confirms the exact string"
assert_contains "gstack-sync: --metrics deleted" "${SKILLS_DIR}/gstack-sync/SKILL.md" "were deleted in v3.10.0"
TOTAL=$((TOTAL + 1))
if ! grep -q '^argument-hint:.*--metrics' "${SKILLS_DIR}/gstack-sync/SKILL.md"; then
    PASS=$((PASS + 1)); echo "PASS: gstack-sync argument-hint no longer advertises --metrics"
else
    FAIL=$((FAIL + 1)); echo "FAIL: gstack-sync argument-hint still advertises --metrics"
fi
# =============================================
# v3.11.0 — council work items (docs/TEAM-DISCUSSION-2026-09-11.md)
# =============================================
echo "--- v3.11.0: CI runner, typed hand-backs, computed review decision, freshness, bridges ---"
CI_YML=$(ls "${SCRIPT_DIR}"/../.github/workflows/*.yml 2>/dev/null | head -1)
assert_true "ci: a GitHub Actions workflow runs both suites + node --check (the constitution is finally executed)" \
    "[ -n '$CI_YML' ] && grep -q 'tests/test-hooks.sh' '$CI_YML' && grep -q 'tests/test-skills.sh' '$CI_YML' && grep -q 'node --check workflows/harness-audit.js' '$CI_YML'"
assert_contains "verify: typed failures[] hand-back" "$VERIFY_MD" 'failures\[\]'
assert_contains "verify: failures[].task_id names the retry target" "$VERIFY_MD" "task_id"
assert_contains "verify: reason == failures[0].message (one key for sensor + ladder)" "$VERIFY_MD" 'failures\[0\]'
assert_contains "SIGNALS: failures[] documented beside findings[]" "$SIGNALS_MD" 'failures\[\]'
assert_true "verify: prose recurring-failure scan replaced by the typed jq" "! grep -q 'Scan the last 5 entries' '$VERIFY_MD'"
assert_true "harness-review: decision COMPUTED from findings[], separate Explore judge, no stale native claims" \
    "! grep -q 'pick one' '$REVIEW_MD' && grep -qi 'computed' '$REVIEW_MD' && ! grep -q 'runs in THIS context' '$REVIEW_MD' && ! grep -q 'run behavior' '$REVIEW_MD' && ! grep -q 'Skill tool' '$REVIEW_MD'"
assert_contains "harness-review: reads gstack's typed findings tolerantly" "$REVIEW_MD" '\.findings // \[\]'
assert_contains "SIGNALS: signal_fresh is the ONE freshness predicate" "$SIGNALS_MD" "signal_fresh"
assert_contains "verify: wtree stamp gated on git check-ignore" "$VERIFY_MD" "check-ignore"
assert_contains "harness-init: ledger dirs gitignored (signals)" "${SKILLS_DIR}/harness-init/SKILL.md" '\.claude/signals/'
assert_contains "harness-init: ledger dirs gitignored (metrics)" "${SKILLS_DIR}/harness-init/SKILL.md" '\.claude/metrics/'
assert_true "common.sh: no in-tree copy of gstack's write-tree fingerprint recipe" "! grep -q 'write-tree' '$COMMON_SH'"
assert_contains "spec-to-task: reads the /spec archive by spec_branch" "${SKILLS_DIR}/spec-to-task/SKILL.md" "spec_branch"
assert_contains "spec-to-task: specs/ archive path" "${SKILLS_DIR}/spec-to-task/SKILL.md" "specs/"
assert_true "integration.json: gstack re-pinned 1.84.1.0, allow-list bindings, /open-gstack-browser, /guard owned" \
    "grep -q '\"version\": \"1.84.1.0\"' '$INTEGRATION_JSON' && ! grep -q '/connect-chrome' '$INTEGRATION_JSON' && grep -q '/open-gstack-browser' '$INTEGRATION_JSON' && grep -q '\"/guard\"' '$INTEGRATION_JSON' && grep -qi 'allow-list' '$INTEGRATION_JSON'"
assert_true "verify: confirms a deterministic pass (no blanket prohibition; CMDISH + failing_tests + ONE plan write)" \
    "! grep -q 'Do NOT mark individual tasks done' '$VERIFY_MD' && grep -q 'CMDISH' '$VERIFY_MD' && grep -q 'failing_tests' '$VERIFY_MD' && grep -q 'ONE plan' '$VERIFY_MD'"
assert_contains "spec-to-task: defaults to a new plan when a spec is given" "${SKILLS_DIR}/spec-to-task/SKILL.md" "ARGUMENTS.*non-empty"
assert_true "disable-model-invocation on exactly the two one-time setup skills" \
    "grep -q '^disable-model-invocation: true' '${SKILLS_DIR}/harness-init/SKILL.md' && grep -q '^disable-model-invocation: true' '${SKILLS_DIR}/gstack-sync/SKILL.md' && [ \$(grep -l '^disable-model-invocation: true' '${SKILLS_DIR}'/*/SKILL.md | wc -l) -eq 2 ]"
DASH_MD="${SKILLS_DIR}/harness-dashboard/SKILL.md"; DEEP_MD="${SKILLS_DIR}/harness-dashboard/DEEP-DIVE.md"
assert_true "dashboard: no row without a file source (Gate-block/Eureka/Enforcement/violations gone; both DORA proxies kept)" \
    "! grep -qE 'Gate-block|Eureka|### Enforcement|query violations' '$DASH_MD' '$DEEP_MD' && grep -q 'change_failure_rate' '$DASH_MD' && grep -q 'deployment_frequency' '$DASH_MD'"
assert_true "no skill reads Bash-leg session lines" "! grep -rq '\"tool\":\"Bash\"' '${SKILLS_DIR}'"
assert_contains "INTEGRATION: self-verify-check retirement recorded under ablate-per-model" "$INTEGRATION_MD" "self-verify-check \\(v3\\.11\\.0"
assert_contains "INTEGRATION: in_progress tolerance sunset FIRED v3.11.0" "$INTEGRATION_MD" "FIRED v3.11.0"
assert_true "gstack-sync: duplicated count probes and verdict tail deleted; verify's readiness rows gone" \
    "! grep -qE 'CAP_CODEX=|CAP_CSO=|REVIEW_VERDICT=' '${SKILLS_DIR}/gstack-sync/SKILL.md' && ! grep -q 'Benchmark baseline' '$VERIFY_MD'"
assert_contains "WORKFLOW: /skill-doctor is the skill-retirement gauge" "${SCRIPT_DIR}/../docs/WORKFLOW.md" "/skill-doctor"
assert_contains "INTEGRATION: claude plugin eval named as the ablation instrument" "$INTEGRATION_MD" "claude plugin eval"
assert_true "integration.json: /skill-doctor no longer called org-gated" "! grep -q 'org-gated' '$INTEGRATION_JSON'"
assert_true "SIGNALS: native TaskCompleted consumer recipe (≤12 lines, no hard-coded gstack path)" \
    "grep -q 'TaskCompleted' '$SIGNALS_MD' && grep -q 'TaskCompleted' '$INTEGRATION_MD' && ! grep -q 'skills/gstack/bin' '$SIGNALS_MD' && [ \$(awk '/^## Native consumers/{f=1;next} f&&/^## /{exit} f' '$SIGNALS_MD' | wc -l) -le 12 ]"
assert_true "harness-init: no generated overview prose (arXiv 2602.11988); confirm before writing" \
    "! grep -q 'Architecture summary' '${SKILLS_DIR}/harness-init/SKILL.md' && ! grep -q 'Common patterns' '${SKILLS_DIR}/harness-init/SKILL.md' && ! grep -q 'Purpose (1-2 sentences)' '${SKILLS_DIR}/harness-init/SKILL.md' && grep -q '2602.11988' '${SKILLS_DIR}/harness-init/SKILL.md' && grep -qi 'confirm before writ' '${SKILLS_DIR}/harness-init/SKILL.md'"
assert_true "hooks.json: timeouts are seconds (every value ≤ 60)" \
    "python3 -c 'import json; h=json.load(open(\"${SCRIPT_DIR}/../hooks/hooks.json\"))[\"hooks\"]; assert all(x.get(\"timeout\",0)<=60 for es in h.values() for e in es for x in e[\"hooks\"])'"

TOTAL=$((TOTAL + 1))
if [ ! -d "${SCRIPT_DIR}/../agents" ]; then
    PASS=$((PASS + 1)); echo "PASS: no agents/ directory (session-observer retired v3.10.0, consume-or-cut)"
else
    FAIL=$((FAIL + 1)); echo "FAIL: agents/ directory exists — an agent needs ≥1 mechanical trigger and ≥1 machine reader"
fi

# =============================================
# Summary
# =============================================

echo ""
echo "=== Results ==="
echo "Total: $TOTAL | Pass: $PASS | Fail: $FAIL"

if [ "$FAIL" -gt 0 ]; then
    echo "FAILED"
    exit 1
else
    echo "ALL PASSED"
    exit 0
fi
