#!/usr/bin/env bash
#
# Documentation drift detection hook
# Triggered on Stop event — after Claude finishes responding
# Checks if recently modified source files have corresponding doc references
# that might need updating
#
# Exit codes:
#   0 - no drift detected or not applicable
#   0 - always exits 0 (advisory only, never blocks)
# Output on stdout is shown to the user as a notification

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Get files modified in the last commit or staged
CHANGED_FILES=$(git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null || git -C "$PROJECT_DIR" diff --name-only --staged 2>/dev/null || echo "")

if [ -z "$CHANGED_FILES" ]; then
    exit 0
fi

WARNINGS=""

# Check if architecture-significant files changed but docs weren't updated
HAS_SRC_CHANGES=false
HAS_DOC_CHANGES=false

while IFS= read -r file; do
    [ -z "$file" ] && continue
    case "$file" in
        docs/*|*.md|CLAUDE.md)
            HAS_DOC_CHANGES=true
            ;;
        *.ts|*.js|*.py|*.go|*.rs|*.java|*.rb)
            HAS_SRC_CHANGES=true
            ;;
    esac
done <<< "$CHANGED_FILES"

# Check for specific drift signals
# 1. New files added to directories documented in ARCHITECTURE.md
if [ -f "$PROJECT_DIR/docs/ARCHITECTURE.md" ]; then
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        # If a new file was added (exists in diff but might be new)
        if git -C "$PROJECT_DIR" diff --name-status HEAD 2>/dev/null | grep -q "^A.*$file"; then
            DIR=$(dirname "$file")
            if grep -q "$DIR" "$PROJECT_DIR/docs/ARCHITECTURE.md" 2>/dev/null; then
                WARNINGS="${WARNINGS}⚠️  New file '${file}' added to documented directory '${DIR}'.\n"
                WARNINGS="${WARNINGS}   Consider updating docs/ARCHITECTURE.md if this changes the module structure.\n\n"
            fi
        fi
    done <<< "$CHANGED_FILES"
fi

# 2. Check if API files changed but API-CONTRACTS.md wasn't updated
if [ -f "$PROJECT_DIR/docs/API-CONTRACTS.md" ]; then
    API_CHANGED=false
    while IFS= read -r file; do
        case "$file" in
            */api/*|*/routes/*|*/endpoints/*|*/handlers/*) API_CHANGED=true ;;
        esac
    done <<< "$CHANGED_FILES"

    if [ "$API_CHANGED" = true ] && [ "$HAS_DOC_CHANGES" = false ]; then
        WARNINGS="${WARNINGS}⚠️  API files were modified but docs/API-CONTRACTS.md was not updated.\n"
        WARNINGS="${WARNINGS}   Review if API contract documentation needs updating.\n\n"
    fi
fi

# 3. Check if config files changed but CONVENTIONS.md wasn't updated
CONFIG_CHANGED=false
while IFS= read -r file; do
    case "$file" in
        *.config.*|.eslintrc*|.prettierrc*|tsconfig*|pyproject.toml|Makefile)
            CONFIG_CHANGED=true
            ;;
    esac
done <<< "$CHANGED_FILES"

if [ "$CONFIG_CHANGED" = true ] && [ "$HAS_DOC_CHANGES" = false ]; then
    WARNINGS="${WARNINGS}⚠️  Configuration files changed but documentation was not updated.\n"
    WARNINGS="${WARNINGS}   Check if CLAUDE.md or docs/CONVENTIONS.md needs updating.\n\n"
fi

# Output warnings if any
if [ -n "$WARNINGS" ]; then
    echo ""
    echo "📋 Documentation Drift Check"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "$WARNINGS"
    echo "Run /entropy-sweep for a full analysis."
fi

exit 0
