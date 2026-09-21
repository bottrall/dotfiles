---
name: dependabot
description: Review and merge open Dependabot PRs with risk assessment, fixing simple CI failures along the way. Assesses every PR in parallel with one subagent each, sized to the PR.
disable-model-invocation: true
---

# Dependabot

Review and merge open Dependabot PRs. Auto-merge low-risk updates, prompt for high-risk ones, push a fix to PRs whose CI failure is simple and mechanical, and retry PRs that hit conflicts after earlier merges.

## How the work is split

The session that runs this skill is the **orchestrator**. It never checks out a PR branch and never leaves the branch it started on. Everything that touches a PR branch happens in a subagent's own worktree, and everything that touches GitHub state (approve, merge, rerun) happens in the orchestrator, one PR at a time.

| Role                            | Count              | Runs                                           | Touches                                     | Job                                                                                                                |
| ------------------------------- | ------------------ | ---------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| **Orchestrator** (this session) | 1                  | Foreground                                     | `gh` remote state only                      | Fetch, triage, pick a model per PR, launch subagents, merge, ask me about high-risk PRs, poll deferred PRs, report |
| **Assessor**                    | one per PR         | Parallel, background, in the main working tree | Nothing — read-only                         | Check CI and mergeability, diagnose any CI failure, assess risk, return a verdict                                  |
| **Fixer**                       | one per fixable PR | Parallel, background, `isolation: "worktree"`  | Its own worktree and the PR's remote branch | Apply the mechanical fix the assessor named, verify, commit, push                                                  |

Why this shape:

- Assessors are read-only, so any number can run at once in the main tree without stepping on each other or on my uncommitted work. Risk is assessed once, up front, for every PR — including PRs whose CI is still pending — so the retry loop later only has to re-check CI and mergeability.
- Fixers write, so each gets its own worktree. Two fixers regenerating two lockfiles in parallel never collide, and the main tree stays untouched, so the old "working tree must be clean" precondition is gone.
- Merges stay sequential in the orchestrator because each merge can invalidate the next PR's mergeability, and because the high-risk decision is mine to make — a background subagent cannot ask me.

A subagent's final report is not shown to me. Relay what matters from every verdict in the per-PR log line and the final summary.

## Model selection

Every subagent launch includes a deliberate model choice, picked from whatever tiers the Agent tool currently exposes. Tiers roughly double in price at each step from smallest to largest, and a Dependabot run can have dozens of PRs, so the saving comes from sending the mechanical majority to a small tier. The cost of a miss runs the other way: one wrongly merged breaking change costs more than every subagent in the run, so when a signal points at risk, pay for capability. Decide per launch by weighing:

- **Judgment density.** How much of the task is reasoning versus mechanical execution? Confirming that a green, patch-level bump of a dev dependency is what its title says needs far less capability than deciding whether a plain-JavaScript codebase with no tests would surface a renamed API at runtime.
- **Cost of a miss.** A weak assessor merges a breaking change or classifies an unfixable CI failure as fixable. A weak fixer pushes a commit that touches application code. Both are caught late and cost CI minutes or a revert.
- **Ambiguity of the input.** "Read this failing CI log and name the actual error" is open-ended; "run `bundle lock` and confirm only `Gemfile.lock` changed" is not.
- **Honesty under uncertainty.** The failure table's last row — _anything you cannot name from the log_ — only works if the assessor admits it cannot name it. Smaller tiers over-classify as fixable. A failing CI check is therefore a floor of the middle tier, regardless of the bump size.

### Signals the orchestrator has before launching

All of these come from the single `gh pr list --json` call in step 1 and cost nothing extra. Use them to size the assessor.

| Signal              | Where                                                                                                 | Pushes toward smaller tier                                                             | Pushes toward larger tier                                                                                                                       |
| ------------------- | ----------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| Semver level        | Title (`Bump X from A to B`) or the Dependabot commit footer's `update-type: version-update:semver-*` | Patch                                                                                  | Major; minor of a 0.x package (0.x minors are majors in disguise)                                                                               |
| Dependency type     | Commit footer `dependency-type`                                                                       | `direct:development`, `indirect`; GitHub Actions bumps (`dependabot/github_actions/…`) | `direct:production`                                                                                                                             |
| What the package is | Title / package name                                                                                  | Linter, formatter, test tooling, type stubs                                            | Framework, runtime, build tool, ORM, auth, HTTP client, anything the app is built on (rails, react, typescript, webpack, vite, devise, sidekiq) |
| Grouped update      | Title `Bump the X group … with N updates`                                                             | —                                                                                      | N > 1: every member needs its own semver and usage check                                                                                        |
| Breaking indicators | Body contains `breaking`, `BREAKING CHANGE`, `deprecated`, `removed`, `migration`, `incompatible`     | None                                                                                   | Any match                                                                                                                                       |
| CI state            | `statusCheckRollup`                                                                                   | All success                                                                            | Any failure (middle tier floor); multiple failing checks or no checks at all                                                                    |
| Diff shape          | `changedFiles`, `additions`, `deletions`                                                              | One or two manifest/lockfile files                                                     | Vendored code, generated files, many files                                                                                                      |

