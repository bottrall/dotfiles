---
name: dependabot
description: Review and merge open Dependabot PRs with risk assessment, fixing simple CI failures along the way
disable-model-invocation: true
---

# Dependabot

Review and merge open Dependabot PRs. Auto-merge low-risk updates, prompt for high-risk ones, push a fix to PRs whose CI failure is simple and mechanical, and retry PRs that hit conflicts after earlier merges.

## Steps

### 1. Fetch Dependabot PRs

- Run `gh pr list --author "app/dependabot" --state open` to get all open PRs.
- **If none found:** stop and tell me there are no open Dependabot PRs.
- Print the count and titles.
- Record the current branch (`git branch --show-current`) and whether the working tree is clean (`git status --porcelain`). Step 3a checks out PR branches, so the fix path is only available when the tree is clean; every checkout must return to this branch afterwards.

### 2. Process each PR

- Loop through the PR list. For each PR, run steps 3–6.
- Print a separator between PRs so output is easy to scan.

### 3. Check CI and mergeability

- Run `gh pr checks <number>` and `gh pr view <number> --json mergeable,mergeStateStatus`.
- **If CI is failing:** go to step 3a and try to fix it. Only skip permanently if 3a decides the failure is not simple.
- **If not mergeable (conflicts) or CI is pending:** move this PR to the back of the queue for retry later (step 7).
- **If no CI checks are configured:** note this as a risk factor and continue to step 4.

### 3a. Fix simple CI failures

Dependabot bumps often fail CI for mechanical reasons that have nothing to do with the update itself being unsafe: a generated lockfile or collection is now out of date, a formatter wants a rewrite, or a job flaked. Fix those; leave anything that needs judgement to me.

**Preconditions** — skip the fix (and the PR, permanently) if any fail:

- The working tree was clean in step 1. Never stash or discard my changes to make room.
- This PR has not already had a fix attempt in this run. One attempt per PR.
- The PR head branch lives in this repo (Dependabot branches always do; do not push to forks).

**Diagnose:**

