---
name: land
description: PR merge driver. Use to get an open PR merged.
disable-model-invocation: true
---

# Land

Drive a pull request all the way to merged, then clean up the tickets it resolves. `launch` opens the PR; `land` finishes it.

This skill is **autonomous within a small-fix boundary**. Invoking it is my go-ahead to mark the PR ready, push fixes and rebases, reply to review comments, merge, and transition tickets. Anything bigger than a small fix is mine to decide — it stops and hands back rather than guessing.

## Inputs

- **The PR**: a URL, `#<n>`, or `<n>` passed when invoking the skill. With none, use the current branch's PR (`gh pr view`). If there's no PR, stop and tell me to run `launch` first.
- **Patience**: how long the PR can sit with nothing changing — no push, review, comment, or CI result — before handing back. Default **24 hours**; the clock restarts whenever something changes. Honor an override if I gave one (e.g. `/land 123 patience 3d`).
- **Fix cap**: max pushes of fixes (CI or feedback) before handing back. Default **3**. Rebases don't count toward it.

Create a todo list before starting. Track the fix counter and the set of feedback items already handled.

## What counts as small

A fix is **small** when all of these hold — otherwise it's a **stop**:

- **Intent is unambiguous.** The failing check or the reviewer says exactly what's wrong, and there's one obvious right fix.
- **It's describable in one sentence**, and a reviewer wouldn't need to re-review the reasoning behind it.
- **It stays inside the PR's footprint** — the files the PR already touches, plus whatever is strictly necessary (a lockfile, a snapshot, a test).
- **It doesn't change behavior beyond what was asked.**

Small, typically: lint or format failures, type errors and missing imports in this PR's code, a typo or rename a reviewer asked for, a nit, a test case a reviewer spelled out, an intended snapshot update, a lockfile regenerated after a rebase, a test expectation the rebase legitimately shifted.

Stop, typically: a design or approach change, new scope, a reviewer question that needs my opinion, disagreement with a human reviewer, a failure whose cause isn't clearly this PR or isn't clearly understood, anything touching data migrations, security, or public API shape that the PR didn't already intend.

## Steps

### 1. Preflight (once)

- `REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)` and `ME=$(gh api user -q .login)`.
- `gh pr view <n> --json number,url,title,body,state,isDraft,headRefName,baseRefName,headRefOid,isCrossRepository,maintainerCanModify,closingIssuesReferences,commits`.
  - **Already `MERGED`:** skip to step 4.
  - **`CLOSED`:** stop and tell me.
- **Stacked PR** — the base isn't the default branch (`git symbolic-ref refs/remotes/origin/HEAD`): stop and tell me to land the parent first. Merging into a parent branch isn't landing.
- **Fork without push access** (`isCrossRepository` and not `maintainerCanModify`): note that rebases and fixes are off the table — the skill can still merge if everything is already green, and stops on anything it would need to push.
- Get onto the PR branch: if the current branch isn't its head, ensure you're in a worktree, then `gh pr checkout <n>`. If the working tree is dirty, stop and tell me to commit or set it aside — never stash automatically.
- **Collect linked tickets now**, while the PR body and branch still exist (step 4 needs them):
  - **GitHub, closing:** `closingIssuesReferences` — the issues this PR resolves.
  - **GitHub, mentioned:** other `#<n>` or issue URLs in the title/body with no closing keyword.
  - **Jira:** keys matching `\b[A-Z][A-Z0-9]+-[0-9]+\b` in the branch name, title, body, and commit messages. A key in the branch name, the title, a commit subject, or a closing-style phrase in the body ("Closes", "Fixes", "Resolves", a `Jira:` field) is **resolved by this PR**; anywhere else ("related to", "follow-up in") is **mentioned**.
- **Open PRs stacked on this branch:** `gh pr list --base <headRefName> --state open --json number,title,url`. Record them for the report — GitHub retargets them when the branch is deleted, and they'll likely need a rebase.
- **Merge method:** a method stated in the repo's rule files or `CONTRIBUTING` wins. Otherwise `gh repo view --json squashMergeAllowed,mergeCommitAllowed,rebaseMergeAllowed` and prefer squash, then merge, then rebase.
- **Merge mechanism:** if the repo merges through something other than `gh pr merge` — a merge queue, auto-merge, a label or comment command a bot acts on — find it from the repo's config and docs, and use it in place of `gh pr merge` in 2f.
- **Draft:** `gh pr ready <n>`. This notifies reviewers — it's part of landing.
- Report the PR, its base, the merge method, and the linked tickets.

### 2. The landing loop

Each pass refreshes the PR's state, deals with whatever is blocking, and either merges, waits, or stops. Batch every small fix found in a pass — feedback and CI together — into one push, so each push costs one CI round.

