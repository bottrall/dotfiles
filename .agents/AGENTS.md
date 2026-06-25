# System Instructions

**Stack:** TypeScript, React, Node.js, Ruby, Rails

## Tooling

- Node.js projects: use `pnpm`
- Rails projects: use `bin/`

## Universal principles

These apply across every language. The language docs hold the language-specific idioms and examples that implement them.

### Functional patterns

- Prefer functional style: enumerable / array methods (`map`, `filter`, `reduce`) over manual loops.
- Favor immutability — return new values rather than mutating arguments.
- Write pure functions where possible; isolate side effects (I/O, DB, network) behind clear boundaries.

### Code organization

- Use a class only when an instance has identity, lifecycle, or mutable state. Otherwise use a module of pure functions.

**Smell:** a class whose methods are all `static` / `self.foo` is a module wearing pants. Make it a module.

### Inheritance and composition

Inheritance is _very strong_ coupling — stronger than people appreciate when they reach for it — and the costs only show up later, once the hierarchy has grown enough that backing out is expensive. Three failure modes to watch for:

- **You inherit everything, not just what you wanted.** `Penguin extends Bird` inherits `fly()`, which it can't actually do. Subclassing to reuse one method drags along every field, override surface, and assumption the parent has.
- **Real domains rarely decompose into clean single-parent trees.** A `BankAccount` is checking-vs-savings _and_ business-vs-personal _and_ domestic-vs-international. A single inheritance chain can only express one of those axes; the others become awkward flags or duplicated subtrees.
- **Deep chains hide where behavior comes from and inflate blast radius.** When `AdminUser extends PowerUser extends User extends ApplicationRecord`, finding which class defines a method requires walking the chain, and any change risks breaking subclasses you didn't know existed.

Default to **composition**: pass collaborators ("has-a") instead of inheriting from a parent ("is-a"). For shared _shape_, use an interface, structural type, or duck typing — that separates "usable in this context" from "kind of this thing", which inheritance conflates. Build small, focused units and assemble objects by combining the pieces they need, rather than locating them in a taxonomy.

Reserve `extends` / Ruby `<` for genuine "is-a" with shared _implementation_, or framework-mandated parents (`ApplicationRecord`, `Sidekiq::Worker`, NestJS providers, custom `Error` subclasses).

### Dependency injection

Don't construct or reach for collaborators inside a function or class — pass them in as arguments. The naive `new DatabaseClient()` inside a function (or a static `EmailService.send(...)`, or a singleton `Logger.instance`) produces four problems:

- **Hidden dependencies.** The signature lies. `processOrder(order)` looks like it takes one argument but really depends on a database, an emailer, the clock, and a logger. None of that shows at the call site.
- **Untestable in isolation.** No seam to substitute a fake. You either spin up the real dependency (slow, flaky) or monkey-patch (fragile). Testability isn't a separate concern — hard-to-test code is hard-to-change code in costume.
- **Locked-in choices.** Hard-coded `new StripeClient()` means switching providers requires editing every call site, not swapping configuration.
- **Coupling at a distance.** Static calls and singletons are dependencies too — invisible ones, with the additional problem of being harder to spot.

The pattern, stated plainly: accept collaborators as constructor or function parameters, typed as the **smallest interface** that captures what the function actually uses (`Emailer` with a `send` method, not `SendgridEmailService` with its 40-method API). Wire concrete implementations at the **application edge** — `main`, the entry point, a composition root. Business logic stays pure of construction concerns. A DI framework (NestJS providers, `dry-system`) is one way to automate the wiring; the pattern itself is just passing arguments.

```ts
// Hidden dependencies, untestable
function processOrder(order: Order) {
  const db = new DatabaseClient();
  const email = new EmailService();
  // ...
}

// Honest signature, swappable in tests
function processOrder(order: Order, db: Database, email: Emailer) {
  // ...
}
```

**Smell:** a function or class taking 8+ dependencies is doing too much — split it. DI makes coupling visible; visible coupling is what lets you notice when there's too much.

