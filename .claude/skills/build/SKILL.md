---
name: build
description: Autonomous build loop that turns a task, GitHub issue, or Jira ticket into a reviewed draft PR with green CI. Use to create high quality PRs.
disable-model-invocation: true
---

# Build Loop

Drive a task to a green, launched PR autonomously. One cycle is: **build → review → launch + CI**. A HIGH SIGNAL review finding or CI failure sends the loop back to build with the specifics; in-passing findings are fixed without a cycle; a clean review followed by green CI ends it.

This loop is **fully autonomous**. It never pauses between phases, and it pushes and opens a **draft** PR on its own. Run it only on a feature branch you're happy to push from. It surfaces to me exactly twice: on success, or when it stops because the cycle cap was reached (or it's genuinely blocked).

## Inputs

- **The task**: the text passed when invoking the skill. If none was passed, use the task established in the current conversation. If neither is clear, that's the one time to stop and ask me what to build.
- **Cycle cap**: max number of build cycles before handing back. Default **3**. Honor an explicit override if I gave one.

Create a todo list before starting. Track a single **cycle counter** starting at 1. Every return to Phase 2 — whether triggered by review findings or CI failure — increments it. When the counter would exceed the cap, stop and hand back instead of looping.

## Criteria

The builder is graded by the `inspect` skill against its [criteria.md](../inspect/criteria.md) — ranked lenses, the two-tier bar, and the false-positive list. The builder sees exactly what the reviewers see, so it can self-review before handing back. It is inlined here so it can be passed **verbatim** into the build subagent's prompt. Do not paraphrase it.

<criteria>
!`cat ~/.claude/skills/inspect/criteria.md`
</criteria>

## Model selection

Every subagent launch includes a deliberate model choice, picked from whatever tiers the Agent tool currently exposes. No phase is mapped to a model — decide per launch, per cycle, by weighing:

- **Judgment density.** How much of the task is reasoning versus mechanical execution? Following explicit instructions (commit, push, fill a template, watch checks) needs far less capability than open-ended design or debugging.
- **Cost of a miss.** What happens if this subagent gets it wrong? A weak build gets caught by review; a weak launch step wastes a CI round. Work the loop double-checks can afford less capability than work it doesn't.
- **Ambiguity of the input.** A cycle-1 "implement the task" prompt is open-ended; a cycle-2 "fix exactly these quoted findings" prompt is nearly mechanical. The same phase can warrant different models on different cycles.
- **Recovery cost.** A cheap model that fails burns a subagent; a cheap model that _plausibly_ succeeds burns a whole cycle. When wrong-but-confident output is hard to detect downstream, pay for capability up front.

