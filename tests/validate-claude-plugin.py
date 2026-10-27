#!/usr/bin/env python3
"""Fail-closed structured validator for `claude plugin validate --strict --json`.

Permits ONLY:
  1. Clean strict validation (`exit 0`, `success: true`, 0 errors, 0 warnings), or
  2. The single documented contributor-context warning on `<plugin-root>/CLAUDE.md`
     (`exit 1`, `success: false`, `type: "plugin"`, `path: "root"`, exact message,
     `code: null`), with 0 errors and no other warnings.

All other warnings (including any hook warning), any manifest/content/directory error,
blocking/held/incomplete/failed directory checks, malformed/empty JSON, unknown
top-level schema keys or missing required diagnostic fields, or incoherent/abnormal
process exit codes fail closed (exit 1). Nonblocking `ICON_MISSING` directory findings
do not fail validation.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from typing import Any

EXPECTED_ROOT_CLAUDE_WARNING_MSG = (
    "CLAUDE.md at the plugin root is not loaded as project context. "
    "To ship context with your plugin, use a skill (skills/<name>/SKILL.md) instead."
)

REQUIRED_TOP_KEYS = {"success", "strict", "target", "manifest", "contents", "directory"}
ALLOWED_TOP_KEYS = {"success", "strict", "target", "manifest", "contents", "advice", "directory"}
REQUIRED_MANIFEST_KEYS = {"file", "type", "errors", "warnings"}
REQUIRED_CONTENT_KEYS = {"file", "type", "errors", "warnings"}
REQUIRED_WARNING_KEYS = {"path", "message", "code"}
REQUIRED_DIRECTORY_KEYS = {"findings", "undecided", "incomplete", "failure"}
REQUIRED_FINDING_KEYS = {"code", "severity", "blocking", "hold"}


def validate_payload(
    exit_code: int,
    raw_json: str,
    expected_target: str | None = None,
) -> tuple[bool, str]:
    if isinstance(exit_code, bool) or not isinstance(exit_code, int) or exit_code not in (0, 1):
        return False, f"Abnormal CLI exit code: {exit_code}"

    if not isinstance(raw_json, str) or not raw_json.strip():
        return False, "Empty JSON output from claude plugin validate"

    try:
        data: Any = json.loads(raw_json)
    except Exception as exc:
        return False, f"Invalid JSON output: {exc}"

    if not isinstance(data, dict):
        return False, "Top-level JSON value must be an object"

    data_keys = set(data.keys())
    if not REQUIRED_TOP_KEYS.issubset(data_keys) or not data_keys.issubset(ALLOWED_TOP_KEYS):
        return False, f"Unexpected or missing top-level schema keys: {sorted(data_keys)}"

    if type(data.get("success")) is not bool:
        return False, "Field 'success' must be a boolean"

    if data.get("strict") is not True:
        return False, "Field 'strict' must be true"

    target = data.get("target")
    if not isinstance(target, str) or not target.strip():
        return False, "Field 'target' must be a non-empty string"

    if "advice" in data and not isinstance(data["advice"], list):
        return False, "Field 'advice' must be a list when present"

    manifest = data.get("manifest")
    if not isinstance(manifest, dict) or not REQUIRED_MANIFEST_KEYS.issubset(manifest.keys()):
        return False, "Field 'manifest' is missing required keys"

    if manifest.get("type") != "plugin":
        return False, f"Unexpected manifest.type: {manifest.get('type')!r}"

    manifest_file_raw = manifest.get("file")
    if not isinstance(manifest_file_raw, str) or not manifest_file_raw.strip():
        return False, "Field 'manifest.file' must be a non-empty string"

    manifest_file = os.path.normpath(manifest_file_raw)
    target_file = os.path.normpath(target)
    if manifest_file != target_file:
        return False, f"Target mismatch: target={target_file!r} != manifest.file={manifest_file!r}"

    if (
        os.path.basename(manifest_file) != "plugin.json"
        or os.path.basename(os.path.dirname(manifest_file)) != ".claude-plugin"
    ):
        return False, f"Manifest path must end with .claude-plugin/plugin.json, got {manifest_file!r}"

    if expected_target is not None:
        exp_abs = os.path.normpath(os.path.abspath(expected_target))
        man_abs = os.path.normpath(os.path.abspath(manifest_file))
        if exp_abs != man_abs:
            return False, f"Validated manifest {man_abs!r} does not match expected {exp_abs!r}"

    manifest_errors = manifest.get("errors")
    manifest_warnings = manifest.get("warnings")
    if not isinstance(manifest_errors, list) or not isinstance(manifest_warnings, list):
        return False, "Fields 'manifest.errors' and 'manifest.warnings' must be lists"

    if manifest_errors:
        return False, f"Manifest errors present: {manifest_errors}"
    if manifest_warnings:
        return False, f"Manifest warnings present: {manifest_warnings}"

    directory = data.get("directory")
    if not isinstance(directory, dict) or not REQUIRED_DIRECTORY_KEYS.issubset(directory.keys()):
        return False, "Field 'directory' is missing required keys"

    if directory.get("failure") is not None:
        return False, f"Directory check failure: {directory.get('failure')!r}"
    if directory.get("incomplete") is not False:
        return False, f"Directory check incomplete: {directory.get('incomplete')!r}"

    undecided = directory.get("undecided")
    if not isinstance(undecided, list) or len(undecided) != 0:
        return False, f"Directory check has undecided items: {undecided!r}"

    findings = directory.get("findings")
    if not isinstance(findings, list):
        return False, "Field 'directory.findings' must be a list"

    for finding in findings:
        if not isinstance(finding, dict) or not REQUIRED_FINDING_KEYS.issubset(finding.keys()):
            return False, f"Malformed directory finding: {finding!r}"
        if type(finding.get("blocking")) is not bool or finding.get("blocking") is not False:
            return False, f"Blocking directory finding: {finding!r}"
        if type(finding.get("hold")) is not bool or finding.get("hold") is not False:
            return False, f"Held directory finding: {finding!r}"
        if finding.get("severity") != "warning" or finding.get("code") != "ICON_MISSING":
            return False, f"Unexpected directory finding: {finding!r}"

    contents = data.get("contents")
    if not isinstance(contents, list):
        return False, "Field 'contents' must be a list"

    plugin_root = os.path.dirname(os.path.dirname(manifest_file))
    expected_claude_md = os.path.normpath(os.path.join(plugin_root, "CLAUDE.md")) if plugin_root else "CLAUDE.md"

    all_warnings: list[tuple[str, str, str, str, Any]] = []
    for item in contents:
        if not isinstance(item, dict) or not REQUIRED_CONTENT_KEYS.issubset(item.keys()):
            return False, f"Malformed contents entry: {item!r}"
        c_file = item.get("file")
        c_type = item.get("type")
        c_errors = item.get("errors")
        c_warnings = item.get("warnings")
        if not isinstance(c_file, str) or not c_file.strip():
            return False, f"Invalid contents[].file: {c_file!r}"
        if not isinstance(c_type, str) or not c_type.strip():
            return False, f"Invalid contents[].type: {c_type!r}"
        if not isinstance(c_errors, list) or not isinstance(c_warnings, list):
            return False, f"Invalid contents[].errors/warnings in {c_file!r}"
        if c_errors:
            return False, f"Validation errors in {c_file}: {c_errors}"
        norm_c_file = os.path.normpath(c_file)
        for w in c_warnings:
            if not isinstance(w, dict) or not REQUIRED_WARNING_KEYS.issubset(w.keys()):
                return False, f"Malformed warning object in {c_file}: {w!r}"
            w_path = w["path"]
            w_msg = w["message"]
            if not isinstance(w_path, str) or not isinstance(w_msg, str):
                return False, f"Warning path/message must be strings in {c_file}: {w!r}"
            all_warnings.append((norm_c_file, c_type, w_path, w_msg, w["code"]))

    if len(all_warnings) == 0:
        if exit_code == 0 and data["success"] is True:
            return True, "clean strict validation pass (0 warnings, 0 errors)"
        return (
            False,
            f"Incoherent zero-warning result: exit_code={exit_code}, success={data['success']}",
        )

    if len(all_warnings) == 1:
        w_file, w_type, w_path, w_msg, w_code = all_warnings[0]
        if (
            w_file == expected_claude_md
            and w_type == "plugin"
            and w_path == "root"
            and w_msg == EXPECTED_ROOT_CLAUDE_WARNING_MSG
            and w_code is None
        ):
            if exit_code == 1 and data["success"] is False:
                return True, "only the expected root-CLAUDE.md warning — pass"
            return (
                False,
                f"Incoherent root-CLAUDE.md warning state: exit_code={exit_code}, success={data['success']}",
            )
        return (
            False,
            f"Unexpected warning: file={w_file!r}, type={w_type!r}, path={w_path!r}, "
            f"code={w_code!r}, message={w_msg!r}",
        )

    return False, f"Validation failed with {len(all_warnings)} warnings: {all_warnings}"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "target",
        nargs="?",
        default=".claude-plugin/plugin.json",
        help="Path to .claude-plugin/plugin.json (default: .claude-plugin/plugin.json)",
    )
    parser.add_argument(
        "--claude-bin",
        default=os.environ.get("CLAUDE_BIN", "claude"),
        help="Claude CLI binary to invoke (default: $CLAUDE_BIN or 'claude')",
    )
    parser.add_argument(
        "--exit-code",
        type=int,
        default=None,
        help="Validate pre-captured JSON output with this CLI exit code instead of invoking claude",
    )
    parser.add_argument(
        "--json-file",
        default=None,
        help="Path to pre-captured JSON output file (use '-' for stdin)",
    )
    args = parser.parse_args(argv)

    if args.exit_code is not None or args.json_file is not None:
        if args.exit_code is None:
            print("ERROR: --exit-code is required when validating pre-captured JSON", file=sys.stderr)
            return 1
        if args.json_file is None or args.json_file == "-":
            raw_json = sys.stdin.read()
        else:
            try:
                with open(args.json_file, "r", encoding="utf-8") as fh:
                    raw_json = fh.read()
            except OSError as exc:
                print(f"ERROR: Cannot read JSON file {args.json_file!r}: {exc}", file=sys.stderr)
                return 1
        ok, reason = validate_payload(args.exit_code, raw_json)
        if ok:
            print(reason)
            return 0
        print(f"claude plugin validate failed: {reason}", file=sys.stderr)
        return 1

    cmd = [args.claude_bin, "plugin", "validate", args.target, "--strict", "--json"]
    env = os.environ.copy()
    env.setdefault("CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC", "1")
    env.setdefault("DISABLE_TELEMETRY", "1")
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, check=False, env=env)
    except OSError as exc:
        print(f"claude plugin validate failed: cannot execute {args.claude_bin!r}: {exc}", file=sys.stderr)
        return 1

    if proc.stdout:
        sys.stdout.write(proc.stdout)
        if not proc.stdout.endswith("\n"):
            sys.stdout.write("\n")
    if proc.stderr:
        sys.stderr.write(proc.stderr)
        if not proc.stderr.endswith("\n"):
            sys.stderr.write("\n")

    ok, reason = validate_payload(proc.returncode, proc.stdout, expected_target=args.target)
    if ok:
        print(reason)
        return 0
    print(f"claude plugin validate failed (exit={proc.returncode}): {reason}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
