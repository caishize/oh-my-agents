#!/usr/bin/env bash
#
# Advisory hook bound to TWO events (one script, hooks.json registers it twice):
#   SessionStart — the GATE LADDER (which signal is fresh, the first typed items it hands
#                  back, the next gate skill, the active plan) injected into the MODEL's
#                  context at session open — and again on resume / compact / fork, since
#                  SessionStart fires for those too. Returns before any repo walk.
#   Stop         — the same ladder rendered for the HUMAN (systemMessage only — at Stop an
#                  additionalContext key would CONTINUE the turn), plus doc drift and the
#                  verify-loop termination sensor.
# (1) Gate ladder: ONE mapping, two renderings — never two mappings. Every rung rides a
#     FRESH signal (signal_fresh, docs/SIGNALS.md); a stale signal is a WARN, never a step.
#     The APPROVE rung IS the pre-ship check: verify GREEN AND review APPROVE, both at HEAD,
#     clean tree. It NAMES the next skill; it never invokes one (rule no-orchestration).
# (2) Doc drift (Stop only): recently modified source files vs the docs that describe them.
# (3) Termination sensor (Stop only): three consecutive RED verify records with the SAME
#     reason ⇒ the loop is not converging; name /investigate or /encode-mistake instead of
#     another /verify. A sensor, never a controller — it never exits 2.
#
# Claude Code passes hook input as JSON on stdin:
#   { "hook_event_name": "Stop"|"SessionStart", "session_id": "...", "cwd": "...",
#     "stop_hook_active": true|false (Stop) }
#
# Exit codes:
#   0 - always (advisory only, never blocks)
# Output: one JSON envelope on stdout via emit_advisory — additionalContext (model) at
# SessionStart; systemMessage (human) at Stop. Nothing when there is nothing to say.
# This hook WRITES NOTHING.

set -euo pipefail

# --- Load shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input
EVENT=$(json_get '.hook_event_name // ""' "import sys,json; print(json.load(sys.stdin).get('hook_event_name',''))")
[ -z "$EVENT" ] && EVENT="Stop"

# --- Re-entry guard (before any git/find call) ---
# When Claude Code is already continuing because of a Stop hook, this hook contributes
# ZERO bytes: re-entry episodes belong to gstack's opt-in verify-gate, which reads the same
# flag and bounds itself; a persistent gate state must never re-fire on each continuation.
STOP_ACTIVE=$(json_get '.stop_hook_active // false' "import sys,json; print(str(json.load(sys.stdin).get('stop_hook_active', False)).lower())")
[ "$STOP_ACTIVE" = "true" ] && exit 0

# --- Addressing: two roots, named once, never mixed ---
# PROJECT_DIR — the harness root; `.claude/signals` and `.claude/metrics` live here.
# REPO_ROOT   — the git toplevel; EVERY path comparison below is repo-root-relative,
#               because that is the path system `git diff --name-only` natively emits.
if ! get_project_dir; then
    # Say it. A check that established nothing must not look like a check that passed.
    emit_advisory "$EVENT" "Doc-drift check skipped: project root unresolved. Set CLAUDE_PROJECT_DIR, or run the session inside a git work tree."
    exit 0
fi

git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
REPO_ROOT=$(git -C "$PROJECT_DIR" rev-parse --show-toplevel 2>/dev/null || echo "")
[ -z "$REPO_ROOT" ] && exit 0
REPO_ROOT=$(_canonical_dir "$REPO_ROOT")   # same physical path as PROJECT_DIR, so they compare
resolve_metrics_dir "$PROJECT_DIR" "$PROJECT_DIR_SOURCE" || METRICS_DIR=""

