---
name: apply-review
description: Find and address REVIEW comments in files changed on the current branch
---

# Apply Review

Find and address all `REVIEW:` comments in files changed on the current branch.

## Steps

### 1. Determine changed files

- Run `git diff --name-only main...HEAD` to list files changed on this branch.
- **If `$ARGUMENTS` is provided:** filter the list to files matching the glob pattern.
- **If no files remain:** stop and tell me there's nothing to review.

### 2. Find review comments

- Search the changed files for `REVIEW:` inside any comment syntax appropriate to the file type (e.g. `// REVIEW:`, `# REVIEW:`, `<!-- REVIEW:`, `/** REVIEW:`, `/* REVIEW:`, etc.).
- Collect each hit with its file path and line number.
- **If no comments are found:** stop and tell me there are no review comments to address.

### 3. List findings

- Print every review comment with its file path and line number so I can see the full list before work begins.

### 4. Address each comment

Process comments **one at a time**. For each comment:

- Read the surrounding code to understand context.
- If the code surrounding a review comment differs from what was originally committed, treat that as an intentional human edit — do not revert it.
- **If the comment is ambiguous or unclear:** stop and ask me for clarification before proceeding.
- Explain briefly what change is being made and why.
- Make the change. If addressing the comment requires changes in other files, make those too.
- Remove the review comment.

### 5. Verify

- Run relevant verification checks for the project.

### 6. Summary

- Print a concise summary listing each comment that was addressed and what changed.
