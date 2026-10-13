# Decision Signals — the Gate API

oh-my-agents emits two small, machine-readable **decision signals**. They are the
plugin's durable, irreplaceable position: the **verification layer** that everything
else gates on. This file is their single source of truth — `/verify`,
`/harness-review`, and `/lifecycle` reference it instead of restating the contract.

## Why this is a public contract (not an internal detail)

Native **Dynamic Workflows** cannot take mid-run user input — "for sign-off between
stages, run each stage as its own workflow." That makes a **machine-readable stage
boundary** mandatory infrastructure, and these signals are already exactly that shape.
So they are promoted to a versioned **Gate API** consumed by:

- **the pre-`/ship` convention** — the accountable human checks both signals before
  invoking gstack `/ship` (see "Pre-ship check" below; whether gstack itself reads them
  is `VERIFIED | ASSERTED` per the contract-check probe — never assumed)
- **`/lifecycle`** (routes / projects the next phase on the decision)
- **Dynamic Workflow** stages (a stage ends by writing a signal; the next stage gates on it)
- **native Agent Teams** (the team-lead reads the signal as the Evaluator verdict)
- **the gate ladder** (`doc-drift-check.sh` — SessionStart: the model's context on
  startup / resume / compact / fork; Stop: the human, `systemMessage` only) — names the next
  gate skill and the first typed items off a FRESH signal only (§ Gate ladder below)

> **The bright line (council canon, 2026-06-06):** a stage's terminal artifact is a
> **SIGNAL** (ours) or a **DEPLOYED ARTIFACT** (gstack's). We own signals; we never
> produce the deployed artifact.

## Contract rules (apply to BOTH signals)

1. **Versioned.** Every signal carries `schema_version` (integer, starts at `1`).
   A consumer that does not recognize the version MUST default-deny (treat as the
   blocking decision), never guess.
2. **Default-deny.** Missing file, malformed JSON, stale signal, or unknown
   `schema_version` ⇒ the blocking decision (`RED` for verify, `NEEDS_HUMAN` for review).
   An automated chain never advances on an absent/unreadable signal.
3. **Enum stability = append-only.** Never repurpose an existing enum value. New states
   are added, old states keep their meaning forever — external consumers pin on them.
4. **Latest-only + ≤500 bytes.** The signal is a decision artifact, not a report. The
   verbose report lives in the matching `.claude/metrics/*.jsonl` history log.
5. **Atomic-ish write.** Write the signal even on early exit. Producers compute fields
   with `python3`/`jq`/`printf` (correct escaping) — never an unquoted heredoc.
5b. **Rooted at the project root, never the shell cwd** (`project-root`). Every path in this
   document is relative to the project root. Producers and consumers resolve it explicitly —
   `ROOT=$(source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && harness_root)` — because a
   build or test step may have left the session in a subdirectory. A signal written to
   `backend/.claude/signals/` is one no consumer looks for, and under `default-deny` that
   reads as *absent* ⇒ blocking. Silent, and indistinguishable from a signal that said OK.
5c. **History logs have ONE writer.** `verify.jsonl` / `reviews.jsonl` are appended through
   `append_history_record` (hooks/lib/common.sh): validated JSON, flock, LOUD on failure.
   A prose "append the record" instruction is not a writer — it is how the 2026-05-23 P0
   happened. (Contract rules are named — `versioned`, `default-deny`, `append-only`,
   `latest-only`, `atomic-write`, `project-root`, `one-writer`, `accountable-writer` —
   cite them by name, never by number.)
6. **Accountable-writer.** A signal must be written by the entity that *derived* the verdict
   (the `/verify` / `/harness-review` run, or a human). A relay agent handed a decision it did
   not itself compute must NOT write it — the safety classifier correctly treats that as a
   fabricated result (proven by the 2026-06-07 `/harness-audit` spike). Hence a Dynamic
   Workflow *returns* a signal-shaped object; the accountable invoker persists it here.
   Corollary, stated once: a skill or workflow that dies before its write leaves NO signal
   ⇒ default-deny (contract rule above) ⇒ any automated chain halts safely. Mid-run death never needs
   special handling downstream.

### Freshness predicate — `signal_fresh` (ONE implementation, hooks/lib/common.sh)

`signal_fresh <root> <signal> [<decision>] [--advance]` is the only freshness check; every
consumer (the gate ladder, `/lifecycle`, the pre-ship rung, the persist recipe) calls it by
name instead of restating it. Fresh ⇔ the file exists, parses, `schema_version` is known, the
decision matches when asked, and: **`commit == HEAD`** (with `--advance` — the three ADVANCE
points: the pre-ship rung, `/lifecycle --auto`'s projection, the audit persist — also a clean
tree per `worktree_dirty`; our own `.claude/`/`.gstack/` never count), OR `commit != HEAD` but
the signal's optional **`wtree`** equals gstack's live working-tree content fingerprint
(`bin/gstack-wtree`, probed lazily under `timeout 2`, never per turn): a history rewrite, or
committing exactly what was verified, no longer forces a re-verify + re-review. Producers
stamp `wtree` ONLY when that binary is executable AND both ledger dirs are gitignored (`git
check-ignore -q` per path — the fingerprint stages untracked files); the commit path is the
permanent gstack-absent path, never sunset. On failure the predicate prints one reason token
— `absent | nojq | malformed | schema | decision:<x> | stale:commit | stale:dirty |
stale:wtree` — and AUTOMATED consumers default-deny (route as if absent, naming the token); a
HUMAN reads it as a WARN and may knowingly act. A pre-v3.9 signal without `commit` reads
`stale:commit`. Mid-session dirt (no `--advance`) is a WARN, never a halt. No producer-side
`dirty` field, no schema change — `wtree` is optional, `schema_version` stays `1`.

### No-averaging fence (deliberate; do not "improve")

`/verify`'s any-`FAIL` ⇒ `RED` mapping and the acceptance-cap rule (any done task whose
`acceptance` command fails or cannot be confirmed caps the decision at `YELLOW`) are
**hard per-criterion thresholds — fail-any, no averaging** (Anthropic harness-design
rubric pattern: failing ANY criterion fails the sprint). Never replace either with a
weighted or averaged score.

