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
