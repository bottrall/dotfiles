---
name: rebase
description: Rebase the current branch onto the latest default branch and resolve conflicts
disable-model-invocation: true
---

# Rebase

Rebase the current branch onto the latest `main` (or `master`) and resolve any conflicts.

## Steps

### 1. Guard rails

- Run `git branch --show-current` to get the current branch name.
- **If the branch is `main` or `master`:** stop immediately and tell me you cannot rebase the default branch onto itself.
- Run `git status` (never use `-uall`) to check for uncommitted changes.
- **If the working tree is dirty:** stop and tell me to commit or stash first. Do not stash automatically.

### 2. Detect the default branch

- Run `git symbolic-ref refs/remotes/origin/HEAD --short` to find the remote default (e.g. `origin/main`).
- Use the branch name after `origin/` as `<base>` for the rest of the steps.

### 3. Fetch the latest

- Run `git fetch origin` so the rebase targets the freshest remote tip.
- Run `git log --oneline HEAD..origin/<base>` to show what's being pulled in. If empty, stop and tell me the branch is already up to date.

### 4. Rebase

- Run `git rebase origin/<base>`.
- **If the rebase succeeds cleanly:** skip to step 6.
- **If there are conflicts:** continue to step 5.

### 5. Resolve conflicts

Repeat until the rebase is complete:

- Run `git status` to list conflicted files.
- For each conflicted file:
  - Read the file and resolve the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`).
  - Preserve the intent of **both sides** where possible — never blindly take one side.
  - If the resolution is non-obvious (semantic conflict, both sides changed the same logic), stop and ask me before guessing.
- Run any relevant checks for the touched files (typecheck, lint, or tests) when feasible to confirm the resolution compiles.
- Stage resolved files by name with `git add <file>` (never `git add -A` or `git add .`).
- Run `git rebase --continue`.
- If a commit becomes empty after resolution, run `git rebase --skip`.

**If the rebase becomes unsalvageable:** run `git rebase --abort` to return to the pre-rebase state and tell me what went wrong.

### 6. Force push

- Run `git push --force-with-lease` to update the remote branch.
- **If the branch has never been pushed:** use `git push -u origin <branch>` instead.

### 7. Done

- Run `git log --oneline origin/<base>..HEAD` to confirm the branch sits cleanly on top of `<base>`.
- Print the result.
