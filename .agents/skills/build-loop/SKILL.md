---
name: build-loop
description: Autonomous build loop
disable-model-invocation: true
---

# Build Loop

Drive a task to a green, shipped PR autonomously. One cycle is: **build → review → ship + CI**. Any surviving review finding or CI failure sends the loop back to build with the specifics; a clean review followed by green CI ends it.

This loop is **fully autonomous**. It never pauses between phases, and it pushes and opens a **draft** PR on its own. Run it only on a feature branch you're happy to ship from. It surfaces to me exactly twice: on success, or when it stops because the cycle cap was reached (or it's genuinely blocked).

## Inputs

- **The task**: the text passed when invoking the skill. If none was passed, use the task established in the current conversation. If neither is clear, that's the one time to stop and ask me what to build.
- **Cycle cap**: max number of build cycles before handing back. Default **3**. Honor an explicit override if I gave one.

Create a todo list before starting. Track a single **cycle counter** starting at 1. Every return to Phase 1 — whether triggered by review findings or CI failure — increments it. When the counter would exceed the cap, stop and hand back instead of looping.

## Phase 0 — Preflight (once)

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- **If the current branch is the default branch:** create and switch to a feature branch with a short kebab-case name derived from the task, then report the branch name. Do not build directly on the default branch.
- **If already on a feature branch:** use it.

## Phase 1 — Build

Launch a subagent to do the work for this cycle. It must read the project's own instructions and relevant language/rules docs before editing.

- **Cycle 1:** implement the task.
- **Cycle > 1:** the subagent's sole job is to resolve the exact blockers passed in from the previous phase — quote the review findings and/or CI failures verbatim. Fix precisely those (plus whatever is strictly necessary to make the fix correct) without regressing anything already working.

Leave the changes uncommitted — the review reads staged + unstaged work, and the ship phase handles committing.

## Phase 2 — Review (encoded, gates the loop)

A multi-agent review of the branch. Because **every surviving finding sends the loop back to Phase 1**, the bar is high signal only — a false positive burns a whole cycle. The validation pass exists to enforce that.

### Scope

All changes since the branch diverged from the default branch, **including staged and unstaged work**. Never use three-dot (`main...HEAD`) — it drops uncommitted changes.

- `BASE=$(git merge-base <default-branch> HEAD)` — recompute at the start of each review.
- Unified diff: `git diff $BASE`
- File list: `git diff --name-only $BASE`
- Stat: `git diff --stat $BASE`

Pass these exact commands to every review subagent. Each reviewer must read the changes via `git diff $BASE` — not `git diff main...HEAD`.

### 2a. Parallel review

Launch these five reviewers in parallel. Each receives the branch summary from 2b and the rule-file paths from 2a, and returns a list of findings — each with a `path:line` reference, a reason tag, and a one-line description.

1. **Rules compliance** — audit the changed code against the discovered rule files (`CLAUDE.md` + `.claude/rules`). For a `CLAUDE.md`, only apply it to files it shares a path with (the file or its parents). Files under `.claude/rules/` apply repo-wide unless the rule itself scopes them. Flag only clear, unambiguous violations where you can quote the exact rule and its source file path.

2. **Bug scan** — obvious, significant bugs in the diff itself, without reading outside context — but only within the changed code.

3. **Security review** — look for injection (SQL/command/template), broken authn/authz, secrets or credentials in code, unsafe deserialization, SSRF, path traversal, missing input validation, unsafe use of untrusted data, and similar — but only within the changed code.

4. **Performance review** — look for N+1 queries, missing pagination or indexes, accidental O(n²) or repeated work in loops, unnecessary allocations, blocking I/O on hot paths, and similar — but only within the changed code. We're only looking for major perforomance issues, readability > than a small performance win.

