#!/usr/bin/env bash
#
# Unit tests for oh-my-agents hooks.
# Run: bash tests/test-hooks.sh
#
# Uses a minimal test harness — no external dependencies required.
# Each test feeds JSON input to a hook on stdin and checks the exit code.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="${SCRIPT_DIR}/../hooks"

PASS=0
FAIL=0
TOTAL=0

# --- Test harness ---

run_test() {
    local name="$1"
    local hook="$2"
    local input="$3"
    local expected_exit="$4"
    local expected_stderr_pattern="${5:-}"

    TOTAL=$((TOTAL + 1))

    local actual_exit=0
    local stderr_output
    stderr_output=$(echo "$input" | bash "$HOOKS_DIR/$hook" 2>&1 >/dev/null) || actual_exit=$?

    if [ "$actual_exit" != "$expected_exit" ]; then
        FAIL=$((FAIL + 1))
        echo "FAIL: $name"
        echo "  Expected exit $expected_exit, got $actual_exit"
        echo "  Stderr: $stderr_output"
        return
    fi

    if [ -n "$expected_stderr_pattern" ] && [ "$expected_exit" = "2" ]; then
        if ! echo "$stderr_output" | grep -qE "$expected_stderr_pattern"; then
            FAIL=$((FAIL + 1))
            echo "FAIL: $name"
            echo "  Expected stderr matching: $expected_stderr_pattern"
            echo "  Got: $stderr_output"
            return
        fi
    fi

    PASS=$((PASS + 1))
    echo "PASS: $name"
}

echo "=== oh-my-agents Hook Tests ==="
echo ""

# =============================================
# arch-check.sh tests
# =============================================

echo "--- arch-check.sh ---"

run_test "arch-check: allow non-layer file" \
    "arch-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/foo.ts","new_string":"import x from \"y\""}}' \
    0

run_test "arch-check: allow same-layer import" \
    "arch-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/types/foo.ts","new_string":"import { Bar } from \"../types/bar\""}}' \
    0

run_test "arch-check: allow lower-layer import" \
    "arch-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/service/foo.ts","new_string":"import { Bar } from \"../types/bar\""}}' \
    0

run_test "arch-check: block higher-layer import (types importing from ui)" \
    "arch-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/types/foo.ts","new_string":"import { Component } from \"../components/bar\""}}' \
    2 \
    "Layer violation"

run_test "arch-check: block service importing from ui" \
    "arch-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/service/auth.ts","new_string":"import { Button } from \"../ui/button\""}}' \
    2 \
    "Layer violation"

run_test "arch-check: allow empty content" \
    "arch-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/types/foo.ts","new_string":""}}' \
    0

run_test "arch-check: allow empty file_path" \
    "arch-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"","new_string":"import x"}}' \
    0

# =============================================
# safety-check.sh tests
# =============================================

echo ""
echo "--- safety-check.sh ---"

run_test "safety: allow normal code" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts","new_string":"const x = process.env.API_KEY"}}' \
    0

run_test "safety: block hardcoded password" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts","new_string":"password = \"hunter2\""}}' \
    2 \
    "Hardcoded credential"

run_test "safety: block AWS key" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts","new_string":"const key = \"AKIAIOSFODNN7EXAMPLE\""}}' \
    2 \
    "AWS Access Key"

run_test "safety: block GitHub token" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts","new_string":"token = \"ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij\""}}' \
    2 \
    "GitHub Personal Access Token"

run_test "safety: skip test files" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/__tests__/auth.test.ts","new_string":"password = \"test123\""}}' \
    0

run_test "safety: skip commented-out secrets" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts","new_string":"// password = \"hunter2\""}}' \
    0

run_test "safety: block API key assignment" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/config.ts","new_string":"api_key = \"sk-proj-abc123def456ghi789\""}}' \
    2 \
    "Hardcoded API key"

