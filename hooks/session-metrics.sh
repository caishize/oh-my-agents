#!/usr/bin/env bash
#
# Session metrics collector — PostToolUse for Edit/Write
# Lightweight append-only JSONL logger. Must complete in <100ms.
#
# Records ONE datum native telemetry has no concept of: the architecture LAYER of each edit
# ({ts,tool,file,layer} — the source of /harness-dashboard's layer-balance view). Tool-level
# telemetry (names, durations, accept/reject) is native OpenTelemetry's, exported to a
# collector. The v3.9 parse of a per-hook results field was deleted in v3.11.0: the field is
# not part of the PostToolUse input contract and never arrived. The Bash-leg registration went
# with it (it wrote {tool:"Bash",file:"",layer:""} lines nobody read).
#
# Input: JSON on stdin from Claude Code
# Output: Appends one line to .claude/metrics/session-{date}.jsonl
# Always exits 0 (never blocks).

set -euo pipefail

# --- Load shared utilities ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input

TOOL_NAME=$(get_tool_name)
FILE_PATH=$(get_file_path)

# --- Determine layer from file path ---
LAYER=""
if [ -n "$FILE_PATH" ]; then
    # Try fast fallback detection first (no harness.json needed)
    LAYER=$(_resolve_layer_fallback "$FILE_PATH" 2>/dev/null || echo "")
    if [ -z "$LAYER" ]; then
        # Only load harness config if fallback didn't match
        find_harness_json "$(dirname "$FILE_PATH")" 2>/dev/null || true
        if [ -n "$HARNESS_FILE" ]; then
            load_harness_config "$HARNESS_FILE"
            LAYER=$(_resolve_layer_from_harness "$FILE_PATH" 2>/dev/null || echo "")
        fi
    fi
    # Classify non-layer files
    if [ -z "$LAYER" ]; then
        case "$FILE_PATH" in
            */docs/*|*.md)       LAYER="docs" ;;
            */test/*|*.test.*|*.spec.*) LAYER="test" ;;
            *)                   LAYER="other" ;;
        esac
    fi
fi

# --- Determine metrics directory ---
# ONE ledger per project, addressed off the project root (common.sh get_project_dir) — never
# off the session cwd. Addressing off cwd used to fork the ledger: `cd backend` once and this
# hook created backend/.claude/metrics/, after which the marker walk found that copy first
# and routed the whole subtree into it. The fork is invisible (all of it gitignored) and
# self-reinforcing, so the fix is at both ends: address off the root, and create a ledger
# only under an authoritative root (resolve_metrics_dir).
if ! get_project_dir "$FILE_PATH"; then
    # Root unestablished — record nothing rather than invent a home for it.
    exit 0
fi

if ! resolve_metrics_dir "$PROJECT_DIR" "$PROJECT_DIR_SOURCE"; then
    exit 0
fi

# --- Append JSONL line ---
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_PART=$(date -u +"%Y-%m-%d")
METRICS_FILE="${METRICS_DIR}/session-${DATE_PART}.jsonl"

# Build JSON without jq for speed — exactly {ts,tool,file,layer}
LINE="{\"ts\":\"${TS}\",\"tool\":\"${TOOL_NAME}\",\"file\":\"${FILE_PATH}\",\"layer\":\"${LAYER}\"}"

# Use flock to prevent JSONL corruption from parallel Claude Code sessions (gstack Conductor)
LOCK_FILE="${METRICS_FILE}.lock"
if command -v flock >/dev/null 2>&1; then
    (flock -w 2 200 && echo "$LINE" >> "$METRICS_FILE") 200>"$LOCK_FILE" 2>/dev/null || \
        echo "$LINE" >> "$METRICS_FILE" 2>/dev/null || true
else
    # macOS: flock not available, use atomic append (>> is typically atomic for small writes)
    echo "$LINE" >> "$METRICS_FILE" 2>/dev/null || true
fi

# --- Log rotation: remove JSONL files older than 30 days ---
if [ -f "$METRICS_FILE" ]; then
    LINE_COUNT=$(wc -l < "$METRICS_FILE" 2>/dev/null || echo "99")
    if [ "$LINE_COUNT" -le 1 ]; then
        find "$METRICS_DIR" -name "session-*.jsonl" -mtime +30 -delete 2>/dev/null || true
    fi
fi

exit 0
