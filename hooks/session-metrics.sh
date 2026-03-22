#!/usr/bin/env bash
#
# Session metrics collector — PostToolUse for Edit/Write/Bash
# Lightweight append-only JSONL logger. Must complete in <100ms.
#
# Input: JSON on stdin from Claude Code
# Output: Appends one line to .claude/metrics/session-{date}.jsonl
# Always exits 0 (never blocks).

set -euo pipefail

# --- Load shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input

TOOL_NAME=$(get_tool_name)
FILE_PATH=$(get_file_path)

# --- Determine layer from file path ---
LAYER=""
if [ -n "$FILE_PATH" ]; then
    # Load harness config if available
    find_harness_json "$(dirname "$FILE_PATH")" 2>/dev/null || true
    if [ -n "$HARNESS_FILE" ]; then
        load_harness_config "$HARNESS_FILE"
    fi
    LAYER=$(resolve_layer "$FILE_PATH")
    [ -z "$LAYER" ] && LAYER="other"
fi

# --- Determine metrics directory ---
METRICS_DIR=""
if [ -n "$FILE_PATH" ]; then
    SEARCH_DIR=$(dirname "$FILE_PATH")
    while [ "$SEARCH_DIR" != "/" ] && [ "$SEARCH_DIR" != "." ]; do
        if [ -d "${SEARCH_DIR}/.claude" ]; then
            METRICS_DIR="${SEARCH_DIR}/.claude/metrics"
            break
        fi
        SEARCH_DIR=$(dirname "$SEARCH_DIR")
    done
fi

# Fallback: try cwd from input
if [ -z "$METRICS_DIR" ]; then
    CWD=$(get_cwd)
    if [ -n "$CWD" ] && [ "$CWD" != "." ] && [ -d "$CWD" ]; then
        METRICS_DIR="${CWD}/.claude/metrics"
    fi
fi

# If we still have no metrics dir, silently exit
if [ -z "$METRICS_DIR" ]; then
    exit 0
fi

# --- Ensure directory exists ---
mkdir -p "$METRICS_DIR" 2>/dev/null || exit 0

# --- Append JSONL line ---
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_PART=$(date -u +"%Y-%m-%d")
METRICS_FILE="${METRICS_DIR}/session-${DATE_PART}.jsonl"

# Build JSON without jq for speed
LINE="{\"ts\":\"${TS}\",\"tool\":\"${TOOL_NAME}\",\"file\":\"${FILE_PATH}\",\"layer\":\"${LAYER}\"}"
echo "$LINE" >> "$METRICS_FILE" 2>/dev/null || true

# --- Log rotation: remove JSONL files older than 30 days ---
if [ -f "$METRICS_FILE" ]; then
    LINE_COUNT=$(wc -l < "$METRICS_FILE" 2>/dev/null || echo "99")
    if [ "$LINE_COUNT" -le 1 ]; then
        find "$METRICS_DIR" -name "session-*.jsonl" -mtime +30 -delete 2>/dev/null || true
    fi
fi

exit 0
