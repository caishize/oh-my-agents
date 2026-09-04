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

# Tier 1 of get_project_dir reads $CLAUDE_PROJECT_DIR. Under a real session it is set to
# THIS repo, which would win for every fixture below. Unset it; the tier-1 test sets it
# explicitly for the one case that asserts its precedence.
unset CLAUDE_PROJECT_DIR

GIT_Q() { git -c user.email=t@t -c user.name=t "$@"; }

assert_true() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    if "$@"; then
        PASS=$((PASS + 1)); echo "PASS: $name"
    else
        FAIL=$((FAIL + 1)); echo "FAIL: $name"
    fi
}

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

run_test "plan-validation: exit 0 on well-specified in-progress task" \
    "plan-validation-check.sh" \
    '{"tool_name":"Write","tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"in-progress\",\"acceptance\":\"ok\",\"context_files\":[\"a\"],\"failing_tests\":[\"t\"]}]}"}}' \
    0

run_test "plan-validation: exit 0 (never blocks) on under-specified task" \
    "plan-validation-check.sh" \
    '{"tool_name":"Write","tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"in_progress\"}]}"}}' \
    0

run_test "plan-validation: exit 0 on invalid/mid-edit JSON" \
    "plan-validation-check.sh" \
    '{"tool_name":"Edit","tool_input":{"file_path":"docs/exec-plans/active/p.json","new_string":"{not valid json"}}' \
    0

