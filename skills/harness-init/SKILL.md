---
name: harness-init
description: "Initialize your project as an agent-ready harness — CLAUDE.md as table of contents, nested CLAUDE.md per module, docs/ system of record, bootstrap script, and task entry points. The complete AI coding environment setup based on OpenAI's four-pillar harness engineering methodology."
user-invocable: true
argument-hint: "[project-path]"
---

# Harness Init v2.0

Initialize the harness — the constraints, documentation, observability, feedback loops,
and entry points that make AI coding agents work reliably. Based on OpenAI's internal
experiment where 3 engineers shipped ~1M lines of production code via ~1,500 PRs in
5 months with zero hand-written code, using 88 AGENTS.md files across their codebase.

> "The bottleneck was never the agent's ability to write code, but the lack of structure,
> tools, and feedback mechanisms surrounding it."

## The Four Pillars

This harness is built on OpenAI's **four pillars** of harness engineering:

1. **Architecture as Guardrails** — Layer model, module boundaries, dependency rules
   that prevent agents from creating spaghetti code
2. **Documentation as System of Record** — Everything an agent needs lives in the repo;
   anything in Slack, wikis, or people's heads does not exist for the agent
3. **Observability & Legibility** — Agents and humans can see what happened, why it
   happened, and where the system stands at any moment
4. **Entropy Management** — Active resistance against codebase degradation through
   structural tests, lint rules, file size limits, and layer boundary enforcement

## Task

Set up the harness for this repository following all four pillars.
If `$ARGUMENTS` specifies a project path, use that; otherwise use the current directory.

### Step 1: Assess Current State

Scan the repository and evaluate readiness:

1. **Repository structure** — Identify top-level directories, package manager, language(s),
   build system, and framework(s)
2. **Module inventory** — List directories with 5+ source files (candidates for nested CLAUDE.md)
3. **Existing documentation** — Check for README, CLAUDE.md, docs/, ARCHITECTURE docs,
   ADRs, or any structured agent guidance
4. **Entry points** — Check if `build`, `test`, `lint`, `run`, `check` commands exist and work
5. **Observability status** — Check for logging, metrics, tracing, or monitoring setup
6. **Entropy indicators** — Look for oversized files, circular dependencies, inconsistent
   naming, dead code patterns

Produce a brief assessment report before proceeding.

### Step 2: Create Root CLAUDE.md (Progressive Disclosure)

CLAUDE.md must be **under 100 lines** and function as a **table of contents**, not an
encyclopedia. This is the principle of **progressive disclosure** — agents start with a
small, stable entry point and learn where to look next.

OpenAI found that one massive instruction file **FAILED** — context is scarce and crowds
out actual task details. They solved this with 88 nested AGENTS.md files. The Claude Code
analog is **nested CLAUDE.md per directory**.

Template:

```markdown
# [Project Name]

## Bootstrap
\`\`\`bash
./scripts/bootstrap.sh  # single command from zero to running
\`\`\`

## Commands
| Command | Purpose |
|---------|---------|
| `[build cmd]` | Compile / bundle the project |
| `[test cmd]` | Run all tests |
| `[lint cmd]` | Lint and format check |
| `[run cmd]` | Start the application |
| `[check cmd]` | Run lint + test + build in sequence |

## Architecture
[1-2 sentences describing the system]. Full details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

Layer model: Types -> Config -> Repo -> Service -> Runtime -> UI
Cross-cutting (auth, telemetry, feature flags): via Providers interface

## Key Conventions (Top 5)
1. [Most important naming/organization rule]
2. [Error handling pattern]
3. [File size limit: 300 lines]
4. [Import/dependency rule]
5. [Testing requirement]

Full conventions: [docs/CONVENTIONS.md](docs/CONVENTIONS.md)

## Module Map
| Module | Path | Purpose | Nested CLAUDE.md |
|--------|------|---------|-----------------|
| [name] | `src/[dir]` | [1-line purpose] | Yes/No |

## Documentation
- Architecture: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Conventions: [docs/CONVENTIONS.md](docs/CONVENTIONS.md)
- Testing: [docs/TESTING.md](docs/TESTING.md)
- Linting: [docs/LINTING.md](docs/LINTING.md)
- Decisions (ADRs): [docs/DECISIONS.md](docs/DECISIONS.md)
- Providers: [docs/PROVIDERS.md](docs/PROVIDERS.md)
- Observability: [docs/OBSERVABILITY.md](docs/OBSERVABILITY.md)
- Execution Plans: [docs/exec-plans/](docs/exec-plans/)
```

