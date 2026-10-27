#!/usr/bin/env bash
#
# Antigravity CLI adapter & distribution regression test suite for oh-my-agents.
# Usage: AGY_BIN=/path/to/agy bash tests/test-antigravity.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ADAPTER="${REPO_ROOT}/hooks/antigravity-adapter.py"
AGY_BIN="${AGY_BIN:-$(command -v agy 2>/dev/null || echo "")}"

PASS=0
FAIL=0
TOTAL=0

assert_true() {
    local name="$1"; shift
    TOTAL=$((TOTAL + 1))
    if "$@"; then
        PASS=$((PASS + 1))
        echo "PASS: $name"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $name"
    fi
}

run_adapter() {
    local event="$1"; shift
    local input="$1"; shift
    printf '%s' "$input" | python3 "$ADAPTER" "$event" "$@"
}

assert_pre_decision() {
    local name="$1"
    local expected_decision="$2"
    local expected_substr="$3"
    local input="$4"
    shift 4
    TOTAL=$((TOTAL + 1))
    local out rc=0
    out=$(printf '%s' "$input" | python3 "$ADAPTER" PreToolUse "$@" 2>/dev/null) || rc=$?
    if [ "$rc" -ne 0 ]; then
        FAIL=$((FAIL + 1))
        echo "FAIL: $name (adapter exited $rc, expected 0 with JSON decision)"
        return
    fi
    if printf '%s' "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
want_dec, want_sub = sys.argv[1], sys.argv[2]
assert d.get("decision") == want_dec, f"decision={d.get('"'"'decision'"'"')} != {want_dec}"
for forbidden in ("permissionOverrides", "auto_approve", "overwrite", "continue"):
    assert forbidden not in d, f"forbidden key {forbidden} in output"
if want_sub:
    reason = d.get("reason", "")
    assert want_sub.lower() in reason.lower(), f"{want_sub!r} not in {reason!r}"
' "$expected_decision" "$expected_substr" 2>/dev/null; then
        PASS=$((PASS + 1))
        echo "PASS: $name"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL: $name (output: $out)"
    fi
}

echo "=== oh-my-agents Antigravity Adapter & Distribution Tests ==="

# =============================================
# 1. Manifests, Rules, and Native Strict Validation
# =============================================
echo ""
echo "--- Manifests & Native Validation ---"

assert_true "manifest: root plugin.json exists and is valid Antigravity schema" python3 -c '
import json, sys
p = json.load(open(sys.argv[1]))
allowed = {"name", "description", "version", "displayName", "logo", "suggestedPrompts", "disabled", "skills"}
unknown = set(p.keys()) - allowed
assert not unknown, f"unknown keys in plugin.json: {unknown}"
assert p["name"] == "oh-my-agents"
' "$REPO_ROOT/plugin.json"

assert_true "manifest: root hooks.json uses Antigravity named-hook map and matches native + docs tools" python3 -c '
import json, sys
h = json.load(open(sys.argv[1]))
assert "hooks" not in h, "root hooks.json must not use legacy top-level hooks key"
spec = h["oh-my-agents"]
assert isinstance(spec["SessionStart"], list) and "command" in spec["SessionStart"][0]
assert isinstance(spec["Stop"], list) and "command" in spec["Stop"][0]
expected_edit_matcher = "write_file|edit_file|write_to_file|replace_file_content|multi_replace_file_content"
pre_matchers = {g["matcher"] for g in spec["PreToolUse"]}
assert expected_edit_matcher in pre_matchers
assert "run_command" in pre_matchers
post_matchers = {g["matcher"] for g in spec["PostToolUse"]}
assert expected_edit_matcher in post_matchers
for ev, entries in spec.items():
    for entry in entries:
        handlers = entry["hooks"] if isinstance(entry, dict) and "hooks" in entry else [entry]
        for x in handlers:
            assert set(x.keys()) <= {"type", "command", "timeout"}, f"invalid handler keys: {x}"
' "$REPO_ROOT/hooks.json"

assert_true "manifest: hooks/hooks.json moved to .claude-plugin/hooks.json (no strict warning)" \
    bash -c "[ ! -e '$REPO_ROOT/hooks/hooks.json' ] && [ -f '$REPO_ROOT/.claude-plugin/hooks.json' ]"

assert_true "rules: rules/AGENTS.md has valid YAML trigger frontmatter and no phantom adapter audit command" python3 -c '
import sys
text = open(sys.argv[1]).read()
assert text.startswith("---\n"), "missing frontmatter start"
parts = text.split("---\n", 2)
assert len(parts) >= 3, "unclosed frontmatter"
assert "trigger: always_on" in parts[1], "missing trigger: always_on"
assert "antigravity-adapter.py audit" not in text
' "$REPO_ROOT/rules/AGENTS.md"

if [ -n "$AGY_BIN" ] && [ -x "$AGY_BIN" ]; then
    VAL_OUT=$("$AGY_BIN" plugin validate "$REPO_ROOT" --strict --json 2>&1) && VAL_RC=0 || VAL_RC=$?
    assert_true "agy plugin validate --strict --json exits 0 with 0 findings" python3 -c '
import json, sys
rc = int(sys.argv[1])
assert rc == 0, f"exit code {rc}: {sys.argv[2]}"
data = json.loads(sys.argv[2])
assert data["manifest"] == "plugin.json"
assert data["components"]["skills"] == 11
assert data["components"]["hooks"] == 1
assert data["components"]["rules"] == 1
assert data["findings"] == [], f"unexpected findings: {data}"
' "$VAL_RC" "$VAL_OUT"

    SMOKE_HOME=$(mktemp -d)
    SMOKE_OUT=$(HOME="$SMOKE_HOME" XDG_CONFIG_HOME="$SMOKE_HOME/.config" XDG_CACHE_HOME="$SMOKE_HOME/.cache" AGY_CLI_DISABLE_AUTO_UPDATE=true \
        "$AGY_BIN" plugin install "$REPO_ROOT" 2>&1) && SMOKE_RC=0 || SMOKE_RC=$?
    LIST_OUT=$(HOME="$SMOKE_HOME" XDG_CONFIG_HOME="$SMOKE_HOME/.config" XDG_CACHE_HOME="$SMOKE_HOME/.cache" AGY_CLI_DISABLE_AUTO_UPDATE=true \
        "$AGY_BIN" plugin list --json 2>&1) || true
    INST_DIR="$SMOKE_HOME/.gemini/config/plugins/oh-my-agents"
    INST_VAL=$(HOME="$SMOKE_HOME" XDG_CONFIG_HOME="$SMOKE_HOME/.config" XDG_CACHE_HOME="$SMOKE_HOME/.cache" AGY_CLI_DISABLE_AUTO_UPDATE=true \
        "$AGY_BIN" plugin validate "$INST_DIR" --strict --json 2>&1) && INST_RC=0 || INST_RC=$?
    assert_true "disposable HOME: agy plugin install + list + strict validate succeed" python3 -c '
