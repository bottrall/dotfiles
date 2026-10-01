# Wayfinding operations — GitHub Issues

Uses `gh`. Every operation below is native: sub-issues give the map its children, issue dependencies give real blocking edges, so the frontier renders visually in GitHub's own UI.

Set once per session:

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
```

`MAP` below is the map issue's number.

## One-time setup

Labels must exist before they can be applied. Creating an existing label is an error, so ignore failures:

```bash
for l in map research prototype grilling task; do
  gh label create "wayfinder:$l" --color ededed 2>/dev/null || true
done
```

## Create the map

```bash
gh issue create --repo "$REPO" --title "<map name>" --label wayfinder:map --body-file map.md
```

Write the body to a file first — map bodies are long and multi-line, and `--body` mangles them.

## Create a ticket

A ticket is a sub-issue of the map, carrying exactly one `wayfinder:<type>` label:

```bash
gh issue create --repo "$REPO" --title "<ticket name>" \
  --label "wayfinder:<research|prototype|grilling|task>" \
  --parent "$MAP" --body-file ticket.md
```

## Wire a blocking edge

Second pass, after the tickets exist and have numbers:

```bash
gh issue edit <ticket> --repo "$REPO" --add-blocked-by <blocker>,<blocker>
```

`gh issue create` also accepts `--blocked-by` when the blocker already exists — but a batch of new tickets that block each other needs the two-pass create-then-wire.

## Query the frontier

Open, unassigned children of the map:

```bash
gh api "repos/$REPO/issues/$MAP/sub_issues" --paginate \
  --jq '.[] | select(.state == "open") | select(.assignees | length == 0) | "\(.number)\t\(.title)"'
```

Then keep only the unblocked — a ticket is unblocked when it has no _open_ blocker. For each candidate number `N`:

```bash
gh api "repos/$REPO/issues/$N/dependencies/blocked_by" \
  --jq '[.[] | select(.state == "open")] | length'
```

`0` means takeable. Closed blockers stay listed in the relationship forever, so counting `blockedBy` alone is wrong — filter on `state`.

## Claim a ticket

Before any work:

```bash
gh issue edit <ticket> --repo "$REPO" --add-assignee @me
```

`@me` resolves to the authenticated user. If the map is driven by someone else, use their handle instead.

## Resolve a ticket

Comment the answer, then close:

```bash
gh issue comment <ticket> --repo "$REPO" --body-file answer.md
gh issue close <ticket> --repo "$REPO"
```

## Update the map body

Read, edit, write back — there is no partial-body edit:

```bash
gh issue view "$MAP" --repo "$REPO" --json body -q .body > map.md
# edit map.md
gh issue edit "$MAP" --repo "$REPO" --body-file map.md
```

Re-read immediately before writing. Concurrent sessions edit the same map body, and a stale read silently clobbers their appends.

## Names and links

Every issue's name is its title, and its link is its URL:

```bash
gh issue view <n> --repo "$REPO" --json title,url -q '"[\(.title)](\(.url))"'
```
