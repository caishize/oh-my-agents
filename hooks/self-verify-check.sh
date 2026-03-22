#!/usr/bin/env bash
#
# Self-verification hook — PostToolUse for Edit/Write
# Runs a lightweight type-check or syntax check after file edits.
# Implements OpenAI's self-verification middleware pattern:
#   "Agents must confirm their own changes work before requesting review."
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

# --- Run language-specific syntax check ---
WARNINGS=""

case "$FILE_PATH" in
    *.ts|*.tsx)
        # TypeScript: run tsc --noEmit on the single file if tsconfig exists
        if [ -f "${PROJECT_DIR}/tsconfig.json" ]; then
            # Use npx to avoid global install requirement; timeout after 8s
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
        # Python: run syntax check with py_compile
        if command -v python3 >/dev/null 2>&1; then
            PY_OUTPUT=$(python3 -m py_compile "$FILE_PATH" 2>&1 || true)
            if [ -n "$PY_OUTPUT" ]; then
                WARNINGS="Self-verify: Python syntax error detected after edit.\n"
                WARNINGS="${WARNINGS}  ${PY_OUTPUT}\n"
            fi
        fi
        ;;
    *.js|*.jsx)
        # JavaScript: run node --check for syntax validation
        if command -v node >/dev/null 2>&1; then
            JS_OUTPUT=$(node --check "$FILE_PATH" 2>&1 || true)
            if [ -n "$JS_OUTPUT" ]; then
                WARNINGS="Self-verify: JavaScript syntax error detected after edit.\n"
                WARNINGS="${WARNINGS}  ${JS_OUTPUT}\n"
            fi
        fi
        ;;
    *.rs)
        # Rust: run cargo check if Cargo.toml exists
        if [ -f "${PROJECT_DIR}/Cargo.toml" ]; then
            RS_OUTPUT=$(cd "$PROJECT_DIR" && timeout 15 cargo check --message-format=short 2>&1 | grep "^error" | head -3 || true)
            if [ -n "$RS_OUTPUT" ]; then
                WARNINGS="Self-verify: Rust compilation errors detected after edit.\n"
                WARNINGS="${WARNINGS}  ${RS_OUTPUT}\n"
            fi
        fi
        ;;
    *.go)
        # Go: run go vet on the package
        if command -v go >/dev/null 2>&1; then
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
fi

exit 0
