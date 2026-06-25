# gstack ↔ oh-my-agents Integration Guide

## Philosophy

**gstack** accelerates delivery: design → ship → deploy → monitor.
**oh-my-agents** enforces quality: architecture → entropy → observability → documentation.

Together they form a complete AI engineering stack. Neither plugin modifies the other's
files or state — integration happens through structured artifact consumption and shared
metric namespaces.

## Complementary Strengths (v1.46+ floor, v1.58.4.0 current)

> **Anchor docs**:
> [TEAM-DISCUSSION-2026-04.md](TEAM-DISCUSSION-2026-04.md) (composition v1),
> [TEAM-DISCUSSION-2026-04-30.md](TEAM-DISCUSSION-2026-04-30.md) (v1.21 alignment),
> [TEAM-DISCUSSION-2026-05-08.md](TEAM-DISCUSSION-2026-05-08.md) (v1.28 + dual-value
> paths + decision-signal flow), [TEAM-DISCUSSION-2026-05-23.md](TEAM-DISCUSSION-2026-05-23.md)
> (verify-signal contract + native Agent Teams + llms.txt oracle), and
> **[TEAM-DISCUSSION-2026-06-06.md](TEAM-DISCUSSION-2026-06-06.md) (gstack v1.56 reground +
> native Dynamic Workflows + signals → versioned Gate API + legacy sunset)**.
> Quarterly contract review is supplemented by **lightweight drift check on every
> `/gstack-sync --status`** — gstack ships ~daily (v1.28 → v1.58.4.0 across 2026-Q2;
> v1.57.5+ added an event-sourced decision/verdict layer we now reconcile read-only).

## Differentiation Anchor (where oh-my-agents is irreplaceable)

With Anthropic Managed Agents at $0.08/session-hour and OpenAI Agents SDK shipping
a model-native harness, generic *workflow orchestration* is now commoditized.
oh-my-agents must explicitly anchor its differentiation. **Locked decisions:**

| Concern | Owner | Rationale |
|---------|-------|-----------|
| Mechanical quality constraints (hooks + arch-guard + TASTE) | **oh-my-agents** | Repo-local enforcement; Managed Agents cannot replicate without source access |
| Two-layer model: observation → enforcement | **oh-my-agents** | ETH Zurich + Osmani back the human-gated TASTE layer |
| Anti-slop / anti-entropy long-horizon view | **oh-my-agents** | Chroma context-rot evidence; needs persistent project memory |
| Workflow orchestration (ideate → plan → ship → deploy) | **gstack** | Already commoditized; we *route* via `/lifecycle`, never *execute* |
| Generic harness runtime | **Managed Agents / Agents SDK** | Don't compete; consume |
| Auto-generated rules from learnings | **NEVER** | ETH Zurich: −20% tokens, lower performance |

