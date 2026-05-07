# Ruby Style

The universal principles in `CLAUDE.md` apply (functional patterns, code organization, inheritance/composition, DI, nesting, error handling, documentation). This doc covers Ruby-specific idioms and examples.

## Style

- Use blocks, `Proc`, and lambdas for composition — they're the Ruby-flavored equivalent of higher-order functions.
- Use `freeze` for shared constants and value objects.
- Prefer keyword arguments for clarity; avoid positional booleans.
- In application code, don't add Sorbet (`# typed:`) or RBS speculatively — only where the project already uses them. For library exports, see _Documentation_ below.

## Code Organization

Pick the right primitive for what you're modeling. Don't reflexively reach for `class` — that's a Rails-culture default that often produces the wrong shape.

### `class` — identity, lifecycle, mutable state

Use a class when an instance has its own life: it accumulates state, persists, holds a connection, processes a job. The test: are two instances with identical fields still meaningfully distinct, or does the object change over its lifetime? If yes, it's a class.

```ruby
class ShoppingCart
  def initialize
    @items = []
  end

  def add(item)
    @items << item
  end
end
```

Ruby-specific inheritance note: framework-mandated parents are fine — `ApplicationRecord`, `Sidekiq::Worker`, `ApplicationPolicy`. The general reasoning on inheritance lives in `CLAUDE.md`.

**Smell:** a class whose methods are all `def self.foo` is a module wearing pants. Make it a module with `extend self`.

### `module` — namespaces and cross-cutting traits

For a bag of pure functions — the Ruby equivalent of a TypeScript file that exports a few helpers — use `module ... extend self` and `private` for internal helpers:

```ruby
module Pricing
  extend self

  def total(line_items)
    line_items.sum { |item| item.amount }
  end

  private

  def round_cents(amount)
    amount.round(2)
  end
end

Pricing.total(items)
```

For traits attached to multiple unrelated host classes, use a mixin module that hosts `include` — that's the role `Comparable` and `Enumerable` play.

**Smell:** a mixin that demands the host implement several methods just to function is a service object in costume. Make it a class that takes the host as a constructor argument.

### `Data.define` — immutable value objects (Ruby 3.2+)

For immutable bundles of fields with value-equality semantics: `Money`, `Coordinate`, `DateRange`, parameter objects, result objects — anywhere two instances with the same fields should be considered equal and mutation doesn't make sense.

```ruby
Money = Data.define(:amount_cents, :currency) do
  def +(other)
    raise ArgumentError, "currency mismatch" unless currency == other.currency
    with(amount_cents: amount_cents + other.amount_cents)
  end

  def format
    "%.2f %s" % [amount_cents / 100.0, currency]
  end
end
```

- Use `Struct` when you need the same shape but mutability.
- Use a full `class` with `attr_reader` only when `Data` doesn't give you enough control.

Many patterns Rails codebases reach for a class for — PORO wrappers, parameter objects, result objects — collapse into `Data.define` plus a namespace module of operations. That shape is closer to how you'd write the equivalent in TypeScript and is easier to test and compose.

## Error Handling

Ruby-specific idioms (the universal "no `raise`/`rescue` for control flow" rule lives in `CLAUDE.md`):

- Return a result object: `dry-monads` `Success`/`Failure`, a custom result type, or a simple `[:ok, value]` / `[:error, reason]` tuple.
- Always rescue specific exception classes; never use a bare `rescue` (which silently catches `StandardError`, almost always wider than intended).

## Documentation

- Public APIs and libraries: provide thorough inline RBS signatures on exported methods.
- Internal Ruby code is self-documenting via clear method names and well-named locals — no comments that just restate the code.
