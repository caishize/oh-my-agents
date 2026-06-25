# Team Discussion — 2026-06-25 · Harness-Fusion Council (→ v3.8.0)

**Topic:** Fuse oh-my-agents + gstack + Claude Code's native harness (Dynamic Workflows,
Agent Teams) into one AI-automated delivery pipeline — higher delivery quality/efficiency,
without bloat.

**Mechanism:** a read-only Dynamic Workflow expert council (`harness-fusion-council`,
ephemeral — NOT shipped; rule 17 keeps the one shipped workflow at `harness-audit.js`).
Four expert lenses proposed (Claude Code Skill · Harness Engineering · R&D Efficiency
(DORA) · System Architect); four adversarial critics stress-tested every recommendation
(anti-bloat · gstack-overlap · native-redundancy · delivery-impact); the accountable
invoker synthesized. 28 recommendations → critic-filtered → the changes below.

## Grounding facts that changed the calculus (verified 2026-06)

1. **gstack is v1.58.4.0**, not v1.56 — our metadata was stale.
2. **gstack now ships its own decision/verdict layer** (v1.57.5 `decisions.jsonl` +
   `decisions.active.json`; v1.57.7 mandatory unresolved-decisions verdict that blocks
   gstack's approval gate; `gstack-review-log` machine verdict; `/codex GATE: PASS/FAIL`).
   Two independent gates that disagree would confuse `/ship`.
3. **`~/.gstack-artifacts-remote.txt` and `~/.gstack-brain-remote.txt` are two DISTINCT
   remotes**, not a rename — the v3.6.0 "artifacts-only" framing could read as "gbrain gone".
4. gstack has **no `.claude-plugin/plugin.json`** (detect by skill dirs) and uses a
   "carved skills" skeleton+`sections/` pattern for context reduction.
5. External patterns folded in: Anthropic Labs' **Planner/Generator/Evaluator** three-agent
   harness (context resets > compaction; structured-artifact handoff; GAN evaluator loop);
   OpenAI/Fowler harness canon (GUIDES feedforward vs SENSORS feedback; computational vs
   inferential; "never make that mistake again").

## Headline decision — reconcile, don't compete

The single highest-value lever: `/harness-review` (and `/verify` advisorily) now **read &
reconcile** gstack's verdict layer **read-only** instead of emitting a competing parallel
signal. The bright-line constraint (enforced by the gstack-overlap + native critics):

> We stay the accountable arbiter. gstack's verdict is **advisory context** captured in the
> optional `gstack_context` field — never an aggregate, never a mechanical rewrite of our
> decision, never a write to gstack paths. **Agree ⇒ pass through. Diverge ⇒
> `NEEDS_HUMAN:judgment-slop`.** Absent ⇒ graceful degrade, our signal stands alone.

Contract: [SIGNALS.md](SIGNALS.md#reconciliation-with-gstack-v1575-native-verdicts).
`gstack_context` is optional ⇒ `schema_version` stays `1`.

## Changes shipped (v3.8.0)

| # | Change | Files |
|---|--------|-------|
| P0 | Version accuracy: gstack v1.56→v1.58.4.0; plugin v3.7.1→v3.8.0 | CLAUDE.md, README.md, INTEGRATION.md, ARCHITECTURE.md, integration.json, plugin.json, marketplace.json |
| P0 | gbrain detection hardened (CLI/`gbrain doctor`/worktree/brain-remote; brain≠artifacts) | gstack-sync, integration.json |
| P1 | gstack verdict reconciliation (read-only advisory + divergence halt) | SIGNALS.md, harness-review, verify, integration.json |
| P1 | Exec-plan `planner_metadata` (parallelizable_groups, context_budget, recovery_edges) + task `context_files`/`failing_tests` — typed Planner→Generator handoff | templates/execution-plan.json, spec-to-task |
| P1 | `plan-validation-check.sh` — feedforward GUIDE (advisory, never blocks) on under-specified exec-plan tasks | hooks/ (new, 7th hook), hooks.json, tests |
| P1 | Slop taxonomy consolidated to one canonical source | docs/LINTING.md (+), harness-review/entropy-sweep (− point to it) |
| P1 | "Three review/audit moments" canonical table; native-harness Evaluator reconciliation noted | ARCHITECTURE.md |
| P2 | `/harness-dashboard --query velocity` (DORA lens) + evidence-gated TASTE-rule sunset recommendation | harness-dashboard |
| P2 | `/harness-audit` 6th dimension: VALIDATES reconciliation happened (never performs it) | harness-audit.js |

## Net accounting (thinner-or-neutral invariant held)

One justified new executable surface — the `plan-validation-check.sh` GUIDE (highest-leverage
harness pattern: prevent the mistake vs detect it) — offset by the slop-taxonomy + audit-moments
**consolidation** (single source of truth, less drift) and net-neutral skill prose. Decision-log
growth (this file) is the expected, healthy growth of the System-of-Record pillar, not bloat.

## Verified-already-done (NOT re-implemented — the plugin was more mature than assumed)

- `/lifecycle` is already a pure router ("NAME, don't invoke"); no executor code to delete.
- `composition-skipped` auto-recovery already wired in `/lifecycle` + SIGNALS.md.
- Planner/Generator/Evaluator + native-harness mapping already in ARCHITECTURE.md.
- `encode-mistake --from-gbrain` already CLI-first with worktree/project fallback.
- `harness-dashboard` already computes velocity (we only added the `--query` deep-dive + sunset rec).
- `doc-gardening-agent` already retired (v3.6.0).

## Do-NOT-do (critics killed these)

New orchestration/Agent-Teams skills (rule 5) · auto-generated TASTE rules (ETH-Zurich:
−20% tokens, worse perf) · relay-agent signal writes (safety classifier blocks) · deleting
`/verify` or `/legibility-score` (deprecate/defer, don't delete) · merging
entropy-sweep/harness-review/harness-audit (same definition, different trigger) · a unified
**aggregate** verdict (bright-line break) · new Bash CLI-API helper files (document the schema).

## Open (deferred — human call)

1. Retire `session-observer-agent`? Audit downstream consumers first; not done this round.
2. Emit a structured `lifecycle-next.json`? Useful for workflow auto-loading but adds a
   signal artifact — deferred pending demand (must never imply auto-invocation).
