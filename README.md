# oh-my-agents

Claude Code skills, agents, and hooks implementing OpenAI's **Harness Engineering** —
the discipline of designing environments, constraints, and feedback loops that make AI
coding agents work reliably at scale.

Based on OpenAI's experiment: 3 engineers shipped ~1M lines of production code via
~1,500 PRs in 5 months with zero hand-written code, using 88 nested AGENTS.md files
across their codebase.

## The Four Pillars

| Pillar | What It Means | This Plugin |
|--------|---------------|-------------|
| **Architecture as Guardrails** | Mechanical layer enforcement + Providers pattern | `arch-guard`, `taste-encoder`, hooks |
| **Documentation as System of Record** | Everything agents need lives in the repo | `harness-init`, `legibility-score`, `spec-to-task` |
| **Observability & Legibility** | Agents and humans can see what happened and verify work | `verify`, `harness-dashboard`, `harness-metrics`, session metrics |
| **Entropy Management** | Continuous resistance to codebase degradation | `entropy-sweep`, `harness-review`, `encode-mistake` |

## Project Structure

```
.claude-plugin/
├── plugin.json                    # Plugin manifest (name, version, paths)
├── marketplace.json               # Marketplace definition for distribution
skills/                            # User-invocable slash commands
├── harness-init/SKILL.md          # Initialize: CLAUDE.md, docs/, bootstrap, entry points
├── legibility-score/SKILL.md      # 10-metric Agent Legibility Score (0-30)
├── spec-to-task/SKILL.md          # Convert specs into agent-ready tasks (auto-imports gstack design docs)
├── verify/SKILL.md                # Post-execution check + gstack readiness signal
├── encode-mistake/SKILL.md        # Convert agent mistakes into permanent lint/hook rules
├── arch-guard/SKILL.md            # Set up layer enforcement + Providers pattern
├── taste-encoder/SKILL.md         # Encode expertise into lint rules & structural tests
├── entropy-sweep/SKILL.md         # Scan for slop, doc drift, dead code, violations
├── harness-review/SKILL.md        # Code review with "Say No to Slop"
├── harness-dashboard/SKILL.md     # Session metrics, plan progress, harness + gstack health
├── harness-metrics/SKILL.md       # Deep-dive metric queries and analysis
├── gstack-sync/SKILL.md           # gstack integration hub: detect, configure, sync metrics
├── unified-review/SKILL.md        # Dual-system review: harness + structural in one pass
└── lifecycle/SKILL.md             # Full lifecycle orchestrator: guides through all phases
agents/                            # Read-only background subagents (with memory: project)
├── arch-guard-agent.md            # Architectural compliance checker
├── entropy-sweep-agent.md         # Entropy scanner
├── harness-reviewer.md            # Code review agent
├── session-observer-agent.md      # Session tracking and shift-handoff (Haiku)
├── doc-gardening-agent.md         # Documentation gardening and drift repair (Haiku)
└── gstack-bridge-agent.md         # Cross-system artifact health monitoring (Haiku)
hooks/                             # Event hook scripts
├── hooks.json                     # Hook event bindings (uses ${CLAUDE_PLUGIN_ROOT})
├── lib/common.sh                  # Shared utilities (JSON parsing, layer detection, sibling layers)
├── arch-check.sh                  # Block Edit/Write on layer violations or Providers bypass
├── safety-check.sh                # Block Edit/Write on hardcoded secrets
├── bash-safety-check.sh           # Block Bash commands with credential leaks
├── self-verify-check.sh           # Warn on type/syntax errors after edit (TS, Py, JS, Rust, Go)
├── session-metrics.sh             # Record tool usage + hook effectiveness to .claude/metrics/ (JSONL)
└── doc-drift-check.sh             # Warn about documentation drift after session ends
tests/                             # Plugin self-tests
├── test-hooks.sh                  # 47 unit tests for all hooks and shared library
└── test-skills.sh                 # 168 smoke tests for skill frontmatter, structure, quality
docs/                              # Template documentation for target projects
├── ARCHITECTURE.md                # Layer model, module boundaries, design decisions
├── CONVENTIONS.md                 # Naming, file size, error handling, logging patterns
├── TESTING.md                     # Test strategy, structural tests, coverage rules
├── LINTING.md                     # Custom lint rules registry (TASTE-NNN)
├── DECISIONS.md                   # Architecture Decision Records (ADRs)
├── PROVIDERS.md                   # Cross-cutting: auth, telemetry, feature flags interface
├── OBSERVABILITY.md               # Logging, metrics, tracing, monitoring strategy
└── WORKFLOW.md                    # Full dev lifecycle (oh-my-agents + gstack integration)
templates/                         # Configuration templates for target projects
├── harness-config.json            # .claude/harness.json starter template
├── execution-plan.json            # docs/exec-plans/ execution plan template
└── github-actions-harness.yml     # CI/CD workflow: lint + type-check + arch-guard + tests
```

