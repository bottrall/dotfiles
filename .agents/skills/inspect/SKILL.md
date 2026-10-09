---
name: inspect
description: Multi-agent code review of the current branch, or of a PR URL in its own worktree, against the shared review criteria; reports findings inline in chat. Use only when explicitly asked to review, or when invoked by the build skill. Never run it speculatively.
---

# Code Review

Code review all changes on the current branch and report findings inline in chat. Do not post to GitHub.

The `build` skill invokes this skill for its review phase and gates on the report below, so the report format is a contract: keep the "No issues found" sentinel and the findings block stable.

## Subagents

Every step below except Filter and Report runs as a headless subagent. Before spawning anything, activate the `riffer-subagent` skill and follow it for mechanics and prompt shape.

## Criteria

Every reviewer and validator is graded against the shared criteria — the ranked lenses, the HIGH SIGNAL bar, and the false-positive list — at `~/.agents/skills/inspect/criteria.md`. Read it once in this session so you can merge and filter, and pass its path to every subagent with the instruction to read it and hold it **verbatim**. Do not paraphrase it.

## Review scope

All changes since the current branch diverged from its **base branch** — the branch this work is stacked on, which is not necessarily the default branch — **including staged and unstaged work**. Never use a three-dot diff (`<base-branch>...HEAD`) — it drops uncommitted changes.

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- Determine the base branch — first match wins:
  1. **Open PR:** `gh pr view --json baseRefName -q .baseRefName`. The PR's target is authoritative.
  2. **Nearest parent:** among the local branches plus the default branch, excluding the current branch, drop any branch stacked _on top of_ this one (`git rev-list --count <candidate>..HEAD` is 0 while `git rev-list --count HEAD..<candidate>` is not). The base is the remaining branch with the smallest `git rev-list --count <candidate>..HEAD`; on a tie, prefer the default branch.
- Run `git fetch origin`. Of `<base>` and `origin/<base>` (whichever exist), use the one with the smaller `git rev-list --count <ref>..HEAD` — it's the fresher view of where this branch forked. This is `<base-branch>`.
- `BASE=$(git merge-base <base-branch> HEAD)` — compute once at the start of the review.
- Unified diff: `git diff $BASE`
- File list: `git diff --name-only $BASE`
- Stat: `git diff --stat $BASE`

Pass the resolved `BASE` commit and these exact commands to every subagent. Each reviewer must read the changes via `git diff $BASE` — never a three-dot diff.

## Steps

Before starting, write a numbered checklist of the steps below in your reply and tick each one off as you go.

### 1. Check out the PR (only if one was passed)

If I passed a PR reference (URL, `#<n>`, or `<n>`) and the current branch isn't already its head: `gh pr checkout <n>`. With no argument (including when `build` runs this review in place), skip this step and review the current branch as is.

### 2. Preflight

Spawn a subagent to verify there is something to review:

- Determine `<base-branch>` and compute `BASE` as defined in the Review scope section. Say which base was chosen and why (open PR or nearest parent).
- Run `git diff --stat $BASE`.
- If there are no changes (committed, staged, or unstaged), stop and tell me there's nothing to review.
- If the current branch **is** the default branch, stop and tell me to switch to a feature branch first (even if there are uncommitted changes).

### 3. Discover rule files

Spawn a subagent to return a list of file paths (not contents) for **every** rule file that applies to a changed file. Rule files live at any depth, not just the repo root: a subdirectory can carry its own `AGENTS.md`, `CLAUDE.md`, or `.claude/` directory with a `CLAUDE.md` and `rules/`, and those are just as binding. Search the whole repo for them — never stop at the root.

- Find every candidate: `git ls-files -co --exclude-standard | grep -E '(^|/)((AGENTS|CLAUDE)\.md|\.claude/rules/.+)$'`. This covers `AGENTS.md`, `CLAUDE.md`, `.claude/CLAUDE.md`, and `.claude/rules/**` at every level.
- Each candidate is owned by a directory `X`: `X/AGENTS.md`, `X/CLAUDE.md`, `X/.claude/CLAUDE.md`, and `X/.claude/rules/**` are all owned by `X`.
- Keep a candidate when `X` contains at least one changed file at any depth (`git diff --name-only $BASE`, which includes uncommitted changes). The repo root always qualifies. If a `.claude/rules/` file has `paths:` frontmatter, also require at least one changed file to match those globs.
- Return the kept paths grouped by owning directory, so reviewers can see which rules govern which files.

