---
name: squash
description: Squash all commits on the current branch into a single commit and force push
disable-model-invocation: true
---

# Squash

Squash all commits on the current branch into a single commit and force push to the remote.

## Steps

### 1. Guard rails

- Run `git branch --show-current` to get the current branch name.
- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- **If the current branch is the default branch:** stop immediately and tell me you cannot squash the default branch.

### 2. Find the divergence point

- Determine `<base-branch>` — the branch this one is stacked on, not necessarily the default branch — exactly as the Review scope section of `~/.agents/skills/inspect/SKILL.md` defines (activate `inspect` for it).
- Run `git log --oneline <base-branch>..HEAD` to list the commits that will be squashed, and keep the output — it's needed for the commit message once the commits are gone.
- Print the commit list so I can see what's being squashed.
- **If there are 0 or 1 commits:** stop and tell me there's nothing to squash.

### 3. Squash

- Run `git reset --soft $(git merge-base <base-branch> HEAD)` to collapse all commits into staged changes.
- Create a single commit using a HEREDOC. The message format should be:
  - **First line:** a brief description summarizing all changes in the branch.
  - **Blank line.**
  - **Commit history:** list each original commit as `- <hash> <message>` (from the log captured in step 2).
  - **Blank line.**
  - `Co-Authored-By: Riffer <noreply@riffer.dev>` trailer.

### 4. Force push

- Run `git push --force-with-lease` to update the remote branch.

### 5. Done

- Run `git log --oneline <base-branch>..HEAD` to confirm the branch now has a single commit.
- Print the result.