import json, sys
assert int(sys.argv[1]) == 0, sys.argv[2]
assert int(sys.argv[3]) == 0, sys.argv[4]
plugins = json.loads(sys.argv[5])
assert len(plugins) == 1
p = plugins[0]
assert p["name"] == "oh-my-agents" and p["enabled"] is True and p["source"] == "antigravity"
assert len(p["skills"]) == 11
assert p["rules"] == ["AGENTS.md"]
assert p["hooks"] == ["oh-my-agents"]
val = json.loads(sys.argv[4])
assert val["findings"] == []
' "$SMOKE_RC" "$SMOKE_OUT" "$INST_RC" "$INST_VAL" "$LIST_OUT"
    rm -rf "$SMOKE_HOME"
else
    echo "SKIP: native agy CLI binary not provided via AGY_BIN or PATH"
fi

# =============================================
# 2. PreToolUse Tool Mappings (Observed Native + Documented Variants)
# =============================================
echo ""
echo "--- PreToolUse Tool Mappings (write_file, edit_file, write_to_file, replace_file_content, multi_replace_file_content, run_command) ---"

# Observed native CLI tools: write_file and edit_file
assert_pre_decision "write_file (native): allow valid lower-layer import" "allow" "" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_file","args":{"Path":"/project/src/service/user.ts","Content":"import { User } from \"../types/user\";\nexport const u = 1;\n","Overwrite":false}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "write_file (native): block upward layer import (types -> ui)" "deny" "Layer violation" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_file","args":{"Path":"/project/src/types/user.ts","Content":"import { Button } from \"../ui/button\";\n","Overwrite":true}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "write_file (native): block hardcoded AWS access key" "deny" "AWS Access Key" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_file","args":{"Path":"/project/src/service/aws.ts","Content":"const k = \"AKIAIOSFODNN7EXAMPLE\";\n","Overwrite":false}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "edit_file (native): allow clean edit" "allow" "" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"edit_file","args":{"Path":"/project/src/service/auth.ts","Target":"const a = 1;","Replacement":"const a = 2;"}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "edit_file (native): block upward layer import (service -> ui)" "deny" "Layer violation" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"edit_file","args":{"Path":"/project/src/service/auth.ts","Target":"const a = 1;","Replacement":"import { Modal } from \"../ui/modal\";"}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "edit_file (native): block hardcoded GitHub token" "deny" "GitHub Personal Access Token" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"edit_file","args":{"Path":"/project/src/service/auth.ts","Target":"const t = \"\";","Replacement":"const t = \"ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn\";"}}}' \
    arch-check.sh safety-check.sh

# Documented variants: write_to_file, replace_file_content, multi_replace_file_content
assert_pre_decision "write_to_file: allow valid lower-layer import" "allow" "" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_to_file","args":{"TargetFile":"/project/src/service/user.ts","CodeContent":"import { User } from \"../types/user\";\nexport const u = 1;\n"}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "write_to_file: block upward layer import (types -> ui)" "deny" "Layer violation" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_to_file","args":{"TargetFile":"/project/src/types/user.ts","CodeContent":"import { Button } from \"../ui/button\";\n"}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "replace_file_content: allow clean edit" "allow" "" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"replace_file_content","args":{"TargetFile":"/project/src/service/auth.ts","TargetContent":"const a = 1;","ReplacementContent":"const a = 2;"}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "replace_file_content: block upward layer import (service -> ui)" "deny" "Layer violation" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"replace_file_content","args":{"TargetFile":"/project/src/service/auth.ts","TargetContent":"const a = 1;","ReplacementContent":"import { Modal } from \"../ui/modal\";"}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "multi_replace_file_content: allow multi-chunk clean edit" "allow" "" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"multi_replace_file_content","args":{"TargetFile":"/project/src/service/auth.ts","ReplacementChunks":[{"TargetContent":"a","ReplacementContent":"import { User } from \"../types/user\";"},{"TargetContent":"b","ReplacementContent":"export const ok = true;"}]}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "multi_replace_file_content: block when 2nd chunk has layer violation" "deny" "Layer violation" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"multi_replace_file_content","args":{"TargetFile":"/project/src/types/user.ts","ReplacementChunks":[{"TargetContent":"a","ReplacementContent":"export type ID = string;"},{"TargetContent":"b","ReplacementContent":"import { View } from \"../ui/view\";"}]}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "multi_replace_file_content: block when 2nd chunk has hardcoded secret" "deny" "Hardcoded credential" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"multi_replace_file_content","args":{"TargetFile":"/project/src/service/auth.ts","ReplacementChunks":[{"TargetContent":"a","ReplacementContent":"const x = 1;"},{"TargetContent":"b","ReplacementContent":"const password = \"supersecret123\";"}]}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "multi_replace_file_content: multi-file chunks block when 2nd file violates layer" "deny" "Layer violation" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"multi_replace_file_content","args":{"ReplacementChunks":[{"TargetFile":"/project/src/service/ok.ts","ReplacementContent":"export const ok = 1;"},{"TargetFile":"/project/src/repo/bad.ts","ReplacementContent":"import { Page } from \"../ui/page\";"}]}}}' \
    arch-check.sh safety-check.sh

assert_pre_decision "run_command: allow safe command" "allow" "" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"run_command","args":{"CommandLine":"npm test","Cwd":"/project"}}}' \
    bash-safety-check.sh

assert_pre_decision "run_command: block inline GitHub token in curl" "deny" "GitHub token" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"run_command","args":{"CommandLine":"curl -H \"Authorization: token ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmn\" https://api.github.com"}}}' \
    bash-safety-check.sh

# Test-only deterministic synthetic fixture composed at runtime (not a real credential)
SYNTHETIC_BEARER_PREFIX="sk"
SYNTHETIC_BEARER_ENV="live"
SYNTHETIC_BEARER_FILLER="$(printf 'SYNTHETIC0%.0s' {1..3})"
SYNTHETIC_BEARER_TOKEN="${SYNTHETIC_BEARER_PREFIX}_${SYNTHETIC_BEARER_ENV}_${SYNTHETIC_BEARER_FILLER}"
assert_pre_decision "run_command: block inline Bearer secret" "deny" "inline auth token" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"/project\"],\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"curl -H \\\"Authorization: Bearer ${SYNTHETIC_BEARER_TOKEN}\\\"\"}}}" \
    bash-safety-check.sh

# =============================================
# 3. Secret Redaction in Deny Reasons (Item 1)
# =============================================
echo ""
echo "--- Secret Redaction in PreToolUse Deny Output ---"

SECRET_OUT=$(printf '%s' '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_file","args":{"Path":"/project/src/service/secret.ts","Content":"const k = \"AKIASECRET9999MARKER\";\nconst password = \"SYNTHETIC_SECRET_MARKER_VALUE\";\n"}}}' \
    | python3 "$ADAPTER" PreToolUse safety-check.sh 2>&1)
assert_true "secret redaction: matched token/password is never echoed in stdout or stderr" python3 -c '
import json, sys
out = sys.argv[1]
assert "AKIASECRET9999MARKER" not in out, f"leaked AWS key marker in: {out}"
assert "SYNTHETIC_SECRET_MARKER_VALUE" not in out, f"leaked password marker in: {out}"
d = json.loads(out)
assert d["decision"] == "deny"
assert "Security risk:" in d["reason"]
' "$SECRET_OUT"