### Step 3: Generate Nested CLAUDE.md Files

For **every module directory with 5+ source files**, generate a nested CLAUDE.md.
Each must be **under 50 lines**. This is the direct analog of OpenAI's 88 nested AGENTS.md
files — scoped context that keeps the root small while giving agents deep module knowledge.

Template for each nested CLAUDE.md:

```markdown
# [Module Name]

## Purpose
[1-2 sentences: what this module does and why it exists]

## Layer Rules
- **Layer**: [Types|Config|Repo|Service|Runtime|UI]
- **Allowed imports**: [list of layers/modules this can import from]
- **Forbidden imports**: [list of layers/modules this must NOT import]

## Key Files
| File | Purpose |
|------|---------|
| `[file]` | [1-line description] |

## Module Conventions
- [Naming pattern specific to this module]
- [Error handling specifics]
- [Any module-specific rules]

## Common Patterns

\`\`\`[language]
// Pattern 1: [name]
[code snippet showing the dominant pattern in this module]
\`\`\`

\`\`\`[language]
// Pattern 2: [name]
[second common pattern if applicable]
\`\`\`
```

After generating, produce a report:

```
Nested CLAUDE.md Report:
  Created: src/services/CLAUDE.md (12 source files)
  Created: src/api/CLAUDE.md (8 source files)
  Skipped: src/types/ (3 source files, below threshold of 5)
  Skipped: src/utils/ (2 source files, below threshold of 5)
```

### Step 4: Create docs/ Directory (System of Record)

The real knowledge base lives in `docs/`. Everything an agent needs to know must live in
the repository — anything in Slack, Google Docs, or people's heads effectively **does not
exist** for the agent.

Create the full directory structure:

```
docs/
├── ARCHITECTURE.md        # Layer model, module boundaries, dependency rules
├── CONVENTIONS.md         # Naming, file size limits, error handling patterns
├── TESTING.md             # Test strategy, structural tests, coverage rules
├── LINTING.md             # Custom lint rules and their rationale
├── DECISIONS.md           # ADRs: "we chose X over Y because..."
├── PROVIDERS.md           # Cross-cutting: auth, telemetry, feature flags
├── OBSERVABILITY.md       # Logging, metrics, tracing, monitoring strategy
├── design-docs/           # Design documents for major features
│   └── .gitkeep
├── exec-plans/            # Execution plans from /spec-to-task
│   ├── active/            # Plans currently being worked on
│   │   └── .gitkeep
│   └── completed/         # Finished plans (moved here when done)
│       └── .gitkeep
├── product-specs/         # Product specifications and requirements
│   └── .gitkeep
└── references/            # External references, research, vendor docs
    └── .gitkeep
```

Key rules for documentation:
- **Structured formats (JSON/YAML) > prose** where agents need to parse rules
- **Machine-readable** — clear headings, bullet points, code examples
- **Actionable** — rules an agent can follow, not descriptions
- **In the repo** — never in Slack, wikis, or Google Docs
- **Pillar: Documentation as System of Record** — if it's not written down here, it doesn't exist
- **Pillar: Observability & Legibility** — OBSERVABILITY.md documents how to see system state

### Step 5: Create `.claude/harness.json` Config

Create a machine-readable harness configuration that other skills can reference:

```json
{
  "version": "2.0",
  "pillars": ["architecture", "documentation", "observability", "entropy"],
  "layers": ["types", "config", "repo", "service", "runtime", "ui"],
  "layer_dirs": {
    "types": "src/types",
    "config": "src/config",
    "repo": "src/repo",
    "service": "src/services",
    "runtime": "src/api",
    "ui": "src/ui"
  },
  "providers_path": null,
  "file_size_limit": 300,
  "nested_claude_md_threshold": 5
}
```

Adapt `layer_dirs` to match the actual project structure discovered in Step 1.
Set `providers_path` if a cross-cutting providers module exists.

