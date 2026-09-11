# oh-my-agents `v3.10.0`

Lean Claude Code plugin implementing **Harness Engineering** — the discipline of
designing environments, constraints, and feedback loops that make AI coding agents
work reliably at scale. **Composition-based** integration with
[gstack](https://github.com/garrytan/gstack.git) (v1.46+ floor, v1.79.0.0 current — source-verified) for
full-lifecycle coverage (slop-deep, security-deep, and UX audits delegated to gstack;
GBrain memory + the always-on `timeline.jsonl` consumed as read-only sensors; gstack's own
content-addressed review verdicts **reconciled** read-only by `/harness-review`; architecture,
entropy, legibility, and the **decision-signal Gate API** owned by oh-my-agents).

**Differentiation anchor**: with Managed Agents, the OpenAI Agents SDK, native **Agent
Teams**, and native **Dynamic Workflows** all commoditizing generic orchestration, this
plugin doubles down on what is *irreplaceable* — repo-local mechanical constraints (hooks
+ arch-guard + TASTE rules) and a **versioned decision-signal Gate API**
([docs/SIGNALS.md](docs/SIGNALS.md)) that every executor gates on. We **never** orchestrate
delivery; gstack does that. `/lifecycle` NAMES the next skill, never invokes it. (Progressive
disclosure is an implementation practice gstack now ships too — kept, but not the moat.)

> **11 skills · 7 hooks · 0 agents · 1 audit workflow** — minimal context-window footprint; a Gate API, not an orchestrator.

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

None (since v3.10.0). `session-observer-agent` was retired under its own binding
consume-or-cut (zero mechanical triggers, zero readers of its memory): shift-handoff is
the decision signals plus the **SessionStart** hook injecting gate state + active plan into
the model's context at session open. `doc-gardening-agent` was retired in v3.6.0 (covered
by `doc-drift-check` + `/entropy-sweep`). Where a fresh-context, read-only judge is needed,
the built-in `Explore` subagent is used — no agent file of ours to maintain.

## Hooks