# =============================================
# bash-safety-check.sh tests
# =============================================

echo ""
echo "--- bash-safety-check.sh ---"

run_test "bash-safety: allow normal command" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' \
    0

run_test "bash-safety: block AWS key in command" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"aws s3 ls --access-key AKIAIOSFODNN7EXAMPLE"}}' \
    2 \
    "AWS Access Key"

run_test "bash-safety: block GitHub token in curl" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghij\""}}' \
    2 \
    "GitHub token"

run_test "bash-safety: allow env var in Authorization" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: Bearer $TOKEN\""}}' \
    0

run_test "bash-safety: allow env var with braces in Authorization" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: Bearer ${MY_TOKEN}\""}}' \
    0

run_test "bash-safety: allow empty command" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":""}}' \
    0

# =============================================
# session-metrics.sh tests
# =============================================

echo ""
echo "--- session-metrics.sh ---"

# session-metrics always exits 0 (never blocks)
run_test "metrics: always exits 0 for valid input" \
    "session-metrics.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.ts"},"cwd":"/tmp"}' \
    0

run_test "metrics: always exits 0 for empty input" \
    "session-metrics.sh" \
    '{"tool_name":"Bash","tool_input":{}}' \
    0

# =============================================
# common.sh library tests
# =============================================

echo ""
echo "--- lib/common.sh ---"

# Test resolve_layer via sourcing
test_resolve_layer() {
    local path="$1"
    local expected="$2"
    local name="$3"

    TOTAL=$((TOTAL + 1))

    # Source common.sh and test resolve_layer
    local actual
    actual=$(
        HARNESS_LAYER_DIRS=""
        source "${HOOKS_DIR}/lib/common.sh"
        resolve_layer "$path"
    )

    if [ "$actual" = "$expected" ]; then
        PASS=$((PASS + 1))
        echo "PASS: $name"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $name"
        echo "  Expected: '$expected', Got: '$actual'"
    fi
}

test_resolve_layer "/project/src/types/user.ts" "types" "resolve_layer: types directory"
test_resolve_layer "/project/src/models/user.ts" "types" "resolve_layer: models maps to types"
test_resolve_layer "/project/src/config/db.ts" "config" "resolve_layer: config directory"
test_resolve_layer "/project/src/repository/users.ts" "repo" "resolve_layer: repository maps to repo"
test_resolve_layer "/project/src/services/auth.ts" "service" "resolve_layer: services maps to service"
test_resolve_layer "/project/src/api/routes.ts" "runtime" "resolve_layer: api maps to runtime"
test_resolve_layer "/project/src/components/button.tsx" "ui" "resolve_layer: components maps to ui"
test_resolve_layer "/project/src/utils/helper.ts" "" "resolve_layer: unknown path returns empty"

# =============================================
# safety-check.sh — additional edge case tests
# =============================================

echo ""
echo "--- safety-check.sh (edge cases) ---"

run_test "safety: block JWT token" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts","new_string":"const token = \"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ\""}}' \
    2 \
    "JWT token"

run_test "safety: block Slack token" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts","new_string":"const slack = \"xoxb-1234567890123-1234567890123-AbCdEfGhIjKlMnOpQrStUv\""}}' \
    2 \
    "Slack token"

run_test "safety: block PEM private key" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts","new_string":"-----BEGIN RSA PRIVATE KEY-----"}}' \
    2 \
    "Private key"

run_test "safety: block Google API key" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/app.ts","new_string":"const key = \"AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P6Q\""}}' \
    2 \
    "Google API key"

run_test "safety: allow binary files" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/assets/icon.png","new_string":"password = \"hunter2\""}}' \
    0

run_test "safety: block SECRET variable" \
    "safety-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/project/src/config.ts","new_string":"MY_SECRET_KEY = \"super_secret_value_123\""}}' \
    2 \
    "Hardcoded secret"

# =============================================
# bash-safety-check.sh — additional edge case tests
# =============================================