### Step 6: Create Bootstrap Script

Create `scripts/bootstrap.sh` — a single script from zero to running:

```bash
#!/usr/bin/env bash
# scripts/bootstrap.sh — one-command project setup
set -euo pipefail

echo "=== Harness Bootstrap ==="

echo "[1/4] Installing dependencies..."
[package-manager install command]

echo "[2/4] Setting up environment..."
cp .env.example .env 2>/dev/null || echo "No .env.example found, skipping"

echo "[3/4] Running initial build..."
[build command]

echo "[4/4] Verifying setup..."
[test command]

echo ""
echo "Setup complete. Available commands:"
echo "  [build cmd]  — Build the project"
echo "  [test cmd]   — Run tests"
echo "  [lint cmd]   — Lint and format"
echo "  [run cmd]    — Start the application"
echo "  [check cmd]  — Full validation (lint + test + build)"
```

Make it executable: `chmod +x scripts/bootstrap.sh`

### Step 7: Create Task Entry Points

Ensure the project has consistent, discoverable entry points. These must be documented
in CLAUDE.md and **actually work** (verify by running each one):

- **build** — Compile or bundle the project
- **test** — Run all tests
- **lint** — Lint and format check (with auto-fix option)
- **run** — Start the application
- **check** — Run lint + test + build in sequence (the validation harness)

If entry points are missing, create them using the project's build system
(Makefile, package.json scripts, Cargo.toml, etc.).

> "When Codex got stuck, we treated it as an environment design problem — what was
> missing for the agent to proceed reliably?"

The `check` command is critical for **Pillar: Entropy Management** — it's how agents
verify their own changes don't degrade the codebase.

### Step 8: Report Summary

After completing all steps, produce a summary report:

```
=== Harness Init Summary ===

Project: [name]
Language: [language(s)]
Framework: [framework(s)]

Files Created:
  [x] CLAUDE.md (root, XX lines)
  [x] src/services/CLAUDE.md (nested, XX lines)
  [x] src/api/CLAUDE.md (nested, XX lines)
  ... (list all nested CLAUDE.md files)
  [x] docs/ARCHITECTURE.md
  [x] docs/CONVENTIONS.md
  [x] docs/TESTING.md
  [x] docs/LINTING.md
  [x] docs/DECISIONS.md
  [x] docs/PROVIDERS.md
  [x] docs/OBSERVABILITY.md
  [x] .claude/harness.json
  [x] scripts/bootstrap.sh

Entry Points Verified:
  [pass/fail] build: [command]
  [pass/fail] test: [command]
  [pass/fail] lint: [command]
  [pass/fail] run: [command]
  [pass/fail] check: [command]

Four Pillars Assessment:
  Architecture as Guardrails:     [score/description]
  Documentation as System of Record: [score/description]
  Observability & Legibility:     [score/description]
  Entropy Management:             [score/description]

Legibility Score: [X/7] (see /legibility-score for details)

Next Steps:
  - Review generated docs and fill in project-specific details
  - Run /legibility-score for detailed assessment
  - Use /spec-to-task to create execution plans for features
```

## Rules

- **CLAUDE.md must stay under 100 lines** — it is the table of contents, not the encyclopedia
- **Nested CLAUDE.md must stay under 50 lines** — scoped context, not a novel
- **Every command must actually work** — verify by running each entry point
- **Use structured formats (JSON/YAML) where agents need to parse rules** — agents comply
  better with structured rules than prose
- **Bootstrap script must work from a clean checkout** — the first-run experience matters
- **All entry points must be documented and functional** — undocumented commands don't exist
- **Past decisions live in ADRs, not in people's heads** — add them to docs/DECISIONS.md
- **Execution plans go in `docs/exec-plans/`** — not in `.claude/plans/`
- **When an agent struggles, treat it as a harness problem, not an agent problem** — improve
  the environment, documentation, and feedback loops
- **Four pillars must all be addressed** — Architecture, Documentation, Observability, Entropy;
  skipping any pillar creates blind spots that compound over time
- **Nested CLAUDE.md for every module with 5+ source files** — this is how OpenAI scaled to
  88 instruction files; one root file cannot hold everything
