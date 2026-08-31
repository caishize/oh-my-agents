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
#
# Three GUIDE sections (all advisory, always exit 0):
#   1. Handoff checklist — active tasks missing acceptance/context_files/failing_tests
#   2. Schema drift — top-level keys not defined in templates/execution-plan.json, and
#      prose-shaped acceptance strings (acceptance must be a runnable command / test name)
#   3. Plan-completion nudge — every task done/skipped but plan still 'active' and no
#      FRESH GREEN verify signal exists ⇒ name /verify as the next step (names, never
#      invokes — rule no-orchestration; suppressed when a fresh GREEN already covers it)
TEMPLATE_FILE="${SCRIPT_DIR}/../templates/execution-plan.json"

# Project root for the signal read below. Addressed off the project (common.sh
# get_project_dir), never off the session cwd and never off $(pwd): a guessed root reads a
# signal that isn't there, and "no signal" is indistinguishable from "signal says OK".
# Unresolved stays EMPTY — sections 1 and 2 need no root, and section 3 says it didn't look.
get_project_dir "$FILE_PATH" || true

GUIDANCE=""
if command -v python3 >/dev/null 2>&1; then
    GUIDANCE=$(printf '%s' "$CONTENT" | python3 -c '
import sys, json, os, re
try:
    plan = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)  # mid-edit / not valid JSON yet — stay silent
if not isinstance(plan, dict):
    sys.exit(0)
template_file, project_dir, plan_path = sys.argv[1], sys.argv[2], sys.argv[3]

# --- 1. Handoff checklist ---
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
    print("HANDOFF")
    print("\n".join(lines))

# --- 2. Schema drift (template is the SSOT) + prose acceptance ---
drift = []
try:
    with open(template_file) as f:
        known = set(json.load(f).get("properties", {}).keys())
except Exception:
    known = set()
if known:
    unknown = [k for k in plan.keys() if k not in known]
    if unknown:
        drift.append("  - top-level keys not in templates/execution-plan.json: %s" % ", ".join(sorted(unknown)))
CMDISH = re.compile(r"(^\./|^[\w.-]+/|\b(test|spec)\w*\b|\b(npm|pnpm|yarn|npx|pytest|jest|vitest|cargo|go|make|mvn|gradle|sh|bash|python3?|node|rspec|phpunit|dotnet|tsc|eslint|ruff)\b)", re.I)
for t in (plan.get("tasks") or []):
    if not isinstance(t, dict):
        continue
    acc = t.get("acceptance")
    if isinstance(acc, str) and len(acc.split()) > 6 and not CMDISH.search(acc):
        drift.append("  - task %s: acceptance reads as prose, not a runnable command/test name" % t.get("id", "?"))
if drift:
    print("DRIFT")
    print("\n".join(drift))

# --- 3. Plan-completion nudge (push, not poll) ---
tasks = [t for t in (plan.get("tasks") or []) if isinstance(t, dict)]
m = plan.get("metrics") or {}
all_done = False
if tasks:
    all_done = all(str(t.get("status", "")).lower() in ("done", "skipped") for t in tasks)
elif isinstance(m.get("tasks_total"), int) and m.get("tasks_total", 0) > 0:
    all_done = m.get("tasks_done") == m.get("tasks_total")
if all_done and str(plan.get("status", "")).lower() == "active":
    fresh_green = False
    if project_dir:
        sig = os.path.join(project_dir, ".claude", "signals", "verify-latest.json")
        try:
            with open(sig) as f:
                s = json.load(f)
            fresh_green = (s.get("decision") == "GREEN"
                           and os.path.getmtime(sig) > os.path.getmtime(plan_path))
        except Exception:
            fresh_green = False
    if not fresh_green:
        n = len(tasks) or m.get("tasks_total", 0)
        print("COMPLETE")
        print("  All %d/%d tasks done — next: /verify --plan %s" % (n, n, plan.get("id", "?")))
        if not project_dir:
            print("  (project root unresolved — the verify signal was not read, not found GREEN)")
' "$TEMPLATE_FILE" "$PROJECT_DIR" "$FILE_PATH" 2>/dev/null || echo "")
fi

if [ -n "$GUIDANCE" ]; then
    {
        if printf '%s' "$GUIDANCE" | grep -q '^HANDOFF$'; then
            echo "Plan handoff checklist (feedforward — not blocking): some active tasks are"
            echo "under-specified for the Planner→Generator handoff. A context-reset Generator"
            echo "needs these to start without re-deriving intent:"
            printf '%s\n' "$GUIDANCE" | sed -n '/^HANDOFF$/,/^\(DRIFT\|COMPLETE\)$/p' | grep '^  -' || true
            echo "  Fix: add acceptance criteria, context_files (read-for-context), and the"
            echo "  failing_tests gate per templates/execution-plan.json before marking in_progress."
        fi
        if printf '%s' "$GUIDANCE" | grep -q '^DRIFT$'; then
            echo "Plan schema GUIDE (templates/execution-plan.json is the source of truth):"
            printf '%s\n' "$GUIDANCE" | sed -n '/^DRIFT$/,/^COMPLETE$/p' | grep '^  -' || true
        fi
        if printf '%s' "$GUIDANCE" | grep -q '^COMPLETE$'; then
            echo "Plan complete (advisory — names the next skill, never invokes it):"
            printf '%s\n' "$GUIDANCE" | sed -n '/^COMPLETE$/,$p' | grep '^  ' || true
        fi
    } >&2
fi

exit 0
