# Architecture

## Overview

oh-my-agents implements OpenAI's harness engineering methodology as Claude Code
skills, agents, and hooks. The harness is the set of constraints, documentation,
feedback loops, and entry points that make AI coding agents work reliably.

## Origin

Based on OpenAI's internal experiment:
- 3 engineers, ~1M lines of production code, ~1,500 PRs in 5 months
- Zero hand-written code — all agent-generated
- Key insight: "The bottleneck was never the agent's ability to write code, but the
  lack of structure, tools, and feedback mechanisms surrounding it."

## Four Pillars

### 1. Architecture as Guardrails

Mechanical enforcement of boundaries so agents can't accidentally violate rules.

- **Rigid layered architecture**: Types → Config → Repo → Service → Runtime → UI
- **Providers interface**: Cross-cutting concerns (auth, telemetry, feature flags)
  channeled through a single interface — never accessed directly
- **Custom linters with remediation in error messages** — error messages are agent context
- **Structural tests** validating layer boundaries, naming, file sizes
- **"Taste invariants"** — encoding team expertise into mechanical rules

Implemented by: `/arch-guard`, `/encode-mistake --proactive`, `arch-check.sh`

### 2. Documentation as System of Record

Making the codebase legible to agents through structured documentation.

- **CLAUDE.md as table of contents** (~100 lines, progressive disclosure)
- **docs/ as system of record** (structured, machine-readable, in-repo)
- **Structured formats > prose** (agents comply better with JSON/YAML rules)
- **No tacit knowledge** — if it's not in the repo, it doesn't exist

Implemented by: `/harness-init`, `/legibility-score`, `/spec-to-task`

### 3. Observability & Legibility

Agents and humans can see what happened, why it happened, and where the system stands.

- **Session metrics** — tool usage, layer activity, enforcement events tracked per session
- **Harness dashboard** — aggregated health overview and trend analysis
- **Shift-handoff** — the decision signals ARE the handoff: the SessionStart hook injects
  gate state + active plan into the model's context at session open (the background
  `session-observer` agent was retired v3.10.0 — zero triggers, zero readers)
- **Nested CLAUDE.md** — module-level context for agent navigation

Implemented by: `/harness-dashboard`, `/harness-dashboard --query`, `doc-drift-check.sh`
(SessionStart), `session-metrics.sh`

### 4. Entropy Management ("Garbage Collection")

Continuous detection and repair of codebase degradation.

- **"Say No to Slop"** — maintain strict review standards, never lower the bar
- **Automated scanning** — evolved from manual Friday cleanup to scheduled agent sweeps
- **Documentation drift detection** — verify docs match reality
- **Missing enforcement detection** — rules without lint/test enforcement are suggestions

Implemented by: `/entropy-sweep`, `/harness-review`, `doc-drift-check.sh`, `/encode-mistake`

## Three review/audit moments

