#!/usr/bin/env bash
#
# Stop-time advisory: doc drift + gate-state nudge.
# Triggered on Stop event — after Claude finishes responding.
# (1) Checks if recently modified source files have corresponding doc references
#     that might need updating.
# (2) Reads the two decision signals (freshness-checked per docs/SIGNALS.md) and NAMES
#     the next gate skill — names, never invokes (rule no-orchestration).
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

# --- Addressing: two roots, named once, never mixed ---
# PROJECT_DIR — the harness root; `.claude/signals` and `.claude/metrics` live here.
# REPO_ROOT   — the git toplevel; EVERY path comparison below is repo-root-relative,
#               because that is the path system `git diff --name-only` natively emits.
# Mixing the two is what silently disabled checks 4 and 6: a repo-root-relative
# `backend/src/api/x.py` was compared against a PROJECT_DIR-relative `src/api`, so the
# match could never fire and the hook exited 0 looking exactly like a clean pass.
if ! get_project_dir; then
    # Say it. A check that established nothing must not look like a check that passed.
    echo ""
    echo "Doc-drift check skipped: project root unresolved."
    echo "  Set CLAUDE_PROJECT_DIR, or run the session inside a git work tree."
    exit 0
fi

git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
REPO_ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$REPO_ROOT" ] && exit 0

# --- Gate-state nudge (advisory; transition mapping source: docs/SIGNALS.md — one
# mapping, two renderings, never two mappings). Freshness predicate FIRST: a signal
# whose commit differs from HEAD is stale — WARN, never a next-step nudge off it.
# Computed up-front so it prints even when no files changed this session. ---
GATE_NUDGE=""
HEAD_SHA=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || echo "")
SIG_DIR="$PROJECT_DIR/.claude/signals"
if [ -n "$HEAD_SHA" ] && command -v jq >/dev/null 2>&1; then
    V_SIG="$SIG_DIR/verify-latest.json"; R_SIG="$SIG_DIR/review-latest.json"
    V_DEC=$(jq -r '.decision // ""' "$V_SIG" 2>/dev/null || echo ""); V_COMMIT=$(jq -r '.commit // ""' "$V_SIG" 2>/dev/null || echo "")
    R_DEC=$(jq -r '.decision // ""' "$R_SIG" 2>/dev/null || echo ""); R_COMMIT=$(jq -r '.commit // ""' "$R_SIG" 2>/dev/null || echo "")
    R_KIND=$(jq -r '.needs_human_kind // ""' "$R_SIG" 2>/dev/null || echo "")
    if [ -n "$V_DEC" ] && [ -n "$V_COMMIT" ] && [ "$V_COMMIT" != "$HEAD_SHA" ]; then
        GATE_NUDGE="WARN: verify-latest.json is stale (commit mismatch) — re-run /verify"
    elif [ -n "$R_DEC" ] && [ -n "$R_COMMIT" ] && [ "$R_COMMIT" != "$HEAD_SHA" ]; then
        GATE_NUDGE="WARN: review-latest.json is stale (commit mismatch) — re-run /harness-review"
    elif [ "$R_DEC" = "NEEDS_HUMAN" ] && [ "$R_KIND" = "composition-skipped" ]; then
        GATE_NUDGE="Gate state: review NEEDS_HUMAN (composition-skipped) — next: re-run /harness-review with gstack composition enabled"
    elif [ "$R_DEC" = "APPROVE" ]; then
        GATE_NUDGE="Gate state: review APPROVE — next: gstack /ship (run the pre-ship check from docs/SIGNALS.md first)"
    elif [ "$V_DEC" = "GREEN" ] && { [ -z "$R_DEC" ] || [ ! -f "$R_SIG" ] || [ "$V_SIG" -nt "$R_SIG" ]; }; then
        GATE_NUDGE="Gate state: verify GREEN with no newer review — next: /harness-review"
    fi
fi

