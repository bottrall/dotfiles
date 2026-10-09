# Wayfinding operations — Local Markdown

Used by `/skill:wayfinder`. Issues live as markdown files in `.scratch/`: the **map** is a file with one **child** file per ticket, all under `.scratch/<effort>/`.

- **Create the map**: write `.scratch/<effort>/map.md` — a `# <map name>` title line, then the map body (creating the directory if needed).
- **Create a ticket**: `.scratch/<effort>/issues/NN-<slug>.md`, numbered from `01` — one file per ticket, never a combined file — opening with a `# <ticket name>` title line, then the question body. A `Type:` line records the ticket type (`research`/`prototype`/`grilling`/`task`); a `Status:` line records `open`/`claimed`/`resolved`/`out-of-scope`. New tickets start `Status: open`.
- **Wire a blocking edge**: a `Blocked by: NN, NN` line near the top. A ticket is unblocked when every file it lists is `resolved` or `out-of-scope`.
- **Query the frontier**: scan `.scratch/<effort>/issues/` for files with `Status: open` that are unblocked; first by number wins.
- **Claim**: set `Status: claimed` and save before any work.
- **Resolve**: append the answer under an `## Answer` heading, set `Status: resolved`, then append a context pointer (gist + link) to the map's Decisions-so-far in `map.md`.
- **Close as out of scope**: set `Status: out-of-scope`. It counts as closed — it never blocks anything and never rejoins the frontier.
- **Update the map body**: edit `map.md` in place. Re-read it immediately before writing — concurrent sessions edit the same file, and a stale read silently clobbers their appends.
- **Names and links**: a map or ticket's name is its `#` title line; its link is its path relative to the repo root.
