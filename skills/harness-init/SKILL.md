---
name: harness-init
description: "Initialize project as agent-ready harness — CLAUDE.md, nested CLAUDE.md per module, docs/ system of record, bootstrap script, pre-commit hooks, architecture tests. Based on OpenAI's four-pillar harness engineering. Aliases: 初始化, 项目初始化, harness初始化, AI开发环境"
user-invocable: true
argument-hint: "[project-path] [--quick]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash
---

# Harness Init

Initialize the harness — constraints, documentation, observability, and feedback loops
that make AI coding agents work reliably.

## Task

Walk through Steps 1–9 (or 1–9 + `/legibility-score` + `/arch-guard` in `--quick`
mode) to bootstrap the four-pillar harness in the target project: assess state,
write CLAUDE.md (root + nested per-module), populate `docs/` (ARCHITECTURE,
CONVENTIONS, TESTING, LINTING, DECISIONS, PROVIDERS, OBSERVABILITY), generate
`.claude/harness.json`, install pre-commit + architecture-test skeletons, and
emit a summary with score and recommendations.

## Quick Start Mode

If `$ARGUMENTS` contains `--quick`: run Steps 1-9, then `/legibility-score`, then
`/arch-guard`. Print a one-paragraph summary with score and top 3 improvements.

## Step 1: Assess Current State

Scan the repository:
1. Repository structure — directories, package manager, language(s), framework(s)
2. Module inventory — directories with 5+ source files (candidates for nested CLAUDE.md)
3. Existing documentation — README, CLAUDE.md, docs/, ADRs
4. Entry points — do `build`, `test`, `lint`, `run`, `check` commands exist and work?
5. gstack detection:
   ```bash
   source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/common.sh" && gstack_detect && echo "GSTACK: yes" || echo "GSTACK: no"
   # If yes: ensure .gitignore covers .claude/gstack-rendered/ (gstack-owned enclave,
   # v1.57.9+ gen-skill-docs writes rendered docs there — never track or flag it)
   ```

Produce a brief assessment before proceeding.

## Step 2: Create Root CLAUDE.md

Must be **under 100 lines** — a table of contents, not an encyclopedia. Include:
- Bootstrap command
- Commands table (build, test, lint, run, check)
- Architecture summary with layer model
- Top 5 conventions
- Module map with file counts and nested CLAUDE.md status
- Workflow table (adapt based on gstack detection — full lifecycle if gstack present,
  oh-my-agents-only if not)
- Documentation links to docs/

## Step 3: Generate Nested CLAUDE.md Files

For every module with **5+ source files**, create a CLAUDE.md under **50 lines**:
- Purpose (1-2 sentences)
- Layer rules (layer name, allowed/forbidden imports)
- Key files table
- Module conventions
- Common patterns (1-2 code snippets)

## Step 4: Create docs/ Directory

```
docs/
├── ARCHITECTURE.md    # Layer model, boundaries, dependency rules
├── CONVENTIONS.md     # Naming, file size limits, patterns
├── TESTING.md         # Test strategy, structural tests
├── LINTING.md         # Custom lint rules (TASTE-NNN entries)
├── DECISIONS.md       # ADRs (Proposed → Accepted → Superseded)
├── PROVIDERS.md       # Cross-cutting: auth, telemetry, flags
├── OBSERVABILITY.md   # Logging, metrics, tracing
├── WORKFLOW.md        # Development lifecycle (adapt to gstack)
├── design-docs/       # Design documents
├── exec-plans/        # Execution plans from /spec-to-task
│   ├── active/
│   └── completed/
├── product-specs/
└── references/
```

If gstack detected, WORKFLOW.md includes full lifecycle (Ideate → Ship → Retro).
Otherwise, oh-my-agents-only (Decompose → Execute → Verify → Review → Guard).

Key rules:
- Structured formats (JSON/YAML) > prose where agents parse rules
- Everything in the repo — Slack/wikis don't exist for agents
- ADR lifecycle: `Proposed → Accepted → Superseded/Deprecated`
- Sibling layers noted separately in ARCHITECTURE.md

## Step 5: Create `.claude/harness.json`

Machine-readable config. Use `templates/harness-config.json` as starting point:
```json
{
  "version": "2.0",
  "layers": ["types", "config", "repo", "service", "runtime", "ui"],
  "layer_dirs": { "types": "src/types", "service": "src/services" },
  "file_size_limit": 300,
  "nested_claude_md_threshold": 5
}
```
**Layer keys must match actual directory names** (e.g., `"services"` not `"service"`).

## Step 6: Create Bootstrap Script

Create `scripts/bootstrap.sh` — single command from zero to running:
1. Install dependencies
2. Set up environment (copy .env.example)
3. Install pre-commit hooks
4. Run initial build
5. Verify setup

Make executable: `chmod +x scripts/bootstrap.sh`
If hardcoded secrets detected, create `.env.example` with placeholders.

## Step 7: Set Up Pre-Commit Enforcement

Create `.pre-commit-config.yaml` with three tiers:
1. **Linter + formatter** (~1s)
2. **Type checker** (~5s)
3. **Architecture guard** — runs structural tests enforcing TASTE/ARCH rules (~1-2s)

Adapt to project language. See `templates/` for examples.

## Step 7b: Generate Architecture Test Skeleton

Generate the architecture test file if it doesn't already exist:
- **Python projects**: See [arch-test-python.md](arch-test-python.md)
- **TypeScript projects**: See [arch-test-typescript.md](arch-test-typescript.md)

Tests include: `test_layer_boundaries`, `test_file_size_limits`, `test_no_circular_imports`.
Never overwrite existing test files.

## Step 8: Create Task Entry Points

Ensure build, test, lint, run, check commands exist and work. Create using the project's
build system if missing. Annotate non-functional commands in CLAUDE.md.

## Step 9: Report Summary

```
=== Harness Init Summary ===
Project: [name] | Language: [lang] | Framework: [fw]

Files Created: [list all created files]
Entry Points Verified: [pass/fail for each]
Four Pillars: [score for each]
gstack: [yes/no]

Next Steps: [top 3 recommendations]
```

## Rules

- CLAUDE.md under 100 lines, nested CLAUDE.md under 50 lines
- Every command must actually work — verify by running
- Bootstrap must work from clean checkout
- All entry points documented and functional
- Layer keys match directory names in harness.json
- Pre-commit must include architecture guard
- Never overwrite existing architecture tests
- Four pillars must all be addressed
