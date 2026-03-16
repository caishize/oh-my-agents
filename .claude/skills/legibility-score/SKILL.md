---
name: legibility-score
description: Assess the 7-metric Agent Legibility Score for a repository — measures how ready a codebase is for AI agent-driven development. Based on OpenAI's harness engineering readiness framework.
user-invocable: true
argument-hint: "[project-path]"
allowed-tools: Read, Glob, Grep, Bash
---

# Agent Legibility Score

Assess this repository against OpenAI's **7-metric Agent Legibility Score** — the
minimum readiness checklist that defines whether a codebase is ready for agent-driven
development.

> "Agents are most effective in environments with strict boundaries and predictable
> structure." The legibility score measures how well the harness channels agent capabilities.

## The 7 Metrics

Evaluate each metric on a 0-3 scale:
- **0** — Missing entirely
- **1** — Exists but incomplete/broken
- **2** — Functional but could improve
- **3** — Excellent, fully agent-ready

### 1. Bootstrap Self-Sufficiency

**Question**: Can an agent go from a fresh clone to a running project with a single command?

Check for:
- [ ] A single `bootstrap.sh`, `setup.sh`, or equivalent script exists
- [ ] Running it from a clean checkout installs all dependencies
- [ ] It sets up environment (copies .env.example, creates dirs, etc.)
- [ ] It succeeds without manual intervention or secret knowledge
- [ ] It works on CI (not just the developer's machine)

**Test**: Run the bootstrap command. Does it work?

### 2. Task Entry Points

**Question**: Are there clear, documented commands for build, test, lint, and run?

Check for:
- [ ] `build` command exists and is documented in CLAUDE.md
- [ ] `test` command exists, runs all tests, and is documented
- [ ] `lint` command exists with auto-fix capability and is documented
- [ ] `run` command exists for local development and is documented
- [ ] Commands are consistent (all in Makefile, package.json, or similar)

**Test**: Run each command. Do they all work?

### 3. Validation Harness

**Question**: Can an agent verify that its own changes work?

Check for:
- [ ] Test suite exists and passes
- [ ] Tests can be run with a single command
- [ ] Test output clearly shows pass/fail
- [ ] Pre-commit hooks catch common errors
- [ ] CI runs tests on PRs

**Test**: Make a deliberate mistake. Does the validation catch it?

### 4. Linting & Formatting

**Question**: Is there automated quality enforcement with auto-fix?

Check for:
- [ ] Linter configured (ESLint, Ruff, clippy, etc.)
- [ ] Formatter configured (Prettier, Black, rustfmt, etc.)
- [ ] Auto-fix available (`lint --fix`)
- [ ] Custom rules enforce project-specific patterns
- [ ] Error messages include remediation instructions

**Test**: Run the linter. Does it catch style violations and auto-fix them?

### 5. Codebase Map

**Question**: Is there a high-level organization guide an agent can start from?

Check for:
- [ ] CLAUDE.md (or equivalent) exists and is under 100 lines
- [ ] It acts as a table of contents, not an encyclopedia (progressive disclosure)
- [ ] Directory structure is explained
- [ ] Key modules and their responsibilities are listed
- [ ] Entry points to deeper documentation are linked

**Test**: Reading only CLAUDE.md, could an agent navigate the codebase?

### 6. Documentation Structure

**Question**: Is documentation organized for agent navigation?

Check for:
- [ ] `docs/` directory exists with structured files
- [ ] Architecture documented (layer model, boundaries, dependencies)
- [ ] Conventions documented (naming, file size, patterns)
- [ ] API contracts documented (interfaces, data models)
- [ ] All docs are in the repo (not in Slack, wikis, or Google Docs)

**Test**: Pick a convention. Is it documented clearly enough for an agent to follow?

### 7. Decision Records

**Question**: Are past architectural choices documented with rationale?

Check for:
- [ ] ADRs (Architecture Decision Records) exist
- [ ] Each ADR explains what was chosen, what was rejected, and why
- [ ] ADRs cover technology choices, patterns, and trade-offs
- [ ] New decisions are being added (not a stale collection)

**Test**: For a non-obvious pattern, can an agent find the ADR explaining why?

## Scoring

After evaluating all 7 metrics, compute the total:

```
| Metric                     | Score (0-3) |
|----------------------------|-------------|
| 1. Bootstrap               |     /3      |
| 2. Entry Points            |     /3      |
| 3. Validation Harness      |     /3      |
| 4. Linting & Formatting    |     /3      |
| 5. Codebase Map            |     /3      |
| 6. Documentation Structure |     /3      |
| 7. Decision Records        |     /3      |
|----------------------------|-------------|
| **Total**                  |    **/21**  |
```

**Interpretation**:
- **0-7**: Not agent-ready — significant harness work needed
- **8-14**: Partially ready — agents will struggle on some tasks
- **15-18**: Agent-ready — agents can work effectively on most tasks
- **19-21**: Excellent — agents operate at maximum efficiency

## Output

Present the score card, then list the **top 3 improvements** ranked by impact.
For each improvement, provide specific, actionable steps.

Recommend running `/harness-init` for items scoring 0-1.
Recommend running `/taste-encoder` for items scoring 2 that need custom rules.

## Rules

- Actually run commands to verify they work — don't just check if files exist
- Be honest in scoring — an inflated score helps nobody
- Prioritize improvements by impact on agent productivity
- Missing items (score 0) are more urgent than weak items (score 1-2)