5. **Simplify / idiomatic review** — what the changed code could drop or collapse (dead code, redundant branches, needless abstraction, duplication) and where it diverges from the idioms of its language/framework (per the project's language docs and conventions). Every finding must name a concrete, mechanical change and the idiomatic replacement — never a vague "could be cleaner."

**HIGH SIGNAL only.** Flag a finding only when:

- The code will fail to compile/parse (syntax, type errors, missing imports, unresolved references), or
- It will definitely produce wrong results regardless of input (clear logic errors), or
- It's a clear security or performance defect in the changed code, or
- It's an unambiguous rule violation you can quote, or
- It's a concrete, clearly-beneficial simplification or idiom fix with a specific replacement.

Do **not** flag: subjective style preferences, issues that only manifest for specific unstated inputs/state, speculative improvements, or anything you're not certain is real.

### 2b. Validate

For each finding, launch a subagent to adversarially confirm it is real and worth fixing with high confidence — e.g. if "variable is not defined" was flagged, verify that's actually true in the code; for a rule finding, verify the rule is in scope for the file and actually violated. Drop any finding that doesn't survive.

### 2c. False-positive list

Never flag these (use in 2a and 2b):

- Pre-existing issues (outside the diff).
- Something that looks like a bug but is actually correct.
- Pedantic nitpicks a senior engineer would not raise.
- Issues a linter will catch (do not run the linter to verify).
- General code-quality gaps (e.g. lack of test coverage) unless a rule file explicitly requires otherwise.
- Issues silenced deliberately in the code (e.g. a lint-ignore comment).

### 2d. Gate

The surviving findings after 2c are blockers.

- **If any survive** and the cycle counter is **below** the cap: increment the counter, pass the findings (grouped `path:line`, with reason and description) to Phase 1, and loop.
- **If any survive** and the cycle counter is **at** the cap: stop. Hand back per the report format — do not ship.
- **If none survive:** proceed to Phase 3.

## Phase 3 — Ship + CI (encoded)

### 3a. Commit

- Run `git status` (never `-uall`) and `git diff` to see uncommitted work.
- Stage relevant files by name (never `git add -A` / `git add .`), then commit — **staging and committing are separate commands, never chained.**
- Commit message: **Conventional Commits** (`feat:`, `fix:`, `chore:`…), written via HEREDOC, with the `Co-Authored-By: Claude <noreply@anthropic.com>` trailer.
- Run `git status` after to verify.

### 3b. Push

- Determine the current branch. Run `git fetch origin`, then `git log origin/<branch>..HEAD`.
- **Unpushed commits:** `git push -u origin <branch>`. **Already up to date:** skip.

### 3c. Detect PR template

Use the **first** match, in order:

1. `.github/PULL_REQUEST_TEMPLATE.md`
2. `.github/pull_request_template.md`
3. `PULL_REQUEST_TEMPLATE.md`
4. `pull_request_template.md`
5. `.github/PULL_REQUEST_TEMPLATE/` (first `.md` file)

### 3d. Title & body

- PR title < 70 chars, derived from the branch commits.
- **Template found:** fill it from the diff (`git diff $BASE`) and commit history; leave a section empty rather than guessing.
- **No template:** use the format below — prefer prose over bullets; explain intent, don't restate the diff.

```
## Problem
<What problem does this solve and why it matters — user-visible symptoms, bug context, or motivation. Reference any linked issue.>

## Solution
<The approach and notable trade-offs. Call out anything subtle a reviewer might miss — migration ordering, feature flags, follow-up work.>

## Proof
<Evidence it works. If CI covers it, say so. If visual/UX, instruct: "Attach a screenshot of X". If it needs manual verification in a specific environment/dataset/integration, instruct the author to confirm and paste results.>
```

If you genuinely can't determine the problem or solution, leave a `<TODO: …>` placeholder rather than inventing intent. Always append:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### 3e. Create or update the PR

- `gh pr view --json url,body` to check for an existing PR on this branch.
- **None:** `gh pr create --draft --assignee @me --title "<title>" --body "$(cat <<'EOF'` … `EOF` … `)"`.
- **Exists:** if the generated body differs, `gh pr edit --body`; otherwise skip.
- Print the PR URL.

### 3f. Monitor CI

- Watch the checks to completion: `gh pr checks <number> --watch` (fall back to polling `gh pr checks <number>` every ~30s if `--watch` is unavailable). Allow a short retry for checks to register after the push.
- **No checks configured:** note it — there's nothing gating — and treat CI as passed.
- **All pass:** done → success report.
- **Any fail:** gather concrete failure detail — `gh pr checks <number>` plus the failing job's logs (`gh run view <run-id> --log-failed`).
  - Cycle counter **below** the cap: increment it, pass the CI failure detail to Phase 1, and loop (the next cycle re-runs the full review before re-shipping).
  - Cycle counter **at** the cap: stop and hand back.

## Reporting

### Success

State that the loop finished clean: cycles used, review clean, CI green, and the PR URL.

### Hand-back (cap reached or blocked)

Say plainly why it stopped and what's left for me. If it stopped on **review findings**, print them in this format:

> ## Build loop — stopped at cycle cap
>
> Ran N cycle(s). Unresolved review findings:
>
> ### `<path>:<line>` (or `<path>:<start>-<end>`)
>
> **<reason tag>** — <one-line description>
>
> <optional suggested fix>

- Group by file, then ascending line. Use `path:line` refs (clickable) — never GitHub blob URLs.
- Small self-contained fix: include a fenced block with the replacement, but only if applying it fully resolves the finding. Larger/multi-location fixes: describe in prose.
- One finding per unique issue; no duplicates. Quote the rule and its file path for any rule finding.

If it stopped on **CI failure**, report which checks failed, the key log excerpts, cycles used, and the PR URL.

## Notes

- This skill never posts review findings to GitHub — the only GitHub writes are the push and the draft PR in Phase 3.
- The review scope always covers the full branch diff each cycle, so fixes can't silently regress previously-clean code.
