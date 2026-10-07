---
name: track
description: Capture new work as a GitHub issue in the right repo, after I confirm the draft
disable-model-invocation: true
---

# Track

Turn a description of new work into a GitHub issue in the right repo.

Before anything else, read the file `~/.agents/skills/_lib/tracker.md` with the read tool and follow its Tracker operations exactly as written.

## Steps

1. **What:** the skill argument is the description. With no argument, use the work established in this conversation; if that isn't clear, ask what to track.
2. **Where:** `route(description, conversation)`.
3. **Draft:** a short title, plus a body only if the description carries more than a title's worth — context, acceptance criteria, links from this conversation. Write it as the ticket itself, not as a message from me. Show me the destination and the draft in one block.
4. **Create:** once I confirm (or after I edit the draft), `create(destination, title, body)`.
5. **Report:** the new issue number and its URL, plus the command to start it: `/skill:build <url>`.