| Dimension | gstack | oh-my-agents | Combined |
|-----------|--------|-------------|----------|
| Ideation | /office-hours (YC-style) | — | Design doc → execution plan |
| Planning | /autoplan (triple-voice) | — | Consensus tables → plan constraints |
| Decomposition | — | /spec-to-task (layer-aware) | Design doc auto-imported |
| Execution | /guard (freeze/careful) | hooks (arch/safety/metrics) | Dual hook systems coexist |
| Verification | — | /verify (lint→build→test→arch) | **Emits .claude/signals/verify-latest.json** for /ship pre-flight |
| Review (structural) | /review | — | Composed by /harness-review, tag `[STRUCTURAL]` |
| Review (architecture/entropy) | — | /harness-review | Owns four-pillar + dedup orchestration |
| Review (cross-model) | /codex | — | Composed when `--with-codex`, tag `[CROSS-MODEL]` |
| Review (security deep) | /cso (OWASP/STRIDE) | safety hooks (secrets) | Hooks block at edit-time; /cso owns deep audit, tag `[SECURITY]` |
| Review (UX/DX) | /design-review + /devex-review | — | Auto-suggested when UI files touched, tag `[UX]` |
| Shipping | /ship (version/changelog/PR) | — | Reads verify signal + review JSONL |
| Deployment | /land-and-deploy | — | Readiness gates include harness data |
| Monitoring | /canary | — | Health report → /harness-dashboard quality trend |
| Multi-session | conductor.json + .gstack-worktrees/ | **worktree-aware** verify/hooks | No cross-fire across sibling sprints |
| Confusion (v0.18) | Confusion Protocol | session-metrics + /harness-dashboard | Signals → .claude/metrics/confusion.jsonl |
| **Observation layer (v1.9+, ingest v1.26+)** | GBrain memory (`learnings`, `eureka`, `retro`, `timeline` via `gbrain put`) | `/encode-mistake --from-gbrain [type]` | Observations → TASTE rules (enforcement); two layers, single direction; human-gated |
| **Cross-machine memory (v1.17+, renamed v1.27)** | `~/.gstack-artifacts-worktree/` (current path only; legacy `gstack-brain*` sunset v3.6.0) | `/gstack-sync` + `/harness-dashboard` (read-only) | Agent learning persists across machines |
| **Deploy metrics (v1.11+)** | `/landing-report` | `/harness-dashboard` DORA proxy → grounded | deployment_frequency, lead_time, change_failure_rate sourced from real ships |
| **Workspace-aware ship (v1.11+)** | `bin/gstack-next-version` + version-gate.yml | `/verify` (no-op; gstack handles parallel-PR safety) | We do not compete with version allocation |
| **Conductor workspaces (v1.11+)** | `~/conductor/workspaces/` | hooks + verify (presence detection only) | Coexists with `.gstack-worktrees/`; both honored |
| Documentation | /document-release | doc-drift-check hook | Auto-sync + drift detection |
| Retrospective (velocity) | /retro | — | — |
| Retrospective (governance) | — | /harness-dashboard | DORA-proxy + dual-review rate |
| Debugging | /investigate (root cause) | /encode-mistake (permanent rule) | Investigate → encode loop |
| Quality | /qa + /design-review | /entropy-sweep + /encode-mistake --proactive | QA findings → encoded rules |
| Performance | /benchmark + /canary | — | Baseline tracking + monitoring |

## Artifact Flow

```
/office-hours ──────────→ design doc
                             │ (~/.gstack/projects/$SLUG/*-design-*.md)
                             ↓
/autoplan ──────────────→ consensus tables + test plan
                             │ (~/.gstack/projects/$SLUG/*-test-plan-*.md)
                             ↓ (auto-discovered by /spec-to-task)
/spec-to-task ──────────→ exec plan + companion MD
                             │ (docs/exec-plans/active/*.json)
                             ↓ (guides development)
[develop] + hooks ──────→ session metrics
                             │ (.claude/metrics/*.jsonl)
                             ↓ (verified)
/verify ────────────────→ verify report + readiness signal
                             │ (.claude/metrics/verify.jsonl)
                             ↓ (reviewed)
/harness-review ────────→ dual findings
                             │ (.claude/metrics/reviews.jsonl)
                             │ (~/.gstack/projects/$SLUG/*-reviews.jsonl)
                             ↓ (shipped)
/ship ──────────────────→ VERSION + CHANGELOG + PR
                             │
                             ↓ (deployed)
/land-and-deploy ───────→ deploy report
                             │ (.gstack/deploy-reports/)
                             ↓ (monitored)
/canary ────────────────→ health report
                             │ (.gstack/canary-reports/)
                             ↓ (retrospected)
/retro + /harness-dashboard → unified metrics
                             │
                             ↓ (improved)
/encode-mistake + /entropy-sweep → permanent guardrails
```

## Artifact Bridges (v1.1 manifest)

All bridges are **read-only**, **glob-based**, and **gracefully degrade** when absent.
See `.claude/integration.json` for the canonical list.

