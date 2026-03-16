# oh-my-agents

Claude Code skills, agents, and hooks implementing OpenAI's **Harness Engineering** —
the discipline of designing environments, constraints, and feedback loops that make AI
coding agents work reliably.

Based on OpenAI's experiment: 3 engineers shipped ~1M lines of production code via
~1,500 PRs in 5 months with zero hand-written code.

## The Three Pillars

| Pillar | What It Means | This Plugin |
|--------|---------------|-------------|
| **Context Engineering** | Structured docs that give agents the right info | `harness-init`, `legibility-score` |
| **Architectural Constraints** | Mechanical enforcement of boundaries | `arch-guard`, `taste-encoder`, agents, hooks |
| **Entropy Management** | Continuous detection of codebase degradation | `entropy-sweep`, `harness-review` |

## Project Structure

```
.claude-plugin/
├── plugin.json                   # Plugin manifest (name, version, paths)
├── marketplace.json              # Marketplace definition for distribution
skills/                           # User-invocable slash commands
├── harness-init/SKILL.md         # Initialize: CLAUDE.md, docs/, bootstrap, entry points
├── legibility-score/SKILL.md     # 7-metric Agent Legibility Score assessment
├── taste-encoder/SKILL.md        # Encode expertise into lint rules & structural tests
├── arch-guard/SKILL.md           # Set up layer enforcement + Providers pattern
├── entropy-sweep/SKILL.md        # Scan for slop, doc drift, dead code, violations
├── harness-review/SKILL.md       # Code review with "Say No to Slop"
└── spec-to-task/SKILL.md         # Convert specs into agent-friendly tasks
agents/                           # Read-only background subagents (with memory: project)
├── arch-guard-agent.md           # Architectural compliance checker
├── entropy-sweep-agent.md        # Entropy scanner
└── harness-reviewer.md           # Code review agent
hooks/                            # Event hook scripts
├── hooks.json                    # Hook event bindings (uses ${CLAUDE_PLUGIN_ROOT})
├── arch-check.sh                 # Block Edit/Write on layer violations
└── doc-drift-check.sh            # Warn about documentation drift after changes
docs/                             # Template documentation for target projects
├── ARCHITECTURE.md               # Layer model, module boundaries, design decisions
├── CONVENTIONS.md                # Naming, file size, error handling, logging patterns
├── TESTING.md                    # Test strategy, structural tests, coverage rules
├── LINTING.md                    # Custom lint rules registry (TASTE-NNN)
├── DECISIONS.md                  # Architecture Decision Records (ADRs)
└── PROVIDERS.md                  # Cross-cutting: auth, telemetry, feature flags interface
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
/oh-my-agents:entropy-sweep
...
```

### Manual Installation (copy to .claude/)

If you prefer the standalone approach, copy individual components:

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

Set up the full harness environment: CLAUDE.md as table of contents (~100 lines),
structured docs/ directory, bootstrap script, and task entry points (build/test/lint/run).

### `/legibility-score` — Agent Legibility Score

Assess the 7-metric readiness score from OpenAI's framework:
1. Bootstrap self-sufficiency (single setup command)
2. Task entry points (build, test, lint, run)
3. Validation harness (can agent verify its own changes?)
4. Linting & formatting (with auto-fix)
5. Codebase map (CLAUDE.md as progressive-disclosure TOC)
6. Documentation structure (docs/ as system of record)
7. Decision records (ADRs with rationale)

Score 0-21. Tells you exactly where to invest in your harness.

### `/taste-encoder` — Encode Your Taste

OpenAI's key insight: **"If you can articulate what code you dislike, write that down."**
Turn team expertise into custom lint rules, structural tests, or pre-commit hooks.
Each expert's knowledge becomes a multiplier for the entire agent fleet.

Real example: Codex kept creating duplicate concurrency helpers, but only one version
had OpenTelemetry. Fix: a custom ESLint rule banning that function outside the approved
location.

### `/arch-guard` — Architectural Constraints

Set up the rigid layered architecture: Types → Config → Repo → Service → Runtime → UI.
Plus the Providers pattern for cross-cutting concerns (auth, telemetry, feature flags).
Creates custom linters with **remediation instructions in error messages** (error messages
are agent context).

### `/entropy-sweep` — Garbage Collection

Evolved from OpenAI's manual Friday "slop cleanup" to automated agent scanning. Detects:
- **Slop**: duplicates, pattern drift, copy-paste artifacts
- **Doc drift**: commands that don't work, dead file references
- **Violations**: layer crossings, Providers bypass
- **Dead weight**: unused exports, deps, orphaned files
- **Missing enforcement**: rules without lint/test backing

### `/harness-review` — Say No to Slop

Code review based on OpenAI's top principle: **"Maintain strict review standards. Lowering
the bar creates compounding technical debt."** Bad patterns multiply via every future
agent-generated PR. Reviews for slop first, then architecture, then code quality.