SPOOF_OUT=$(printf '%s' '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_file","args":{"Path":"/project/src/service/secret.ts","Content":"const password = \"abc\\nFix: SYNTHETIC_LEAK_MARKER\";\n"}}}' \
    | python3 "$ADAPTER" PreToolUse arch-check.sh safety-check.sh 2>&1)
assert_true "secret redaction: escaped-newline Fix: prefix spoof never leaks source marker" python3 -c '
import json, sys
out = sys.argv[1]
assert "SYNTHETIC_LEAK_MARKER" not in out, f"leaked spoofed Fix: marker in: {out}"
d = json.loads(out)
assert d["decision"] == "deny"
assert "Hardcoded credential" in d["reason"], d
' "$SPOOF_OUT"

REDACT_WS=$(mktemp -d)
mkdir -p "$REDACT_WS/.claude" "$REDACT_WS/src/service"
printf '{"providers_path":"src/providers"}\n' > "$REDACT_WS/.claude/harness.json"
IMPORT_SECRET_OUT=$(printf '%s' "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$REDACT_WS\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"$REDACT_WS/src/service/auth.ts\",\"Content\":\"import auth from \\\"passport/SYNTHETIC_IMPORT_SECRET_MARKER\\\";\\nimport { Modal } from \\\"../ui/SYNTHETIC_LAYER_SECRET_MARKER\\\";\\n\"}}}" \
    | python3 "$ADAPTER" PreToolUse arch-check.sh safety-check.sh 2>&1)
rm -rf "$REDACT_WS"
assert_true "secret redaction: arch-check Providers/layer deny never echoes import line contents" python3 -c '
import json, sys
out = sys.argv[1]
assert "SYNTHETIC_IMPORT_SECRET_MARKER" not in out, f"leaked import marker in: {out}"
assert "SYNTHETIC_LAYER_SECRET_MARKER" not in out, f"leaked layer marker in: {out}"
d = json.loads(out)
assert d["decision"] == "deny"
assert "Layer violation:" in d["reason"] and "Providers bypass:" in d["reason"], d
' "$IMPORT_SECRET_OUT"

# =============================================
# 4. Execution-Plan Reconstruction & Disambiguation (Item 3)
# =============================================
echo ""
echo "--- Execution-Plan Feedforward Validation & Disambiguation ---"

PLAN_WS=$(mktemp -d)
git init -q "$PLAN_WS"
mkdir -p "$PLAN_WS/docs/exec-plans/active" "$PLAN_WS/.claude/signals"
cat << 'EOF' > "$PLAN_WS/docs/exec-plans/active/p.json"
{
  "id": "plan-1",
  "status": "active",
  "tasks": [
    {
      "id": "t-1",
      "status": "pending",
      "acceptance": "pytest tests/test_one.py",
      "context_files": ["src/one.py"],
      "failing_tests": ["tests/test_one.py"]
    },
    {
      "id": "t-2",
      "status": "pending"
    }
  ]
}
EOF

assert_pre_decision "plan-validation: write_file surfaces handoff checklist on under-specified in-progress task" \
    "allow" "Plan handoff checklist" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$PLAN_WS\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"docs/exec-plans/active/p.json\",\"Content\":\"{\\\"id\\\":\\\"plan-1\\\",\\\"status\\\":\\\"active\\\",\\\"tasks\\\":[{\\\"id\\\":\\\"t-2\\\",\\\"status\\\":\\\"in-progress\\\"}]}\"}}}" \
    plan-validation-check.sh

assert_pre_decision "plan-validation: repeated target without StartLine/EndLine or AllowMultiple denies fail-closed" \
    "deny" "Ambiguous TargetContent" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$PLAN_WS\"],\"toolCall\":{\"name\":\"replace_file_content\",\"args\":{\"TargetFile\":\"docs/exec-plans/active/p.json\",\"TargetContent\":\"\\\"status\\\": \\\"pending\\\"\",\"ReplacementContent\":\"\\\"status\\\": \\\"in-progress\\\"\"}}}" \
    plan-validation-check.sh

assert_pre_decision "plan-validation: StartLine/EndLine selecting 1st task (well-specified) has no handoff warning" \
    "allow" "" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$PLAN_WS\"],\"toolCall\":{\"name\":\"replace_file_content\",\"args\":{\"TargetFile\":\"docs/exec-plans/active/p.json\",\"StartLine\":5,\"EndLine\":12,\"TargetContent\":\"\\\"status\\\": \\\"pending\\\"\",\"ReplacementContent\":\"\\\"status\\\": \\\"in-progress\\\"\"}}}" \
    plan-validation-check.sh

assert_pre_decision "plan-validation: StartLine/EndLine selecting 2nd task (t-2 missing handoff fields) warns on t-2" \
    "allow" "task t-2 [in-progress]: missing acceptance" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$PLAN_WS\"],\"toolCall\":{\"name\":\"replace_file_content\",\"args\":{\"TargetFile\":\"docs/exec-plans/active/p.json\",\"StartLine\":13,\"EndLine\":16,\"TargetContent\":\"\\\"status\\\": \\\"pending\\\"\",\"ReplacementContent\":\"\\\"status\\\": \\\"in-progress\\\"\"}}}" \
    plan-validation-check.sh

assert_pre_decision "plan-validation: edit_file replaces all occurrences and warns on under-specified t-2" \
    "allow" "task t-2 [in-progress]: missing acceptance" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$PLAN_WS\"],\"toolCall\":{\"name\":\"edit_file\",\"args\":{\"Path\":\"docs/exec-plans/active/p.json\",\"Target\":\"\\\"status\\\": \\\"pending\\\"\",\"Replacement\":\"\\\"status\\\": \\\"in-progress\\\"\"}}}" \
    plan-validation-check.sh

assert_pre_decision "plan-validation: multi_replace_file_content with range-scoped chunks reconstructs both and warns on t-2" \
    "allow" "task t-2 [in-progress]: missing acceptance" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$PLAN_WS\"],\"toolCall\":{\"name\":\"multi_replace_file_content\",\"args\":{\"TargetFile\":\"docs/exec-plans/active/p.json\",\"ReplacementChunks\":[{\"StartLine\":5,\"EndLine\":12,\"TargetContent\":\"\\\"status\\\": \\\"pending\\\"\",\"ReplacementContent\":\"\\\"status\\\": \\\"done\\\"\"},{\"StartLine\":13,\"EndLine\":16,\"TargetContent\":\"\\\"status\\\": \\\"pending\\\"\",\"ReplacementContent\":\"\\\"status\\\": \\\"in-progress\\\"\"}]}}}" \
    plan-validation-check.sh

rm -rf "$PLAN_WS"

# =============================================
# 5. Multi-Workspace Containment, Path Safety & Spaces (Item 2 & Item 5)
# =============================================
echo ""
echo "--- Multi-Workspace Routing, Path Containment & Special Filenames ---"