| Source | Artifact | Location | Consumer |
|--------|----------|----------|----------|
| /office-hours | Design doc | `~/.gstack/projects/$SLUG/*-design-*.md` | /spec-to-task (auto) |
| /plan-eng-review | Test plan | `~/.gstack/projects/$SLUG/*-test-plan-*.md` | /spec-to-task (auto) |
| /autoplan | Consensus tables | In plan file | /spec-to-task (extracted) |
| /spec-to-task | Exec plan JSON | `docs/exec-plans/active/*.json` | /verify --plan |
| /verify | Results JSONL | `.claude/metrics/verify.jsonl` | /harness-dashboard |
| /verify | **Readiness signal** | `.claude/signals/verify-latest.json` | /ship pre-flight |
| /harness-review | Findings JSONL | `.claude/metrics/reviews.jsonl` | /ship, /harness-dashboard |
| /review | Review log | `~/.gstack/projects/$SLUG/*-reviews.jsonl` | /ship, /harness-review (dedup) |
| /codex (v0.15+) | Cross-model report | `~/.gstack/projects/$SLUG/*-codex-*.md` | /harness-review (`[CROSS-MODEL]`) |
| /cso | Security audit | `~/.gstack/projects/$SLUG/*-cso-*.md` | /harness-review (`[SECURITY]`) |
| /design-review | UX report | `~/.gstack/projects/$SLUG/*-design-review-*.md` | /harness-review (`[UX]`) |
| /qa | Test outcome | `~/.gstack/projects/$SLUG/*-test-outcome-*.md` | /harness-dashboard |
| /canary | Health report | `.gstack/canary-reports/*.json` | /harness-dashboard (quality trend) |
| /land-and-deploy | Deploy report | `.gstack/deploy-reports/*.json` | /harness-dashboard (DORA proxy) |
| conductor (v0.16+) | Multi-session state | `conductor.json` | /verify, hooks (worktree-aware) |
| worktrees | Parallel sprint dirs | `.gstack-worktrees/` | /verify, hooks (scope guard) |
| /investigate | Root cause | Session context | /encode-mistake |
| session-metrics.sh | Tool usage | `.claude/metrics/session-*.jsonl` | /harness-dashboard, /retro |
| Confusion Protocol (v0.18+) | Uncertainty signals | `.claude/metrics/confusion.jsonl` | /harness-dashboard (legibility input) |
| gstack analytics | Skill usage | `~/.gstack/analytics/skill-usage.jsonl` | /harness-dashboard |
| gstack analytics | Eureka moments | `~/.gstack/analytics/eureka.jsonl` | /harness-dashboard |
| **GBrain (v1.12+, renamed v1.27)** | Federation worktree | `~/.gstack-artifacts-worktree/` (current path only; legacy `gstack-brain*` sunset v3.6.0) | /gstack-sync, /harness-dashboard |
| **GBrain (v1.9+)** | Learnings log | `${GBRAIN_WT}/learnings-*.jsonl` **OR** fallback `~/.gstack/projects/$SLUG/*-learnings-*.jsonl` | **/encode-mistake `--from-gbrain learning`** |
| **GBrain (v1.9+)** | Timeline log | `${GBRAIN_WT}/timeline-*.jsonl` | /harness-dashboard |
| **GBrain (v1.9+)** | Review log | `${GBRAIN_WT}/review-*.jsonl` | /harness-dashboard |
| **GBrain (v1.9+)** | Developer profile | `${GBRAIN_WT}/developer-profile-*.json` | /harness-dashboard |
| **GBrain (v1.12+)** | Repo policy | `~/.gstack/gbrain-repo-policy.json` | /gstack-sync |
| **gbrain CLI (v1.26+)** | Memory federation queries | `command -v gbrain` | /encode-mistake (`gbrain search --type {learning|eureka|retro}`) |
| **llms.txt index (v1.28+)** | Authoritative skill/command index | `<gstack_root>/llms.txt` | /gstack-sync (skill discovery; replaces hand-rolled enumeration) |
| **memory-ingest binary (v1.26+)** | Internal gstack ingest tool | `<gstack_root>/bin/gstack-memory-ingest` | presence probe only — we never invoke |
| **review decision signal (v3.4+)** | Decision tag from `/harness-review` | `.claude/signals/review-latest.json` | /lifecycle next (gates auto-advance) |
| **/landing-report (v1.11+)** | Post-ship metrics (local) | `.gstack/landing-reports/*.json` | /harness-dashboard (DORA grounded) |
| **/landing-report (v1.11+)** | Post-ship metrics (project) | `~/.gstack/projects/$SLUG/*-landing-*.md` | /harness-dashboard |
| **Conductor workspaces (v1.11+)** | Parallel sprint dirs | `~/conductor/workspaces/` | hooks (presence only) |

