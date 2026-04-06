# Providers

Cross-cutting concerns interface. Fill in when running `/arch-guard`.

## What Are Providers?

Providers channel cross-cutting concerns (auth, telemetry, feature flags, logging)
through a single interface. This prevents agents from scattering these concerns
throughout the codebase.

> If one file calls `getFeatureFlag()` directly, agents will replicate that pattern
> everywhere. Providers ensure there's exactly one way to access cross-cutting services.

## Interface Definition

<!-- Define your Providers interface here -->

```typescript
// Example: src/providers/index.ts
export interface Providers {
  auth: AuthProvider;
  telemetry: TelemetryProvider;
  featureFlags: FeatureFlagProvider;
  logger: LoggerProvider;
}
```

## Rules

- All service/runtime code accesses cross-cutting concerns through Providers
- Never import auth/telemetry/feature-flag libraries directly
- The Providers interface is the single injection point
- Enforced by: `/arch-guard` skill and `arch-check.sh` hook

## Adding a New Provider

1. Define the interface in the Providers module
2. Implement the concrete provider
3. Register it in the Providers factory
4. Update this document
5. Add a structural test verifying no direct access
6. Run `/encode-mistake --proactive` to create a lint rule if needed
