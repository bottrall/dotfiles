# Testing

## Single Assertion Principle

One logical assertion per test. Each test should verify exactly one behavior.

## No Mocking

Don't mock code you own. If a function needs a dependency to work, test it with the real dependency — mocking it away means you're not testing real behaviour. If including the dependency is inconvenient, refactor the code to accept it via dependency injection so tests can supply a real alternative.

The only acceptable exception is third-party services that cannot be hit from the test suite (e.g., Stripe, SendGrid). Intercept those at the network boundary with a tool like MSW and route first-party requests to the real backend — do not fake your own modules.

## What to Test

Only test behaviour that can change. Don't assert on static output — a heading that's always rendered, a config object that's always the same shape. That's snapshot testing, and it's noise: it fails on cosmetic changes without catching real bugs.

Don't test TypeScript's job. The shape of data returned from a tRPC procedure, the type of a function's arguments, whether a value is a string — the compiler already guarantees these. Runtime tests that re-check them add no signal.

## Every Exported Function Gets a Test

Every exported function gets at least one test, even when there's nothing dynamic to assert. This is the caveat to "don't test static things": a minimal smoke test proves the function runs and gives future contributors a ready-made place to add cases as the function grows.

The minimum looks like:

- Function with an output → assert on the output.
- Function with no output → assert it doesn't throw.
- Presentational React component → render it and assert it's in the DOM.
