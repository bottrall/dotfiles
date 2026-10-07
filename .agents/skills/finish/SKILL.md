---
name: finish
description: Finish the work on the current branch — merge my PR as soon as it's mergeable and close its issue; for a PR I reviewed, just wrap up
disable-model-invocation: true
---

# Finish

Close out whatever this session's branch is about. Takes no argument — the context is the current branch and its PR.

## 1. Context

- `git branch --show-current`. On the default branch: stop — there's nothing to finish.
- `gh pr view --json number,url,state,isDraft,author,headRefName,baseRefName,mergeable,mergeStateStatus,reviewDecision,closingIssuesReferences,reviews,isCrossRepository`. No PR: stop and say so.
- My login via `gh api user -q .login`. If the PR author is me, this is a **build** session — steps 2, 3. Otherwise it’s a **review** session — step 4.

## 2. Merge my PR

Skip to step 3 if it's already merged. If it was closed without merging, say so, don't touch the issue, and stop.

**Preconditions — stop and report if any fail:**

- Local work not on the PR: `git status --porcelain` is non-empty, or `git log @{u}..HEAD` shows unpushed commits. Tell me to ship it first (`/skill:ship`).
- `mergeable` is `CONFLICTING` / `mergeStateStatus` is `DIRTY`: tell me to rebase (`/skill:rebase`).
- A check has failed (`gh pr checks`): list the failed checks with their URLs.

**Make it mergeable:**

- Draft: `gh pr ready <n>`.
- `mergeStateStatus` is `BEHIND`: `gh pr update-branch <n>`, then wait for checks as below.

**Merge as soon as it can:**

- Merge method from `gh repo view --json squashMergeAllowed,rebaseMergeAllowed,mergeCommitAllowed,autoMergeAllowed,deleteBranchOnMerge`: squash if allowed, else rebase, else merge commit.
- `CLEAN` (or `HAS_HOOKS`): merge now — `gh pr merge <n> --<method>`. Don't pass `--delete-branch`; it tries to switch branches locally, which fails in a worktree.
- Otherwise, if auto-merge is allowed: `gh pr merge <n> --<method> --auto`, then wait for GitHub to merge it. If it isn't allowed: wait until `CLEAN`, then merge.
- **Waiting:** say in one line what it's waiting on (approval, pending checks), then poll in the foreground (riffer-rig has no background commands — not available in riffer-rig yet): a bash loop over `gh pr view <n> --json state,mergeStateStatus,mergeable,statusCheckRollup` every 60s, run with `timeout_ms: 600000`, that exits when the PR is merged or closed, a check fails, it becomes conflicting, or (without auto-merge) it reaches `CLEAN`. Act on whichever happened: merge, carry on to step 3, or stop and report. If the loop times out still waiting, stop and tell me to run `/skill:finish` again later — with auto-merge on, GitHub merges in the meantime and the rerun picks up at step 3.
- After merging: if `deleteBranchOnMerge` is false and the PR isn't from a fork, `git push origin --delete <branch>`.

## 3. Close the issue

For each of the PR's `closingIssuesReferences` that's still open (GitHub only auto-closes them on merges into the default branch): `gh issue close <n> --reason completed`. None: say so and carry on.

## 4. Review session

Don't merge someone else's PR. Check `reviews` includes one from me; if not, say so.

## Report

Two or three lines: how the PR was merged (or that it already was), and which issues closed — then remind me to remove the worktree with `wtd`.