## Installation

### Via Claude Code Plugin System (Recommended)

```bash
# Add the marketplace
/plugin marketplace add caishize/oh-my-agents

# Install the plugin
/plugin install oh-my-agents
```

After installation, all skills are available with the `oh-my-agents:` namespace:

```
/oh-my-agents:harness-init
/oh-my-agents:legibility-score
/oh-my-agents:verify
...
```

### Manual Installation (copy to .claude/)

```bash
git clone https://github.com/caishize/oh-my-agents.git

# Copy all skills
cp -r oh-my-agents/skills/ /path/to/your-project/.claude/skills/

# Copy all agents
mkdir -p /path/to/your-project/.claude/agents
for f in oh-my-agents/agents/*.md; do
  name=$(basename "$f" .md)
  mkdir -p /path/to/your-project/.claude/agents/"$name"
  cp "$f" /path/to/your-project/.claude/agents/"$name"/AGENT.md
done

# Copy hooks
cp -r oh-my-agents/hooks/ /path/to/your-project/.claude/hooks/
```

## Skills

### `/harness-init` — Initialize the Harness

Set up the full harness environment in 9 steps: root CLAUDE.md as table of contents
(~100 lines), nested CLAUDE.md for every module with 5+ files, structured docs/ directory,
machine-readable `.claude/harness.json`, bootstrap script, pre-commit enforcement, and
architecture test skeleton.

**Quick start**: `/harness-init --quick` runs init + legibility-score + arch-guard in one command.

### `/legibility-score` — Agent Legibility Score

Assess the **10-metric readiness score** (0-30) across four pillars:

| # | Metric | Pillar |
|---|--------|--------|
| 1 | Bootstrap self-sufficiency | Architecture |
| 2 | Task entry points (build/test/lint/run) | Architecture |
| 3 | Validation harness | Architecture |
| 4 | Linting & formatting | Architecture |
| 5 | Codebase map (CLAUDE.md) | Documentation |
| 6 | Documentation structure (docs/) | Documentation |
| 7 | Decision records (ADRs) | Documentation |
| 8 | App bootstrap | Observability |
| 9 | Runtime logs | Observability |
| 10 | Nested CLAUDE.md coverage | Observability |

Score interpretation: 0-10 (not ready), 11-20 (struggling), 21-25 (agent-ready), 26-30 (excellent).

### `/spec-to-task` — Planning Before Execution

Decompose specs into agent-executable tasks with **tests first**, layer-aware
decomposition (Types → Config → Repo → Service → Runtime → UI), explicit context arrays,
and acceptance criteria. Produces a JSON execution plan for shift-handoff and a Markdown
companion for humans.

### `/verify` — Post-Execution Verification

Implements the **Verify** phase of OpenAI's Research → Plan → Execute → Verify cycle.
Runs lint → build → test → architecture guard in order, reports structured pass/fail
results, maps to plan acceptance criteria, and recommends `/encode-mistake` for recurring
failures.

```
=== Verify Report ===
  LINT     PASS     0 errors, 2 warnings
  BUILD    PASS     Compiled in 4.2s
  TEST     FAIL     47 passed, 3 failed
  ARCH     PASS     No violations
Overall: RED (1 check failed)
```

### `/encode-mistake` — Mistake → Permanent Guardrail

> "Every agent mistake is an encoding opportunity." — Mitchell Hashimoto

Converts incidents into permanent TASTE rules: lint rules, structural tests, hook
patterns, or improved error messages. Complements `/taste-encoder` (proactive taste
encoding) with reactive learning from actual failures.

**Difference:**
- `/taste-encoder` — "I dislike this pattern; encode it" (proactive)
- `/encode-mistake` — "This just broke; ensure it never happens again" (reactive)

### `/taste-encoder` — Encode Your Taste (Proactive)

Turn team expertise into custom lint rules, structural tests, or pre-commit hooks.
Each expert's knowledge becomes a multiplier for the entire agent fleet.

Real example from OpenAI: Codex kept creating duplicate concurrency helpers, but only
one version had OpenTelemetry. Fix: a custom ESLint rule banning that function outside
the approved location.

### `/arch-guard` — Architectural Constraints

Set up the rigid layered architecture: Types → Config → Repo → Service → Runtime → UI.
Plus the Providers pattern for cross-cutting concerns (auth, telemetry, feature flags).
Creates custom linters with **remediation instructions in error messages** (error
messages double as agent context). Supports **sibling layers** for horizontal imports
between same-level modules (configurable via `sibling_layers` in `.claude/harness.json`).

