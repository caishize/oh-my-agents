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
- **the Stop-time gate-state nudge** (`doc-drift-check.sh` — names the next gate skill
  off a FRESH signal only)

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
5b. **Rooted at the project root, never the shell cwd.** Every path in this document is
   relative to the project root. Producers and consumers resolve it explicitly —
   `ROOT=$(source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && harness_root)` — because a
   build or test step may have left the session in a subdirectory. A signal written to
   `backend/.claude/signals/` is one no consumer looks for, and under rule 2 that reads as
   *absent* ⇒ blocking. Silent, and indistinguishable from a signal that said OK.
6. **Accountable-writer.** A signal must be written by the entity that *derived* the verdict
   (the `/verify` / `/harness-review` run, or a human). A relay agent handed a decision it did
   not itself compute must NOT write it — the safety classifier correctly treats that as a
   fabricated result (proven by the 2026-06-07 `/harness-audit` spike). Hence a Dynamic
   Workflow *returns* a signal-shaped object; the accountable invoker persists it here.
   Corollary, stated once: a skill or workflow that dies before its write leaves NO signal
   ⇒ default-deny (contract rule above) ⇒ any automated chain halts safely. Mid-run death never needs
   special handling downstream.

### Freshness predicate (v3.9.0)

Both signals carry an optional `commit` field: the `git rev-parse HEAD` sha at the moment
the verdict was derived. The predicate:

- Any **AUTOMATED** consumer (hook, workflow stage, Agent Team lead, `/lifecycle` routing)
  MUST treat a signal whose `commit` differs from the current `HEAD` (or whose `branch`
  differs from the current branch) as **default-deny** — route as if the signal were
  absent, and name the mismatch.
- A **HUMAN** consumer sees a WARN and decides; humans may knowingly act on a stale signal.
- A signal without `commit` (pre-v3.9.0 producer) is treated by automated consumers as
  stale-unknown: WARN + re-run recommendation, never silent advance.

This is what makes push-style stage nudges (plan-complete → `/verify`; Stop-time
gate-state → `/harness-review` / gstack `/ship`) safe: a nudge is only ever emitted off a
FRESH signal.

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
| `gstack_context` | object \| null | gstack v1.57.5+ verdict, read read-only for reconciliation (below). `null`/absent when the gstack decision layer is not present |
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
   `{"present":true,"review_status":"issues_found","decisions_unresolved":2,"source":"gstack-review-log"}`,
   and show both verdicts side-by-side in the report text.
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

## Related: the `NEXT:` tail line — router OUTPUT, not a signal

`/lifecycle next` (and `--auto`) always ends its output with one machine-parseable line —
`NEXT: {"phase":…,"skill":…,"args":[…],"gates":[…],"advisory":true}` — parsed by whoever
invoked the router (the shape Dynamic Workflows' structured-output capture consumes).
It is invocation OUTPUT with zero persistence, not one of the two decision signals; it
never gates anything, and emitting it is naming, never invoking (rule no-orchestration).
Its predecessor — the cached `.claude/signals/lifecycle-next.json` file (`--emit-next`) —
was retired in v3.9.0 after a full cycle with zero consumers: native executors read
invocation output, not files that can be read stale.

## Pre-ship check — our-side convention (not a verified gstack contract)

No evidence confirms gstack `/ship` reads these signals (see INTEGRATION.md — the
contract-check probe reports `VERIFIED | ASSERTED`). The gate is therefore OUR side's
convention: the accountable human (or their project harness config) runs this before
invoking `/ship`:

```bash
ROOT=$(source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && harness_root)   # rule 5b
HEAD_SHA=$(git -C "$ROOT" rev-parse HEAD)
jq -e --arg head "$HEAD_SHA" \
  'select(.decision=="GREEN" and (.commit // $head)==$head)' "$ROOT/.claude/signals/verify-latest.json" >/dev/null \
&& jq -e --arg head "$HEAD_SHA" \
  'select(.decision=="APPROVE" and (.commit // $head)==$head)' "$ROOT/.claude/signals/review-latest.json" >/dev/null \
&& echo "SHIP GATE: pass" || echo "SHIP GATE: blocked (stale/missing/blocking signal)"
```

## Persisting a `/harness-audit` result — the ONLY sanctioned recipe

The workflow RETURNS a `review-latest.json`-shaped object (accountable-writer, contract rule above);
no relay agent may write it. The accountable invoking human reviews the returned object,
then persists it with ONE command that stamps `timestamp` + `commit` (without the commit
stamp the persisted signal is stale-by-definition under the freshness predicate) and tags
provenance:

```bash
ROOT=$(source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && harness_root)   # rule 5b
python3 -c '
import json, subprocess, sys, datetime
sig = json.load(open(sys.argv[1]))          # the returned object, saved to a file
root = sys.argv[2]
sig.pop("_persistence", None)
sig["timestamp"] = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
sig["commit"] = subprocess.check_output(["git", "-C", root, "rev-parse", "HEAD"], text=True).strip()
sig["reason"] = ("source:harness-audit " + sig.get("reason", ""))[:120]
open(root + "/.claude/signals/review-latest.json", "w").write(json.dumps(sig))
open(root + "/.claude/metrics/reviews.jsonl", "a").write(json.dumps(sig) + "\n")
' /path/to/returned-signal.json "$ROOT"
```

## Versioning policy

- Adding an optional field ⇒ same `schema_version` (consumers ignore unknown fields).
- Adding a new enum value ⇒ same `schema_version` (append-only; consumers default-deny unknowns).
- Removing/renaming a field or repurposing an enum ⇒ **breaking**: bump `schema_version`
  and update this file + both producers + every consumer in the same change.

Anchor: [docs/TEAM-DISCUSSION-2026-06-06.md](TEAM-DISCUSSION-2026-06-06.md).
