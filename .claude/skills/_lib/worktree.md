### Worktree

Work never happens in a repo's main checkout. It happens in a linked worktree, laid out the way pit lays them out: `~/<repo>.worktrees/<name>` beside the main checkout `~/<repo>`. Run these operations in the main session, never a subagent. The point is to move _this_ session, and a subagent's `EnterWorktree` only moves the subagent.

**where()** → `git rev-parse --path-format=absolute --git-dir --git-common-dir`. If the two match, this is the **main checkout**. If they differ, it's a **linked worktree**: one pit or Claude Code Desktop made, or one `enter` already moved into. The main checkout is the common dir's parent (`<main>` below).

**pathFor(name)** → `<parent of main>/<basename of main>.worktrees/<name>`. Names can contain `/`.

**enter(path)** → call `EnterWorktree` with `path`, loading it via ToolSearch if it's deferred. Then report one line: branch, path, and whether the worktree was new or existing. `EnterWorktree` only accepts an arbitrary path from the main checkout. From inside another worktree it only takes `.claude/worktrees/` paths. So only call this when `where()` says main checkout.

**ensureBuild(branch, default)**: from the main checkout, the worktree to build `branch` in.

1. `git -C <main> fetch origin --quiet`.
2. If `git -C <main> worktree list --porcelain` already has `branch` checked out in a linked worktree, `enter` that path. If the main checkout itself has it checked out, stop: git can't check out one branch twice, so tell me to switch the main checkout back to `default`.
3. Otherwise take `pathFor(branch)`. If it already exists, `enter` it. If not, add it, then `enter` it:
   - Local branch (`git -C <main> rev-parse --verify --quiet refs/heads/<branch>`): `git -C <main> worktree add <path> <branch>`.
   - Only on origin: `git -C <main> worktree add --track -b <branch> <path> origin/<branch>`.
   - New: `git -C <main> worktree add --no-track -b <branch> <path> origin/<default>`.

**ensureReview(pr)**: the PR checked out at its head on a local branch of its own, `pr-<n>-review`. Using its own branch means the PR's branch can stay checked out in its build worktree. The PR must be in the current repo (`gh repo view --json nameWithOwner`); if it isn't, stop and say so.

- **Main checkout:** `git -C <main> fetch origin --quiet`. Take `pathFor("review-<n>")`. If it doesn't exist, run `git -C <main> worktree add --detach <path>`. Then run `gh pr checkout <n> --branch pr-<n>-review --force` with `<path>` as the working directory. This resets the branch to the PR's head every time. Finally, `enter(path)`.
- **Linked worktree:** `enter` can't move the session from here, so check the PR out in place: `gh pr checkout <n> --branch pr-<n>-review --force`. First check `git status --porcelain`. If it isn't empty, stop and name the dirty files rather than carry them across.
