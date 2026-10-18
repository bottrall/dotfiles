---
name: riffer-subagent
description: Spawn headless riffer subagents for fresh-context or concurrent work — parallel reviewers, per-ticket research, delegated builds.
---

# Subagents on riffer

A subagent is a headless riffer run: `riffer -p` in a child process — same settings, auth, AGENTS.md and skills as this session, fresh context, and only its report comes back. Caller skills (`inspect`, `build`, `wayfinder`) say **what** to spawn; this skill is **how**.

## When to spawn

- **The subtask's reading would flood this session** — reviewing a diff, researching a topic, summarizing a branch. Only the child's report comes back; the reading stays in the child.
- **The subtasks can run concurrently** — one reviewer per lens, one validator per finding. Each child is its own background job, so fan-out is real parallelism.

Do it in-session when the subtask is trivial or needs context already accumulated here — every child pays a cold start.

Children are **read-only by convention**: they review, research, summarize, report. The driving session does the mutating — the one exception is a delegated build, which owns its worktree work by explicit instruction in its prompt.

## Spawn: one child per background job

Each child is a `bash` call with `run_in_background: true`. The call returns a job id immediately and the job's exit is announced to this session — no pid files, no mktemp, no wait loop, no polling. Issue the spawn calls together so the children run concurrently.

Pass the prompt as an argument, write it to a file, or pipe it in — anything but the job's own stdin, which is empty in a background job (a heredoc inside the command string works too, since it's the shell's stdin, not the job's). A file is the low-friction default for long prompts: no shell quoting, and it survives for retries:

```bash
riffer -p < /tmp/child-security-prompt.md \
  > /tmp/child-security-report.md 2> /tmp/child-security-err.md
```

- **Redirect the report to a file you named** — child stdout is streamed to the file as it is written, so the report is complete the moment the exit lands, and the exit notice alone carries only the last 2,000 bytes. Read the file for the full report.
- **Keep stderr** — it carries the child's session id (for a later resume) and the only diagnostics when a child fails, including the exit-3 reason.
- **Wrap with `timeout`** (`timeout 900 riffer -p …`) for a hard cap; a child killed by it reports `status=killed`. Add `--max-steps N` to bound a child that could loop.

## Collect

The runtime delivers each exit as a notice: job id, status (`completed` for exit 0, `failed`, or `killed`), the command, the output path, and the last 2,000 bytes of output. Read the report file at the path you redirected stdout to. While a long child is still running, `bash_output` returns what it has written since the previous read; `bash_kill` stops a child that is wedged or no longer needed.

Grade each child by exit code:

- **0** — the turn finished, and so did every follow-up turn.
- **1** — runtime error (provider, network, tool exception). Retry once.
- **2** — invocation or configuration failure: no credentials for a provider, unparseable settings/auth. An empty report; fix the environment rather than retrying blind.
- **3** — the turn ended but did not complete (`max_steps`, `context_window`, `content_filter`, …), or the child's own background jobs passed its idle timeout; the reason is on stderr.
- **130** — the child was interrupted.

Check the report's shape, not just its presence. A child that can't do its job still exits 0 — with a clarifying question as its "report". State the report's first-line marker in the prompt and treat non-conforming output as a failure; the retry's prompt answers the child's question.

Keep fan-outs bounded — five to eight concurrent children; batch beyond that.

## Follow up on a child

A saved child is resumable — the cheap retry when a child asked a clarifying question or stopped short, instead of paying the cold start again. Resume from the id: `riffer -p -r <id> "follow-up"`, which works from any directory. Capture the id at spawn: headless prints `session <id>` on stderr when the session starts (in `--json` mode it rides on the `session_start` record instead), so it is in the stderr file you kept — `grep -m1 '^session '` it. A `--no-save` child has no session to resume. Avoid `-c` for follow-ups — it continues the most recent session in the _current_ directory only, which is ambiguous after a parallel fan-out; it also reads as if it takes the prompt as its value, but `-c` is valueless and the prompt is just the `-p` argument.

## Children that run long

Headless waits for background jobs a child leaves running: each exit hands the child a further turn, and the run ends only when no job is left. An idle timeout (`--job-idle-timeout`, 600s by default) kills stragglers and exits 3 — which is what keeps a dev server or a file watcher from holding a child open forever. A delegated build that starts long-running processes must either be told in its prompt to kill its background jobs before reporting, or carry an explicit `--job-idle-timeout`.

## The child prompt

A child knows nothing except what's in its prompt and what it can read from disk. Every prompt carries:

1. **Role and output.** What the child is, and that it prints **only its report**, opening with the report's first-line marker.
2. **Reference files by absolute path** — criteria, rule files, whatever the task grades against. Instruct the child to read them and hold them **verbatim**.
3. **Computed facts, pre-resolved.** Anything the parent already knows — the `BASE` commit and scope commands, file paths, ticket numbers. Children never re-derive shared facts.
4. **The one task.** Loop state and gate decisions stay with the parent.
