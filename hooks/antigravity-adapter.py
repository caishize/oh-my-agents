#!/usr/bin/env python3
"""Antigravity CLI hook adapter for oh-my-agents.

Translates Antigravity CLI camelCase hook payloads (SessionStart, PreInvocation,
PreToolUse, PostToolUse, PostInvocation, Stop) into the canonical shell hook
contracts in hooks/*.sh and maps their exit codes and stdout/stderr back to
Antigravity's JSON responses.

Supports both observed native CLI tool calls (write_file, edit_file, run_command)
and documented IDE/CLI variants (write_to_file, replace_file_content,
multi_replace_file_content).

Safety invariants:
- PreToolUse fails closed ({"decision": "deny", "reason": ...}) on malformed
  JSON, oversized payloads, invalid argument types, unknown tools, paths outside
  approved workspacePaths (and optional artifactDirectoryPath), ambiguous or
  unreconstructable execution-plan edits, or non-zero hook exits.
- Conversation artifacts under artifactDirectoryPath are still scanned by
  safety-check.sh / bash-safety-check.sh, while skipping project-only arch,
  exec-plan, and session-metrics ledger hooks.
- Sanitizes safety-check.sh and bash-safety-check.sh stderr so matched secrets
  or credentials are never echoed in stdout or stderr.
- Resolves each edit's owning workspace by canonical path containment across
  workspacePaths without ambient CLAUDE_PROJECT_DIR contamination.
- Delivers execution-plan feedforward advisories to the model via PostToolUse ->
  PreInvocation ephemeralMessage, and renders human-facing turn-end gate/drift
  summaries via PostInvocation metadata.user_markdown (never forcing continuation).
- Never emits permissionOverrides, auto_approve, overwrite, or bypass settings.
- Stop returns {} and never emits {"decision": "continue"} (rule no-orchestration).
"""

import hashlib
import json
import os
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

try:
    import fcntl
except ImportError:  # pragma: no cover
    fcntl = None  # type: ignore[assignment]

HOOKS_DIR = Path(__file__).resolve().parent
PLUGIN_ROOT = HOOKS_DIR.parent
MAX_INPUT_BYTES = 8 * 1024 * 1024  # 8 MiB fail-closed ceiling
ADVISORY_TTL_SECONDS = 86400
PROJECT_ONLY_PRE_SCRIPTS = {"arch-check.sh", "plan-validation-check.sh"}

EDIT_TOOLS = {
    "write_file",
    "edit_file",
    "write_to_file",
    "replace_file_content",
    "multi_replace_file_content",
}
COMMAND_TOOLS = {"run_command"}


def emit_json(payload: Dict[str, Any]) -> int:
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()
    return 0


def deny_pre_tool_use(reason: str) -> int:
    clean = (reason or "").strip() or "Blocked by oh-my-agents PreToolUse gate."
    return emit_json({"decision": "deny", "reason": clean})


def allow_pre_tool_use(reason: Optional[str] = None) -> int:
    out: Dict[str, Any] = {"decision": "allow"}
    if reason and reason.strip():
        out["reason"] = reason.strip()
    return emit_json(out)


KNOWN_DENY_PREFIXES: Tuple[Tuple[str, str], ...] = (
    tuple(
        (
            f"Layer violation: '{src}' layer cannot import from '{dst}' layer.",
            f"Layer violation: '{src}' layer cannot import from '{dst}' layer. Ref: docs/ARCHITECTURE.md",
        )
        for src in ("types", "config", "repo", "service", "runtime", "ui")
        for dst in ("types", "config", "repo", "service", "runtime", "ui")
        if src != dst
    )
    + (
        (
            "Providers bypass: Direct auth library import detected.",
            "Providers bypass: Direct auth library import detected. Ref: docs/PROVIDERS.md",
        ),
        (
            "Providers bypass: Direct telemetry library import detected.",
            "Providers bypass: Direct telemetry library import detected. Ref: docs/PROVIDERS.md",
        ),
        (
            "Providers bypass: Direct feature-flag library import detected.",
            "Providers bypass: Direct feature-flag library import detected. Ref: docs/PROVIDERS.md",
        ),
        (
            "Security risk: Hardcoded credential detected in source code.",
            "Security risk: Hardcoded credential detected in source code.",
        ),
        (
            "Security risk: Hardcoded secret detected.",
            "Security risk: Hardcoded secret detected.",
        ),
        (
            "Security risk: Hardcoded API key detected.",
            "Security risk: Hardcoded API key detected.",
        ),
        (
            "Security risk: AWS Access Key ID detected.",
            "Security risk: AWS Access Key ID detected.",
        ),
        (
            "Security risk: JWT token detected in source code.",
            "Security risk: JWT token detected in source code.",
        ),
        (
            "Security risk: GitHub Personal Access Token detected.",
            "Security risk: GitHub Personal Access Token detected.",
        ),
        (
            "Security risk: Slack token detected.",
            "Security risk: Slack token detected.",
        ),
        (
            "Security risk: Private key detected in source code.",
            "Security risk: Private key detected in source code.",
        ),
        (
            "Security risk: Google API key detected.",
            "Security risk: Google API key detected.",
        ),
        (
            "Security risk: Stripe API key detected.",
            "Security risk: Stripe API key detected.",
        ),
        (
            "Security risk: Anthropic API key detected.",
            "Security risk: Anthropic API key detected.",
        ),
        (
            "Security risk: OpenAI API key detected.",
            "Security risk: OpenAI API key detected.",
        ),
        (
            "Security risk: npm token detected.",
            "Security risk: npm token detected.",
        ),
        (
            "Security risk: Potential secret value in env file.",
            "Security risk: Potential secret value in env file.",
        ),
        (
            "Security risk: AWS Access Key in bash command.",
            "Security risk: AWS Access Key in bash command.",
        ),
        (
            "Security risk: GitHub token in bash command.",
            "Security risk: GitHub token in bash command.",
        ),
        (
            "Security risk: Slack token in bash command.",
            "Security risk: Slack token in bash command.",
        ),
        (
            "Security risk: Google API key in bash command.",
            "Security risk: Google API key in bash command.",
        ),
        (
            "Security risk: JWT token in bash command.",
            "Security risk: JWT token in bash command.",
        ),
        (
            "Security risk: Private key content in bash command.",
            "Security risk: Private key content in bash command.",
        ),
        (
            "Security risk: Possible inline auth token in bash command.",
            "Security risk: Possible inline auth token in bash command.",
        ),
        (
            "Security risk: Stripe API key in bash command.",
            "Security risk: Stripe API key in bash command.",
        ),
        (
            "Security risk: Anthropic API key in bash command.",
            "Security risk: Anthropic API key in bash command.",
        ),
        (
            "Security risk: OpenAI API key in bash command.",
            "Security risk: OpenAI API key in bash command.",
        ),
        (
            "Security risk: curl -u with inline credentials.",
            "Security risk: curl -u with inline credentials.",
        ),
        (
            "Security risk: Inline password in CLI flag.",
            "Security risk: Inline password in CLI flag.",
        ),
        (
            "Hook input exceeds 8 MiB",
            "Hook input exceeds 8 MiB; split the edit and retry.",
        ),
        (
            "Missing hook script:",
            "Missing hook script.",
        ),
    )
)


