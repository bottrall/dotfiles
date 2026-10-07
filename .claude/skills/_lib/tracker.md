### Tracker

My work lives in GitHub Issues, and on some machines also in Jira; they stay the source of truth. Anything machine-specific — Jira site and cloudId, projects, issue repos, path mappings, routing rules — comes from `~/.work.local.md` if it exists. Read it before any tracker operation. Whatever it doesn't set falls back to these defaults, so no config at all means GitHub only:

- **Jira:** none. A Jira reference is an error — say Jira isn't configured on this machine.
- **Issue repos:** any repo. `ticketFor` reads `<n>-` branches as issues in the PR's own repo.
- **Paths:** none — no part of the codebase maps to a project.
- **Routing:** a GitHub issue in the current repo.

Jira goes through the Atlassian MCP tools, passing the config's cloudId. GitHub goes through `gh`. My GitHub login: `gh api user -q .login`.

**References.** A ticket reference is a Jira key (`ABC-123`), a Jira URL (`…/browse/ABC-123`), or a GitHub issue URL (`https://github.com/<owner>/<repo>/issues/<n>`).

**resolve(ref)** → key or `<owner>/<repo>#<n>`, URL, summary, description, status, assignee. Jira via the MCP issue lookup; GitHub via `gh issue view <n> -R <owner>/<repo> --json number,title,body,url,state,assignees`.

**Public repos.** Jira is internal; a public repo (`gh repo view --json visibility -q .visibility` is `PUBLIC`) must never show a Jira ticket: no key, URL, or summary in branch names, commits, PR titles or bodies, and nothing that only makes sense with access to the ticket. Describe the change in its own terms. The ticket points at the PR instead, through `link`.

**branchFor(ticket)** — the branch naming convention. Jira: `<KEY>-<n>-<slug>`, except in a public repo, where it's just `<slug>`; then record the ticket privately with `git config branch.<name>.ticket <KEY>` (local only, and shared by every worktree). GitHub issue: `<n>-<slug>`. The slug is the summary/title lowercased, every run of non-alphanumerics replaced with `-`, trimmed of leading/trailing `-`; cut the whole name at a `-` boundary to ≤ 60 chars. Before creating a new name, reuse an existing branch if one already belongs to the ticket: any local or `origin/` branch starting with the key or `<n>-` (case-insensitive, `git branch -a --list`), one whose `branch.<name>.ticket` is the key (`git config --get-regexp '^branch\..*\.ticket$'`), or for GitHub a linked branch from `gh issue develop --list <n> -R <owner>/<repo>`.

**ticketFor(branch, pr)** — the inverse, so it must stay in step with branchFor. A leading `<KEY>-<n>` whose KEY is one of the config's Jira projects (case-insensitive) is that Jira ticket, and so is `git config branch.<branch>.ticket`. A leading `<n>-` is that GitHub issue when the PR's repo is one of the issue repos (with the default, always). Also count any `closingIssuesReferences` on the PR. If there's a PR and still no Jira ticket, ask Jira which ticket links it: search JQL `project in (<projects>) AND issue in issuesWithRemoteLinksByGlobalId("<PR URL>")`. Nothing matched: no ticket. docket (`~/docket/lib/docket/refs.rb`) does the same matching, so change both together.

**link(ticket, pr)** — make a Jira ticket point at its PR, for a public repo, where nothing on the PR side can. Call it after the PR is created or updated. It adds a remote link (shown under "Web links") whose `globalId` is the PR URL; that's what `ticketFor` and docket search on. Jira treats an existing `globalId` as an update, so calling it again never duplicates the link. Don't use the MCP web-link tool: it can't set a `globalId`, so nothing could find the link afterwards and every call would add another. Use the REST API with the config's email and the API token (`$JIRA_API_TOKEN`, else `security find-generic-password -s jira-api-token -a <email> -w`), and never print the token:

```sh
curl -sSf -u "<email>:$(security find-generic-password -s jira-api-token -a <email> -w)" \
  -H 'Content-Type: application/json' -X POST "<site>/rest/api/3/issue/<KEY>/remotelink" \
  -d '{"globalId":"<PR URL>","object":{"url":"<PR URL>","title":"<owner>/<repo>#<n>: <PR title>"}}'
```

If it fails, say so and carry on. It doesn't block shipping.

**projectFor(path)** and **pathsFor(ticket)** — the config's Paths mapping, read in both directions, so it has one owner. `projectFor` returns the destination of the longest mapped path containing `path`, matching on the path relative to the repo root, so a worktree path maps the same as the main checkout; no match, none. `pathsFor` returns every mapped path whose destination is the ticket's Jira project (or, for a GitHub issue, its repo), each as `{ repo: the git root containing it, subdir: the rest }`.

**transition(ticket, category)** — category is To Do, In Progress, or Done.

- Jira: workflows differ per project, so never hardcode a transition ID. Skip if the status is already in that category. Otherwise fetch the issue's available transitions and pick the one whose target status is in the category, preferring one named exactly "In Progress" / "Done". If none fits, or several fit and none has the exact name, ask which to use. Moving to In Progress also assigns it to me if it's unassigned.
- GitHub: In Progress → `gh issue edit <n> -R <repo> --add-assignee @me` if I'm not assigned. Done → if still open, `gh issue close <n> -R <repo> --reason completed` (no comment).

**route(description, conversation)** → destination. Apply the config's routing rules; where they defer to Paths, use `projectFor` on the directory the work is about — the conversation's, or else the current one. Where a rule says to ask unless the context is obvious, only skip asking when this conversation makes the answer unambiguous; otherwise ask with `AskUserQuestion`, one option per destination.

**create(destination, title, body)** → key or number, URL. Jira via the MCP create tool (issue type Task, assigned to me, unless I said otherwise). GitHub via `gh issue create -R <repo> --assignee @me --title … --body …`. Never call this without my confirmation of the exact draft — GitHub issues are public.
