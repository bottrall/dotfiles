---
name: triage
description: One list of all my open work across Jira and GitHub — in progress, waiting on my review, up next, and anything out of sync with its PR
disable-model-invocation: true
---

# Triage

Read-only by default: gather everything on my plate into one numbered list. Jira and GitHub stay the source of truth; nothing is copied anywhere.

<tracker>
!`cat ~/.claude/skills/_lib/tracker.md`
</tracker>

## Gather

In parallel:

- **Tickets:** `listMine()`.
- **PRs:** one `gh api graphql` call with two `search` blocks, each with the config's PR scope and `archived:false` appended — `is:pr is:open author:@me`, and the config's review-request query. For each PR fetch `number title url isDraft createdAt reviewDecision headRefName author { login } repository { nameWithOwner } closingIssuesReferences(first: 5) { nodes { number } } commits(last: 1) { nodes { commit { statusCheckRollup { state } } } }`.
- **Recently merged:** `is:pr is:merged author:@me merged:>=<14 days ago>` with the same scope — `headRefName`, `url`, `repository`, `closingIssuesReferences` only.

Match each of my PRs to a ticket with `ticketFor(headRefName, pr)`.

## Report

One numbered list — numbers run across sections so I can refer to "3" — with these sections, skipping empty ones:

1. **In progress** — tickets in an In Progress category status, and tickets with an open PR. Show the PR: draft / ready, CI ✅ ❌ ⏳, review decision.
2. **Waiting on your review** — repo, title, author, age.
3. **Your PRs without a ticket** — open PRs of mine that matched nothing.
4. **Up next** — To Do tickets with no PR.
5. **Out of sync** — status disagrees with the PR: ticket not Done but its PR merged; ticket To Do but it has an open PR. Say what the fix would be.

Each item is one line: `<n>. <KEY or repo#n> <title> — <status / PR state> <url>`.

End with one line: `/build <ticket url>` · `/inspect <pr url>` · `/finish` (in that session) · `/track "<description>"`.

If I then ask to fix out-of-sync items, apply the `transition`s directly — that's me approving.
