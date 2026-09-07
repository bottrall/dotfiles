---
name: build-loop
description: Autonomous build loop
disable-model-invocation: true
---

# Build Loop

Drive a task to a green, shipped PR autonomously. One cycle is: **build → review → ship + CI**. Any surviving review finding or CI failure sends the loop back to build with the specifics; a clean review followed by green CI ends it.

This loop is **fully autonomous**. It never pauses between phases, and it pushes and opens a **draft** PR on its own. Run it only on a feature branch you're happy to ship from. It surfaces to me exactly twice: on success, or when it stops because the cycle cap was reached (or it's genuinely blocked).

**Agent assumptions:**

- All tools are functional and will work without error. Do not test tools or make exploratory calls.
- Only call a tool if it is required to complete the task. Every tool call should have a clear purpose.

## Inputs

- **The task**: the text passed when invoking the skill. If none was passed, use the task established in the current conversation. If neither is clear, that's the one time to stop and ask me what to build.
- **Cycle cap**: max number of build cycles before handing back. Default **3**. Honor an explicit override if I gave one.

Before starting, write a numbered checklist of the phases below in your reply and tick each one off as you go. Track a single **cycle counter** starting at 1. Every return to Phase 1 — whether triggered by review findings or CI failure — increments it. When the counter would exceed the cap, stop and hand back instead of looping.

## Criteria

The build is graded by the `code-review` skill against the shared criteria — ranked lenses, the HIGH SIGNAL bar, and the false-positive list. The builder sees exactly what the reviewer sees, so it can self-review before handing back. Before Phase 1, read the file `~/.riffer/skills/code-review/criteria.md` with the read tool and hold it **verbatim** for the rest of the loop. Do not paraphrase it.

## Phase 0 — Preflight (once)

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- **If the current branch is the default branch:** create and switch to a feature branch with a short kebab-case name derived from the task, then report the branch name. Do not build directly on the default branch.
- **If already on a feature branch:** use it.

## Phase 1 — Build

Do the work for this cycle yourself, in this order:

1. **The criteria, verbatim.** This is exactly what the work will be reviewed against; you must self-review your diff against every lens at the stated bar before moving on — see "For the builder" in the criteria.
2. **The rule files.** Read the project's own rule files (`AGENTS.md`) before editing — the Rules compliance lens audits against exactly those.
3. **The work for this cycle:**
   - **Cycle 1:** implement the task.
   - **Cycle > 1:** the sole job is to resolve the exact blockers carried over from the previous phase — quote the review findings and/or CI failures verbatim. Fix precisely those (plus whatever is strictly necessary to make the fix correct) without regressing anything already working.
4. **Verify locally before moving on.** Run the tests that exercise the files you changed (the touched spec/test files and anything obviously covering them). A failing test is yours to fix in this cycle, not CI's to discover — a CI round is the most expensive way to find it.

Leave the changes uncommitted — the review reads staged + unstaged work, and the ship phase handles committing.

## Phase 2 — Review (gates the loop)

A skill cannot activate another skill mid-turn, so run the review in place: read the file `~/.riffer/skills/code-review/SKILL.md` with the read tool and follow its **Steps** section exactly as written — preflight, rule discovery, summary, one pass per lens, validate every finding, filter, report. It performs the single-agent review against the criteria and prints its report; that report is the sole input to the gate below. Phase 0 guarantees its preflight will not stop on the default branch.

Because **every surviving finding sends the loop back to Phase 1**, the review's HIGH SIGNAL bar and validation pass are what keep a false positive from burning a cycle. Review the diff as if someone else wrote it.

### Gate

Read the report the review printed.

- **"No issues found":** proceed to Phase 3.
- **Findings, and the cycle counter is below the cap:** increment the counter, carry the findings (grouped `path:line`, with reason tag and description, exactly as printed) into Phase 1, and loop.
- **Findings, and the cycle counter is at the cap:** stop. Hand back per the report format — do not ship.

## Phase 3 — Ship + CI (encoded)

### 3a. Commit

- Run `git status` (never `-uall`) and `git diff` to see uncommitted work.
- Stage relevant files by name (never `git add -A` / `git add .`), then commit — **staging and committing are separate commands, never chained.**
- Commit message: **Conventional Commits** (`feat:`, `fix:`, `chore:`…), written via HEREDOC, with the `Co-Authored-By: Riffer <noreply@riffer.dev>` trailer.
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
- **Template found:** fill it from the diff (`git diff $(git merge-base <default-branch> HEAD)`) and commit history; leave a section empty rather than guessing.
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

### 3e. Create or update the PR

- `gh pr view --json url,body` to check for an existing PR on this branch.
- **None:** `gh pr create --draft --assignee @me --title "<title>" --body "$(cat <<'EOF'` … `EOF` … `)"`.
- **Exists:** if the generated body differs, `gh pr edit --body`; otherwise skip.
- Print the PR URL.

### 3f. Monitor CI

- Watch the checks to completion: `gh pr checks <number> --watch` (fall back to polling `gh pr checks <number>` every ~30s via `sleep 30` if `--watch` is unavailable). Allow a short retry for checks to register after the push.
- **No checks configured:** note it — there's nothing gating — and treat CI as passed.
- **All pass:** done → success report.
- **Any fail:** gather concrete failure detail — `gh pr checks <number>` plus the failing job's logs (`gh run view <run-id> --log-failed`).
  - Cycle counter **below** the cap: increment it, carry the CI failure detail into Phase 1, and loop (the next cycle re-runs the full review before re-shipping).
  - Cycle counter **at** the cap: stop and hand back.

## Reporting

### Success

State that the loop finished clean: cycles used, review clean, CI green, and the PR URL.

### Hand-back (cap reached or blocked)

Say plainly why it stopped and what's left for me. If it stopped on **review findings**, print them in the `code-review` skill's report format under this heading:

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