#### 2a. Refresh

- `gh pr view <n> --json state,isDraft,headRefOid,mergeable,mergeStateStatus,reviewDecision,reviewRequests,latestReviews,reviews,comments,statusCheckRollup`
- Unresolved review threads:

  ```bash
  gh api graphql -F owner="${REPO%/*}" -F repo="${REPO#*/}" -F n=<n> -f query='
    query($owner:String!,$repo:String!,$n:Int!){repository(owner:$owner,name:$repo){pullRequest(number:$n){
      reviewThreads(first:100){nodes{id isResolved isOutdated path line
        comments(first:50){nodes{databaseId author{login} body createdAt url}}}}}}}'
  ```

- **`MERGED`** (a merge queue or someone else landed it): go to step 4. **`CLOSED`:** stop.

#### 2b. Triage feedback

Feedback is anything a reviewer — human or bot — has said that isn't handled yet:

- Unresolved review threads whose **last comment isn't mine** (`$ME`, or carries the signoff below).
- Reviews in `CHANGES_REQUESTED`, and review bodies with actionable content.
- Top-level PR comments posted since my last reply or since the PR was last pushed.

On the first pass, that's every unhandled item — not just new ones. Skip items already in the handled set. Classify each against **What counts as small**:

- **Small fix** → make it (2e), then reply on the thread with what changed and the commit SHA.
- **Factual question** the code answers → reply with the answer.
- **Bot suggestion that's wrong** (Copilot, CodeRabbit, and the like) → reply briefly with why, and move on.
- **Already addressed or outdated** (`isOutdated` and the concern no longer applies) → reply saying so.
- **Anything else** — design pushback, scope, a question for me, a human I'd disagree with → **stop**, quoting the comment.

Every reply goes out on my behalf without a draft, so it ends with the signoff:

> — 🤖 Claude (beep boop)

Reply in-thread with `gh api repos/$REPO/pulls/<n>/comments/<comment databaseId>/replies -f body=...`, or top-level with `gh pr comment <n> --body`. Don't resolve human reviewers' threads — that's their call. Resolve a bot's thread once its point is fixed or answered.

After pushing fixes for a human's `CHANGES_REQUESTED`, re-request their review: `gh pr edit <n> --add-reviewer <login>`.

#### 2c. Triage CI