# --- Ledger integrity ---
# Forks created by earlier versions of this hook survive the addressing fix, and they stay
# invisible: `.claude/` is gitignored, so every git-based check is green on all of them, and
# /harness-dashboard reads the root ledger only. The records are not corrupt — they are just
# somewhere nobody looks. Name them. Merging them back is the user's call; deleting them is
# never the answer to "where did the records go".
LEDGER_WARN=""
FORKED_LEDGERS=$(find "$REPO_ROOT" -maxdepth 4 \
    \( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name .next \) -prune -o \
    -type d -path "*/.claude/metrics" -print 2>/dev/null \
    | grep -vxF "$PROJECT_DIR/.claude/metrics" | head -5 || true)
if [ -n "$FORKED_LEDGERS" ]; then
    LEDGER_WARN="WARN: metrics ledger is forked — /harness-dashboard reads only ${PROJECT_DIR}/.claude/metrics:"
    while IFS= read -r fork_dir; do
        [ -z "$fork_dir" ] && continue
        LEDGER_WARN="${LEDGER_WARN}
  ${fork_dir#$REPO_ROOT/}"
    done <<< "$FORKED_LEDGERS"
    LEDGER_WARN="${LEDGER_WARN}
  Merge their session-*.jsonl lines into the root ledger before removing the directories."
fi

# Get files modified in the last commit or staged
CHANGED_FILES=$(git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null || git -C "$REPO_ROOT" diff --name-only --staged 2>/dev/null || echo "")

if [ -z "$CHANGED_FILES" ]; then
    if [ -n "$GATE_NUDGE" ] || [ -n "$LEDGER_WARN" ]; then
        echo ""
        [ -n "$LEDGER_WARN" ] && echo "$LEDGER_WARN"
        [ -n "$GATE_NUDGE" ] && echo "$GATE_NUDGE"
    fi
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
if [ -f "$REPO_ROOT/docs/ARCHITECTURE.md" ]; then
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        if git -C "$REPO_ROOT" diff --name-status HEAD 2>/dev/null | grep -q "^A.*$file"; then
            DIR=$(dirname "$file")
            if grep -q "$DIR" "$REPO_ROOT/docs/ARCHITECTURE.md" 2>/dev/null; then
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
if [ -d "$REPO_ROOT" ]; then
    while IFS= read -r claude_md; do
        [ -z "$claude_md" ] && continue
        # Get the directory this CLAUDE.md covers, as a REPO_ROOT-relative path — the same
        # path system CHANGED_FILES is in, so the comparison below can actually match.
        CLAUDE_DIR=$(dirname "$claude_md")
        # Check 4 is about NESTED CLAUDE.md files; the root one covers the whole tree and
        # would fire on every source change.
        if [ "$CLAUDE_DIR" = "$REPO_ROOT" ]; then
            continue
        fi
        REL_CLAUDE_DIR="${CLAUDE_DIR#$REPO_ROOT/}"

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
        CLAUDE_MD_REL="${claude_md#$REPO_ROOT/}"
        CLAUDE_MD_CHANGED=false
        if echo "$CHANGED_FILES" | grep -qF "$CLAUDE_MD_REL"; then
            CLAUDE_MD_CHANGED=true
        fi

        if [ "$SRC_CHANGED_IN_DIR" = true ] && [ "$CLAUDE_MD_CHANGED" = false ]; then
            WARNINGS="${WARNINGS}Source files changed under '${REL_CLAUDE_DIR}/' but its CLAUDE.md was not updated.\n"
            WARNINGS="${WARNINGS}   Review: ${CLAUDE_MD_REL}\n\n"
        fi
    done < <(find "$REPO_ROOT" -maxdepth 5 -name "CLAUDE.md" -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/vendor/*" -not -path "*/.next/*" -not -path "*/dist/*" -not -path "*/.claude/gstack-rendered/*" 2>/dev/null || true)
fi

# 5. Check if active execution plans reference modified files
if [ -d "$REPO_ROOT/docs/exec-plans/active" ]; then
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
    done < <(find "$REPO_ROOT/docs/exec-plans/active" -type f -name "*.json" -o -name "*.md" 2>/dev/null || true)
fi

# 6. Warn if a new directory with 5+ files was created without a CLAUDE.md
NEW_DIRS=$(git -C "$REPO_ROOT" diff --name-status HEAD 2>/dev/null | grep "^A" | awk '{print $2}' | xargs -I{} dirname {} 2>/dev/null | sort -u || true)
while IFS= read -r dir; do
    [ -z "$dir" ] && continue
    # Skip root, docs, and hidden directories
    case "$dir" in
        .|docs|docs/*|.git|.git/*|.claude|.claude/*|node_modules|node_modules/*) continue ;;
    esac
    # Count files in this directory (including newly added)
    # $dir is repo-root-relative (git's native output) — resolve it against REPO_ROOT.
    FILE_COUNT=$(find "$REPO_ROOT/$dir" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$FILE_COUNT" -ge 5 ]; then
        if [ ! -f "$REPO_ROOT/$dir/CLAUDE.md" ]; then
            WARNINGS="${WARNINGS}Directory '${dir}/' has ${FILE_COUNT} files but no CLAUDE.md.\n"
            WARNINGS="${WARNINGS}   Consider adding a CLAUDE.md for agent context. Threshold: 5 files.\n\n"
        fi
    fi
done <<< "$NEW_DIRS"

# --- Session handoff note ---
# Write a structured handoff file so the next session can bootstrap context quickly.
# This enables /lifecycle next to pick up where the previous session left off.
if resolve_metrics_dir "$PROJECT_DIR" "$PROJECT_DIR_SOURCE"; then
    BRANCH=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo "unknown")
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || echo "unknown")
    FILE_COUNT=$(echo "$CHANGED_FILES" | grep -c . 2>/dev/null || echo "0")

    # Find active plan
    ACTIVE_PLAN=""
    if [ -d "$REPO_ROOT/docs/exec-plans/active" ]; then
        ACTIVE_PLAN=$(ls "$REPO_ROOT/docs/exec-plans/active/"*.json 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "")
    fi

    # Last verify status
    LAST_VERIFY=""
    if [ -f "$METRICS_DIR/verify.jsonl" ]; then
        LAST_VERIFY=$(tail -1 "$METRICS_DIR/verify.jsonl" 2>/dev/null || echo "")
    fi

    # Build handoff JSON (atomic write via tmp + rename)
    # Sanitize variables to prevent JSON injection (strip quotes and backslashes)
    SAFE_BRANCH=$(echo "$BRANCH" | tr -d '"\\\n')
    SAFE_PLAN=$(echo "$ACTIVE_PLAN" | tr -d '"\\\n')
    SAFE_VERIFY=$(echo "$LAST_VERIFY" | tr -d '"\\\n')
    SAFE_FILES=$(echo "$CHANGED_FILES" | head -20 | tr '\n' ',' | sed 's/,$//' | tr -d '"\\\n')
    HANDOFF_TMP="$METRICS_DIR/.handoff-tmp-$$"
    HANDOFF_FILE="$METRICS_DIR/handoff-${SAFE_BRANCH}.json"
    cat > "$HANDOFF_TMP" 2>/dev/null <<HANDOFF_EOF
{"timestamp":"$TIMESTAMP","branch":"$SAFE_BRANCH","files_modified":$FILE_COUNT,"active_plan":"$SAFE_PLAN","last_verify":"$SAFE_VERIFY","changed_files":"$SAFE_FILES","has_warnings":$([ -n "$WARNINGS" ] && echo "true" || echo "false")}
HANDOFF_EOF
    mv "$HANDOFF_TMP" "$HANDOFF_FILE" 2>/dev/null || true
fi

# Output warnings if any
if [ -n "$WARNINGS" ] || [ -n "$GATE_NUDGE" ] || [ -n "$LEDGER_WARN" ]; then
    echo ""
    if [ -n "$WARNINGS" ]; then
        echo "Documentation Drift Check"
        echo "========================="
        echo -e "$WARNINGS"
        echo "Run /entropy-sweep for a full analysis."
    fi
    [ -n "$LEDGER_WARN" ] && echo "$LEDGER_WARN"
    [ -n "$GATE_NUDGE" ] && echo "$GATE_NUDGE"
fi

exit 0
