---
name: build-loop
description: Autonomous build loop
disable-model-invocation: true
---

# Build Loop

Drive a task to a green, shipped PR autonomously. One cycle is: **build → review → ship + CI**. Any surviving review finding or CI failure sends the loop back to build with the specifics; a clean review followed by green CI ends it.

This loop is **fully autonomous**. It never pauses between phases, and it pushes and opens a **draft** PR on its own. Run it only on a feature branch you're happy to ship from. It surfaces to me exactly twice: on success, or when it stops because the cycle cap was reached (or it's genuinely blocked).

**Agent assumptions (applies to all agents and subagents):**

- All tools are functional and will work without error. Do not test tools or make exploratory calls. Make sure this is clear to every subagent that is launched.
- Only call a tool if it is required to complete the task. Every tool call should have a clear purpose.

## Inputs

- **The task**: the text passed when invoking the skill. If none was passed, use the task established in the current conversation. If neither is clear, that's the one time to stop and ask me what to build.
- **Cycle cap**: max number of build cycles before handing back. Default **3**. Honor an explicit override if I gave one.

Create a todo list before starting. Track a single **cycle counter** starting at 1. Every return to Phase 1 — whether triggered by review findings or CI failure — increments it. When the counter would exceed the cap, stop and hand back instead of looping.

## Criteria

The builder is graded by the `code-review` skill against its [criteria.md](../code-review/criteria.md) — ranked lenses, the HIGH SIGNAL bar, and the false-positive list. The builder sees exactly what the reviewers see, so it can self-review before handing back. It is inlined here so it can be passed **verbatim** into the build subagent's prompt. Do not paraphrase it.

<criteria>
!`cat ~/.claude/skills/code-review/criteria.md`
</criteria>

## Model selection

Every subagent launch includes a deliberate model choice, picked from whatever tiers the Agent tool currently exposes. No phase is mapped to a model — decide per launch, per cycle, by weighing:

- **Judgment density.** How much of the task is reasoning versus mechanical execution? Following explicit instructions (commit, push, fill a template, watch checks) needs far less capability than open-ended design or debugging.
- **Cost of a miss.** What happens if this subagent gets it wrong? A weak build gets caught by review; a weak ship step wastes a CI round. Work the loop double-checks can afford less capability than work it doesn't.
- **Ambiguity of the input.** A cycle-1 "implement the task" prompt is open-ended; a cycle-2 "fix exactly these quoted findings" prompt is nearly mechanical. The same phase can warrant different models on different cycles.
- **Recovery cost.** A cheap model that fails burns a subagent; a cheap model that _plausibly_ succeeds burns a whole cycle. When wrong-but-confident output is hard to detect downstream, pay for capability up front.

Omitting the model (inheriting the session's) is a valid choice, not a default — make it deliberately. State the chosen model in each launch so the decision is visible in the transcript.

This applies to anything delegated — a fully-encoded phase (like ship + CI) may be handed to a subagent when that's sensible, and it gets the same weighing as any other launch. The review phase makes its own model choices per the `code-review` skill.

## Phase 0 — Preflight (once)

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- **If the current branch is the default branch:** create and switch to a feature branch with a short kebab-case name derived from the task, then report the branch name. Do not build directly on the default branch.
- **If already on a feature branch:** use it.

## Phase 1 — Build

Launch a subagent to do the work for this cycle. Its prompt must include, in this order:

1. **The criteria, verbatim** (the `<criteria>` block above), with the instruction that this is exactly what its work will be reviewed against, and that it must self-review its diff against every lens at the stated bar before handing back — see "For the builder" in the criteria.
2. **The rule files.** It must read the project's own rule files (`CLAUDE.md` + `.claude/rules`) before editing — the Rules compliance lens audits against exactly those.
3. **The work for this cycle:**
   - **Cycle 1:** implement the task.
   - **Cycle > 1:** its sole job is to resolve the exact blockers passed in from the previous phase — quote the review findings and/or CI failures verbatim. Fix precisely those (plus whatever is strictly necessary to make the fix correct) without regressing anything already working.
4. **Verify locally before handing back.** Run the tests that exercise the files it changed (the touched spec/test files and anything obviously covering them). A failing test is the builder's to fix in this cycle, not CI's to discover — a CI round is the most expensive way to find it.

Leave the changes uncommitted — the review reads staged + unstaged work, and the ship phase handles committing.

## Phase 2 — Review (gates the loop)

Invoke the `code-review` skill via the Skill tool and run it exactly as written. It performs the multi-agent review against the criteria and prints its report; that report is the sole input to the gate below. Phase 0 guarantees its preflight will not stop on the default branch.

Because **every surviving finding sends the loop back to Phase 1**, the review's HIGH SIGNAL bar and validation pass are what keep a false positive from burning a cycle.

### Gate

Read the report the `code-review` skill printed.

- **"No issues found":** proceed to Phase 3.
- **Findings, and the cycle counter is below the cap:** increment the counter, pass the findings (grouped `path:line`, with reason tag and description, exactly as printed) to Phase 1, and loop.
- **Findings, and the cycle counter is at the cap:** stop. Hand back per the report format — do not ship.

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
