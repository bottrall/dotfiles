# TypeScript Style

## Functional Patterns

- Prefer functional programming over imperative/OOP where practical
- Favor immutability, pure functions, and composition
- Avoid side effects; isolate them when necessary

## Code Organization

- Classes are for things with identity, lifecycle, or mutable state over time. If two instances with identical contents are still meaningfully distinct, or the object mutates over its lifetime, use a class. Otherwise don't.
- For value shapes (DTOs, parameter objects, result objects, config), use `type` with `readonly` plus a module of standalone operations — not a class.
- For operations that take inputs and return outputs, use exported functions in a module. File-local functions for internal helpers.
- Avoid `class` with only static methods — that's a module wearing pants. Use a module.
- Avoid inheritance hierarchies. Prefer composition; use `interface` for shared shape; reserve `extends` for genuine "is-a" with shared implementation or framework requirements (NestJS, TypeORM, custom `Error` subclasses).
- Prefer discriminated unions with exhaustive `switch` over class hierarchies for variant types — better narrowing, trivial serialization.
- Prefer composition or higher-order functions over mixin classes for cross-cutting behavior.

## Types

- Do not annotate function return types. Inferred types cannot lie; annotations can drift from what the function actually returns. The only exception is authoring a published library where explicit return types improve type-checker performance at the public API boundary.
- Avoid type casts (`as X`). Prefer `as const`, `satisfies`, type guards, or assertion functions. Use `as` only as a last resort when no safer option exists.

## Error Handling

- Do not use thrown errors for control flow. Return a Result/Either or discriminated union instead.
- Reserve `throw` for truly exceptional circumstances (programmer errors, unrecoverable state).

## Documentation

- Public APIs and libraries: provide thorough JSDoc on exported symbols.
- Internal code should be self-documenting via strong type definitions; don't add JSDoc that just restates the types.
