#!/usr/bin/env bash
#
# Advisory hook bound to TWO events (one script, hooks.json registers it twice):
#   Stop         — doc drift + gate-state nudge + verify-loop termination sensor.
#   SessionStart — gate-state ONLY (which signal is fresh, the next gate skill, the active
#                  plan), injected into the model's context at session open so nobody asks
#                  "what state is this branch in?"; returns before any repo walk.
# (1) Checks if recently modified source files have corresponding doc references
#     that might need updating (Stop only).
# (2) Reads the two decision signals (freshness-checked per docs/SIGNALS.md) and NAMES
#     the next gate skill — names, never invokes (rule no-orchestration).
# (3) Termination sensor (Stop only): three consecutive RED verify records with the SAME
#     reason ⇒ the loop is not converging; name /investigate or /encode-mistake instead of
#     another /verify. A sensor, never a controller — it never exits 2.
#
# Claude Code passes hook input as JSON on stdin:
#   { "hook_event_name": "Stop"|"SessionStart", "session_id": "...", "cwd": "..." }
#
# Exit codes:
#   0 - always (advisory only, never blocks)
# Output: one JSON envelope on stdout via emit_advisory (systemMessage for the user;
# additionalContext for the model on SessionStart). Nothing when there is nothing to say.
# This hook WRITES NOTHING (the v3.9 handoff-<branch>.json writer — zero consumers, and an
# unquoted-heredoc JSON build the Gate API forbids — was deleted in v3.10.0).

set -euo pipefail

# --- Load shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input
EVENT=$(json_get '.hook_event_name // ""' "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))")
[ -z "$EVENT" ] && EVENT="Stop"

# --- Addressing: two roots, named once, never mixed ---
# PROJECT_DIR — the harness root; `.claude/signals` and `.claude/metrics` live here.
# REPO_ROOT   — the git toplevel; EVERY path comparison below is repo-root-relative,
#               because that is the path system `git diff --name-only` natively emits.
# Mixing the two is what silently disabled checks 4 and 6: a repo-root-relative
# `backend/src/api/x.py` was compared against a PROJECT_DIR-relative `src/api`, so the
# match could never fire and the hook exited 0 looking exactly like a clean pass.
if ! get_project_dir; then
    # Say it. A check that established nothing must not look like a check that passed.
    emit_advisory "$EVENT" "Doc-drift check skipped: project root unresolved. Set CLAUDE_PROJECT_DIR, or run the session inside a git work tree."
    exit 0
fi

git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
REPO_ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$REPO_ROOT" ] && exit 0
REPO_ROOT=$(_canonical_dir "$REPO_ROOT")   # same physical path as PROJECT_DIR, so they compare

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
        # APPROVE hands the user to the irreversible step, so the dirty-tree clause of the
        # freshness predicate (docs/SIGNALS.md) applies here and only here: a verdict at
        # commit X over a tree edited since does not describe the code being shipped.
        if worktree_dirty "$REPO_ROOT"; then
            GATE_NUDGE="WARN: review APPROVE but the working tree has uncommitted changes since the verdict — commit, then re-run /verify and /harness-review before /ship"
        else
            GATE_NUDGE="Gate state: review APPROVE — next: gstack /ship (run the pre-ship check from docs/SIGNALS.md first)"
        fi
    elif [ "$V_DEC" = "GREEN" ] && { [ -z "$R_DEC" ] || [ ! -f "$R_SIG" ] || [ "$V_SIG" -nt "$R_SIG" ]; }; then
        GATE_NUDGE="Gate state: verify GREEN with no newer review — next: /harness-review"
    fi
fi

# --- SessionStart: gate state only, then out (before any repo walk) ---
if [ "$EVENT" = "SessionStart" ]; then
    ACTIVE_PLAN=""
    if [ -d "$REPO_ROOT/docs/exec-plans/active" ]; then
        ACTIVE_PLAN=$(ls "$REPO_ROOT/docs/exec-plans/active/"*.json 2>/dev/null | head -1 | xargs -r basename 2>/dev/null || echo "")
    fi
    MSG="$GATE_NUDGE"
    [ -n "$ACTIVE_PLAN" ] && MSG="${MSG:+$MSG
}Active exec-plan: docs/exec-plans/active/${ACTIVE_PLAN} — continue it or run /lifecycle next"
    emit_advisory SessionStart "$MSG"
    exit 0