def sanitize_hook_stderr(script_name: str, stderr: str) -> str:
    """Return only fixed, constant category summaries; never reflect raw stderr text."""
    if not stderr:
        return f"Blocked by {script_name}."
    matched: List[str] = []
    for needle, fixed_summary in KNOWN_DENY_PREFIXES:
        if needle in stderr and fixed_summary not in matched:
            matched.append(fixed_summary)
    if matched:
        return "\n".join(matched)
    return f"Blocked by {script_name}."


def read_hook_stdin(event: str) -> Tuple[Optional[Dict[str, Any]], Optional[str]]:
    raw = sys.stdin.buffer.read(MAX_INPUT_BYTES + 1)
    if len(raw) > MAX_INPUT_BYTES:
        return None, "Hook input exceeds 8 MiB limit; split the edit and retry."
    if not raw or not raw.strip():
        return None, f"Empty {event} hook input."
    try:
        data = json.loads(raw.decode("utf-8"))
    except Exception:
        return None, f"Malformed {event} hook JSON input."
    if not isinstance(data, dict):
        return None, f"Expected JSON object for {event} hook input."
    return data, None


def _is_within_workspace(candidate_real: str, ws_real: str) -> bool:
    try:
        return os.path.commonpath([ws_real, candidate_real]) == ws_real
    except ValueError:
        return False


def extract_canonical_workspaces(
    payload: Dict[str, Any],
) -> Tuple[Optional[List[str]], Optional[str]]:
    """Extract and canonicalize workspacePaths (or fallback cwd)."""
    raw_ws = payload.get("workspacePaths")
    workspaces: List[str] = []
    if raw_ws is not None:
        if not isinstance(raw_ws, list) or not raw_ws:
            return None, "Malformed or empty workspacePaths in hook input."
        for item in raw_ws:
            if not isinstance(item, str) or not item.strip():
                return None, "Invalid entry in workspacePaths."
            if not os.path.isabs(item):
                return None, "workspacePaths entries must be absolute paths."
            real_item = os.path.realpath(item)
            if real_item == "/":
                return None, "Root directory '/' is not a valid workspacePath."
            workspaces.append(real_item)

    fallback_cwd = payload.get("cwd")
    if fallback_cwd is not None:
        if not isinstance(fallback_cwd, str) or not fallback_cwd.strip():
            return None, "Malformed cwd field in hook input."
        if not workspaces:
            if not os.path.isabs(fallback_cwd):
                return None, "cwd must be an absolute path."
            real_cwd = os.path.realpath(fallback_cwd)
            if real_cwd == "/":
                return None, "Root directory '/' is not a valid cwd."
            workspaces.append(real_cwd)

    if not workspaces:
        return None, "Missing workspacePaths in hook input."

    return workspaces, None


def extract_canonical_artifact_dir(
    payload: Dict[str, Any],
) -> Tuple[Optional[str], Optional[str]]:
    """Extract and canonicalize optional artifactDirectoryPath safely."""
    raw_art = payload.get("artifactDirectoryPath")
    if raw_art is None or raw_art == "":
        return None, None
    if not isinstance(raw_art, str) or not raw_art.strip():
        return None, "Malformed artifactDirectoryPath in hook input."
    if not os.path.isabs(raw_art):
        return None, "artifactDirectoryPath must be an absolute path."
    art_real = os.path.realpath(raw_art)
    if art_real == "/":
        return None, "Root directory '/' is not a valid artifactDirectoryPath."
    raw_home = os.environ.get("HOME", "")
    if raw_home and os.path.isabs(raw_home):
        home_real = os.path.realpath(raw_home)
        if art_real == home_real or _is_within_workspace(home_real, art_real):
            return None, "HOME directory is not a valid artifactDirectoryPath."
    plugin_real = os.path.realpath(str(PLUGIN_ROOT))
    if _is_within_workspace(art_real, plugin_real) or _is_within_workspace(
        plugin_real, art_real
    ):
        return None, "Plugin directory is not a valid artifactDirectoryPath."
    return art_real, None


def find_owning_workspace(
    target_real: str, workspaces: List[str]
) -> Optional[str]:
    """Return the most specific canonical workspace containing target_real."""
    matches = [ws for ws in workspaces if _is_within_workspace(target_real, ws)]
    if not matches:
        return None
    matches.sort(key=len, reverse=True)
    return matches[0]


def resolve_tool_cwd(
    args: Dict[str, Any],
    workspaces: List[str],
    artifact_dir: Optional[str] = None,
) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """Return (effective_cwd, owning_workspace, error_reason)."""
    primary_ws = workspaces[0]
    if "Cwd" not in args or args["Cwd"] is None:
        return primary_ws, primary_ws, None
    raw_cwd = args["Cwd"]
    if not isinstance(raw_cwd, str) or not raw_cwd.strip():
        return None, None, "Malformed Cwd argument in toolCall.args."
    if os.path.isabs(raw_cwd):
        cand_real = os.path.realpath(raw_cwd)
    else:
        cand_real = os.path.realpath(os.path.join(primary_ws, raw_cwd))
    owner = find_owning_workspace(cand_real, workspaces)
    if owner is not None:
        return cand_real, owner, None
    if artifact_dir and _is_within_workspace(cand_real, artifact_dir):
        return cand_real, primary_ws, None
    return None, None, "Cwd is outside approved workspacePaths."


