---
name: sentry-issue
description: Investigate a Sentry issue, determine root cause, and produce a resolution plan
---

# Sentry Issue

Investigate a Sentry issue using the `sentry` CLI, determine the root cause, cross-reference with the local codebase, and produce a resolution plan. This skill does not modify any code.

## Steps

### 1. Validate input

- `$ARGUMENTS` must contain a Sentry issue identifier (e.g. `ARMAX-3E`, `@latest`, `my-org/CLI-G`).
- **If `$ARGUMENTS` is empty:** stop and ask me for the Sentry issue ID.

### 2. Fetch issue details

- Run `sentry issue view $ARGUMENTS --json` to get the full issue payload including the latest event, stacktrace, tags, and metadata.
- **If the command fails or returns no data:** stop and tell me the issue could not be found. Include the exact error message.
- Print a summary of the issue: title, issue type, status, first seen, last seen, event count, and affected platform/environment.

### 3. Fetch recent events

- Run `sentry issue events $ARGUMENTS --full --limit 5 --json` to get the most recent events with full stacktraces.
- Compare events to identify patterns: does the error always occur in the same location, or does it vary across environments, users, or code paths?
- Print a brief summary of event patterns (e.g. "5/5 events share the same stacktrace" or "errors occur across 3 different endpoints").

### 4. Cross-reference with local codebase

- Extract all file paths and function names from the stacktraces collected in steps 2 and 3.
- Search the working directory for matching files. Try exact paths first, then fall back to filename-only matches if the stacktrace paths use a different prefix (e.g. deployed path vs local path).
- **If no matching files are found in the local codebase:** stop and tell me this does not appear to be the correct repository for this issue. List the file paths from the stacktrace so I can identify the right repo.
- For each matched file, read the relevant code around the line numbers referenced in the stacktrace. Include enough context (30 lines above and below) to understand the function and its callers.

### 5. Determine root cause

Synthesize all information gathered so far — stacktraces, event patterns, and local code — to determine the root cause. Structure the analysis as:

- **What is failing:** the specific error, exception, or unexpected behavior.
- **Where it fails:** file path, function, and line number in the local codebase.
- **Why it fails:** the underlying cause (e.g. unhandled null, race condition, missing validation, incorrect assumption about input).
- **Contributing factors:** anything that makes the bug more likely or harder to detect (e.g. missing error handling, lack of types, implicit contract between modules).
- **If the root cause is ambiguous or there are multiple plausible causes:** present each candidate with supporting evidence and ask me which direction to investigate.

### 6. Produce resolution plan

Based on the root cause analysis, produce a numbered plan with specific, actionable steps. Each step must include:

- The file to change (absolute path).
- What to change and why.
- Any new tests or test updates needed.
- Any edge cases the fix must handle.

The plan should follow the project's conventions as described in any `CLAUDE.md` files in the repository.

**Do not modify any files.** The plan is for review only.

### 7. Summary

Print a final summary block:

- **Issue:** title and ID.
- **Root cause:** one-sentence description.
- **Files to change:** list of file paths that the plan touches.
- **Risk assessment:** low / medium / high — based on how many files are affected, whether the change touches shared code, and how confident the root cause analysis is.
- **Suggested next step:** tell me I can ask to implement the plan or request deeper investigation into a specific area.