# Custom assertion: advisory message MUST appear for an under-specified in-progress task,
# and MUST NOT appear for a well-specified one. Since v3.10.0 the advisory is a JSON
# envelope on STDOUT (emit_advisory) — stderr at exit 0 reaches neither the model nor a
# parsed envelope — so this reads stdout and requires the additionalContext key.
assert_advisory() {
    local name="$1" input="$2" should_warn="$3"
    TOTAL=$((TOTAL + 1))
    local out
    out=$(printf '%s' "$input" | bash "$HOOKS_DIR/plan-validation-check.sh" 2>/dev/null || true)
    local has_warn="no"
    echo "$out" | grep -q "Plan handoff checklist" && echo "$out" | grep -q '"additionalContext"' && has_warn="yes"
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
git init -q "$SV_TMP"                  # authoritative root — a build manifest alone is not
printf '{}' > "$SV_TMP/package.json"   # build-root marker (find_build_root)
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
# Project-root addressing (issue #22)
#
# The bug: hooks took the hook input's .cwd as the project root. Claude Code's Bash tool
# keeps cwd across calls, so one `cd backend && pytest` left every later hook believing the
# root was backend/. Two consequences, both silent: the metrics ledger forked per directory,
# and doc-drift compared repo-root-relative git output against cwd-relative paths, so its
# checks could never match while still exiting 0.
# =============================================

echo "--- project-root addressing ---"

# One monorepo fixture, shaped like the report: root .git, backend/pyproject.toml.
MONO=$(mktemp -d)
git init -q "$MONO"
mkdir -p "$MONO/backend/src/api" "$MONO/frontend/lib" "$MONO/.claude/metrics"
printf '[project]\nname = "be"\n' > "$MONO/backend/pyproject.toml"
printf '{}\n' > "$MONO/frontend/package.json"
printf '# backend\n' > "$MONO/backend/CLAUDE.md"
printf 'x = 1\n' > "$MONO/backend/src/api/handler.py"
for i in 1 2 3 4 5; do printf 'export const a%s = %s\n' "$i" "$i" > "$MONO/frontend/lib/m$i.js"; done
GIT_Q -C "$MONO" add -A >/dev/null 2>&1
GIT_Q -C "$MONO" commit -q -m init >/dev/null 2>&1

# --- session-metrics: one ledger, at the repo root, even when cwd is a package dir ---
printf '%s' "{\"tool_name\":\"Edit\",\"cwd\":\"$MONO/backend\",\"tool_input\":{\"file_path\":\"$MONO/backend/src/api/handler.py\"}}" \
    | bash "$HOOKS_DIR/session-metrics.sh" >/dev/null 2>&1 || true

assert_true "session-metrics: records land in the ROOT ledger (cwd was backend/)" \
    bash -c "ls '$MONO/.claude/metrics/'session-*.jsonl >/dev/null 2>&1"
assert_true "session-metrics: no forked ledger created under backend/" \
    bash -c "[ ! -d '$MONO/backend/.claude' ]"

# --- session-metrics: a Bash call with no file_path (the leg that created the fork) ---
printf '%s' "{\"tool_name\":\"Bash\",\"cwd\":\"$MONO/frontend\",\"tool_input\":{\"command\":\"ls\"}}" \
    | bash "$HOOKS_DIR/session-metrics.sh" >/dev/null 2>&1 || true
assert_true "session-metrics: Bash-leg does not fork the ledger under frontend/" \
    bash -c "[ ! -d '$MONO/frontend/.claude' ]"

# --- session-metrics: a DERIVED root may not invent a .claude/ home ---
LOOSE=$(mktemp -d)
mkdir -p "$LOOSE/pkg"
printf '{}\n' > "$LOOSE/pkg/package.json"
printf 'const x = 1\n' > "$LOOSE/pkg/a.js"
printf '%s' "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$LOOSE/pkg/a.js\"}}" \
    | bash "$HOOKS_DIR/session-metrics.sh" >/dev/null 2>&1 || true
assert_true "session-metrics: derived root (build manifest only) creates no .claude/" \
    bash -c "[ ! -d '$LOOSE/pkg/.claude' ]"
rm -rf "$LOOSE"

# --- \$CLAUDE_PROJECT_DIR outranks a git toplevel (tier 1) ---
ENVROOT=$(mktemp -d)
mkdir -p "$ENVROOT/.claude"
CLAUDE_PROJECT_DIR="$ENVROOT" bash -c "printf '%s' '{\"tool_name\":\"Edit\",\"cwd\":\"$MONO/backend\",\"tool_input\":{\"file_path\":\"$MONO/backend/src/api/handler.py\"}}' | bash '$HOOKS_DIR/session-metrics.sh'" >/dev/null 2>&1 || true
assert_true "get_project_dir: \$CLAUDE_PROJECT_DIR wins over the git toplevel" \
    bash -c "ls '$ENVROOT/.claude/metrics/'session-*.jsonl >/dev/null 2>&1"
rm -rf "$ENVROOT"

# --- doc-drift: the checks that used to be silently unreachable from a subdirectory ---
printf 'x = 2\n' > "$MONO/backend/src/api/handler.py"      # modified, tracked
mkdir -p "$MONO/newmod"
for i in 1 2 3 4 5; do printf 'v = %s\n' "$i" > "$MONO/newmod/f$i.py"; done
GIT_Q -C "$MONO" add -A >/dev/null 2>&1

assert_output "doc-drift: check 4 fires for a nested CLAUDE.md when cwd is a subdir" \
    "doc-drift-check.sh" \
    "{\"hook_event_name\":\"Stop\",\"cwd\":\"$MONO/backend\"}" \
    "Source files changed under 'backend/'" "yes"

assert_output "doc-drift: check 6 counts files under the REPO root, not cwd" \
    "doc-drift-check.sh" \
    "{\"hook_event_name\":\"Stop\",\"cwd\":\"$MONO/backend\"}" \
    "Directory 'newmod/' has 5 files but no CLAUDE.md" "yes"

# --- doc-drift: an unresolvable root is stated, not passed off as a clean run ---
assert_output "doc-drift: says so when the project root is unresolved" \
    "doc-drift-check.sh" \
    '{"hook_event_name":"Stop"}' \
    "project root unresolved" "yes"

# --- doc-drift: forked ledgers left by earlier versions are named, not left invisible ---
mkdir -p "$MONO/backend/.claude/metrics"
printf '{"ts":"2026-08-23T00:00:00Z","tool":"Edit"}\n' > "$MONO/backend/.claude/metrics/session-2026-08-23.jsonl"
assert_output "doc-drift: names a forked metrics ledger" \
    "doc-drift-check.sh" \
    "{\"hook_event_name\":\"Stop\",\"cwd\":\"$MONO/backend\"}" \
    "metrics ledger is forked" "yes"

rm -rf "$MONO"

# --- the fork detector must not cry wolf: two ways the root reads as "not itself" ---

# (a) A root reached through a symlink must still compare equal to the git toplevel,
#     or the hook reports the project's OWN ledger and tells you to delete it.
SYM=$(mktemp -d)
mkdir -p "$SYM/real"
git init -q "$SYM/real"
mkdir -p "$SYM/real/.claude/metrics"
printf 'a\n' > "$SYM/real/f.txt"
GIT_Q -C "$SYM/real" add -A >/dev/null 2>&1
GIT_Q -C "$SYM/real" commit -q -m init >/dev/null 2>&1
ln -s "$SYM/real" "$SYM/link"
TOTAL=$((TOTAL + 1))
SYM_OUT=$(CLAUDE_PROJECT_DIR="$SYM/link" bash -c "printf '%s' '{\"hook_event_name\":\"Stop\"}' | bash '$HOOKS_DIR/doc-drift-check.sh'" 2>&1 || true)
if echo "$SYM_OUT" | grep -q "ledger is forked"; then
    FAIL=$((FAIL + 1)); echo "FAIL: doc-drift: symlinked root reported as its own fork"
else
    PASS=$((PASS + 1)); echo "PASS: doc-drift: a symlinked root is not reported as its own fork"
fi
rm -rf "$SYM"

# (b) A sibling git work tree owns its own ledger — worktree-aware, never cross-fire.
WT=$(mktemp -d)
git init -q "$WT"
mkdir -p "$WT/.claude/metrics"
printf 'a\n' > "$WT/f.txt"
GIT_Q -C "$WT" add -A >/dev/null 2>&1
GIT_Q -C "$WT" commit -q -m init >/dev/null 2>&1
GIT_Q -C "$WT" worktree add -q "$WT/.gstack-worktrees/feat-x" -b feat-x >/dev/null 2>&1 || true
mkdir -p "$WT/.gstack-worktrees/feat-x/.claude/metrics"
assert_output "doc-drift: a sibling work tree's ledger is not a fork" \
    "doc-drift-check.sh" \
    "{\"hook_event_name\":\"Stop\",\"cwd\":\"$WT\"}" \
    "ledger is forked" "no"

# ...but a copy inside THIS work tree still is.
mkdir -p "$WT/sub/.claude/metrics"
assert_output "doc-drift: a same-work-tree copy is still reported" \
    "doc-drift-check.sh" \
    "{\"hook_event_name\":\"Stop\",\"cwd\":\"$WT\"}" \
    "sub/.claude/metrics" "yes"
rm -rf "$WT"

# --- find_project_root / find_build_root: the two roots are not the same question ---
ROOTS=$(mktemp -d)
git init -q "$ROOTS"
mkdir -p "$ROOTS/backend/src"
printf '[project]\n' > "$ROOTS/backend/pyproject.toml"
printf 'x = 1\n' > "$ROOTS/backend/src/a.py"
# shellcheck disable=SC1090
( set +u; source "$HOOKS_DIR/lib/common.sh"
  [ "$(find_project_root "$ROOTS/backend/src/a.py")" = "$ROOTS" ] ) \
    && ROOT_OK=0 || ROOT_OK=1
assert_true "find_project_root: repo root beats a package build manifest" \
    bash -c "[ '$ROOT_OK' = '0' ]"
( set +u; source "$HOOKS_DIR/lib/common.sh"
  [ "$(find_build_root "$ROOTS/backend/src/a.py")" = "$ROOTS/backend" ] ) \
    && BUILD_OK=0 || BUILD_OK=1
assert_true "find_build_root: nearest build manifest, i.e. the package dir" \
    bash -c "[ '$BUILD_OK' = '0' ]"
rm -rf "$ROOTS"

# --- no hook may fall back to \$(pwd), and \$CLAUDE_PROJECT_DIR must be honoured somewhere ---
assert_true "hooks: no PROJECT_DIR=\$(pwd) guess remains" \
    bash -c "! grep -rn 'PROJECT_DIR=\"\\\$(pwd)\"' '$HOOKS_DIR'"
assert_true "hooks: \$CLAUDE_PROJECT_DIR is consulted" \
    bash -c "grep -rq 'CLAUDE_PROJECT_DIR' '$HOOKS_DIR/lib/common.sh'"

# =============================================
# Summary
# =============================================

# =============================================
# v3.10.0 — advisory channel, SessionStart, termination sensor, dirty tree, enum GUIDE,
# hook latency budget (docs/TEAM-DISCUSSION-2026-09-04.md)
# =============================================

echo ""
echo "--- v3.10.0: emit_advisory channel ---"

COMMON_SH="$HOOKS_DIR/lib/common.sh"

# Advisory hooks emit ONE JSON envelope on stdout (the channel that reaches the model),
# never permissionDecision, and ZERO bytes when there is nothing to say.
ADV_OUT=$(printf '%s' '{"tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"in-progress\"}]}"}}' \
    | bash "$HOOKS_DIR/plan-validation-check.sh" 2>/dev/null || true)
assert_true "advisory: plan-validation stdout is a JSON envelope with additionalContext" \
    bash -c "printf '%s' \"\$1\" | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"permissionDecision\" not in d[\"hookSpecificOutput\"]'" _ "$ADV_OUT"
assert_true "advisory: plan-validation names the remediation (plan handoff checklist)" \
    bash -c "printf '%s' \"\$1\" | grep -q 'Plan handoff checklist'" _ "$ADV_OUT"

CLEAN_OUT=$(printf '%s' '{"tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"status\":\"active\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"pending\"}]}"}}' \
    | bash "$HOOKS_DIR/plan-validation-check.sh" 2>/dev/null || true)
assert_true "advisory: success silence — clean plan emits zero bytes" test -z "$CLEAN_OUT"

assert_true "advisory: 400-char cap on the injected text keeps the remediation pointer" \
    bash -c "source '$COMMON_SH'; emit_advisory Stop \"\$(head -c 2000 /dev/zero | tr '\\0' 'x')\" | python3 -c 'import json,sys; c=json.load(sys.stdin)[\"hookSpecificOutput\"][\"additionalContext\"]; assert len(c) <= 420 and \"entropy-sweep\" in c'"
assert_true "advisory: spawned gstack subagent (GSTACK_SESSION_KIND=spawned) emits nothing" \
    bash -c "source '$COMMON_SH'; [ -z \"\$(GSTACK_SESSION_KIND=spawned emit_advisory Stop 'x')\" ]"
assert_true "advisory: blank text emits nothing" \
    bash -c "source '$COMMON_SH'; [ -z \"\$(emit_advisory Stop '   ')\" ]"
assert_true "advisory: no advisory hook emits permissionDecision" \
    bash -c "! grep -l 'permissionDecision' '$HOOKS_DIR'/plan-validation-check.sh '$HOOKS_DIR'/self-verify-check.sh '$HOOKS_DIR'/doc-drift-check.sh >/dev/null 2>&1"

# --- status-enum GUIDE (plan-validation, template enum is the SSOT for spelling) ---
assert_output "plan-validation: enum GUIDE flags in_progress (did you mean in-progress)" \
    "plan-validation-check.sh" \
    '{"tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"status\":\"active\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"in_progress\",\"acceptance\":\"ok\",\"context_files\":[\"a\"],\"failing_tests\":[\"t\"]}]}"}}' \
    "did you mean 'in-progress'" "yes"
assert_output "plan-validation: enum GUIDE silent on template spelling" \
    "plan-validation-check.sh" \
    '{"tool_input":{"file_path":"docs/exec-plans/active/p.json","content":"{\"id\":\"p\",\"status\":\"active\",\"tasks\":[{\"id\":\"t-1\",\"status\":\"in-progress\",\"acceptance\":\"ok\",\"context_files\":[\"a\"],\"failing_tests\":[\"t\"]}]}"}}' \
    "not in template enum" "no"

echo "--- v3.10.0: doc-drift SessionStart / termination / dirty tree ---"

if command -v jq >/dev/null 2>&1; then
    DD_TMP=$(mktemp -d)
    (cd "$DD_TMP" && git init -q . && GIT_Q commit -q --allow-empty -m init)
    mkdir -p "$DD_TMP/.claude/signals" "$DD_TMP/.claude/metrics" "$DD_TMP/docs/exec-plans/active"
    DD_SHA=$(git -C "$DD_TMP" rev-parse HEAD)
    printf '{"schema_version":1,"decision":"GREEN","commit":"%s"}' "$DD_SHA" > "$DD_TMP/.claude/signals/verify-latest.json"
    printf '{"id":"plan-s","status":"active","tasks":[]}' > "$DD_TMP/docs/exec-plans/active/plan-s.json"

    SS_OUT=$(printf '%s' "{\"hook_event_name\":\"SessionStart\",\"cwd\":\"$DD_TMP\"}" | bash "$HOOKS_DIR/doc-drift-check.sh" 2>/dev/null || true)
    assert_true "doc-drift SessionStart: JSON envelope with gate state + active plan in additionalContext" \
        bash -c "printf '%s' \"\$1\" | python3 -c 'import json,sys; d=json.load(sys.stdin); c=d[\"hookSpecificOutput\"][\"additionalContext\"]; assert \"next: /harness-review\" in c and \"plan-s\" in c and d[\"hookSpecificOutput\"][\"hookEventName\"]==\"SessionStart\"'" _ "$SS_OUT"

    rm -f "$DD_TMP/.claude/signals/verify-latest.json" "$DD_TMP/docs/exec-plans/active/plan-s.json"
    SS_CLEAN=$(printf '%s' "{\"hook_event_name\":\"SessionStart\",\"cwd\":\"$DD_TMP\"}" | bash "$HOOKS_DIR/doc-drift-check.sh" 2>/dev/null || true)
    assert_true "doc-drift SessionStart: zero bytes when no signal and no plan" test -z "$SS_CLEAN"

    # termination sensor: 3 consecutive RED with identical reason ⇒ escalation, not another /verify
    printf '%s\n' '{"decision":"RED","reason":"3 tests failed"}' '{"decision":"RED","reason":"3 tests failed"}' '{"decision":"RED","reason":"3 tests failed"}' > "$DD_TMP/.claude/metrics/verify.jsonl"
    assert_output "doc-drift Stop: 3 RED same reason trips the termination sensor" \
        "doc-drift-check.sh" "{\"hook_event_name\":\"Stop\",\"cwd\":\"$DD_TMP\"}" \
        "not converging" "yes"
    printf '%s\n' '{"decision":"RED","reason":"a"}' '{"decision":"RED","reason":"b"}' '{"decision":"RED","reason":"a"}' > "$DD_TMP/.claude/metrics/verify.jsonl"
    assert_output "doc-drift Stop: 3 RED different reasons does NOT trip" \
        "doc-drift-check.sh" "{\"hook_event_name\":\"Stop\",\"cwd\":\"$DD_TMP\"}" \
        "not converging" "no"
    run_test "doc-drift Stop: termination sensor never blocks (exit 0)" \
        "doc-drift-check.sh" "{\"hook_event_name\":\"Stop\",\"cwd\":\"$DD_TMP\"}" 0
    rm -f "$DD_TMP/.claude/metrics/verify.jsonl"

    # dirty tree at the APPROVE advance point (our own .claude/ state never counts as dirt)
    printf '{"schema_version":1,"decision":"APPROVE","commit":"%s"}' "$DD_SHA" > "$DD_TMP/.claude/signals/review-latest.json"
    assert_output "doc-drift Stop: APPROVE on a clean tree (only .claude/ untracked) nudges /ship" \
        "doc-drift-check.sh" "{\"hook_event_name\":\"Stop\",\"cwd\":\"$DD_TMP\"}" \
        "next: gstack /ship" "yes"
    printf 'x=1\n' > "$DD_TMP/new-source.py"
    assert_output "doc-drift Stop: APPROVE with an untracked source file WARNs instead" \
        "doc-drift-check.sh" "{\"hook_event_name\":\"Stop\",\"cwd\":\"$DD_TMP\"}" \
        "uncommitted changes since the verdict" "yes"
    assert_true "worktree_dirty: ignores .claude/ and .gstack/, sees source" \
        bash -c "source '$COMMON_SH'; rm -f '$DD_TMP/new-source.py'; ! worktree_dirty '$DD_TMP' && printf 'y\n' > '$DD_TMP/z.txt' && worktree_dirty '$DD_TMP'"

    # the v3.9 handoff writer is gone: a Stop with changed files writes nothing
    (cd "$DD_TMP" && git add z.txt && GIT_Q commit -q -m two && printf 'z\n' >> z.txt)
    printf '%s' "{\"hook_event_name\":\"Stop\",\"cwd\":\"$DD_TMP\"}" | bash "$HOOKS_DIR/doc-drift-check.sh" >/dev/null 2>&1 || true
    assert_true "doc-drift: writes no handoff-<branch>.json (deleted v3.10.0)" \
        bash -c "! ls '$DD_TMP'/.claude/metrics/handoff-* >/dev/null 2>&1"
    rm -rf "$DD_TMP"
else
    echo "SKIP: v3.10.0 doc-drift tests (jq not installed; hook degrades silently)"
fi

echo "--- v3.10.0: hook latency budget (rule hook-latency-budget) ---"
# Every hooks.json timeout ≤ its event's ceiling: PreToolUse 10000, PostToolUse 5000,
# Stop 8000, SessionStart 3000 (ms). Reads a static file; cannot degrade.
assert_true "hooks.json: every timeout within its event ceiling" python3 -c '
import json
h=json.load(open("'"$HOOKS_DIR"'/hooks.json"))["hooks"]
cap={"PreToolUse":10000,"PostToolUse":5000,"Stop":8000,"SessionStart":3000}
bad=[(ev,x["command"],x["timeout"]) for ev,es in h.items() for e in es for x in e["hooks"] if x.get("timeout",0)>cap.get(ev,0)]
assert not bad, bad'
assert_true "hooks.json: exactly 7 hook scripts (no new hook surface)" \
    bash -c "[ \$(ls '$HOOKS_DIR'/*.sh | wc -l | tr -d ' ') -eq 7 ]"
assert_true "hooks.json: doc-drift-check bound to SessionStart" \
    bash -c "python3 -c 'import json; h=json.load(open(\"$HOOKS_DIR/hooks.json\"))[\"hooks\"]; assert any(x[\"command\"].endswith(\"doc-drift-check.sh\") for e in h[\"SessionStart\"] for x in e[\"hooks\"])'"
assert_true "self-verify: heavy path (self_verify_heavy / tsc / cargo) deleted" \
    bash -c "! grep -qE 'HEAVY_VERIFY|timeout 15 cargo|npx --no-install tsc' '$HOOKS_DIR/self-verify-check.sh'"


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