# --- Gate ladder (advisory; the transition mapping source is docs/SIGNALS.md) ---
# Order: stale WARNs → recoverable composition skip → APPROVE (= pre-ship check) →
# REQUEST_CHANGES (first fixes) → hard NEEDS_HUMAN → RED (first failures) → YELLOW →
# GREEN-no-review → plan changed since the last verify. First match wins; each rung is one
# line and rides a FRESH signal only. Work lists come from the typed history logs
# (findings[] / failures[], docs/SIGNALS.md) — never invented.
GATE_NUDGE=""
SIG_DIR="$PROJECT_DIR/.claude/signals"
V_SIG="$SIG_DIR/verify-latest.json"; R_SIG="$SIG_DIR/review-latest.json"
ACTIVE_PLAN=""
if command -v jq >/dev/null 2>&1; then
    V_DEC=$(jq -r '.decision // ""' "$V_SIG" 2>/dev/null || echo "")
    R_DEC=$(jq -r '.decision // ""' "$R_SIG" 2>/dev/null || echo "")
    R_KIND=$(jq -r '.needs_human_kind // ""' "$R_SIG" 2>/dev/null || echo "")
    V_REASON=$(signal_fresh "$REPO_ROOT" verify-latest.json || true)   # "" ⇒ fresh
    R_REASON=$(signal_fresh "$REPO_ROOT" review-latest.json || true)
    V_FRESH=0; [ -n "$V_DEC" ] && [ -z "$V_REASON" ] && V_FRESH=1
    R_FRESH=0; [ -n "$R_DEC" ] && [ -z "$R_REASON" ] && R_FRESH=1
    # "no newer review": the verify signal is the latest verdict on this tree
    V_LATEST=0; { [ ! -f "$R_SIG" ] || [ "$V_SIG" -nt "$R_SIG" ]; } && V_LATEST=1

    # First ≤3 typed items from a history log's last line — the hand-back to the next turn.
    first_items() {   # $1 = file, $2 = jq expression yielding strings
        [ -n "$METRICS_DIR" ] && [ -f "$METRICS_DIR/$1" ] || return 0
        tail -1 "$METRICS_DIR/$1" 2>/dev/null | jq -r "$2" 2>/dev/null | head -3 | paste -sd ',' - || true
    }
    red_items() {   # first failures[].id, else the signal's reason, else a loud placeholder
        local ids; ids=$(first_items verify.jsonl '.failures[]?.id // empty')
        local why; why=$(jq -r '.reason // ""' "$V_SIG" 2>/dev/null || echo "")
        printf '%s' "${ids:-${why:-failures[] missing, see verify.jsonl}}"
    }

    if [ -n "$V_DEC" ] && [ "${V_REASON#stale}" != "$V_REASON" ]; then
        GATE_NUDGE="WARN: verify-latest.json is stale ($V_REASON) — re-run /verify"
    elif [ -n "$R_DEC" ] && [ "${R_REASON#stale}" != "$R_REASON" ]; then
        GATE_NUDGE="WARN: review-latest.json is stale ($R_REASON) — re-run /harness-review"
    elif [ "$R_DEC" = "NEEDS_HUMAN" ] && [ "$R_KIND" = "composition-skipped" ]; then
        GATE_NUDGE="Gate state: review NEEDS_HUMAN (composition-skipped) — next: re-run /harness-review with gstack composition enabled"
    elif [ "$R_FRESH" = 1 ] && [ "$R_DEC" = "APPROVE" ]; then
        # The APPROVE rung IS the pre-ship check (docs/SIGNALS.md): both signals at HEAD,
        # clean tree. APPROVE alone never names the irreversible step.
        if signal_fresh "$REPO_ROOT" verify-latest.json GREEN --advance >/dev/null \
           && signal_fresh "$REPO_ROOT" review-latest.json APPROVE --advance >/dev/null; then
            GATE_NUDGE="SHIP GATE: pass (verify GREEN + review APPROVE at HEAD, clean tree) — next: gstack /ship"
        elif worktree_dirty "$REPO_ROOT"; then
            GATE_NUDGE="WARN: review APPROVE but the working tree has uncommitted changes since the verdict — commit, then re-run /verify and /harness-review before /ship"
        elif [ "$V_FRESH" = 1 ] && [ "$V_DEC" = "RED" ]; then
            GATE_NUDGE="Gate state: review APPROVE but verify is not GREEN at HEAD (RED — first failures: $(red_items)) — fix, then /verify"
        else
            GATE_NUDGE="Gate state: review APPROVE but verify is not GREEN at HEAD (${V_DEC:-absent}) — run /verify"
        fi
    elif [ "$R_FRESH" = 1 ] && [ "$R_DEC" = "REQUEST_CHANGES" ]; then
        FIXES=$(first_items reviews.jsonl '.findings[]?.fingerprint // empty')
        GATE_NUDGE="Gate state: review REQUEST_CHANGES — first fixes: ${FIXES:-findings[] missing, see reviews.jsonl} — fix, then /verify"
    elif [ "$R_FRESH" = 1 ] && [ "$R_DEC" = "NEEDS_HUMAN" ]; then
        GATE_NUDGE="Gate state: review NEEDS_HUMAN (${R_KIND:-kind absent}) — human decision required; no automated step"
    elif [ "$V_FRESH" = 1 ] && [ "$V_DEC" = "RED" ] && [ "$V_LATEST" = 1 ]; then
        GATE_NUDGE="Gate state: verify RED — first failures: $(red_items) — fix, then /verify"
    elif [ "$V_FRESH" = 1 ] && [ "$V_DEC" = "YELLOW" ]; then
        GATE_NUDGE="Gate state: verify YELLOW ($(jq -r '.reason // "see verify.jsonl"' "$V_SIG" 2>/dev/null)) — confirm or fix, then /verify"
    elif [ "$V_FRESH" = 1 ] && [ "$V_DEC" = "GREEN" ] && [ "$V_LATEST" = 1 ]; then
        GATE_NUDGE="Gate state: verify GREEN with no newer review — next: /harness-review"
    fi

    # Plan rung (lowest priority): an active plan with in-progress work that no verify at
    # HEAD covers — the execute→verify push that does not depend on the model editing JSON.
    PLAN_FILE=$(ls "$REPO_ROOT/docs/exec-plans/active/"*.json 2>/dev/null | head -1 || true)
    if [ -n "$PLAN_FILE" ]; then
        ACTIVE_PLAN=$(basename "$PLAN_FILE")
        if [ -z "$GATE_NUDGE" ]; then
            PLAN_ROW=$(jq -r 'select(.status=="active") | [(.id // "?"), ([.tasks[]? | select(.status=="in-progress")] | length)] | @tsv' "$PLAN_FILE" 2>/dev/null || echo "")
            PLAN_ID=${PLAN_ROW%%	*}; IN_PROG=${PLAN_ROW##*	}
            if [ -n "$PLAN_ROW" ] && [ "${IN_PROG:-0}" -gt 0 ] 2>/dev/null \
               && { [ ! -f "$V_SIG" ] || [ "$PLAN_FILE" -nt "$V_SIG" ]; }; then
                GATE_NUDGE="Gate state: plan $PLAN_ID changed since the last verify ($IN_PROG in-progress) — next: /verify --plan $PLAN_ID"
            fi
        fi
    fi
fi

# --- SessionStart: gate ladder + active plan for the MODEL, then out (no repo walk) ---
if [ "$EVENT" = "SessionStart" ]; then
    MSG="$GATE_NUDGE"
    if [ -n "$ACTIVE_PLAN" ] && ! printf '%s' "$MSG" | grep -qF "${ACTIVE_PLAN%.json}"; then
        MSG="${MSG:+$MSG
}Active exec-plan: docs/exec-plans/active/${ACTIVE_PLAN} — continue it or run /lifecycle next"
    fi
    emit_advisory SessionStart "$MSG"
    exit 0
