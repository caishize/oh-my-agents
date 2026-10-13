"""Behavioral tests for native Codex payloads and release gating. No model/API needed."""
import importlib.util
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("adapter", ROOT / "hooks/codex-adapter.py")
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


class CodexFixture(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.project = Path(self.tmp.name)
        subprocess.run(["git", "init", "-q", str(self.project)], check=True)
        self.env = dict(os.environ)
        self.env.pop("HARNESS_PROJECT_DIR", None)
        self.env.pop("GSTACK_SESSION_KIND", None)

    def hook(self, patch, mode="pre", **extra):
        data = dict(cwd=str(self.project), tool_name="apply_patch",
                    hook_event_name="PreToolUse" if mode == "pre" else "PostToolUse",
                    tool_input={"command": patch})
        data.update(extra)
        return subprocess.run(["python3", str(ROOT / "hooks/codex-adapter.py"), mode],
                              input=json.dumps(data), text=True, capture_output=True,
                              env=self.env, timeout=10)

    def put(self, name, content):
        path = self.project / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path


class CodexHooks(CodexFixture):
    def test_native_add_allows_valid_import(self):
        result = self.hook('*** Begin Patch\n*** Add File: src/service/a.ts\n+import {x} from "../types/x";\n*** End Patch')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.project / "src/service/a.ts").exists())

    def test_native_add_blocks_upward_import(self):
        result = self.hook('*** Begin Patch\n*** Add File: src/types/a.ts\n+import {x} from "../service/x";\n*** End Patch')
        self.assertEqual(result.returncode, 2)
        self.assertIn("Layer violation", result.stderr)

    def test_later_file_in_batch_is_checked(self):
        result = self.hook('*** Begin Patch\n*** Add File: src/ui/a.ts\n+export const a = 1;\n*** Add File: src/types/b.ts\n+import {x} from "../ui/x";\n*** End Patch')
        self.assertEqual(result.returncode, 2)
        self.assertIn("b.ts", result.stderr)

    def test_secret_is_blocked_and_redacted(self):
        fake = "ghp_" + "Z" * 40
        result = self.hook(f'*** Begin Patch\n*** Add File: src/service/keys.py\n+token = "{fake}"\n*** End Patch')
        self.assertEqual(result.returncode, 2)
        self.assertNotIn(fake, result.stderr + result.stdout)
        self.assertIn("GitHub", result.stderr)

    def test_existing_json_is_reconstructed_for_plan_guide(self):
        self.put("docs/exec-plans/active/p.json", '{\n  "id": "p",\n  "status": "active",\n  "tasks": []\n}\n')
        result = self.hook('*** Begin Patch\n*** Update File: docs/exec-plans/active/p.json\n@@\n-  "tasks": []\n+  "tasks": [{"id":"t","status":"in-progress"}]\n*** End Patch')
        self.assertEqual(result.returncode, 0, result.stderr)
        context = json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("handoff", context)
        self.assertIn("acceptance", context)

    def test_multiple_plan_advisories_emit_one_envelope(self):
        plan = '{"id":"p","tasks":[{"id":"t","status":"in-progress"}]}'
        patch = f'*** Begin Patch\n*** Add File: docs/exec-plans/a.json\n+{plan}\n*** Add File: docs/exec-plans/b.json\n+{plan}\n*** End Patch'
        result = self.hook(patch)
        self.assertEqual(result.returncode, 0, result.stderr)
        output = json.loads(result.stdout)
        self.assertLessEqual(len(output["hookSpecificOutput"]["additionalContext"]), 400)

    def test_update_uses_original_context_without_mutation(self):
        path = self.put("a.txt", "a\nb\nc\nd\n")
        patch = '*** Begin Patch\n*** Update File: a.txt\n@@\n a\n-b\n+B\n@@ c\n-d\n+D\n*** End Patch'
        edits = adapter.parse_patch(patch, self.project)
        self.assertEqual(edits[0][1], "a\nB\nc\nD\n")
        self.assertEqual(path.read_text(), "a\nb\nc\nd\n")

    def test_eof_hunk_matches_last_context(self):
        self.put("a.txt", "x\nx\n")
        edits = adapter.parse_patch('*** Begin Patch\n*** Update File: a.txt\n@@\n-x\n+y\n*** End of File\n*** End Patch', self.project)
        self.assertEqual(edits[0][1], "x\ny\n")

    def test_move_checks_destination_layer(self):
        self.put("src/ui/a.ts", 'import {x} from "../service/x";\n')
        result = self.hook('*** Begin Patch\n*** Update File: src/ui/a.ts\n*** Move to: src/types/a.ts\n@@\n import {x} from "../service/x";\n*** End Patch')
        self.assertEqual(result.returncode, 2)

    def test_deletion_allows_removing_bad_content(self):
        self.put("src/types/a.ts", 'import {x} from "../service/x";\n')
        result = self.hook('*** Begin Patch\n*** Delete File: src/types/a.ts\n*** End Patch')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_invalid_patch_does_not_echo_payload(self):
        result = self.hook("private-payload-without-envelope")
        self.assertEqual(result.returncode, 2)
        self.assertNotIn("private-payload", result.stderr)

    def test_invalid_json_shape_denies_edit(self):
        result = subprocess.run(["python3", str(ROOT / "hooks/codex-adapter.py"), "pre"],
                                input="[]", capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    def test_context_mismatch_does_not_pass(self):
        self.put("a.txt", "actual\n")
        result = self.hook('*** Begin Patch\n*** Update File: a.txt\n@@\n-missing\n+new\n*** End Patch')
        self.assertEqual(result.returncode, 2)

    def test_post_move_records_destination_without_original(self):
        patch = '*** Begin Patch\n*** Update File: src/ui/a.ts\n*** Move to: src/types/a.ts\n@@\n-old\n+new\n*** End Patch'
        result = self.hook(patch, "post")
        self.assertEqual(result.returncode, 0, result.stderr)
        records = list((self.project / ".codex/metrics").glob("session-*.jsonl"))
        row = json.loads(records[0].read_text())
        self.assertTrue(row["file"].endswith("src/types/a.ts"))
        self.assertEqual(row["tool"], "apply_patch")
        self.assertEqual(row["layer"], "types")

    def test_failed_post_does_not_create_metrics(self):
        result = self.hook('*** Begin Patch\n*** Add File: a.txt\n+a\n*** End Patch', "post", tool_response={"success": False})
        self.assertEqual(result.returncode, 0)
        self.assertFalse((self.project / ".codex/metrics").exists())

    def test_cmd_shell_payload_blocks_inline_token(self):
        payload = {"tool_name": "exec_command", "tool_input": {"cmd": 'curl -H "Authorization: ghp_' + "Z" * 40 + '" example.test'}}
        result = subprocess.run(["bash", str(ROOT / "hooks/bash-safety-check.sh")],
                                input=json.dumps(payload), capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)


class GateTests(CodexFixture):
    # Keep fixture utilities, but do not inherit/rerun native-hook test methods.
    def setUp(self):
        super().setUp()
        self.put(".gitignore", ".codex/signals/\n.codex/metrics/\n")
        self.put("code.txt", "source\n")
        subprocess.run(["git", "-C", str(self.project), "add", "."], check=True)
        subprocess.run(["git", "-C", str(self.project), "-c", "user.name=test", "-c",
                        "user.email=test@example.test", "commit", "-qm", "fixture"], check=True)
        self.sha = subprocess.check_output(["git", "-C", str(self.project), "rev-parse", "HEAD"], text=True).strip()
        self.write_signals()

    def write_signals(self, **changes):
        verify = dict(schema_version=1, decision="GREEN", commit=self.sha, scope="all",
                      checks={name: "PASS" for name in ["build", "test", "lint", "arch"]})
        verify.update(changes)
        self.put(".codex/signals/verify-latest.json", json.dumps(verify))
        self.put(".codex/signals/review-latest.json", json.dumps(dict(schema_version=1, decision="APPROVE", commit=self.sha)))

    def gate(self):
        return subprocess.run(["bash", str(ROOT / "scripts/gate.sh"), str(self.project)],
                              capture_output=True, text=True, env=self.env)

    def test_valid_full_gate(self):
        self.assertEqual(self.gate().returncode, 0)

    def test_partial_verification_is_not_release_ready(self):
        self.write_signals(scope="test")
        self.assertNotEqual(self.gate().returncode, 0)

    def test_documented_required_checks_allow_inapplicable_build(self):
        self.write_signals(required_checks=["test", "arch"],
                           checks={"build": "SKIP", "test": "PASS", "lint": "SKIP", "arch": "PASS"})
        self.assertEqual(self.gate().returncode, 0)

    def test_empty_or_unknown_required_checks_do_not_bypass_gate(self):
        for required in ([], ["unknown"], "test"):
            with self.subTest(required=required):
                self.write_signals(required_checks=required)
                self.assertNotEqual(self.gate().returncode, 0)

    def test_partial_hook_evidence_does_not_claim_release_readiness(self):
        self.write_signals(scope="test")
        payload = dict(cwd=str(self.project), hook_event_name="SessionStart")
        result = subprocess.run(["bash", str(ROOT / "hooks/doc-drift-check.sh")],
                                input=json.dumps(payload), capture_output=True, text=True, env=self.env)
        self.assertNotIn("RELEASE GATE: pass", result.stdout)
        self.assertIn("full verification evidence is missing", result.stdout)

    def test_skipped_required_check_denies_gate(self):
        self.write_signals(checks={"build": "PASS", "test": "SKIP", "lint": "PASS", "arch": "PASS"})
        self.assertNotEqual(self.gate().returncode, 0)

    def test_source_change_denies_gate(self):
        self.put("code.txt", "modified\n")
        self.assertNotEqual(self.gate().returncode, 0)

    def test_harness_config_change_denies_gate(self):
        self.put(".codex/harness.json", "{}")
        self.assertNotEqual(self.gate().returncode, 0)

    def test_unknown_schema_or_string_schema_denies_gate(self):
        for schema in (2, "1"):
            with self.subTest(schema=schema):
                self.write_signals(schema_version=schema)
                self.assertNotEqual(self.gate().returncode, 0)

    def test_stale_or_missing_review_denies_gate(self):
        path = self.project / ".codex/signals/review-latest.json"
        path.write_text('{"schema_version":1,"decision":"APPROVE","commit":"stale"}')
        self.assertNotEqual(self.gate().returncode, 0)
        path.unlink()
        self.assertNotEqual(self.gate().returncode, 0)

    def test_unknown_decision_denies_freshness(self):
        self.write_signals(decision="UNKNOWN")
        result = subprocess.run(["bash", "-c", 'source "$1"; signal_fresh "$2" verify-latest.json',
                                 "test", str(ROOT / "hooks/lib/common.sh"), str(self.project)],
                                capture_output=True, text=True, env=self.env)
        self.assertNotEqual(result.returncode, 0)


class PackageTests(unittest.TestCase):
    def test_native_package_paths_and_count(self):
        manifest = json.loads((ROOT / ".codex-plugin/plugin.json").read_text())
        market = json.loads((ROOT / ".agents/plugins/marketplace.json").read_text())
        self.assertEqual(manifest["name"], market["plugins"][0]["name"])
        for field in ("skills", "hooks"):
            path = manifest[field]
            self.assertTrue(path.startswith("./"))
            self.assertTrue((ROOT / path).exists())
        self.assertEqual(len(list((ROOT / "skills").glob("*/SKILL.md"))), 11)
        self.assertFalse((ROOT / ".claude-plugin").exists())
        self.assertFalse((ROOT / "workflows").exists())

    def test_skills_are_codex_native(self):
        for path in (ROOT / "skills").glob("*/SKILL.md"):
            with self.subTest(skill=path.parent.name):
                text = path.read_text()
                front = text.split("---", 2)[1]
                self.assertIn("name: " + path.parent.name, front)
                self.assertIn("description: ", front)
                self.assertNotRegex(front, r"allowed-tools|argument-hint|user-invocable|disable-model-invocation")
                self.assertNotIn("${CLAUDE_PLUGIN_ROOT}", text)
                self.assertLessEqual(len(text.splitlines()), 400)
                self.assertTrue((path.parent / "agents/openai.yaml").exists())
        for name in ("harness-init", "gstack-sync", "encode-mistake"):
            self.assertIn("allow_implicit_invocation: false", (ROOT / "skills" / name / "agents/openai.yaml").read_text())

    def test_registered_hook_paths_are_quoted_and_native(self):
        hooks = json.loads((ROOT / "hooks/hooks.json").read_text())["hooks"]
        for groups in hooks.values():
            for group in groups:
                for hook in group["hooks"]:
                    self.assertIn('"${PLUGIN_ROOT}/', hook["command"])
                    self.assertNotIn("CLAUDE_PLUGIN_ROOT", hook["command"])
        self.assertEqual(hooks["PreToolUse"][0]["matcher"], "^apply_patch$")

    def test_live_document_links_exist(self):
        paths = [ROOT / "README.md", ROOT / "AGENTS.md"] + list((ROOT / "docs").glob("*.md"))
        for path in paths:
            for link in re.findall(r"\]\(([^)]+)\)", path.read_text()):
                if "://" in link or link.startswith("#"):
                    continue
                target = link.split("#", 1)[0]
                self.assertTrue((path.parent / target).exists(), f"{path}: {link}")


if __name__ == "__main__":
    unittest.main()
