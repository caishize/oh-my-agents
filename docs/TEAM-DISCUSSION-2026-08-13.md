# Team Discussion — 2026-08-13 · Harness-Fusion Council v2

**Topic:** With Claude Code's native harness evolving fast (Dynamic Workflows prominent,
Agent Teams + Routines shipped), (a) retire plugin surface made unnecessary by native
features; (b) fold in the Anthropic Labs Planner/Generator/Evaluator self-correcting loop
where it improves the pipeline; (c) tighten oh-my-agents ↔ gstack ↔ native-harness fusion:
automation BETWEEN stages + clean artifact handoff; (d) all in service of delivery
quality/efficiency; (e) never at the cost of bloat.

**Mechanism:** read-only expert council v2 (ephemeral — rule `single-workflow` keeps the
one shipped workflow at `harness-audit.js`). Four research digests (repo audit · native
capabilities · gstack 1.62 state · external patterns) fed four proposal lenses; four
adversarial critics (anti-bloat · gstack-overlap · native-redundancy · delivery-impact)
issued per-proposal verdicts; the accountable synthesizer applied the kill rule
(≥2 kill verdicts dies) and folded every `modify` into its canonical survivor.
30 proposals → **15 canonical work items** (13 duplicates + 2 weak variants killed).

## Grounding facts that changed the calculus (verified 2026-08-13)

1. **gstack is v1.62.0.0** (raw VERSION fetch), not our pinned 1.58.4.0. GitHub Releases
   page is EMPTY — VERSION/CHANGELOG raw-fetch is the only drift channel. v1.61 made
   cross-model review **default-on** (`codex_reviews`); v1.57.9 `gen-skill-docs` now
   **writes inside OUR `.claude/` namespace** (`.claude/gstack-rendered/`, untracked) —
   the first upstream crossing into our namespace. `decisions.active.json` and `llms.txt`
   could NOT be verified on the current surface (absence itself unverified — WebFetch-summarized).
2. **No evidence gstack reads our signals.** The `/ship`-gates-on-`verify-latest.json`
   claim asserted in four of our docs is an our-side convention, confirmed by nobody.
   gstack v1.62 grew its own "host-anchored plan signals" — the nearest future convergence
   point (unverified, changelog-summarized).
3. **Anthropic primary source (harness-design post) details beyond our June snapshot:**
   evaluator rubric = hard per-criterion thresholds, failing ANY criterion fails the sprint
   (no averaging); sprint contracts = machine-checkable done-criteria negotiated BEFORE
   implementation ("vague criteria produce vague critiques that agents disregard");
   **evaluator blindness** = fresh context, artifact + fixed rubric only, never the
   generator's trace; filesystem JSON state beats context-embedded state. And the
   **Opus 4.6 lesson**: Anthropic DELETED their own context-reset machinery when the
   platform obsoleted it — "regularly reassess and delete machinery" validates our
   thinner-or-neutral invariant.
4. **Repo audit found the June release's automation artifact never got its executor:**
   `lifecycle-next.json` has ZERO consumers after a full cycle. Four sensor chains are
   dead (dashboard reads `legibility-*.json`/`entropy-*.json` that no skill writes;
   `confusion.jsonl` has consumers but no producer; the investigate→encode rate is
   circular — `investigations.jsonl` is written only by `encode-mistake` itself; the
   TASTE ratchet has fired zero times — `LINTING.md` index empty). The exec-plan template
   (verified: 12 top-level properties) defines NONE of the 8 top-level fields
   `spec-to-task` Step 5 mandates — the typed Planner→Generator handoff contradicts its
   own schema. `harness-review:275` still carries a legacy dual verdict vocabulary.
   Measured doc drift: 6-vs-7 hook tables in three docs, floor v1.26-vs-1.46
   contradiction, a "rule 13" mis-cite.
5. **Native capabilities are complementary, not commoditizing:** no native equivalent to
   the Gate API or the mechanical hooks. But Dynamic Workflows capture *invocation output*
   — a cached routing file is the wrong native shape. Native post-edit diagnostics
   plausibly commoditize `self-verify-check.sh` (evidence needed).

## Headline decision — push, don't poll; bind signals to commits; stop asserting untested contracts