fi

# --- Termination sensor (Stop only; docs/SIGNALS.md no-change-cycle rule) ---
# Three consecutive RED records with the SAME reason means another /verify will not help.
# Reads the history log only; never exits 2 — a sensor, never a controller.
if command -v jq >/dev/null 2>&1 && [ -n "$METRICS_DIR" ] && [ -f "$METRICS_DIR/verify.jsonl" ]; then
    LAST3=$(tail -3 "$METRICS_DIR/verify.jsonl" 2>/dev/null | jq -r 'select(.decision=="RED") | .reason // ""' 2>/dev/null || echo "")
    if [ "$(printf '%s\n' "$LAST3" | grep -c .)" -eq 3 ] && [ "$(printf '%s\n' "$LAST3" | sort -u | wc -l | tr -d ' ')" -eq 1 ]; then
        SAME_REASON=$(printf '%s\n' "$LAST3" | head -1)
        GATE_NUDGE="Gate state: 3 consecutive RED with identical reason (${SAME_REASON}) — the loop is not converging; next: /investigate (gstack) or /encode-mistake, not another /verify"
    fi
fi

# Get files modified in the last commit or staged
CHANGED_FILES=$(git -C "$REPO_ROOT" diff --name-only HEAD 2>/dev/null || git -C "$REPO_ROOT" diff --name-only --staged 2>/dev/null || echo "")

if [ -z "$CHANGED_FILES" ]; then
    # Idle turn: the gate line only. No repo walk — a timed-out hook loses its WHOLE output,
    # and the gate hand-off is the part worth keeping.
    emit_advisory Stop "$GATE_NUDGE"
    exit 0
fi

# --- Ledger integrity (only on turns that changed files) ---
# Forks created by earlier versions of this hook survive the addressing fix, and they stay
# invisible: `.claude/` is gitignored, so every git-based check is green on all of them, and
# /harness-dashboard reads the root ledger only. Name them. Merging them back is the user's
# call; deleting them is never the answer to "where did the records go".
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

WARNINGS=""

# Check if architecture-significant files changed but docs weren't updated
HAS_DOC_CHANGES=false

while IFS= read -r file; do
    [ -z "$file" ] && continue
    case "$file" in
        docs/*|*.md|CLAUDE.md) HAS_DOC_CHANGES=true ;;
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

# Output — one envelope through emit_advisory (zero bytes when clean). The gate line is
# assembled FIRST so the 400-char cap trims drift text, never the hand-off.
OUT="$GATE_NUDGE"
[ -n "$LEDGER_WARN" ] && OUT="${OUT:+$OUT
}$LEDGER_WARN"
if [ -n "$WARNINGS" ]; then
    OUT="${OUT:+$OUT
}$(printf 'Documentation Drift Check\n%b\nRun /entropy-sweep for the full analysis.' "$WARNINGS")"
fi
emit_advisory Stop "$OUT"

exit 0