echo ""
echo "--- bash-safety-check.sh (edge cases) ---"

run_test "bash-safety: block JWT in command" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0\""}}' \
    2 \
    "JWT token"

run_test "bash-safety: block Slack token in command" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: xoxb-1234567890123-AbCdEfGhIjKl\""}}' \
    2 \
    "Slack token"

run_test "bash-safety: block PEM key in command" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"echo \"-----BEGIN RSA PRIVATE KEY-----\" | base64"}}' \
    2 \
    "Private key"

run_test "bash-safety: block inline Bearer token" \
    "bash-safety-check.sh" \
    '{"tool_name":"Bash","tool_input":{"command":"curl -H \"Authorization: Bearer sk_live_AbCdEfGhIjKlMnOpQrSt\""}}' \
    2 \
    "inline auth token"

# =============================================
# self-verify-check.sh tests
# =============================================

echo ""
echo "--- self-verify-check.sh ---"

# self-verify-check always exits 0 (advisory only, never blocks)
run_test "self-verify: always exits 0 for valid input" \
    "self-verify-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/test.ts"}}' \
    0

run_test "self-verify: always exits 0 for empty file_path" \
    "self-verify-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":""}}' \
    0

run_test "self-verify: always exits 0 for non-code file" \
    "self-verify-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/tmp/readme.md"}}' \
    0

run_test "self-verify: always exits 0 for nonexistent file" \
    "self-verify-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"/nonexistent/path/foo.ts"}}' \
    0

# =============================================
# doc-drift-check.sh tests
# =============================================

echo ""
echo "--- doc-drift-check.sh ---"

# doc-drift-check always exits 0 (advisory only, never blocks)
run_test "doc-drift: always exits 0 for valid input" \
    "doc-drift-check.sh" \
    '{"hook_event_name":"Stop","session_id":"test","cwd":"/tmp"}' \
    0

run_test "doc-drift: always exits 0 for empty cwd" \
    "doc-drift-check.sh" \
    '{"hook_event_name":"Stop","session_id":"test","cwd":""}' \
    0

# Test with a non-existent project dir (should gracefully handle)
run_test "doc-drift: handles non-existent project dir gracefully" \
    "doc-drift-check.sh" \
    '{"hook_event_name":"Stop","session_id":"test","cwd":"/nonexistent/path/xyz"}' \
    0

# =============================================
# plan-validation-check.sh tests (feedforward GUIDE — always exits 0)
# =============================================

echo ""
echo "--- plan-validation-check.sh ---"

run_test "plan-validation: silent + exit 0 on non-plan file" \
    "plan-validation-check.sh" \
    '{"tool_name":"Write","tool_input":{"file_path":"src/foo.ts","content":"const x=1"}}' \
    0

run_test "plan-validation: exit 0 on well-specified in_progress task" \
    "plan-validation-check.sh" \
    '{"tool_name":"Write","tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"in_progress\",\"acceptance\":\"ok\",\"context_files\":[\"a\"],\"failing_tests\":[\"t\"]}]}"}}' \
    0

run_test "plan-validation: exit 0 (never blocks) on under-specified task" \
    "plan-validation-check.sh" \
    '{"tool_name":"Write","tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"in_progress\"}]}"}}' \
    0