Omitting the model (inheriting the session's) is a valid choice, not a default — make it deliberately. State the chosen model in each launch so the decision is visible in the transcript.

This applies to anything delegated — a fully-encoded phase (like launch + CI) may be handed to a subagent when that's sensible, and it gets the same weighing as any other subagent. The review phase makes its own model choices per the `inspect` skill.

## Ticket

A ticket is a **GitHub issue** in this repo (URL, `#<n>`, or `<n>`) or a **Jira issue** (a key like `ABC-123`, or a `…/browse/ABC-123` URL). Its content is the task.

- **Preflight:** read it, then claim it — assign it to me only if it has no assignee; if someone else holds it, leave it. Move a Jira issue to **in progress**.
- **On success** (4b): move a Jira issue to **in review**. A hand-back leaves it where it is.

Bookkeeping never blocks the loop — if a step fails, carry on. Every report (preflight, success, hand-back) states the ticket's assignee, its Jira status, and anything skipped and why.

### GitHub issue

- **Read:** `gh issue view <n> --json title,body,assignees`.
- **Claim:** `gh issue edit <n> --add-assignee @me`.

### Jira issue

Use the Atlassian MCP; call `getAccessibleAtlassianResources` once for the `cloudId` and reuse it. Without it, build from any task text given alongside the key — a bare key means asking me for the task — and skip the bookkeeping.

- **Read:** `getJiraIssue` — summary and description, assignee, and status with its category (To Do / In Progress / Done).
- **Claim:** `atlassianUserInfo` for my `accountId`, then `editJiraIssue` with `fields: { "assignee": { "accountId": "<id>" } }`.
- **Move:** list the transitions out of the current status (`listJiraIssueTransitions` — via `discover` if it isn't a primary tool) and apply one with `transitionJiraIssue` by `transitionId`. Choose by **target status**, not transition name. Never move it to Done — the project's Jira automation handles that on merge. No fitting transition → leave it.
  - **In progress:** only from a To Do-category status, into an In Progress-category one (prefer `In Progress`).
  - **In review:** only from an In Progress-category status that isn't already a review status, into one whose name contains "review" (`In Review`, `Code Review`, …).

## Phase 1 — Preflight (once)

Run this phase in the main session, not a subagent, since it may move the session into a worktree.

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- **If the task is a ticket:** do its preflight steps per [Ticket](#ticket).
- Pick the branch and its base:
  - **The current branch is the default branch:** the branch is a new feature branch with a short kebab-case name derived from the task — prefixed with the key for a Jira issue (`ABC-123-fix-login`), so Jira links the branch and its PR. Never build directly on the default branch. Its base branch is the default branch.
  - **Already on a feature branch:** the branch is this one. Its base branch is whatever it's stacked on. Determine it exactly as the `inspect` skill's [Review scope](../inspect/SKILL.md) section defines.
- Ensure you're in a worktree, on the branch.
- Report the branch, its base, and the worktree path.

The base branch is what the review diffs against and what the PR targets.

## Phase 2 — Build

Launch a subagent to do the work for this cycle. Its prompt must include, in this order:

1. **The criteria, verbatim** (the `<criteria>` block above), with the instruction that this is exactly what its work will be reviewed against, and that it must self-review its diff against every lens at the stated bar before handing back — see "For the builder" in the criteria.
2. **The rule files.** Before editing a file, it must read every rule file that governs it — `CLAUDE.md`, `.claude/CLAUDE.md`, and `.claude/rules/**` at the repo root **and in every directory between the root and that file**, as the `inspect` skill's "Discover rule files" step defines. Nested ones are easy to miss and just as binding — the Rules compliance lens audits against exactly those.
3. **The work for this cycle:**
   - **Cycle 1:** implement the task.
   - **Cycle > 1:** its sole job is to resolve the exact blockers passed in from the previous phase — quote the review findings and/or CI failures verbatim — and apply any in-passing list carried alongside them. Fix precisely those (plus whatever is strictly necessary to make the fix correct) without regressing anything already working.
4. **Verify locally before handing back.** Run automatic fixes (formatters/linters) & the tests that exercise the files it changed (the touched spec/test files and anything obviously covering them). A failing test is the builder's to fix in this cycle, not CI's to discover — a CI round is the most expensive way to find it.

Leave the changes uncommitted — the review reads staged + unstaged work, and the launch phase handles committing.

## Phase 3 — Review (gates the loop)

Invoke the `inspect` skill via the Skill tool and run it exactly as written. It performs the multi-agent review against the criteria and prints its report; that report is the sole input to the gate below. Phase 1 guarantees its preflight will not stop on the default branch.

Because **every surviving finding sends the loop back to Phase 2**, the review's HIGH SIGNAL bar and validation pass are what keep a false positive from burning a cycle.

### Gate

Read the report the `inspect` skill printed. A finding's heading carries its tier: no suffix means HIGH SIGNAL, `(in-passing)` means Tier 2.

- **"No issues found":** proceed to Phase 4.
- **In-passing findings only:** apply them now, in the main session — small, policy-level edits of the kind the criteria's Tier 2 names, already located precisely by the review. This does not increment the cycle counter. Run the project's lint and typecheck entry points (`bin/lint`, `bin/typecheck`, or their equivalents) plus the touched tests, then proceed to Phase 4.
- **HIGH SIGNAL findings, and the cycle counter is below the cap:** increment the counter, pass the findings (grouped `path:line`, with reason tag and description, exactly as printed) **plus any in-passing list** to Phase 2, and loop — the builder resolves the blockers and applies the in-passing fixes in the same visit.
- **HIGH SIGNAL findings, and the cycle counter is at the cap:** stop. Hand back per the report format — do not launch.

## Phase 4 — Launch + CI

### 4a. Launch

Invoke the `launch` skill via the Skill tool and follow it to commit, push, and open or update the draft PR, with these overrides:

- `<base-branch>` is the one from Phase 1 — skip launch's own base-branch detection. Its default-branch stop can't fire; Phase 1 guarantees a feature branch.
- **Task is a ticket:** reference it in the body (under Problem when using launch's format) — `Closes #<n>` for a GitHub issue, `[ABC-123](<browse URL>)` for Jira.

When it prints the PR URL, carry on to 4b — don't stop there.

### 4b. Monitor CI

- Watch the checks to completion: `gh pr checks <number> --watch` (fall back to polling `gh pr checks <number>` every ~30s if `--watch` is unavailable). Allow a short retry for checks to register after the push.
- **No checks configured:** note it — there's nothing gating — and treat CI as passed.
- **All pass:** move a Jira ticket to in review per [Ticket](#ticket), then done → success report.
- **Any fail:** gather concrete failure detail — `gh pr checks <number>` plus the failing job's logs (`gh run view <run-id> --log-failed`).
  - Cycle counter **below** the cap: increment it, pass the CI failure detail to Phase 2, and loop (the next cycle re-runs the full review before re-launching).
  - Cycle counter **at** the cap: stop and hand back.

## Reporting

### Success

State that the loop finished clean: cycles used, review clean, CI green, and the PR URL.

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

- This skill never posts review findings to GitHub or Jira — beyond the ticket bookkeeping, the only writes are the push and the draft PR in Phase 4.
- The review scope always covers the full branch diff each cycle, so fixes can't silently regress previously-clean code.
