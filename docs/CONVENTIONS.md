# Conventions

Project-level coding conventions. Fill in when running `/harness-init`.

## Naming

<!-- Define your naming patterns here -->
<!-- Example:
- Files: kebab-case (e.g., `user-service.ts`)
- Functions: camelCase (e.g., `getUserById`)
- Types: PascalCase (e.g., `UserProfile`)
- Constants: UPPER_SNAKE (e.g., `MAX_RETRIES`)
-->

## File Size

- Maximum lines per source file: 300
- When a file exceeds this limit, extract helpers into separate modules
- Enforced by: structural test `test_file_size_limits`

## Error Handling

<!-- Define your error handling patterns here -->
<!-- Example:
- All errors at system boundaries (API, DB) must be caught and wrapped
- Use typed errors, not raw strings
- Include context in error messages: what failed, why, how to fix
-->

## Logging

<!-- Define your logging patterns here -->
<!-- Example:
- Use structured logging via the Providers interface
- Never use console.log/print in production code
- Log levels: error (broken), warn (degraded), info (state change), debug (details)
-->

## Concurrency Helpers

<!-- Define approved locations for shared utilities -->
<!-- Example:
- Retry/timeout helpers: only in `src/utils/concurrency.ts`
- The approved version includes OpenTelemetry instrumentation
- Enforced by: lint rule `no-duplicate-concurrency-helpers` (TASTE-001)
-->

## Cross-Cutting Concerns

- Auth, telemetry, feature flags: access only via the Providers interface
- Never import auth/telemetry libraries directly in business logic
- See [PROVIDERS.md](PROVIDERS.md) for the interface definition
