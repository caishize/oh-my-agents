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

# JSON parser: prefer jq, fallback to python3
json_get() {
    local jq_expr="$1"
    local py_expr="$2"
    if command -v jq >/dev/null 2>&1; then
        echo "$INPUT" | jq -r "$jq_expr" 2>/dev/null || echo ""
    elif command -v python3 >/dev/null 2>&1; then
        echo "$INPUT" | python3 -c "$py_expr" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Parse the file path from tool input
FILE_PATH=$(json_get \
    '.tool_input.file_path // ""' \
    "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))")

if [ -z "$FILE_PATH" ]; then
    exit 0  # Can't determine file, allow
fi

# --- Load harness.json if available ---
HARNESS_FILE=""
HARNESS_LAYER_DIRS=""
PROVIDERS_PATH=""
SEARCH_DIR=$(dirname "$FILE_PATH")
while [ "$SEARCH_DIR" != "/" ] && [ "$SEARCH_DIR" != "." ]; do
    if [ -f "${SEARCH_DIR}/.claude/harness.json" ]; then
        HARNESS_FILE="${SEARCH_DIR}/.claude/harness.json"
        break
    fi
    SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

if [ -n "$HARNESS_FILE" ]; then
    if command -v jq >/dev/null 2>&1; then
        PROVIDERS_PATH=$(jq -r '.providers_path // ""' "$HARNESS_FILE" 2>/dev/null || echo "")
        HARNESS_LAYER_DIRS=$(jq -r '.layer_dirs // empty' "$HARNESS_FILE" 2>/dev/null || echo "")
    elif command -v python3 >/dev/null 2>&1; then
        PROVIDERS_PATH=$(python3 -c "import json; print(json.load(open('${HARNESS_FILE}')).get('providers_path',''))" 2>/dev/null || echo "")
        HARNESS_LAYER_DIRS=$(python3 -c "import json; d=json.load(open('${HARNESS_FILE}')).get('layer_dirs',{}); print(json.dumps(d) if d else '')" 2>/dev/null || echo "")
    fi
fi

# --- Layer resolution ---
# If harness.json provides layer_dirs, use those; otherwise fall back to hardcoded patterns
get_layer_from_harness() {
    local path="$1"
    if [ -z "$HARNESS_LAYER_DIRS" ]; then
        echo "-1"
        return
    fi
    # Use python3 or jq to match path against layer_dirs globs
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, fnmatch, sys
layer_dirs = json.loads('${HARNESS_LAYER_DIRS}')
layer_order = ['types','config','repo','service','runtime','ui']
path = '${path}'
for layer_name in layer_order:
    if layer_name in layer_dirs:
        for pattern in layer_dirs[layer_name]:
            if fnmatch.fnmatch(path, pattern):
                print(layer_order.index(layer_name))
                sys.exit(0)
print(-1)
" 2>/dev/null || echo "-1"
    else
        echo "-1"
    fi
}

# Hardcoded fallback layer detection
get_layer_hardcoded() {
    local path="$1"
    case "$path" in
        */types/*|*/models/*|*/interfaces/*)  echo 0 ;;
        */config/*|*/configuration/*)         echo 1 ;;
        */repo/*|*/repository/*|*/dal/*)      echo 2 ;;
        */service/*|*/services/*)             echo 3 ;;
        */runtime/*|*/server/*|*/api/*)       echo 4 ;;
        */ui/*|*/components/*|*/pages/*|*/views/*) echo 5 ;;
        *)                                    echo -1 ;;
    esac
}

get_layer() {
    local path="$1"
    if [ -n "$HARNESS_LAYER_DIRS" ]; then
        local result
        result=$(get_layer_from_harness "$path")
        if [ "$result" != "-1" ]; then
            echo "$result"
            return
        fi
    fi
    get_layer_hardcoded "$path"
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
CONTENT=$(json_get \
    '(.tool_input.content // "") + (.tool_input.new_string // "")' \
    "import sys,json; d=json.load(sys.stdin).get('tool_input',{}); print((d.get('content','') or '')+(d.get('new_string','') or ''))")

if [ -z "$CONTENT" ]; then
    exit 0
fi

VIOLATIONS=""

# --- Check imports for layer violations ---
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

# --- Providers bypass detection ---
if [ -n "$PROVIDERS_PATH" ] && [ "$PROVIDERS_PATH" != "null" ]; then
    AUTH_IMPORTS=$(echo "$CONTENT" | grep -iE "(import|from|require).*['\"](@?passport|jsonwebtoken|bcrypt|jose|next-auth|auth0|firebase\/auth)" 2>/dev/null || true)
    TELEMETRY_IMPORTS=$(echo "$CONTENT" | grep -iE "(import|from|require).*['\"](@?opentelemetry|datadog|newrelic|sentry)" 2>/dev/null || true)
    FF_IMPORTS=$(echo "$CONTENT" | grep -iE "(import|from|require).*['\"](@?launchdarkly|unleash|flagsmith|split)" 2>/dev/null || true)

    if [ -n "$AUTH_IMPORTS" ]; then
        VIOLATIONS="${VIOLATIONS}Providers bypass: Direct auth library import detected.\n"
        VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
        VIOLATIONS="${VIOLATIONS}  Import: $(echo "$AUTH_IMPORTS" | head -1 | sed 's/^[[:space:]]*//')\n"
        VIOLATIONS="${VIOLATIONS}  Fix: Use Providers interface instead of direct import. See docs/PROVIDERS.md\n"
        VIOLATIONS="${VIOLATIONS}  Providers path: ${PROVIDERS_PATH}\n\n"
    fi
    if [ -n "$TELEMETRY_IMPORTS" ]; then
        VIOLATIONS="${VIOLATIONS}Providers bypass: Direct telemetry library import detected.\n"
        VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
        VIOLATIONS="${VIOLATIONS}  Import: $(echo "$TELEMETRY_IMPORTS" | head -1 | sed 's/^[[:space:]]*//')\n"
        VIOLATIONS="${VIOLATIONS}  Fix: Use Providers interface instead of direct import. See docs/PROVIDERS.md\n"
        VIOLATIONS="${VIOLATIONS}  Providers path: ${PROVIDERS_PATH}\n\n"
    fi
    if [ -n "$FF_IMPORTS" ]; then
        VIOLATIONS="${VIOLATIONS}Providers bypass: Direct feature-flag library import detected.\n"
        VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
        VIOLATIONS="${VIOLATIONS}  Import: $(echo "$FF_IMPORTS" | head -1 | sed 's/^[[:space:]]*//')\n"
        VIOLATIONS="${VIOLATIONS}  Fix: Use Providers interface instead of direct import. See docs/PROVIDERS.md\n"
        VIOLATIONS="${VIOLATIONS}  Providers path: ${PROVIDERS_PATH}\n\n"
    fi
fi

if [ -n "$VIOLATIONS" ]; then
    echo -e "$VIOLATIONS" >&2
    exit 2
fi

exit 0
