#!/usr/bin/env python3
"""Adapt Codex apply_patch hook inputs without applying or changing the patch."""

import json
import os
from pathlib import Path
import subprocess
import sys

HOOKS = Path(__file__).resolve().parent
LIMIT = 8 * 1024 * 1024


class PatchError(ValueError):
    pass


def resolve_path(name, cwd):
    path = Path(name)
    return path if path.is_absolute() else cwd / path


def reconstruct(original, hunks):
    """Match ordered context hunks, including Codex's optional jump/EOF markers."""
    lines = original.splitlines()
    cursor = 0
    result = []
    for jump, body, eof in hunks:
        if jump:
            found = next((i for i in range(cursor, len(lines)) if lines[i] == jump), None)
            if found is None:
                raise PatchError("patch jump context not found")
            result.extend(lines[cursor:found + 1])
            cursor = found + 1
        before = [line[1:] for line in body if line.startswith((" ", "-"))]
        after = [line[1:] for line in body if line.startswith((" ", "+"))]
        if before:
            start = len(lines) - len(before) if eof else cursor
            found = next((i for i in range(max(cursor, start), len(lines) - len(before) + 1)
                          if lines[i:i + len(before)] == before), None)
            if found is None:
                # Codex tolerates trailing whitespace differences in patch context.
                found = next((i for i in range(max(cursor, start), len(lines) - len(before) + 1)
                              if [s.rstrip() for s in lines[i:i + len(before)]] ==
                              [s.rstrip() for s in before]), None)
            if found is None:
                raise PatchError("patch context not found; refresh the patch from the current file")
        else:
            found = len(lines) if eof else cursor
        result.extend(lines[cursor:found])
        result.extend(after)
        cursor = found + len(before)
    result.extend(lines[cursor:])
    return "\n".join(result) + ("\n" if result else "")


def parse_patch(patch, cwd, post=False):
    lines = patch.strip().splitlines()
    if not lines or lines[0] != "*** Begin Patch" or lines[-1] != "*** End Patch":
        raise PatchError("expected a Codex Begin Patch / End Patch envelope")
    edits = []
    i = 1
    while i < len(lines) - 1:
        header = lines[i]
        kind = next((k for k in ("Add", "Update", "Delete")
                     if header.startswith(f"*** {k} File: ")), None)
        if kind is None:
            raise PatchError("unsupported patch file header")
        source = resolve_path(header.split(": ", 1)[1], cwd)
        target = source
        i += 1
        if kind == "Update" and lines[i].startswith("*** Move to: "):
            target = resolve_path(lines[i].split(": ", 1)[1], cwd)
            i += 1
        body = []
        while i < len(lines) - 1 and not lines[i].startswith(("*** Add File: ", "*** Update File: ", "*** Delete File: ")):
            body.append(lines[i])
            i += 1
        if kind == "Delete":
            if body:
                raise PatchError("unexpected delete-file content")
            content = ""
        elif kind == "Add":
            if any(not line.startswith("+") for line in body):
                raise PatchError("invalid add-file line")
            content = "\n".join(line[1:] for line in body) + ("\n" if body else "")
        elif post:
            content = ""  # metrics need paths only; the original file may have moved
        else:
            hunks = []
            for line in body:
                if line == "@@" or line.startswith("@@ "):
                    hunks.append((line[3:] if line.startswith("@@ ") else "", [], False))
                elif line == "*** End of File":
                    if not hunks:
                        raise PatchError("EOF marker without a hunk")
                    jump, chunk, _ = hunks[-1]
                    hunks[-1] = (jump, chunk, True)
                elif line.startswith((" ", "+", "-")) or line == "":
                    if not hunks:
                        hunks.append(("", [], False))
                    hunks[-1][1].append(line or " ")
                else:
                    raise PatchError("invalid patch hunk line")
            if not hunks:
                raise PatchError("update without a hunk")
            content = reconstruct(source.read_text(), hunks)
        edits.append((target, content))
    if not edits:
        raise PatchError("patch contains no edits")
    return edits


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "pre"
    if mode not in ("pre", "post"):
        raise PatchError("mode must be pre or post")
    raw = sys.stdin.buffer.read(LIMIT + 1)
    if len(raw) > LIMIT:
        raise PatchError("hook input exceeds 8 MiB; split the patch")
    payload = json.loads(raw)
    if payload.get("tool_name") != "apply_patch":
        return 0
    # A failed tool call must not create edit metrics.
    response = payload.get("tool_response", {})
    if mode == "post" and isinstance(response, dict) and (
            response.get("success") is False or response.get("isError") is True):
        return 0
    cwd = Path(payload.get("cwd") or os.getcwd()).resolve()
    patch = payload.get("tool_input", {}).get("command", "")
    if not isinstance(patch, str):
        raise PatchError("apply_patch command must be text")
    edits = parse_patch(patch, cwd, post=mode == "post")
    advisories = []
    for path, content in edits:
        normalized = dict(payload, tool_input={"file_path": str(path), "content": content})
        scripts = ["session-metrics.sh"] if mode == "post" else [
            "arch-check.sh", "safety-check.sh", "plan-validation-check.sh"]
        for script in scripts:
            result = subprocess.run(["bash", str(HOOKS / script)],
                                    input=json.dumps(normalized), text=True,
                                    capture_output=True, timeout=3)
            if result.returncode:
                # Check scripts print risk categories and paths, never credential values.
                sys.stderr.write(result.stderr or f"{script} failed\n")
                return 2 if mode == "pre" else 0
            if result.stdout.strip() and mode == "pre":
                output = json.loads(result.stdout)
                text = output.get("hookSpecificOutput", {}).get("additionalContext")
                if text:
                    advisories.append(text)
    if advisories:
        text = "\n".join(advisories)[:400]
        print(json.dumps({"hookSpecificOutput": {"hookEventName": "PreToolUse",
                                                "additionalContext": text}}))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError, TypeError, AttributeError, KeyError, IndexError,
            subprocess.TimeoutExpired) as error:
        # Never echo input or file contents from an invalid patch.
        sys.stderr.write(f"Codex patch check could not complete ({type(error).__name__}); "
                         "refresh or split the patch and retry.\n")
        sys.exit(2 if len(sys.argv) < 2 or sys.argv[1] == "pre" else 0)
