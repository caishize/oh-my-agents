# oh-my-agents `v3.9.0`

Lean Claude Code plugin implementing **Harness Engineering** — the discipline of
designing environments, constraints, and feedback loops that make AI coding agents
work reliably at scale. **Composition-based** integration with
[gstack](https://github.com/garrytan/gstack.git) (v1.46+ floor, v1.62.0.0 current) for
full-lifecycle coverage (slop-deep, security-deep, and UX audits delegated to gstack;
GBrain memory ingest + `/landing-report` consumed as read-only sensors; gstack's own
v1.57.5+ verdict layer **reconciled** read-only by `/harness-review`; architecture,
entropy, legibility, and the **decision-signal Gate API** owned by oh-my-agents).

**Differentiation anchor**: with Managed Agents, the OpenAI Agents SDK, native **Agent
Teams**, and native **Dynamic Workflows** all commoditizing generic orchestration, this
plugin doubles down on what is *irreplaceable* — repo-local mechanical constraints (hooks
+ arch-guard + TASTE rules) and a **versioned decision-signal Gate API**
([docs/SIGNALS.md](docs/SIGNALS.md)) that every executor gates on. We **never** orchestrate
delivery; gstack does that. `/lifecycle` NAMES the next skill, never invokes it. (Progressive
disclosure is an implementation practice gstack now ships too — kept, but not the moat.)

> **11 skills · 1 agent · 7 hooks · 1 audit workflow** — minimal context-window footprint; a Gate API, not an orchestrator.

## The Four Pillars

| Pillar | What It Means | This Plugin |
|--------|---------------|-------------|
| **Architecture as Guardrails** | Mechanical layer enforcement + Providers pattern | `arch-guard`, `encode-mistake`, hooks |
| **Documentation as System of Record** | Everything agents need lives in the repo | `harness-init`, `legibility-score`, `spec-to-task` |
| **Observability & Legibility** | Agents and humans can see what happened | `verify`, `harness-dashboard`, session metrics |
| **Entropy Management** | Continuous resistance to codebase degradation | `entropy-sweep`, `harness-review`, `encode-mistake` |

## Installation

```bash
# Via plugin system (recommended)
/plugin marketplace add caishize/oh-my-agents
/plugin install oh-my-agents

# Manual
git clone https://github.com/caishize/oh-my-agents.git ~/.claude/skills/oh-my-agents
```

## Quick Start

```
/harness-init --quick     # All-in-one: init + score + arch-guard
/gstack-sync --setup      # Configure gstack integration (if installed)
```

## Skills

| Skill | Pillar | Purpose |
|-------|--------|---------|
| `/harness-init` | All | Initialize harness: CLAUDE.md, docs/, bootstrap, config |
| `/legibility-score` | All | 10-metric Agent Legibility Score (0-30) |
| `/spec-to-task` | Documentation | Convert specs to layer-aware execution plans |
| `/verify` | Architecture | Build + test + lint + arch check with structured results |
| `/encode-mistake` | Entropy | Mistakes or taste → permanent guardrails (TASTE-NNN) |
| `/arch-guard` | Architecture | Set up layer enforcement + Providers pattern |
| `/entropy-sweep` | Entropy | Scan for slop, drift, violations, dead code |
| `/harness-review` | Entropy | Four-pillar review; composes gstack `/codex` (cross-model), `/cso` (security), `/design-review` — dedup + severity escalation |
| `/harness-dashboard` | Observability | Metrics overview + DORA-proxy + `--query` for deep-dive analysis |
| `/gstack-sync` | Integration | Detect gstack, configure bridges, lightweight drift check on every `--status`, `--contract-check` for quarterly deep audit |
| `/lifecycle` | Integration | Lifecycle **router** — detects state, reads decision signals, NAMES the next phase + remediation skill (never invokes); worktree-aware |

## Agents

| Agent | Model | Purpose |
|-------|-------|---------|
| `session-observer-agent` | Haiku | Session tracking and shift-handoff summaries |

Read-only (no Write/Edit), uses agent memory for cross-session learning. (The former
`doc-gardening-agent` was retired in v3.6.0 — doc drift is covered by the `doc-drift-check`
hook at edit-time plus `/entropy-sweep` Sweeps 2/4/5/7 on-demand; the continuous background
agent was a redundant third layer.)

## Hooks

**Canonical list: [`hooks/hooks.json`](hooks/hooks.json)** (7 hooks). One line each:
`arch-check` (blocks layer violations) · `safety-check` (blocks secrets) ·
`plan-validation-check` (exec-plan GUIDE + plan-completion nudge) · `bash-safety-check`
(blocks credential leaks) · `self-verify-check` (post-edit syntax warn; deprecation
candidate vs native diagnostics) · `session-metrics` (JSONL activity log) ·
`doc-drift-check` (Stop-time doc drift + gate-state nudge).

## Dynamic Workflows

| Workflow | Purpose |
|----------|---------|
| `/harness-audit` | Read-only four-pillar **governance audit** — fan-out `Explore` agents (cannot write) + adversarial verification; **returns** a `review-latest.json`-shaped decision (the accountable invoker persists it — never a relay write). Use for release/quarterly audits (the A/B spike found 3× the recall of a single pass, zero overlap); use `/harness-review` for PR validation. Requires native Dynamic Workflows (Claude Code v2.1.154+); degrades to `/harness-review` when absent. |

Governed by anti-bloat rule **`single-workflow`** (≤1 workflow, read-only, audit-only, returns — never writes — the signal; SIGNAL-not-ARTIFACT bright line). See [docs/TEAM-DISCUSSION-2026-06-06.md](docs/TEAM-DISCUSSION-2026-06-06.md) (§ spike addendum) for the evidence.

## Workflow

### Full Lifecycle (with [gstack](https://github.com/garrytan/gstack))

```
/lifecycle next                   # Auto-guided (recommended)
# OR manually:
/office-hours → /autoplan → /spec-to-task → develop → /verify → /harness-review → /ship
```

### Daily (oh-my-agents only)

```
/spec-to-task <feature-spec>      # Plan with tests first
# ... agent implements tasks ...
/verify                            # Structured pass/fail
/harness-review                    # Say No to Slop
```

### When Agents Make Mistakes

```
/encode-mistake "agent imported from wrong layer again"
# → permanent hook or lint rule (TASTE-NNN), documented in docs/LINTING.md

/encode-mistake --proactive "all API responses must use ResponseEnvelope<T>"
# → encode expert taste without waiting for a failure
```

### Weekly

```
/entropy-sweep                     # Codebase garbage collection
/harness-dashboard                 # Health overview
/harness-dashboard --query trends  # Deep-dive metric analysis
```

## gstack Integration

oh-my-agents and gstack are complementary:
- **gstack** accelerates delivery: ideation → planning → review → shipping → deployment → monitoring
- **oh-my-agents** enforces quality: architecture → entropy → observability → documentation

Key handoffs (composition-based, read-only, glob-based; **single-path since the v3.6.0
legacy sunset** — dual-value only transiently across a future rename):
- Design docs from `/office-hours` and specs from `/spec` (v1.47) → `/spec-to-task` (auto-imported)
- **Decision-signal Gate API (v3.6, versioned; v3.9 commit-freshness)** — full contract
  in [docs/SIGNALS.md](docs/SIGNALS.md). Both signals carry `schema_version` (+ optional
  `commit`); consumers default-deny anything missing/malformed/unknown-version/stale.
  Consumed by `/lifecycle`, **Dynamic Workflow stages**, and **Agent Teams**. The
  pre-`/ship` gate is an **our-side convention** (docs/SIGNALS.md pre-ship check) —
  `gstack-sync --contract-check` probes it and reports `VERIFIED | ASSERTED`; no
  evidence yet confirms gstack reads our signals.
- **`/verify`** → `.claude/signals/verify-latest.json` with `GREEN | YELLOW | RED`.
- **`/harness-review`** → `.claude/signals/review-latest.json` with `APPROVE |
  REQUEST_CHANGES | NEEDS_HUMAN`. `NEEDS_HUMAN` now carries `needs_human_kind`
  (`composition-skipped` auto-recovers; `arch-ambiguity` / `judgment-slop` halt) — compresses
  "未决态" so the flow no longer waits on a human for a recoverable skip.
- `/harness-review` composes gstack's `/codex` (cross-model slop), `/cso` (security),
  `/design-review` (UI) — tags `[HARNESS]`/`[STRUCTURAL]`/`[CROSS-MODEL]`/`[SECURITY]`/`[UX]`/`[BOTH+]`
- `/investigate` (gstack) → `/encode-mistake` (oh-my-agents) closes the feedback loop permanently
- **GBrain memory** → `/encode-mistake --from-gbrain [learning|eureka|retro|all]` — uses
  `gbrain` CLI when present (v1.26+), falls back to `~/.gstack-artifacts-worktree/` (v1.27+)
  → per-project log (legacy `gstack-brain*` path dropped in the v3.6.0 sunset). Always
  **human-gated** (ETH Zurich 2026: auto-generated rules hurt agent performance).
- **`/landing-report` (gstack v1.11+) → `/harness-dashboard`** — DORA proxy upgrades to
  `[grounded]` when real ship/canary data is present
- `/lifecycle` is a **router** with Gate Failure Routing — names the exact remediation
  skill on every failed gate; never re-implements a phase
- Worktree-aware: honors both `.gstack-worktrees/` and `~/conductor/workspaces/` (v1.11+)
- Lightweight contract drift check on every `/gstack-sync --status` (gstack shipped
  7 versions in 8 days during 2026-Q2; drift is the norm)
- **Capability oracle (ordered succession, v3.9)** — local `VERSION` file → `llms.txt`
  glob → skill index → raw CHANGELOG fetch (network last); never hand-rolled enumeration
- `.claude/gstack-rendered/` is a **gstack-owned enclave** (v1.57.9+) — gitignored,
  excluded from entropy scans, never flagged

See [docs/INTEGRATION.md](docs/INTEGRATION.md) for full bridge manifest;
[docs/TEAM-DISCUSSION-2026-04.md](docs/TEAM-DISCUSSION-2026-04.md) (original
composition rationale),
[docs/TEAM-DISCUSSION-2026-04-30.md](docs/TEAM-DISCUSSION-2026-04-30.md)
(v1.21-era re-alignment), and
[docs/TEAM-DISCUSSION-2026-05-08.md](docs/TEAM-DISCUSSION-2026-05-08.md)
(v1.28-era dual-value bridges + decision signal + differentiation anchor), and
[docs/TEAM-DISCUSSION-2026-05-23.md](docs/TEAM-DISCUSSION-2026-05-23.md)
(verify-signal contract fix + native Agent Teams + llms.txt capability oracle +
OpenAI-component mapping), and
[docs/TEAM-DISCUSSION-2026-06-06.md](docs/TEAM-DISCUSSION-2026-06-06.md)
(gstack v1.56 reground + native Dynamic Workflows stance + signals → versioned
**Gate API** [docs/SIGNALS.md](docs/SIGNALS.md) + legacy sunset + doc-gardening retirement),
and [docs/TEAM-DISCUSSION-2026-06-25.md](docs/TEAM-DISCUSSION-2026-06-25.md)
(v3.8.0 harness-fusion: gstack v1.58.4.0 verdict-layer reconciliation + typed Planner
handoff + plan-validation GUIDE hook + slop-taxonomy consolidation), and
[docs/TEAM-DISCUSSION-2026-08-13.md](docs/TEAM-DISCUSSION-2026-08-13.md)
(v3.9.0 harness-fusion v2: push nudges + commit-freshness Gate API + honest ship gate +
dead-sensor cull + gstack v1.62 resync + evaluator blindness + sprint-contract verify).

## Project Structure

```
.claude-plugin/plugin.json         # Plugin manifest (v3.9.0)
skills/                            # 11 user-invocable slash commands
├── harness-init/                  # Init (progressive disclosure refs)
│   ├── SKILL.md
│   ├── arch-test-python.md        # Python test skeleton
│   └── arch-test-typescript.md    # TypeScript test skeleton
├── harness-dashboard/
│   ├── SKILL.md
│   └── DEEP-DIVE.md              # Query format reference
├── <other-skills>/SKILL.md        # One dir per skill
agents/                            # 1 read-only background agent (session-observer)
hooks/                             # 7 event-driven shell scripts (canonical: hooks.json)
├── hooks.json                     # Hook event bindings
├── lib/common.sh                  # Shared utilities (incl. gstack_detect())
.claude/workflows/harness-audit.js # 1 Dynamic Workflow (rule `single-workflow`: read-only governance audit)
docs/                              # Progressive disclosure references
templates/                         # Config templates
tests/                             # Plugin self-tests
```

## Configuration (`.claude/harness.json`)

| Field | Default | Description |
|-------|---------|-------------|
| `layers` | `["types","config","repo","service","runtime","ui"]` | Layer order |
| `layer_dirs` | `{...}` | Directory-to-layer mappings |
| `sibling_layers` | `[]` | Pairs that can import each other |
| `file_size_limit` | `300` | Max lines per source file |

## Key Principles

- **"Say No to Slop"** — never lower review standards
- **"Every agent mistake is an encoding opportunity"** — Mitchell Hashimoto
- **Progressive disclosure** — CLAUDE.md is the TOC, docs/ is the encyclopedia
- **Error messages are context** — must include WHAT, WHERE, HOW, REF

## References

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)
- [gstack](https://github.com/garrytan/gstack) — complementary workflow plugin
- [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)

## License

MIT
