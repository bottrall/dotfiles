# Review Criteria

The single source of truth for what a change is graded on. The builder reads it before writing code, every reviewer applies it, and every validator checks findings against it. Same text, same bar, no surprises.

## Priority

When two criteria genuinely conflict on the same code, the higher-ranked one wins. A criterion only enters a conflict if the concern meets **the bar** below — a hypothetical, minor, or speculative concern never outranks anything.

1. **Correctness** — the code does what the task requires and does not break what already worked.
2. **Security** — no exploitable defect in the changed code.
3. **Rules compliance** — the project's rule files (`AGENTS.md`) are followed.
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

3. **Rules compliance** — audit the changed code against the discovered rule files; an `AGENTS.md` governs the files under its directory. Every rule check ends in a **catalog**: what the rule governs in this diff, each item with a verdict — or a count plus the method used, when the set is too large to itemize. Counts must be recomputable from the diff (`grep`-able claims, not unverifiable prose), and the catalog must be the coarsest that still proves the audit ran — a mostly-compliant inventory collapses to a count. Findings-only audits cannot distinguish "checked everything" from "checked nothing"; the catalog can. What the governed artifact classes are comes from the project's rule files — these criteria name none. A non-compliant item is a finding at the bar below: unambiguous → Tier 1, judgement → Tier 2. A rule that cannot name what it governs is not yet a rule — report the rule itself.

4. **Performance** — N+1 queries, missing pagination or indexes, accidental O(n²) or repeated work in loops, unnecessary allocations, blocking I/O on hot paths, and similar. Major issues only.

5. **Simplicity / idiom** — what the changed code could drop or collapse (dead code, redundant branches, needless abstraction, duplication) and where it diverges from the idioms of its language or framework, per the project's conventions and rule files. Every finding must name a concrete, mechanical change and the idiomatic replacement — never a vague "could be cleaner."

## The bar

Findings come in two tiers, split by one question: **is this certain, or is it a judgement the owner would plausibly make?**

### Tier 1 — HIGH SIGNAL (sends the loop back)

Flag a finding only when at least one of these holds:

- The code will fail to compile/parse (syntax, type errors, missing imports, unresolved references).
- It will definitely produce wrong results regardless of input (clear logic error).
- It is a clear security or performance defect in the changed code.
- It is an unambiguous rule violation that can be quoted with its source file path.
- It is a concrete, clearly-beneficial simplification or idiom fix with a specific replacement.

A false positive at this tier costs a whole build cycle and erodes trust.

### Tier 2 — In-passing (reported, fixed without a cycle)

A judgement-call finding on the changed code that is cheap and safe to apply:

- A classification from the catalog of a principle rule: the item fails a policy the project's rule files state in a way that requires judging weight rather than matching a form — for example, where a project defines a comment policy, an item that restates the code, repeats a type the signature states, narrates history, or sits in the wrong place.
- A small divergence from a written convention (naming, idiom) with a concrete replacement.

Tier 2 findings are not adversarially validated and do not send the loop back — they are fixed in passing before launch. The bar for reporting one is lower: would the owner plausibly rule this way? The cost of a false positive is seconds; the cost of silence is the owner re-catching it by hand after launch, which has happened repeatedly. Subjective style preferences with no anchor in a rule file or the project's conventions are still not findings at any tier.

Do **not** flag (either tier): issues that only manifest for specific unstated inputs or state, speculative improvements, or anything not real.

## Never flag (false-positive list)

- Pre-existing issues (outside the diff).
- Something that looks like a bug but is actually correct.
- Issues a linter will catch (do not run the linter to verify).
- General code-quality gaps (e.g. lack of test coverage) unless a rule file explicitly requires otherwise.
- Issues silenced deliberately in the code (e.g. a lint-ignore comment).

## For the builder

Before handing back, self-review your diff against every lens at the stated bar, in priority order, and fix what you find. Do **not** add code to pre-empt a lens the bar would not trigger — defensive checks on trusted data, speculative abstractions, or premature optimisation trade a phantom finding for a real simplicity one.
