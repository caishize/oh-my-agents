---
name: legibility-score
description: "Assess the 10-metric Agent Legibility Score for a repository — measures how ready a codebase is for AI agent-driven development across four pillars: Architecture as Guardrails, Documentation as System of Record, Observability & Legibility, Entropy Management. Aliases: 可读性评分, Agent就绪度, 代码可读性, AI友好度评估, 代码评分"
user-invocable: true
argument-hint: "[project-path]"
allowed-tools: Read, Glob, Grep, Bash
---

# Agent Legibility Score

Assess this repository against the **10-metric Agent Legibility Score** — the readiness
checklist that defines whether a codebase is ready for agent-driven development.

The metrics are organized around the **four pillars**:

1. **Architecture as Guardrails** — layers, providers, mechanical enforcement
2. **Documentation as System of Record** — CLAUDE.md, docs/, nested CLAUDE.md per module
3. **Observability & Legibility** — can agents see what happened and verify their work?
4. **Entropy Management** — are there systems to prevent and clean up drift?

> "Agents are most effective in environments with strict boundaries and predictable
> structure." The legibility score measures how well the harness channels agent capabilities.

## The 10 Metrics

Evaluate each metric on a 0-3 scale:
- **0** — Missing entirely
- **1** — Exists but incomplete/broken
- **2** — Functional but could improve
- **3** — Excellent, fully agent-ready

---

### Pillar 1: Architecture as Guardrails

#### 1. Bootstrap Self-Sufficiency

**Question**: Can an agent go from a fresh clone to a running project with a single command?

