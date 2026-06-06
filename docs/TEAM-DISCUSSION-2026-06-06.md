# Team Discussion — 2026-06-06

**Topic:** Tighten oh-my-agents' integration with **gstack v1.56** and Claude Code's new
native **Dynamic Workflows**, aligned to the latest Harness-Engineering thinking — to raise
delivery **quality + efficiency** toward AI-automated development, **without bloat**.

**Format:** Run as a native **Dynamic Workflow** (12 Opus agents: 4 independent positions →
4 rebuttals + votes → adversarial prosecutor/defender/referee on the riskiest call →
synthesis). The medium was the message: we used the very primitive under debate to debate it.

**Panel** (same four as all prior rounds — decision inheritance):
- **林舟** — Claude Code Skill/Plugin expert (primitive taxonomy, token budget, anti-bloat caps)
- **方哲** — Harness Engineering expert (four pillars, 5-layer model, rippable principle; authored "never orchestrate")
- **苏衡** — R&D efficiency expert (DORA, flow efficiency, handoff friction, AI-autonomy)
- **陈景** — Systems architect (contracts, coupling, capability probing, version resilience)

---

## What changed since 2026-05-23 (the facts that forced this round)

1. **gstack is at v1.56.0.0** (2026-06-03), not the v1.28 our `integration.json` pinned —
   ~28 minor versions of self-inflicted drift inside an *anti-drift* plugin. gstack's recent
   line **converged onto our principles**: on-demand content loading (progressive disclosure,
   25–49% token cut, v1.46/1.54/1.56), a `/spec` intent→spec skill (v1.47), a shared redaction
   engine (v1.53), and an eval-first floor + hard token/$ gates across all 51 skills (v1.46).
2. **Claude Code shipped Dynamic Workflows** (research preview, 2026-05-28) — a *deterministic*
   JS-script orchestration primitive (the script holds the plan; only `agent()` bodies are
   model-powered; up to 1000 agents; savable as `.claude/workflows/*.js`). This **postdates
   every prior round** — the plugin had never considered it.
3. **Harness Engineering** is now framed as the "fourth paradigm," with a normative 5-layer
   model (tool orchestration · verification loops · context/memory · guardrails · observability).
   Evidence that the harness — not the model — is the lever: LangChain moved Terminal-Bench 2.0
   52.8% → 66.5% by changing only the harness.

---

## The central tension

The plugin's locked anchor is **"never orchestrate — `/lifecycle` is a router, not an executor;
generic orchestration is commoditized; we own repo-local mechanically-verifiable quality."**
Native Dynamic Workflows make orchestration *even more* native. Does that **kill** any
ambition to use workflows, or does it **open a door**?

The council also self-verified against disk and found three pre-existing debts: the
`/lifecycle` skill **contradicted its own anchor** ("EXECUTES the next skill directly" vs
"router, never executor"), neither decision signal carried a `schema_version`, and doc-drift
was covered **three** times.

---

## Decisions (consensus level noted)

1. **Dynamic Workflows REINFORCE "never orchestrate" for the delivery lifecycle, and open
   exactly ONE narrow exception** *(unanimous)* — oh-my-agents MAY ship **≤1** saved
   read-only QUALITY-AUDIT workflow that fans out its OWN audit skills at scale and
   **terminates in a decision signal**. It may NEVER advance a delivery phase, mutate source,
   commit, open a PR, or call a gstack lifecycle skill. A saved workflow is a *distribution*
   primitive, not a *capability* primitive — it does not breach the zero-new-skills cap, but
   it is **counted** (anti-bloat rule 17) so the discipline can't leak into an ungoverned dir.

