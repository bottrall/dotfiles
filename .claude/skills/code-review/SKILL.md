---
name: code-review
description: Multi-agent code review of the current branch against the shared review criteria; reports findings inline in chat. Use only when explicitly asked to review, or when invoked by the build-loop skill. Never run it speculatively.
---

# Code Review

Code review all changes on the current branch and report findings inline in chat. Do not post to GitHub.

The `build-loop` skill invokes this skill for its review phase and gates on the report below, so the report format is a contract: keep the "No issues found" sentinel and the findings block stable.

**Agent assumptions (applies to all agents and subagents):**

- All tools are functional and will work without error. Do not test tools or make exploratory calls. Make sure this is clear to every subagent that is launched.
- Only call a tool if it is required to complete the task. Every tool call should have a clear purpose.

## Criteria

Every reviewer and validator is graded against [criteria.md](criteria.md) — the ranked lenses, the HIGH SIGNAL bar, and the false-positive list. It is inlined below so it can be passed **verbatim** to every subagent. Do not paraphrase it.

<criteria>
!`cat ~/.claude/skills/code-review/criteria.md`
</criteria>

## Review scope

All changes since the current branch diverged from the default branch, **including staged and unstaged work**. Never use three-dot (`main...HEAD`) — it drops uncommitted changes.

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- `BASE=$(git merge-base <default-branch> HEAD)` — compute once at the start of the review.
- Unified diff: `git diff $BASE`
- File list: `git diff --name-only $BASE`
- Stat: `git diff --stat $BASE`

Pass these exact commands to every review subagent. Each reviewer must read the changes via `git diff $BASE` — not `git diff main...HEAD`.

## Model selection

Every subagent launch includes a deliberate model choice, picked from whatever tiers the Agent tool currently exposes. No step is mapped to a model — decide per launch by weighing:

- **Judgment density.** How much of the task is reasoning versus mechanical execution? Following explicit instructions (listing file paths, verifying a single quoted claim) needs far less capability than spotting what _isn't_ written in the diff.
- **Cost of a miss.** What happens if this subagent gets it wrong? A weak reviewer ships the bug; a weak validator drops a real finding or keeps a false one.
- **Ambiguity of the input.** An open-ended "find security problems" prompt is not the same task as "confirm this specific quoted finding is real."
- **Recovery cost.** When wrong-but-confident output is hard to detect downstream, pay for capability up front.

Generation and verification are asymmetric: checking work often demands more capability than producing it, because the checker must catch what the producer missed. Don't assume the validator can be weaker than the reviewer just because the finding is short.

Omitting the model (inheriting the session's) is a valid choice, not a default — make it deliberately. State the chosen model in each launch so the decision is visible in the transcript.

## Steps

Create a todo list before starting.

### 1. Preflight

Launch a subagent to verify there is something to review:

- Compute `BASE` as defined in the Review scope section.
- Run `git diff --stat $BASE`.
- If there are no changes (committed, staged, or unstaged), stop and tell me there's nothing to review.
- If the current branch **is** the default branch, stop and tell me to switch to a feature branch first (even if there are uncommitted changes).

### 2. Discover rule files

Launch a subagent to return a list of file paths (not contents) for all relevant rule files:

- The repo root `CLAUDE.md`, if it exists.
- Any `CLAUDE.md` in a directory containing a file modified on this branch (use `git diff --name-only $BASE`, which includes uncommitted changes).
- Any file under `.claude/rules/`.

### 3. Summarize the changes

Launch a subagent to summarize the branch. It should:

- Read `git diff $BASE` (committed + staged + unstaged) and `git log --oneline <default-branch>..HEAD` (commits only).
- Run `git status --porcelain`; if non-empty, note which files have uncommitted changes so the reviewers in step 4 have that context.
- Return a short summary of what the branch does.

### 4. Parallel review

Launch **one reviewer per lens** in the criteria — five in parallel: Correctness, Security, Rules compliance, Performance, Simplicity / idiom. Each receives:

- The full criteria text, verbatim.
- Which single lens it owns. It reviews through that lens only, at the stated bar, and honours the false-positive list.
- The rule-file paths from step 2 and the branch summary from step 3.
- The exact scope commands from the Review scope section.

Each returns a list of findings — `path:line`, a reason tag naming the lens, and a one-line description. A finding that fails the bar is not returned.

### 5. Validate

For each finding, launch a subagent to adversarially confirm it is real and worth fixing with high confidence, using the criteria verbatim. E.g. if "variable is not defined" was flagged, verify that's actually true in the code; for a rule finding, verify the rule is in scope for the file and actually violated; for a simplicity finding, verify the proposed replacement does not lose behaviour a higher-ranked criterion requires. Drop any finding that doesn't survive.

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

- This skill never touches GitHub. No `gh pr` commands, no inline-comment MCP calls.
