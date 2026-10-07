# dotfiles

Personal dotfiles for macOS and Arch Linux.

## What's included

**Shell** — `.zshrc` (macOS), `.bashrc` (Linux)

**Git** — `.gitconfig`, global ignore, post-checkout hook

**Terminal** — Ghostty

**Prompt** — Starship

**Hyprland** (Linux) — Hyprland, Hyprpaper, Hypridle, Hyprlock, Waybar, Wofi, swaync, clipse, btop, swappy, GTK 3/4

**hotglass** (Linux) — the desktop's design system. `.config/hotglass/tokens.yml` is the source of truth; `.config/hotglass/generate` rewrites every derived color file. See `.config/hotglass/DESIGN.md`.

**Shell helpers** — `.config/sh/`: `repos` lists local projects from the untracked `~/.repos.local`, `sweep` resets the dev environment across them (supports `--dry-run`), and `wta`/`wtd` add and remove git worktrees.

**Claude Code** — `.claude/`, symlinked into `~/.claude/`: global instructions, settings, and skills. Machine-specific config for the work-tracking skills lives in the untracked `~/.work.local.md`.

**riffer-rig** — `.riffer/` and `.agents/skills/`, symlinked into `~`: the same instructions and skills adapted for [riffer-rig](https://github.com/bottrall/riffer-rig). `~/.riffer/auth.json` holds API keys and is never linked or committed.

## Usage

```sh
git clone git@github.com:bottrall/dotfiles.git ~/dotfiles
cd ~/dotfiles
./install.sh
```

## How install.sh works

The script detects the OS and symlinks each config file/directory to its corresponding location under `~`. Shared configs are always linked; platform-specific configs (zsh on macOS, bash + Hyprland on Linux) are linked conditionally.

If a file already exists at the target path, it gets moved to `~/.dotfiles-backup/` before the symlink is created. Existing symlinks pointing to the correct source are left as-is, making the script safe to re-run.
