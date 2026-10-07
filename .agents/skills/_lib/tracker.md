### Tracker

My work lives in GitHub Issues; it stays the source of truth. Everything goes through `gh`. My GitHub login: `gh api user -q .login`.

Anything machine-specific — issue repos, routing rules — comes from `~/.work.local.md` if it exists. Read it before any tracker operation. Whatever it doesn't set falls back to these defaults:

- **Issue repos:** any repo. `ticketFor` reads `<n>-` branches as issues in the PR's own repo.
- **Routing:** a GitHub issue in the current repo.

**References.** A ticket reference is a GitHub issue URL (`https://github.com/<owner>/<repo>/issues/<n>`).

**resolve(ref)** → `<owner>/<repo>#<n>`, URL, title, body, state, assignees: `gh issue view <n> -R <owner>/<repo> --json number,title,body,url,state,assignees`.

**branchFor(ticket)** — the branch naming convention: `<n>-<slug>`. The slug is the title lowercased, every run of non-alphanumerics replaced with `-`, trimmed of leading/trailing `-`; cut the whole name at a `-` boundary to ≤ 60 chars. Before creating a new name, reuse an existing branch if one already belongs to the issue: a linked branch from `gh issue develop --list <n> -R <owner>/<repo>`, or any local or `origin/` branch starting with `<n>-` (`git branch -a --list`).

**ticketFor(branch, pr)** — the inverse, so it must stay in step with branchFor. A leading `<n>-` is that issue when the PR's repo is one of the issue repos (with the default, always). Also count any `closingIssuesReferences` on the PR. Nothing matched: no ticket.

**transition(ticket, state)** — In Progress: `gh issue edit <n> -R <repo> --add-assignee @me` if I'm not assigned. Done: if still open, `gh issue close <n> -R <repo> --reason completed` (no comment).

**route(description, conversation)** → repo. Apply the routing rules. Where a rule says to ask unless the context is obvious, only skip asking when this conversation makes the answer unambiguous; otherwise ask one prose question listing the repos, and wait for my reply.

**create(repo, title, body)** → number, URL: `gh issue create -R <repo> --assignee @me --title … --body …`. Never call this without my confirmation of the exact draft — issues are public.