**Canonical list: [`hooks/hooks.json`](hooks/hooks.json)** (7 scripts). One line each:
`arch-check` (blocks layer violations) · `safety-check` (blocks secrets) ·
`plan-validation-check` (exec-plan GUIDE + status-enum + plan-completion nudge) ·
`bash-safety-check` (blocks credential leaks) · `self-verify-check` (post-edit py/js syntax
warn; heavy tsc/cargo path deleted v3.10.0) · `session-metrics` (JSONL activity log) ·
`doc-drift-check` (**Stop**: doc drift + gate-state nudge + 3-RED termination sensor;
**SessionStart**: gate state + active plan injected into the model's context).

**Advisory channel (v3.10.0)** — advisory hooks emit ONE JSON envelope on stdout via
`emit_advisory` (`hookSpecificOutput.additionalContext` for the model on
PreToolUse/PostToolUse/SessionStart; `systemMessage` for the user, load-bearing at Stop).
Through v3.9 the nudges went to stderr at exit 0, which reaches neither the model nor a
parsed envelope. Invariants: zero bytes when there is nothing to say, ≤400 chars of injected
text, silent inside gstack-spawned subagents (`GSTACK_SESSION_KIND=spawned`), never
`permissionDecision`. Blocking hooks keep exit 2 + stderr. Timeouts obey rule
`hook-latency-budget` (CI-asserted).

**Addressing (v3.9.1)** — every hook resolves the project root through
`get_project_dir()` in [`hooks/lib/common.sh`](hooks/lib/common.sh), in one fixed order:
`$CLAUDE_PROJECT_DIR` → git toplevel of the input's `.cwd` → a VCS/`.claude`/build-manifest
walk up from the edited file → **empty**. Never the raw `.cwd` (which is only "wherever the
last `cd` left the session") and never `$(pwd)`. On empty a hook says so and exits 0 — a
check that established nothing must not read as a check that passed. Creating
`.claude/metrics` follows from *knowing* the root: an existing ledger is always appended to,
a missing one is created only under an authoritative root, so the ledger cannot fork
per-directory. Skills that write into `.claude/` (signals, metrics) anchor on the same
lib's `harness_root()` for the same reason — a signal written to `backend/.claude/signals/`
is one no consumer looks for, and under the Gate API's default-deny rule that reads as
*absent*, not as *OK*.

## Dynamic Workflows

| Workflow | Purpose |
|----------|---------|
| `/harness-audit` | Read-only four-pillar **governance audit** — fan-out `Explore` agents (cannot write) + adversarial verification; **returns** a `review-latest.json`-shaped decision (the accountable invoker persists it — never a relay write). Use for release/quarterly audits (the A/B spike found 3× the recall of a single pass, zero overlap); use `/harness-review` for PR validation. Requires native Dynamic Workflows (Claude Code v2.1.154+). **Project-local** to this repository (`.claude/workflows/`): plugin-level workflow distribution is an unverified watch item — installers copy nothing; they get it when the platform ships distribution. |

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
  REQUEST_CHANGES | NEEDS_HUMAN`. `NEEDS_HUMAN` carries `needs_human_kind`
  (`composition-skipped` auto-recovers; `arch-ambiguity` / `judgment-slop` halt) — compresses
  "未决态" so the flow no longer waits on a human for a recoverable skip. The
  `reviews.jsonl` history line carries typed **`findings[]`** (`fingerprint`/`severity`/`fix`)
  so a `REQUEST_CHANGES` hands the next Generator turn a work list, not a count.
- **Freshness = commit + clean tree (v3.10)** — at the three ADVANCE points (pre-ship check,
  `/lifecycle --auto`, audit persist) a signal is fresh only if `commit == HEAD` AND the
  working tree has no uncommitted source (`worktree_dirty`); the Stop hook's `APPROVE`
  nudge WARNs on a dirty tree instead of naming `/ship`.
- **Termination sensor** — three consecutive `RED` verify records with the same `reason`
  make the Stop hook name `/investigate` / `/encode-mistake` instead of another `/verify`.
- `/harness-review` composes gstack's `/codex` (cross-model slop), `/cso` (security),
  `/design-review` (UI) — tags `[HARNESS]`/`[STRUCTURAL]`/`[CROSS-MODEL]`/`[SECURITY]`/`[UX]`/`[BOTH+]`
- `/investigate` (gstack) → `/encode-mistake` (oh-my-agents) closes the feedback loop permanently
- **GBrain memory** → `/encode-mistake --from-gbrain [learning|eureka|retro|all]` — uses
  `gbrain` CLI when present, else `~/.gstack-brain-worktree/` (env `GSTACK_BRAIN_WORKTREE`),
  else `projects/<slug>/learnings.jsonl` — one detection (`gbrain_detect()`); the
  `gstack-artifacts-worktree` name probed through v3.9 has zero hits in gstack v1.79 and is
  CI-grepped out. Always **human-gated** (ETH Zurich 2026: auto-generated rules hurt).
- **gstack `timeline.jsonl` (always-on) + `.gstack/{deploy,canary}-reports/*.md` →
  `/harness-dashboard`** — lifecycle coverage and DORA `[proxy]` rows from data that exists
  (`.gstack/landing-reports/` never existed; `skill-usage.jsonl` is telemetry-gated)
- **gstack `bin/gstack-verify-gate` ← our CLAUDE.md** — `/harness-init` exports
  `<!-- gstack:verify: <confirmed test cmd> -->` (ours→gstack; opt-in, `--trust`-gated on
  gstack's side) so a failing test blocks the turn with the failure in the agent's context
- `/lifecycle` is a **router** with Gate Failure Routing — names the exact remediation
  skill on every failed gate; never re-implements a phase
- Worktree-aware: honors both `.gstack-worktrees/` and `~/conductor/workspaces/` (v1.11+)
- Lightweight contract drift check on every `/gstack-sync --status`, plus a mechanical
  `CONTRACT-CHECK OVERDUE` nudge when the recorded quarter is behind the clock (gstack went
  v1.62 → v1.79 in three weeks; drift is the norm)
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
dead-sensor cull + gstack v1.62 resync + evaluator blindness + sprint-contract verify), and
[docs/TEAM-DISCUSSION-2026-09-04.md](docs/TEAM-DISCUSSION-2026-09-04.md)
(v3.10.0 harness-fusion v3: source-verified gstack v1.79 resync + slug/GSTACK_HOME identity fix
+ advisory channel that reaches the model + SessionStart gate state + termination sensor +
dirty-tree freshness + typed findings + Q4 cut of session-observer/handoff/--metrics +
constitution enforced in CI).

## Project Structure

```
.claude-plugin/plugin.json         # Plugin manifest (v3.10.0)
skills/                            # 11 user-invocable slash commands
├── harness-init/                  # Init (progressive disclosure refs)
│   ├── SKILL.md
│   ├── arch-test-python.md        # Python test skeleton
│   └── arch-test-typescript.md    # TypeScript test skeleton
├── harness-dashboard/
│   ├── SKILL.md
│   └── DEEP-DIVE.md              # Query format reference
├── <other-skills>/SKILL.md        # One dir per skill
hooks/                             # 7 event-driven shell scripts (canonical: hooks.json)
├── hooks.json                     # Hook event bindings (PreToolUse/PostToolUse/Stop/SessionStart)
├── lib/common.sh                  # Shared utilities (gstack_detect, gbrain_detect, emit_advisory, append_history_record)
.claude/workflows/harness-audit.js # 1 Dynamic Workflow (rule `single-workflow`: read-only governance audit; project-local)
docs/                              # Progressive disclosure references (SIGNALS.md = the Gate API)
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