## Setup

### First-time integration

```bash
# 1. Install both plugins
# gstack: follow https://github.com/garrytan/gstack setup
# oh-my-agents: follow README.md installation

# 2. Initialize harness (detects gstack automatically)
/harness-init --quick

# 3. Configure integration bridges
/gstack-sync --setup
```

### Verify integration

```bash
/gstack-sync --status    # Shows full integration health report
```

## Workflow Modes

### Full Lifecycle (both installed)

```
/lifecycle next    # Auto-guided through all phases
```

Or manually:
```
/office-hours → /autoplan → /spec-to-task → [develop] → /verify → /harness-review → /ship → /land-and-deploy → /retro + /harness-dashboard → /encode-mistake
```

### oh-my-agents Only

```
/spec-to-task → [develop] → /verify → /harness-review → /encode-mistake
```

### gstack Only

```
/office-hours → /autoplan → [develop] → /review → /ship → /land-and-deploy → /retro
```

## Hook Coexistence

Both hook systems run independently and check different dimensions:

| Event | oh-my-agents Hook | gstack Hook | Conflict? |
|-------|-------------------|-------------|-----------|
| PreToolUse (Edit/Write) | arch-check.sh (layers) | check-freeze.sh (boundaries) | No — different checks |
| PreToolUse (Edit/Write) | safety-check.sh (secrets) | — | No overlap |
| PreToolUse (Bash) | bash-safety-check.sh | check-careful.sh (destructive) | No — different checks |
| PostToolUse (Edit/Write) | self-verify-check.sh | — | No overlap |
| PostToolUse (Edit/Write/Bash) | session-metrics.sh | — | No overlap |
| Stop | doc-drift-check.sh | — | No overlap |

## Key Integration Loops

### Design → Plan → Execute Loop
```
/office-hours → design doc → /spec-to-task auto-imports → exec plan → [develop with hooks]
```

### Verify → Review → Ship Loop
```
/verify (readiness signal) → /harness-review (dual findings) → /ship (consumes both)
```

### Investigate → Encode Loop
```
/investigate (root cause found) → /encode-mistake (permanent guardrail created)
```

### QA → Taste Loop
```
/qa (UI bug found) → /design-review (pattern identified) → /encode-mistake --proactive (rule encoded)
```

### Retro → Improve Loop
```
/retro + /harness-dashboard (metrics analysis) → /entropy-sweep (cleanup) → /encode-mistake (rules)
```

## Composition Principles & Skill Ownership

Decided in [Team Discussion 2026-04](TEAM-DISCUSSION-2026-04.md). The core rule:
**composition over duplication**. oh-my-agents does only what gstack cannot, and
defers cross-cutting concerns that gstack already owns.

