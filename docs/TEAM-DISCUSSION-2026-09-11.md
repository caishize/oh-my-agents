# Team Discussion — 2026-09-11 · Harness-Fusion Council v4 (→ v3.11.0)

**Topic:** One week after v3.10.0 the ground moved again: gstack v1.79 → **v1.84.1** (five
releases in nine days), Claude Code's plugin/hook/workflow surface re-read from the RAW docs
(not summaries), the Anthropic Labs harness-design post read in the original, and the
2026-09-04 council's BINDING items due. The owner's ask: (a) retire what the platform
obsoleted — Dynamic Workflows first; (b) fold in the Planner/Generator/Evaluator
self-correcting loop where it improves the pipeline; (c) make oh-my-agents ↔ gstack ↔ native
Claude Code interlock — automation BETWEEN stages, typed hand-off of deliverables; (d) all
for delivery quality + lead time, AI-automated development; (e) never at the cost of bloat.

**Mechanism:** read-only expert council v4 (ephemeral Dynamic Workflow, 15 agents — rule
`single-workflow` keeps the one shipped workflow at `workflows/harness-audit.js`). Five
evidence digests fed it: native Claude Code (claude-code-guide agent) **plus a lead re-check
against the raw hooks/plugins/skills references** (two of the agent's "verified" claims were
wrong and two P0 defects surfaced), harness-engineering 2026 (the Anthropic Labs original
post, OpenAI + follow-ups, ETH/DORA/METR/LLM-judge evidence, competing plugins), **gstack
v1.84.1 verified against a source clone**, and a file-anchored fact sheet of this repo.
Four expert lenses (Claude Code skill/plugin · harness engineering · R&D efficiency ·
systems architect) PROPOSED (43) → every lens DEBATED every proposal (172 positions, 16
proposals born in debate) → four adversarial critics (anti-bloat · gstack-overlap ·
native-redundancy · delivery-impact) voted per proposal → kill rule (≥2 kills dies; the
critics also merged duplicates into one canonical item per cluster) → synthesizer → a
completeness critic verified ~90 citations on disk (7 false ones dropped, 12 gaps, 6
contradictions) → final fold into **20 work items**, all implemented below.

## Grounding facts that changed the calculus (verified 2026-09-11)