### `/entropy-sweep` — Garbage Collection

Evolved from OpenAI's manual Friday "slop cleanup" to automated agent scanning. Detects:
- **Slop**: duplicates, pattern drift, copy-paste artifacts, security slop
- **Doc drift**: commands that don't work, dead file references
- **Violations**: layer crossings, Providers bypass
- **Dead weight**: unused exports, deps, orphaned files, stale TODOs
- **Missing enforcement**: rules in docs/ without lint/test backing
- **Stale plans**: execution plans with no updates in N+ days (configurable via `plan_stale_days`)

### `/harness-review` — Say No to Slop

Code review based on OpenAI's top principle: **"Maintain strict review standards.
Lowering the bar creates compounding technical debt."** Bad patterns multiply via every
future agent-generated PR. Checks slop first, then safety, then architecture, then
plan alignment.

### `/harness-dashboard` + `/harness-metrics` — Observability

Dashboard aggregates session metrics, enforcement activity, and plan progress.
Now includes gstack metrics fusion: skill usage, dual review rates, lifecycle coverage.
Metrics allows deep-dive queries: layer balance, violation trends, plan velocity.

### `/gstack-sync` — Integration Hub

Detect gstack installation, configure artifact bridges, and sync metrics between
oh-my-agents and gstack. Run `/gstack-sync --status` to check integration health,
`--setup` for first-time configuration, or `--metrics` for cross-system reporting.

### `/unified-review` — Dual-System Code Review

Orchestrate both gstack's structural review and oh-my-agents' four-pillar review in
a single pass. Deduplicates findings, cross-validates issues (both systems flagging
the same issue escalates severity), and produces a unified report with actionable verdict.

### `/lifecycle` — Full Lifecycle Orchestrator

Guides through the complete development lifecycle: Ideate → Plan → Decompose → Execute →
Verify → Review → Ship → Deploy → Retro → Improve. Adapts to installed plugins,
auto-detects the next phase from artifacts, and ensures proper handoffs.

```
/lifecycle next       # Auto-detect and execute next phase
/lifecycle status     # Show current progress across all phases
/lifecycle decompose  # Start specific phase
```

## Agents (Background, Read-Only)

All agents have Write/Edit disabled — they report but never modify code.

| Agent | Dispatched when... |
|-------|---------------------|
| `arch-guard-agent` | Code changes might violate layers or boundaries |
| `entropy-sweep-agent` | Periodic scan or pre-release check requested |
| `harness-reviewer` | PR or staged changes need review |
| `session-observer-agent` | Session ends — writes shift-handoff summary to memory |
| `doc-gardening-agent` | Periodic doc scan — dead refs, stale commands, contradictions |
| `gstack-bridge-agent` | Cross-system artifact health: stale handoffs, metric drift, lifecycle gaps |

## Hooks (Automatic Enforcement)

| Hook | Trigger | Behavior |
|------|---------|----------|
| `arch-check.sh` | Before Edit/Write | **Blocks** layer violations, Providers bypass; supports sibling layers |
| `safety-check.sh` | Before Edit/Write | **Blocks** hardcoded secrets (inline comment stripping, fast-exit for non-code) |
| `bash-safety-check.sh` | Before Bash | **Blocks** credential leaks in bash commands |
| `self-verify-check.sh` | After Edit/Write | **Warns** on type/syntax errors (TypeScript, Python, JS, Rust, Go) |
| `session-metrics.sh` | After Edit/Write/Bash | Records tool usage + hook effectiveness to JSONL (flock for parallel safety) |
| `doc-drift-check.sh` | Session end | **Warns** if source changes may need doc updates |

## Workflow

Full lifecycle details: [docs/WORKFLOW.md](docs/WORKFLOW.md)

### One-Time Setup

```
/harness-init --quick  # All-in-one: init + legibility-score + arch-guard
# Or step by step:
/harness-init          # CLAUDE.md, docs/, bootstrap, harness.json, pre-commit
/legibility-score      # Assess readiness (0-30) — find gaps
/arch-guard            # Layer enforcement + Providers pattern
```

### Full Lifecycle (with [gstack](https://github.com/garrytan/gstack) installed)

oh-my-agents and gstack are deeply complementary — gstack covers ideation, planning,
QA, and shipping; oh-my-agents covers architectural enforcement, entropy management, and
rule encoding. With v3.0, they share structured artifacts (design docs, review logs,
metrics) in addition to conversation context.

