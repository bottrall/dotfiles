---
name: build
description: Autonomous build loop — pass a GitHub issue URL to start it in its own worktree, or describe the task
disable-model-invocation: true
---

# Build Loop

Drive a task to a green, shipped PR autonomously. One cycle is: **build → review → ship + CI**. Any surviving review finding or CI failure sends the loop back to build with the specifics; a clean review followed by green CI ends it.

This loop is **fully autonomous**. It never pauses between phases, and it pushes and opens a **draft** PR on its own. Run it only on a feature branch you're happy to ship from. It surfaces to me exactly twice: on success, or when it stops because the cycle cap was reached (or it's genuinely blocked).

## Inputs

- **The task**: the text passed when invoking the skill. If none was passed, use the task established in the current conversation. If neither is clear, that's the one time to stop and ask me what to build.
- **Cycle cap**: max number of build cycles before handing back. Default **3**. Honor an explicit override if I gave one.

Before starting, write a numbered checklist of the phases below in your reply and tick each one off as you go. Track a single **cycle counter** starting at 1. Every return to Phase 2 — whether triggered by review findings or CI failure — increments it. When the counter would exceed the cap, stop and hand back instead of looping.

## Criteria

The build is graded by the `inspect` skill against the shared criteria — ranked lenses, the HIGH SIGNAL bar, and the false-positive list — at `~/.agents/skills/inspect/criteria.md`. The builder sees exactly what the reviewers see, so it can self-review before handing back. The build subagent's prompt passes that path with the instruction to read it and hold it **verbatim**. Do not paraphrase it.

## Subagents

Phase 2 runs as a headless build subagent, and Phase 3's review fans out its own. Before spawning anything, activate the `riffer-subagent` skill and follow it for mechanics and prompt shape. A build child is the one read-only exception turned deliberate writer: its prompt states that it owns the worktree edits for its cycle, and it touches nothing else — no commits (Phase 4 owns committing), no GitHub writes.

## Phase 1 — Preflight (once)

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- **If the task is a GitHub issue** (URL, `#<n>`, or `<n>`) in this repo: `gh issue view <n> --json title,body,assignees` — its title and body are the task. Assign it to me (`gh issue edit <n> --add-assignee @me`) if I'm not assigned, and put `Closes #<n>` in the PR body in 4d. I've already made the worktree, so carry on with the branch bullets below.
- **If the current branch is the default branch:** create and switch to a feature branch with a short kebab-case name derived from the task, then report the branch name. Do not build directly on the default branch. Its base branch is the default branch.
- **If already on a feature branch:** use it. Its base branch is whatever it's stacked on — determine it exactly as the Review scope section of the `inspect` skill defines (activate `inspect` for it), and report it.

The base branch is what the review diffs against and what the PR targets.

## Phase 2 — Build

Spawn a build subagent to do the work for this cycle. It runs long — give it a generous `timeout` (an hour, not the review default). Its prompt must include, in this order:

