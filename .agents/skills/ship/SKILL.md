---
name: ship
description: Prepare and open a pull request for the current branch
disable-model-invocation: true
---

# Ship

Prepare and open a pull request for the current branch.

## Steps

### 1. Preflight checks

- Run `git status` (never use `-uall`) and `git diff` (staged + unstaged) to check for uncommitted changes.
- If there are changes, stage and commit them. **Run staging and committing as separate commands — never combine them into a single chained command.**
  - Stage relevant files by name (never use `git add -A` or `git add .`).
  - Write a commit message using **Conventional Commits** (`feat:`, `fix:`, `chore:`, etc.).
  - Commit using a HEREDOC for the message and include the `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` trailer.
  - Run `git status` after committing to verify success.
- Run `git log --oneline main..HEAD` (or the repo's default branch) to confirm there are commits to ship. If the branch **is** the default branch, stop and tell me to create a feature branch first.

### 2. Push

- Determine the current branch name.
- Run `git fetch origin` then check `git log origin/<branch>..HEAD` to see if there are unpushed commits.
- **If there are unpushed commits:** push with `git push -u origin <branch>`.
- **If already up to date:** skip the push.

### 3. Detect PR template

Search for a pull request template in the repo. Check these paths **in order** and use the **first** match:

1. `.github/PULL_REQUEST_TEMPLATE.md`
2. `.github/pull_request_template.md`
3. `PULL_REQUEST_TEMPLATE.md`
4. `pull_request_template.md`
5. `.github/PULL_REQUEST_TEMPLATE/` (use the first `.md` file found)

### 4. Build PR title & body

- Derive a short PR title (< 70 chars) from the branch commits.
- **If a template was found:** fill it in using the branch's diff (`git diff main...HEAD`) and commit history. Leave any section empty rather than guessing.
- **If no template was found:** write a human-friendly description using the format below. Prefer prose over bullet lists — a reviewer should be able to read it top-to-bottom and understand the change without scanning the diff. Don't restate what the diff already shows; explain the intent.

```
## Problem
<What problem does this PR solve? Why does it matter? Include user-visible symptoms, bug context, or the motivation behind the feature. If there's a linked issue or ticket, reference it.>

## Solution
<How does this PR solve the problem? Explain the approach and any notable trade-offs or alternatives considered. Call out anything subtle a reviewer might otherwise miss (e.g. migration ordering, feature flags, follow-up work).>

## Proof
<Evidence the change works. State what's already covered and tell the author what's still needed:
- If CI fully covers it, say so explicitly ("CI is sufficient — see new tests in <file>").
- If the change is visual or UX-related, instruct the author: "Attach a screenshot of <X>" or "Attach a demo video showing <Y>".
- If it requires manual verification in a specific environment, dataset, or external integration, instruct the author to confirm those steps and paste the results.
- If reviewers need to run something locally, list the exact steps.>
```

Infer the content from the branch's diff, commit messages, and any linked issue. If you genuinely can't determine the problem or solution from the available context, leave a placeholder like `<TODO: describe the problem>` rather than inventing one — better to flag the gap than fabricate intent. For **Proof**, always include explicit instructions to the author for any evidence you can't produce yourself (screenshots, videos, manual test output).

- Always append the following footer to the body:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

### 5. Create or update the PR

- Run `gh pr view --json url,body` to check if a PR already exists for the current branch.
- **If no PR exists:** create one:

```
gh pr create --draft --assignee @me --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

- **If a PR already exists:** compare the generated body against the existing body.
  - **If the body has changed:** update it with `gh pr edit --body`.
  - **If the body is the same:** skip.

### 6. Done

Print the PR URL so I can review it.