| Capability | Owner | Composer behavior |
|------------|-------|-------------------|
| Layer / arch enforcement | oh-my-agents (hooks + arch-guard) | always-on |
| Secrets / bash safety | oh-my-agents (hooks) | edit-time blocking |
| Entropy & encode rules | oh-my-agents (entropy-sweep + encode-mistake) | weekly + on-demand |
| Doc drift | oh-my-agents (doc-drift-check) | session end |
| Legibility scoring | oh-my-agents (legibility-score) | on-demand |
| Lifecycle orchestration | gstack | oh-my-agents `/lifecycle` only routes & reports gates |
| Slop deep-check | **gstack /codex** | /harness-review delegates, never duplicates |
| Security deep-audit | **gstack /cso** | /harness-review delegates; hooks are backstop |
| UX / DX audit | **gstack /design-review + /devex-review** | /harness-review auto-suggests on UI diffs |
| Cross-model verification | **gstack /codex** | opt-in via `--with-codex` |
| Ship/Deploy/Canary | gstack | reads `.claude/signals/verify-latest.json` |
| Velocity retro | gstack /retro | — |
| Governance retro | oh-my-agents /harness-dashboard | DORA proxy + dual-review rate |

## Anti-Bloat Constraints

*Hard rules (current through v3.8.1). Stable anchor — linked from CLAUDE.md.*

1. **No new skills** for integration purposes; modify existing skills only.
2. **SKILL.md ≤ 400 lines** per skill; over-budget triggers immediate trim
   (this rule itself caught `spec-to-task` at 465 → trimmed to 317 lines).
3. **Glob over exact path** for every gstack bridge; gstack reorganizes frequently
   (~daily releases; 7 versions in 8 days during 2026-Q2).
4. **Loose version match**: probe artifact presence, not version strings.
5. **Read-only bridge**: never write to `~/.gstack/` or `~/.gstack-artifacts-worktree/`
   (post-v1.27 rename; legacy `gstack-brain*` path sunset v3.6.0).
6. **Lightweight drift check on every `/gstack-sync --status`**; deep contract
   review still quarterly (`--contract-check`).
7. **`min_supported` tracks gstack's major capability milestones**, not minor
   versions. Current floor: **v1.26.0.0** (Memory Ingest v1).
8. **Two-layer enforcement model — never collapse**:
   - gstack writes **observations** (`learnings-log`, `timeline-log`, `review-log`,
     `eureka`, `retro`, `builder-profile` via `gbrain put`)
   - oh-my-agents writes **mechanical enforcement** (TASTE rules, hook patterns)
   - Bridge is one-direction: observation → enforcement, via `/encode-mistake --from-gbrain`
   - **"taste" naming hazard**: gstack's `gstack-taste-update` learns *soft, decaying*
     design preferences (the observation layer); the harness `TASTE-NNN` rule is a
     *permanent, human-gated, mechanical* guardrail (the enforcement layer). Same word,
     opposite half-life. The collision *reinforces* the two-layer model when named
     precisely — gstack-taste is a candidate **feed** for a harness TASTE-NNN rule —
     but the two must never be equated in logs, prompts, or prose.
9. **Osmani principle for review output**: *success silence, failure verbosity*.
   Passing checks collapse to one line; failures stay verbose.
10. Every integration rule must answer: *"Will this still hold after gstack's next release?"*
    If no — replace with capability detection.
11. **Bridge dual-value is TRANSIENT, not permanent**: a gstack rename is probed at both
    the legacy and current paths *only until* `min_supported` clears the rename floor, then
    the legacy path is dropped (see rule 16). Both absent ⇒ graceful degrade. As of v3.6.0
    the `gstack-brain*` → `gstack-artifacts*` dual-value has sunset; single-path probes only.
12. **`min_supported` follows core-capability milestones (NEW v3)** — bumped at major
    surfaces (Memory Ingest v1 = v1.26), not at minor releases.
13. **No orchestration (NEW v3)** — `/lifecycle` is router + reporter, never executor.
    Workflow orchestration belongs to gstack; if any skill in this plugin starts
    *implementing* a phase rather than *invoking* it, that logic is removed.
14. **No auto-generated rules (NEW v3, ETH Zurich 2026)** — `/encode-mistake` candidates
    surfaced from gbrain are always human-gated. Auto-writing TASTE-NNN entries is forbidden.
