#!/usr/bin/env bash
#
# Architectural layer boundary check hook
# Triggered on PreToolUse for Edit/Write operations
# Checks if a file edit would violate layer boundaries
#
# Claude Code passes hook input as JSON on stdin:
#   { "tool_name": "Edit", "tool_input": { "file_path": "...", "new_string": "..." } }
#
# Exit codes:
#   0 - no violations found (allow)
#   2 - violation found (block with message on stderr)

set -euo pipefail

# Read JSON input from stdin
INPUT=$(cat)

# Parse the file path from tool input
FILE_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

if [ -z "$FILE_PATH" ]; then
    exit 0  # Can't determine file, allow
fi

# Define layer order (customize per project)
# Layers: types(0) -> config(1) -> repo(2) -> service(3) -> runtime(4) -> ui(5)
get_layer() {
    local path="$1"
    case "$path" in
        */types/*|*/models/*|*/interfaces/*)  echo 0 ;;
        */config/*|*/configuration/*)         echo 1 ;;
        */repo/*|*/repository/*|*/dal/*)      echo 2 ;;
        */service/*|*/services/*)             echo 3 ;;
        */runtime/*|*/server/*|*/api/*)       echo 4 ;;
        */ui/*|*/components/*|*/pages/*|*/views/*) echo 5 ;;
        *)                                    echo -1 ;;  # Unknown layer
    esac
}

get_layer_name() {
    case "$1" in
        0) echo "types" ;;
        1) echo "config" ;;
        2) echo "repository" ;;
        3) echo "service" ;;
        4) echo "runtime" ;;
        5) echo "ui" ;;
        *) echo "unknown" ;;
    esac
}

FILE_LAYER=$(get_layer "$FILE_PATH")

# If file isn't in a recognized layer, allow
if [ "$FILE_LAYER" = "-1" ]; then
    exit 0
fi

# Check if the file content (for Write) or new_string (for Edit) imports from higher layers
CONTENT=$(echo "$INPUT" | python3 -c "
import sys, json
data = json.load(sys.stdin).get('tool_input', {})
print(data.get('content', '') or data.get('new_string', ''))
" 2>/dev/null || echo "")

if [ -z "$CONTENT" ]; then
    exit 0
fi

# Check imports for layer violations
VIOLATIONS=""
while IFS= read -r import_path; do
    [ -z "$import_path" ] && continue
    IMPORT_LAYER=$(get_layer "$import_path")
    if [ "$IMPORT_LAYER" != "-1" ] && [ "$IMPORT_LAYER" -gt "$FILE_LAYER" ]; then
        FILE_LAYER_NAME=$(get_layer_name "$FILE_LAYER")
        IMPORT_LAYER_NAME=$(get_layer_name "$IMPORT_LAYER")
        VIOLATIONS="${VIOLATIONS}Layer violation: '${FILE_LAYER_NAME}' layer cannot import from '${IMPORT_LAYER_NAME}' layer.\n"
        VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
        VIOLATIONS="${VIOLATIONS}  Import: ${import_path}\n"
        VIOLATIONS="${VIOLATIONS}  Fix: Move shared logic to the types or config layer, or use a service interface.\n"
        VIOLATIONS="${VIOLATIONS}  Ref: docs/ARCHITECTURE.md#dependency-layers\n\n"
    fi
done < <(echo "$CONTENT" | grep -oE "(import|from|require)\s*[\(\"']([^\"']+)[\"'\)]" | grep -oE "[\"'][^\"']+[\"']" | tr -d "\"'" 2>/dev/null || true)

if [ -n "$VIOLATIONS" ]; then
    echo -e "$VIOLATIONS" >&2
    exit 2
fi

exit 0
