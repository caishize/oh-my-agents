# Conventions

Project-level coding conventions. Customize for your project after running `/harness-init`.

## Naming

- **Files**: kebab-case (e.g., `user-service.ts`, `auth_provider.py`)
- **Functions/methods**: camelCase (JS/TS) or snake_case (Python/Go/Rust)
- **Types/classes**: PascalCase (e.g., `UserProfile`, `OrderRepository`)
- **Constants**: UPPER_SNAKE (e.g., `MAX_RETRIES`, `DEFAULT_TIMEOUT`)
- **Test files**: `[module].test.ts` or `test_[module].py`

> Customize above for your project. Enforce via `/taste-encoder`.

## File Size

- Maximum lines per source file: **300**
- When a file exceeds this limit, extract helpers into separate modules
- Enforced by: structural test `test_file_size_limits`

## Error Handling

- All errors at system boundaries (API, DB, external services) must be caught and wrapped
- Use typed errors, not raw strings
- Include context in error messages: what failed, why, how to fix
- Error messages are agent context — remediation instructions help both humans and agents

## Logging

- Use structured logging via the Providers interface
- Never use `console.log` / `print()` in production code
- Log levels: `error` (broken), `warn` (degraded), `info` (state change), `debug` (details)

## Concurrency Helpers

- Retry/timeout helpers: only in the approved location (e.g., `src/utils/concurrency.ts`)
- The approved version must include observability instrumentation
- Duplicate concurrency helpers are the #1 slop signal (OpenAI's real example)
- Enforced by: lint rule (see docs/LINTING.md)

## Cross-Cutting Concerns

- Auth, telemetry, feature flags: access only via the Providers interface
- Never import auth/telemetry libraries directly in business logic
- See [PROVIDERS.md](PROVIDERS.md) for the interface definition