From `statusCheckRollup`, for each failing check, pull the failed log: `gh run view <run-id> --log-failed` (the run id is in the check's link). Read enough to name the actual error, not just the job. For long logs, delegate the read to a subagent that returns the error lines and its diagnosis.

- **Flaky or infrastructure** (timeouts, network, runner errors, a test unrelated to the diff that passes on the base branch) → `gh run rerun <run-id> --failed`, once per check per run. A second failure is a stop.
- **Caused by this PR and small** → fix it (2e).
- **Anything else** → **stop** with the log excerpt.

#### 2d. Rebase when it's what's blocking

Rebase only when it's needed — a rebase reruns CI and can dismiss approvals:

- **`mergeStateStatus: DIRTY`** (conflicts) → rebase now.
- **`BEHIND`** → rebase only once nothing else is blocking (CI green, approved, feedback handled), since that's the moment it matters.

Follow the `rebase` skill (read `~/.claude/skills/rebase/SKILL.md`), with three overrides: rebase onto `origin/<baseRefName>`; resolve only conflicts whose resolution is mechanical (both sides' intent preserved without a judgment call — imports, adjacent edits, lockfiles regenerated, changelogs) and otherwise `git rebase --abort` and **stop** rather than asking; run the lint, typecheck, and tests covering the conflicted files before force-pushing with `--force-with-lease`.

#### 2e. Apply small fixes

- If the fix counter is at the cap, **stop** instead.
- Before editing a file, read the rule files that govern it (`CLAUDE.md`, `.claude/CLAUDE.md`, `.claude/rules/**`, at the root and in every directory down to the file).
- Make the fixes, then run the project's lint and typecheck entry points (`bin/lint`, `bin/typecheck`, or equivalents) and the tests covering the touched files. A local failure you can't fix small is a **stop**.
- Stage files by name (never `git add -A` / `git add .`), then commit — **staging and committing are separate commands, never chained**. Conventional Commits message via HEREDOC (e.g. `fix: address review feedback`, `fix: satisfy lint`), with the `Co-Authored-By: Claude <noreply@anthropic.com>` trailer. New commits, never amends.
- `git push`. Increment the fix counter. Then post the replies from 2b.

Pushing may dismiss existing approvals under branch protection; if it does, re-request review from the approvers.

#### 2f. Merge, wait, or stop

- **Ready to merge** — `mergeStateStatus` is `CLEAN` (or `HAS_HOOKS`), required checks pass, `reviewDecision` is `APPROVED` or empty, and no feedback is unhandled. Re-run 2a once more immediately before merging, in case a comment landed in the meantime. Then `gh pr merge <n> --<method> --delete-branch`, or the merge mechanism found in preflight.
  - Whatever the merge mechanism, triggering it is the merge. Take it only here, once the PR is ready to merge — never earlier as setup, even when the mechanism would hold the PR until it's approved. Applying it early tells reviewers the PR is cleared to merge, and it merges the moment an approval lands, with no final check in between.
  - **Merge queue:** gh enqueues the PR instead of merging. Keep looping until it's `MERGED`; if it's ejected, the next pass finds out why.
  - If the command errors, check `gh pr view <n> --json state` before treating it as a failure — in a worktree, gh can merge successfully and then fail to switch the local checkout. If the remote branch survived, `git push origin --delete <headRefName>`.
  - Never `--admin`, never bypass branch protection, never dismiss someone's review.
- **Review required but nobody's on it** — `REVIEW_REQUIRED` with no `reviewRequests` and no reviews: **stop** and ask me who should review.
- **Waiting** — on CI or on people: block until the PR changes, then start the next pass. Use the bundled waiter — it polls every minute while CI runs and every five minutes while only people are pending, retries failed polls rather than reading them as changes, and doesn't wake for individual checks passing, only for a failure or CI finishing:

  ```bash
  ~/.claude/skills/land/wait-for-pr <n> $(( $(date +%s) + <patience-seconds> ))
  ```

  Run it with `run_in_background` and end your turn — the harness wakes you when it exits, so an hours-long wait costs nothing in between. Don't read its output early or schedule other wakeups. Each wait gets a fresh deadline, which is what restarts the patience clock. It prints one line:

  - `changed` → start the next pass (2a).
  - `idle` → patience is spent with nothing changed: **stop** and report what the PR is waiting on.
  - `error <message>` → gh can't read the PR: **stop** with the message.

### 3. Stopping

When any step says **stop**: leave the branch and PR exactly as they are (abort any in-progress rebase), and hand back per **Reporting**. Don't reply on GitHub to say you've stopped — the stop is for me.

### 4. Clean up tickets

Run only once the PR is `MERGED`.

**GitHub issues.**

- **Closing references:** GitHub closes these on merge to the default branch. Confirm each with `gh issue view <n> --json state,stateReason`. If one is still open, `gh issue close <n> --reason completed --comment "Landed in <PR url>."` plus the signoff.
- **Mentions:** leave open; list them in the report.

**Jira tickets.** Use the Atlassian MCP tools (fetch the issue, list its transitions, transition, comment — use `discover` for any operation not already exposed). For each key **resolved by this PR**:

- Fetch it. A key that doesn't resolve is a false match (`UTF-8`, `SHA-256`) — drop it silently.
- **Already in a Done-category status** (often an integration moved it): skip.
- Otherwise move it to **Done**. My teams only use three statuses — To Do, In Progress, Done — so merged means done: never stop at an intermediate status (`In Review`, `Merged`, `Ready for QA`, `Ready for Release`, …). List its transitions and pick the one into a Done-category status that isn't a won't-do (`Won't Do`, `Cancelled`, `Duplicate`), preferring one named `Done`. If there's no such transition from the current status, or more than one candidate, don't guess — leave the ticket and list its options in the report.
- After transitioning, comment `Landed in <PR url>.` plus the signoff.

**Mentioned** Jira keys are left alone and listed in the report.

**Local.** `git fetch origin --prune`. Get off the branch first — git won't delete the branch you're on: if this run created the worktree, exit and remove it; otherwise switch to the default branch and `git pull --ff-only`. Then, if the local branch's tip equals the PR's final `headRefOid`, delete it (`git branch -D` — safe once merged; squash merges make `-d` refuse). If it has commits the PR never saw, keep it and say so.

## Reporting

### Landed

- PR URL, merge method, and the merge commit SHA (`gh pr view <n> --json mergeCommit`).
- Fixes pushed (one line each, with SHA), rebases done, reruns triggered.
- Feedback handled: what was replied to and how.
- Tickets: closed or transitioned (with the new status), skipped (already done), left alone (mentioned, or ambiguous with the options).
- Stacked PRs that were retargeted and now need landing.
- Local cleanup done.

### Stopped

Say plainly why it stopped and what decision or action is mine — quote the comment, the log excerpt, or the conflicting hunk. Then the PR's current state (CI, reviews, mergeability), what this run already did, and that `/land` picks up where it left off once I've dealt with it.
