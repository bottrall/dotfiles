# Dependabot

Review and merge open Dependabot PRs. Auto-merge low-risk updates, prompt for high-risk ones, and retry PRs that hit conflicts after earlier merges.

## Steps

### 1. Fetch Dependabot PRs

- Run `gh pr list --author "app/dependabot" --state open` to get all open PRs.
- **If none found:** stop and tell me there are no open Dependabot PRs.
- Print the count and titles.

### 2. Process each PR

- Loop through the PR list. For each PR, run steps 3–6.
- Print a separator between PRs so output is easy to scan.

### 3. Check CI and mergeability

- Run `gh pr checks <number>` and `gh pr view <number> --json mergeable,mergeStateStatus`.
- **If CI is failing:** skip this PR permanently and log the reason.
- **If not mergeable (conflicts) or CI is pending:** move this PR to the back of the queue for retry later (step 7).
- **If no CI checks are configured:** note this as a risk factor and continue to step 4.

### 4. Assess risk

Perform a three-part analysis:

- **Semver:** parse the version bump from the PR title (Dependabot uses "Bump X from A to B"). Major = high risk. Patch/minor = low risk baseline.
- **Changelog:** scan the PR body for breaking change indicators (`breaking`, `BREAKING CHANGE`, `deprecated`, `removed`, `migration`, `incompatible`). Any match = high risk.
- **Test coverage:** search the codebase for imports/requires of the package being updated. Identify which files use it. Then check if those files have corresponding test coverage (matching test files, or are themselves test files). If the dependency is used in areas with no test coverage, consider whether static analysis provides sufficient safety — for example, in a TypeScript project the type checker can catch breaking API changes at compile time even without unit tests. If the project has neither test coverage nor static analysis (e.g. plain JavaScript with no type checking) for the affected code, mark as high risk.

Risk matrix:

- **Low risk:** patch/minor bump + no breaking indicators + CI passing + usage areas have test coverage or static analysis (e.g. TypeScript).
- **High risk:** major bump OR breaking indicators found OR no CI checks configured OR dependency used in code with neither test coverage nor static analysis.

### 5. Decide

- Before merging, approve the PR with `gh pr review <number> --approve` — some projects require an approval before the PR is mergeable.
- **Low-risk:** auto-merge with `gh pr merge <number> --squash --delete-branch`.
- **High-risk:** print the risk details and ask me whether to merge or skip. Always use `--squash` when merging.

### 6. Log result

- Print the outcome for this PR: merged / skipped + reason.

### 7. Retry deferred PRs

After the first pass, if there are PRs that were deferred (conflicts or pending CI from step 3):

- Print which PRs are waiting and why (conflicts / pending CI).
- Poll every 30 seconds: run `gh pr view <number> --json mergeable,mergeStateStatus` and `gh pr checks <number>` for each deferred PR.
- When a deferred PR becomes mergeable with CI passing, process it through steps 4–6.
- When a deferred PR's CI fails, skip it permanently.
- **If no progress is made after 3 minutes:** stop polling and report the remaining deferred PRs as unresolved.

### 8. Done

Print a summary table of all processed PRs with columns: PR number, title, semver level, risk, and outcome (merged / skipped + reason / unresolved).
