# TypeScript Style

The universal principles in `CLAUDE.md` apply (functional patterns, code organization, inheritance/composition, DI, nesting, error handling, documentation). This doc covers TypeScript-specific idioms and examples.

## Style

- Prefer a single options object over positional booleans — `fn({ admin: true, active: false })` not `fn(true, false)`. Names at the call site beat unlabeled flags every time.
- Named exports over default exports for non-React modules — they're refactor-safe and grep-able. React components may default-export per project convention.
- camelCase for values, PascalCase for types and components, SCREAMING_SNAKE for module-level constants.

## Code Organization

Pick the right primitive for what you're modeling. The default isn't `class` — that's an OOP-culture habit that often produces the wrong shape in TS.

### `class` — identity, lifecycle, mutable state

Use a class when an instance has its own life: it accumulates state, holds a connection, manages a subscription. The test: are two instances with identical fields still meaningfully distinct, or does the object change over its lifetime? If yes, it's a class.

```ts
class ShoppingCart {
  private items: Item[] = [];

  add(item: Item) {
    this.items.push(item);
  }
}
```

TS-specific inheritance note: reserve `extends` for framework requirements (NestJS providers, TypeORM entities, custom `Error` subclasses). The general reasoning on inheritance lives in `CLAUDE.md`.

**Smell:** a class whose methods are all `static` is a module wearing pants. Use a module of exported functions instead.

### `type` + module — value shapes and operations

For value shapes (DTOs, parameter objects, result objects, config), use `type` with `readonly` plus a module of standalone operations — not a class. This is the TS parallel of Ruby's `Data.define` + namespace module.

```ts
// money.ts
export type Money = {
  readonly amountCents: number;
  readonly currency: string;
};

export function add(a: Money, b: Money): Money {
  if (a.currency !== b.currency) throw new Error("currency mismatch");
  return { amountCents: a.amountCents + b.amountCents, currency: a.currency };
}

export function format({ amountCents, currency }: Money) {
  return `${(amountCents / 100).toFixed(2)} ${currency}`;
}
```

### Discriminated unions — variant types

Prefer discriminated unions over class hierarchies for variant types — better narrowing, trivial serialization, exhaustive `switch`.

```ts
type Result<T, E> =
  | { ok: true; value: T }
  | { ok: false; error: E };

function describe<T, E>(r: Result<T, E>) {
  switch (r.ok) {
    case true: return `value: ${r.value}`;
    case false: return `error: ${r.error}`;
  }
}
```

### React / JSX

- Function components only. No class components.
- Hooks at the top of the function body; never call hooks conditionally or inside loops.
- Default to server components in apps that support them; add `'use client'` only where you actually need interactivity, refs, or browser APIs.
- Prefer composition (`children`, slot props) over prop-heavy mega-components. Small, focused components are easier to read, test, and reuse.

**Smell:** props named `is*` / `has*` piling up usually means the component should split into focused variants — or the variant axis should become a discriminated union prop.

## Types

- Do not annotate function return types. Inferred types cannot lie; annotations can drift from what the function actually returns. The only exception is authoring a published library where explicit return types improve type-checker performance at the public API boundary.
- Avoid type casts (`as X`). Prefer `as const`, `satisfies`, type guards, or assertion functions. Use `as` only as a last resort when no safer option exists.
- Prefer `unknown` over `any` for values you haven't narrowed yet; refine with type guards or assertion functions.

## Error Handling

TS-specific idioms (the universal "no thrown errors for control flow" rule lives in `CLAUDE.md`):

- Use a `Result<T, E>` discriminated union (shown above) or a library like `neverthrow` for typed errors at boundaries.
- For genuinely exceptional cases, throw `Error` subclasses with discriminating fields — easier to filter than `instanceof` chains.

## Documentation

- Public APIs and libraries: provide thorough JSDoc on exported symbols, including `@param`, `@returns`, and `@example` where useful.
- Internal code is self-documenting via strong types and clear names. Don't add JSDoc that just restates the types.
