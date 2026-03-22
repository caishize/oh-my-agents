#!/usr/bin/env bash
#
# Architectural layer boundary check hook
# Triggered on PreToolUse for Edit/Write operations
# Checks if a file edit would violate layer boundaries
#
# Exit codes:
#   0 - no violations found (allow)
#   2 - violation found (block with message on stderr)

set -euo pipefail

# --- Load shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input

FILE_PATH=$(get_file_path)

if [ -z "$FILE_PATH" ]; then
    exit 0  # Can't determine file, allow
fi

# --- Fast exit for non-code files (no import analysis needed) ---
case "$FILE_PATH" in
    *.md|*.json|*.yaml|*.yml|*.toml|*.css|*.scss|*.less|*.html|*.svg|*.png|*.jpg|*.gif|*.ico|*.lock|*.txt|*.csv|*.env*)
        exit 0
        ;;
esac

# --- Load harness.json ---
find_harness_json "$(dirname "$FILE_PATH")" || true
if [ -n "$HARNESS_FILE" ]; then
    load_harness_config "$HARNESS_FILE"
fi

FILE_LAYER_INDEX=$(resolve_layer_index "$FILE_PATH")

# If file isn't in a recognized layer, allow
if [ "$FILE_LAYER_INDEX" = "-1" ]; then
    exit 0
fi

# Check content for imports from higher layers
CONTENT=$(get_content)

if [ -z "$CONTENT" ]; then
    exit 0
fi

VIOLATIONS=""

# --- Extract import paths from content ---
# Handles: static imports, dynamic import(), require(), re-exports, TypeScript path aliases (@/),
# Python imports (from x import y), Go imports
IMPORT_PATHS=$(echo "$CONTENT" | {
    # JS/TS: import ... from "path", import("path"), require("path"), export ... from "path"
    grep -oE "(import|from|require|export)\s*[\(\"']\s*[\"']?([^\"';\)]+)[\"';\)]" 2>/dev/null || true
} | grep -oE "[\"'][^\"']+[\"']" | tr -d "\"'" 2>/dev/null || true)

# Also extract Python-style imports: from xxx.yyy import zzz
PYTHON_IMPORTS=$(echo "$CONTENT" | grep -oE "^from\s+[a-zA-Z0-9_.]+\s+import" | sed 's/^from\s\+//;s/\s\+import$//' | tr '.' '/' 2>/dev/null || true)

# Resolve TypeScript path aliases: @/types/foo -> types/foo
ALL_IMPORTS=$(printf "%s\n%s" "$IMPORT_PATHS" "$PYTHON_IMPORTS" | sed 's|^@/||' | sort -u)

# --- Check imports for layer violations ---
while IFS= read -r import_path; do
    [ -z "$import_path" ] && continue
    IMPORT_LAYER_INDEX=$(resolve_layer_index "$import_path")
    if [ "$IMPORT_LAYER_INDEX" != "-1" ] && [ "$IMPORT_LAYER_INDEX" -gt "$FILE_LAYER_INDEX" ]; then
        FILE_LAYER_NAME=$(index_to_layer_name "$FILE_LAYER_INDEX")
        IMPORT_LAYER_NAME=$(index_to_layer_name "$IMPORT_LAYER_INDEX")
        # Skip if layers are declared as siblings in harness.json
        if are_sibling_layers "$FILE_LAYER_NAME" "$IMPORT_LAYER_NAME" 2>/dev/null; then
            continue
        fi
        VIOLATIONS="${VIOLATIONS}Layer violation: '${FILE_LAYER_NAME}' layer cannot import from '${IMPORT_LAYER_NAME}' layer.\n"
        VIOLATIONS="${VIOLATIONS}  File: ${FILE_PATH}\n"
        VIOLATIONS="${VIOLATIONS}  Import: ${import_path}\n"
        VIOLATIONS="${VIOLATIONS}  Fix: Move shared logic to the types or config layer, or use a service interface.\n"
        VIOLATIONS="${VIOLATIONS}  Ref: docs/ARCHITECTURE.md#dependency-layers\n\n"
    fi
done <<< "$ALL_IMPORTS"

# --- Providers bypass detection ---
if [ -n "${PROVIDERS_PATH:-}" ] && [ "${PROVIDERS_PATH:-}" != "null" ]; then
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
