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
    # Try fast fallback detection first (no harness.json needed)
    LAYER=$(_resolve_layer_fallback "$FILE_PATH" 2>/dev/null || echo "")
    if [ -z "$LAYER" ]; then
        # Only load harness config if fallback didn't match
        find_harness_json "$(dirname "$FILE_PATH")" 2>/dev/null || true
        if [ -n "$HARNESS_FILE" ]; then
            load_harness_config "$HARNESS_FILE"
            LAYER=$(_resolve_layer_from_harness "$FILE_PATH" 2>/dev/null || echo "")
        fi
    fi
    # Classify non-layer files
    if [ -z "$LAYER" ]; then
        case "$FILE_PATH" in
            */docs/*|*.md)       LAYER="docs" ;;
            */test/*|*.test.*|*.spec.*) LAYER="test" ;;
            *)                   LAYER="other" ;;
        esac
    fi
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

# --- Check for hook block events and performance (PreToolUse hooks) ---
# Claude Code passes hook_results in the input for PostToolUse
HOOK_BLOCKED=""
HOOK_DURATIONS=""
if echo "$INPUT" | grep -q '"hook_results"' 2>/dev/null; then
    HOOK_BLOCKED=$(json_get '.hook_results[]? | select(.exit_code == 2) | .hook' \
        'import json,sys; d=json.loads(sys.stdin.read()); results=d.get("hook_results",[]); print(",".join(h.get("hook","") for h in results if h.get("exit_code")==2))' \
        2>/dev/null || echo "")
    # Extract hook durations for performance monitoring
    HOOK_DURATIONS=$(json_get '[.hook_results[]? | {hook: .hook, duration_ms: .duration_ms}] | map(select(.duration_ms != null)) | map("\(.hook):\(.duration_ms)") | join(",")' \
        'import json,sys; d=json.loads(sys.stdin.read()); results=d.get("hook_results",[]); print(",".join(f"{h.get(\"hook\",\"\")}:{h.get(\"duration_ms\",\"\")}" for h in results if h.get("duration_ms") is not None))' \
        2>/dev/null || echo "")
fi

# Build JSON without jq for speed
BLOCKED_FIELD=""
if [ -n "$HOOK_BLOCKED" ]; then
    BLOCKED_FIELD=",\"blocked_by\":\"${HOOK_BLOCKED}\""
fi
DURATION_FIELD=""
if [ -n "$HOOK_DURATIONS" ]; then
    DURATION_FIELD=",\"hook_durations\":\"${HOOK_DURATIONS}\""
fi
LINE="{\"ts\":\"${TS}\",\"tool\":\"${TOOL_NAME}\",\"file\":\"${FILE_PATH}\",\"layer\":\"${LAYER}\"${BLOCKED_FIELD}${DURATION_FIELD}}"

# Use flock to prevent JSONL corruption from parallel Claude Code sessions (gstack Conductor)
LOCK_FILE="${METRICS_FILE}.lock"
if command -v flock >/dev/null 2>&1; then
    (flock -w 2 200 && echo "$LINE" >> "$METRICS_FILE") 200>"$LOCK_FILE" 2>/dev/null || \
        echo "$LINE" >> "$METRICS_FILE" 2>/dev/null || true
else
    # macOS: flock not available, use atomic append (>> is typically atomic for small writes)
    echo "$LINE" >> "$METRICS_FILE" 2>/dev/null || true
fi

# --- Log rotation: remove JSONL files older than 30 days ---
if [ -f "$METRICS_FILE" ]; then
    LINE_COUNT=$(wc -l < "$METRICS_FILE" 2>/dev/null || echo "99")
    if [ "$LINE_COUNT" -le 1 ]; then
        find "$METRICS_DIR" -name "session-*.jsonl" -mtime +30 -delete 2>/dev/null || true
    fi
fi

exit 0
