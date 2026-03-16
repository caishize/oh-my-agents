# Architecture Decision Records

Document past choices so agents (and humans) don't rediscover decisions.
Fill in as decisions are made.

> "Lightweight format: 'We chose Postgres over MongoDB because X, Y, Z.'
> Prevents agents from rediscovering the same decisions differently."

## Template

```markdown
## ADR-NNN: [Title]

**Date**: YYYY-MM-DD
**Status**: [Proposed / Accepted / Deprecated / Superseded by ADR-NNN]
**Deciders**: [names]

### Context
[What is the issue that we're seeing that is motivating this decision?]

### Decision
[What is the change that we're making?]

### Alternatives Considered
- [Option A]: [pros/cons]
- [Option B]: [pros/cons]

### Consequences
- [Positive consequence]
- [Negative consequence / trade-off]
- [Enforcement]: [lint rule / structural test / doc update needed]
```

## Decision Log

<!-- Add decisions as they are made -->

| ADR | Title | Status | Date |
|-----|-------|--------|------|
| <!-- ADR-001 --> | <!-- Layer architecture: Types→Config→Repo→Service→Runtime→UI --> | <!-- Accepted --> | <!-- date --> |
