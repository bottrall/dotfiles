# Review Criteria

The single source of truth for what a change is graded on. The builder reads it before writing code, every reviewer applies it, and every validator checks findings against it. Same text, same bar, no surprises.

## Priority

When two criteria genuinely conflict on the same code, the higher-ranked one wins. A criterion only enters a conflict if the concern meets **the bar** below — a hypothetical, minor, or speculative concern never outranks anything.

1. **Correctness** — the code does what the task requires and does not break what already worked.
2. **Security** — no exploitable defect in the changed code.
3. **Rules compliance** — the project's rule files (`AGENTS.md`, `CLAUDE.md`, `.claude/rules/`) are followed.
4. **Performance** — no major performance defect. Readability beats a small performance win.
5. **Simplicity** — nothing the change could drop or collapse; idiomatic for its language and framework.

Worked examples of the conflict rule:

- A rule file mandates dependency injection. The simplicity lens sees the injected collaborator as needless indirection. Rules (3) beats simplicity (5): keep the injection.
- A guard re-validates a value that already arrived validated at a trust boundary. Security only enters the conflict if the missing check would be an actual defect. It would not, so simplicity (5) wins: drop the redundant guard.
- A memoization cache makes a hot path faster but hides a stale-read bug. Correctness (1) beats performance (4): fix or remove the cache.

## Lenses

Each lens is scoped to **the changed code only**. Pre-existing issues outside the diff are out of scope for every lens.

1. **Correctness** — obvious, significant bugs in the diff itself: code that will not compile or parse (syntax, type errors, missing imports, unresolved references), or logic that will definitely produce wrong results regardless of input. Judged from the diff without reading outside context.

2. **Security** — injection (SQL/command/template), broken authn/authz, secrets or credentials in code, unsafe deserialization, SSRF, path traversal, missing validation of **untrusted** input at a trust boundary, unsafe use of untrusted data, and similar.

3. **Rules compliance** — audit against the discovered rule files. An `AGENTS.md` or `CLAUDE.md` applies only to files it shares a path with (the file or its parents). Files under `.claude/rules/` apply repo-wide unless the rule itself scopes them. Flag only clear, unambiguous violations where the exact rule and its source file path can be quoted.

4. **Performance** — N+1 queries, missing pagination or indexes, accidental O(n²) or repeated work in loops, unnecessary allocations, blocking I/O on hot paths, and similar. Major issues only.

5. **Simplicity / idiom** — what the changed code could drop or collapse (dead code, redundant branches, needless abstraction, duplication) and where it diverges from the idioms of its language or framework, per the project's conventions and rule files. Every finding must name a concrete, mechanical change and the idiomatic replacement — never a vague "could be cleaner."

## The bar (HIGH SIGNAL only)

Flag a finding only when at least one of these holds:

- The code will fail to compile/parse (syntax, type errors, missing imports, unresolved references).
- It will definitely produce wrong results regardless of input (clear logic error).
- It is a clear security or performance defect in the changed code.
- It is an unambiguous rule violation that can be quoted with its source file path.
- It is a concrete, clearly-beneficial simplification or idiom fix with a specific replacement.

Do **not** flag: subjective style preferences, issues that only manifest for specific unstated inputs or state, speculative improvements, or anything not certain to be real. A false positive costs a whole build cycle and erodes trust.

## Never flag (false-positive list)

- Pre-existing issues (outside the diff).
- Something that looks like a bug but is actually correct.
- Pedantic nitpicks a senior engineer would not raise.
- Issues a linter will catch (do not run the linter to verify).
- General code-quality gaps (e.g. lack of test coverage) unless a rule file explicitly requires otherwise.
- Issues silenced deliberately in the code (e.g. a lint-ignore comment).

## For the builder

Before handing back, self-review your diff against every lens at the stated bar, in priority order, and fix what you find. Do **not** add code to pre-empt a lens the bar would not trigger — defensive checks on trusted data, speculative abstractions, or premature optimisation trade a phantom finding for a real simplicity one.
