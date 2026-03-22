#!/usr/bin/env bash
#
# Documentation drift detection hook
# Triggered on Stop event — after Claude finishes responding
# Checks if recently modified source files have corresponding doc references
# that might need updating
#
# Claude Code passes hook input as JSON on stdin:
#   { "hook_event_name": "Stop", "session_id": "...", "cwd": "..." }
#
# Exit codes:
#   0 - always (advisory only, never blocks)
# Output on stdout is shown to the user as a notification

set -euo pipefail

# --- Load shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input

PROJECT_DIR=$(get_cwd)

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
        if git -C "$PROJECT_DIR" diff --name-status HEAD 2>/dev/null | grep -q "^A.*$file"; then
            DIR=$(dirname "$file")
            if grep -q "$DIR" "$PROJECT_DIR/docs/ARCHITECTURE.md" 2>/dev/null; then
                WARNINGS="${WARNINGS}New file '${file}' added to documented directory '${DIR}'.\n"
                WARNINGS="${WARNINGS}   Consider updating docs/ARCHITECTURE.md if this changes the module structure.\n\n"
            fi
        fi
    done <<< "$CHANGED_FILES"
fi

# 2. Check if API files changed but docs weren't updated
API_CHANGED=false
while IFS= read -r file; do
    case "$file" in
        */api/*|*/routes/*|*/endpoints/*|*/handlers/*) API_CHANGED=true ;;
    esac
done <<< "$CHANGED_FILES"

if [ "$API_CHANGED" = true ] && [ "$HAS_DOC_CHANGES" = false ]; then
    WARNINGS="${WARNINGS}API files were modified but documentation was not updated.\n"
    WARNINGS="${WARNINGS}   Review if API documentation needs updating.\n\n"
fi

# 3. Check if config files changed but docs weren't updated
CONFIG_CHANGED=false
while IFS= read -r file; do
    case "$file" in
        *.config.*|.eslintrc*|.prettierrc*|tsconfig*|pyproject.toml|Makefile)
            CONFIG_CHANGED=true
            ;;
    esac
done <<< "$CHANGED_FILES"

if [ "$CONFIG_CHANGED" = true ] && [ "$HAS_DOC_CHANGES" = false ]; then
    WARNINGS="${WARNINGS}Configuration files changed but documentation was not updated.\n"
    WARNINGS="${WARNINGS}   Check if CLAUDE.md or docs/CONVENTIONS.md needs updating.\n\n"
fi

# 4. Check nested CLAUDE.md files for drift
# Find all CLAUDE.md files in the project (not just root)
if [ -d "$PROJECT_DIR" ]; then
    while IFS= read -r claude_md; do
        [ -z "$claude_md" ] && continue
        # Get the directory this CLAUDE.md covers
        CLAUDE_DIR=$(dirname "$claude_md")
        REL_CLAUDE_DIR="${CLAUDE_DIR#$PROJECT_DIR/}"

        # Check if any changed files are under this CLAUDE.md's directory
        SRC_CHANGED_IN_DIR=false
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            case "$file" in
                *.ts|*.js|*.py|*.go|*.rs|*.java|*.rb)
                    if [[ "$file" == "$REL_CLAUDE_DIR"/* ]]; then
                        SRC_CHANGED_IN_DIR=true
                        break
                    fi
                    ;;
            esac
        done <<< "$CHANGED_FILES"

        # Check if this CLAUDE.md was also modified
        CLAUDE_MD_REL="${claude_md#$PROJECT_DIR/}"
        CLAUDE_MD_CHANGED=false
        if echo "$CHANGED_FILES" | grep -qF "$CLAUDE_MD_REL"; then
            CLAUDE_MD_CHANGED=true
        fi

        if [ "$SRC_CHANGED_IN_DIR" = true ] && [ "$CLAUDE_MD_CHANGED" = false ]; then
            WARNINGS="${WARNINGS}Source files changed under '${REL_CLAUDE_DIR}/' but its CLAUDE.md was not updated.\n"
            WARNINGS="${WARNINGS}   Review: ${CLAUDE_MD_REL}\n\n"
        fi
    done < <(find "$PROJECT_DIR" -name "CLAUDE.md" -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null || true)
fi

# 5. Check if active execution plans reference modified files
if [ -d "$PROJECT_DIR/docs/exec-plans/active" ]; then
    while IFS= read -r plan_file; do
        [ -z "$plan_file" ] && continue
        PLAN_NAME=$(basename "$plan_file")
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            if grep -qF "$file" "$plan_file" 2>/dev/null; then
                WARNINGS="${WARNINGS}Modified file '${file}' is referenced in active plan '${PLAN_NAME}'.\n"
                WARNINGS="${WARNINGS}   Review plan status: docs/exec-plans/active/${PLAN_NAME}\n\n"
                break
            fi
        done <<< "$CHANGED_FILES"
    done < <(find "$PROJECT_DIR/docs/exec-plans/active" -type f -name "*.json" -o -name "*.md" 2>/dev/null || true)
fi

# 6. Warn if a new directory with 5+ files was created without a CLAUDE.md
NEW_DIRS=$(git -C "$PROJECT_DIR" diff --name-status HEAD 2>/dev/null | grep "^A" | awk '{print $2}' | xargs -I{} dirname {} 2>/dev/null | sort -u || true)
while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    # Skip root, docs, and hidden directories
    case "$dir" in
        .|docs|docs/*|.git|.git/*|.claude|.claude/*|node_modules|node_modules/*) continue ;;
    esac
    # Count files in this directory (including newly added)
    FILE_COUNT=$(find "$PROJECT_DIR/$dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$FILE_COUNT" -ge 5 ]; then
        if [ ! -f "$PROJECT_DIR/$dir/CLAUDE.md" ]; then
            WARNINGS="${WARNINGS}Directory '${dir}/' has ${FILE_COUNT} files but no CLAUDE.md.\n"
            WARNINGS="${WARNINGS}   Consider adding a CLAUDE.md for agent context. Threshold: 5 files.\n\n"
        fi
    fi
done <<< "$NEW_DIRS"

# Output warnings if any
if [ -n "$WARNINGS" ]; then
    echo ""
    echo "Documentation Drift Check"
    echo "========================="
    echo -e "$WARNINGS"
    echo "Run /entropy-sweep for a full analysis."
fi

exit 0
