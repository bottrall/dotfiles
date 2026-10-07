### Worktree

My worktrees live at `~/<repo>.worktrees/<branch>`, made by my `wta` shell helper (which also copies env files and starts dependency installs). riffer-rig can't move a running session into another directory (not available in riffer-rig yet): every tool works in the directory the session was started in. So `enter` makes sure the worktree exists, and if the session isn't already in it, hands off to a new session started there.

**repoFor(ref)** — the local clone to work in.

- GitHub URL with `<owner>/<repo>`: the clone whose `origin` matches — the current repo first, then each path from `zsh -ic repos` (`git -C <path> remote get-url origin`). None match: stop and say so.
- Anything else: the current repo. Not in a git repo: ask one prose question listing the `zsh -ic repos` paths, and wait for my reply.

Work from the repo's **main worktree** (`git -C <repo> worktree list --porcelain | head -1`). If the session is already in a linked worktree on the target branch, there's nothing to do. If it's in a linked worktree on a different branch, stop and tell me to start from the main checkout.

**branchForPR(pr)** — `gh pr view <n> -R <owner>/<repo> --json headRefName,isCrossRepository`. Same-repo PR: `headRefName`. Fork PR: `git -C <main> fetch origin pull/<n>/head:pr-<n>` and use `pr-<n>`.

**enter(repo, branch)**

1. `git -C <main> fetch origin --prune`.
2. If `git -C <main> worktree list --porcelain` already has the branch checked out, use that path. Otherwise, from the main worktree: `cd <main> && zsh -ic 'wta <branch>'` (checks out an existing local/remote branch, or branches a new one from the default branch), then read the path back from `git worktree list --porcelain` — don't guess it.
3. Report one line: repo, branch, path, and whether the worktree was new or existing.
4. If the session's working directory isn't the worktree path, stop the calling skill here and tell me to continue in a session started there: `cd <path> && riffer`, then the same `/skill:<name> <args>` I ran. Re-running it there finds the worktree already on the target branch and carries on.

**remove()** — for the worktree this session is on.

1. Note the current worktree path, branch, and main worktree first.
2. Run removal against the main worktree, since this session can't leave its own directory: `git -C <main> worktree remove <path>`, then `git -C <main> branch -D <branch>`. Never `--force`; if removal refuses because of uncommitted changes, show what's dirty and ask.
3. Make this the last command of the session: once the directory is gone every later tool call fails, so tell me it's removed and to close the session.
