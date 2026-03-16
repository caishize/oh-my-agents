# Linting

Custom lint rules and their rationale. Fill in when running `/taste-encoder`.

## Rule Index

<!-- Add rules as they are encoded via /taste-encoder -->

| ID | Rule | Severity | Enforced By | Added |
|----|------|----------|-------------|-------|
| <!-- TASTE-001 --> | <!-- no-duplicate-concurrency-helpers --> | <!-- error --> | <!-- ESLint --> | <!-- date --> |

## How to Add a Rule

1. Run `/taste-encoder <pattern-description>`
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

## Principles

- **Error messages are agent context** — every lint error must include:
  1. What's wrong
  2. How to fix it
  3. Reference to docs/ (e.g., `Ref: docs/CONVENTIONS.md#section`)
- **100% test coverage** for each rule (positive + negative cases)
- **"If you can articulate what code you dislike, write that down"** (OpenAI)
- **Each rule has an owner** — the person who encoded the expertise