```
/gstack-sync --setup            # One-time: configure artifact bridges
/lifecycle next                 # Auto-guided (recommended)
# OR manually:
/office-hours                   # Brainstorm & design doc (gstack)
/autoplan                       # Auto-review: CEO → Design → Eng (gstack)
/spec-to-task                   # Layer-aware execution plan (auto-imports design doc)
# ... develop with automatic hook enforcement (both systems) ...
/verify                         # Build + test + lint + arch + gstack readiness
/unified-review                 # Dual review: harness + structural in one pass
/ship                           # Version, changelog, PR (gstack)
/land-and-deploy                # Merge → deploy → canary verify (gstack)
/retro + /harness-dashboard     # Combined velocity + governance metrics
/encode-mistake                 # Convert any failures to permanent rules
```

### Daily Development Cycle (oh-my-agents only)

```
/spec-to-task <feature-spec>    # Decompose: tests first, layer-aware, explicit context
# ... agent implements tasks ...
/verify                          # Build + test + lint + arch — structured results
/harness-review                  # Say No to Slop — final check before merge
```

### When Agents Make Mistakes

```
/encode-mistake "agent imported from wrong layer again"
# → permanent hook pattern or lint rule (TASTE-NNN)
# → documented in docs/LINTING.md
# → never happens again
```

### Weekly / Pre-Release

```
/entropy-sweep          # Full scan: slop, drift, violations, dead code, stale plans
/retro                  # Engineering velocity retrospective (gstack, if installed)
/harness-dashboard      # Harness health overview
```

### Team Knowledge Encoding (Ongoing)

```
/taste-encoder "no direct DB queries outside repo layer"
/taste-encoder "all API responses use ResponseEnvelope<T>"
/taste-encoder "max 300 lines per file"
```

Each team member's expertise becomes a lint rule or structural test that all agents
inherit. Designate an **Agent Captain** per team (OpenAI's recommendation) to manage
the encoding process.

## CI/CD Integration

Copy `templates/github-actions-harness.yml` to `.github/workflows/harness.yml` in your
project for three-tier enforcement on every PR:
1. Lint & format (fastest — style violations)
2. Type check (type errors)
3. Architecture guard (TASTE/ARCH structural tests)
4. Tests (full suite)

## Testing

Run the plugin's self-test suites:

```bash
# Hook tests (47 tests): arch-check, safety-check, bash-safety-check,
# self-verify-check, session-metrics, doc-drift-check, and shared library
bash tests/test-hooks.sh

# Skill smoke tests (168 tests): frontmatter validation,
# file size, description quality, i18n, structural integrity, cross-references
bash tests/test-skills.sh
```

215 total tests covering all hooks and all 14 skills.

## Configuration (`.claude/harness.json`)

| Field | Default | Description |
|-------|---------|-------------|
| `layers` | `["types","config","repo","service","runtime","ui"]` | Canonical layer order |
| `layer_dirs` | `{...}` | Glob patterns mapping directories to layers |
| `sibling_layers` | `[]` | Layer pairs that can import each other, e.g. `["service:runtime"]` |
| `providers_path` | `null` | Path to Providers interface (enables bypass detection) |
| `file_size_limit` | `300` | Max lines per source file |
| `nested_claude_md_threshold` | `5` | Min files in a directory to require CLAUDE.md |
| `plan_stale_days` | `7` | Days before an execution plan is flagged as stalled |

## Key Principles from OpenAI

- **"Agents have no tacit knowledge; until it is made explicit, it doesn't exist"**
- **"If you can articulate what code you dislike, write that down"** — as a lint rule
- **"Say No to Slop"** — never lower review standards, even to ship faster
- **"When the agent struggles, treat it as an environment design problem"**
- **"Every agent mistake is an encoding opportunity"** — Mitchell Hashimoto
- **"If you over-engineer the control flow, the next model update will break your system"** — build rippable harnesses
- **Progressive disclosure** — CLAUDE.md is the TOC, docs/ is the encyclopedia
- **Structured formats > prose** — agents comply better with JSON/YAML rules
- **Error messages are context** — lint errors must include WHAT, WHERE, HOW, REF
- **JSON > Markdown for tracking** — agents less frequently overwrite structured data
- **Speed increases communication need** — faster AI output requires more human check-ins
- **Self-verification** — agents must confirm their own changes work before requesting review

## References

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)
- [gstack: Garry Tan's Claude Code Setup](https://github.com/garrytan/gstack) — complementary workflow plugin
- [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [NxCode: Complete Guide to Harness Engineering](https://www.nxcode.io/resources/news/harness-engineering-complete-guide-ai-agent-codex-2026)
- [The Emerging Harness Engineering Playbook](https://www.ignorance.ai/p/the-emerging-harness-engineering)