MW_BASE=$(mktemp -d)
WS0="$MW_BASE/ws zero"
WS1="$MW_BASE/ws one"
WS_EVIL="$MW_BASE/ws zero-evil"
mkdir -p "$WS0/src/service" "$WS0/.claude/metrics" "$WS1/src/service" "$WS1/.claude/metrics" "$WS_EVIL/src/service"
git init -q "$WS0"
git init -q "$WS1"

# Ambient CLAUDE_PROJECT_DIR pointing to WS0 must NOT hijack an edit targeting WS1
CLAUDE_PROJECT_DIR="$WS0" run_adapter PostToolUse \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$WS0\",\"$WS1\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"$WS1/src/service/order.ts\",\"Content\":\"export const o = 1;\"}}}" \
    session-metrics.sh >/dev/null

assert_true "multi-workspace: edit under workspacePaths[1] records only in WS1 ledger, never WS0" python3 -c '
import glob, json, sys
ws0, ws1 = sys.argv[1], sys.argv[2]
assert glob.glob(ws0 + "/.claude/metrics/session-*.jsonl") == []
files1 = glob.glob(ws1 + "/.claude/metrics/session-*.jsonl")
assert len(files1) == 1
rec = json.loads(open(files1[0]).readlines()[-1])
assert rec["layer"] == "service" and rec["file"].endswith("src/service/order.ts")
' "$WS0" "$WS1"

assert_pre_decision "path containment: prefix trick (/ws zero-evil vs /ws zero) is denied fail-closed" \
    "deny" "outside approved workspacePaths" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$WS0\",\"$WS1\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"$WS_EVIL/src/service/x.ts\",\"Content\":\"export const x = 1;\"}}}" \
    arch-check.sh safety-check.sh

assert_pre_decision "path containment: ../ traversal escaping workspace is denied fail-closed" \
    "deny" "outside approved workspacePaths" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$WS0\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"$WS0/../outside.ts\",\"Content\":\"export const x = 1;\"}}}" \
    arch-check.sh safety-check.sh

assert_pre_decision "path containment: run_command Cwd outside workspacePaths is denied fail-closed" \
    "deny" "outside approved workspacePaths" \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$WS0\"],\"toolCall\":{\"name\":\"run_command\",\"args\":{\"CommandLine\":\"ls\",\"Cwd\":\"$WS_EVIL\"}}}" \
    bash-safety-check.sh

# Item 5: Filename containing double-quote and backslash remains valid JSONL in session-metrics.sh
WEIRD_REL='src/service/weird"quote\file.ts'
WEIRD_PAYLOAD=$(python3 -c '
import json, sys
ws1, rel = sys.argv[1], sys.argv[2]
print(json.dumps({
    "conversationId": "c1",
    "workspacePaths": [ws1],
    "toolCall": {
        "name": "edit_file",
        "args": {"Path": ws1 + "/" + rel, "Target": "a", "Replacement": "b"}
    }
}))
' "$WS1" "$WEIRD_REL")
run_adapter PostToolUse "$WEIRD_PAYLOAD" session-metrics.sh >/dev/null
assert_true "metrics JSONL: filename containing quote and backslash serializes as valid JSON" python3 -c '
import glob, json, sys
ws1, rel = sys.argv[1], sys.argv[2]
files = glob.glob(ws1 + "/.claude/metrics/session-*.jsonl")
assert len(files) == 1
lines = [json.loads(line) for line in open(files[0])]
assert lines[-1]["file"].endswith(rel), lines[-1]
' "$WS1" "$WEIRD_REL"

rm -rf "$MW_BASE"

# =============================================
# 6. Fail-Closed Blocking on Malformed Input
# =============================================
echo ""
echo "--- Fail-Closed Malformed Input Handling ---"

assert_pre_decision "malformed: empty input denies" "deny" "Empty PreToolUse" \
    "" arch-check.sh

assert_pre_decision "malformed: invalid JSON denies" "deny" "Malformed PreToolUse" \
    "{not json" arch-check.sh

assert_pre_decision "malformed: JSON array root denies" "deny" "Expected JSON object" \
    "[]" arch-check.sh

assert_pre_decision "malformed: missing toolCall denies" "deny" "toolCall" \
    '{"conversationId":"c1","workspacePaths":["/project"]}' arch-check.sh

assert_pre_decision "malformed: missing toolCall.args denies" "deny" "toolCall.args" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_file"}}' arch-check.sh

assert_pre_decision "malformed: unknown tool name denies" "deny" "Unhandled PreToolUse tool" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"unknown_tool","args":{}}}' arch-check.sh

assert_pre_decision "malformed: write_file missing Content denies" "deny" "Content" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_file","args":{"Path":"/project/a.ts"}}}' arch-check.sh

assert_pre_decision "malformed: write_file combining Overwrite=true and Append=true denies" "deny" "Overwrite=true and Append=true" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_file","args":{"Path":"/project/a.ts","Content":"x","Overwrite":true,"Append":true}}}' arch-check.sh

assert_pre_decision "malformed: edit_file empty Target denies" "deny" "Target" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"edit_file","args":{"Path":"/project/a.ts","Target":"","Replacement":"x"}}}' arch-check.sh

assert_pre_decision "malformed: write_to_file missing CodeContent denies" "deny" "CodeContent" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"write_to_file","args":{"TargetFile":"/project/a.ts"}}}' arch-check.sh

assert_pre_decision "malformed: replace_file_content missing ReplacementContent denies" "deny" "ReplacementContent" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"replace_file_content","args":{"TargetFile":"/project/a.ts"}}}' arch-check.sh

assert_pre_decision "malformed: replace_file_content StartLine > EndLine denies" "deny" "StartLine cannot exceed EndLine" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"replace_file_content","args":{"TargetFile":"/project/a.ts","ReplacementContent":"x","StartLine":10,"EndLine":5}}}' arch-check.sh

assert_pre_decision "malformed: multi_replace_file_content empty ReplacementChunks denies" "deny" "ReplacementChunks" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"multi_replace_file_content","args":{"TargetFile":"/project/a.ts","ReplacementChunks":[]}}}' arch-check.sh

assert_pre_decision "malformed: multi_replace_file_content chunk missing ReplacementContent denies" "deny" "ReplacementContent" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"multi_replace_file_content","args":{"TargetFile":"/project/a.ts","ReplacementChunks":[{"TargetContent":"x"}]}}}' arch-check.sh

assert_pre_decision "malformed: run_command missing CommandLine denies" "deny" "CommandLine" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"run_command","args":{}}}' bash-safety-check.sh

assert_pre_decision "malformed: non-list workspacePaths denies" "deny" "workspacePaths" \
    '{"conversationId":"c1","workspacePaths":"/not-a-list","toolCall":{"name":"run_command","args":{"CommandLine":"ls"}}}' bash-safety-check.sh

assert_pre_decision "malformed: missing workspacePaths denies" "deny" "workspacePaths" \
    '{"conversationId":"c1","toolCall":{"name":"run_command","args":{"CommandLine":"ls"}}}' bash-safety-check.sh

