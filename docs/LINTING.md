# Linting

Custom lint rules and their rationale. Fill in when running `/encode-mistake --proactive`.

## Rule Index

<!-- Add rules as they are encoded via /encode-mistake --proactive -->

| ID | Rule | Severity | Enforced By | Added |
|----|------|----------|-------------|-------|
| <!-- TASTE-001 --> | <!-- no-duplicate-concurrency-helpers --> | <!-- error --> | <!-- ESLint --> | <!-- date --> |

## How to Add a Rule

1. Run `/encode-mistake --proactive <pattern-description>`
2. The skill will create the enforcement (lint rule, structural test, or hook)
3. Add an entry to this table with a TASTE-NNN ID
4. Include test coverage (both positive and negative cases)

## Rule Template

```markdown
## [Rule Name] (TASTE-NNN)

**Rule**: [One-line description]
**Enforced by**: [ESLint rule / structural test / pre-commit hook]
**Severity**: [error (blocks) / warning (flags) / info (suggests)]
**Rationale**: [Why this rule exists — what problem it prevents]
**Added by**: [name] on [date]

**Good example**:
\`\`\`
[code that follows the rule]
\`\`\`

**Bad example**:
\`\`\`
[code that violates the rule]
\`\`\`
```

## Slop taxonomy (canonical)

Single source of truth for "slop" — technically-correct code that degrades quality.
`/harness-review` (Review 1, per-PR), `/entropy-sweep` (Sweep 1, weekly), and
`/harness-audit` (slop dimension, governance) all classify against THIS list — same
definition, different trigger. Edit here, not in three places.

| Category | What it is | Highest-signal tell |
|----------|-----------|---------------------|
| **Duplicate logic** | Same function/helper in 2+ places | one copy has instrumentation the other lacks (e.g. only one retry helper has OTel) |
| **Pattern inconsistency** | Same operation done differently across files | mixed async/await vs callbacks; `logger.info()` vs `console.log()` |
| **Copy-paste artifacts** | Generic comments, template variable names, leftover scaffolding TODOs | a comment/name that doesn't match its context |
| **Over-engineering** | Abstraction with no second caller | abstract factory for one impl; generic param used once; config for behavior that never varies |
| **Inconsistent naming** | Same concept, different names across modules | rename to one canonical term |
| **Security slop** | Hardcoded secrets/keys/tokens in source | literals matching `sk-`/`ghp_`/`AKIA`/`Bearer`/key-assignments — use env/secret manager |
| **Missing taste** | Would a senior engineer reject this in a manual PR? | the catch-all judgment call |

**Agent-replication risk (always note it):** bad patterns in the codebase multiply via
every future agent-generated PR. "Three retry implementations exist — an agent
encountering this codebase will create a 4th." Severity rises with replication risk.

## Principles

- **Error messages are agent context** — every lint error must include:
  1. What's wrong
  2. How to fix it
  3. Reference to docs/ (e.g., `Ref: docs/CONVENTIONS.md#section`)
- **100% test coverage** for each rule (positive + negative cases)
- **"If you can articulate what code you dislike, write that down"** (OpenAI)
- **Each rule has an owner** — the person who encoded the expertise
