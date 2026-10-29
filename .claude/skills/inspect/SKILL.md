---
name: inspect
description: Multi-agent code review of the current branch or a PR, reported in chat. Use only when explicitly asked for a review, or from the build skill.
---

# Code Review

Code review all changes on the current branch and report findings inline in chat. Do not post to GitHub.

The `build` skill invokes this skill for its review phase and gates on the report below, so the report format is a contract: keep the "No issues found" sentinel and the findings block stable.

## Criteria

Every reviewer and validator is graded against [criteria.md](criteria.md) — the ranked lenses, the two-tier bar, and the false-positive list. It is inlined below so it can be passed **verbatim** to every subagent. Do not paraphrase it.

<criteria>
!`cat ~/.claude/skills/inspect/criteria.md`
</criteria>

## Review scope

All changes since the current branch diverged from its **base branch** — the branch this work is stacked on, which is not necessarily the default branch — **including staged and unstaged work**. Never use a three-dot diff (`<base-branch>...HEAD`) — it drops uncommitted changes.

- Detect the default branch: `git symbolic-ref refs/remotes/origin/HEAD` (e.g. `main`).
- Determine the base branch — first match wins:
  1. **Open PR:** the one step 1 checked out, else the current branch's: `gh pr view [<n>] --json baseRefName -q .baseRefName`. The PR's target is authoritative.
  2. **Nearest parent:** among the local branches plus the default branch, excluding the current branch, drop any branch stacked _on top of_ this one (`git rev-list --count <candidate>..HEAD` is 0 while `git rev-list --count HEAD..<candidate>` is not). The base is the remaining branch with the smallest `git rev-list --count <candidate>..HEAD`; on a tie, prefer the default branch.
- Run `git fetch origin`. Of `<base>` and `origin/<base>` (whichever exist), use the one with the smaller `git rev-list --count <ref>..HEAD` — it's the fresher view of where this branch forked. This is `<base-branch>`.
- `BASE=$(git merge-base <base-branch> HEAD)` — compute once at the start of the review.
- Unified diff: `git diff $BASE`
- File list: `git diff --name-only $BASE`
- Stat: `git diff --stat $BASE`

Pass the resolved `BASE` commit and these exact commands to every review subagent. Each reviewer must read the changes via `git diff $BASE` — never a three-dot diff.

## Authorship

My global instructions bind the review only when I wrote the change. Decide once, in preflight — first match wins:

1. **Open PR:** the one step 1 checked out, else the current branch's. Mine when `gh pr view [<n>] --json author -q .author.login` equals `gh api user -q .login`.
2. **No PR:** mine when `git log --format=%ae $BASE..HEAD` includes `git config user.email`, or the range has no commits (uncommitted work only).

When the change is **not mine**, `~/.claude/CLAUDE.md` is out of scope. It loads into every session and subagent regardless, so pass this instruction verbatim to every reviewer and validator:

> This change was not written by the user. Your context includes the user's global instructions (`~/.claude/CLAUDE.md`): they are personal preferences, not this project's rules. Do not cite them, catalog them, or let them anchor a finding at either tier — judge only against the criteria and the repo's rule files. A rule file tracked in the repo stays binding even if its text matches the global file.

When the change is mine, review as usual.

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

### 1. Get onto a worktree

Do this in the main session, not a subagent — a subagent's worktree and checkout don't carry back to this session, and every subagent below must see the PR's branch.

- **I passed a PR reference** (URL, `#<n>`, or `<n>`): ensure you're in a worktree, then `gh pr checkout <n>`.
- **No argument** (including when `build` invokes this skill): review the current branch as is.

### 2. Preflight

Launch a subagent to verify there is something to review:

- Determine `<base-branch>` and compute `BASE` as defined in the Review scope section. Say which base was chosen and why (open PR or nearest parent).
- Run `git diff --stat $BASE`.
- Determine authorship as defined in the Authorship section. Say whether the change is mine and which signal decided it (PR author or commit authors).
- If there are no changes (committed, staged, or unstaged), stop and tell me there's nothing to review.
- If the current branch **is** the default branch, stop and tell me to switch to a feature branch first (even if there are uncommitted changes).

### 3. Discover rule files

Launch a subagent to return a list of file paths (not contents) for **every** rule file that applies to a changed file. Rule files live at any depth, not just the repo root: a subdirectory can carry its own `CLAUDE.md` or its own `.claude/` directory with a `CLAUDE.md` and `rules/`, and those are just as binding. Search the whole repo for them — never stop at the root.

