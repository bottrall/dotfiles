---
name: track
description: Capture new work as a ticket in the right place — the right Jira project or a GitHub issue — after I confirm the draft
disable-model-invocation: true
---

# Track

Turn a description of new work into a ticket in the right tracker.

<tracker>
!`cat ~/.claude/skills/_lib/tracker.md`
</tracker>

## Steps

1. **What:** the skill argument is the description. With no argument, use the work established in this conversation; if that isn't clear, ask what to track.
2. **Where:** `route(description, conversation)`.
3. **Draft:** a short title, plus a body only if the description carries more than a title's worth — context, acceptance criteria, links from this conversation. Write it as the ticket itself, not as a message from me. Show me the destination and the draft in one block. Name the session so its tab says what's being tracked: `Track: <a few words of the draft title>`, under ~40 characters, via `mcp__ccd_session_mgmt__set_session_title` with `session_id: "self"` (load it via ToolSearch if it's deferred; skip if it isn't available).
4. **Create:** once I confirm (or after I edit the draft), `create(destination, title, body)`.
5. **Report:** the new key or number and its URL, plus the command to start it: `/build <url>`.