## `verify-latest.json` — produced by `/verify`

Path: `.claude/signals/verify-latest.json` · History: `.claude/metrics/verify.jsonl`

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | integer | Contract version. Current: `1`. |
| `timestamp` | string (ISO-8601 UTC) | When verify concluded |
| `decision` | enum | `GREEN` \| `YELLOW` \| `RED` |
| `scope` | string | `all` \| `build` \| `test` \| `lint` \| `arch` |
| `lint` / `build` / `test` / `arch` | enum | `PASS` \| `FAIL` \| `WARN` \| `SKIP` |
| `first_pass` | boolean | GREEN on the first verify for this plan/branch |
| `plan_id` | string \| null | Active exec-plan id, if `--plan` given |
| `branch` | string | Current git branch |
| `commit` | string (optional) | `git rev-parse HEAD` at derivation time (freshness predicate) |
| `reason` | string (≤120 chars) | One-line rationale, e.g. `3 tests failed` |

Decision mapping: every in-scope check `PASS` (WARN allowed) ⇒ `GREEN`; no `FAIL` but a
`WARN` ⇒ `YELLOW`; any `FAIL` ⇒ `RED`. Additionally (sprint-contract rule, v3.9.0): any
`done` task whose `acceptance` command fails or cannot be confirmed caps the decision at
`YELLOW` with reason `acceptance unconfirmed: <task-id>` — so `YELLOW` can mean
**contract-unmet**, not just lint warnings (fail-any; see the no-averaging fence).

## `review-latest.json` — produced by `/harness-review`