Rules of thumb for the **assessor**:

- **Smallest tier:** patch or minor bump, green CI, no breaking indicators, single dependency, dev-only / indirect / GitHub Action, one or two files changed. The assessor is confirming signals and running a usage grep.
- **Middle tier:** minor bump of a production dependency; grouped updates; any failing CI check; a dependency used across many files; a project whose safety net (types, tests) needs weighing.
- **Largest tier, or inherit the session's model:** major bump; breaking indicators; framework or runtime bumps; no CI configured; failing CI with several distinct failures; a plain-JS or untyped codebase where the coverage question is genuinely hard.

Rules of thumb for the **fixer**: the assessor has already named the exact command and the files it should change, so the fixer is mostly mechanical and the middle tier is the default. Drop to the smallest tier only when the fix is a single lockfile command with a one-file expected diff. Go up when the fix is a formatter pass across many files (it has to judge "purely formatting"), or when reproducing the failing check locally is involved. The fixer's guardrail — bail if `git diff --stat` shows anything outside the expected files — is a mechanical check; the judgment sits in the assessor, so do not assume the fixer needs to match the assessor's tier.

Omitting the model (inheriting the session's) is a valid choice, not a default — make it deliberately. State the chosen model and the one-line reason in each launch, and carry it into the summary table so the decision is visible in the transcript.

## Failure classification

Passed **verbatim** to every assessor. Dependabot bumps often fail CI for mechanical reasons that have nothing to do with the update itself being unsafe: a generated lockfile or collection is now out of date, a formatter wants a rewrite, or a job flaked. Those are fixable; anything that needs judgement is skipped and reported.

Every failing check must fall into a fixable category, or the PR is not simple.

| Failure                                                                                                                                           | Fixable?       | Fix                                                                                                                                                                              |
| ------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| RBS collection out of date (`rbs collection` complains the lockfile is stale, or Steep fails on missing signatures for the bumped gem)            | Yes            | `bundle exec rbs collection update` (or `install` if the project pins that way); commit `rbs_collection.lock.yaml`                                                               |
| Lockfile out of sync with manifest (`bundle install --frozen` / `npm ci` / `yarn install --immutable` / `pnpm install --frozen-lockfile` refuses) | Yes            | Regenerate with the project's lockfile-only command (`bundle lock`, `npm install --package-lock-only`, `yarn install`, `pnpm install --lockfile-only`); commit the lockfile only |
| Formatter or linter with an autofix mode failing on files the bump touched or generated (`rubocop`, `prettier`, `eslint`, `biome`, `gofmt`)       | Yes            | Run the tool's fix mode on the reported files only; commit if the diff is purely formatting                                                                                      |
| Flaky or infra failure unrelated to the dependency (timeout, runner lost, network fetch failed, a test that passes on the base branch)            | Rerun, not fix | Report `rerun` with the run id; the orchestrator runs `gh run rerun <run-id> --failed` and defers the PR                                                                         |
| Test failures caused by changed behaviour in the dependency                                                                                       | No             | Skip permanently; report the failing tests                                                                                                                                       |
| Deprecation or removal requiring source changes (renamed API, removed option, new required config)                                                | No             | Skip permanently; report the log excerpt                                                                                                                                         |
| Snapshot or fixture mismatches                                                                                                                    | No             | Skip permanently — regenerating snapshots hides real behaviour changes                                                                                                           |
| Anything you cannot name from the log                                                                                                             | No             | Skip permanently                                                                                                                                                                 |

The bar for "simple": the fix is produced by a tool, touches only generated or formatting-only files, and needs no hand-written source change.

## Risk rubric

Passed **verbatim** to every assessor. Three-part analysis:

- **Semver:** parse the version bump from the PR title (Dependabot uses "Bump X from A to B"; grouped PRs list each member in the body). Major = high risk. Patch/minor = low risk baseline. Treat a minor bump of a 0.x package as major.
- **Changelog:** scan the PR body for breaking change indicators (`breaking`, `BREAKING CHANGE`, `deprecated`, `removed`, `migration`, `incompatible`). Any match = high risk.
- **Test coverage:** search the codebase for imports/requires of the package being updated. Identify which files use it. Then check if those files have corresponding test coverage (matching test files, or are themselves test files). If the dependency is used in areas with no test coverage, consider whether static analysis provides sufficient safety — for example, in a TypeScript project the type checker can catch breaking API changes at compile time even without unit tests. If the project has neither test coverage nor static analysis (e.g. plain JavaScript with no type checking) for the affected code, mark as high risk.

Risk matrix:

- **Low risk:** patch/minor bump + no breaking indicators + CI passing + usage areas have test coverage or static analysis (e.g. TypeScript).
- **High risk:** major bump OR breaking indicators found OR no CI checks configured OR dependency used in code with neither test coverage nor static analysis.

A fix pushed by a fixer does not change the risk level on its own — it was mechanical by definition. Mention it in the risk details, though, so I can see what was regenerated when a high-risk PR is put to me.

## Fix procedure

Passed **verbatim** to every fixer. The fixer runs with `isolation: "worktree"`, so its working directory is a fresh worktree of this repo; it must do all of the following there and never `cd` into the main checkout.

- `gh pr checkout <number>`.
- Run the fix command the assessor named. Reproduce the failing check locally where the project makes that cheap (e.g. `bundle exec steep check`, the lint command) so you know the fix actually addresses it before pushing.
- Inspect `git diff --stat`. If anything outside the expected generated/formatting files changed, `git checkout -- .` to restore and report the PR as **not fixed** with the unexpected files listed. If you find yourself editing application code, stop, restore, and report the same way.
- Commit with a **Conventional Commits** message describing what was regenerated and why, e.g. `fix: update rbs collection for rails 7.2 bump`, written via HEREDOC, with the `Co-Authored-By: Claude <noreply@anthropic.com>` trailer.
- `git push` to the PR branch.
- Check out the branch the worktree started on, so the worktree is left as it was created and can be cleaned up.
- Report: **fixed** (what was regenerated, the commit SHA) or **not fixed** (why). Do not wait for CI.

**Dependabot after a manual push:** once someone else commits to its branch, Dependabot stops rebasing that PR itself, and `@dependabot rebase` or `@dependabot recreate` would throw the fix away. Never post those commands on a PR that has been pushed to. If that PR later conflicts with the base branch, the orchestrator launches a fixer to merge the base branch into the PR branch in a worktree and push, not via Dependabot.

## Steps

Create a todo list before starting.

### 1. Fetch Dependabot PRs

- Run one query that returns every triage signal at once:

  ```sh
  gh pr list --author "app/dependabot" --state open --limit 100 \
    --json number,title,body,headRefName,baseRefName,labels,statusCheckRollup,mergeable,mergeStateStatus,changedFiles,additions,deletions,commits,isCrossRepository
  ```

- **If none found:** stop and tell me there are no open Dependabot PRs.
- Print the count and titles.
- Record the current branch (`git branch --show-current`). The orchestrator must be on this same branch at the end. Note whether `git status --porcelain` is empty, for the report only — the fix path no longer depends on it.
- Drop any PR with `isCrossRepository: true` (a fork) from the fix path; it can still be assessed and merged.

### 2. Triage and pick a model per PR

From the JSON alone — no further calls — derive per PR: semver level, dependency type (from the Dependabot commit footer, falling back to the title), whether it is grouped, breaking-indicator hits, CI rollup state, mergeability, and diff shape. Then choose the assessor's model using the **Model selection** section.

Print a triage table: PR number, title, semver, dependency type, CI, mergeable, chosen model, one-line reason. This is the record of the model decisions, so keep the reason honest ("patch, dev-only, green" or "major bump of rails").

### 3. Assess every PR in parallel

Launch **one assessor per PR**, all in a single message so they run concurrently. If there are more than ten, launch in batches of ten and run steps 4–5 on each batch's verdicts before launching the next, so merges start flowing early.

Each assessor receives:

- The agent assumptions above.
- The PR number, title, body, head branch, and the triage signals from step 2.
- The **Failure classification** and **Risk rubric** sections, verbatim.
- A hard rule: **read-only**. It runs in the main working tree alongside other assessors. It must not `gh pr checkout`, `git checkout`, `git stash`, install dependencies, rerun CI, comment, approve, or write any file. It reads the repo and GitHub.
- Its task:
  1. `gh pr checks <number> --json name,state,link,bucket` and `gh pr view <number> --json mergeable,mergeStateStatus`.
  2. If any check is failing: for each failing check pull the failed log with `gh run view <run-id> --log-failed` (the run id is the number in the check's link). Read enough of the log to name the actual error, not just the job. Classify every failing check against the table. If all are fixable, name the exact fix command and the files the fix is expected to change; if any is a rerun, return the run id; otherwise return the log excerpt that proves it is not simple.
  3. Run the risk rubric regardless of CI state.
  4. Return a verdict in exactly this shape:

     ```
     pr: <number>
     ci: passing | failing | pending | none
     mergeable: MERGEABLE | CONFLICTING | UNKNOWN
     failure: none | fixable | rerun | not-simple
     fix: <command> — expected files: <list>   (only when fixable)
     rerun_ids: <run ids>                        (only when rerun)
     failure_evidence: <one or two lines from the log naming the error>
     semver: patch | minor | major
     breaking_indicators: none | <matched words>
     coverage: <which files use the package; covered by tests / static analysis / neither>
     risk: low | high
     risk_details: <one or two sentences I can act on>
     ```

State the model and reason in each launch, as decided in step 2.

### 4. Act on the verdicts

As each verdict arrives, print one log line for the PR (number, title, CI, risk, model used) and route it:

- **`failure: fixable`** → launch a **fixer** (`isolation: "worktree"`, model chosen per the fixer rules of thumb) with the agent assumptions, the PR number, the assessor's fix command and expected files, and the **Fix procedure** section verbatim. One fix attempt per PR per run — track it. Move the PR to the deferred queue as **pending CI (fix pushed)** once the fixer reports success; if the fixer reports **not fixed**, skip the PR permanently with its reason. Fork PRs (`isCrossRepository`) skip this path and are reported as not fixable.
- **`failure: rerun`** → `gh run rerun <run-id> --failed` for each id, then defer as **pending CI (rerun)**.
- **`failure: not-simple`** → skip permanently; keep the evidence for the report.
- **`ci: pending`** or **`mergeable: CONFLICTING`** → defer, keeping the risk verdict so it does not need re-assessing.
- **`ci: passing`, mergeable, `risk: low`** → add to the merge queue.
- **`ci: passing`, mergeable, `risk: high`** → add to the ask list.

### 5. Merge and ask

- **Merge queue, one PR at a time:** re-check `gh pr view <number> --json mergeable,mergeStateStatus` immediately before each merge, because the previous merge can have made it stale. If still mergeable: `gh pr review <number> --approve` (some projects require an approval before the PR is mergeable), then `gh pr merge <number> --squash --delete-branch`. If it has become `CONFLICTING` or `BEHIND` with CI re-running, move it to the deferred queue instead.
- **Ask list, once:** after the merge queue drains, ask me about **all** high-risk PRs in a single prompt rather than one at a time — a multi-select question listing each PR with its semver, breaking indicators, coverage finding, and risk details. Anything I do not select is skipped. Merge my selections through the merge-queue procedure above, always with `--squash`.
- Log each outcome as it happens: merged / skipped + reason / deferred + reason. If a fix was pushed, say what it was.

### 6. Retry deferred PRs

After the first pass, if any PRs are deferred (conflicts, pending CI, rerun, or a pushed fix):

- Print which PRs are waiting and why.
- Poll every 30 seconds without a subagent — this is cheap `gh` polling, not judgment. Use a Bash `run_in_background` `until` loop per deferred PR that exits when `gh pr checks <number>` has no pending checks or `gh pr view <number> --json mergeable` changes, or a single Monitor loop that emits one line per PR whose state changed. Never use a foreground `sleep`.
- When a deferred PR becomes mergeable with CI passing, route it by its **existing** risk verdict: low → merge queue, high → ask list (batch any that land close together into one question).
- When a deferred PR's CI fails and it has **not** had a fix attempt yet, launch a fresh assessor for **CI diagnosis only** (skip the risk rubric; it is already known), sized at least middle tier, and route the result through step 4.
- When a deferred PR's CI fails **after** a fix attempt, skip it permanently and include the new failure in the report — the fix was wrong or incomplete, and a second guess is not worth my CI minutes.
- When a deferred PR that a fixer pushed to reports conflicts, launch a fixer (worktree) to merge the base branch into the PR branch and push; never use `@dependabot rebase` on it.
- **Timeout:** stop polling a PR waiting on conflicts or on Dependabot's own CI after 3 minutes without progress. A PR waiting on CI for a pushed fix or a rerun gets 15 minutes, since a full CI run has to complete. Report anything still waiting as unresolved.

### 7. Done

- Confirm the orchestrator is on the branch recorded in step 1 and `git status --porcelain` matches what it was.
- `git worktree prune`, then `git worktree list`; remove any worktree a fixer left behind this run with `git worktree remove <path>`.
- Print a summary table of all processed PRs with columns: PR number, title, semver level, risk, model (assessor / fixer, or `—`), fix pushed (none / what was regenerated), and outcome (merged / skipped + reason / unresolved).
