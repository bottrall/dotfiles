---
name: code-review
description: Multi-agent code review of changes on the current branch; reports findings inline in chat
---

# Code Review

Code review all changes on the current branch and report findings inline in chat. Do not post to GitHub.

This is the same review protocol as Phase 2 of the `build-loop` skill; the two are kept deliberately in sync. Only the disposition differs — this skill prints its findings, build-loop gates on them. Change one, change both.

**Agent assumptions (applies to all agents and subagents):**

- All tools are functional and will work without error. Do not test tools or make exploratory calls. Make sure this is clear to every subagent that is launched.
- Only call a tool if it is required to complete the task. Every tool call should have a clear purpose.

## Review scope

All changes since the current branch diverged from the default branch, **including staged and unstaged work**. Never use three-dot (`main...HEAD`) — it drops uncommitted changes.

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- `BASE=$(git merge-base <default-branch> HEAD)` — compute once at the start of the review.
- Unified diff: `git diff $BASE`
- File list: `git diff --name-only $BASE`
- Stat: `git diff --stat $BASE`

Pass these exact commands to every review subagent. Each reviewer must read the changes via `git diff $BASE` — not `git diff main...HEAD`.

## Model selection

Every subagent launch includes a deliberate model choice, picked from whatever tiers the Agent tool currently exposes. No step is mapped to a model — decide per launch by weighing:

- **Judgment density.** How much of the task is reasoning versus mechanical execution? Following explicit instructions (listing file paths, verifying a single quoted claim) needs far less capability than spotting what _isn't_ written in the diff.
- **Cost of a miss.** What happens if this subagent gets it wrong? A weak reviewer ships the bug; a weak validator drops a real finding or keeps a false one.
- **Ambiguity of the input.** An open-ended "find security problems" prompt is not the same task as "confirm this specific quoted finding is real."
- **Recovery cost.** When wrong-but-confident output is hard to detect downstream, pay for capability up front.

Generation and verification are asymmetric: checking work often demands more capability than producing it, because the checker must catch what the producer missed. Don't assume the validator can be weaker than the reviewer just because the finding is short.

Omitting the model (inheriting the session's) is a valid choice, not a default — make it deliberately. State the chosen model in each launch so the decision is visible in the transcript.

## Steps

Create a todo list before starting.

### 1. Preflight

Launch a subagent to verify there is something to review:

- Compute `BASE` as defined in the Review scope section.
- Run `git diff --stat $BASE`.
- If there are no changes (committed, staged, or unstaged), stop and tell me there's nothing to review.
- If the current branch **is** the default branch, stop and tell me to switch to a feature branch first (even if there are uncommitted changes).

### 2. Discover rule files

Launch a subagent to return a list of file paths (not contents) for all relevant rule files:

- The repo root `CLAUDE.md`, if it exists.
- Any `CLAUDE.md` in a directory containing a file modified on this branch (use `git diff --name-only $BASE`, which includes uncommitted changes).
- Any file under `.claude/rules/`.

### 3. Summarize the changes

Launch a subagent to summarize the branch. It should:

- Read `git diff $BASE` (committed + staged + unstaged) and `git log --oneline <default-branch>..HEAD` (commits only).
- Run `git status --porcelain`; if non-empty, note which files have uncommitted changes so the reviewers in step 4 have that context.
- Return a short summary of what the branch does.

### 4. Parallel review

Launch these five reviewers in parallel. Each receives the rule-file paths from step 2 and the branch summary from step 3, and returns a list of findings — each with a `path:line` reference, a reason tag, and a one-line description.

1. **Rules compliance** — audit the changed code against the discovered rule files (`CLAUDE.md` + `.claude/rules`). For a `CLAUDE.md`, only apply it to files it shares a path with (the file or its parents). Files under `.claude/rules/` apply repo-wide unless the rule itself scopes them. Flag only clear, unambiguous violations where you can quote the exact rule and its source file path.

2. **Bug scan** — obvious, significant bugs in the diff itself, without reading outside context — but only within the changed code.

3. **Security review** — look for injection (SQL/command/template), broken authn/authz, secrets or credentials in code, unsafe deserialization, SSRF, path traversal, missing input validation, unsafe use of untrusted data, and similar — but only within the changed code.

4. **Performance review** — look for N+1 queries, missing pagination or indexes, accidental O(n²) or repeated work in loops, unnecessary allocations, blocking I/O on hot paths, and similar — but only within the changed code. Only major performance issues; readability beats a small performance win.

5. **Simplify / idiomatic review** — what the changed code could drop or collapse (dead code, redundant branches, needless abstraction, duplication) and where it diverges from the idioms of its language/framework (per the project's conventions and rule files). Every finding must name a concrete, mechanical change and the idiomatic replacement — never a vague "could be cleaner."

**HIGH SIGNAL only.** Flag a finding only when:

- The code will fail to compile/parse (syntax, type errors, missing imports, unresolved references), or
- It will definitely produce wrong results regardless of input (clear logic errors), or
- It's a clear security or performance defect in the changed code, or
- It's an unambiguous rule violation you can quote, or
- It's a concrete, clearly-beneficial simplification or idiom fix with a specific replacement.

Do **not** flag: subjective style preferences, issues that only manifest for specific unstated inputs/state, speculative improvements, or anything you're not certain is real. False positives erode trust and waste reviewer time.

### 5. Validate

For each finding, launch a subagent to adversarially confirm it is real and worth fixing with high confidence — e.g. if "variable is not defined" was flagged, verify that's actually true in the code; for a rule finding, verify the rule is in scope for the file and actually violated. Drop any finding that doesn't survive.

### 6. Filter

Drop every finding that failed validation in step 5, plus anything on the false-positive list below. What remains is the final high-signal set.

### 7. Report findings inline in chat

**If no findings survived**, print exactly:

> ## Code review
>
> No issues found.

**If findings survived**, print a single markdown block:

> ## Code review
>
> Found N issue(s) across M file(s).
>
> ### `<path>:<line>` (or `<path>:<start>-<end>`)
>
> **<reason tag>** — <one-line description>
>
> <optional suggested fix>

- Group by file, then ascending line. Use `path:line` refs (clickable) — never GitHub blob URLs.
- Small self-contained fix: include a fenced block with the replacement, but only if applying it fully resolves the finding. Larger fixes (6+ lines, structural, or spanning multiple locations): describe in prose.
- One finding per unique issue; no duplicates. Quote the rule and its file path for any rule finding.

## False-positive list

Never flag these (use in steps 4 and 5):

- Pre-existing issues (outside the diff).
- Something that looks like a bug but is actually correct.
- Pedantic nitpicks a senior engineer would not raise.
- Issues a linter will catch (do not run the linter to verify).
- General code-quality gaps (e.g. lack of test coverage) unless a rule file explicitly requires otherwise.
- Issues silenced deliberately in the code (e.g. a lint-ignore comment).

## Notes

- This skill never touches GitHub. No `gh pr` commands, no inline-comment MCP calls.