Automation between stages ships as **push nudges inside the two existing advisory hooks**
(plan-complete → `/verify`; Stop-time gate-state → `/harness-review` / gstack `/ship`),
made safe by a **commit-freshness binding** on both decision signals — while the release
**deletes** the cached-routing artifact that waited a full cycle for an executor
(`--emit-next`/`lifecycle-next.json` → a machine-parseable `NEXT:` tail line on router
output, the shape native Workflows actually consume). The Evaluator gets the two
Anthropic patterns worth their bytes: **sprint-contract enforcement** (unconfirmed
acceptance caps `/verify` at YELLOW, fail-any, no averaging) and **evaluator blindness**
(judge the artifact, never the generator's trace). And the plugin stops stating an
untested gstack contract as fact: the `/ship` gate is **relabeled a convention and
probed** (VERIFIED | ASSERTED — a grep miss is never "gstack ignores signals").

> Bright lines intact: every nudge NAMES the next skill, never invokes it
> (no-orchestration). All gstack paths stay read-only. The workflow still only RETURNS
> its signal. The human TASTE gate is untouched.

## Changes (→ v3.9.0)

| # | P | Change | Files |
|---|---|--------|-------|
| 1 | P0 | Close Planner schema drift: template is the SSOT; every added field names a consumer; consumerless Step-5 fields dropped; `acceptance` = runnable command, never prose | templates/execution-plan.json, spec-to-task, plan-validation-check.sh |
| 2 | P0 | Signal freshness: optional `commit` field + normative staleness predicate (stale ⇒ default-deny for machines); mid-run death ⇒ no signal ⇒ safe halt, stated once | SIGNALS.md, verify, harness-review, lifecycle, harness-audit.js |
| 3 | P0 | Retire `--emit-next` + `lifecycle-next.json` (zero consumers); replace with `NEXT:` JSON tail line on `/lifecycle next` output; session-observer gets binding Q4 consume-or-cut | lifecycle, SIGNALS.md, session-observer-agent.md, README, integration.json |
| 4 | P0 | Stage-transition push nudges in the two existing advisory hooks (plan-done→/verify with GREEN-freshness suppression; Stop-time gate-state, freshness-checked, SIGNALS.md-sourced mapping) | plan-validation-check.sh, doc-drift-check.sh, tests, SIGNALS.md |
| 5 | P0 | Dead-sensor cull: real Bash-append writers for legibility/entropy (verify pattern: `-latest.json` + `.jsonl`); confusion.jsonl demoted reserved/inactive + upstream probe; circular investigate→encode rate deleted, honest LINTING-registry count instead | legibility-score, entropy-sweep, harness-dashboard, gstack-sync, lifecycle, INTEGRATION.md, integration.json |
| 6 | P0 | gstack contract resync 1.58.4.0→1.62.0.0: `.claude/gstack-rendered/` registered as gstack-owned enclave; llms.txt goes glob + ordered oracle succession (local first, network last); LOUD degrades (`verdict-unparsed`, `unresolved-count-unavailable`), never silent `na`; codex-default recalibration gated on local probe | integration.json, gstack-sync, harness-review, harness-init, entropy-sweep, doc-drift-check.sh, INTEGRATION.md |
| 7 | P1 | Honest ship gate: relabel 4 doc overclaims as our-side convention FIRST; then read-only probe (wide glob incl. carved/rendered layouts) reporting VERIFIED \| ASSERTED | gstack-sync, README, WORKFLOW.md, INTEGRATION.md, SIGNALS.md, verify |
| 8 | P1 | Sprint-contract verify: auto-detect single active plan; unconfirmed acceptance caps decision at YELLOW (fail-any, no averaging) | verify, SIGNALS.md |
| 9 | P1 | Evaluator blindness in harness-review (artifact + fixed rubric only; fresh-context read-only subagent when same-session); legacy `Verdict (legacy)` deleted; no-averaging fence in SIGNALS.md | harness-review, SIGNALS.md |
| 10 | P1 | Dedupe: `gstack_detect()` in existing hooks/lib/common.sh via `${CLAUDE_PLUGIN_ROOT}` (glob-based, no exact paths baked in); 6-7 skill snippets collapse; verify's schema table → pointer | hooks/lib/common.sh, 7 SKILL.md, tests/test-skills.sh |
| 11 | P1 | De-circularize encode loop: /lifecycle improve scans gbrain/decisions.jsonl durable artifacts (glob, schema-tolerant, loud degrade); investigations.jsonl relabeled provenance ledger | lifecycle, encode-mistake, INTEGRATION.md, LINTING.md |
| 12 | P1 | Doc single-sourcing: hooks.json canonical hook list; floor contradiction fixed; anti-bloat rules cited by kebab-case NAME (renumber-proof); WORKFLOW.md thinned ~100 lines | README, WORKFLOW.md, INTEGRATION.md, lifecycle |
| 13 | P2 | Cut `recovery_edges` (zero consumers; runtime retry routing belongs to native executors); consume-or-cut audit of `parallelizable_groups`/`context_budget` recorded per field | templates/execution-plan.json, spec-to-task, ARCHITECTURE.md |
| 14 | P2 | Audit-persist recipe (docs-only): exact one-liner stamping timestamp+commit through the accountable invoker; mid-run-death semantics stated normatively | SIGNALS.md, harness-audit.js |
| 15 | P2 | Passive self-verify overlap measurement (NO flag, NO hooks.json change): tag warnings into session metrics; v4.0 deletes on evidence | self-verify-check.sh, tests |

## Net accounting (thinner-or-neutral invariant HOLDS)

Skills 11→11 · hooks 7→7 · agents 1→1 · workflows 1→1. **Removed:** 1 artifact
(`lifecycle-next.json`) · 1 flag (`--emit-next`) · 1 schema field (`recovery_edges`, plus
any consumerless siblings) · 1 legacy verdict vocabulary · 1 circular metric · 1 active
bridge (confusion.jsonl → reserved/inactive) · 2 phantom dashboard reads · ~60-80 lines of
duplicated bash/tables · ~120 doc lines. **Added:** ~100 lines, all inside existing files
(2 hook nudge blocks, 2 accountable metric writers, 1 optional signal field, 2 read-only
probes, 1 tail-line spec, blindness + sprint-contract blocks). All SKILL.md stay ≤400L
(harness-review lands ~350 after its offsets). `self-verify-check.sh` deletion is queued
as v4.0's offset budget. Decision-log growth (this file) is System-of-Record growth, not bloat.

## Verified-already-done (NOT re-implemented)

- `hooks/lib/common.sh` already contains GSTACK_PATH detection logic — item 10 extends it
  rather than creating `lib/common.sh` (the path architect:schema-ssot misnamed).
- Task-level exec-plan fields (`context_files`/`failing_tests`/string-`acceptance`) were
  reconciled in v3.8.1; only the TOP-LEVEL drift remains (verified against the template).
- `/lifecycle` is already a pure router; `plan-validation-check.sh` already parses the
  full plan JSON at the right event — the completion nudge is ~15 lines, not a new sensor.
- `harness-audit.js` already runs blind by construction (fresh fan-out Explore agents).
- Bash is already in legibility-score/entropy-sweep allowed-tools — metric writers need
  NO allowed-tools widening.

## Do-NOT-do (critics killed these)

13 duplicate filings (one canonical per idea — one edit per file) · `--from-audit`
flag on harness-review (quarterly event doesn't earn permanent skill surface; relay-shaped)
· harness.json trial flag for self-verify (add-then-remove double-touch; no new config
knobs) · hard-deleting the confusion.jsonl bridge (upstream Confusion Protocol fate
unverified; demote + probe instead) · shadow-computing GSTACK_UNRESOLVED from
decisions.jsonl event replay (read-only in bytes but not semantics; loud degrade beats a
wrong number feeding judgment-slop reconciliation) · renaming doc-drift-check.sh (churn;
header comment instead) · building any lifecycle-next.json consumer (artifact deleted)
· weighted-score "improvement" of fail-any semantics (fenced in SIGNALS.md) · invoking
gstack CLIs beyond `gbrain doctor` without a recorded policy decision · reporting a
ship-gate grep miss as "gstack ignores signals" · retiring session-observer now (binding
Q4 consume-or-cut instead) · new skills/hooks/workflows/agents of any kind.

## Open questions (unverified externals → graceful degradation, never hard dependency)

1. **Native post-edit diagnostics coverage** vs self-verify-check — passive evidence
   collected this cycle; v4.0 deletes on evidence (the next release's offset budget).
2. **`decisions.active.json` upstream status** — absence is unverified-by-summarization;
   dual-read (existing probe + loud degrade) until checked against an installed gstack.
3. **`decisions.jsonl` event schema** — unverified; no computed unresolved-count fallback
   until verified locally.
4. **Policy call:** may skills invoke read-only gstack CLIs (`gstack-decision-log/search`,
   `gstack-first-task-detect`)? Today only `gbrain doctor` is sanctioned. If broadened,
   record in integration.json policies.
5. **Confusion Protocol upstream fate** — contract-check probe added; bridge hard-deleted
   at next quarterly check only if probe confirms sunset.
6. **`codex_reviews` default-on (v1.61)** — confirm via local VERSION/config probe before
   inverting the composition-skipped anomaly framing.
7. **`llms.txt` at install layout** — if the glob finds none anywhere, the ordered
   successor oracle stands (local VERSION → skill index → raw CHANGELOG).
8. **session-observer-agent** — BINDING: one mechanical trigger + one machine reader by
   the 2026-Q4 council, or retire (its context-reset rationale is weakening per the
   Opus 4.6 simplification).
9. **session-metrics.sh vs native OTel** — benchmark field overlap by Q4 (dashboard is a
   live consumer; keep until measured).
10. **gstack v1.62 host-anchored plan signals** — watch item (unverified) as the future
    bilateral gate contract `/ship` could someday natively honor.