Canonical — same slop taxonomy, different trigger. The slop check appears in three skills
by design, not duplication. They share ONE definition
([docs/LINTING.md](LINTING.md#slop-taxonomy-canonical)); pick by the moment:

| Moment | Skill | Cost / shape | When |
|--------|-------|--------------|------|
| **per-PR / pre-ship** | `/harness-review` | single-pass, low context | every change before ship |
| **weekly GC** | `/entropy-sweep` | repo-wide scan | scheduled maintenance |
| **release / governance** | `/harness-audit` (workflow) | fanned-out Explore + adversarial verify (3× recall, ~3× cost) | release gates, quarterly |

`/harness-review` and `/entropy-sweep` reference this table rather than restating it.

## Mapping to the Planner / Generator / Evaluator topology

The multi-agent harness pattern (InfoQ, 2026-04) decomposes long-running coding work
into three roles — **Planner**, **Generator**, **Evaluator** — connected by structured
handoff artifacts and context resets. As of **Feb 2026, Claude Code ships this topology
natively** as **Agent Teams** (a team-lead session coordinating peer sessions via a
shared task list + mailbox; gated behind `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`). gstack
adds the same kind of parallelism through Conductor workspaces.

As of **May 2026, Claude Code also ships native Dynamic Workflows** — a JS *script* that
deterministically fans out subagents (the script holds the plan; only `agent()` bodies are
model-powered). This is a second native coordination form, and it further commoditizes
generic orchestration: for the *delivery lifecycle* the script belongs to gstack, never us.

oh-my-agents does **not** reimplement coordination — Agent Teams and Dynamic Workflows are
platform/gstack concerns. Instead, oh-my-agents is the **per-role guardrail + evidence
layer that a team or workflow runs *inside***: it constrains the Generator (PreToolUse
hooks), supplies the Evaluator its **versioned decision-signal Gate API**
([SIGNALS.md](SIGNALS.md) — exactly the machine-readable stage boundary a Dynamic Workflow
or team-lead gates on), and persists memory between context resets (TASTE rules, nested
CLAUDE.md). The one sanctioned use of Dynamic Workflows by this plugin is a read-only audit
that *terminates in a signal* (anti-bloat rule `single-workflow`); never a delivery script.

| Role | What oh-my-agents contributes | gstack / native counterpart | Handoff artifact |
|------|-------------------------------|-----------------------------|------------------|
| **Coordination** | — (deliberately none) | **native Agent Teams** (mailbox) + **Dynamic Workflows** (script); gstack Conductor | shared task list / mailbox / script vars |
| **Planner** | `/spec-to-task` (layer-aware decomposition) | `/office-hours`, `/autoplan` | `docs/exec-plans/active/*.json` — per-task `context_files`/`failing_tests`/`constraints`/runnable `acceptance` ARE the typed handoff; on a RED verify, `/lifecycle recover` derives the retry target AT RECOVER TIME from `verify-latest.json`'s reason + the task list (no pre-declared failure maps — `planner_metadata` cut 2026-08-13, zero consumers) |
| **Generator constraints** | `arch-check`, `safety-check`, `bash-safety-check` (block); `plan-validation-check` (feedforward GUIDE) — PreToolUse hooks | `/guard` (freeze/careful) | hook block + remediation message in agent context |
| **Evaluator** | `/verify` + `/harness-review` (decision signals; `/harness-review` reads & reconciles gstack's v1.57.5+ verdict layer read-only) | `/codex`, `/cso`, `/design-review`, `/qa` | `.claude/signals/verify-latest.json`, `.claude/signals/review-latest.json` (+ `gstack_context`) |
| **Memory between resets** | nested CLAUDE.md, `docs/LINTING.md` (TASTE rules) | GBrain (`learnings-log`, `timeline-log`, `eureka`) | one-direction bridge: observation → enforcement |
| **Loop closure** | `/encode-mistake --from-gbrain` (human-gated) | `/investigate`, `/retro` | TASTE-NNN rule with `taste_id` ↔ learning-id back-reference |

**Key implication**: when adding capability, ask *which role does this serve, and is it
already served by the platform or gstack?* If coordination — defer to native Agent Teams.
If a role gstack covers — defer to gstack. oh-my-agents only owns the constraint + evidence
surfaces that are repo-local and mechanical.

## Mapping the Four Pillars to OpenAI's harness-engineering components

OpenAI's published harness-engineering writeup (openai.com, Feb 2026) names ~six
components. Our Four Pillars cover four of them directly; the other two are **delegated
to gstack by composition** rather than reimplemented. This table makes coverage —
and deliberate non-coverage — auditable:

| OpenAI component | Four-Pillar / harness home | Owner |
|------------------|----------------------------|-------|
| Architectural constraints (mechanical rules + structural tests) | Pillar 1 — Architecture as Guardrails | **oh-my-agents** (hooks, arch-guard, TASTE) |
| Documentation as System of Record | Pillar 2 — Documentation as System of Record | **oh-my-agents** (`/harness-init`, docs/) |
| Observability integration (logs/metrics/spans) | Pillar 3 — Observability & Legibility | **oh-my-agents** (session-metrics, dashboard) |
| Entropy / quality maintenance | Pillar 4 — Entropy Management | **oh-my-agents** (`/entropy-sweep`, `/encode-mistake`) |
| **Structured feedback loops** (PR / CI) | decision signals (`verify-latest.json`, `review-latest.json`) + CI template | **shared** — harness emits signals; the pre-`/ship` convention checks them (gstack-side read is `VERIFIED \| ASSERTED` per probe); CI via `templates/github-actions-harness.yml` |
| **Isolated testing** (reproduce bugs in isolation) | *not reimplemented* | **gstack** `/investigate` + `/qa` (delegated) |

The role-shift OpenAI describes — engineers move from *implementing code* to *specifying
intent and giving structured feedback* — is realized as `/spec-to-task` (intent capture)
plus the decision-signal gates (structured, machine-readable feedback that drives the
next agent turn without a human round-trip).

## Plugin Structure

```
.claude-plugin/
├── plugin.json                           # Plugin manifest
├── marketplace.json                      # Marketplace definition for distribution
skills/                                   # User-invocable slash commands (11 skills)
├── harness-init/SKILL.md                 # Initialize the harness
├── legibility-score/SKILL.md             # 10-metric readiness assessment
├── spec-to-task/SKILL.md                 # Task decomposition with execution plans
├── verify/SKILL.md                       # Post-execution verification (build/test/lint/arch)
├── encode-mistake/SKILL.md               # Convert agent mistakes into guardrails (--proactive for taste encoding)
├── arch-guard/SKILL.md                   # Set up constraint enforcement
├── entropy-sweep/SKILL.md                # Scan for entropy
├── harness-review/SKILL.md               # Harness-aware code review (auto-detects gstack for dual review)
├── harness-dashboard/SKILL.md            # Session metrics and health overview (--query for deep-dive)
├── gstack-sync/SKILL.md                  # Detect gstack, configure bridges, sync metrics
└── lifecycle/SKILL.md                    # Lifecycle router (names next phase; never executes)
                                          # (no agents/ since v3.10.0: session-observer retired —
                                          #  SessionStart gate-state injection + signals replace it;
                                          #  doc-gardening-agent retired v3.6.0)
hooks/                                    # Event hook scripts (7 hooks + shared lib)
├── hooks.json                            # Hook event bindings (${CLAUDE_PLUGIN_ROOT})
├── lib/common.sh                         # Shared utilities (JSON parsing, layer resolution,
│                                         #  project-root addressing: get_project_dir; gstack +
│                                         #  gbrain detection; emit_advisory; append_history_record)
├── arch-check.sh                         # PreToolUse (Edit|Write): layer boundary check
├── safety-check.sh                       # PreToolUse (Edit|Write): hardcoded secrets detection
├── plan-validation-check.sh             # PreToolUse (Edit|Write): exec-plan handoff GUIDE (advisory)
├── bash-safety-check.sh                  # PreToolUse (Bash): credential leak detection
├── self-verify-check.sh                  # PostToolUse (Edit|Write): syntax self-verification (py/js)
├── session-metrics.sh                    # PostToolUse (Edit|Write|Bash): JSONL activity logging
└── doc-drift-check.sh                    # Stop: drift + gate-state nudge + termination sensor;
                                          # SessionStart: gate state injected into context
docs/                                     # Template docs for target projects
├── ARCHITECTURE.md                       # Layer model, boundaries, decisions
├── CONVENTIONS.md                        # Naming, size, patterns
├── TESTING.md                            # Test strategy, structural tests
├── LINTING.md                            # Lint rule registry (TASTE-NNN)
├── DECISIONS.md                          # Architecture Decision Records
├── PROVIDERS.md                          # Cross-cutting interface definition
├── OBSERVABILITY.md                      # Logging, metrics, tracing strategy
├── WORKFLOW.md                           # Full development lifecycle
├── SIGNALS.md                            # The Gate API (decision signals, freshness, history logs)
├── INTEGRATION.md                        # gstack integration guide, bridges, anti-bloat rules
└── TEAM-DISCUSSION-*.md                  # Council decision records (system of record)
templates/                                # Starter templates for target projects
├── harness-config.json                   # .claude/harness.json template
├── execution-plan.json                   # Execution plan schema
└── github-actions-harness.yml            # CI/CD enforcement workflow
tests/                                    # Plugin self-tests
├── test-hooks.sh                         # Unit tests for all hooks
└── test-skills.sh                        # Smoke tests for skill quality
```

## Claude Code Features Used

This plugin leverages specific Claude Code capabilities:

| Feature | Where Used | Why |
|---------|-----------|-----|
| `.claude-plugin/plugin.json` | Plugin root | Standard plugin manifest for install/update |
| `marketplace.json` | Plugin root | Distribution via `/plugin marketplace add` |
| `${CLAUDE_PLUGIN_ROOT}` | hooks.json, hook scripts | Portable path resolution within plugin |
| `allowed-tools` | legibility-score, harness-review, entropy-sweep | Enforce read-only behavior for review/scan skills |
| Hook JSON output (`hookSpecificOutput.additionalContext`, `systemMessage`) | `emit_advisory` in lib/common.sh | Advisory nudges reach the MODEL (stderr at exit 0 reaches nobody) |
| `PreToolUse` hooks | arch-check.sh | Block layer violations before Edit/Write |
| `Stop` hooks | doc-drift-check.sh | Advisory drift + gate state + termination sensor after each turn |
| `SessionStart` hooks | doc-drift-check.sh | Gate state + active plan injected at session open |
| Built-in `Explore` subagent | /harness-review blind judge, harness-audit.js | Read-only, fresh-context Evaluator with no agent file of ours |
| `$ARGUMENTS` | All skills | Pass user arguments to skill content |
| Decision signals (`.claude/signals/`) | verify, harness-review | Versioned Gate API consumed by `/lifecycle`, the pre-ship convention check, Dynamic Workflow stages, Agent Teams (gstack `/ship` reads none of it — VERIFIED v1.79) |
| Dynamic Workflows (`.claude/workflows/`) | `harness-audit.js` (1 shipped; rule `single-workflow`) | Native deterministic fan-out; read-only `Explore` audit that RETURNS a signal (accountable invoker persists it) |

## Design Decisions

### Hook addressing: the project root is resolved, never assumed

A hook's stdin carries `.cwd`, but Claude Code's Bash tool keeps cwd across calls by design,
so `.cwd` means "wherever the last `cd` left the session" — in a monorepo, one
`cd backend && pytest` and it is `backend/` for the rest of the session. Taking it as the
project root failed twice over, both times silently: the metrics ledger forked per directory
(records intact, but not where `/harness-dashboard` reads), and `doc-drift-check` compared
repo-root-relative `git diff` output against cwd-relative paths, so those comparisons could
never match while the hook still exited 0.

`get_project_dir()` (`hooks/lib/common.sh`) is the single addressing order:

| Tier | Source | `PROJECT_DIR_SOURCE` | Authoritative |
|------|--------|----------------------|---------------|
| 1 | `$CLAUDE_PROJECT_DIR` | `env` | yes |
| 2 | git toplevel of `.cwd` | `git` | yes |
| 3 | walk up from the edited file to a VCS root | `git` | yes |
| 3 | walk up to `.claude/` or a build manifest | `marker` | no |
| 4 | nothing | `""` | — (caller exits 0 **and says so**) |

Two rules follow. **Creation is a consequence of knowing the root**: `resolve_metrics_dir`
appends to an existing ledger anywhere, but creates a missing one only under an
authoritative root — a build manifest marks a monorepo *package*, not a project, so it never
earns a new `.claude/`. **One path system**: every path comparison is repo-root-relative,
the shape `git -C ROOT diff --name-only` natively emits. `doc-drift-check` therefore keeps
`PROJECT_DIR` (harness root — `.claude/signals`, `.claude/metrics`) and `REPO_ROOT` (git
toplevel — every scan and comparison) as separate names, and never mixes them in one test.

The build root is a different question and keeps its own helper: `find_build_root()` returns
the nearest build manifest, because `tsc`/`cargo` must run in `backend/`, exactly where the
ledger must not.

### No agents of our own (since v3.10.0)

Both background agents this plugin once shipped were retired on evidence: doc-gardening
(v3.6.0 — the Stop hook + `/entropy-sweep` covered it) and session-observer (v3.10.0 —
zero mechanical triggers, zero readers of its memory after a binding consume-or-cut;
its shift-handoff job is done by the decision signals plus SessionStart context injection).
Where a read-only, fresh-context judge is needed (`/harness-review` blindness,
`/harness-audit`), the built-in `Explore` subagent is used — a native primitive, no
agent file to maintain. This is rule `ablate-per-model` in practice.

### Shell-based hooks

Shell hooks are portable across project types and run deterministically outside the
LLM. Error messages from hooks inject remediation instructions into agent context,
following OpenAI's pattern of "custom linter error messages that double as
remediation instructions."

### Progressive disclosure (implementation practice, not a differentiator)

CLAUDE.md is the table of contents (~60 lines); docs/ contains the full details.
OpenAI found that one massive instruction file failed — context is scarce and crowds
out actual task details. **Note:** gstack v1.46–1.79 converged onto on-demand content
loading (25–49% token cut; "carved skills" = skeleton + on-demand `sections/`), so
progressive disclosure is now table stakes both platforms ship — we keep the practice but
no longer claim it as a moat. The moat is the repo-local edit-time mechanical enforcement
(hooks/arch-guard/TASTE) + the versioned signal Gate API.
