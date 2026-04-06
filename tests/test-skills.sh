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
    if [ "$LINE_COUNT" -le 900 ]; then
        PASS=$((PASS + 1))
        echo "PASS: size: $skill ($LINE_COUNT lines <= 900)"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: size: $skill ($LINE_COUNT lines > 900 limit)"
    fi
done

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
