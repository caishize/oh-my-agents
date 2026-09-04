#!/usr/bin/env bash
#
# Self-verification hook — PostToolUse for Edit/Write
# Runs a lightweight syntax check after file edits (py_compile / node --check).
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

# --- Determine the BUILD root (not the project root) ---
# A type-check or compile has to run where the manifest is: for backend/src/x.py in a
# monorepo that is backend/, not the repo. This is deliberately NOT the project root —
# the ledger write further down uses get_project_dir, because a per-package ledger is
# exactly the fork this hook must not create.
BUILD_DIR=$(find_build_root "$FILE_PATH" || true)

if [ -z "$BUILD_DIR" ]; then
    exit 0
fi

# --- Run language-specific syntax check ---
# Lightweight syntax checks only (py_compile, node --check) — <100ms. The "heavy" path
# (tsc / cargo check / go vet behind a `self_verify_heavy` harness.json key) was deleted
# in v3.10.0: the key was documented nowhere, so no user could have opted in; the branches
# were untested; and the 15s timeout it needed is exactly what gets a PostToolUse chain
# disabled (taking arch-check and safety-check with it). Type errors belong to the
# project's own LSP / `/verify`. A stale `self_verify_heavy` key is RETIRED — /harness-init
# reports it rather than silently ignoring it.
WARNINGS=""

case "$FILE_PATH" in
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
esac

# Output warnings if any — through emit_advisory (stdout JSON with additionalContext), the
# channel a PostToolUse hook at exit 0 has into the model's context.
if [ -n "$WARNINGS" ]; then
    emit_advisory PostToolUse "$(printf 'Self-Verification Check\n%b\nFix before proceeding. Persistent errors? -> /encode-mistake' "$WARNINGS")"

    # Passive overlap measurement (v3.9.0): append one structured event to the existing
    # session metrics stream so the Q4 council can diff these warnings against what
    # native post-edit diagnostics surfaced in the same sessions. No new file, no flag.
    # ONE ledger per project: address off the project root, never off the build root.
    # Writing to "${BUILD_DIR}/.claude/metrics" is what forked the ledger per package.
    if get_project_dir "$FILE_PATH" && resolve_metrics_dir "$PROJECT_DIR" "$PROJECT_DIR_SOURCE"; then
        ISSUE_CLASS=$(printf '%s' "$WARNINGS" | head -1 | tr -d '"\\' | cut -c1-80)
        printf '{"ts":"%s","hook":"self-verify-check","file":"%s","issue_class":"%s"}\n' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo unknown)" \
            "$(printf '%s' "$FILE_PATH" | tr -d '"\\')" \
            "$ISSUE_CLASS" >> "$METRICS_DIR/session-$(date -u +%Y-%m-%d 2>/dev/null || echo unknown).jsonl" 2>/dev/null || true
    fi
fi

exit 0
