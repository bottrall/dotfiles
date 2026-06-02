# dotfiles

Personal dotfiles for macOS and Arch Linux.

## What's included

**Shell** — `.zshrc` (macOS), `.bashrc` (Linux)

**Git** — `.gitconfig`, global ignore, post-checkout hook

**Terminal** — Ghostty, htop

**Prompt** — Starship

**Hyprland** (Linux) — Hyprland, Hyprpaper, Hypridle, Hyprlock, Waybar, Wofi

**Agents** — harness-agnostic instructions, docs, and skills live in `.agents/` (`AGENTS.md`, `docs/`, `skills/`) as the source of truth. `install.sh` symlinks them into Claude Code's locations (`~/.claude/CLAUDE.md` → `.agents/AGENTS.md`, plus `docs/` and `skills/`), so other harnesses can point at the same `.agents/` later.

**Claude Code** — harness-specific `settings.json` (lives in `.claude/`)

## Usage

```sh
git clone git@github.com:bottrall/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## How install.sh works

The script detects the OS and symlinks each config file/directory to its corresponding location under `~`. Shared configs are always linked; platform-specific configs (zsh on macOS, bash + Hyprland on Linux) are linked conditionally.

If a file already exists at the target path, it gets moved to `~/.dotfiles-backup/` before the symlink is created. Existing symlinks pointing to the correct source are left as-is, making the script safe to re-run.