assert_pre_decision "malformed: missing hook script denies fail-closed" "deny" "Missing hook script" \
    '{"conversationId":"c1","workspacePaths":["/project"],"toolCall":{"name":"run_command","args":{"CommandLine":"ls"}}}' nonexistent-hook.sh

OVERSIZE_OUT=$(python3 -c 'import sys; sys.stdout.write("{\"a\":\"" + ("x" * (8 * 1024 * 1024 + 64)) + "\"}")' \
    | python3 "$ADAPTER" PreToolUse arch-check.sh 2>/dev/null)
assert_true "malformed: oversized input (>8 MiB) denies fail-closed" python3 -c '
import json, sys
d = json.loads(sys.argv[1])
assert d["decision"] == "deny" and "8 MiB" in d["reason"], d
' "$OVERSIZE_OUT"

# =============================================
# 7. PostToolUse, SessionStart, and Stop Lifecycle (Item 4)
# =============================================
echo ""
echo "--- PostToolUse, SessionStart, and Stop ---"

LIFE_WS=$(mktemp -d)
git init -q "$LIFE_WS"
git -C "$LIFE_WS" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init
mkdir -p "$LIFE_WS/src/service" "$LIFE_WS/.claude/metrics" "$LIFE_WS/.claude/signals"
printf '.claude/signals/\n.claude/metrics/\n' > "$LIFE_WS/.gitignore"
git -C "$LIFE_WS" add .gitignore
git -C "$LIFE_WS" -c user.email=t@t -c user.name=t commit -q -m ignore
HEAD_SHA=$(git -C "$LIFE_WS" rev-parse HEAD)

POST_OUT=$(run_adapter PostToolUse \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$LIFE_WS\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"$LIFE_WS/src/service/user service.ts\",\"Content\":\"export const x = 1;\"}}}" \
    session-metrics.sh)
assert_true "PostToolUse: returns {} and records Write metric for write_file" python3 -c '
import glob, json, sys
ws, out = sys.argv[1], sys.argv[2]
assert json.loads(out) == {}
files = glob.glob(ws + "/.claude/metrics/session-*.jsonl")
assert len(files) == 1
rec = json.loads(open(files[0]).readlines()[-1])
assert rec["tool"] == "Write" and rec["layer"] == "service" and rec["file"].endswith("src/service/user service.ts"), rec
' "$LIFE_WS" "$POST_OUT"

BEFORE_COUNT=$(wc -l < "$(ls "$LIFE_WS/.claude/metrics/"session-*.jsonl | head -1)" | tr -d ' ')
ERR_OUT=$(run_adapter PostToolUse \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$LIFE_WS\"],\"error\":\"exit status 1\",\"toolCall\":{\"name\":\"edit_file\",\"args\":{\"Path\":\"$LIFE_WS/src/service/user service.ts\",\"Target\":\"1\",\"Replacement\":\"2\"}}}" \
    session-metrics.sh)
AFTER_COUNT=$(wc -l < "$(ls "$LIFE_WS/.claude/metrics/"session-*.jsonl | head -1)" | tr -d ' ')
assert_true "PostToolUse: skips metric write when error is non-empty and returns {}" \
    bash -c "[ '$BEFORE_COUNT' = '$AFTER_COUNT' ] && [ '$ERR_OUT' = '{}' ]"

mkdir -p "$LIFE_WS/docs/exec-plans/active" "$LIFE_WS/src/repo"
printf '{"id":"p-1","status":"done"}\n' > "$LIFE_WS/docs/exec-plans/active/p.json"
PLAN_POST_OUT=$(run_adapter PostToolUse \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$LIFE_WS\"],\"error\":\"\",\"toolCall\":{\"name\":\"edit_file\",\"args\":{\"Path\":\"$LIFE_WS/docs/exec-plans/active/p.json\",\"Target\":\"\\\"status\\\":\\\"pending\\\"\",\"Replacement\":\"\\\"status\\\":\\\"done\\\"\"}}}" \
    session-metrics.sh)
assert_true "PostToolUse: records Edit metric for already-applied exec-plan edit_file without pre-edit reconstruction" python3 -c '
import glob, json, sys
ws, out = sys.argv[1], sys.argv[2]
assert json.loads(out) == {}
files = glob.glob(ws + "/.claude/metrics/session-*.jsonl")
assert len(files) == 1
rec = json.loads(open(files[0]).readlines()[-1])
assert rec["tool"] == "Edit" and rec["file"].endswith("docs/exec-plans/active/p.json"), rec
' "$LIFE_WS" "$PLAN_POST_OUT"
rm -f "$LIFE_WS/docs/exec-plans/active/p.json"

BEFORE_MULTI_COUNT=$(wc -l < "$(ls "$LIFE_WS/.claude/metrics/"session-*.jsonl | head -1)" | tr -d ' ')
MULTI_POST_OUT=$(run_adapter PostToolUse \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$LIFE_WS\"],\"error\":\"\",\"toolCall\":{\"name\":\"multi_replace_file_content\",\"args\":{\"TargetFile\":\"$LIFE_WS/src/service/multi-a.ts\",\"ReplacementChunks\":[{\"TargetContent\":\"old1\",\"ReplacementContent\":\"new1\"},{\"TargetContent\":\"old2\",\"ReplacementContent\":\"new2\"},{\"TargetFile\":\"$LIFE_WS/src/repo/multi-b.ts\",\"TargetContent\":\"old3\",\"ReplacementContent\":\"new3\"}]}}}" \
    session-metrics.sh)
assert_true "PostToolUse: multi_replace_file_content records metric once per changed file with valid JSON" python3 -c '
import glob, json, sys
ws, out, before = sys.argv[1], sys.argv[2], int(sys.argv[3])
assert json.loads(out) == {}
files = glob.glob(ws + "/.claude/metrics/session-*.jsonl")
assert len(files) == 1
lines = [json.loads(line) for line in open(files[0])]
assert len(lines) == before + 2, f"expected {before + 2} lines, got {len(lines)}"
assert lines[-2]["tool"] == "Edit" and lines[-2]["layer"] == "service" and lines[-2]["file"].endswith("src/service/multi-a.ts")
assert lines[-1]["tool"] == "Edit" and lines[-1]["layer"] == "repo" and lines[-1]["file"].endswith("src/repo/multi-b.ts")
' "$LIFE_WS" "$MULTI_POST_OUT" "$BEFORE_MULTI_COUNT"

SS_EMPTY=$(run_adapter SessionStart \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$LIFE_WS\"]}" \
    doc-drift-check.sh)
assert_true "SessionStart: returns {} when no signals and no active plan" \
    bash -c "[ '$SS_EMPTY' = '{}' ]"

printf '{"schema_version":1,"decision":"GREEN","commit":"%s"}' "$HEAD_SHA" > "$LIFE_WS/.claude/signals/verify-latest.json"
SS_GREEN=$(run_adapter SessionStart \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$LIFE_WS\"]}" \
    doc-drift-check.sh)
assert_true "SessionStart: emits injectSteps.systemMessage.systemMessage with gate state" python3 -c '
import json, sys
d = json.loads(sys.argv[1])
msg = d["injectSteps"][0]["systemMessage"]["systemMessage"]
assert "Gate state:" in msg and "/harness-review" in msg, msg
' "$SS_GREEN"

