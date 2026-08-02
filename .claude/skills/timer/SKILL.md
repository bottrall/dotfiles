---
name: timer
description: Track contracting time in the Notion Time Tracking database — start, pause, resume, and stop a work timer
disable-model-invocation: true
---

# Timer

You own the clock for this conversation: start on invocation, pause whenever you hand back and wait on the user, stop when the work is done or ready for review (usually a PR with CI green). The user should never have to ask.

Other sessions may be running their own timers. Only ever touch rows carrying your own `Session`.

## Database

Contracting → [Time Tracking](https://app.notion.com/p/5f92ddfb5b2e45c78e322959ade2c53a) · data source `62e152ba-020a-4a09-aafe-345689efd00e`

Two shapes of row:

- **Task** (parent) — `Description` is the task name, plus `Client` and `Category`. No dates.
- **Segment** (sub-item) — one unbroken stretch of work: `Parent item` → its task, plus `Session`, `Start`, `End`, and a `Description` of what you did. A pause is the gap between two segments, not a field.

`Hours`, `Total Hours`, `First worked`, `Last worked` and `State` are computed — never write them, and they can't be read back through SQL.

Your `Session` is `<repo>@<first 8 chars of the session-id directory in your scratchpad path>`, e.g. `armax@fd4ae7db`.

## Lifecycle

**Start** — `date -Iseconds` for the timestamp; find the task with `notion-search` (unmetered) or create it if genuinely new; create a segment with `Parent item`, `Session` and `Start`. Keep both page IDs in context.

**Pause** — set `End` before any reply that waits on the user. Waiting isn't billable.

**Resume** — gap under ~2 minutes, clear `End` on the same segment; longer, open a new segment under the same task.

**Stop** — set `End`, then rewrite the segment's `Description` to say what was delivered (ticket, root cause, PR, outcome) — it's an invoice line someone reads months later. Stop as well if the user moves on or abandons the work; log what was spent and say so.

## Rules

- One running segment per session.
- Local timestamps only (`2026-08-02T15:04:05-07:00`); UTC silently shifts everything.
- Trim time the client shouldn't pay for — your wrong turns, a runaway test run — and note the deduction.
- Concurrent sessions overlap, and overlapping minutes are one hour of wall clock, not two. Never present a billable total above wall clock.

## Calls

Create a segment — `notion-create-pages`, parent `{ "data_source_id": "62e152ba-020a-4a09-aafe-345689efd00e" }`:

```json
{
  "Description": "Investigating tRPC validation 500s",
  "Parent item": ["https://app.notion.com/<task-id>"],
  "Session": "armax@fd4ae7db",
  "Client": "Argus Vision",
  "Category": "Bug Fixing",
  "date:Start:start": "2026-08-02T15:04:05-07:00",
  "date:Start:is_datetime": 1
}
```

Close it — `notion-update-page`, `update_properties`: `{ "date:End:start": "…", "date:End:is_datetime": 1 }`. Resume with `{ "date:End:start": null }`.

If you ever need to query the table: segments are the rows with a `Start`, tasks the rows without. Select relation columns directly — wrapping one in `CASE` or an aggregate silently yields `NULL`.
