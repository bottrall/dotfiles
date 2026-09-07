---
name: code-review
description: Single-agent code review of the current branch against the shared review criteria; reports findings inline in chat. Use only when explicitly asked to review, or when invoked by the build-loop skill. Never run it speculatively.
---

# Code Review

Code review all changes on the current branch and report findings inline in chat. Do not post to GitHub.

The `build-loop` skill invokes this skill for its review phase and gates on the report below, so the report format is a contract: keep the "No issues found" sentinel and the findings block stable.

**This is the single-agent variant.** riffer-rig has no subagents, so every step below that the Claude Code version delegated — preflight, rule discovery, summary, one reviewer per lens, one validator per finding — is done by you, sequentially, in this session. Walk the lenses in order, record every finding before validating, then validate each finding adversarially as if you had not written it.

**Agent assumptions:**

- All tools are functional and will work without error. Do not test tools or make exploratory calls.
- Only call a tool if it is required to complete the task. Every tool call should have a clear purpose.

## Criteria

Every lens and every validation is graded against the shared criteria — the ranked lenses, the HIGH SIGNAL bar, and the false-positive list. Before starting, read the file `~/.riffer/skills/code-review/criteria.md` with the read tool. Apply it **verbatim**; do not paraphrase it.

## Review scope

All changes since the current branch diverged from the default branch, **including staged and unstaged work**. Never use three-dot (`main...HEAD`) — it drops uncommitted changes.

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- `BASE=$(git merge-base <default-branch> HEAD)` — compute once at the start of the review.
- Unified diff: `git diff $BASE`
- File list: `git diff --name-only $BASE`
- Stat: `git diff --stat $BASE`

Use these exact commands for every lens. Read the changes via `git diff $BASE` — not `git diff main...HEAD`.

## Steps

Before starting, write a numbered checklist of the steps below in your reply and tick each one off as you go.

### 1. Preflight

Verify there is something to review:

- Compute `BASE` as defined in the Review scope section.
- Run `git diff --stat $BASE`.
- If there are no changes (committed, staged, or unstaged), stop and tell me there's nothing to review.
- If the current branch **is** the default branch, stop and tell me to switch to a feature branch first (even if there are uncommitted changes).

### 2. Discover rule files

Collect a list of file paths (not contents) for all relevant rule files:

- The repo root `AGENTS.md` or `CLAUDE.md`, if either exists.
- Any `AGENTS.md` or `CLAUDE.md` in a directory containing a file modified on this branch (use `git diff --name-only $BASE`, which includes uncommitted changes).
- Any file under `.claude/rules/`.

### 3. Summarize the changes

Summarize the branch:

- Read `git diff $BASE` (committed + staged + unstaged) and `git log --oneline <default-branch>..HEAD` (commits only).
- Run `git status --porcelain`; if non-empty, note which files have uncommitted changes so the lens passes in step 4 have that context.
- Write a short summary of what the branch does.

### 4. Review, one lens at a time

Walk the five lenses in the criteria **in order, one pass each**: Correctness, Security, Rules compliance, Performance, Simplicity / idiom. For each pass:

- Hold the full criteria text in mind, verbatim.
- Review through that single lens only, at the stated bar, and honour the false-positive list.
- Use the rule-file paths from step 2, the branch summary from step 3, and the exact scope commands from the Review scope section.
- Record the pass's findings before moving to the next lens — `path:line`, a reason tag naming the lens, and a one-line description. A finding that fails the bar is not recorded.

Do not validate while reviewing; finish all five passes first so each lens gets a clean look.

### 5. Validate

For each recorded finding, adversarially confirm it is real and worth fixing with high confidence, using the criteria verbatim. E.g. if "variable is not defined" was flagged, verify that's actually true in the code; for a rule finding, verify the rule is in scope for the file and actually violated; for a simplicity finding, verify the proposed replacement does not lose behaviour a higher-ranked criterion requires. Drop any finding that doesn't survive.

### 6. Filter

Drop every finding that failed validation in step 5, plus anything on the false-positive list. If two surviving findings conflict on the same code, keep the one from the higher-ranked lens and drop the other. What remains is the final high-signal set.

### 7. Report findings inline in chat

**If no findings survived**, print exactly:

> ## Code review
>
> No issues found.

**If findings survived**, print a single markdown block:

> ## Code review
>
> Found N issue(s) across M file(s).
>
> ### `<path>:<line>` (or `<path>:<start>-<end>`)
>
> **<reason tag>** — <one-line description>
>
> <optional suggested fix>

- Group by file, then ascending line. Use `path:line` refs (clickable) — never GitHub blob URLs.
- Small self-contained fix: include a fenced block with the replacement, but only if applying it fully resolves the finding. Larger fixes (6+ lines, structural, or spanning multiple locations): describe in prose.
- One finding per unique issue; no duplicates. Quote the rule and its file path for any rule finding.

## Notes

- This skill never touches GitHub. No `gh pr` commands.
