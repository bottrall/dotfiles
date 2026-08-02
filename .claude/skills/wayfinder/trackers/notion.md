# Wayfinding operations — Notion

Uses the Notion MCP tools. The map is a **page**; its tickets are rows in a **Tickets database** created inside that page, so "child of the map" is literal containment. Blocking is a self-relation on that database, which Notion renders as linked rows on every ticket.

Before the first call, read the MCP resource `notion://docs/enhanced-markdown-spec` (or `notion-fetch` that URI) — Notion-flavored Markdown is not CommonMark, and guessing its syntax corrupts page content.

## One-time setup

**1. Create the map page.** Ask the user which Notion page should hold it (`notion-search` to find candidates) — there is no repo to infer a home from, so this is the one thing that can't be defaulted.

`notion-create-pages` with `parent: {page_id: <chosen page>}`, the map name as title, and the map body as `content`.

**2. Create the Tickets database** inside the map page, via `notion-create-database` with `parent: {page_id: <map page id>}`, title `Tickets`:

```sql
CREATE TABLE (
  "Name" TITLE,
  "Type" SELECT('research':blue, 'prototype':purple, 'grilling':orange, 'task':gray),
  "Status" SELECT('Open':gray, 'Closed':green),
  "Assignee" PEOPLE
)
```

The question is the page's **content**, not a property — it needs to be long-form, and properties truncate.

**3. Add the blocking self-relation.** A relation can't reference a database that doesn't exist yet, so this is a second call — `notion-update-data-source` on the data source id returned by step 2:

```sql
"Blocked by" RELATION('<data_source_id>', DUAL 'Blocking' 'blocking')
```

`DUAL` is what makes it two-way: setting *Blocked by* on one ticket populates *Blocking* on the other, which is what renders the frontier visually.

Record the map page URL and the data source id (`collection://<id>`) in the map's Notes — every later session needs both, and rediscovering them costs a search.

## Create a ticket

`notion-create-pages` with `parent: {data_source_id: <ds_id>}`, properties `{Name, Type, Status: "Open"}`, and the question as `content`. Leave `Assignee` unset — unassigned *is* unclaimed.

Pass all the tickets in one call; the tool takes up to 100 pages per invocation.

## Wire a blocking edge

Second pass, once the rows exist and have ids: `notion-update-page` on the blocked ticket, setting `Blocked by` to the blocking tickets' page ids.

## Query the frontier

A map holds tens of tickets, not thousands, so fetch them all in one query and compute the frontier in context rather than trying to express "every blocker is closed" in SQL across a relation:

```sql
SELECT * FROM "collection://<data_source_id>"
```

via `notion-query-data-sources`. The frontier is the rows where `Status` is `Open`, `Assignee` is empty, and every row named in `Blocked by` is `Closed` in the same result set. The `Blocked by` column comes back as references to the related rows — match them against the rows you already have rather than issuing a query per ticket.

## Claim a ticket

`notion-update-page`, setting `Assignee` to the dev driving the map. Before any work.

## Resolve a ticket

`notion-create-comment` on the ticket page with the answer, then `notion-update-page` setting `Status` to `Closed`. The comment is the resolution record; don't append the answer to the page body, which holds the question.

## Update the map body

`notion-update-page` on the map page. Fetch it immediately before writing — concurrent sessions edit the same map, and a stale read silently clobbers their appends.

## Names and links

A ticket's name is its title and its link is its page URL, both returned by `notion-fetch` and by the query above.