Check for:
- [ ] A single `bootstrap.sh`, `setup.sh`, or equivalent script exists
- [ ] Running it from a clean checkout installs all dependencies
- [ ] It sets up environment (copies .env.example, creates dirs, etc.)
- [ ] It succeeds without manual intervention or secret knowledge
- [ ] It works on CI (not just the developer's machine)

**Test**: Run the bootstrap command. Does it work?

#### 2. Task Entry Points

**Question**: Are there clear, documented commands for build, test, lint, and run?

Check for:
- [ ] `build` command exists and is documented in CLAUDE.md
- [ ] `test` command exists, runs all tests, and is documented
- [ ] `lint` command exists with auto-fix capability and is documented
- [ ] `run` command exists for local development and is documented
- [ ] Commands are consistent (all in Makefile, package.json, or similar)

**Test**: Run each command. Do they all work?

#### 3. Validation Harness

**Question**: Can an agent verify that its own changes work?

Check for:
- [ ] Test suite exists and passes
- [ ] Tests can be run with a single command
- [ ] Test output clearly shows pass/fail
- [ ] Pre-commit hooks catch common errors
- [ ] CI runs tests on PRs

**Test**: Make a deliberate mistake. Does the validation catch it?

#### 4. Linting & Formatting

**Question**: Is there automated quality enforcement with auto-fix?

Check for:
- [ ] Linter configured (ESLint, Ruff, clippy, etc.)
- [ ] Formatter configured (Prettier, Black, rustfmt, etc.)
- [ ] Auto-fix available (`lint --fix`)
- [ ] Custom rules enforce project-specific patterns
- [ ] Error messages include remediation instructions

**Test**: Run the linter. Does it catch style violations and auto-fix them?

---

### Pillar 2: Documentation as System of Record

#### 5. Codebase Map

**Question**: Is there a high-level organization guide an agent can start from?

Scoring guide:
- **0**: No CLAUDE.md exists
- **1**: Root CLAUDE.md exists but is over 100 lines or lacks structure
  (missing directory overview, key commands, or module descriptions)
- **2**: Root CLAUDE.md is under 100 lines with proper structure
  (acts as table of contents, progressive disclosure, key entry points)
- **3**: Root CLAUDE.md + nested CLAUDE.md for all qualifying modules
  (modules with 5+ files get their own CLAUDE.md with layer rules and conventions)

Check for:
- [ ] CLAUDE.md exists and is under 100 lines
- [ ] It acts as a table of contents, not an encyclopedia (progressive disclosure)
- [ ] Directory structure is explained
- [ ] Key modules and their responsibilities are listed
- [ ] Entry points to deeper documentation are linked
- [ ] Qualifying modules have their own nested CLAUDE.md

**Test**: Reading only CLAUDE.md, could an agent navigate the codebase?

#### 6. Documentation Structure

**Question**: Is documentation organized for agent navigation?

Check for:
- [ ] `docs/` directory exists with structured files
- [ ] Architecture documented (layer model, boundaries, dependencies)
- [ ] Conventions documented (naming, file size, patterns)
- [ ] API contracts documented (interfaces, data models)
- [ ] All docs are in the repo (not in Slack, wikis, or Google Docs)

**Test**: Pick a convention. Is it documented clearly enough for an agent to follow?

#### 7. Decision Records

**Question**: Are past architectural choices documented with rationale?

Check for:
- [ ] ADRs (Architecture Decision Records) exist
- [ ] Each ADR explains what was chosen, what was rejected, and why
- [ ] ADRs cover technology choices, patterns, and trade-offs
- [ ] New decisions are being added (not a stale collection)

**Test**: For a non-obvious pattern, can an agent find the ADR explaining why?

---

### Pillar 3: Observability & Legibility

#### 8. App Bootstrap

**Question**: Can the agent boot the app and verify it runs?

This goes beyond "can I run the test suite" to "can I start the actual application
and confirm it's healthy." Agents that can verify runtime behavior catch issues that
unit tests miss.

Check for:
- [ ] A documented command starts the application (dev mode)
- [ ] The app has a health check endpoint or startup confirmation
- [ ] Boot errors produce actionable messages (not silent failures)
- [ ] The app can run with test/mock data (no external dependencies required)
- [ ] Startup time is reasonable (under 30 seconds for dev mode)

**Test**: Start the app. Can you confirm it's running and healthy?

#### 9. Runtime Logs

**Question**: Can the agent capture logs/errors from a running instance?

Agents that can read runtime output can self-diagnose failures instead of
guessing. This is the difference between "it doesn't work" and "line 42 throws
TypeError because X is undefined."

Check for:
- [ ] Structured logging is configured (JSON or consistent format)
- [ ] Log levels are used meaningfully (error/warn/info/debug)
- [ ] Errors include stack traces and context
- [ ] Logs are written to stdout/stderr (accessible to agents)
- [ ] No sensitive data in logs (tokens, passwords, PII)

**Test**: Trigger an error. Can you find useful diagnostic information in the logs?

#### 10. Nested CLAUDE.md Coverage

**Question**: What percentage of qualifying modules have their own CLAUDE.md?

Nested CLAUDE.md files give agents module-specific context without polluting the
root CLAUDE.md. A "qualifying module" is any directory with 5+ source files that
represents a distinct domain or layer.

Check for:
- [ ] Identify all qualifying modules (directories with 5+ source files)
- [ ] Count how many have a CLAUDE.md
- [ ] Each nested CLAUDE.md includes: purpose, layer rules, conventions, key files
- [ ] Nested CLAUDE.md files are under 50 lines each
- [ ] Content is consistent with root CLAUDE.md (no contradictions)

Scoring:
- **0**: No nested CLAUDE.md files exist, even with qualifying modules
- **1**: Less than 30% of qualifying modules have CLAUDE.md
- **2**: 30-70% of qualifying modules have CLAUDE.md
- **3**: Over 70% of qualifying modules have well-maintained CLAUDE.md

---

### Pillar 4: Entropy Management

Check if `docs/exec-plans/` exists. If it does, note whether there are active plans
in `docs/exec-plans/active/`. Execution plans are a sign of mature entropy management
— they show the team is breaking large changes into trackable, reviewable phases.

This pillar doesn't have its own scored metric but influences the overall assessment.
Note the presence or absence of execution plans in the report.

---

## Scoring

After evaluating all 10 metrics, compute the total:

```
| #  | Metric                     | Pillar              | Score (0-3) |
|----|----------------------------|----------------------|-------------|
| 1  | Bootstrap                  | Architecture         |     /3      |
| 2  | Entry Points               | Architecture         |     /3      |
| 3  | Validation Harness         | Architecture         |     /3      |
| 4  | Linting & Formatting       | Architecture         |     /3      |
| 5  | Codebase Map               | Documentation        |     /3      |
| 6  | Documentation Structure    | Documentation        |     /3      |
| 7  | Decision Records           | Documentation        |     /3      |
| 8  | App Bootstrap              | Observability        |     /3      |
| 9  | Runtime Logs               | Observability        |     /3      |
| 10 | Nested CLAUDE.md Coverage  | Observability        |     /3      |
|----|----------------------------|----------------------|-------------|
|    | **Total**                  |                      |    **/30**  |
```

**Interpretation**:
- **0-10**: Not agent-ready — significant harness work needed
- **11-20**: Partially ready — agents will struggle on some tasks
- **21-25**: Agent-ready — agents can work effectively on most tasks
- **26-30**: Excellent — agents operate at maximum efficiency

**Entropy Management bonus**: If `docs/exec-plans/` exists with active plans,
note "Execution plan infrastructure detected" in the report. This is a positive
signal even though it doesn't affect the numeric score.

## Output

Present the score card, then list the **top 3 improvements** ranked by impact.
For each improvement, provide specific, actionable steps.

Recommend running `/harness-init` for items scoring 0-1.
Recommend running `/taste-encoder` for items scoring 2 that need custom rules.
Recommend running `/entropy-sweep` for codebases scoring 21+ that need ongoing maintenance.

## Rules

- Actually run commands to verify they work — don't just check if files exist
- Be honest in scoring — an inflated score helps nobody
- Prioritize improvements by impact on agent productivity
- Missing items (score 0) are more urgent than weak items (score 1-2)
- When scoring metric 5 (Codebase Map), apply the detailed scoring guide strictly
- For metric 10, identify qualifying modules before scoring coverage