2. **Bright-line test, adopted verbatim as canon** *(unanimous, 苏衡's)* —
   > *Does the artifact end in a **SIGNAL** or a **DEPLOYED ARTIFACT**? Signal = ours,
   > allowed. Artifact = gstack's, forbidden.*
   Corollary: `/lifecycle` is NEVER reimplemented as a workflow; the day any `agent()` node
   can mutate/commit/PR/call-a-gstack-lifecycle-skill, the workflow is deleted — no rule-17
   amendments to admit it. Read-only-ness is enforced **structurally** (agent() calls may pass
   only the four read-only audit skills' toolsets), because a grep self-test cannot prove the
   read-only-ness of IO that happens inside model turns (the prosecutor's winning point).

3. **Promote the decision signals to a versioned, documented "Gate API"** *(unanimous —
   "highest-confidence yes of the council")* — Dynamic Workflows forbid mid-run user input
   ("each stage its own workflow"), which makes machine-readable stage boundaries *mandatory
   infrastructure*, and we already emit exactly that shape. Add `schema_version`, consolidate
   the triplicated semantics into one **`docs/SIGNALS.md`**, and have verify/harness-review/
   lifecycle reference it. This is the durable, irreplaceable position: the verification
   **layer** the whole stack gates on, not a workflow participant.

4. **Fire `legacy_sunset` now** *(unanimous)* — the plugin's OWN rule 16 trigger is met
   (`min_supported` should clear the v1.27 rename floor). Delete the 5 `*_legacy`
   gstack-brain bridges + the **duplicate `bridge_dual_value` JSON key**, rename `*_current`
   → plain, re-ground `integration.json` to v1.56 via the `llms.txt` oracle, and raise
   `min_supported` to a **capability milestone (v1.46**, eval-first/on-demand floor) — not
   the latest minor, to avoid stranding mid-version users. Pure subtraction.

5. **`/spec-to-task` is NOT redundant given gstack `/spec`** *(unanimous)* — re-cut as a
   clean pipeline handoff. gstack `/spec` does intent→spec (codex-gated); our `/spec-to-task`
   does spec→**layer-aware, dependency-ordered, failing-tests-first exec-plan JSON** that
   `verify --plan` / `harness-review --plan` gate on — gstack has no equivalent. Add a
   `/spec` import probe (glob, never hard-parse — `/spec` may file a GitHub issue, not a
   stable file) and thin the now-upstream ambiguity prose.

6. **Resolve the `/lifecycle` router/executor contradiction THIS round** *(unanimous,
   author 方哲 conceding)* — delete the "EXECUTES directly" language; `/lifecycle` becomes a
   pure router/reporter that names the next phase + remediation skill, reads the signal, and
   STOPS. *"The plugin may not ship a new fan-out engine while its existing router violates
   the anchor it cites."* Delivery auto-advance is ceded to gstack — it does NOT migrate into
   the audit workflow.

7. **Fine-grain `NEEDS_HUMAN`** *(unanimous)* — add a `needs_human_kind` sub-enum
   (`arch-ambiguity | judgment-slop | composition-skipped`) set by harness-review.
   `composition-skipped` becomes **auto-recoverable** (lifecycle re-runs `/codex`|`/cso`
   instead of halting); the other two stay hard halts. Halting because composition was
   skipped is a false-positive human touchpoint that breeds alarm fatigue.

8. **Demote "progressive disclosure" from differentiator to implementation note**
   *(unanimous)* — gstack v1.46–1.56 converged onto it; it's table stakes now. Re-anchor the
   moat on (a) repo-local edit-time mechanical enforcement and (b) the versioned signal Gate API.

9. **Retire `doc-gardening-agent` (2 → 1 agents)** *(lead-call over mild dissent)* — doc-drift
   is triple-covered; keep the deterministic `doc-drift-check` hook + on-demand `/entropy-sweep`,
   drop the redundant continuous background agent. Sequenced after the config/contract work.

10. **The actual `/harness-audit` workflow file is GATED to next round** *(majority)* — ratify
    the exception + rule 17 + the structural read-only guarantee now; ship the file only after
    (a) a verified `agent()`→`.claude/signals/` write path against the real Dynamic Workflows
    API (scripts can't do FS/shell — only agents do IO), and (b) a measured A/B proving
    adversarial fan-out beats sequential `/entropy-sweep` + `/harness-review`. Honors gstack's
    own v1.46 eval-first floor. When shipped it emits `review-latest.json`, not a new artifact.

---

## Adversarial debate — may we ship a workflow at all?

- **Prosecutor's winning blow:** a workflow's IO happens inside model-turn `agent()` calls,
  so a grep self-test *cannot* mechanically prove read-only-ness — and "mechanically verifiable"
  is our entire moat. ⇒ the read-only guarantee must be **structural** (toolset-scoped), not textual.
- **Defender's winning line:** "never orchestrate" was always about owning the *delivery
  lifecycle graph*, not whether any deterministic loop may exist; a parallel-map over our own
  read-only audits that ends in a signal is the one irreplaceable thing run at repo scale.
- **Referee verdict (binding):** *Conditional yes — but win the fight we're already losing
  first.* Sequence: (1) pay the staleness debt + retire the redundant agent, (2) de-orchestrate
  `/lifecycle`, (3) harden the signals into a versioned Gate API, (4) only then ship ≤1 workflow
  under rule 17 + an evidence gate + structural read-only. This round does (1)–(3) and ratifies
  the rule; (4)'s file is deferred.

---

## Action plan (status: all landed this round except the gated workflow file)

| # | Change | Files | Net bloat |
|---|--------|-------|-----------|
| 1 | Fire legacy_sunset; re-ground integration.json to v1.56; min_supported→1.46; kill dup key; rename `*_current` | `.claude/integration.json`, `skills/gstack-sync/SKILL.md` | −5 keys, −1 dup key, −~20 lines |
| 2 | `/lifecycle` → pure router/reporter (delete EXECUTE language) | `skills/lifecycle/SKILL.md` | −~12 lines |
| 3 | Gate API: `docs/SIGNALS.md` + `schema_version` + `needs_human_kind`; consolidate triplicated prose; contract test | `docs/SIGNALS.md`, `skills/verify`, `skills/harness-review`, `skills/lifecycle`, `tests/test-skills.sh` | +1 doc, −~30 dup lines |
| 4 | `/spec`→`/spec-to-task` handoff glob + thin upstream prose | `skills/spec-to-task/SKILL.md`, `.claude/integration.json` | ~neutral |
| 5 | Ratify rule 17 + bright line + Dynamic-Workflows architecture note | `CLAUDE.md`, `docs/INTEGRATION.md`, `docs/ARCHITECTURE.md` | +~6 doc lines |
| 6 | Demote progressive disclosure; refresh v1.28→v1.56 metadata | `README.md`, `CLAUDE.md`, `docs/ARCHITECTURE.md`, `docs/INTEGRATION.md` | thinner narrative |
| 7 | Retire `doc-gardening-agent` (2→1) | `agents/`, `CLAUDE.md`, `README.md`, `docs/ARCHITECTURE.md`, `.claude-plugin/*` | −1 file |

Version: **v3.5.0 → v3.6.0**.

---

## Open questions (carried forward)

- **Exact gstack `/spec` artifact path** — `/spec` may file a GitHub issue, not a stable
  `*-spec-*.md`; confirm against `llms.txt` + live `~/.gstack/projects/$SLUG/` before relying
  on the glob. (Handled defensively this round; resolve before deepening the handoff.)
- **`agent()`→signal write path** — does a Dynamic Workflow agent re-running our skill actually
  write `.claude/signals/` correctly given the script itself can't do FS/shell? Blocks `/harness-audit`.
- **Adversarial-fan-out evidence A/B** — does cross-verification measurably beat sequential
  runs (false-positive ↓ or catch-rate ↑)? Required before shipping `/harness-audit`.
- **Legibility Score → trajectory-eval** (deferred 4×) — bind it as one `parallel()` node in the
  future `/harness-audit` with a hard evidence-gated sunset, rather than a 5th blind defer.
- **`session-metrics.sh` → native monitor** — monitor-shaped hot-path work; time-box the
  migration, keep separate from the workflow work (don't change two observability mechanics at once).
- **Workflow min-version pin** (Claude Code v2.1.154+) — capability-detect + graceful-degrade to
  sequential runs; decide before `/harness-audit` ships.
- **If gstack ships a native Evaluator-role skill** — does `/harness-review` retreat to a thin
  shell emitting only the decision signal + dedup tags? The signal-emission role is the durable part.

---

## Anti-bloat ledger

**Net thinner.** Skills **11 → 11** (zero new — cap honored). Agents **2 → 1**. Hooks **6 → 6**.
Workflows **0 → 0** (governed-but-deferred). Docs **+1** (`SIGNALS.md`, which *absorbs* ~30 lines
previously triplicated across three SKILL.md and frees headroom toward the 400-line cap).
Removed: 5 legacy bridges, 1 duplicate JSON key, ~15 contradictory lifecycle lines, triplicated
signal semantics, the progressive-disclosure moat claim + stale v1.28 strings, 1 agent file. The
one genuinely new capability (read-only adversarial audit-at-scale terminating in a signal) adds
**no executable surface this round** — it's gated behind evidence. The durable position (repo-local
mechanical enforcement + a versioned cross-tool Gate API) is **strengthened, not expanded**. The
plugin now practices the anti-entropy mission it preaches.