1. **The criteria, verbatim.** The path `~/.agents/skills/inspect/criteria.md`, with the instruction to read it and hold it verbatim — this is exactly what the work will be reviewed against, and the builder must self-review its diff against every lens at the stated bar before handing back — see "For the builder" in the criteria.
2. **The rule files.** Before editing a file, it must read every rule file that governs it — `AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, and `.claude/rules/**` at the repo root **and in every directory between the root and that file**, as the `inspect` skill's rule-discovery step defines. Nested ones are easy to miss and just as binding — the Rules compliance lens audits against exactly those.
3. **The work for this cycle:**
   - **Cycle 1:** implement the task.
   - **Cycle > 1:** the sole job is to resolve the exact blockers carried over from the previous phase — quote the review findings and/or CI failures verbatim. Fix precisely those (plus whatever is strictly necessary to make the fix correct) without regressing anything already working.
4. **Verify locally before handing back.** It must run the tests that exercise the files it changed (the touched spec/test files and anything obviously covering them). A failing test is the builder's to fix in this cycle, not CI's to discover — a CI round is the most expensive way to find it.

Its report states what it did, what it verified, and anything it couldn't finish. It leaves the changes uncommitted — the review reads staged + unstaged work, and the ship phase handles committing.

## Phase 3 — Review (gates the loop)

Activate the `inspect` skill and run its **Steps** section exactly as written — preflight, rule discovery, summary, one reviewer per lens, validate every finding, filter, report. It performs the multi-agent review against the criteria and prints its report; that report is the sole input to the gate below. Phase 1 guarantees its preflight will not stop on the default branch.

Because **every surviving finding sends the loop back to Phase 2**, the review's HIGH SIGNAL bar and validation pass are what keep a false positive from burning a cycle. Review the diff as if someone else wrote it.

### Gate

Read the report the review printed.

- **"No issues found":** proceed to Phase 4.
- **Findings, and the cycle counter is below the cap:** increment the counter, carry the findings (grouped `path:line`, with reason tag and description, exactly as printed) into Phase 2, and loop.
- **Findings, and the cycle counter is at the cap:** stop. Hand back per the report format — do not ship.

## Phase 4 — Ship + CI (encoded)

### 4a. Commit

- Run `git status` (never `-uall`) and `git diff` to see uncommitted work.
- Stage relevant files by name (never `git add -A` / `git add .`), then commit — **staging and committing are separate commands, never chained.**
- Commit message: **Conventional Commits** (`feat:`, `fix:`, `chore:`…), written via HEREDOC, with the `Co-Authored-By: Riffer <noreply@riffer.dev>` trailer.
- Run `git status` after to verify.

### 4b. Push

- Determine the current branch. Run `git fetch origin`, then `git log origin/<branch>..HEAD`.
- **Unpushed commits:** `git push -u origin <branch>`. **Already up to date:** skip.

### 4c. Detect PR template

Use the **first** match, in order:

1. `.github/PULL_REQUEST_TEMPLATE.md`
2. `.github/pull_request_template.md`
3. `PULL_REQUEST_TEMPLATE.md`
4. `pull_request_template.md`
5. `.github/PULL_REQUEST_TEMPLATE/` (first `.md` file)

### 4d. Title & body

- PR title < 70 chars, derived from the branch commits.
- **Template found:** fill it from the diff (`git diff $(git merge-base <base-branch> HEAD)`) and commit history; leave a section empty rather than guessing.
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
🤖 Generated with [Riffer Rig](https://github.com/bottrall/riffer-rig)
```

### 4e. Create or update the PR

- `gh pr view --json url,body` to check for an existing PR on this branch.
- **None:** `gh pr create --draft --base <base-branch> --assignee @me --title "<title>" --body "$(cat <<'EOF'` … `EOF` … `)"`.
- **Exists:** if the generated body differs, `gh pr edit --body`; otherwise skip.
- `<base-branch>` is the bare branch name from Phase 1 (no `origin/` prefix), so a stacked PR targets its parent rather than the default branch.
- Print the PR URL.

### 4f. Monitor CI

- Watch the checks to completion: `gh pr checks <number> --watch` (fall back to polling `gh pr checks <number>` every ~30s via `sleep 30` if `--watch` is unavailable). Allow a short retry for checks to register after the push.
- **No checks configured:** note it — there's nothing gating — and treat CI as passed.
- **All pass:** mark the PR ready for review — `gh pr ready <number>` — then done → success report. (Only applies when the loop created the draft PR in 4e; if the PR already existed and wasn't a draft, this is a no-op.)
- **Any fail:** gather concrete failure detail — `gh pr checks <number>` plus the failing job's logs (`gh run view <run-id> --log-failed`).
  - Cycle counter **below** the cap: increment it, carry the CI failure detail into Phase 2, and loop (the next cycle re-runs the full review before re-shipping).
  - Cycle counter **at** the cap: stop and hand back.

## Reporting

### Success

State that the loop finished clean: cycles used, review clean, CI green, the PR URL, and that the PR is marked ready for review.

### Hand-back (cap reached or blocked)

Say plainly why it stopped and what's left for me. If it stopped on **review findings**, print them in the `inspect` skill's report format under this heading:

> ## Build loop — stopped at cycle cap
>
> Ran N cycle(s). Unresolved review findings:
>
> ---
>
> ### `<path>`
>
> #### 1. <Reason tag> — <one-line description>
>
> **Where:** `<path>:<line>` (or `<path>:<start>-<end>`)
>
> **Why:** <one or two sentences on what goes wrong and when>
>
> **Fix:** <prose on the same line, or a fenced replacement block on the next line>
>
> ---
>
> #### 2. <Reason tag> — <one-line description>
>
> **Where:** `<path>:<line>`
>
> **Why:** …
>
> **Fix:** …
>
> ---
>
> ### `<next path>`
>
> #### 3. <Reason tag> — <one-line description>
>
> …
>
> ---

Layout rules:

- **Sections.** One `###` heading per file, files ordered by path, findings within a file in ascending line order. A `---` rule follows the summary line and closes every finding, so every boundary — finding to finding, file to file — is a horizontal rule.
- **Numbering.** Sequential across the whole report (1…N), not per file, so any finding can be referred to as "finding 3".
- **Heading.** The reason tag is the lens name (Correctness, Security, Rules, Performance, Simplicity), then the one-line description.
- **Where.** `path:line` refs (clickable) — never GitHub blob URLs.
- **Why.** What goes wrong and when. For a rule finding, quote the rule and its file path here.
- **Fix.** Small self-contained fix: a fenced block with the replacement, only if applying it fully resolves the finding. Larger/multi-location fixes: describe in prose. If there is no concrete fix to suggest, omit the line.
- One finding per unique issue; no duplicates.

If it stopped on **CI failure**, report which checks failed, the key log excerpts, cycles used, and the PR URL.

## Notes

- This skill never posts review findings to GitHub — the only GitHub writes are the push, the draft PR, and the `gh pr ready` flip in Phase 4.
- The review scope always covers the full branch diff each cycle, so fixes can't silently regress previously-clean code.