Path: `.claude/signals/review-latest.json` · History: `.claude/metrics/reviews.jsonl`

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | integer | Contract version. Current: `1`. |
| `timestamp` | string (ISO-8601 UTC) | When the review concluded |
| `decision` | enum | `APPROVE` \| `REQUEST_CHANGES` \| `NEEDS_HUMAN` |
| `needs_human_kind` | enum \| null | Only when `decision=NEEDS_HUMAN` (see below) |
| `merge_recommendation` | enum | `TRIVIAL` \| `STANDARD` \| `COMPLEX` |
| `p0_count` / `p1_count` / `p2_count` | integer | Issue counts by severity |
| `tags_present` | string[] | Subset of `[HARNESS]`/`[STRUCTURAL]`/`[CROSS-MODEL]`/`[SECURITY]`/`[UX]`/`[BOTH+]` |
| `gstack_composed` | boolean | True if any gstack skill was composed |
| `commit` | string (optional) | `git rev-parse HEAD` at derivation time (freshness predicate) |
| `gstack_context` | object \| null | gstack verdict, read read-only for reconciliation (below): `{present, review_status, currency, source}`. `null`/absent when the gstack decision layer is not present. `decisions_unresolved` is DEPRECATED-optional (v3.10.0: never produced — `decisions.active.json` is a rebuildable cache; consumers tolerate its absence; kept documented so `schema_version` stays 1 under `append-only`) |
| `plan_id` | string \| null | Active exec-plan id, if any |
| `reason` | string (≤120 chars) | One-line rationale |

### `needs_human_kind` — fine-grained NEEDS_HUMAN

Set **by `/harness-review`**, never inferred downstream. Splits one halt bucket into a
recoverable case and two real halts, so an automated chain stops only when it must:

| Value | Meaning | `/lifecycle` routing |
|-------|---------|----------------------|
| `composition-skipped` | `/codex` or `/cso` was not run (e.g. `--no-gstack`) | **auto-recover**: next step is to re-run the skipped composition; not a human halt |
| `arch-ambiguity` | Architectural decision needs a human call | **hard halt** |
| `judgment-slop` | Judgment-dependent slop; taste call needed | **hard halt** |

`decision=NEEDS_HUMAN` with `needs_human_kind` absent ⇒ treat as a hard halt (default-deny).

## Reconciliation with gstack v1.57.5+ native verdicts

As of **gstack v1.57.5** gstack ships its own event-sourced decision layer
(`~/.gstack/projects/<slug>/decisions.jsonl` + `decisions.active.json`), and **v1.57.7**
makes every plan/review end in a verdict line that blocks gstack's own approval gate;
`/review` writes a machine verdict via `gstack-review-log` (`status: clean|issues_found`).
Two independent gates that disagree would confuse `/ship`. The rule keeps **one accountable
arbiter** without violating the SIGNAL-not-ARTIFACT bright line:

1. **We stay the arbiter.** `/harness-review` derives `decision` from its OWN four-pillar
   findings. gstack's verdict is **read-only advisory context**, never an input that
   mechanically rewrites our decision and never an aggregate.
2. **Surface, don't merge.** When the gstack layer is present, record it in the optional
   `gstack_context` object (small, within the ≤500-byte cap), e.g.
   `{"present":true,"review_status":"issues_found","currency":"current","source":"gstack-review-log"}`,
   and show both verdicts side-by-side in the report text. **Currency (v3.10.0):** gstack's
   review records are content-addressed (`wtree` = working-tree fingerprint from
   `bin/gstack-wtree`); a record whose `wtree` differs from the live one is STALE and is
   treated as absent — loudly (`verdict-stale`), never as agreement or divergence.
3. **Agree ⇒ pass through.** If gstack and our pass agree on direction (both block or both
   allow), emit our `decision` unchanged.
4. **Diverge ⇒ halt for judgment.** If they point opposite directions (e.g. we'd `APPROVE`
   but `gstack-review-log` is `issues_found`, or vice-versa), emit
   `decision=NEEDS_HUMAN`, `needs_human_kind=judgment-slop`, and name the disagreement in
   `reason`. A human reconciles; we never silently override either system.
5. **Read-only + graceful degrade.** We only *read* gstack paths (`gbrain`/glob), never
   write them. Absence of the gstack layer ⇒ `gstack_context` is `null`/omitted and our
   signal stands alone (unchanged behavior for gstack < v1.57.5).

