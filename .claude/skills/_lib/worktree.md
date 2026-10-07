### Worktree

My worktrees live at `~/<repo>.worktrees/<branch>`, made by my `wta` shell helper (which also copies env files and starts dependency installs). Run these operations in the main session, never a subagent — the point is to move _this_ session.

**repoFor(ref, candidates)** — the local clone to work in. `candidates` is optional: a list of `{ repo, subdir }` the caller already knows the work belongs to (from `pathsFor`).

- GitHub URL with `<owner>/<repo>`: the clone whose `origin` matches — the current repo first, then each path from `zsh -ic repos` (`git -C <path> remote get-url origin`). None match: stop and say so.
- With candidates: the current repo if it's one of them; otherwise the only one if there's one; otherwise the one the ticket names (a repo, engine, or remote in its summary or description). Still ambiguous: ask, offering the candidates as options. Return the chosen candidate's `subdir` too — if several candidates share the chosen repo, the one the ticket names, else none.
- Anything else: the current repo. Not in a git repo: ask which, offering the `zsh -ic repos` list as options.

Work from the repo's **main worktree** (`git -C <repo> worktree list --porcelain | head -1`). If the session is already in a linked worktree on the target branch, there's nothing to do. If it's in a linked worktree on a different branch, stop and tell me to start from the main checkout.

**branchForPR(pr)** — `gh pr view <n> -R <owner>/<repo> --json headRefName,isCrossRepository`. Same-repo PR: `headRefName`. Fork PR: `git -C <main> fetch origin pull/<n>/head:pr-<n>` and use `pr-<n>`.

**enter(repo, branch)**

1. `git -C <main> fetch origin --prune`.
2. If `git -C <main> worktree list --porcelain` already has the branch checked out, use that path. Otherwise, from the main worktree: `cd <main> && zsh -ic 'wta <branch>'` (checks out an existing local/remote branch, or branches a new one from the default branch), then read the path back from `git worktree list --porcelain` — don't guess it.
3. Call `EnterWorktree` with `path: <worktree path>`.
4. Report one line: repo, branch, path, and whether the worktree was new or existing.

**remove()** — for the worktree this session is on.

1. Note the current worktree path, branch, and main worktree first.
2. If this session entered it via `EnterWorktree`, call `ExitWorktree` with `action: "keep"` to return to the main checkout.
3. From the main worktree: `git worktree remove <path>`, then `git branch -D <branch>`. Never `--force`; if removal refuses because of uncommitted changes, show what's dirty and ask.
4. If the session was launched directly inside the worktree, `ExitWorktree` is a no-op — still remove it, then tell me the session's directory is gone and to close it.
