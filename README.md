# dotfiles

Personal dotfiles for macOS and Arch Linux.

## What's included

**Shell** — `.zshrc` (macOS), `.bashrc` (Linux)

**Git** — `.gitconfig`, global ignore, post-checkout hook

**Terminal** — Ghostty, htop

**Prompt** — Starship

**Hyprland** (Linux) — Hyprland, Hyprpaper, Hypridle, Hyprlock, Waybar, Wofi

**Claude Code** — everything under `.claude/`, symlinked into `~/.claude/`: global instructions (`CLAUDE.md`), `settings.json`, and `skills/`.

`CLAUDE.md` is deliberately project- and language-agnostic — only what's worth loading into *every* session. Language conventions, testing rules, and lint-enforceable style belong in each project's own `CLAUDE.md`.

## Usage

```sh
git clone git@github.com:bottrall/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## How install.sh works

The script detects the OS and symlinks each config file/directory to its corresponding location under `~`. Shared configs are always linked; platform-specific configs (zsh on macOS, bash + Hyprland on Linux) are linked conditionally.

If a file already exists at the target path, it gets moved to `~/.dotfiles-backup/` before the symlink is created. Existing symlinks pointing to the correct source are left as-is, making the script safe to re-run.