def resolve_target_and_workspace(
    target_file: str,
    effective_cwd: str,
    workspaces: List[str],
    artifact_dir: Optional[str] = None,
) -> Tuple[Optional[str], Optional[str], bool, Optional[str]]:
    """Resolve target_file and verify containment in workspacePaths or artifactDirectoryPath."""
    if os.path.isabs(target_file):
        cand_real = os.path.realpath(target_file)
    else:
        cand_real = os.path.realpath(os.path.join(effective_cwd, target_file))
        if not os.path.exists(cand_real):
            try:
                proc_cwd = os.path.realpath(os.getcwd())
            except Exception:
                proc_cwd = ""
            if (
                proc_cwd
                and proc_cwd != str(PLUGIN_ROOT)
                and find_owning_workspace(proc_cwd, workspaces) is not None
            ):
                alt_real = os.path.realpath(os.path.join(proc_cwd, target_file))
                if os.path.exists(alt_real) or (
                    not os.path.isdir(os.path.dirname(cand_real))
                    and os.path.isdir(os.path.dirname(alt_real))
                ):
                    cand_real = alt_real
    owner = find_owning_workspace(cand_real, workspaces)
    in_artifact = bool(artifact_dir and _is_within_workspace(cand_real, artifact_dir))
    if owner is None and not in_artifact:
        return None, None, False, "Target file path is outside approved workspacePaths."
    is_artifact = bool(
        in_artifact and artifact_dir and (owner is None or len(artifact_dir) > len(owner))
    )
    return cand_real, (owner or workspaces[0]), is_artifact, None


def _is_exec_plan_path(file_path: str) -> bool:
    norm = file_path.replace("\\", "/")
    return "docs/exec-plans/" in norm and norm.endswith(".json")


def _validate_chunk_bounds(
    chunk: Dict[str, Any], label: str
) -> Tuple[Optional[int], Optional[int], bool, Optional[str]]:
    """Validate optional StartLine, EndLine, AllowMultiple on a replacement spec."""
    allow_multiple = chunk.get("AllowMultiple", False)
    if allow_multiple is None:
        allow_multiple = False
    if not isinstance(allow_multiple, bool):
        return None, None, False, f"{label} AllowMultiple must be a boolean."

    start_line = chunk.get("StartLine")
    end_line = chunk.get("EndLine")
    if start_line is not None:
        if (
            not isinstance(start_line, int)
            or isinstance(start_line, bool)
            or start_line < 1
        ):
            return None, None, False, f"{label} StartLine must be a positive integer."
    if end_line is not None:
        if (
            not isinstance(end_line, int)
            or isinstance(end_line, bool)
            or end_line < 1
        ):
            return None, None, False, f"{label} EndLine must be a positive integer."
    if start_line is not None and end_line is not None and start_line > end_line:
        return None, None, False, f"{label} StartLine cannot exceed EndLine."

    return start_line, end_line, allow_multiple, None


def _apply_replacement_spec(
    text: str,
    target_content: Optional[str],
    replacement_content: str,
    start_line: Optional[int],
    end_line: Optional[int],
    allow_multiple: bool,
) -> Tuple[Optional[str], Optional[str]]:
    """Apply a single replacement to text accurately, or return an error."""
    if not isinstance(target_content, str) or target_content == "":
        return None, "Missing or empty TargetContent for file replacement."

    if start_line is not None or end_line is not None:
        lines = text.splitlines(keepends=True)
        total = len(lines)
        s_idx = (start_line - 1) if start_line is not None else 0
        e_idx = end_line if end_line is not None else total
        if s_idx < 0 or e_idx > total or s_idx >= e_idx:
            return None, "StartLine/EndLine out of bounds for target file."
        region = "".join(lines[s_idx:e_idx])
        count = region.count(target_content)
        if count == 0:
            return None, "TargetContent not found within StartLine/EndLine range."
        if count > 1 and not allow_multiple:
            return (
                None,
                "Ambiguous TargetContent: multiple matches in StartLine/EndLine range with AllowMultiple=false.",
            )
        new_region = (
            region.replace(target_content, replacement_content)
            if allow_multiple
            else region.replace(target_content, replacement_content, 1)
        )
        return "".join(lines[:s_idx]) + new_region + "".join(lines[e_idx:]), None

    count = text.count(target_content)
    if count == 0:
        return None, "TargetContent not found in target file."
    if count > 1 and not allow_multiple:
        return (
            None,
            "Ambiguous TargetContent: multiple matches in file with AllowMultiple=false.",
        )
    new_text = (
        text.replace(target_content, replacement_content)
        if allow_multiple
        else text.replace(target_content, replacement_content, 1)
    )
    return new_text, None


