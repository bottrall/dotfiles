---
name: riffer-subagent
description: Spawn headless riffer subagents (riffer -p children) for fresh-context or concurrent work — parallel reviewers, per-ticket research, delegated builds.
---

# Subagents on riffer

A subagent is a headless riffer run: `riffer -p` in a child process — same settings, auth, AGENTS.md and skills as this session, fresh context, and only its stdout comes back. Caller skills (`inspect`, `build`, `wayfinder`) say **what** to spawn; this skill is **how**.

## When to spawn

- **The subtask's reading would flood this session** — reviewing a diff, researching a topic, summarizing a branch. Only the child's report comes back; the reading stays in the child.
- **The subtasks can run concurrently** — one reviewer per lens, one validator per finding. Children are OS processes, so fan-out is real parallelism.

Do it in-session when the subtask is trivial or needs context already accumulated here — every child pays a cold start.

Children are **read-only by convention**: they review, research, summarize, report. The driving session does the mutating — the one exception is a delegated build, which owns its worktree work by explicit instruction in its prompt.

## Spawn, wait, collect

Everything happens in **one bash call** — each bash invocation is a fresh shell, so the children must be spawned, waited on, and collected together:

```bash
work=$(mktemp -d)
run_child() {  # $1=name  $2=prompt-file  $3=timeout-secs
  timeout "${3:-900}" riffer -p --no-save < "$2" \
    > "$work/child-$1.md" 2> "$work/child-$1.err" &
  echo "$1 $!" >> "$work/child-pids"
}
: > "$work/child-pids"
run_child security "$work/prompt-security.md" 900
run_child correctness "$work/prompt-correctness.md" 900
# … one line per child
while read -r name pid; do
  wait "$pid"; echo "$?" > "$work/child-$name.exit"
done < "$work/child-pids"
while read -r name _; do
  echo "=== $name (exit $(cat "$work/child-$name.exit"))"
  cat "$work/child-$name.md"
done < "$work/child-pids"
```

- **Prompt via stdin** — `riffer -p` reads the prompt from stdin when given no argument; write each child's prompt to a temp file first.
- **Capture each child's exit code** — exit 2 with an empty report is an invocation failure: a provider this environment doesn't authenticate kills the child at startup.
- **Check the report's shape, not just its presence.** A child that can't do its job still exits 0 — with a clarifying question as its "report". State the report's first-line marker in the prompt and treat non-conforming output as a failure; the retry's prompt answers the child's question.
- **`timeout` per child** so one wedged child can't hold the loop; a timed-out child is retried once, serially. The default suits a review pass; a delegated build runs long and gets a larger timeout from its caller.
- **Keep stderr** — it carries the only diagnostics when a child fails.

Keep fan-outs bounded — five to eight concurrent children; batch beyond that.

## The child prompt

A child knows nothing except what's in its prompt and what it can read from disk. Every prompt carries:

1. **Role and output.** What the child is, and that it prints **only its report**, opening with the report's first-line marker.
2. **Reference files by absolute path** — criteria, rule files, whatever the task grades against. Instruct the child to read them and hold them **verbatim**.
3. **Computed facts, pre-resolved.** Anything the parent already knows — the `BASE` commit and scope commands, file paths, ticket numbers. Children never re-derive shared facts.
4. **The one task.** Loop state and gate decisions stay with the parent.
