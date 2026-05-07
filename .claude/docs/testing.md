# Testing

Test files still follow the language doc — `typescript.md` for `*.test.ts`/`*.test.tsx`, `ruby.md` for `*_spec.rb` / `*_test.rb`. The universal principles in `CLAUDE.md` apply too — in particular, **DI is what makes "no mocking" practical**: pass real lightweight fakes in (an in-memory repository, a fake clock, a recording emailer), don't monkey-patch globals.

## Single Assertion Principle

One logical assertion per test. Each test should verify exactly one behavior.

## No Mocking

Don't mock code you own. If a function needs a dependency to work, test it with the real dependency — mocking it away means you're not testing real behaviour. If including the dependency is inconvenient, refactor the code to accept it via dependency injection so tests can supply a real (lightweight) alternative.

The only acceptable exception is third-party services that cannot be hit from the test suite (e.g., Stripe, SendGrid). Intercept those at the network boundary with a tool like MSW or VCR and route first-party requests to the real backend — do not fake your own modules.

## What to Test

Only test behaviour that can change. Don't assert on static output — a heading that's always rendered, a config object that's always the same shape. That's snapshot testing, and it's noise: it fails on cosmetic changes without catching real bugs.

Don't test TypeScript's job. The shape of data returned from a tRPC procedure, the type of a function's arguments, whether a value is a string — the compiler already guarantees these. Runtime tests that re-check them add no signal.

## Every Exported Function Gets a Test

Every exported function gets at least one test, even when there's nothing dynamic to assert. This is the caveat to "don't test static things": a minimal smoke test proves the function runs and gives future contributors a ready-made place to add cases as the function grows.

The minimum looks like:

- Function with an output → assert on the output.
- Function with no output → assert it doesn't throw.
- Presentational React component → render it and assert it's in the DOM.

For Ruby specifically: every public method on a `module ... extend self` API and every public class method intended as the class's API gets a smoke test. Private methods do not.

## Framework Conventions

### Ruby (RSpec)

Use RSpec where the project does. Structure: `describe` for the unit under test, `context` for scenarios, `it` for behaviour. Prefer `let` over instance variables. Prefer FactoryBot factories over fixtures — factories produce minimal valid records and fail loudly when the schema drifts.

```ruby
RSpec.describe Pricing do
  describe ".total" do
    context "with multiple line items" do
      it "sums the amounts" do
        items = [build(:line_item, amount: 5), build(:line_item, amount: 7)]
        expect(Pricing.total(items)).to eq(12)
      end
    end
  end
end
```

### TypeScript (Vitest / Jest)

Use whichever the project already uses. `describe` + `it`. Co-locate `*.test.ts` next to the source file rather than in a parallel `__tests__/` tree.

```ts
describe("add", () => {
  it("sums two Money values of the same currency", () => {
    const total = add(
      { amountCents: 100, currency: "USD" },
      { amountCents: 250, currency: "USD" },
    );
    expect(total.amountCents).toBe(350);
  });
});
```

## React Component Testing

- Use Testing Library; query by accessible role/label (`getByRole`, `getByLabelText`) rather than `data-testid` when an accessible query works.
- Prefer `userEvent` over `fireEvent` — closer to real interactions (focus, typing, modifier keys).
- Use `findBy*` for elements that appear async; don't sprinkle `waitFor` reflexively.
- Test from the user's perspective. Don't reach into component internals (props, state, refs); assert on what the user actually sees and does.

## Async Testing

- `await` promises explicitly. Don't `.then()`-chain in tests.
- Don't use fake timers unless the code under test depends on real time (debounce, polling, scheduled jobs).
