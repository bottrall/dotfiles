# dotfiles

Personal dotfiles for macOS and Arch Linux.

## What's included

**Shell** — `.zshrc` (macOS), `.bashrc` (Linux)

**Git** — `.gitconfig`, global ignore, post-checkout hook

**Terminal** — Ghostty

**Prompt** — Starship

**Hyprland** (Linux) — Hyprland, Hyprpaper, Hypridle, Hyprlock, Waybar, Wofi, swaync, clipse, btop, swappy, GTK 3/4

**hotglass** (Linux) — the desktop's design system: black glass, one electric pink, sharp edges. `.config/hotglass/tokens.yml` is the single source of truth; `.config/hotglass/generate` (Ruby) rewrites every derived color file (GTK CSS, hypr conf, wofi tokens, starship palette, clipse theme, icon theme). See `.config/hotglass/DESIGN.md` for principles, tokens, and scope.

**repos** — `.config/sh/repos.sh` prints the machine-local project list from `~/.repos.local` (untracked, one path per line, `#` comments, `~` expansion). The shared source of truth for any script that iterates local repos.

**sweep** — `.config/sh/sweep.sh` resets the dev environment: brew upgrade/cleanup, and for each repo from `repos` it switches to the default branch, pulls, deletes local branches not backed by a worktree, reinstalls deps, and runs git maintenance; then it uninstalls node/ruby versions no repo pins and prunes pnpm/gem/nvm/docker caches. Supports `--dry-run`.

**Claude Code** — everything under `.claude/`, symlinked into `~/.claude/`: global instructions (`CLAUDE.md`), `settings.json`, and `skills/`.

`CLAUDE.md` is deliberately project- and language-agnostic — only what's worth loading into *every* session. Language conventions, testing rules, and lint-enforceable style belong in each project's own `CLAUDE.md`.

**riffer-rig** — everything under `.riffer/`, symlinked into `~/.riffer/` for [riffer-rig](https://github.com/bottrall/riffer-rig). It mirrors `.claude/` so both tools coexist; `.claude/` is untouched. What maps:

- `AGENTS.md` ← `CLAUDE.md`, content unchanged apart from `<!-- TODO -->` markers where the sign-off and commit trailers still say "Claude".
- `settings.json` ← `model` and `effortLevel` become `model` (`openrouter/z-ai/glm-5.3-flash`) and `reasoning`, plus a `models` pricing entry for that model (USD per million tokens, from openrouter.ai; OpenRouter lists no separate cache-write price, so it is set equal to the input price). Nothing else from `.claude/settings.json` has an equivalent — `env`, `permissions`, `enabledPlugins`, `tui`, `voice`, notification and `autoMemory` keys are dropped rather than carried as dead keys. `settings.local.json` is a permission allowlist and has no counterpart because riffer-rig has no permission model.
- `skills/` ← the same skill names, ported mechanically as **single-agent variants**: riffer-rig has no subagents, so `code-review` walks the five lenses in order and validates each finding itself, and `build-loop` builds, reviews and ships in one session. Inlined `!`cat`` blocks become "read this file" instructions with absolute `~/.riffer/...` paths (`code-review/criteria.md`, `wayfinder/trackers/`), question tools become one prose question per reply, todo lists become a checklist in the reply, and web fetches become `curl`. Steps that need a missing capability are kept and marked `(not available in riffer-rig yet)`. Activate a skill with `/skill:<name>`.

`~/.riffer/auth.json` holds API keys; `install.sh` never links or creates it and `.gitignore` guards it.

## Usage

```sh
git clone git@github.com:bottrall/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## How install.sh works

The script detects the OS and symlinks each config file/directory to its corresponding location under `~`. Shared configs are always linked; platform-specific configs (zsh on macOS, bash + Hyprland on Linux) are linked conditionally.

If a file already exists at the target path, it gets moved to `~/.dotfiles-backup/` before the symlink is created. Existing symlinks pointing to the correct source are left as-is, making the script safe to re-run.