`gstack_context` is an **optional** field ⇒ `schema_version` stays `1` (consumers that
don't read it are unaffected; the versioning policy below covers this).

## History logs — `verify.jsonl` / `reviews.jsonl` (the verbose side of each signal)

The ≤500-byte cap (`latest-only`) binds the two signal FILES only. Each history line is
the signal object plus report detail, appended through `append_history_record`
(`one-writer`). `reviews.jsonl` lines carry the typed work list a `REQUEST_CHANGES`
hands to the next Generator turn:

| Field | Type | Description |
|-------|------|-------------|
| `findings[]` (reviews.jsonl) | array ≤10, ≤4 KB | `{fingerprint: "<file>:<line>:<dimension>", severity: P0\|P1\|P2, tag: [HARNESS]\|…, fix: "<≤80 chars>", needs_human?: arch-ambiguity\|judgment-slop}` — highest severity first; `needs_human` is set by the separate judge and COMPUTES `decision=NEEDS_HUMAN` |
| `dimension` | enum | `slop\|arch\|docs\|observ\|contract\|reconcile` — our four-pillar vocabulary (the same `/harness-audit` returns); never gstack's `CRITICAL\|INFORMATIONAL` |
| `failures[]` (verify.jsonl) | array ≤10, ≤4 KB | `{check: lint\|build\|test\|arch, id: "<test name \| file:line>", task_id: "<plan tasks[].id>"\|null, message: "<≤80 chars>"}` — the RED twin of `findings[]`; `reason` == `failures[0].message` verbatim |

Consumers: the gate ladder (RED rung: first ≤3 `failures[].id`; REQUEST_CHANGES rung: first
≤3 `findings[].fingerprint`), `/lifecycle` (`REQUEST_CHANGES` routing — a count is not a
work item; `recover` retries `failures[].task_id`), `/verify`'s recurring-failure jq over
`failures[].id`, `/harness-dashboard` velocity, and the Stop termination sensor
(`verify.jsonl`: three consecutive `RED` with the same `reason` ⇒ the loop is not
converging; it names `/investigate` / `/encode-mistake`, never another `/verify` — so
producers keep `reason` stable for the same failure).

## Gate ladder — ONE mapping, two renderings (`hooks/doc-drift-check.sh`)

Rendered at `SessionStart` (startup / resume / compact / fork) into the MODEL's context and
at `Stop` for the HUMAN (`systemMessage` only — at Stop an `additionalContext` key would
CONTINUE the turn under the platform's 8-continuation cap; a hook that NAMES the next skill
never does that, and a re-entry turn — `stop_hook_active` — gets zero bytes). Rungs, first
match wins, each riding a FRESH signal (`signal_fresh`): stale WARN → `composition-skipped`
(re-run the composition) → **APPROVE = the pre-ship check** (`signal_fresh verify-latest.json
GREEN --advance && signal_fresh review-latest.json APPROVE --advance` ⇒ `SHIP GATE: pass —
next: gstack /ship`; APPROVE without a GREEN at HEAD names `/verify`, never `/ship`; a dirty
tree WARNs) → REQUEST_CHANGES (first ≤3 `findings[].fingerprint` — fix, then `/verify`) →
hard NEEDS_HUMAN (`arch-ambiguity` / `judgment-slop` / kind absent — no automated step) →
RED (first ≤3 `failures[].id`) → YELLOW (its `reason`) → GREEN with no newer review
(`/harness-review`) → an active plan with in-progress tasks and no verify at HEAD
(`/verify --plan <id>` — the execute→verify push that needs no model-written JSON). Stop
additionally carries doc drift and the termination sensor; the gate line is assembled first
so the 400-char cap never trims the hand-off.

## Native consumers

- **User-opt-in `TaskCompleted` gate** — in the USER's `settings.json` (commit-only, inline
  jq: a user hook is not plugin-launched, so nothing of ours is sourced and no install path
  is hard-coded): `ls docs/exec-plans/active/*.json >/dev/null 2>&1 || exit 0; HEAD=$(git rev-parse HEAD); jq -e --arg head "$HEAD" 'select(.decision=="GREEN" and .commit==$head)' .claude/signals/verify-latest.json >/dev/null || { echo "verify-latest RED/stale — run /verify --plan <id>" >&2; exit 2; }`
  Default-deny is the point: with an active plan and no GREEN at HEAD, every task close is
  refused (stderr fed back to the model) until `/verify` runs.
- **A Dynamic Workflow stage** is `agent('run /verify --plan X and report', {schema})` and
  gates on the signal FILE; an Agent Team lead reads the same file.
- The `NEXT:` JSON tail line of `/lifecycle next` was retired v3.11.0 — zero consumers in two
  cycles; executors read the signal files, or declare a schema on their own `agent()` call.

