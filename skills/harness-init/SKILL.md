---
name: harness-init
description: Initialize the harness engineering environment for a project — CLAUDE.md as table of contents, docs/ structure, bootstrap script, task entry points. Based on OpenAI's harness engineering methodology.
user-invocable: true
argument-hint: "[project-path]"
---

# Harness Init

Initialize the harness — the constraints, documentation, feedback loops, and entry points
that make AI coding agents work reliably. Based on OpenAI's internal experiment where
3 engineers shipped ~1M lines of production code via ~1,500 PRs in 5 months with zero
hand-written code.

> "The bottleneck was never the agent's ability to write code, but the lack of structure,
> tools, and feedback mechanisms surrounding it."

## Task

Set up the harness for this repository following OpenAI's three pillars:
Context Engineering, Architectural Constraints, and Entropy Management.

### Step 1: Assess Current State

Scan the repository and evaluate readiness against the **Agent Legibility Score**
(see `/legibility-score` for the full 7-metric assessment):

1. Is there a single setup/bootstrap script?
2. Are there clear `build`, `test`, `lint`, `run` entry points?
3. Can an agent verify its own changes?
4. Is there automated linting & formatting with auto-fix?
5. Is there a high-level codebase map?
6. Is documentation structured for agent navigation?
7. Are past architectural decisions recorded?

### Step 2: Create CLAUDE.md (Progressive Disclosure)

CLAUDE.md must be **~100 lines max** and function as a **table of contents**, not an
encyclopedia. This is the principle of **progressive disclosure** — agents start with a
small, stable entry point and learn where to look next.

OpenAI found that one massive instruction file **failed** — context is scarce and crowds
out actual task details.

```markdown
# [Project Name]

## Bootstrap
\`\`\`bash
./scripts/bootstrap.sh  # single command from zero to running
\`\`\`

## Task Entry Points
- Build: `make build` (or npm/cargo/go equivalent)
- Test: `make test`
- Lint: `make lint`
- Run: `make run`

## Architecture
[1-2 sentences]. Full details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

Layer model: Types → Config → Repo → Service → Runtime → UI
Cross-cutting (auth, telemetry, feature flags): via Providers interface

## Conventions
Key rules: [docs/CONVENTIONS.md](docs/CONVENTIONS.md)
- [naming pattern]
- [file organization pattern]
- [error handling pattern]

## Decisions
Architecture Decision Records: [docs/DECISIONS.md](docs/DECISIONS.md)

## Quality
- Custom lints: [docs/LINTING.md](docs/LINTING.md)
- Structural tests: [docs/TESTING.md](docs/TESTING.md)
```

### Step 3: Create docs/ Directory (System of Record)

The real knowledge base lives in `docs/`, not in CLAUDE.md. Everything an agent
needs to know must live in the repository — anything in Slack, Google Docs, or
people's heads effectively **does not exist** for the agent.

```
docs/
├── ARCHITECTURE.md    # Layer model, module boundaries, dependency rules
├── CONVENTIONS.md     # Naming, file size limits, error handling patterns
├── TESTING.md         # Test strategy, structural tests, coverage rules
├── LINTING.md         # Custom lint rules and their rationale
├── DECISIONS.md       # ADRs: "we chose X over Y because..."
└── PROVIDERS.md       # Cross-cutting: auth, telemetry, feature flags
```

Key rules for docs:
- **Structured formats (JSON/YAML) > prose** — agents comply better with structured rules
- **Machine-readable** — clear headings, bullet points, code examples
- **Actionable** — rules an agent can follow, not descriptions
- **In the repo** — never in Slack, wikis, or Google Docs

### Step 4: Create Bootstrap Script

A single script that takes the project from zero to running:

```bash
#!/usr/bin/env bash
# scripts/bootstrap.sh — one-command project setup
set -euo pipefail

echo "Installing dependencies..."
[package-manager install command]

echo "Setting up environment..."
cp .env.example .env 2>/dev/null || true

echo "Running initial build..."
[build command]

echo "Verifying setup..."
[test command]

echo "✅ Ready. Run 'make run' to start."
```

### Step 5: Create Task Entry Points

Ensure the project has consistent, discoverable entry points that agents can call:

- `make build` / `npm run build` / `cargo build`
- `make test` / `npm test` / `cargo test`
- `make lint` / `npm run lint` / `cargo clippy`
- `make run` / `npm start` / `cargo run`
- `make check` — runs lint + test + build in sequence

These must be documented in CLAUDE.md and actually work.

### Step 6: Set Up Validation Harness

The agent must be able to **verify its own changes**. Set up:

1. Pre-commit hooks that run lint + format
2. A `make check` command that validates everything
3. CI pipeline that runs on every PR

> "When Codex got stuck, we treated it as an environment design problem — what was
> missing for the agent to proceed reliably?"

## Rules

- CLAUDE.md must stay under 100 lines — it's the table of contents
- Every command in CLAUDE.md must actually work (verify by running)
- Docs use structured formats where agents need to parse rules
- Bootstrap script must work from a clean checkout
- All entry points must be documented and functional
- Past decisions live in ADRs, not in people's heads
- When an agent struggles, treat it as a harness problem, not an agent problem
