---
name: code-review
description: Multi-agent code review of changes on the current branch; reports findings inline in chat
---

# Code Review

Code review all changes on the current branch (`git diff main...HEAD`) and report findings inline in chat. Do not post to GitHub.

**Agent assumptions (applies to all agents and subagents):**
- All tools are functional and will work without error. Do not test tools or make exploratory calls. Make sure this is clear to every subagent that is launched.
- Only call a tool if it is required to complete the task. Every tool call should have a clear purpose.

## Steps

### 1. Preflight

Launch a **haiku** agent to verify there are changes on the current branch:

- Run `git diff --stat main...HEAD` (replace `main` with the repo's default branch if different — detect via `git symbolic-ref refs/remotes/origin/HEAD` if needed).
- If there are no changes, stop and tell me there's nothing to review.
- If the current branch **is** the default branch, stop and tell me to switch to a feature branch first.

### 2. Discover CLAUDE.md files

Launch a **haiku** agent to return a list of file paths (not contents) for all relevant `CLAUDE.md` files:

- The repo root `CLAUDE.md`, if it exists.
- Any `CLAUDE.md` files in directories containing files modified on the current branch (use `git diff --name-only main...HEAD` to get the changed file list).

### 3. Summarize the changes

Launch a **sonnet** agent to read `git diff main...HEAD` and `git log --oneline main..HEAD` and return a short summary of what the branch does. This summary provides context to the reviewers in step 4.

### 4. Parallel review (4 agents)

Launch 4 agents in parallel. Each agent receives the branch summary from step 3 and returns a list of issues, where each issue includes a description and the reason it was flagged (e.g. "CLAUDE.md adherence", "bug"). The agents:

**Agents 1 + 2: CLAUDE.md compliance (sonnet)**
Audit changes for CLAUDE.md compliance in parallel. When evaluating compliance for a file, only consider `CLAUDE.md` files that share a file path with the file or its parents.

**Agent 3: Bug scan (opus)**
Scan for obvious bugs. Focus only on the diff itself without reading extra context. Flag only significant bugs; ignore nitpicks and likely false positives. Do not flag issues you cannot validate without looking at context outside the git diff.

**Agent 4: Introduced-code review (opus)**
Look for problems in the introduced code — security issues, incorrect logic, etc. Only look for issues within the changed code.

**CRITICAL: We only want HIGH SIGNAL issues.** Flag issues where:
- The code will fail to compile or parse (syntax errors, type errors, missing imports, unresolved references)
- The code will definitely produce wrong results regardless of inputs (clear logic errors)
- Clear, unambiguous CLAUDE.md violations where you can quote the exact rule being broken

Do NOT flag:
- Code style or quality concerns
- Potential issues that depend on specific inputs or state
- Subjective suggestions or improvements

If you are not certain an issue is real, do not flag it. False positives erode trust and waste reviewer time.

### 5. Validate each issue

For each issue from step 4's bug agents (3 and 4), launch a parallel subagent to validate the issue is real with high confidence. For example, if "variable is not defined" was flagged, the subagent's job is to validate that's actually true in the code. For CLAUDE.md issues, validate that the rule is scoped for the file and actually violated.

- Use **opus** subagents for bugs and logic issues.
- Use **sonnet** subagents for CLAUDE.md violations.

### 6. Filter

Drop any issue that was not validated in step 5. What remains is the final high-signal set.

### 7. Report findings inline in chat

**If no issues were found**, print exactly:

> ## Code review
>
> No issues found. Checked for bugs and CLAUDE.md compliance.

**If issues were found**, print a single markdown block:

> ## Code review
>
> Found N issue(s) across M file(s).
>
> ### `<path>:<line>` (or `<path>:<start>-<end>`)
> **<reason tag>** — <one-line description of the issue>
>
> <optional suggested fix>

Rules:
- Group by file, then by line number ascending.
- Use `path:line` or `path:line-line` refs — they're clickable in the terminal. **Do not** construct GitHub blob URLs.
- For small, self-contained fixes, include a fenced code block with the suggested replacement.
- For larger fixes (6+ lines, structural changes, or changes spanning multiple locations), describe the issue and suggested fix in prose without a suggestion block.
- Only include a code suggestion if applying it fully fixes the issue. If follow-up steps are required, describe them instead.
- **Only report ONE finding per unique issue.** No duplicates.
- If you cite a CLAUDE.md rule, quote the rule and include the CLAUDE.md file path.

## False-positive list

Use this list when evaluating issues in Steps 4 and 5 (these are false positives — do NOT flag):

- Pre-existing issues
- Something that appears to be a bug but is actually correct
- Pedantic nitpicks that a senior engineer would not flag
- Issues that a linter will catch (do not run the linter to verify)
- General code quality concerns (e.g., lack of test coverage, general security issues) unless explicitly required in CLAUDE.md
- Issues mentioned in CLAUDE.md but explicitly silenced in the code (e.g., via a lint ignore comment)

## Notes

- This skill never touches GitHub. No `gh pr` commands, no inline-comment MCP calls.
- Create a todo list before starting.