## Pre-ship check — the ladder's APPROVE rung (our-side convention)

No evidence confirms gstack `/ship` reads these signals (verified again against gstack
v1.84.1 source, 2026-09-11: zero references outside gstack's own tests — ASSERTED is the
confirmed state, not a probe miss). The gate is OUR side's convention, rendered by the gate
ladder's APPROVE rung — `signal_fresh verify-latest.json GREEN --advance && signal_fresh
review-latest.json APPROVE --advance` ⇒ `SHIP GATE: pass`. One mapping, one predicate, no
parallel snippet to paste. The one bilateral surface is gstack's own `bin/gstack-verify-gate`
(Stop hook, opt-in, `--trust`-gated, fail-open, 3 bounded re-entries) reading
`<!-- gstack:verify: <cmd> -->` from the PROJECT's CLAUDE.md — `/harness-init` EXPORTS that
line from the confirmed test command (ours→gstack); `/verify` reads the commands table as
primary and the marker only as a named fallback.

## Persisting a `/harness-audit` result — the ONLY sanctioned recipe

The workflow (`/oh-my-agents:harness-audit`, shipped from the plugin root `workflows/`)
RETURNS `{signal, confirmed, refuted, stats}` (accountable-writer, contract rule above); no
relay agent may write it. The accountable invoking human reviews the
returned object, then persists it with ONE command that stamps `timestamp` + `commit`
(without the commit stamp the persisted signal is stale-by-definition), refuses a dirty
tree (the stamp would mint a maximally-fresh verdict over code that was never audited),
writes ONLY `signal` to the signal file (≤500 bytes), and `signal` + `findings[]` (from
`confirmed`, mapped to the history-log shape above) to the history log:

```bash
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh"; ROOT=$(harness_root)   # rule project-root
worktree_dirty "$ROOT" && { echo "refusing: uncommitted changes since the audit"; exit 1; }
python3 -c '
import json, subprocess, sys, datetime
ret = json.load(open(sys.argv[1]))          # the WHOLE returned object, saved to a file
root = sys.argv[2]
sig = ret["signal"]; sig.pop("_persistence", None)
sig["timestamp"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
sig["commit"] = subprocess.check_output(["git", "-C", root, "rev-parse", "HEAD"], text=True).strip()
# optional: sig["wtree"] = <bin/gstack-wtree output> — same rule as /verify (executable AND ledger dirs gitignored)
sig["reason"] = ("source:harness-audit " + sig.get("reason", ""))[:120]
open(root + "/.claude/signals/review-latest.json", "w").write(json.dumps(sig))
order = {"P0": 0, "P1": 1, "P2": 2}
findings = [{"fingerprint": "%s:%s:%s" % (f["file"], f.get("line") or "0", f["dimension"]),
             "severity": f["severity"], "tag": "[HARNESS]", "fix": f["title"][:80]}
            for f in sorted(ret.get("confirmed", []), key=lambda f: order.get(f["severity"], 9))[:10]]
print(json.dumps(dict(sig, findings=findings)))
' /path/to/returned.json "$ROOT" > /tmp/audit-history.json \
&& append_history_record "$ROOT/.claude/metrics" reviews.jsonl "$(cat /tmp/audit-history.json)"
```

## Versioning policy

- Adding an optional field ⇒ same `schema_version` (consumers ignore unknown fields).
- Adding a new enum value ⇒ same `schema_version` (append-only; consumers default-deny unknowns).
- Removing/renaming a field or repurposing an enum ⇒ **breaking**: bump `schema_version`
  and update this file + both producers + every consumer in the same change.

Anchors: [docs/TEAM-DISCUSSION-2026-06-06.md](TEAM-DISCUSSION-2026-06-06.md) (Gate API),
[docs/TEAM-DISCUSSION-2026-09-04.md](TEAM-DISCUSSION-2026-09-04.md) (dirty-tree clause, history-log
schema, termination sensor, currency), [docs/TEAM-DISCUSSION-2026-09-11.md](TEAM-DISCUSSION-2026-09-11.md)
(`signal_fresh` + `wtree`, the gate ladder as the pre-ship check, `failures[]`, computed
review decision, native consumers).
