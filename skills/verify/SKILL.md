---
name: verify
description: "Run project build, tests, lint and architecture checks, then save a GREEN/YELLOW/RED decision and typed failures for the next task. Use after implementation and before independent review. 验证、验收、测试。"
---

# Verify

Arguments in the user's message select `all|build|test|lint|arch` (default `all`) and optional
`--plan <id>`. Read `docs/SIGNALS.md` before deriving or writing a decision.

1. Find the project root through Git or an explicit project path; keep it fixed even if
   commands run in a subdirectory. Read applicable AGENTS.md, CI and manifests for commands.
   Prefer documented checks; do not invent a command or enable automatic lint fixes.
2. Select the named active plan, or the only `docs/exec-plans/active/*.json` match. Multiple
   plans require explicit selection; continue shared checks and report omitted mapping.
3. Run in-scope checks in useful dependency order: lint, build, test, architecture. Capture
   the original exit code and current-run output. PASS, FAIL, WARN and SKIP are distinct.
   Count tests and skips when the runner reports them. Zero tests do not establish PASS.
   A missing required tool/test is unconfirmed evidence, not a green check. Record
   `required_checks` from actual project instructions/CI; inapplicable checks may be SKIP
   with a reason. Do not remove a failed check from that list to pass the gate.
4. Run each in-progress/done task's acceptance command or map it to a test already executed.
   Failure makes the decision RED. Unexecuted or unverifiable required acceptance caps it at
   YELLOW. Mark a task done only when its acceptance was confirmed in this run.
5. Investigate setup failures and retry after a meaningful correction. Distinguish code
   defects from environment blockers. Do not disable assertions or lower checks to pass.
6. Derive RED for any FAIL; YELLOW for warnings or required SKIP/unconfirmed acceptance;
   GREEN only for all required checks passing. Out-of-scope checks may be SKIP, but a partial
   scope cannot satisfy a full release gate. Record the scope explicitly.
7. Write `.codex/signals/verify-latest.json` and append a validated record with typed
   `failures[]` to `.codex/metrics/verify.jsonl`. Anchor all paths to the project root.
   Resolve `PLUGIN_DIR` from this skill's installed path, then source
   `"$PLUGIN_DIR/hooks/lib/common.sh"` and use `append_history_record` for history.
   Use JSON encoding; no unquoted placeholder heredocs. Signals include HEAD and freshness
   evidence from the contract. The latest signal is compact; detailed evidence is in history.
8. Report the decision, executed checks/counts, failures and next action. Name
   `$oh-my-agents:harness-review` after a full GREEN result, or the failed checks after RED.

Never turn a warning, missing prerequisite or unexecuted command into a passing claim.
