# Team Discussion — 2026-09-04 · Harness-Fusion Council v3 (→ v3.10.0)

**Topic:** Claude Code's native harness keeps moving (Dynamic Workflows GA, Agent Teams,
33 hook events, native `/code-review`), gstack moved v1.62 → v1.79 in three weeks, and the
Anthropic Labs Planner/Generator/Evaluator loop has a documented "delete what the model
obsoleted" lesson. (a) Retire plugin surface the platform or gstack now covers; (b) fold in
the self-correcting loop where it improves the pipeline; (c) tighten oh-my-agents ↔ gstack
↔ native fusion — automation BETWEEN stages, typed handoff of deliverables; (d) all in
service of delivery quality + lead time; (e) never at the cost of bloat.

**Mechanism:** read-only expert council v3 (ephemeral Dynamic Workflow — rule
`single-workflow` keeps the one shipped workflow at `harness-audit.js`). Four research
digests fed it — native Claude Code capabilities (claude-code-guide), **gstack v1.79
verified against a source clone** (not changelog summaries), harness-engineering patterns
2026 (Anthropic, OpenAI, ETH Zurich, DORA/Faros/DX), and a file-anchored fact sheet of this
repo. Four expert lenses (Claude Code skill/plugin · harness engineering · R&D efficiency ·
systems architect) PROPOSED (32) → the same lenses DEBATED every proposal openly (8 more
born in debate) → four adversarial critics (anti-bloat · gstack-overlap · native-redundancy
· delivery-impact) issued per-proposal verdicts → kill rule (≥2 kills dies: 34 survived, 6
killed) → the synthesizer folded survivors into **16 canonical work items** → a
completeness critic named 10 gaps and 5 contradictions, all folded in below.

## Grounding facts that changed the calculus (verified 2026-09-04)

1. **gstack is v1.79.0.0 (2026-09-01)**, not our recorded 1.62. Verified in source, not
   summaries: `/ship` reads NOTHING under `.claude/signals` (the pre-ship gate is
   our-side convention — now VERIFIED as such, not ASSERTED); `.gstack/landing-reports/`
   never existed; deploy/canary reports are `.md`, not `.json`; `~/.gstack-artifacts-worktree`
   has zero hits (current: `~/.gstack-brain-worktree`) — **our v3.6.0 legacy sunset dropped
   the wrong side, so every gbrain bridge was dead**; learnings are ONE file
   (`projects/<slug>/learnings.jsonl`), never `*-learnings-*.jsonl`; `decisions.active.json`
   is a bare JSON array and a rebuildable cache (our `.get('unresolved')` parse raised on
   every read); `/find-decisions` never existed; `skill-usage.jsonl` is telemetry-gated
   (default OFF) while `projects/<slug>/timeline.jsonl` is always written; review records
   are content-addressed (`wtree`); `GSTACK_SESSION_KIND=spawned` marks dispatched
   subagents; `bin/gstack-verify-gate` (v1.65) is an opt-in Stop hook reading
   `<!-- gstack:verify: cmd -->` from the PROJECT's CLAUDE.md — the first bilateral surface.
2. **Project identity was malformed on every install.** `bin/gstack-slug` prints TWO lines
   (`SLUG=…`, `BRANCH=…`); `common.sh` captured both as the slug. `.claude/integration.json`
   baked 14 `projects/oh-my-agents` literals with zero `{SLUG}` placeholders. `$GSTACK_HOME`
   was never honored. Every gstack read on a real install pointed at an unreachable directory.
3. **The flagship push nudges reached nobody.** `plan-validation-check.sh` closed its
   guidance with `} >&2` at exit 0; per the hook contract, stderr reaches the model ONLY on
   exit 2 and stdout at exit 0 is parsed as JSON. No hook emitted `additionalContext`.
4. **The 2026-Q4 consume-or-cut on `session-observer-agent` was unmet on both conditions**
   (zero mechanical triggers, zero readers). The `handoff-<branch>.json` writer had zero
   consumers, a false consumer claim in its own comment, and built JSON with the unquoted
   heredoc the Gate API forbids.
5. **The constitution was unenforced in both halves**: `tests/test-skills.sh` asserted
   `≤ 900` lines (2.25× the 400 cap); root CLAUDE.md was 69 lines against its own "≤ ~60",
   which had no canonical rule entry and had drifted to "under 100" in two skills.
6. **Native**: Dynamic Workflows GA (no mid-run input ⇒ machine-readable stage boundaries
   are mandatory infrastructure — our Gate API); hook JSON output (`additionalContext`,
   `systemMessage`) is the channel that reaches the model; `SessionStart` exists; built-in
   `Explore` is the read-only fresh-context judge; `/code-review`'s alias `/review` collides
   with gstack's; plugin-level `workflows` distribution is UNVERIFIED.