fi

# --- Termination sensor (Stop only; docs/SIGNALS.md no-change-cycle rule) ---
# Three consecutive RED records with the SAME reason means another /verify will not help.
# Same-HEAD would be wrong in both directions (RED→fix→GREEN happens at one HEAD; the loop
# that burns an afternoon commits between attempts). Reads the history log only; this
# block resolves METRICS_DIR itself and never exits 2 — a sensor, never a controller.
if command -v jq >/dev/null 2>&1 && resolve_metrics_dir "$PROJECT_DIR" "$PROJECT_DIR_SOURCE" && [ -f "$METRICS_DIR/verify.jsonl" ]; then
    LAST3=$(tail -3 "$METRICS_DIR/verify.jsonl" 2>/dev/null | jq -r 'select(.decision=="RED") | .reason // ""' 2>/dev/null || echo "")
    if [ "$(printf '%s\n' "$LAST3" | grep -c .)" -eq 3 ] && [ "$(printf '%s\n' "$LAST3" | sort -u | wc -l | tr -d ' ')" -eq 1 ]; then
        SAME_REASON=$(printf '%s\n' "$LAST3" | head -1)
        GATE_NUDGE="Gate state: 3 consecutive RED with identical reason (${SAME_REASON}) — the loop is not converging; next: /investigate (gstack) or /encode-mistake, not another /verify"
    fi
fi

# --- Ledger integrity ---
# Forks created by earlier versions of this hook survive the addressing fix, and they stay
# invisible: `.claude/` is gitignored, so every git-based check is green on all of them, and
# /harness-dashboard reads the root ledger only. The records are not corrupt — they are just
# somewhere nobody looks. Name them. Merging them back is the user's call; deleting them is
# never the answer to "where did the records go".
LEDGER_WARN=""
FORKED_LEDGERS=""
FORK_COUNT=0
while IFS= read -r cand; do
    [ -z "$cand" ] && continue
    [ "$cand" = "$PROJECT_DIR/.claude/metrics" ] && continue
    # A sibling git work tree (.gstack-worktrees/, ~/conductor/workspaces/, a submodule)
    # owns its OWN ledger — honouring that is the worktree-aware rule, not a fork. Only a
    # copy inside THIS work tree is one.
    CAND_TOP=$(git -C "$cand" rev-parse --show-toplevel 2>/dev/null || echo "")
    [ "$(_canonical_dir "$CAND_TOP")" = "$REPO_ROOT" ] || continue
    FORKED_LEDGERS="${FORKED_LEDGERS}${cand}
"
    FORK_COUNT=$((FORK_COUNT + 1))
    [ "$FORK_COUNT" -ge 5 ] && break
done < <(find "$REPO_ROOT" -maxdepth 4 \
    \( -name node_modules -o -name .git -o -name vendor -o -name dist -o -name .next \) -prune -o \
    -type d -path "*/.claude/metrics" -print 2>/dev/null || true)
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
    emit_advisory Stop "${LEDGER_WARN:+$LEDGER_WARN
}${GATE_NUDGE}"
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

# Output warnings if any — one envelope through emit_advisory (zero bytes when clean).
OUT=""
if [ -n "$WARNINGS" ]; then
    OUT=$(printf 'Documentation Drift Check\n%b\nRun /entropy-sweep for a full analysis.' "$WARNINGS")
fi
[ -n "$LEDGER_WARN" ] && OUT="${OUT:+$OUT
}$LEDGER_WARN"
[ -n "$GATE_NUDGE" ] && OUT="${OUT:+$OUT
}$GATE_NUDGE"
emit_advisory Stop "$OUT"

exit 0
