# Programming Style

## Functional Patterns

- Prefer functional programming over imperative/OOP where practical
- Favor immutability, pure functions, and composition
- Avoid side effects; isolate them when necessary

## TypeScript

- Do not annotate function return types. Inferred types cannot lie; annotations can drift from what the function actually returns. The only exception is authoring a published library where explicit return types improve type-checker performance at the public API boundary.
- Avoid type casts (`as X`). Prefer `as const`, `satisfies`, type guards, or assertion functions. Use `as` only as a last resort when no safer option exists.

## Error Handling

- Do not use thrown errors for control flow. Return a Result/Either or discriminated union instead.
- Reserve `throw` for truly exceptional circumstances (programmer errors, unrecoverable state).
