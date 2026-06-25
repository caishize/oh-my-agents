#!/usr/bin/env bash
#
# Execution-plan validation hook (feedforward GUIDE, not a barrier).
# Triggered on PreToolUse for Edit/Write to docs/exec-plans/**/*.json.
#
# Why feedforward: the Planner→Generator handoff fails when a Generator starts on an
# under-specified task (OpenAI: agents waste 15–20% effort rediscovering Planner intent).
# This nudges the author to fill acceptance criteria / context_files / failing_tests BEFORE
# a task is marked in_progress — so the mistake is prevented, not detected after the fact.
#
# GUIDE semantics: this NEVER blocks (always exit 0). It only surfaces a checklist on stderr
# when an in_progress/done task is missing its handoff fields. Blocking plan edits would block
# the very act of authoring the plan — wrong. Mechanical enforcement stays in arch/safety hooks.
#
# Exit codes:
#   0 - always (advisory only)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

read_input

FILE_PATH=$(get_file_path)
[ -z "$FILE_PATH" ] && exit 0

# Only execution-plan JSON files under docs/exec-plans/
case "$FILE_PATH" in
    *docs/exec-plans/*.json) : ;;
    *) exit 0 ;;
esac

CONTENT=$(get_content)
[ -z "$CONTENT" ] && exit 0

# Inspect the new plan content. Parse with python3 (preferred) or jq; if neither is present
# or the JSON is mid-edit/invalid, stay silent — this is a guide, never a blocker.
GUIDANCE=""
if command -v python3 >/dev/null 2>&1; then
    GUIDANCE=$(printf '%s' "$CONTENT" | python3 -c '
import sys, json
try:
    plan = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)  # mid-edit / not valid JSON yet — stay silent
if not isinstance(plan, dict):
    sys.exit(0)
ACTIVE = {"in_progress", "in-progress", "done"}
lines = []
for t in (plan.get("tasks") or []):
    if not isinstance(t, dict):
        continue
    if str(t.get("status", "")).lower() not in ACTIVE:
        continue
    tid = t.get("id", "?")
    missing = []
    acc = t.get("acceptance")
    if not acc or (isinstance(acc, (list, str)) and len(acc) == 0):
        missing.append("acceptance")
    if not t.get("context_files") and not t.get("context"):
        missing.append("context_files")
    if not t.get("failing_tests"):
        missing.append("failing_tests")
    if missing:
        lines.append("  - task %s [%s]: missing %s" % (tid, t.get("status"), ", ".join(missing)))
if lines:
    print("\n".join(lines))
' 2>/dev/null || echo "")
fi

if [ -n "$GUIDANCE" ]; then
    {
        echo "Plan handoff checklist (feedforward — not blocking): some active tasks are"
        echo "under-specified for the Planner→Generator handoff. A context-reset Generator"
        echo "needs these to start without re-deriving intent:"
        echo "$GUIDANCE"
        echo "  Fix: add acceptance criteria, context_files (read-for-context), and the"
        echo "  failing_tests gate per templates/execution-plan.json before marking in_progress."
    } >&2
fi

exit 0