15. **`llms.txt` is the capability oracle (NEW v3.5)** — gstack ships an authoritative
    skill/command index at `<gstack_root>/llms.txt` (v1.28+). Hand-maintained command
    names in `integration.json.composition` are **capability bindings, not pins**;
    `/gstack-sync --contract-check` reconciles them against `llms.txt` when present.
    Hand-rolled command lists are the drift source (this is how `/ux-audit` and `/health`
    went stale) — prefer the oracle, and degrade gracefully when it is absent.
16. **Sunset legacy dual-value paths on schedule (v3.5; FIRED v3.6.0)** — globbing both
    `gstack-brain*` (legacy) and `gstack-artifacts*` (current) forever is unbounded entropy,
    against our own anti-entropy mission. In v3.6.0 `min_supported` rose to **1.46** (well
    above the v1.27 rename floor), so every `*_legacy` bridge was DROPPED and `*_current`
    keys renamed to plain names. `legacy_sunset` now reads `FIRED@1.46.0.0`. A future rename
    re-introduces dual-value transiently, then sunsets on this same rule.

17. **Workflows ≤ 1, read-only, audit-only (NEW v3.6, native Dynamic Workflows)** — native
    Dynamic Workflows REINFORCE "never orchestrate" for the *delivery lifecycle* (a JS
    lifecycle script is now even more commoditized) and open exactly ONE narrow exception:
    oh-my-agents MAY ship **at most one** saved `.claude/workflows/*.js` that fans out its
    OWN read-only audit skills (entropy-sweep / harness-review / legibility) at repo scale
    and **terminates in a decision signal**. It may NEVER advance a delivery phase, mutate
    source, commit, open a PR, or call a gstack lifecycle skill (`/ship`, `/land-and-deploy`,
    `/canary`).
    - **Bright-line test (council canon):** does the artifact end in a **SIGNAL** or a
      **DEPLOYED ARTIFACT**? Signal = ours, allowed. Artifact = gstack's, forbidden.
    - **Distribution vs capability:** a saved workflow is a *distribution* primitive, not a
      *capability* primitive — it does not breach the ZERO-new-skills cap, but it is counted
      here so the discipline cannot leak into an ungoverned directory.
    - **Structural read-only, mechanically:** every audit/verify `agent()` uses
      `agentType:'Explore'`, which cannot Write/Edit/NotebookEdit — a real mechanism, not a
      grep self-test.
    - **Accountable-writer principle (v3.7.0, proven by the 2026-06-07 spike):** the workflow
      RETURNS a `review-latest.json`-shaped decision; it does NOT relay-write the signal. A
      relay agent that did not itself derive the verdict is *correctly blocked by the safety
      classifier* from emitting a decision signal (it reads as a fabricated audit result). The
      accountable invoker (a human, or `/harness-review`) persists the returned signal. This is
      the empirical answer to the prior "can a workflow agent write the signal?" open question:
      it can do FS, but it MUST NOT write a verdict it didn't earn.
    - **Status: ONE shipped — `.claude/workflows/harness-audit.js` (v3.7.0).** A read-only,
      fan-out, four-pillar governance audit. The A/B spike cleared the evidence gate: vs a
      single sequential pass it found **ZERO-overlap, additive** findings (3× recall) and
      adversarial verification filtered ~17% false positives. Use it for governance/release
      audits; use single-pass `/harness-review` for PR/hotfix validation.
    - **Corollary:** `/lifecycle` is NEVER reimplemented as a workflow.

## Foundational Principles

1. **Read-only bridge** — oh-my-agents reads gstack artifacts but never writes to gstack paths
2. **Graceful degradation** — all features work when either plugin is absent
3. **No duplicate data** — reference original files, don't copy metrics
4. **Conversation + artifacts** — within a session, context flows naturally;
   across sessions, structured artifacts provide continuity
5. **Rippable integration** — if either plugin updates, the bridge adapts; no tight coupling
6. **Composition over duplication** — defer to gstack when gstack already covers the concern
7. **Capability detection over version pinning** — probe artifact surface, not version numbers
8. **Worktree awareness** — never operate across `.gstack-worktrees/` siblings