### `/spec-to-task` — Planning Before Execution

Decompose specs into agent-executable tasks with **tests first** (write failing tests
before implementation), layer-aware decomposition, explicit context, and acceptance
criteria. Based on OpenAI's finding that separating planning and execution phases
prevents wasted agent effort.

## Agents (Background, Read-Only)

All agents have Write/Edit disabled — they report but never modify code.

| Agent | Dispatched by Claude when... |
|-------|-------------------------------|
| `arch-guard-agent` | Code changes might violate layers or boundaries |
| `entropy-sweep-agent` | Periodic scan or pre-release check requested |
| `harness-reviewer` | PR or staged changes need review |

## Hooks (Automatic)

| Hook | Trigger | Behavior |
|------|---------|----------|
| `arch-check.sh` | Before Edit/Write | **Blocks** if edit violates layer boundary |
| `doc-drift-check.sh` | After Claude stops | **Warns** if source changes may need doc updates |

## Workflow: How to Use This Plugin

### Phase 1: Initialize (one-time setup)

```
/harness-init          # Set up CLAUDE.md, docs/, bootstrap, entry points
/legibility-score      # Assess readiness — find gaps
/arch-guard            # Set up layer enforcement + Providers
```

### Phase 2: Encode Team Knowledge (ongoing)

```
/taste-encoder "no direct DB queries outside repo layer"
/taste-encoder "all API responses use ResponseEnvelope<T>"
/taste-encoder "max 300 lines per file"
```

Each team member's expertise becomes a lint rule or structural test that all agents
inherit. Designate an **Agent Captain** per team (OpenAI's recommendation) to manage
this encoding process.

### Phase 3: Daily Development Cycle

```
/spec-to-task <feature-spec>       # Decompose into agent-ready tasks
# ... agent implements tasks ...
/harness-review                    # Review with "Say No to Slop"
```

### Phase 4: Entropy Management (weekly or pre-release)

```
/entropy-sweep                     # Full scan: slop, drift, violations, dead code
```

### Parallelization Workflows

OpenAI's key throughput multiplier: **3.5 PRs per engineer per day**, increasing as team grew.

**Attended parallelization** — engineer manages 3-4 Claude Code sessions simultaneously:
1. Open multiple terminal sessions
2. Give each a scoped task from `/spec-to-task` output
3. Monitor progress, redirect when stuck
4. Review each output with `/harness-review`

**Unattended parallelization** — agent works independently to PR stage:
1. Use Claude Code's `/batch` for large-scale changes across files
2. Agent implements, runs tests, opens PR
3. Engineer reviews when ready
4. CI validation catches issues the agent missed

> "When someone had a technical decision in Slack, they would tag Codex:
> '@codex please add guardrails to our codebase' and get 4 PRs in 15 minutes"

### Delegate-Review-Own (across the SDLC)

OpenAI defines clear human/agent responsibilities at each phase:

| Phase | Agent Handles | Human Owns |
|-------|--------------|------------|
| **Plan** | Read specs, cross-reference codebase, flag ambiguities | Strategic prioritization |
| **Design** | Scaffold boilerplate, translate mockups | Architecture decisions |
| **Build** | Multi-step implementation (models, APIs, tests, docs) | Trade-offs, intent |
| **Test** | Suggest edge cases, generate test cases | Coverage alignment with specs |
| **Review** | Execute code, trace logic, find P0/P1 bugs | Final merge decision |
| **Docs** | Summarize functionality, generate diagrams | Structure, accuracy |
| **Deploy** | Parse logs, surface anomalies | Production responsibility |

## Key Principles from OpenAI

- **"Agents have no tacit knowledge; until it is made explicit, it doesn't exist"**
- **"If you can articulate what code you dislike, write that down"** as a lint rule
- **"Say No to Slop"** — never lower review standards, even to ship faster
- **"When the agent struggles, treat it as an environment design problem"**
- **"Every agent mistake becomes a permanent guardrail, not a one-time fix"** (Mitchell Hashimoto)
- **Progressive disclosure** — CLAUDE.md is the TOC, docs/ is the encyclopedia
- **Structured formats > prose** — agents comply better with JSON/YAML rules
- **Error messages are context** — lint errors must include remediation instructions
- **JSON > Markdown for tracking** — agents less frequently overwrite structured data
- **Build rippable harnesses** — keep constraints easy to update as models improve
- **Encode taste, not just rules** — each expert's knowledge multiplies across all agents
- **Speed increases communication need** — faster AI output requires more human check-ins, not fewer

## References

- [OpenAI: Harness Engineering](https://openai.com/index/harness-engineering/)
- [Martin Fowler: Harness Engineering](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)
- [The Emerging Harness Engineering Playbook](https://www.ignorance.ai/p/the-emerging-harness-engineering)