1. **Hook `timeout` is in SECONDS.** hooks reference: "`timeout` — Seconds before canceling …
   Defaults: 600 for `command`". Our `hooks.json` wrote `10000`/`5000`/`8000`/`3000`/`2000`
   — 10 000 s (2.8 h) for arch-check. Rule `hook-latency-budget`, its `_ms` keys and the CI
   assertion measured the wrong unit; the platform enforced no useful ceiling on any hook.
   (The Bash TOOL's `timeout` is in ms — the source of the confusion.) Same-event hooks run
   in PARALLEL (latency = max, not sum); a PreToolUse command hook that reaches its timeout
   lets the tool call CONTINUE — the blocking gates fail OPEN at their ceiling.
2. **At `Stop`, `hookSpecificOutput.additionalContext` CONTINUES the conversation** ("the
   conversation continues so Claude can act on it … the same loop protections as
   `decision:"block"` … the 8-consecutive-continuation cap"). `emit_advisory` computed a
   per-event `with_context` flag and never used it — every Stop nudge ("APPROVE — next:
   /ship", ledger WARN, doc-drift WARN) forced another model turn, and `doc-drift-check.sh`
   never read `stop_hook_active`, so a persistent gate state re-fired up to the 8-cap. A hook
   that NAMES the next skill (rule `no-orchestration`) was, by channel semantics, invoking
   another turn. The 2026-09-04 council's "an additionalContext sibling rides along" was half
   right: it rides along and changes control flow.
3. **`PreToolUse` DOES honor `additionalContext`** (the agent digest omitted it) — the plan
   GUIDE's channel is valid. **`SessionStart` fires on startup / resume / clear / compact /
   fork**, so the gate state survives compaction with no new binding.
4. **Plugins distribute workflows from the plugin ROOT** (`workflows/`, or the `workflows`
   manifest field, which only REPLACES the default); "all other directories … must be at the
   plugin root"; a plugin's `.claude/` is not scanned. `.claude/workflows/harness-audit.js`
   therefore reached nobody who installed the plugin. `claude plugin validate --strict`
   (v2.1.269) accepts a root `workflows/` — the 2026-09-04 watch item is closed, no field needed.
5. **Explore has NO Bash** (Read/Grep/Glob/WebFetch/WebSearch). `/skill-doctor` is documented
   (per-skill token cost, invocation frequency, unused skills; ≥ v2.1.252, not org-gated).
   `claude plugin eval` is GA (`evals/<case>/prompt.md` + graders, with/without-plugin
   ablation). The skill listing truncates `description` + `when_to_use` at 1,536 chars;
   `disable-model-invocation: true` removes a skill's description from context entirely.
   `hook_results` appears nowhere in the 3,802-line hooks reference — our sensor parsed a
   field the platform never sends.
6. **gstack v1.84.1.0** (2026-09-09): `/ship` still reads nothing under `.claude/signals`
   (zero hits outside `test/`); `bin/gstack-evidence` is gstack's verification-evidence
   ledger (`run` wraps a command, `check --max-age 24` gates `/ship`; freshness bound to
   `wtree`, the content fingerprint — NOT the commit); `/spec` ALWAYS archives the sanitized
   spec to `projects/<slug>/specs/<ts>-<pid>-<title>.md` with `spec_issue_number` /
   `spec_issue_url` / `spec_branch` frontmatter and `/ship` selects it by `spec_branch` for
   `Closes #N` (our top-level `*-spec-*.md` glob never had a producer); gstack registers a
   default-on Stop hook (`timeline-stop`, 2 s self-bound) and an opt-in Stop verify-gate that
   RUNS the test command (`MAX_REENTRY_BLOCKS=3`, reads `stop_hook_active`); every skill ends
   with a Completion Status Protocol (`DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT`);
   design review runs 61 deterministic checks BEFORE the LLM pass; `/connect-chrome` survives
   as a backwards-compat alias of `/open-gstack-browser` (a digest said "no longer exists" —
   the clone said otherwise: grep the source before filing).
7. **Anthropic Labs, "Harness design for long-running application development"** (Prithvi
   Rajasekaran, 2026-03-24): "Separating the agent doing the work from the agent judging it
   proves to be a strong lever"; "Tuning a standalone evaluator to be skeptical turns out to
   be far more tractable than making a generator critical of its own work"; "Every component
   in a harness encodes an assumption about what the model can't do on its own … those
   assumptions … can quickly go stale as models improve"; v2 on Opus 4.6 DELETED sprints,
   per-sprint contracts, per-sprint evaluations AND context resets, keeping Planner +
   Generator + ONE end-of-run QA pass; hand-off was FILES ("one agent would write a file,
   another agent would read it and respond"). Corrections to our earlier recollection: "fresh
   context per evaluation" was a v1 mechanism dropped in v2; the "blind evaluator" phrase is
   not in the post (its substance — a separate evaluator testing the live app — is).
8. **Evidence base:** ETH 2602.11988 v2 (LLM-generated context files −0.5…−2 pp success,
   +20–23 % cost; developer-written +2.4 pp n.s.); LLM-as-judge for code κ≈0.16 pairwise;
   self-preference bias grows with capability (a structured rubric cuts it 31.5 %); DORA
   2026-03 "deliver AI feedback to the author during the writing phase"; 2605.29442 — 91.5 %
   of resolutions needed human intervention and inaccurate self-reporting rises over time;
   MirrorCode's hardest failure was an early architectural choice diagnosed 192× and never
   reverted; LangChain +13.7 Terminal-Bench points from harness changes alone.
9. **This repo had no `.github/` directory** — every "CI-enforced" claim described tests
   nobody ran automatically (the ms/seconds bug shipped through a suite that asserted the
   wrong unit and was never executed). `arch-guard` still documents a camelCase
   `harness.json` shape nothing reads; ARCHITECTURE.md said "~100 lines" against the ≤60 cap.

## Headline decision

Four P0 contract fixes (hook timeouts are seconds; Stop NAMES via `systemMessage` and never
continues; the one workflow moves to plugin-root `workflows/` so it ships as
`/oh-my-agents:harness-audit`; a CI runner makes "CI-enforced" true) + a typed
self-correcting loop built ONLY from existing signals and native primitives (a complete gate
ladder whose APPROVE rung IS the pre-ship check and whose new plan rung pushes
execute→verify; `failures[]` as the twin of `findings[]`; a COMPUTED review decision from a
separate `Explore` judge that also reads gstack's typed findings; ONE `signal_fresh`
predicate with lazy gstack `wtree`; the `/spec` archive bridge; deterministic
done-confirmation) + six retirements (`NEXT:` line, the `hook_results` sensor and every
sourceless dashboard row, the Bash leg of session-metrics, `self-verify-check.sh`, the
`in_progress` tolerance, LLM-generated overview prose in `/harness-init`). Bright lines
intact: hooks NAME and never invoke — now by channel construction, not just by prose; all
gstack paths read-only (the `wtree` stamp calls a sanctioned read-only binary and is gated on
`git check-ignore`); the gstack verify marker stays a DERIVED EXPORT; the human TASTE gate is
untouched; coordination stays native.

## Changes (→ v3.11.0)

| # | P | Change | Files |
|---|---|--------|-------|
| 1 | P0 | Hook timeouts in SECONDS (10/5/5/3/2/8/3); rule + integration.json re-united (`*_s`); CI: ≤ceiling AND ≤60 tripwire; the three blocking gates carry no `git`/`find` and finish a 100 KB input in < 2 s (timed with python3); rule text: parallel ⇒ max(), fail-OPEN at the ceiling | hooks.json, integration.json, INTEGRATION.md, test-hooks |
| 2 | P0 | Stop NAMES, never continues: `emit_advisory` emits `systemMessage` only at Stop (the computed `with_context` flag is live); `doc-drift-check` exits with zero bytes on `stop_hook_active`; gate line assembled FIRST; no hook contains a `"continue"` key (CI) | common.sh, doc-drift-check.sh, test-hooks, CLAUDE.md, INTEGRATION, SIGNALS |
| 3 | P0 | `git mv .claude/workflows/harness-audit.js workflows/` — no manifest field; CI asserts `.claude/workflows/` stays absent and `meta.name` holds; every doc names `/oh-my-agents:harness-audit` | workflows/, harness.json, test-skills, README, ARCHITECTURE, INTEGRATION, SIGNALS, plugin.json |
| 4 | P0 | `.github/workflows/ci.yml`: both suites + `node --check` + `claude plugin validate --strict` (CLI installed on the runner); CI asserts the wiring | .github/, test-skills |
| 5 | P1 | Gate ladder completed — stale WARN → composition-skipped → **APPROVE = pre-ship check** (`signal_fresh GREEN --advance && signal_fresh APPROVE --advance` ⇒ `SHIP GATE: pass`; APPROVE without a GREEN at HEAD names `/verify`, never `/ship` — the live bug) → REQUEST_CHANGES (first ≤3 fingerprints) → hard NEEDS_HUMAN → RED (first ≤3 failure ids) → YELLOW → GREEN-no-review → plan changed since the last verify; SessionStart = model, Stop = human; 12 fixtures | doc-drift-check.sh, test-hooks, lifecycle, SIGNALS |
| 6 | P1 | Typed RED hand-back: `verify.jsonl` `failures[] {check,id,task_id,message}`; `reason == failures[0].message`; recurring-failure detection is one jq over `failures[].id`; `/lifecycle recover` retries `task_id` | verify, SIGNALS, lifecycle, DEEP-DIVE, test-skills |
| 7 | P1 | `/harness-review`: Reviews 1–5 ALWAYS in a separate built-in `Explore` judge (diff + acceptance + rubric + fresh verify signal; never this session's reasoning); decision COMPUTED from `findings[]` (P0 or ≥2 `[BOTH+]` ⇒ REQUEST_CHANGES; per-finding `needs_human` ⇒ NEEDS_HUMAN); gstack's typed `findings` read tolerantly (`.findings // []`); native `/code-review` is the user's forked delegate, never claimed Skill-tool-invocable | harness-review, SIGNALS, test-skills |
| 8 | P1 | ONE freshness predicate `signal_fresh <root> <signal> [decision] [--advance]` (common.sh): commit==HEAD (+ clean tree at ADVANCE points) OR optional `wtree` == live `bin/gstack-wtree` (lazy, `timeout 2`); producers stamp `wtree` only when the binary is executable AND both ledger dirs are gitignored (`git check-ignore -q` per path); `/harness-init` ignores `.claude/signals/` + `.claude/metrics/` unconditionally; 11 fixtures | common.sh, doc-drift-check.sh, SIGNALS, verify, harness-review, harness-init, lifecycle, tests |
| 9 | P1 | `/spec` archive bridge: `spec_artifacts` → `projects/{SLUG}/specs/*.md` selected by `spec_branch`; `/spec-to-task` reads it (issue view only as fallback); gstack re-pinned 1.84.1.0 with the milestone pin extended; `/connect-chrome` → `/open-gstack-browser`; `gstack_owns` += `/guard`, `/plan-*-review`, `/qa-only`, `/document-release`; both lists declared allow-lists; `-spec-*.md` CI-grepped dead | integration.json, spec-to-task, lifecycle, INTEGRATION, CLAUDE.md, plugin.json, test-skills |
| 10 | P1 | `/verify` CONFIRMS a deterministic pass: `in-progress` → `done` only for command-shaped acceptance THIS run executed green, all `failing_tests[]` passing, no `failures[].task_id` naming the task; ONE plan write before the signal; `/spec-to-task` defaults to a new plan when a spec is given | verify, spec-to-task, test-skills |
| 11 | P1 | `disable-model-invocation: true` on `harness-init` + `gstack-sync` (human-typed setup; −513 chars off every turn's listing; CI: exactly two) | harness-init, gstack-sync, WORKFLOW, test-skills |
| 12 | P1 | BINDING 1: `NEXT:` tail line RETIRED (zero consumers in two cycles); lifecycle stubs trimmed; negative grep in CI | lifecycle, SIGNALS, test-skills |
| 13 | P1 | BINDING 2: `hook_results` sensor deleted (field not in the PostToolUse input); every dashboard/DEEP-DIVE/gstack-sync row without a file source deleted (Enforcement, Gate-block, Eureka, `violations` query, "recent activity"); BOTH DORA `[proxy]` rows kept (they read existing report bridges); ledger line is exactly `{ts,tool,file,layer}` (CI) | session-metrics.sh, harness-dashboard, DEEP-DIVE, gstack-sync, WORKFLOW, OBSERVABILITY, integration.json, tests |
| 14 | P1 | PostToolUse `Bash` registration of session-metrics dropped (it wrote reader-less `{tool:"Bash",file:"",layer:""}` lines on the highest-frequency hook path); registrations 9 → 7 | hooks.json, session-metrics.sh, harness-dashboard, INTEGRATION, ARCHITECTURE, test-hooks |
| 15 | P1 | `ablate-per-model` fires: `self-verify-check.sh` deleted (hooks 7 → 6; PostToolUse ceiling 5 s → 2 s) with a named observational re-add trigger (syntax-class first-pass RED in `failures[]`) and `claude plugin eval --ablation with-without` as the re-add instrument | hooks/, hooks.json, tests, INTEGRATION, ARCHITECTURE, README, CLAUDE.md, plugin.json |
| 16 | P1 | BINDING 3: `in_progress` reader tolerance SUNSET (ACTIVE = `in-progress`, `done`; the enum GUIDE keeps the miss loud); fixture proves no handoff nag + a loud hint | plan-validation-check.sh, test-hooks, INTEGRATION |
| 17 | P1 | Duplicated probes deleted: gstack-sync's 26 count probes + verdict tail (−36 lines), verify's gstack-readiness paragraph/rows/rule (−12); `/skill-doctor` + `claude plugin eval` named as the retirement/ablation instruments (never dependencies) | gstack-sync, verify, WORKFLOW, INTEGRATION, harness-dashboard, integration.json, test-skills |
| 18 | P1 | doc-drift Stop path: the forked-ledger `find` walk runs only on turns that changed files (an idle Stop is the gate line only — a timed-out hook loses its whole output); observable `find`-shim fixture | doc-drift-check.sh, test-hooks |
| 19 | P2 | SIGNALS § Native consumers: a user-opt-in `TaskCompleted` gate recipe (commit-only inline jq, no plugin path, ≤12 lines) + the Dynamic-Workflow-stage sentence; INTEGRATION declares it as a reader | SIGNALS, INTEGRATION, test-skills |
| 20 | P1 | `/harness-init` writes task-specific instructions only — no "Architecture summary", "Module map with file counts", "Purpose (1-2 sentences)", "Common patterns" prose (arXiv 2602.11988); confirm before writing | harness-init, test-skills |

Also folded: ARCHITECTURE.md "~100 lines" → ≤60; OBSERVABILITY.md native-telemetry note;
version literals to 3.11.0 / gstack 1.84.1.0 / 2026-09-11 everywhere.

## Net accounting (thinner-or-neutral invariant HOLDS — thinner)

Skills 11→11 (two gain `disable-model-invocation`) · hook scripts **7→6** · hook event
registrations **9→7** · agents 0→0 · workflows 1→1 (moved to the plugin root; now actually
shipped). **Removed:** 1 hook script (95 lines) · 2 registrations · the `hook_results` parse
· ~40 sourceless dashboard/DEEP-DIVE/gstack-sync lines · ~26 duplicated probes · the `NEXT:`
section + lifecycle stubs · the pre-ship bash snippet (folded into the ladder) · one dead
bridge glob · one drifted command binding · four overview-prose generation bullets · a
2.8-hour effective hook ceiling · up to 8 forced continuation turns per Stop · one repo walk
per idle Stop. **Added:** `signal_fresh` (~40 lines incl. comments) · six ladder rungs (~30
lines) · `failures[]` (3 table rows) · one CI YAML (≤40 lines, outside the plugin runtime
surface) · ~90 test assertions. All SKILL.md ≤ 400 (max harness-review 387); root CLAUDE.md
60/60.

## Do-NOT-do (critics killed these — do not re-file)

The 2026-09-04 list stays in force (three entries are now RESOLVED rather than open: Stop
`additionalContext` removed as verified-harmful; `in_progress` sunset; plugin `workflows`
field VERIFIED unnecessary) · a native `if` filter on plan-validation-check (parallel hooks:
CPU not latency; the in-script guard stays) · keeping `self-verify-check.sh` "to measure it"
or shipping an `evals/` directory as its re-add gate (a re-add PR ships the eval case AND the
delta) · an in-tree bash copy of `gstack-wtree`, `wtree` as the PRIMARY predicate, or a
sunset of the commit path · routing the `/spec` hand-off through `decisions.jsonl` + `gh
issue view` as the primary path (the archive is on disk) · `/connect-chrome` as a DEAD
pattern (alias dir exists; replace, never purge) · reading or writing gstack's
`<branch>-evidence.jsonl` from `/verify` (`/ship` re-runs its lanes anyway; `gstack-evidence
run` is a writer) · any I/O (git, flock, ledger writes) inside the three blocking PreToolUse
gates (they fail OPEN) · naming native `/code-review` the four-pillar judge or claiming
Skill-tool invocation · re-binding the gate nudge to `UserPromptSubmit` (re-injects every
turn; collides with gstack's Memorable hook) · a second ladder location or a parallel
pre-ship snippet (one mapping, two renderings) · an APPROVE rung without `signal_fresh
verify-latest.json GREEN --advance` · removing the model's own `done`-marking trigger ·
`signal_fresh`, a sourced common.sh, or any gstack path literal inside the user-settings
`TaskCompleted` recipe · `disable-model-invocation` on any gate skill or `--quick`/`/loop`
target · deleting either DORA `[proxy]` row or the `{ts,tool,file,layer}` line · generating
repository-overview prose from `/harness-init` · timing with `date +%s%N` or a `find` shim
that exits non-zero.

## Open questions (unverified externals → probe / graceful degrade, never hard dependency)

1. `claude plugin validate --strict` on the unauthenticated CI runner — the job installs the
   CLI; confirm on the first run before calling it enforced.
2. Skill-listing budget (1 % of context, shared with gstack's 54 skills): run `/skill-doctor`
   once in a gstack-equipped session and record the table before the next cut.
3. `bin/gstack-wtree` cost under `timeout 2` on a large monorepo when commit≠HEAD — falls
   back to the commit path on timeout; measure once on a real repo.
4. gstack `/ship` Step 5 becoming ledger-first — the only condition under which reading
   `<branch>-evidence.jsonl` from `/verify` would save a test run.
5. Whether the `Explore` judge's per-review spawn is cost-justified on TRIVIAL diffs — a
   `--no-judge` opt-out for docs-only diffs only if cost data says so.
6. `git check-ignore -q` on a not-yet-existing path across target git versions (pattern
   matching does not require the file; the fixture runs on the CI runner's git only).
7. gstack `reviews.jsonl` `findings` shape across 1.84.x — read tolerantly; verify the
   `[BOTH+]` cross-tag against one real record before relying on it in a retro.
8. **BINDING for the next council:** every ladder rung must show ≥1 live sighting (a
   SessionStart injection or a Stop line observed in a real session) or be simplified; the
   `TaskCompleted` recipe must have ≥1 documented user or be dropped from SIGNALS.md.