### 4. Summarize the changes

Spawn a subagent to summarize the branch. It should:

- Read `git diff $BASE` (committed + staged + unstaged) and `git log --oneline $BASE..HEAD` (commits only).
- Run `git status --porcelain`; if non-empty, note which files have uncommitted changes so the reviewers in step 5 have that context.
- Return a short summary of what the branch does.

Steps 3 and 4 depend only on `BASE`, not on each other — spawn them in one fan-out.

### 5. Parallel review

Spawn **one reviewer per lens** in the criteria — five in parallel, in one fan-out. Each receives:

- The criteria path, with the instruction to read it and hold it **verbatim**.
- Which single lens it owns. It reviews through that lens only, at the stated bar, and honours the false-positive list.
- The rule-file paths from step 3 and the branch summary from step 4.
- The resolved `BASE` commit and the exact scope commands from the Review scope section.

Each returns a list of findings — `path:line`, a reason tag naming the lens, and a one-line description. A finding that fails the bar is not returned.

### 6. Validate

For each finding, spawn a subagent to adversarially confirm it is real and worth fixing with high confidence, using the criteria verbatim — all validators in one fan-out. E.g. if "variable is not defined" was flagged, verify that's actually true in the code; for a rule finding, verify the rule is in scope for the file and actually violated; for a simplicity finding, verify the proposed replacement does not lose behaviour a higher-ranked criterion requires. Drop any finding that doesn't survive.

### 7. Filter

In this session, not a subagent: drop every finding that failed validation in step 6, plus anything on the false-positive list. If two surviving findings conflict on the same code, keep the one from the higher-ranked lens and drop the other. What remains is the final high-signal set.

### 8. Report findings inline in chat

**If no findings survived**, print exactly:

> ## Code review
>
> No issues found.

**If findings survived**, print a single markdown block. Every file is a section, every finding is a numbered sub-heading inside its file's section, and a horizontal rule closes every finding:

> ## Code review
>
> Found N issue(s) across M file(s).
>
> ---
>
> ### `<path>`
>
> #### 1. <Reason tag> — <one-line description>
>
> **Where:** `<path>:<line>` (or `<path>:<start>-<end>`)
>
> **Why:** <one or two sentences on what goes wrong and when>
>
> **Fix:** <prose on the same line, or a fenced replacement block on the next line>
>
> ---
>
> #### 2. <Reason tag> — <one-line description>
>
> **Where:** `<path>:<line>`
>
> **Why:** …
>
> **Fix:** …
>
> ---

Layout rules:

- **Sections.** One `###` heading per file, files ordered by path, findings within a file in ascending line order. A `---` rule follows the summary line and closes every finding, so every boundary — finding to finding, file to file — is a horizontal rule.
- **Numbering.** Sequential across the whole report (1…N), not per file, so any finding can be referred to as "finding 3".
- **Heading.** The reason tag is the lens name (Correctness, Security, Rules, Performance, Simplicity), then the one-line description.
- **Where.** `path:line` refs (clickable) — never GitHub blob URLs.
- **Why.** What goes wrong and when. For a rule finding, quote the rule and its file path here.
- **Fix.** Small self-contained fix: a fenced block with the replacement, only if applying it fully resolves the finding. Larger fixes (6+ lines, structural, or spanning multiple locations): describe in prose. If there is no concrete fix to suggest, omit the line.
- One finding per unique issue; no duplicates.

## Notes

- This skill never writes to GitHub, and neither do its subagents — the review is read-only end to end. Read-only `gh` lookups (base branch, checking out a PR) are fine; no reviews, comments, or inline comments.
- The review scope always covers the full branch diff each cycle, so fixes can't silently regress previously-clean code.