run_test "plan-validation: exit 0 on invalid/mid-edit JSON" \
    "plan-validation-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"docs/exec-plans/active/p.json","new_string":"{not valid json"}}' \
    0

# Custom assertion: advisory message MUST appear for an under-specified in_progress task,
# and MUST NOT appear for a well-specified one (run_test only checks stderr on exit 2).
assert_advisory() {
    local name="$1" input="$2" should_warn="$3"
    TOTAL=$((TOTAL + 1))
    local out
    out=$(printf '%s' "$input" | bash "$HOOKS_DIR/plan-validation-check.sh" 2>&1 >/dev/null || true)
    local has_warn="no"
    echo "$out" | grep -q "Plan handoff checklist" && has_warn="yes"
    if [ "$has_warn" = "$should_warn" ]; then
        PASS=$((PASS + 1)); echo "PASS: $name"
    else
        FAIL=$((FAIL + 1)); echo "FAIL: $name (expected warn=$should_warn, got $has_warn)"
    fi
}

assert_advisory "plan-validation: warns on missing handoff fields" \
    '{"tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"in_progress\"}]}"}}' \
    "yes"

assert_advisory "plan-validation: stays silent when fields present" \
    '{"tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"done\",\"acceptance\":\"ok\",\"context_files\":[\"a\"],\"failing_tests\":[\"t\"]}]}"}}' \
    "no"

# --- v3.9.0: schema GUIDE + completion nudge (plan-validation-check) ---

assert_output() {
    # Generic stderr-content assertion (exit code must be 0 — GUIDE semantics)
    local name="$1" hook="$2" input="$3" pattern="$4" should_match="$5" cwd="${6:-}"
    TOTAL=$((TOTAL + 1))
    local out rc=0
    if [ -n "$cwd" ]; then
        out=$(cd "$cwd" && printf '%s' "$input" | bash "$HOOKS_DIR/$hook" 2>&1) || rc=$?
    else
        out=$(printf '%s' "$input" | bash "$HOOKS_DIR/$hook" 2>&1) || rc=$?
    fi
    local matched="no"
    echo "$out" | grep -q "$pattern" && matched="yes"
    if [ "$rc" = "0" ] && [ "$matched" = "$should_match" ]; then
        PASS=$((PASS + 1)); echo "PASS: $name"
    else
        FAIL=$((FAIL + 1)); echo "FAIL: $name (exit=$rc, match=$matched, want=$should_match)"
    fi
}

assert_output "plan-validation: schema GUIDE on unknown top-level key" \
    "plan-validation-check.sh" \
    '{"tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"unknown_field\":1,\"tasks\":[{\"id\":\"t-1\",\"status\":\"pending\"}]}"}}' \
    "Plan schema GUIDE" "yes"

assert_output "plan-validation: schema GUIDE on prose acceptance" \
    "plan-validation-check.sh" \
    '{"tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"pending\",\"acceptance\":\"the user should be able to log in without any errors at all\"}]}"}}' \
    "acceptance reads as prose" "yes"

assert_output "plan-validation: completion nudge fires when all tasks done + plan active" \
    "plan-validation-check.sh" \
    '{"tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"plan-x\",\"status\":\"active\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"done\",\"acceptance\":\"run-tests\",\"context_files\":[\"a\"],\"failing_tests\":[\"t\"]}]}"}}' \
    "next: /verify --plan plan-x" "yes"

# Suppression: a FRESH GREEN verify signal newer than the plan file suppresses the nudge
NUDGE_TMP=$(mktemp -d)
mkdir -p "$NUDGE_TMP/docs/exec-plans/active" "$NUDGE_TMP/.claude/signals"
printf '%s' '{"id":"plan-x","status":"active","tasks":[{"id":"t-1","status":"done","acceptance":"run-tests","context_files":["a"],"failing_tests":["t"]}]}' \
    > "$NUDGE_TMP/docs/exec-plans/active/p.json"
sleep 0.01 2>/dev/null || sleep 1
printf '%s' '{"schema_version":1,"decision":"GREEN"}' > "$NUDGE_TMP/.claude/signals/verify-latest.json"
assert_output "plan-validation: completion nudge suppressed by fresh GREEN" \
    "plan-validation-check.sh" \
    "{\"cwd\":\"$NUDGE_TMP\",\"tool_input\":{\"file_path\":\"$NUDGE_TMP/docs/exec-plans/active/p.json\",\"content\":\"{\\\"id\\\":\\\"plan-x\\\",\\\"status\\\":\\\"active\\\",\\\"tasks\\\":[{\\\"id\\\":\\\"t-1\\\",\\\"status\\\":\\\"done\\\",\\\"acceptance\\\":\\\"run-tests\\\",\\\"context_files\\\":[\\\"a\\\"],\\\"failing_tests\\\":[\\\"t\\\"]}]}\"}}" \
    "next: /verify" "no"
rm -rf "$NUDGE_TMP"

# --- v3.9.0: gate-state nudge (doc-drift-check, Stop hook) ---

echo "--- doc-drift-check.sh gate-state nudge ---"

if command -v jq >/dev/null 2>&1; then
    GATE_TMP=$(mktemp -d)
    (cd "$GATE_TMP" && git init -q . && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m init)
    mkdir -p "$GATE_TMP/.claude/signals"
    HEAD_SHA=$(git -C "$GATE_TMP" rev-parse HEAD)

    printf '{"schema_version":1,"decision":"APPROVE","commit":"%s"}' "$HEAD_SHA" \
        > "$GATE_TMP/.claude/signals/review-latest.json"
    assert_output "doc-drift: APPROVE (fresh) nudges gstack /ship" \
        "doc-drift-check.sh" \
        "{\"hook_event_name\":\"Stop\",\"cwd\":\"$GATE_TMP\"}" \
        "next: gstack /ship" "yes"

    printf '{"schema_version":1,"decision":"APPROVE","commit":"stale-sha"}' \
        > "$GATE_TMP/.claude/signals/review-latest.json"
    printf '{"schema_version":1,"decision":"GREEN","commit":"stale-sha"}' \
        > "$GATE_TMP/.claude/signals/verify-latest.json"
    assert_output "doc-drift: stale commit yields WARN, never a nudge" \
        "doc-drift-check.sh" \
        "{\"hook_event_name\":\"Stop\",\"cwd\":\"$GATE_TMP\"}" \
        "is stale (commit mismatch)" "yes"

    rm -f "$GATE_TMP/.claude/signals/review-latest.json"
    printf '{"schema_version":1,"decision":"GREEN","commit":"%s"}' "$HEAD_SHA" \
        > "$GATE_TMP/.claude/signals/verify-latest.json"
    assert_output "doc-drift: fresh GREEN with no review nudges /harness-review" \
        "doc-drift-check.sh" \
        "{\"hook_event_name\":\"Stop\",\"cwd\":\"$GATE_TMP\"}" \
        "next: /harness-review" "yes"
    rm -rf "$GATE_TMP"
else
    echo "SKIP: doc-drift gate-state tests (jq not installed; hook degrades silently)"
fi

# --- v3.9.0: self-verify passive overlap measurement (item 15) ---

echo "--- self-verify-check.sh metrics event ---"

SV_TMP=$(mktemp -d)
printf '{}' > "$SV_TMP/package.json"   # project-root marker
printf 'def broken(:\n' > "$SV_TMP/bad.py"
printf '%s' "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$SV_TMP/bad.py\"}}" \
    | bash "$HOOKS_DIR/self-verify-check.sh" >/dev/null 2>&1 || true
TOTAL=$((TOTAL + 1))
if ls "$SV_TMP/.claude/metrics/"session-*.jsonl >/dev/null 2>&1 \
   && grep -q '"hook":"self-verify-check"' "$SV_TMP/.claude/metrics/"session-*.jsonl; then
    PASS=$((PASS + 1)); echo "PASS: self-verify: warning appends metrics event"
else
    FAIL=$((FAIL + 1)); echo "FAIL: self-verify: warning appends metrics event"
fi
rm -rf "$SV_TMP"

run_test "self-verify: exit 0 unchanged on triggered warning" \
    "self-verify-check.sh" \
    '{"tool_name":"Write","tool_input":{"file_path":"/nonexistent/x.py"}}' \
    0

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