- Find every candidate: `git ls-files -co --exclude-standard | grep -E '(^|/)(CLAUDE\.md|\.claude/rules/.+)$'`. This covers `CLAUDE.md`, `.claude/CLAUDE.md`, and `.claude/rules/**` at every level.
- Each candidate is owned by a directory `X`: `X/CLAUDE.md`, `X/.claude/CLAUDE.md`, and `X/.claude/rules/**` are all owned by `X`.
- Keep a candidate when `X` contains at least one changed file at any depth (`git diff --name-only $BASE`, which includes uncommitted changes). The repo root always qualifies. If a `.claude/rules/` file has `paths:` frontmatter, also require at least one changed file to match those globs.
- Return the kept paths grouped by owning directory, so reviewers can see which rules govern which files.

### 4. Summarize the changes

Launch a subagent to summarize the branch. It should:

- Read `git diff $BASE` (committed + staged + unstaged) and `git log --oneline $BASE..HEAD` (commits only).
- Run `git status --porcelain`; if non-empty, note which files have uncommitted changes so the reviewers in step 5 have that context.
- Return a short summary of what the branch does.

### 5. Parallel review

Launch **one reviewer per lens** in the criteria — five in parallel: Correctness, Security, Rules compliance, Performance, Simplicity / idiom. Each receives:

- The full criteria text, verbatim.
- Which single lens it owns. It reviews through that lens only, at the stated bar, and honours the false-positive list.
- The rule-file paths from step 3 and the branch summary from step 4.
- The resolved `BASE` commit and the exact scope commands from the Review scope section.
- When the change is not mine, the instruction from the Authorship section, verbatim.

Each returns findings tagged with their tier — `path:line`, a reason tag naming the lens, and a one-line description. A Tier 1 finding must meet the HIGH SIGNAL bar; a Tier 2 finding needs only a plausible owner ruling (see the bar in the criteria). The Rules-compliance reviewer additionally returns the **catalog** every rule check ends in (see the criteria): the governed set, the verdicts, and the method where the set cannot be itemized. The catalog is the audit's observable output: it is what distinguishes a performed audit from a skipped one.

### 6. Validate

For each finding, launch a subagent to adversarially confirm it is real and worth fixing with high confidence, using the criteria verbatim. E.g. if "variable is not defined" was flagged, verify that's actually true in the code; for a rule finding, verify the rule is in scope for the file and actually violated; for a simplicity finding, verify the proposed replacement does not lose behaviour a higher-ranked criterion requires. Drop any finding that doesn't survive. When the change is not mine, each validator also receives the instruction from the Authorship section, verbatim.

Tier 2 findings skip validation — there is nothing adversarial to confirm in a classification, and re-judging it would reintroduce the silence this tier exists to prevent. For Tier 1 rule findings, validation is **correspondence, not re-judgement**: confirm the quoted rule exists in the quoted file and the quoted text is in the diff. Judging whether the finding is subjective was the lens's call; the validator checks facts.

### 7. Filter

Drop every finding that failed validation in step 6, plus anything on the false-positive list. When the change is not mine, also drop any finding anchored in my global instructions rather than the criteria or a repo rule file. If two surviving findings conflict on the same code, keep the one from the higher-ranked lens and drop the other. What remains is the final set, tagged by tier: HIGH SIGNAL findings and in-passing findings.

### 8. Report findings inline in chat

**If no findings survived**, print exactly the block below — adding one catalog line per catalog the Rules lens produced, immediately after the sentinel:

> ## Code review
>
> No issues found.
>
> Catalog: comments — 14 added, all compliant.

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
>
> ### `<next path>`
>
> #### 3. <Reason tag> — <one-line description>
>
> …
>
> ---

Layout rules:

- **Sections.** One `###` heading per file, files ordered by path, findings within a file in ascending line order. A `---` rule follows the summary line and closes every finding, so every boundary — finding to finding, file to file — is a horizontal rule.
- **Numbering.** Sequential across the whole report (1…N), not per file, so any finding can be referred to as "finding 3".
- **Heading.** The reason tag is the lens name (Correctness, Security, Rules, Performance, Simplicity), suffixed `(in-passing)` for Tier 2 findings, then the one-line description.
- **Catalog.** When the Rules lens produced a catalog, summarise it in one line immediately after the summary line — `Catalog: comments — 14 added, 12 compliant, 2 flagged below.` — so the audit's scope is visible alongside the findings. A fully-compliant catalog appears even when the report otherwise has findings.
- **Where.** `path:line` refs (clickable) — never GitHub blob URLs.
- **Why.** What goes wrong and when. For a rule finding, quote the rule and its file path here.
- **Fix.** Small self-contained fix: a fenced block with the replacement, only if applying it fully resolves the finding. Larger fixes (6+ lines, structural, or spanning multiple locations): describe in prose. If there is no concrete fix to suggest, omit the line.
- One finding per unique issue; no duplicates.

## Notes

- This skill never writes to GitHub. Read-only `gh` lookups (base branch, checking out a PR) are fine; no reviews, comments, or inline-comment MCP calls.
