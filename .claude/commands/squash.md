# Squash

Squash all commits on the current branch into a single commit and force push to the remote.

## Steps

### 1. Guard rails

- Run `git branch --show-current` to get the current branch name.
- **If the branch is `main` or `master`:** stop immediately and tell me you cannot squash the default branch.

### 2. Find the divergence point

- Run `git merge-base main HEAD` to find where this branch diverged from `main`.
- Run `git log --oneline main..HEAD` to list commits that will be squashed.
- Print the commit list so I can see what's being squashed.
- **If there are 0 or 1 commits:** stop and tell me there's nothing to squash.

### 3. Collect commit messages

- Run `git log --oneline main..HEAD` to capture all commit messages before they're lost.

### 4. Squash

- Run `git reset --soft $(git merge-base main HEAD)` to collapse all commits into staged changes.
- Create a single commit using a HEREDOC. The message format should be:
  - **First line:** a brief description summarizing all changes in the branch.
  - **Blank line.**
  - **Commit history:** list each original commit as `- <hash> <message>` (from the log captured in step 3).
  - **Blank line.**
  - `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` trailer.

### 5. Force push

- Run `git push --force-with-lease` to update the remote branch.

### 6. Done

- Run `git log --oneline main..HEAD` to confirm the branch now has a single commit.
- Print the result.