**Framework conventions are exempt.** A framework's own global collaborators — the ones it expects you to call by name — are idiomatic to reach for directly, not DI violations: Rails `ActiveRecord` models (`User.find`, `user.save`), `ActionMailer` (`UserMailer.welcome(user).deliver_later`), `ActiveJob`. They ship with first-class test seams (the test database, `ActionMailer::TestHelper` / `assert_emails`, `perform_enqueued_jobs`), so calling them in place costs none of the testability or swappability DI exists to protect — the seam is already there. The rule still binds collaborators that lack such a seam: third-party clients (`Stripe::Client`, an HTTP or S3 SDK) and your own service objects — inject those.

### Nesting

Never nest more than three levels deep. Two techniques to keep things flat:

- **Extraction.** When a block grows nested, lift the inner work into a separate, well-named function. The nesting doesn't disappear from the program but it disappears from any single place a reader has to comprehend at once. The function name acts as a cognitive checkpoint — the reader can decide whether they need to descend or trust the name.
- **Inversion (early returns / guard clauses).** Invert each precondition and return early when it fails, so the happy path sits at the base indentation:

```ts
function process(user) {
  if (!user) return;
  if (!user.isActive) return;
  if (!user.hasPermission) return;
  // happy path at the base indentation
}
```

Loops use `continue` for the same effect; error paths use early `return Result.err(...)` / `raise`.

### Error handling

- Don't use thrown exceptions for control flow. Return a Result/Either/discriminated union or `[:ok, value]` / `[:error, reason]` tuple instead.
- Reserve `throw` / `raise` for truly exceptional circumstances — programmer errors, unrecoverable state, framework-level boundaries.

### Comments and documentation

A comment exists to explain a **why** the code itself cannot — never a **how**, and never a restatement of what the code already says. This bar governs all prose, from inline comments to docstrings on the public API. Types are not prose's job: parameters, return values, and field types live in the type system (TypeScript types, RBS/rbs-inline `#:` annotations), not in comments that duplicate them.

- **Published library surface** — and _only_ a distributed package's public API (a gem, an npm module, a public SDK consumed by third parties) — gets at minimum a brief description on each exported symbol: one verb-first sentence on one line (`Serializes the definition to JSON.`). A second sentence is reserved strictly for a "why" — a non-obvious constraint or rationale — never a second sentence of "how". If a description needs more than one sentence to say _what_ it does, that's a smell the symbol does too much. _Exempt:_ a constant whose name and value already carry the full meaning (`VERSION = "0.30.0"`), and an empty namespace/placeholder whose members are documented individually. This floor does **not** reach inside an application: a symbol exported across modules of an app you ship as a whole (not as a package) is internal code, governed by the next bullet — give it a docstring only when it clears the why-bar there.
- **Internal and private code** — which is everything in an application, plus the non-exported internals of a library — is self-documenting via strong types and clear names. A comment survives here **only** if it explains a why a competent reader cannot recover from the code and names alone — a non-local constraint, an external-system quirk, a deliberate non-obvious tradeoff. A description of _what_ it does, or a why that's evident from the code, gets cut.
- **Inline comments** meet the same bar: kept only to explain the why of something genuinely ambiguous. `TODO` / `FIXME` / `HACK` markers are tracked work and stay; `NOTE` / `REVIEW` are subject to the why-rule.
- **No history.** A comment describes the present, never how the code got there. Change narration — "was X, now Y", "previously used Z" — has no place; the reader cares about what is, not what was. State a still-true constraint in the present tense ("the API returns null for empty results — guard"), never as the story of the bug that revealed it.

Language docs cover the docstring mechanics (JSDoc tags, RDoc directives, rbs-inline) for each ecosystem.

Don't hard-wrap markdown prose — write one line per paragraph and let it soft-wrap. (Hard-wrapping code comments at the usual column width is fine.)

## Language docs (REQUIRED before editing)

**Before writing or editing code, you MUST first read the relevant doc:**

- TypeScript / JavaScript / TSX / JSX → [docs/typescript.md](docs/typescript.md)
- Ruby (incl. Rails) → [docs/ruby.md](docs/ruby.md)
- Test files (`*.test.*`, `*.spec.*`, `*_spec.rb`, `*_test.rb`, files under `__tests__/`, `spec/`, `test/`) → [docs/testing.md](docs/testing.md)
