#!/usr/bin/env bash
#
# Self-verification hook — PostToolUse for Edit/Write
# Runs a lightweight type-check or syntax check after file edits.
# Implements OpenAI's self-verification middleware pattern:
#   "Agents must confirm their own changes work before requesting review."
#
# DEPRECATION CANDIDATE vs native post-edit diagnostics — evidence collected passively
# (each warning also appends a structured event to the session metrics stream below);
# decision at the 2026-Q4 council. If native LSP-backed coverage is confirmed, v4.0
# deletes this hook (script + hooks.json entry + doc rows) as that release's offset budget.
#
# Input: JSON on stdin from Claude Code (PostToolUse)
# Output: Warning on stdout (advisory only, never blocks)
# Always exits 0 — violations are surfaced as warnings, not blocks.

set -euo pipefail

# --- Load shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input

FILE_PATH=$(get_file_path)

# Skip if no file path or file doesn't exist
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
    exit 0
fi

# --- Determine project root ---
PROJECT_DIR=""
SEARCH_DIR=$(dirname "$FILE_PATH")
while [ "$SEARCH_DIR" != "/" ] && [ "$SEARCH_DIR" != "." ]; do
    if [ -f "${SEARCH_DIR}/package.json" ] || [ -f "${SEARCH_DIR}/tsconfig.json" ] || \
       [ -f "${SEARCH_DIR}/pyproject.toml" ] || [ -f "${SEARCH_DIR}/Cargo.toml" ]; then
        PROJECT_DIR="$SEARCH_DIR"
        break
    fi
    SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

if [ -z "$PROJECT_DIR" ]; then
    exit 0
fi

# --- Check if heavy verification is enabled (off by default) ---
# Heavy checks (tsc --noEmit, cargo check, go vet) run full compilation passes
# and add 3-15 seconds per edit. Enable via harness.json: "self_verify_heavy": true
HEAVY_VERIFY=false
if find_harness_json "$(dirname "$FILE_PATH")"; then
    if command -v jq >/dev/null 2>&1; then
        HEAVY_VERIFY=$(jq -r '.self_verify_heavy // false' "$HARNESS_FILE" 2>/dev/null || echo "false")
    elif command -v python3 >/dev/null 2>&1; then
        HEAVY_VERIFY=$(python3 -c "import json; print(str(json.load(open('$HARNESS_FILE')).get('self_verify_heavy', False)).lower())" 2>/dev/null || echo "false")
    fi
fi

# --- Run language-specific syntax check ---
# Default: lightweight syntax checks only (py_compile, node --check) — <100ms
# Heavy mode: full type-check / compilation (tsc, cargo check, go vet) — 3-15s
WARNINGS=""

case "$FILE_PATH" in
    *.ts|*.tsx)
        if [ "$HEAVY_VERIFY" = "true" ] && [ -f "${PROJECT_DIR}/tsconfig.json" ]; then
            TSC_OUTPUT=$(cd "$PROJECT_DIR" && timeout 8 npx --no-install tsc --noEmit --pretty false 2>&1 | head -5 || true)
            if echo "$TSC_OUTPUT" | grep -qE "error TS[0-9]+" 2>/dev/null; then
                ERROR_COUNT=$(echo "$TSC_OUTPUT" | grep -cE "error TS[0-9]+" 2>/dev/null || echo "0")
                FIRST_ERROR=$(echo "$TSC_OUTPUT" | grep -E "error TS[0-9]+" | head -1 | sed 's/^[[:space:]]*//')
                WARNINGS="Self-verify: TypeScript type errors detected after edit (${ERROR_COUNT} errors).\n"
                WARNINGS="${WARNINGS}  First error: ${FIRST_ERROR}\n"
                WARNINGS="${WARNINGS}  Run: npx tsc --noEmit\n"
            fi
        fi
        ;;
    *.py)
        # Lightweight: syntax check only (~50ms)
        if command -v python3 >/dev/null 2>&1; then
            PY_OUTPUT=$(python3 -m py_compile "$FILE_PATH" 2>&1 || true)
            if [ -n "$PY_OUTPUT" ]; then
                WARNINGS="Self-verify: Python syntax error detected after edit.\n"
                WARNINGS="${WARNINGS}  ${PY_OUTPUT}\n"
            fi
        fi
        ;;
    *.js|*.jsx)
        # Lightweight: syntax check only (~30ms)
        if command -v node >/dev/null 2>&1; then
            JS_OUTPUT=$(node --check "$FILE_PATH" 2>&1 || true)
            if [ -n "$JS_OUTPUT" ]; then
                WARNINGS="Self-verify: JavaScript syntax error detected after edit.\n"
                WARNINGS="${WARNINGS}  ${JS_OUTPUT}\n"
            fi
        fi
        ;;
    *.rs)
        if [ "$HEAVY_VERIFY" = "true" ] && [ -f "${PROJECT_DIR}/Cargo.toml" ]; then
            RS_OUTPUT=$(cd "$PROJECT_DIR" && timeout 15 cargo check --message-format=short 2>&1 | grep "^error" | head -3 || true)
            if [ -n "$RS_OUTPUT" ]; then
                WARNINGS="Self-verify: Rust compilation errors detected after edit.\n"
                WARNINGS="${WARNINGS}  ${RS_OUTPUT}\n"
            fi
        fi
        ;;
    *.go)
        if [ "$HEAVY_VERIFY" = "true" ] && command -v go >/dev/null 2>&1; then
            GO_DIR=$(dirname "$FILE_PATH")
            GO_OUTPUT=$(cd "$GO_DIR" && timeout 8 go vet ./... 2>&1 | head -3 || true)
            if [ -n "$GO_OUTPUT" ]; then
                WARNINGS="Self-verify: Go vet issues detected after edit.\n"
                WARNINGS="${WARNINGS}  ${GO_OUTPUT}\n"
            fi
        fi
        ;;
esac

# Output warnings if any
if [ -n "$WARNINGS" ]; then
    echo ""
    echo "Self-Verification Check"
    echo "======================="
    echo -e "$WARNINGS"
    echo "Fix before proceeding. Persistent errors? -> /encode-mistake"

    # Passive overlap measurement (v3.9.0): append one structured event to the existing
    # session metrics stream so the Q4 council can diff these warnings against what
    # native post-edit diagnostics surfaced in the same sessions. No new file, no flag.
    METRICS_DIR="${PROJECT_DIR}/.claude/metrics"
    if [ -d "$METRICS_DIR" ] || mkdir -p "$METRICS_DIR" 2>/dev/null; then
        ISSUE_CLASS=$(printf '%s' "$WARNINGS" | head -1 | tr -d '"\\' | cut -c1-80)
        printf '{"ts":"%s","hook":"self-verify-check","file":"%s","issue_class":"%s"}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" \
            "$(printf '%s' "$FILE_PATH" | tr -d '"\\')" \
            "$ISSUE_CLASS" >> "$METRICS_DIR/session-$(date -u +%Y-%m-%d 2>/dev/null || echo unknown).jsonl" 2>/dev/null || true
    fi
fi

exit 0
