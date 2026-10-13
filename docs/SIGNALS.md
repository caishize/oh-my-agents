# Decision signals — Gate API

Two project-root records carry compact, versioned decisions:
`.codex/signals/verify-latest.json` and `.codex/signals/review-latest.json`.
Consumers are the hook ladder, `$oh-my-agents:lifecycle`, `$oh-my-agents:harness-dashboard` and `scripts/gate.sh`.
No delivery tool is assumed to read them.

## Shared contract

- `schema_version`: integer 1. Missing, malformed, unknown-version or stale evidence denies
  advancement (verify RED / review NEEDS_HUMAN). Unknown decision enums also deny.
- Latest record is compact (≤500 UTF-8 bytes). Full reports live in history JSONL.
- Include `ts` (UTC ISO 8601), `branch`, `commit` (full HEAD), `decision`, and `reason`
  (≤120 characters). Resolve ROOT once; do not write relative to a changed shell cwd.
- Derive from current-run evidence, then atomically replace the latest file using a temporary
  file in the same directory. A failed run writes its blocking decision when possible.
- Only the accountable verifier/reviewer derives and persists the decision; a model's
  untested claim or relay message is not evidence.
- Append history through `append_history_record` in hooks/lib/common.sh (JSON validation,
  flock, visible failure). Resolve PLUGIN_DIR from the installed skill, source the library,
  then call `append_history_record "$ROOT/.codex/metrics" verify.jsonl "$RECORD_JSON"`.
- Ignore `.codex/signals/` and `.codex/metrics/` in Git. Old `.claude/` records are not migrated.

## Verification

Decision: GREEN = all required checks passed; YELLOW = warnings or required unconfirmed
checks/acceptance; RED = failed checks. Zero-test and missing-required-tool results are not
PASS. Scope is `all|build|test|lint|arch`; partial scope cannot satisfy the full release gate.
`checks` maps build/test/lint/arch to PASS/FAIL/WARN/SKIP. An optional nonempty
`required_checks` array names the applicable checks confirmed from project instructions/CI;
only those must PASS. Inapplicable checks may be SKIP with an explanation in history. If
required_checks is omitted, all four are required. Unknown names and an empty list deny
release. Include optional `plan_id`, `first_pass` and freshness fingerprint.

Example (encode dynamically, never write these placeholders as a real result):

```json
{"schema_version":1,"ts":"2026-10-12T00:00:00Z","branch":"feature","commit":"<full HEAD>","scope":"all","decision":"GREEN","checks":{"build":"PASS","test":"PASS","lint":"PASS","arch":"PASS"},"reason":"all required checks passed"}
```

History `.codex/metrics/verify.jsonl` adds `failures[]` (≤10, ≤4 KiB):
`{check, id, task_id, message}` where check is build/test/lint/arch, id identifies the
check/file, task_id is a plan task or null, message ≤80 characters. RED reason equals the
first failure's message to support recurrence detection. Report warnings/skips separately.

## Independent review

Decision: APPROVE = independent review found no P0/P1 or unresolved ambiguity;
REQUEST_CHANGES = any confirmed P0/P1; NEEDS_HUMAN = unresolved evaluation/architecture.
`needs_human_kind` is `composition-skipped`, `arch-ambiguity`, or `judgment-slop` when needed.
No independent evaluator yields judgment-slop with the reason explaining availability.
The history records the evaluation method and confirmed findings; no self-review APPROVE.

History `.codex/metrics/reviews.jsonl` adds typed `findings[]` (≤10, ≤4 KiB), each with
`fingerprint` (file:line:rule), `severity` P0/P1/P2, `tag` and `fix`. Optional gstack evidence
is reconciled read-only, not aggregated into an untraceable decision.

## Freshness

`signal_fresh <root> <filename> [decision] [--advance]` is the shared predicate.
It checks schema/enum and HEAD equality. At advancement, the tree must be clean; our own
state ledgers are excluded. An optional gstack `wtree` content fingerprint permits history
changes when the verified content is identical. Only stamp it when gstack-wtree is executable
and both ledger directories are ignored; producers must not mutate gstack files.

Without a content fingerprint, verify/review a committed tree. Committing exactly what was
checked changes HEAD and requires rerunning the checks. Never stamp a future commit or
reuse a stale record. Advisory-only calls may explain current state; release uses --advance.

## Explicit release gate

`bash "$PLUGIN_DIR/scripts/gate.sh" "$ROOT"` exits nonzero unless full verification GREEN
and independent review APPROVE are fresh. It does not commit, push, merge or deploy.
Missing or invalid signals fail. Hooks present the next action and first typed failure/fix;
Stop advisories never request continuation or fabricate permission decisions.