- Run `gh pr checks <number> --json name,state,link` and, for each failing check, pull the failed log with `gh run view <run-id> --log-failed` (the run id is the number in the check's link). Read enough of the log to name the actual error, not just the job.
- Classify the failure using the table below. Every failing check must fall into a fixable category, or the PR is not simple.

| Failure | Fixable? | Fix |
| --- | --- | --- |
| RBS collection out of date (`rbs collection` complains the lockfile is stale, or Steep fails on missing signatures for the bumped gem) | Yes | `bundle exec rbs collection update` (or `install` if the project pins that way); commit `rbs_collection.lock.yaml` |
| Lockfile out of sync with manifest (`bundle install --frozen` / `npm ci` / `yarn install --immutable` / `pnpm install --frozen-lockfile` refuses) | Yes | Regenerate with the project's lockfile-only command (`bundle lock`, `npm install --package-lock-only`, `yarn install`, `pnpm install --lockfile-only`); commit the lockfile only |
| Formatter or linter with an autofix mode failing on files the bump touched or generated (`rubocop`, `prettier`, `eslint`, `biome`, `gofmt`) | Yes | Run the tool's fix mode on the reported files only; commit if the diff is purely formatting |
| Flaky or infra failure unrelated to the dependency (timeout, runner lost, network fetch failed, a test that passes on the base branch) | Rerun, not fix | `gh run rerun <run-id> --failed`, then defer the PR to step 7 |
| Test failures caused by changed behaviour in the dependency | No | Skip permanently; report the failing tests |
| Deprecation or removal requiring source changes (renamed API, removed option, new required config) | No | Skip permanently; report the log excerpt |
| Snapshot or fixture mismatches | No | Skip permanently — regenerating snapshots hides real behaviour changes |
| Anything you cannot name from the log | No | Skip permanently |

The bar for "simple": the fix is produced by a tool, touches only generated or formatting-only files, and needs no hand-written source change. If you find yourself editing application code, stop, restore the branch, and skip the PR.

**Apply:**

- `gh pr checkout <number>`.
- Run the fix command from the table. Reproduce the failing check locally where the project makes that cheap (e.g. `bundle exec steep check`, the lint command) so you know the fix actually addresses it before pushing.
- Inspect `git diff --stat`. If anything outside the expected generated/formatting files changed, `git checkout -- .` to restore and skip the PR.
- Commit with a **Conventional Commits** message describing what was regenerated and why, e.g. `fix: update rbs collection for rails 7.2 bump`, written via HEREDOC, with the `Co-Authored-By: Riffer <noreply@riffer.dev>` trailer.
- `git push` to the PR branch.
- Return to the branch recorded in step 1 (`git checkout <branch>`). Do this even if the fix failed.
- Move the PR to the deferred queue as **pending CI (fix pushed)** and continue with the next PR. Do not wait here.

**Dependabot after a manual push:** once someone else commits to its branch, Dependabot stops rebasing that PR itself, and `@dependabot rebase` or `@dependabot recreate` would throw the fix away. Never post those commands on a PR you have pushed to. If that PR later conflicts with the base branch (step 7), resolve it by merging the base branch into the PR branch locally and pushing, not via Dependabot.

### 4. Assess risk

Perform a three-part analysis:

- **Semver:** parse the version bump from the PR title (Dependabot uses "Bump X from A to B"). Major = high risk. Patch/minor = low risk baseline.
- **Changelog:** scan the PR body for breaking change indicators (`breaking`, `BREAKING CHANGE`, `deprecated`, `removed`, `migration`, `incompatible`). Any match = high risk.
- **Test coverage:** search the codebase for imports/requires of the package being updated. Identify which files use it. Then check if those files have corresponding test coverage (matching test files, or are themselves test files). If the dependency is used in areas with no test coverage, consider whether static analysis provides sufficient safety — for example, in a TypeScript project the type checker can catch breaking API changes at compile time even without unit tests. If the project has neither test coverage nor static analysis (e.g. plain JavaScript with no type checking) for the affected code, mark as high risk.

Risk matrix:

- **Low risk:** patch/minor bump + no breaking indicators + CI passing + usage areas have test coverage or static analysis (e.g. TypeScript).
- **High risk:** major bump OR breaking indicators found OR no CI checks configured OR dependency used in code with neither test coverage nor static analysis.

A fix pushed in step 3a does not change the risk level on its own — it was mechanical by definition. Mention it in the risk details, though, so I can see what was regenerated when a high-risk PR is put to me.

### 5. Decide

- Before merging, approve the PR with `gh pr review <number> --approve` — some projects require an approval before the PR is mergeable.
- **Low-risk:** auto-merge with `gh pr merge <number> --squash --delete-branch`.
- **High-risk:** print the risk details and ask me whether to merge or skip. Always use `--squash` when merging.

### 6. Log result

- Print the outcome for this PR: merged / skipped + reason / deferred + reason. If a fix was pushed, say what it was.

### 7. Retry deferred PRs

After the first pass, if there are PRs that were deferred (conflicts, pending CI, or a pushed fix from step 3a):

- Print which PRs are waiting and why (conflicts / pending CI / pending CI after fix).
- Poll every 30 seconds (`sleep 30` via the bash tool between rounds): run `gh pr view <number> --json mergeable,mergeStateStatus` and `gh pr checks <number>` for each deferred PR.
- When a deferred PR becomes mergeable with CI passing, process it through steps 4–6.
- When a deferred PR's CI fails and it has **not** had a fix attempt yet, send it through step 3a.
- When a deferred PR's CI fails **after** a fix attempt, skip it permanently and include the new failure in the report — the fix was wrong or incomplete, and a second guess is not worth my CI minutes.
- When a deferred PR that you pushed to reports conflicts, merge the base branch into it locally and push (see the note in 3a); never use `@dependabot rebase` on it.
- **Timeout:** stop polling a PR waiting on conflicts or on Dependabot's own CI after 3 minutes without progress. A PR waiting on CI for a fix you pushed gets 15 minutes, since a full CI run has to complete. Report anything still waiting as unresolved.

### 8. Done

Print a summary table of all processed PRs with columns: PR number, title, semver level, risk, fix pushed (none / what was regenerated), and outcome (merged / skipped + reason / unresolved).
