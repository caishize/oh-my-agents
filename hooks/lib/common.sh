#!/usr/bin/env bash
#
# Shared utilities for oh-my-agents hooks.
# Source this file from hook scripts:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib/common.sh"
#
# Provides:
#   read_input          — reads stdin into $INPUT
#   json_get <jq> <py>  — extract value from $INPUT using jq or python3 fallback
#   get_file_path       — extract .tool_input.file_path from $INPUT
#   get_content         — extract content + new_string from $INPUT
#   get_command         — extract .tool_input.command from $INPUT (for Bash hooks)
#   find_harness_json <start-dir> — walk up to find .claude/harness.json
#   load_harness_config <harness-file> — load providers_path and layer_dirs
#   resolve_layer <path> — return layer name for a file path (uses harness.json + fallback)
#   resolve_layer_index <path> — return numeric layer index (0-5, or -1)
#   layer_name_to_index <name> — convert layer name to index
#   add_violation <msg>  — append to $VIOLATIONS (caller must declare VIOLATIONS="")

# --- Input ---

read_input() {
    INPUT=$(cat)
}

# --- JSON parsing: prefer jq, fallback to python3 ---

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

# --- Common field extractors ---

get_file_path() {
    json_get \
        '.tool_input.file_path // ""' \
        "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('file_path',''))"
}

get_content() {
    json_get \
        '(.tool_input.content // "") + (.tool_input.new_string // "")' \
        "import sys,json; d=json.load(sys.stdin).get('tool_input',{}); print((d.get('content','') or '')+(d.get('new_string','') or ''))"
}

get_command() {
    json_get \
        '.tool_input.command // ""' \
        "import sys,json; print(json.load(sys.stdin).get('tool_input',{}).get('command',''))"
}

get_tool_name() {
    json_get \
        '.tool_name // ""' \
        "import sys,json; print(json.load(sys.stdin).get('tool_name',''))"
}

get_cwd() {
    json_get \
        '.cwd // "."' \
        "import sys,json; print(json.load(sys.stdin).get('cwd','.'))"
}

# --- Harness config loading ---

# Initialize harness config variables with defaults
HARNESS_FILE=""
HARNESS_ROOT=""
PROVIDERS_PATH=""
HARNESS_LAYER_DIRS=""
SIBLING_LAYERS=""

# Walk up from a directory to find .claude/harness.json
# Sets: HARNESS_FILE, HARNESS_ROOT
find_harness_json() {
    local search_dir="$1"
    HARNESS_FILE=""
    HARNESS_ROOT=""
    while [ "$search_dir" != "/" ] && [ "$search_dir" != "." ]; do
        if [ -f "${search_dir}/.claude/harness.json" ]; then
            HARNESS_FILE="${search_dir}/.claude/harness.json"
            HARNESS_ROOT="$search_dir"
            return 0
        fi
        search_dir=$(dirname "$search_dir")
    done
    return 1
}

# Load config from harness.json
# Sets: PROVIDERS_PATH, HARNESS_LAYER_DIRS, SIBLING_LAYERS
load_harness_config() {
    local harness_file="$1"
    PROVIDERS_PATH=""
    HARNESS_LAYER_DIRS=""
    SIBLING_LAYERS=""
    if [ -z "$harness_file" ] || [ ! -f "$harness_file" ]; then
        return 1
    fi
    if command -v jq >/dev/null 2>&1; then
        PROVIDERS_PATH=$(jq -r '.providers_path // ""' "$harness_file" 2>/dev/null || echo "")
        HARNESS_LAYER_DIRS=$(jq -r '.layer_dirs // empty' "$harness_file" 2>/dev/null || echo "")
        SIBLING_LAYERS=$(jq -r '(.sibling_layers // []) | .[]' "$harness_file" 2>/dev/null | tr '\n' ',' || echo "")
    elif command -v python3 >/dev/null 2>&1; then
        PROVIDERS_PATH=$(python3 -c "import json; print(json.load(open('${harness_file}')).get('providers_path',''))" 2>/dev/null || echo "")
        HARNESS_LAYER_DIRS=$(python3 -c "import json; d=json.load(open('${harness_file}')).get('layer_dirs',{}); print(json.dumps(d) if d else '')" 2>/dev/null || echo "")
        SIBLING_LAYERS=$(python3 -c "import json; print(','.join(json.load(open('${harness_file}')).get('sibling_layers',[])))" 2>/dev/null || echo "")
    fi
}

# Check if two layers are siblings (allowed to import from each other)
# sibling_layers format in harness.json: ["service:runtime", "ui:pages"]
# SIBLING_LAYERS is a comma-separated string: "service:runtime,ui:pages,"
are_sibling_layers() {
    local layer_a="$1"
    local layer_b="$2"
    if [ -z "${SIBLING_LAYERS:-}" ]; then
        return 1
    fi
    # Check both orderings: a:b and b:a
    if echo ",$SIBLING_LAYERS" | grep -qE ",${layer_a}:${layer_b},|,${layer_b}:${layer_a},"; then
        return 0
    fi
    return 1
}

# --- Layer resolution ---

# Canonical layer order
LAYER_ORDER=(types config repo service runtime ui)

layer_name_to_index() {
    case "$1" in
        types)   echo 0 ;;
        config)  echo 1 ;;
        repo)    echo 2 ;;
        service) echo 3 ;;
        runtime) echo 4 ;;
        ui)      echo 5 ;;
        *)       echo -1 ;;
    esac
}

index_to_layer_name() {
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

# Resolve layer name from file path using harness.json layer_dirs
_resolve_layer_from_harness() {
    local path="$1"
    if [ -z "${HARNESS_LAYER_DIRS:-}" ]; then
        echo ""
        return
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
layer_dirs = json.loads(sys.argv[1])
layer_order = ['types','config','repo','service','runtime','ui']
path = sys.argv[2]
for layer_name in layer_order:
    if layer_name in layer_dirs:
        dirs = layer_dirs[layer_name]
        if isinstance(dirs, str):
            dirs = [dirs]
        for pattern in dirs:
            clean = pattern.strip('*/ ')
            if clean and ('/' + clean + '/' in path or path.startswith(clean + '/')):
                print(layer_name)
                sys.exit(0)
print('')
" "$HARNESS_LAYER_DIRS" "$path" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# Fallback layer detection from path patterns
_resolve_layer_fallback() {
    local path="$1"
    case "$path" in
        */types/*|*/models/*|*/interfaces/*)       echo "types" ;;
        */config/*|*/configuration/*)              echo "config" ;;
        */repo/*|*/repository/*|*/dal/*)           echo "repo" ;;
        */service/*|*/services/*)                  echo "service" ;;
        */runtime/*|*/server/*|*/api/*)            echo "runtime" ;;
        */ui/*|*/components/*|*/pages/*|*/views/*)  echo "ui" ;;
        *)                                         echo "" ;;
    esac
}

# Resolve layer name for a file path (harness.json first, then fallback)
# Returns: layer name string or empty
resolve_layer() {
    local path="$1"
    local result
    result=$(_resolve_layer_from_harness "$path" || echo "")
    if [ -n "$result" ]; then
        echo "$result"
        return
    fi
    _resolve_layer_fallback "$path"
}

# Resolve layer index for a file path (0-5, or -1 if unknown)
resolve_layer_index() {
    local name
    name=$(resolve_layer "$1")
    if [ -n "$name" ]; then
        layer_name_to_index "$name"
    else
        echo "-1"
    fi
}