def _reconstruct_plan_replacements(
    file_path: str,
    specs: List[Tuple[Optional[str], str, Optional[int], Optional[int], bool]],
    fallback_text: str,
) -> Tuple[Optional[str], Optional[str]]:
    """Reconstruct full execution-plan JSON on disk, failing closed on ambiguity."""
    if not _is_exec_plan_path(file_path):
        return fallback_text, None
    if not os.path.isfile(file_path):
        return (
            None,
            "Execution-plan partial edit requires an existing plan file on disk.",
        )
    try:
        with open(file_path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except Exception:
        return None, "Unable to read execution-plan file for validation."

    for tgt, rep, s_line, e_line, allow_mult in specs:
        updated, err = _apply_replacement_spec(
            text, tgt, rep, s_line, e_line, allow_mult
        )
        if err or updated is None:
            return None, err or "Failed to reconstruct execution-plan edit."
        text = updated
    return text, None


def normalize_edit_operations(
    tool_name: str,
    args: Dict[str, Any],
    effective_cwd: str,
    workspaces: List[str],
    artifact_dir: Optional[str] = None,
) -> Tuple[Optional[List[Dict[str, Any]]], Optional[str]]:
    """Return normalized edit operations with resolved file_path and owning_workspace."""
    if tool_name == "write_file":
        path_arg = args.get("Path")
        if not isinstance(path_arg, str) or not path_arg.strip():
            return None, "write_file requires a non-empty string Path."
        if "TargetFile" in args and args["TargetFile"] != path_arg:
            return None, "Conflicting Path and TargetFile in write_file."
        content = args.get("Content")
        if not isinstance(content, str):
            return None, "write_file requires string Content."
        overwrite = args.get("Overwrite", False)
        append = args.get("Append", False)
        if overwrite is not None and not isinstance(overwrite, bool):
            return None, "write_file Overwrite must be a boolean."
        if append is not None and not isinstance(append, bool):
            return None, "write_file Append must be a boolean."
        if overwrite and append:
            return None, "write_file cannot combine Overwrite=true and Append=true."

        resolved, owner, is_art, path_err = resolve_target_and_workspace(
            path_arg, effective_cwd, workspaces, artifact_dir
        )
        if path_err or not resolved or not owner:
            return None, path_err or "Invalid write_file Path."

        plan_content = content
        if (
            not is_art
            and append
            and _is_exec_plan_path(resolved)
            and os.path.isfile(resolved)
        ):
            try:
                with open(resolved, "r", encoding="utf-8") as fh:
                    plan_content = fh.read() + content
            except Exception:
                return None, "Unable to read existing execution plan for Append."

        return [
            {
                "tool_name": "Write",
                "file_path": resolved,
                "owning_workspace": owner,
                "is_artifact": is_art,
                "content": content,
                "new_string": "",
                "plan_content": plan_content,
            }
        ], None

    if tool_name == "write_to_file":
        target = args.get("TargetFile")
        if not isinstance(target, str) or not target.strip():
            return None, "write_to_file requires a non-empty string TargetFile."
        if "Path" in args and args["Path"] != target:
            return None, "Conflicting TargetFile and Path in write_to_file."
        code = args.get("CodeContent")
        if not isinstance(code, str):
            return None, "write_to_file requires string CodeContent."
        resolved, owner, is_art, path_err = resolve_target_and_workspace(
            target, effective_cwd, workspaces, artifact_dir
        )
        if path_err or not resolved or not owner:
            return None, path_err or "Invalid write_to_file TargetFile."
        return [
            {
                "tool_name": "Write",
                "file_path": resolved,
                "owning_workspace": owner,
                "is_artifact": is_art,
                "content": code,
                "new_string": "",
                "plan_content": code,
            }
        ], None

    if tool_name == "edit_file":
        path_arg = args.get("Path")
        if not isinstance(path_arg, str) or not path_arg.strip():
            return None, "edit_file requires a non-empty string Path."
        target_str = args.get("Target")
        if not isinstance(target_str, str) or target_str == "":
            return None, "edit_file requires a non-empty string Target."
        replacement = args.get("Replacement")
        if not isinstance(replacement, str):
            return None, "edit_file requires string Replacement."
        resolved, owner, is_art, path_err = resolve_target_and_workspace(
            path_arg, effective_cwd, workspaces, artifact_dir
        )
        if path_err or not resolved or not owner:
            return None, path_err or "Invalid edit_file Path."
        if is_art:
            plan_text, plan_err = replacement, None
        else:
            plan_text, plan_err = _reconstruct_plan_replacements(
                resolved,
                [(target_str, replacement, None, None, True)],
                replacement,
            )
        if plan_err or plan_text is None:
            return None, plan_err or "Invalid execution-plan edit."
        return [
            {
                "tool_name": "Edit",
                "file_path": resolved,
                "owning_workspace": owner,
                "is_artifact": is_art,
                "content": "",
                "new_string": replacement,
                "plan_content": plan_text,
            }
        ], None

    if tool_name == "replace_file_content":
        target = args.get("TargetFile")
        if not isinstance(target, str) or not target.strip():
            return None, "replace_file_content requires a non-empty string TargetFile."
        replacement = args.get("ReplacementContent")
        if not isinstance(replacement, str):
            return None, "replace_file_content requires string ReplacementContent."
        target_content = args.get("TargetContent")
        if target_content is not None and not isinstance(target_content, str):
            return None, "replace_file_content TargetContent must be a string."
        s_line, e_line, allow_mult, bounds_err = _validate_chunk_bounds(
            args, "replace_file_content"
        )
        if bounds_err:
            return None, bounds_err
        resolved, owner, is_art, path_err = resolve_target_and_workspace(
            target, effective_cwd, workspaces, artifact_dir
        )
        if path_err or not resolved or not owner:
            return None, path_err or "Invalid replace_file_content TargetFile."
        if is_art:
            plan_text, plan_err = replacement, None
        else:
            plan_text, plan_err = _reconstruct_plan_replacements(
                resolved,
                [(target_content, replacement, s_line, e_line, allow_mult)],
                replacement,
            )
        if plan_err or plan_text is None:
            return None, plan_err or "Invalid execution-plan replacement."
        return [
            {
                "tool_name": "Edit",
                "file_path": resolved,
                "owning_workspace": owner,
                "is_artifact": is_art,
                "content": "",
                "new_string": replacement,
                "plan_content": plan_text,
            }
        ], None

    if tool_name == "multi_replace_file_content":
        default_target = args.get("TargetFile")
        if default_target is not None and (
            not isinstance(default_target, str) or not default_target.strip()
        ):
            return (
                None,
                "multi_replace_file_content TargetFile must be a non-empty string.",
            )
        chunks = args.get("ReplacementChunks")
        if not isinstance(chunks, list) or not chunks:
            return (
                None,
                "multi_replace_file_content requires a non-empty list ReplacementChunks.",
            )

        grouped_specs: Dict[
            str,
            List[Tuple[Optional[str], str, Optional[int], Optional[int], bool]],
        ] = {}
        owners: Dict[str, str] = {}
        is_artifacts: Dict[str, bool] = {}
        file_order: List[str] = []

        for idx, chunk in enumerate(chunks):
            if not isinstance(chunk, dict):
                return None, f"ReplacementChunks[{idx}] must be an object."
            chunk_target = chunk.get("TargetFile", default_target)
            if not isinstance(chunk_target, str) or not chunk_target.strip():
                return (
                    None,
                    f"ReplacementChunks[{idx}] requires a non-empty string TargetFile.",
                )
            rep = chunk.get("ReplacementContent")
            if not isinstance(rep, str):
                return (
                    None,
                    f"ReplacementChunks[{idx}] requires string ReplacementContent.",
                )
            tgt = chunk.get("TargetContent")
            if tgt is not None and not isinstance(tgt, str):
                return (
                    None,
                    f"ReplacementChunks[{idx}] TargetContent must be a string.",
                )
            s_line, e_line, allow_mult, bounds_err = _validate_chunk_bounds(
                chunk, f"ReplacementChunks[{idx}]"
            )
            if bounds_err:
                return None, bounds_err
            resolved, owner, is_art, path_err = resolve_target_and_workspace(
                chunk_target, effective_cwd, workspaces, artifact_dir
            )
            if path_err or not resolved or not owner:
                return None, path_err or f"Invalid path in ReplacementChunks[{idx}]."
            if resolved not in grouped_specs:
                grouped_specs[resolved] = []
                owners[resolved] = owner
                is_artifacts[resolved] = is_art
                file_order.append(resolved)
            grouped_specs[resolved].append((tgt, rep, s_line, e_line, allow_mult))

        items: List[Dict[str, Any]] = []
        for resolved in file_order:
            specs = grouped_specs[resolved]
            combined_new = "\n".join(rep for _, rep, _, _, _ in specs)
            if is_artifacts[resolved]:
                plan_text, plan_err = combined_new, None
            else:
                plan_text, plan_err = _reconstruct_plan_replacements(
                    resolved, specs, combined_new
                )
            if plan_err or plan_text is None:
                return None, plan_err or "Invalid execution-plan multi-replacement."
            items.append(
                {
                    "tool_name": "Edit",
                    "file_path": resolved,
                    "owning_workspace": owners[resolved],
                    "is_artifact": is_artifacts[resolved],
                    "content": "",
                    "new_string": combined_new,
                    "plan_content": plan_text,
                }
            )
        return items, None

    return None, f"Unsupported edit tool: {tool_name}"


def run_hook_script(
    script_name: str, hook_input: Dict[str, Any]
) -> Tuple[int, str, str]:
    script_path = HOOKS_DIR / script_name
    if not script_path.is_file():
        return 2, "", f"Missing hook script: {script_name}"
    env = os.environ.copy()
    # Prevent ambient project-dir overrides from contaminating per-workspace routing.
    for key in (
        "CLAUDE_PROJECT_DIR",
        "AGY_PROJECT_DIR",
        "HARNESS_PROJECT_DIR",
        "PROJECT_DIR",
        "PROJECT_DIR_SOURCE",
    ):
        env.pop(key, None)
    env["CLAUDE_PLUGIN_ROOT"] = str(PLUGIN_ROOT)
    env["AGY_PLUGIN_ROOT"] = str(PLUGIN_ROOT)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    hook_cwd = hook_input.get("cwd")
    run_cwd = (
        hook_cwd
        if isinstance(hook_cwd, str) and os.path.isdir(hook_cwd)
        else tempfile.gettempdir()
    )
    proc = subprocess.run(
        ["bash", str(script_path)],
        input=json.dumps(hook_input).encode("utf-8"),
        capture_output=True,
        env=env,
        cwd=run_cwd,
    )
    stdout = proc.stdout.decode("utf-8", errors="replace").strip()
    stderr = proc.stderr.decode("utf-8", errors="replace").strip()
    return proc.returncode, stdout, stderr


def extract_advisory_message(stdout: str) -> Optional[str]:
    if not stdout:
        return None
    for line in reversed(stdout.splitlines()):
        line = line.strip()
        if not line:
            continue
        try:
            parsed = json.loads(line)
        except Exception:
            continue
        if isinstance(parsed, dict):
            hso = parsed.get("hookSpecificOutput")
            if isinstance(hso, dict):
                ctx = hso.get("additionalContext")
                if isinstance(ctx, str) and ctx.strip():
                    return ctx.strip()
            sys_msg = parsed.get("systemMessage")
            if isinstance(sys_msg, str) and sys_msg.strip():
                return sys_msg.strip()
    return None


def _advisory_queue_dir(create: bool = True) -> Optional[Path]:
    """Return a private per-UID temp directory (never inside project or plugin root)."""
    uid = os.getuid() if hasattr(os, "getuid") else 0
    qdir = Path(tempfile.gettempdir()) / f"oh-my-agents-agy-{uid}"
    try:
        if create:
            os.makedirs(qdir, mode=0o700, exist_ok=True)
        elif not os.path.exists(qdir):
            return None
        st = os.lstat(qdir)
        if not stat.S_ISDIR(st.st_mode):
            return None
        if hasattr(os, "getuid") and st.st_uid != uid:
            return None
        return qdir
    except Exception:
        return None


def _sweep_stale_advisories(qdir: Path, keep_prefix: str) -> None:
    cutoff = time.time() - ADVISORY_TTL_SECONDS
    try:
        for entry in os.scandir(qdir):
            if entry.name.startswith(keep_prefix):
                continue
            try:
                st = entry.stat(follow_symlinks=False)
                if st.st_mtime < cutoff:
                    os.unlink(entry.path)
            except Exception:
                continue
    except Exception:
        pass


def _update_queued_advisory(
    session_id: str, file_path: str, advisory: Optional[str]
) -> None:
    if not session_id:
        return
    qdir = _advisory_queue_dir(create=True)
    if qdir is None:
        return
    key = hashlib.sha256(session_id.encode("utf-8")).hexdigest()
    _sweep_stale_advisories(qdir, key)
    lock_path = qdir / f"{key}.lock"
    data_path = qdir / f"{key}.json"
    flags = os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(str(lock_path), flags, 0o600)
    except Exception:
        return
    try:
        with os.fdopen(fd, "r+") as lock_fh:
            if fcntl is not None:
                fcntl.flock(lock_fh.fileno(), fcntl.LOCK_EX)
            adv_map: Dict[str, str] = {}
            if data_path.exists() and not data_path.is_symlink():
                try:
                    existing = json.loads(data_path.read_text(encoding="utf-8"))
                    if isinstance(existing, dict) and isinstance(
                        existing.get("advisories"), dict
                    ):
                        for k, v in existing["advisories"].items():
                            if isinstance(k, str) and isinstance(v, str) and v.strip():
                                adv_map[k] = v
                except Exception:
                    adv_map = {}
            if advisory and advisory.strip():
                adv_map[file_path] = advisory.strip()
            else:
                adv_map.pop(file_path, None)
            if adv_map:
                tmp_fd, tmp_name = tempfile.mkstemp(prefix=f".{key}.", dir=str(qdir))
                try:
                    with os.fdopen(tmp_fd, "w", encoding="utf-8") as tmp_fh:
                        json.dump(
                            {"updated_at": time.time(), "advisories": adv_map}, tmp_fh
                        )
                    os.replace(tmp_name, str(data_path))
                except Exception:
                    try:
                        os.unlink(tmp_name)
                    except Exception:
                        pass
            else:
                try:
                    if data_path.exists() or data_path.is_symlink():
                        os.unlink(str(data_path))
                except Exception:
                    pass
    except Exception:
        return


def _pop_queued_advisories(session_id: str) -> List[str]:
    if not session_id:
        return []
    qdir = _advisory_queue_dir(create=False)
    if qdir is None:
        return []
    key = hashlib.sha256(session_id.encode("utf-8")).hexdigest()
    data_path = qdir / f"{key}.json"
    if not data_path.exists():
        return []
    lock_path = qdir / f"{key}.lock"
    flags = os.O_CREAT | os.O_RDWR | getattr(os, "O_NOFOLLOW", 0)
    try:
        fd = os.open(str(lock_path), flags, 0o600)
    except Exception:
        return []
    try:
        with os.fdopen(fd, "r+") as lock_fh:
            if fcntl is not None:
                fcntl.flock(lock_fh.fileno(), fcntl.LOCK_EX)
            if not data_path.exists() or data_path.is_symlink():
                return []
            try:
                raw = json.loads(data_path.read_text(encoding="utf-8"))
            except Exception:
                raw = {}
            try:
                os.unlink(str(data_path))
            except Exception:
                pass
            if isinstance(raw, dict) and isinstance(raw.get("advisories"), dict):
                return [
                    v.strip()
                    for v in raw["advisories"].values()
                    if isinstance(v, str) and v.strip()
                ]
            return []
    except Exception:
        return []


def handle_pre_tool_use(scripts: List[str]) -> int:
    if not scripts:
        return deny_pre_tool_use("No hook scripts configured for PreToolUse.")
    payload, err = read_hook_stdin("PreToolUse")
    if err or payload is None:
        return deny_pre_tool_use(err or "Invalid PreToolUse input.")

    tool_call = payload.get("toolCall")
    if not isinstance(tool_call, dict):
        return deny_pre_tool_use(
            "Missing or invalid toolCall object in PreToolUse input."
        )
    tool_name = tool_call.get("name")
    if not isinstance(tool_name, str) or not tool_name.strip():
        return deny_pre_tool_use(
            "Missing or invalid toolCall.name in PreToolUse input."
        )
    args = tool_call.get("args")
    if not isinstance(args, dict):
        return deny_pre_tool_use(
            "Missing or invalid toolCall.args in PreToolUse input."
        )

    workspaces, ws_err = extract_canonical_workspaces(payload)
    if ws_err or not workspaces:
        return deny_pre_tool_use(ws_err or "Invalid workspacePaths configuration.")

    artifact_dir, art_err = extract_canonical_artifact_dir(payload)
    if art_err:
        return deny_pre_tool_use(art_err)

    effective_cwd, cmd_owner, cwd_err = resolve_tool_cwd(
        args, workspaces, artifact_dir
    )
    if cwd_err or not effective_cwd or not cmd_owner:
        return deny_pre_tool_use(cwd_err or "Invalid Cwd configuration.")

    session_id = payload.get("conversationId") or payload.get("session_id") or ""
    if not isinstance(session_id, str):
        return deny_pre_tool_use("Invalid conversationId in PreToolUse input.")

    advisories: List[str] = []

    if tool_name in COMMAND_TOOLS:
        cmd = args.get("CommandLine")
        if not isinstance(cmd, str):
            return deny_pre_tool_use("run_command requires string CommandLine.")
        norm_input = {
            "hook_event_name": "PreToolUse",
            "session_id": session_id,
            "cwd": cmd_owner,
            "workspacePaths": [cmd_owner],
            "tool_name": "Bash",
            "tool_input": {"command": cmd},
        }
        for script in scripts:
            rc, stdout, stderr = run_hook_script(script, norm_input)
            if rc != 0:
                sanitized = sanitize_hook_stderr(script, stderr)
                return deny_pre_tool_use(sanitized or f"Blocked by {script}.")
            adv = extract_advisory_message(stdout)
            if adv:
                advisories.append(adv)
        return allow_pre_tool_use("\n".join(advisories) if advisories else None)

    if tool_name in EDIT_TOOLS:
        edits, edit_err = normalize_edit_operations(
            tool_name, args, effective_cwd, workspaces, artifact_dir
        )
        if edit_err or not edits:
            return deny_pre_tool_use(edit_err or "Invalid edit arguments.")
        for item in edits:
            owner_ws = item["owning_workspace"]
            is_art = bool(item.get("is_artifact"))
            for script in scripts:
                if is_art and script in PROJECT_ONLY_PRE_SCRIPTS:
                    continue
                if script == "plan-validation-check.sh":
                    tool_input = {
                        "file_path": item["file_path"],
                        "content": item["plan_content"],
                        "new_string": "",
                    }
                else:
                    tool_input = {
                        "file_path": item["file_path"],
                        "content": item["content"],
                        "new_string": item["new_string"],
                    }
                norm_input = {
                    "hook_event_name": "PreToolUse",
                    "session_id": session_id,
                    "cwd": owner_ws,
                    "workspacePaths": [owner_ws],
                    "tool_name": item["tool_name"],
                    "tool_input": tool_input,
                }
                rc, stdout, stderr = run_hook_script(script, norm_input)
                if rc != 0:
                    sanitized = sanitize_hook_stderr(script, stderr)
                    return deny_pre_tool_use(sanitized or f"Blocked by {script}.")
                adv = extract_advisory_message(stdout)
                if adv:
                    advisories.append(adv)
        return allow_pre_tool_use("\n".join(advisories) if advisories else None)

    return deny_pre_tool_use(f"Unhandled PreToolUse tool: {tool_name}")


def extract_post_edit_targets(
    tool_name: str,
    args: Dict[str, Any],
    effective_cwd: str,
    workspaces: List[str],
    artifact_dir: Optional[str] = None,
) -> Tuple[Optional[List[Dict[str, Any]]], Optional[str]]:
    """Extract target file paths and owning workspaces for PostToolUse without pre-edit content reconstruction."""
    if tool_name == "write_file":
        path_arg = args.get("Path")
        if not isinstance(path_arg, str) or not path_arg.strip():
            return None, "Invalid write_file Path."
        resolved, owner, is_art, err = resolve_target_and_workspace(
            path_arg, effective_cwd, workspaces, artifact_dir
        )
        if err or not resolved or not owner:
            return None, err or "Invalid write_file Path."
        return [
            {
                "tool_name": "Write",
                "file_path": resolved,
                "owning_workspace": owner,
                "is_artifact": is_art,
            }
        ], None

    if tool_name == "write_to_file":
        target = args.get("TargetFile")
        if not isinstance(target, str) or not target.strip():
            return None, "Invalid write_to_file TargetFile."
        resolved, owner, is_art, err = resolve_target_and_workspace(
            target, effective_cwd, workspaces, artifact_dir
        )
        if err or not resolved or not owner:
            return None, err or "Invalid write_to_file TargetFile."
        return [
            {
                "tool_name": "Write",
                "file_path": resolved,
                "owning_workspace": owner,
                "is_artifact": is_art,
            }
        ], None

    if tool_name == "edit_file":
        path_arg = args.get("Path")
        if not isinstance(path_arg, str) or not path_arg.strip():
            return None, "Invalid edit_file Path."
        resolved, owner, is_art, err = resolve_target_and_workspace(
            path_arg, effective_cwd, workspaces, artifact_dir
        )
        if err or not resolved or not owner:
            return None, err or "Invalid edit_file Path."
        return [
            {
                "tool_name": "Edit",
                "file_path": resolved,
                "owning_workspace": owner,
                "is_artifact": is_art,
            }
        ], None

    if tool_name == "replace_file_content":
        target = args.get("TargetFile")
        if not isinstance(target, str) or not target.strip():
            return None, "Invalid replace_file_content TargetFile."
        resolved, owner, is_art, err = resolve_target_and_workspace(
            target, effective_cwd, workspaces, artifact_dir
        )
        if err or not resolved or not owner:
            return None, err or "Invalid replace_file_content TargetFile."
        return [
            {
                "tool_name": "Edit",
                "file_path": resolved,
                "owning_workspace": owner,
                "is_artifact": is_art,
            }
        ], None

    if tool_name == "multi_replace_file_content":
        default_target = args.get("TargetFile")
        if default_target is not None and (
            not isinstance(default_target, str) or not default_target.strip()
        ):
            return None, "Invalid multi_replace_file_content TargetFile."
        chunks = args.get("ReplacementChunks")
        if not isinstance(chunks, list) or not chunks:
            return None, "Invalid multi_replace_file_content ReplacementChunks."
        seen: Dict[str, Tuple[str, bool]] = {}
        order: List[str] = []
        for chunk in chunks:
            if not isinstance(chunk, dict):
                return None, "Invalid chunk in ReplacementChunks."
            chunk_target = chunk.get("TargetFile", default_target)
            if not isinstance(chunk_target, str) or not chunk_target.strip():
                return None, "Missing TargetFile in ReplacementChunks."
            resolved, owner, is_art, err = resolve_target_and_workspace(
                chunk_target, effective_cwd, workspaces, artifact_dir
            )
            if err or not resolved or not owner:
                return None, err or "Invalid chunk TargetFile."
            if resolved not in seen:
                seen[resolved] = (owner, is_art)
                order.append(resolved)
        return [
            {
                "tool_name": "Edit",
                "file_path": r,
                "owning_workspace": seen[r][0],
                "is_artifact": seen[r][1],
            }
            for r in order
        ], None

    return None, f"Unsupported edit tool: {tool_name}"


def handle_post_tool_use(scripts: List[str]) -> int:
    payload, err = read_hook_stdin("PostToolUse")
    if err or payload is None:
        return emit_json({})

    # Do not record metrics or queue advisories when the tool failed at runtime.
    tool_error = payload.get("error")
    if tool_error is not None and (
        not isinstance(tool_error, str) or bool(tool_error.strip())
    ):
        return emit_json({})

    tool_call = payload.get("toolCall")
    if not isinstance(tool_call, dict):
        return emit_json({})
    tool_name = tool_call.get("name")
    args = tool_call.get("args")
    if not isinstance(tool_name, str) or not isinstance(args, dict):
        return emit_json({})

    workspaces, ws_err = extract_canonical_workspaces(payload)
    if ws_err or not workspaces:
        return emit_json({})

    artifact_dir, art_err = extract_canonical_artifact_dir(payload)
    if art_err:
        return emit_json({})

    effective_cwd, _, cwd_err = resolve_tool_cwd(args, workspaces, artifact_dir)
    if cwd_err or not effective_cwd:
        return emit_json({})

    session_id = payload.get("conversationId") or payload.get("session_id") or ""
    if not isinstance(session_id, str):
        session_id = ""

    if tool_name in EDIT_TOOLS:
        edits, edit_err = extract_post_edit_targets(
            tool_name, args, effective_cwd, workspaces, artifact_dir
        )
        if not edit_err and edits:
            for item in edits:
                if item.get("is_artifact"):
                    continue
                owner_ws = item["owning_workspace"]
                file_path = item["file_path"]
                for script in scripts:
                    if script == "plan-validation-check.sh":
                        if not _is_exec_plan_path(file_path) or not session_id:
                            continue
                        plan_text = ""
                        if os.path.isfile(file_path):
                            try:
                                with open(file_path, "r", encoding="utf-8") as fh:
                                    plan_text = fh.read(MAX_INPUT_BYTES)
                            except Exception:
                                plan_text = ""
                        elif isinstance(args.get("Content"), str):
                            plan_text = args["Content"]
                        elif isinstance(args.get("CodeContent"), str):
                            plan_text = args["CodeContent"]
                        if plan_text:
                            plan_input = {
                                "hook_event_name": "PreToolUse",
                                "session_id": session_id,
                                "cwd": owner_ws,
                                "workspacePaths": [owner_ws],
                                "tool_name": "Write",
                                "tool_input": {
                                    "file_path": file_path,
                                    "content": plan_text,
                                    "new_string": "",
                                },
                            }
                            _, stdout, _ = run_hook_script(script, plan_input)
                            adv = extract_advisory_message(stdout)
                            _update_queued_advisory(session_id, file_path, adv)
                        else:
                            _update_queued_advisory(session_id, file_path, None)
                        continue

                    norm_input = {
                        "hook_event_name": "PostToolUse",
                        "session_id": session_id,
                        "cwd": owner_ws,
                        "workspacePaths": [owner_ws],
                        "tool_name": item["tool_name"],
                        "tool_input": {"file_path": file_path},
                    }
                    _, _, stderr = run_hook_script(script, norm_input)
                    if stderr and (
                        "not writable" in stderr
                        or "cannot create or write" in stderr
                        or "failed to write" in stderr
                    ):
                        sys.stderr.write(
                            "PostToolUse metrics skipped: project state directory is not writable.\n"
                        )

    return emit_json({})


def handle_pre_invocation(_scripts: List[str]) -> int:
    payload, err = read_hook_stdin("PreInvocation")
    if err or payload is None:
        return emit_json({})

    session_id = payload.get("conversationId") or payload.get("session_id") or ""
    if not isinstance(session_id, str) or not session_id:
        return emit_json({})

    advisories = _pop_queued_advisories(session_id)
    if advisories:
        return emit_json(
            {
                "injectSteps": [
                    {
                        "ephemeralMessage": "\n\n".join(advisories),
                    }
                ]
            }
        )
    return emit_json({})


def handle_session_start(scripts: List[str]) -> int:
    payload, err = read_hook_stdin("SessionStart")
    if err or payload is None:
        return emit_json({})

    workspaces, ws_err = extract_canonical_workspaces(payload)
    if ws_err or not workspaces:
        return emit_json({})

    session_id = payload.get("conversationId") or payload.get("session_id") or ""
    if not isinstance(session_id, str):
        session_id = ""

    primary_ws = workspaces[0]
    norm_input = {
        "hook_event_name": "SessionStart",
        "session_id": session_id,
        "cwd": primary_ws,
        "workspacePaths": workspaces,
    }
    messages: List[str] = []
    for script in scripts:
        _, stdout, _ = run_hook_script(script, norm_input)
        adv = extract_advisory_message(stdout)
        if adv:
            messages.append(adv)

    if messages:
        return emit_json(
            {
                "injectSteps": [
                    {
                        "systemMessage": {
                            "systemMessage": "\n".join(messages),
                        }
                    }
                ]
            }
        )
    return emit_json({})


def _is_turn_end_invocation(payload: Dict[str, Any]) -> bool:
    """Return True only when the latest transcript step is a completed model reply with no tool calls."""
    transcript_path = payload.get("transcriptPath")
    if not isinstance(transcript_path, str) or not transcript_path.strip():
        return True
    if not os.path.isfile(transcript_path):
        return True
    try:
        size = os.path.getsize(transcript_path)
        tail_bytes = 262144  # 256 KiB easily covers compact transcript tail
        with open(transcript_path, "rb") as fh:
            if size > tail_bytes:
                fh.seek(size - tail_bytes)
                chunk = fh.read().decode("utf-8", errors="replace")
                nl = chunk.find("\n")
                if nl == -1:
                    return False
                chunk = chunk[nl + 1 :]
            else:
                chunk = fh.read().decode("utf-8", errors="replace")
        lines = [ln.strip() for ln in chunk.splitlines() if ln.strip()]
        if not lines:
            return True
        last = json.loads(lines[-1])
        if not isinstance(last, dict):
            return False
        if last.get("type") != "PLANNER_RESPONSE":
            return False
        if last.get("status") not in (None, "DONE"):
            return False
        if last.get("tool_calls"):
            return False
        trunc = last.get("truncated_fields")
        if isinstance(trunc, list) and "tool_calls" in trunc:
            return False
        return True
    except Exception:
        return False


def handle_post_invocation(scripts: List[str]) -> int:
    payload, err = read_hook_stdin("PostInvocation")
    if err or payload is None:
        return emit_json({})

    if not _is_turn_end_invocation(payload):
        return emit_json({})

    workspaces, ws_err = extract_canonical_workspaces(payload)
    if ws_err or not workspaces:
        return emit_json({})

    session_id = payload.get("conversationId") or payload.get("session_id") or ""
    if not isinstance(session_id, str):
        session_id = ""

    primary_ws = workspaces[0]
    norm_input = {
        "hook_event_name": "Stop",
        "session_id": session_id,
        "cwd": primary_ws,
        "workspacePaths": workspaces,
        "stop_hook_active": False,
    }
    messages: List[str] = []
    for script in scripts:
        _, stdout, _ = run_hook_script(script, norm_input)
        adv = extract_advisory_message(stdout)
        if adv:
            messages.append(adv)

    # Render human-facing gate ladder / doc-drift summary inline via user_markdown
    # with empty model systemMessage ("") and default terminationBehavior (never force_continue).
    if messages:
        return emit_json(
            {
                "injectSteps": [
                    {
                        "systemMessage": {
                            "systemMessage": "",
                            "metadata": {
                                "user_markdown": "\n\n".join(messages),
                            },
                        }
                    }
                ]
            }
        )
    return emit_json({})


def handle_stop(_scripts: List[str]) -> int:
    # Turn-end human-facing doc-drift-check.sh output is surfaced via PostInvocation
    # (metadata.user_markdown). Antigravity's Stop contract only consumes reason when
    # decision=="continue", and rule no-orchestration forbids continuing the turn,
    # so validate stdin and return safe empty JSON {} without duplicate git/find I/O.
    read_hook_stdin("Stop")
    return emit_json({})


def main(argv: List[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write(
            "Usage: antigravity-adapter.py <SessionStart|PreInvocation|PreToolUse|PostToolUse|PostInvocation|Stop> [hook.sh ...]\n"
        )
        return 2
    event = argv[1]
    scripts = argv[2:]
    if event == "PreToolUse":
        return handle_pre_tool_use(scripts)
    if event == "PostToolUse":
        return handle_post_tool_use(scripts)
    if event == "PreInvocation":
        return handle_pre_invocation(scripts)
    if event == "PostInvocation":
        return handle_post_invocation(scripts)
    if event == "SessionStart":
        return handle_session_start(scripts)
    if event == "Stop":
        return handle_stop(scripts)
    return deny_pre_tool_use(f"Unsupported hook event: {event}")


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv))
    except Exception:
        if len(sys.argv) > 1 and sys.argv[1] == "PreToolUse":
            deny_pre_tool_use("Internal error in Antigravity PreToolUse adapter.")
            sys.exit(0)
        emit_json({})
        sys.exit(0)