7. **Patterns**: Anthropic deleted context resets and the sprint construct once Opus 4.6
   obsoleted them ("every component in a harness encodes an assumption about what the model
   can't do … those assumptions go stale"); the Apr-23 postmortem shows prose knobs regress
   silently while hooks do not; ETH Zurich 2602.11988 (LLM-generated context files −3%
   success, +20% cost) is the strongest evidence for `human-gated-encoding` and the ≤60
   CLAUDE.md; DORA 2026: "shift AI feedback to the author phase"; `/checkup` turns off slow
   hooks — a disabled PostToolUse chain takes the blocking gates down with it.

## Headline decision — fix identity first, make nudges reach the model, then execute the Q4 cut

Repair the slug/`GSTACK_HOME`/`{SLUG}` identity under every gstack read so the five bridge
repairs land on a directory that exists. Route every advisory hook through ONE capped
`emit_advisory` helper (JSON `additionalContext` for the model on PreToolUse/PostToolUse/
SessionStart, `systemMessage` load-bearing at Stop; zero bytes when clean; silent inside
gstack-spawned subagents) — and bind the existing `doc-drift-check.sh` to **SessionStart**
so gate state + active plan are in the model's context at session open, which is the whole
job the retired observer agent was supposed to do. Give the history logs one tested writer,
give review findings a typed shape so `REQUEST_CHANGES` returns a work list, add a
termination sensor (3 RED, same reason ⇒ `/investigate`, not another `/verify`), and close
the dirty-tree hole at the three ADVANCE points. Execute the binding Q4 cut unconditionally
(agent, handoff writer, `--metrics`, heavy self-verify) and make the constitution
mechanical (400 / 60 / kebab-case citations / declared artifacts / latency budget / dead-shape
greps in CI). Bright lines intact: hooks nudge and never invoke; all gstack paths stay
read-only; the gstack verify marker is a DERIVED EXPORT of our own CLAUDE.md, never an
imported source of truth; the human TASTE gate is untouched.

## Changes (→ v3.10.0)

| # | P | Change | Files |
|---|---|--------|-------|
| 1 | P0 | Identity: parse gstack-slug's `SLUG=` line (never raw stdout/eval); `GSTACK_PROJECT_SLUG` → slug-cache → `owner-repo` from origin → basename; `gstack_home()` honors `$GSTACK_HOME`; `{SLUG}`-templated bridges (14 literals removed); fixture test | common.sh, integration.json, test-skills |
| 2 | P0 | Q4 consume-or-cut EXECUTED: `agents/session-observer-agent.md` deleted (agents 1→0); `handoff-<branch>.json` writer deleted (zero consumers, forbidden heredoc); reference sweep | agents/, doc-drift-check.sh, README, CLAUDE.md, ARCHITECTURE, plugin.json, harness.json |
| 3 | P0 | `emit_advisory <event> <text>` in common.sh — static per-event key table, ≤400 chars, success-silence, `GSTACK_SESSION_KIND=spawned` suppression, python3/jq escaping with bare-text fallback, no `continue`, never `permissionDecision`; plan-validation / self-verify / doc-drift converted; first mechanical success-silence test | common.sh, 3 hooks, test-hooks |
| 4 | P0 | `append_history_record <dir> <file> <json>` — validated, flocked, LOUD; `/verify` + `/harness-review` call it (prose writers replaced) | common.sh, verify, harness-review, test-skills |
| 5 | P0 | `doc-drift-check.sh` bound to SessionStart (3000 ms; gate state + active plan, returns before any repo walk — after root resolution, per the completeness critic); Stop-only termination sensor: 3 consecutive RED with identical `reason` ⇒ escalation (same-HEAD rejected as wrong in both directions) | hooks.json, doc-drift-check.sh, test-hooks |
| 6 | P0 | harness-review: typed `findings[]` in the reviews.jsonl history line (four-pillar `dimension`, never gstack's enum); `decisions.active.json` count DELETED (cache semantics) — `decisions_unresolved` kept documented as DEPRECATED-optional so `schema_version` stays 1 under `append-only`; Review 6 delegated to gstack `/review`/`/cso` + native `/code-review` (never `/review`); gstack verdict currency by `wtree`; blind judge = built-in `Explore` subagent, never shown the generator's self-assessment; persist recipe fixed (`signal` → signal file, `signal+findings` → history) | harness-review, SIGNALS.md, lifecycle |
| 7 | P1 | Dirty-tree clause at the three ADVANCE points via `worktree_dirty` (our `.claude/`/`.gstack/` never count); Stop-hook APPROVE branch WARNs on dirt; `.claude/gstack-rendered/` finally gitignored (claimed in three docs, false on disk) | common.sh, SIGNALS.md, lifecycle, doc-drift-check.sh, .gitignore, test-hooks |
| 8 | P1 | `gbrain_detect()` folded into `gstack_detect()` — `~/.gstack-brain-worktree` (env), ONE `*learnings*.jsonl` glob, `GSTACK_TIMELINE`; four divergent inline probes deleted (encode-mistake, gstack-sync, harness-dashboard, lifecycle) | common.sh, 4 skills, integration.json, docs |
| 9 | P1 | Dashboard re-grounded: `.md` report globs rooted at `$ROOT`; landing-reports row deleted; usage from always-on `timeline.jsonl`; lead_time/MTTR rows deleted (structural zeros); velocity block extended with re-verify count + gate-block rate (LOUD `hook_results present in N of M`); `n=` + "insufficient data" panel rule; DEEP-DIVE `velocity` section; TASTE count kept honest | harness-dashboard, DEEP-DIVE.md, gstack-sync, integration.json |
| 10 | P1 | Heavy self-verify path deleted (unreachable knob, untested, 15 s timeout); `self_verify_heavy` RETIRED (harness-init reports it); rule `hook-latency-budget` with CI assertion (PreToolUse 10 s · PostToolUse 5 s · Stop 8 s · SessionStart 3 s — ceilings consistent with existing timeouts, per the completeness critic); self-verify 15000→5000, doc-drift 15000→8000 | self-verify-check.sh, hooks.json, INTEGRATION.md, harness-init, test-hooks |
| 11 | P1 | Status-enum GUIDE at authoring time (template enum is the SSOT for spelling; "did you mean 'in-progress'?"); reader stays tolerant of `in_progress` until v3.11 (`transient-dual-value`) | plan-validation-check.sh, verify, test-hooks |
| 12 | P1 | CI: rule `declared-artifact` (every written `.claude/metrics|signals` basename must name a reader) + anti-regression greps for every dead gstack shape, over skills/, hooks/, integration.json AND the INTEGRATION.md bridge table | test-skills |
| 13 | P1 | `/gstack-sync --metrics` + `integrated-report.json` deleted (one producer, zero consumers, triple-dead inputs); description no longer claims "sync bidirectionally"; weekly chain shortened; `/loop` named as the scheduler in WORKFLOW.md | gstack-sync, CLAUDE.md, WORKFLOW, README, INTEGRATION |
| 14 | P1 | `CONTRACT-CHECK OVERDUE` nudge on every `--status` (current quarter from the clock; the recorded quarter is trigger AND receipt; human-bumped, never auto-written); `--setup` copies the plugin's `{SLUG}`-templated manifest into projects that lack one (installers never got integration.json) | gstack-sync, integration.json |
| 15 | P1 | gstack verify-gate marker as a DERIVED EXPORT: `/harness-init` Step 8 emits `<!-- gstack:verify: <confirmed cmd> -->` only behind a capability probe + human confirmation + a test command proven to run; `/verify` reads the commands table as primary and the marker as a named fallback | harness-init, verify, INTEGRATION.md, test-skills |
| 16 | P2 | Constitution in CI: 900→400 SKILL.md cap; root CLAUDE.md ≤ 60 (rewritten 69→59); kebab-case citation assertion (six `rule17` labels + the workflow's user-visible "Rule-17" fixed); `node --check` on the workflow; `next-contract-documented` (documented ≠ emitted) + a BINDING consume-or-cut on the `NEXT:` line for the Q4 council; `skill-line-cap` gains its root-CLAUDE.md clause; legibility-score/harness-init repointed from 100 to 60 | test-skills, INTEGRATION.md, CLAUDE.md, legibility-score, harness-init, lifecycle, harness-audit.js |

Gap fixes folded in from the completeness critic: `$GSTACK_HOME` honored everywhere (not
just the slug cache); gstack verdict currency by `wtree`; dead remediation anchors in the
two BLOCKING hooks (`#dependency-layers`, `#secrets-management`) replaced with live
references; gstack version, `last_verified` and milestone pin recorded at v1.79 with the
verification method; INTEGRATION.md's landing-reports row and the surviving `/ship reads
verify-latest` / "gates auto-advance" / "logs to gstack's review system" overclaims removed
and CI-grepped; `GSTACK_SESSION_KIND=spawned` suppression inside `emit_advisory`; evaluator
blindness stated on the primitive that exists (`Explore`), not an inline `disallowedTools`
argument.

## Net accounting (thinner-or-neutral invariant HOLDS)

Skills 11→11 · hooks 7→7 scripts (one bound to a second event) · **agents 1→0** ·
workflows 1→1. **Removed:** 1 agent (171 lines) · 2 dead artifacts (`handoff-<branch>.json`,
`integrated-report.json`) · 1 flag (`--metrics`) · 1 config knob (`self_verify_heavy`) · 1
signal field produced (`decisions_unresolved`, kept as deprecated-optional) · 1 dead bridge
row (`landing_reports_local`) · 4 duplicated gbrain probes · 1 always-failing parse · 1
generic review checklist · 14 baked slug literals · ~10 s of PostToolUse timeout · 10
lines of root CLAUDE.md. **Added:** 5 common.sh helpers (`gstack_home`, `gbrain_detect`,
`worktree_dirty`, `emit_advisory`, `append_history_record`) · 1 hook EVENT registration ·
1 optional history-log field (`findings[]`; `schema_version` stays 1) · 2 bridge rows
(`gstack_timeline`, `gstack_verify_marker`) · 3 named rules (`hook-latency-budget`,
`declared-artifact`, `ablate-per-model`) · 1 derived export line · ~60 new test assertions.
All SKILL.md ≤ 400 (max harness-review 382); CLAUDE.md 59.

## Do-NOT-do (critics killed these — do not re-file)

`commands` object in harness.json as the build/test SSOT (new config surface; the marker is
an export, CLAUDE.md prose stays primary) · `emit_signal` + evidence-before-write in common.sh
(the flag is passed by the same model that derived the verdict — theatre; item 4 closes the
real defect) · `/entropy-sweep` zero-fire self-audit (built on an untested sensor that cannot
see advisory hooks) · a `dirty` boolean stamped at derivation time (stale on the next
keystroke; consumer-side `git status` is strictly better) · `context: fork` + `agent: Explore`
on `/harness-dashboard` (token spend is not a performance metric; Explore's Bash access is
unverified) · repairing `decisions.active.json` to `len(array)` (rebuildable cache ⇒
plausible wrong 0) · copying `harness-audit.js` into every project (an un-upgradeable fork of
the one governed workflow) · adding the plugin.json `workflows` field (UNVERIFIED) · prose
rule lines restating a check a test already enforces · a p95 latency dashboard row
(`hook_durations` is a one-hit dead sensor) · a fixture harness pinning gstack's internal
file shapes (chased daily) · `additionalContext` as the load-bearing Stop channel
(UNVERIFIED; `systemMessage` is) · `"continue":true` from an advisory hook · narrowing the
plan reader to the hyphen spelling this release (silent-miss class) · justifying the
self-verify deletion on LSP coverage (LSP is per-project) · new skills/hooks/workflows/agents.

## Open questions (unverified externals → probe / graceful degrade, never hard dependency)

1. Does a Stop hook honor `hookSpecificOutput.additionalContext`? `systemMessage` is
   load-bearing at Stop; a sibling rides along. Probe by observation; one-line table change.
2. plugin.json `workflows` field — probe with `claude plugin validate --strict`; until then
   `/harness-audit` is project-local and the docs say so.
3. `/skill-doctor` availability (org-gated) — the evidence source for retiring skills; never
   a dependency, never a parallel counter of our own.
4. Does built-in `Explore` permit read-only Bash? Nothing shipped depends on it; probe before
   any skill forks to it (every dashboard probe is a Bash pipeline).
5. Does the host populate `hook_results` on PostToolUse (repo gap 10, untested)? The
   gate-block rate prints `present in N of M` and hides at 0 until a test closes the gap.
6. gstack verify-gate marker rename — a rename costs one export line; the quarterly nudge
   surfaces it.
7. Read-only gstack CLI policy (2026-08-13 Q4, premise drifted): sanctioned today =
   `gbrain doctor`, `gbrain search`, `bin/gstack-slug`, `bin/gstack-wtree` (recorded in
   integration.json). Broaden only by recording first.
8. slug-cache key encoding — placed THIRD in precedence; a miss costs nothing.
9. session-metrics.sh vs native OTel (2026-08-13 Q9, still unmeasured) — carried forward as a
   binding for the Q4 council with a named evidence source.
10. **BINDING for the 2026-Q4 council:** the `NEXT:` tail line must have ≥1 live consumer
    (a Dynamic Workflow `agent(…,{schema})` capture or an Agent Team lead parsing it) or it
    is retired — the profile that retired `lifecycle-next.json` and `session-observer`.
