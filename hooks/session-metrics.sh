#!/usr/bin/env bash
#
# Session metrics collector — PostToolUse for Edit/Write/Bash
# Lightweight append-only JSONL logger. Must complete in <100ms.
#
# Input: JSON on stdin from Claude Code
# Output: Appends one line to .claude/metrics/session-{date}.jsonl
# Always exits 0 (never blocks).

set -euo pipefail

INPUT=$(cat)

# --- Extract tool_name and file_path ---
TOOL_NAME=""
FILE_PATH=""

if command -v jq >/dev/null 2>&1; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
elif command -v python3 >/dev/null 2>&1; then
    TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_name',''))" 2>/dev/null || echo "")
    FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")
fi

# --- Load harness.json layer_dirs if available (P1 fix: consistency with arch-check.sh) ---
HARNESS_LAYER_DIRS=""
if [ -n "$FILE_PATH" ]; then
    _SEARCH_DIR=$(dirname "$FILE_PATH")
    while [ "$_SEARCH_DIR" != "/" ] && [ "$_SEARCH_DIR" != "." ]; do
        if [ -f "${_SEARCH_DIR}/.claude/harness.json" ]; then
            if command -v jq >/dev/null 2>&1; then
                HARNESS_LAYER_DIRS=$(jq -r '.layer_dirs // empty' "${_SEARCH_DIR}/.claude/harness.json" 2>/dev/null || echo "")
            elif command -v python3 >/dev/null 2>&1; then
                HARNESS_LAYER_DIRS=$(python3 -c "import json; d=json.load(open('${_SEARCH_DIR}/.claude/harness.json')).get('layer_dirs',{}); print(json.dumps(d) if d else '')" 2>/dev/null || echo "")
            fi
            break
        fi
        _SEARCH_DIR=$(dirname "$_SEARCH_DIR")
    done
fi

# --- Determine layer from file path ---
get_layer() {
    local path="$1"
    # Try harness.json layer_dirs first
    if [ -n "$HARNESS_LAYER_DIRS" ] && command -v python3 >/dev/null 2>&1; then
        local result
        result=$(python3 -c "
import json, fnmatch, sys
layer_dirs = json.loads(sys.argv[1])
layer_order = ['types','config','repo','service','runtime','ui']
path = sys.argv[2]
for layer_name in layer_order:
    if layer_name in layer_dirs:
        dirs = layer_dirs[layer_name]
        if isinstance(dirs, str):
            dirs = [dirs]
        for pattern in dirs:
            if fnmatch.fnmatch(path, '*/' + pattern + '/*') or fnmatch.fnmatch(path, pattern + '/*'):
                print(layer_name)
                sys.exit(0)
print('')
" "$HARNESS_LAYER_DIRS" "$path" 2>/dev/null || echo "")
        if [ -n "$result" ]; then
            echo "$result"
            return
        fi
    fi
    # Hardcoded fallback
    case "$path" in
        */types/*|*/models/*|*/interfaces/*)       echo "types" ;;
        */config/*|*/configuration/*)              echo "config" ;;
        */repo/*|*/repository/*|*/dal/*)           echo "repo" ;;
        */service/*|*/services/*)                  echo "service" ;;
        */runtime/*|*/server/*|*/api/*)            echo "runtime" ;;
        */ui/*|*/components/*|*/pages/*|*/views/*)  echo "ui" ;;
        *)                                         echo "other" ;;
    esac
}

LAYER=""
if [ -n "$FILE_PATH" ]; then
    LAYER=$(get_layer "$FILE_PATH")
fi

# --- Determine metrics directory ---
# Walk up from FILE_PATH to find .claude/, or use cwd
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
    CWD=""
    if command -v jq >/dev/null 2>&1; then
        CWD=$(echo "$INPUT" | jq -r '.cwd // ""' 2>/dev/null || echo "")
    elif command -v python3 >/dev/null 2>&1; then
        CWD=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null || echo "")
    fi
    if [ -n "$CWD" ] && [ -d "$CWD" ]; then
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

exit 0
