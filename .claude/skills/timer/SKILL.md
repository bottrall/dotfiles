---
name: timer
description: Track contracting time with the punch CLI — start, stop, and report on a work timer for this session
disable-model-invocation: true
---

# Timer

You own the clock for this conversation: start on invocation, stop whenever you hand back and wait on the user, stop for good when the work is done or ready for review (usually a PR with CI green). The user should never have to ask.

Time is tracked with `~/punch/bin/punch` (invoke it by that path; the commands below abbreviate it to `punch`). It finds its database via the repo's `.env`, and derives this session's identity (`<repo>@<first 8 of session id>`) from `$CLAUDE_CODE_SESSION_ID` and the cwd, so every command is scoped to your own timer — other sessions run theirs concurrently without conflict.

## Lifecycle

**Start** — look the task up with `punch tasks`, then `punch start "<exact name>"` (or `punch start <id>`). Only if the work is genuinely new: `punch start "Name" --create --client "Argus Vision" --category "Development" --note "what you're doing"` (categories: Development, Bug Fixing). On a not-found error, check the suggested close matches before reaching for `--create` — never fork a near-duplicate task.

**Pause** — `punch stop` before any reply that waits on the user. Waiting isn't billable. There is no separate resume: `punch start` on the same task within ~2 minutes reopens the same segment; after longer it opens a new one. Both are correct.

**Stop** — `punch stop --note "<invoice line>"`: what was delivered — ticket, root cause, PR, outcome. It's an invoice line someone reads months later. Stop as well if the user moves on or abandons the work; log what was spent and say so.

## Rules

- One running segment per session — punch enforces it and `start` errors while one is running; stop first.
- Timestamps are punch's job. Pass `--at` only to trim time the client shouldn't pay for — your wrong turns, a runaway test run — and note the deduction.
- Concurrent sessions overlap, and overlapping minutes are one hour of wall clock, not two. `punch report` shows billed vs wall clock and warns when they differ; never present a billable total above wall clock.
- `punch status` shows every session's running timer; touch only your own (default behavior — no flags needed).