printf '{"schema_version":1,"decision":"APPROVE","commit":"%s"}' "$HEAD_SHA" > "$LIFE_WS/.claude/signals/review-latest.json"
STOP_OUT=$(run_adapter Stop \
    "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$LIFE_WS\"],\"terminationReason\":\"NO_TOOL_CALL\",\"fullyIdle\":true}" \
    doc-drift-check.sh)
assert_true "Stop: returns safe non-continuing {} (never decision=continue)" \
    bash -c "[ '$STOP_OUT' = '{}' ]"

rm -rf "$LIFE_WS"

# =============================================
# 8. Portable Skill Plugin-Root Discovery & Workflow Fail-Closed (Item 7)
# =============================================
echo ""
echo "--- Portable Skill Discovery & Audit Workflow Fail-Closed ---"

FAKE_HOME=$(mktemp -d)
FAKE_PROJ=$(mktemp -d)
git init -q "$FAKE_PROJ"
mkdir -p "$FAKE_HOME/.gemini/config/plugins/oh-my-agents"
cp -r "$REPO_ROOT/hooks" "$REPO_ROOT/.claude" "$FAKE_HOME/.gemini/config/plugins/oh-my-agents/"

DISC_OUT=$(cd "$FAKE_PROJ" && env -i HOME="$FAKE_HOME" PATH="$PATH" bash -c '
_t=$(git rev-parse --show-toplevel 2>/dev/null || echo ""); _r=""; for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${AGY_PLUGIN_ROOT:-}" "$_t" "${_t:+$_t/.agents/plugins/oh-my-agents}" . .agents/plugins/oh-my-agents .. ../.agents/plugins/oh-my-agents "${HOME:+$HOME/.gemini/config/plugins/oh-my-agents}" "${HOME:+$HOME/.gemini/antigravity-cli/config/plugins/oh-my-agents}"; do [ -n "$_p" ] && [ "$_p" != "/" ] && [ -f "$_p/hooks/lib/common.sh" ] && { _r="$_p"; break; }; done; [ -n "$_r" ] && source "$_r/hooks/lib/common.sh" || { echo "ERROR: oh-my-agents common.sh not found" >&2; exit 1; }
gstack_detect || true
echo "ROOT=$(harness_root)|PLUGIN=$CLAUDE_PLUGIN_ROOT|SLUG=$SLUG"
')
assert_true "portable skill snippet: resolves installed Antigravity plugin root with CLAUDE_PLUGIN_ROOT unset" \
    bash -c "printf '%s' \"\$1\" | grep -q 'PLUGIN=$FAKE_HOME/.gemini/config/plugins/oh-my-agents' && printf '%s' \"\$1\" | grep -q 'SLUG='" _ "$DISC_OUT"

# Workspace-local plugin (.agents/plugins/oh-my-agents) invoked from a project subdirectory with spaces
# and stale/empty CLAUDE_PLUGIN_ROOT / CLAUDE_PROJECT_DIR
mkdir -p "$FAKE_PROJ/.agents/plugins/oh-my-agents" "$FAKE_PROJ/packages/sub dir/deep"
cp -r "$REPO_ROOT/hooks" "$REPO_ROOT/.claude" "$FAKE_PROJ/.agents/plugins/oh-my-agents/"
SUBDIR_SKILL_OUT=$(cd "$FAKE_PROJ/packages/sub dir/deep" && env -i HOME="$FAKE_HOME" PATH="$PATH" CLAUDE_PLUGIN_ROOT="" AGY_PLUGIN_ROOT="/nonexistent/stale" CLAUDE_PROJECT_DIR="" AGY_PROJECT_DIR="/nonexistent/project" bash -c '
_t=$(git rev-parse --show-toplevel 2>/dev/null || echo ""); _r=""; for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${AGY_PLUGIN_ROOT:-}" "$_t" "${_t:+$_t/.agents/plugins/oh-my-agents}" . .agents/plugins/oh-my-agents .. ../.agents/plugins/oh-my-agents "${HOME:+$HOME/.gemini/config/plugins/oh-my-agents}" "${HOME:+$HOME/.gemini/antigravity-cli/config/plugins/oh-my-agents}"; do [ -n "$_p" ] && [ "$_p" != "/" ] && [ -f "$_p/hooks/lib/common.sh" ] && { _r="$_p"; break; }; done; [ -n "$_r" ] && source "$_r/hooks/lib/common.sh" || { echo "ERROR: oh-my-agents common.sh not found" >&2; exit 1; }
ROOT=$(harness_root) && ensure_harness_dir "$ROOT" signals metrics || exit 1
echo "ROOT=$ROOT|PLUGIN=$CLAUDE_PLUGIN_ROOT"
')
assert_true "skill snippet from project subdir: prefers workspace-local .agents/plugins/oh-my-agents and writes state only at repo root" \
    bash -c "printf '%s' \"\$1\" | grep -q \"ROOT=$FAKE_PROJ|PLUGIN=$FAKE_PROJ/.agents/plugins/oh-my-agents\" && [ -d '$FAKE_PROJ/.claude/signals' ] && [ -d '$FAKE_PROJ/.claude/metrics' ] && [ ! -d '$FAKE_PROJ/packages/sub dir/.claude' ] && [ ! -d '$FAKE_PROJ/packages/sub dir/deep/.claude' ]" _ "$SUBDIR_SKILL_OUT"

# Missing plugin candidate must fail closed BEFORE any write (never mkdir /.claude or ./claude)
EMPTY_ENV_DIR=$(mktemp -d)
NO_PLUGIN_RC=0
NO_PLUGIN_OUT=$(cd "$EMPTY_ENV_DIR" && env -i HOME="$EMPTY_ENV_DIR/nohome" PATH="$PATH" CLAUDE_PLUGIN_ROOT="" AGY_PLUGIN_ROOT="/stale/nonexistent" bash -c '
_t=$(git rev-parse --show-toplevel 2>/dev/null || echo ""); _r=""; for _p in "${CLAUDE_PLUGIN_ROOT:-}" "${AGY_PLUGIN_ROOT:-}" "$_t" "${_t:+$_t/.agents/plugins/oh-my-agents}" . .agents/plugins/oh-my-agents .. ../.agents/plugins/oh-my-agents "${HOME:+$HOME/.gemini/config/plugins/oh-my-agents}" "${HOME:+$HOME/.gemini/antigravity-cli/config/plugins/oh-my-agents}"; do [ -n "$_p" ] && [ "$_p" != "/" ] && [ -f "$_p/hooks/lib/common.sh" ] && { _r="$_p"; break; }; done; [ -n "$_r" ] && source "$_r/hooks/lib/common.sh" || { echo "ERROR: oh-my-agents common.sh not found" >&2; exit 1; }
ROOT=$(harness_root) && ensure_harness_dir "$ROOT" signals metrics || exit 1
mkdir -p "$ROOT/.claude/signals"
' 2>&1) || NO_PLUGIN_RC=$?
assert_true "skill snippet with no plugin candidate: fails closed (rc!=0) with ERROR before any write" \
    bash -c "[ '$NO_PLUGIN_RC' -ne 0 ] && printf '%s' \"\$1\" | grep -q 'ERROR: oh-my-agents common.sh not found' && [ ! -d '$EMPTY_ENV_DIR/.claude' ] && [ ! -d '/.claude' ]" _ "$NO_PLUGIN_OUT"
rm -rf "$EMPTY_ENV_DIR" "$FAKE_HOME" "$FAKE_PROJ"

# =============================================
# 9. Empty/Stale Env Vars, Subdir CWD, Read-Only Plugin & Unwritable Project State
# =============================================
echo ""
echo "--- Empty/Stale Env Vars, Read-Only Plugin Install & Unwritable Project State ---"

ENV_TEST_BASE=$(mktemp -d)
RO_PLUGIN="$ENV_TEST_BASE/ro plugin"
FAKE_HOME2="$ENV_TEST_BASE/home dir"
UNREL_CWD="$ENV_TEST_BASE/unrelated cwd"
WRONG_PROJ="$ENV_TEST_BASE/wrong proj"
WS_A="$ENV_TEST_BASE/ws alpha"
WS_B="$ENV_TEST_BASE/ws beta"
mkdir -p "$RO_PLUGIN" "$FAKE_HOME2/.claude" "$UNREL_CWD" "$WRONG_PROJ" "$WS_A/packages/sub mod/src/service" "$WS_B/src/service"
cp -r "$REPO_ROOT/hooks" "$REPO_ROOT/templates" "$REPO_ROOT/plugin.json" "$REPO_ROOT/hooks.json" "$RO_PLUGIN/"
git init -q "$WS_A"
git init -q "$WS_B"

# Make the installed plugin completely read-only (simulating system/read-only plugin installation)
chmod -R a-w "$RO_PLUGIN"

# 9a. PreToolUse + PostToolUse from read-only plugin install, invoked from unrelated CWD and subdir CWD,
#     with empty, "/", nonexistent, HOME, and wrong env vars
RO_PRE_ALLOW=$(cd "$UNREL_CWD" && HOME="$FAKE_HOME2" CLAUDE_PLUGIN_ROOT="" AGY_PLUGIN_ROOT="" CLAUDE_PROJECT_DIR="" AGY_PROJECT_DIR="/" \
    python3 "$RO_PLUGIN/hooks/antigravity-adapter.py" PreToolUse arch-check.sh safety-check.sh plan-validation-check.sh \
    <<< "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$WS_A\",\"$WS_B\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"$WS_A/packages/sub mod/src/service/ok.ts\",\"Content\":\"export const ok = 1;\n\"}}}")
assert_true "read-only plugin + empty/root env vars: PreToolUse allows valid edit and writes nothing to plugin or HOME" \
    bash -c "printf '%s' \"\$1\" | grep -q '\"decision\": \"allow\"' && [ ! -d '$RO_PLUGIN/.claude' ] && [ ! -d '$RO_PLUGIN/hooks/__pycache__' ] && [ ! -d '$FAKE_HOME2/.claude/metrics' ]" _ "$RO_PRE_ALLOW"

RO_PRE_DENY=$(cd "$WS_A/packages/sub mod" && HOME="$FAKE_HOME2" CLAUDE_PLUGIN_ROOT="/nonexistent/plugin" AGY_PLUGIN_ROOT="/wrong/plugin" CLAUDE_PROJECT_DIR="$WRONG_PROJ" AGY_PROJECT_DIR="$FAKE_HOME2" \
    python3 "$RO_PLUGIN/hooks/antigravity-adapter.py" PreToolUse arch-check.sh safety-check.sh \
    <<< "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$WS_A\",\"$WS_B\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"$WS_A/packages/sub mod/src/service/bad.ts\",\"Content\":\"import { Btn } from '../ui/btn';\n\"}}}")
assert_true "read-only plugin + stale/wrong env vars: PreToolUse denies layer violation from project subdir" \
    bash -c "printf '%s' \"\$1\" | grep -q '\"decision\": \"deny\"' && printf '%s' \"\$1\" | grep -q 'Layer violation'" _ "$RO_PRE_DENY"

# 9b. PostToolUse from project subdir with relative path & multiple workspaces + stale env vars
printf 'export const sub = 1;\n' > "$WS_A/packages/sub mod/src/service/ok.ts"
RO_POST_OUT=$(cd "$WS_A/packages/sub mod" && HOME="$FAKE_HOME2" CLAUDE_PLUGIN_ROOT="" AGY_PLUGIN_ROOT="/stale/plugin" CLAUDE_PROJECT_DIR="$RO_PLUGIN" AGY_PROJECT_DIR="$WRONG_PROJ" \
    python3 "$RO_PLUGIN/hooks/antigravity-adapter.py" PostToolUse session-metrics.sh \
    <<< "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$WS_A\",\"$WS_B\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"src/service/ok.ts\",\"Content\":\"export const sub = 1;\n\"}}}")
assert_true "read-only plugin + subdir CWD: PostToolUse records metric only in WS_A root ledger (never subdir, WS_B, plugin, WRONG_PROJ, or HOME)" python3 -c '
import glob, json, os, sys
ws_a, ws_b, ro_plugin, wrong_proj, fake_home, out = sys.argv[1:7]
assert json.loads(out) == {}
files_a = glob.glob(ws_a + "/.claude/metrics/session-*.jsonl")
assert len(files_a) == 1, f"expected 1 ledger in WS_A, got {files_a}"
rec = json.loads(open(files_a[0]).readlines()[-1])
assert rec["layer"] == "service" and rec["file"].endswith("packages/sub mod/src/service/ok.ts"), rec
assert not os.path.exists(ws_a + "/packages/sub mod/.claude")
assert glob.glob(ws_b + "/.claude/metrics/session-*.jsonl") == []
assert not os.path.exists(ro_plugin + "/.claude")
assert not os.path.exists(wrong_proj + "/.claude")
assert not os.path.exists(fake_home + "/.claude/metrics")
' "$WS_A" "$WS_B" "$RO_PLUGIN" "$WRONG_PROJ" "$FAKE_HOME2" "$RO_POST_OUT"

# 9c. Direct shell hook invocation on read-only plugin with empty/stale/wrong env vars
DIRECT_POST=$(cd "$UNREL_CWD" && HOME="$FAKE_HOME2" CLAUDE_PLUGIN_ROOT="" AGY_PLUGIN_ROOT="/nonexistent" CLAUDE_PROJECT_DIR="" AGY_PROJECT_DIR="$RO_PLUGIN" \
    bash "$RO_PLUGIN/hooks/session-metrics.sh" \
    <<< "{\"tool_name\":\"Edit\",\"cwd\":\"$WS_B/src/service\",\"tool_input\":{\"file_path\":\"$WS_B/src/service/b.ts\"}}")
assert_true "direct session-metrics.sh on read-only plugin: ignores CLAUDE_PROJECT_DIR=RO_PLUGIN and records in WS_B root" python3 -c '
import glob, json, os, sys
ws_b, ro_plugin = sys.argv[1], sys.argv[2]
files_b = glob.glob(ws_b + "/.claude/metrics/session-*.jsonl")
assert len(files_b) == 1
rec = json.loads(open(files_b[0]).readlines()[-1])
assert rec["layer"] == "service" and rec["file"].endswith("src/service/b.ts"), rec
assert not os.path.exists(ro_plugin + "/.claude")
' "$WS_B" "$RO_PLUGIN"

# 9d. Root "/" workspacePath or project dir is rejected fail-closed
assert_pre_decision "workspacePaths: root '/' is rejected fail-closed" "deny" "Root directory '/'" \
    '{"conversationId":"c1","workspacePaths":["/"],"toolCall":{"name":"write_file","args":{"Path":"/tmp/x.ts","Content":"export const x = 1;"}}}' \
    arch-check.sh

# 9e. Unwritable intended project state directory: explicit diagnostic + fail-closed (no reroute, no security loosening)
UNWRITABLE_WS="$ENV_TEST_BASE/unwritable ws"
mkdir -p "$UNWRITABLE_WS/src/service" "$UNWRITABLE_WS/.claude"
git init -q "$UNWRITABLE_WS"
chmod a-w "$UNWRITABLE_WS/.claude"

UNW_PRE_DENY=$(HOME="$FAKE_HOME2" python3 "$RO_PLUGIN/hooks/antigravity-adapter.py" PreToolUse arch-check.sh safety-check.sh \
    <<< "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$UNWRITABLE_WS\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"$UNWRITABLE_WS/src/service/s.ts\",\"Content\":\"const password = \\\"secret123\\\";\"}}}")
assert_true "unwritable project .claude: PreToolUse still denies secret violation (never loosens security)" \
    bash -c "printf '%s' \"\$1\" | grep -q '\"decision\": \"deny\"' && printf '%s' \"\$1\" | grep -q 'Hardcoded credential'" _ "$UNW_PRE_DENY"

UNW_POST_STDERR_FILE="$ENV_TEST_BASE/unw_post.err"
UNW_POST_STDOUT=$(HOME="$FAKE_HOME2" python3 "$RO_PLUGIN/hooks/antigravity-adapter.py" PostToolUse session-metrics.sh \
    <<< "{\"conversationId\":\"c1\",\"workspacePaths\":[\"$UNWRITABLE_WS\"],\"toolCall\":{\"name\":\"write_file\",\"args\":{\"Path\":\"$UNWRITABLE_WS/src/service/s.ts\",\"Content\":\"export const x = 1;\"}}}" 2>"$UNW_POST_STDERR_FILE")
UNW_POST_STDERR=$(cat "$UNW_POST_STDERR_FILE")
assert_true "unwritable project .claude: PostToolUse emits explicit writability diagnostic and never reroutes writes" \
    bash -c "[ '$UNW_POST_STDOUT' = '{}' ] && printf '%s' \"\$1\" | grep -q 'not writable' && [ ! -d '$UNWRITABLE_WS/.claude/metrics' ] && [ ! -d '$RO_PLUGIN/.claude' ] && [ ! -d '$FAKE_HOME2/.claude/metrics' ]" _ "$UNW_POST_STDERR"

UNW_SKILL_RC=0
UNW_SKILL_ERR=$(cd "$UNWRITABLE_WS" && HOME="$FAKE_HOME2" bash -c "source '$RO_PLUGIN/hooks/lib/common.sh'; ROOT=\$(harness_root) && ensure_harness_dir \"\$ROOT\" metrics" 2>&1) || UNW_SKILL_RC=$?
assert_true "unwritable project .claude: ensure_harness_dir fails closed (rc!=0) with writability diagnostic" \
    bash -c "[ '$UNW_SKILL_RC' -ne 0 ] && printf '%s' \"\$1\" | grep -q 'not writable'" _ "$UNW_SKILL_ERR"

UNW_AHR_RC=0
UNW_AHR_ERR=$(HOME="$FAKE_HOME2" bash -c "source '$RO_PLUGIN/hooks/lib/common.sh'; append_history_record '$UNWRITABLE_WS/.claude/metrics' verify.jsonl '{\"decision\":\"GREEN\"}'" 2>&1) || UNW_AHR_RC=$?
assert_true "unwritable project .claude: append_history_record fails closed (rc!=0) with diagnostic" \
    bash -c "[ '$UNW_AHR_RC' -ne 0 ] && printf '%s' \"\$1\" | grep -q 'append_history_record:'" _ "$UNW_AHR_ERR"

ROOT_AHR_RC=0
ROOT_AHR_ERR=$(HOME="$FAKE_HOME2" bash -c "source '$RO_PLUGIN/hooks/lib/common.sh'; append_history_record '/.claude/metrics' verify.jsonl '{\"decision\":\"GREEN\"}'" 2>&1) || ROOT_AHR_RC=$?
assert_true "root path '/.claude/metrics': append_history_record refuses before mkdir (rc!=0)" \
    bash -c "[ '$ROOT_AHR_RC' -ne 0 ] && printf '%s' \"\$1\" | grep -q 'refusing to write to root path'" _ "$ROOT_AHR_ERR"

chmod -R u+w "$RO_PLUGIN" "$UNWRITABLE_WS"
rm -rf "$ENV_TEST_BASE"

NODE_BIN="${NODE_BIN:-$(command -v node 2>/dev/null || echo "")}"
if [ -z "$NODE_BIN" ] && [ -x "/opt/codex/runtimes/codex-primary-runtime/dependencies/node/bin/node" ]; then
    NODE_BIN="/opt/codex/runtimes/codex-primary-runtime/dependencies/node/bin/node"
fi
if [ -n "$NODE_BIN" ] && [ -x "$NODE_BIN" ]; then
    assert_true "workflows/harness-audit.js: incomplete verification fails closed to NEEDS_HUMAN (never APPROVE)" "$NODE_BIN" --input-type=module -e '
import { pathToFileURL } from "node:url";
globalThis.args = {};
globalThis.phase = () => {};
globalThis.log = () => {};
globalThis.parallel = async (fns) => Promise.all(fns.map((fn) => fn()));
globalThis.agent = async (_prompt, opts) => {
  if (opts.phase === "Audit") {
    return {
      dimension: opts.label,
      findings: [{ id: "f1", severity: "P2", title: "minor", file: "a.ts", detail: "d" }]
    };
  }
  throw new Error("verifier agent failed");
};
const mod = await import(pathToFileURL(process.argv[1]).href);
const res = mod.default;
if (!res || !res.signal || res.signal.decision !== "NEEDS_HUMAN") {
  throw new Error("Expected NEEDS_HUMAN on verifier failure, got: " + JSON.stringify(res?.signal));
}
' "$REPO_ROOT/workflows/harness-audit.js"
fi

echo ""
echo "=== Results ==="
echo "Total: $TOTAL | Pass: $PASS | Fail: $FAIL"
if [ "$FAIL" -gt 0 ]; then
    echo "FAILED"
    exit 1
else
    echo "ALL PASSED"
    exit 0
fi
