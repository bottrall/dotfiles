---
name: finish
description: Finish the work on the current branch — merge my PR as soon as it's mergeable and move its ticket to Done; for a PR I reviewed, just wrap up
disable-model-invocation: true
---

# Finish

Close out whatever this session's branch is about. Takes no argument — the context is the current branch and its PR.

<tracker>
!`cat ~/.claude/skills/_lib/tracker.md`
</tracker>

## 1. Context

- `git branch --show-current`. On the default branch: stop — there's nothing to finish.
- `gh pr view --json number,url,state,isDraft,author,headRefName,baseRefName,mergeable,mergeStateStatus,reviewDecision,closingIssuesReferences,reviews,isCrossRepository`. No PR: stop and say so.
- My login via `gh api user -q .login`. If the PR author is me, this is a **build** session — steps 2, 3. Otherwise it’s a **review** session — step 4.

## 2. Merge my PR

Skip to step 3 if it's already merged. If it was closed without merging, say so, don't touch the ticket, and stop.

**Preconditions — stop and report if any fail:**

- Local work not on the PR: `git status --porcelain` is non-empty, or `git log @{u}..HEAD` shows unpushed commits. Tell me to ship it first (`/ship`).
- A check has failed (`gh pr checks`): list the failed checks with their URLs.

**Make it mergeable:**

- Draft: `gh pr ready <n>`.
- `mergeStateStatus` is `BEHIND`: `gh pr update-branch <n>`, then wait for checks as below.

**Merge as soon as it can** — unless `~/.work.local.md` sets a merge process for this repo; then follow that instead of picking a method and merging, and still wait and handle conflicts as below:

- Merge method from `gh repo view --json squashMergeAllowed,rebaseMergeAllowed,mergeCommitAllowed,autoMergeAllowed,deleteBranchOnMerge`: squash if allowed, else rebase, else merge commit.
- `CLEAN` (or `HAS_HOOKS`): merge now — `gh pr merge <n> --<method>`. Don't pass `--delete-branch`; it tries to switch branches locally, which fails in a worktree.
- Otherwise, if auto-merge is allowed: `gh pr merge <n> --<method> --auto`, then wait for GitHub to merge it. If it isn't allowed: wait until `CLEAN`, then merge.
- **Waiting:** say in one line what it's waiting on (approval, pending checks), then poll in a background Bash loop — `gh pr view <n> --json state,mergeStateStatus,mergeable,statusCheckRollup` every 60s — that exits when the PR is merged or closed, a check fails, it becomes conflicting, or (without auto-merge) it reaches `CLEAN`. Act on whichever happened: merge, carry on to step 3, rebase, or stop and report.
- **Conflicts**, before merging or while waiting: rebase by following `~/.claude/skills/rebase/SKILL.md` (read it — it asks me when a resolution isn't obvious), then carry on waiting.
- After merging: if `deleteBranchOnMerge` is false and the PR isn't from a fork, `git push origin --delete <branch>`.

## 3. Close the ticket

`ticketFor(branch, pr)`, then `transition(ticket, Done)` for each ticket found. No ticket: say so and carry on.

## 4. Review session

Don't merge someone else's PR. Check `reviews` includes one from me; if not, say so.

## Report

Two or three lines: how the PR was merged (or that it already was), and what moved to Done — then remind me to archive this session, which removes the worktree.
