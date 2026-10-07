### Tracker

My work lives in GitHub Issues, and on some machines also in Jira; they stay the source of truth. Anything machine-specific — Jira site and cloudId, projects, issue repos, path mappings, routing rules — comes from `~/.work.local.md` if it exists. Read it before any tracker operation. Whatever it doesn't set falls back to these defaults, so no config at all means GitHub only:

- **Jira:** none. A Jira reference is an error — say Jira isn't configured on this machine.
- **Issue repos:** any repo. `ticketFor` reads `<n>-` branches as issues in the PR's own repo.
- **Paths:** none — no part of the codebase maps to a project.
- **Routing:** a GitHub issue in the current repo.

Jira goes through the Atlassian MCP tools, passing the config's cloudId. GitHub goes through `gh`. My GitHub login: `gh api user -q .login`.

**References.** A ticket reference is a Jira key (`ABC-123`), a Jira URL (`…/browse/ABC-123`), or a GitHub issue URL (`https://github.com/<owner>/<repo>/issues/<n>`).

**resolve(ref)** → key or `<owner>/<repo>#<n>`, URL, summary, description, status, assignee. Jira via the MCP issue lookup; GitHub via `gh issue view <n> -R <owner>/<repo> --json number,title,body,url,state,assignees`.

**branchFor(ticket)** — the branch naming convention. Jira: `<KEY>-<n>-<slug>`. GitHub issue: `<n>-<slug>`. The slug is the summary/title lowercased, every run of non-alphanumerics replaced with `-`, trimmed of leading/trailing `-`; cut the whole name at a `-` boundary to ≤ 60 chars. Before creating a new name, reuse an existing branch if one already belongs to the ticket: any local or `origin/` branch starting with the key or `<n>-` (case-insensitive, `git branch -a --list`), or for GitHub a linked branch from `gh issue develop --list <n> -R <owner>/<repo>`.

**ticketFor(branch, pr)** — the inverse, so it must stay in step with branchFor. A leading `<KEY>-<n>` whose KEY is one of the config's Jira projects (case-insensitive) is that Jira ticket. A leading `<n>-` is that GitHub issue when the PR's repo is one of the issue repos (with the default, always). Also count any `closingIssuesReferences` on the PR. Nothing matched: no ticket.

**projectFor(path)** and **pathsFor(ticket)** — the config's Paths mapping, read in both directions, so it has one owner. `projectFor` returns the destination of the longest mapped path containing `path`, reading a worktree path `~/<repo>.worktrees/<branch>/<rest>` as `~/<repo>/<rest>`; no match, none. `pathsFor` returns every mapped path whose destination is the ticket's Jira project (or, for a GitHub issue, its repo), each as `{ repo: the git root containing it, subdir: the rest }`.

**transition(ticket, category)** — category is To Do, In Progress, or Done.

- Jira: workflows differ per project, so never hardcode a transition ID. Skip if the status is already in that category. Otherwise fetch the issue's available transitions and pick the one whose target status is in the category, preferring one named exactly "In Progress" / "Done". If none fits, or several fit and none has the exact name, ask which to use. Moving to In Progress also assigns it to me if it's unassigned.
- GitHub: In Progress → `gh issue edit <n> -R <repo> --add-assignee @me` if I'm not assigned. Done → if still open, `gh issue close <n> -R <repo> --reason completed` (no comment).

**route(description, conversation)** → destination. Apply the config's routing rules; where they defer to Paths, use `projectFor` on the directory the work is about — the conversation's, or else the current one. Where a rule says to ask unless the context is obvious, only skip asking when this conversation makes the answer unambiguous; otherwise ask with `AskUserQuestion`, one option per destination.

**create(destination, title, body)** → key or number, URL. Jira via the MCP create tool (issue type Task, assigned to me, unless I said otherwise). GitHub via `gh issue create -R <repo> --assignee @me --title … --body …`. Never call this without my confirmation of the exact draft — GitHub issues are public.
