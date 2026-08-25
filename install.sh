#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "$0")" && pwd)"
BACKUP="$HOME/.dotfiles-backup"
OS="$(uname -s)"

link_file() {
  local src="$DOTFILES/$1"
  local dst="$HOME/$1"

  if [[ ! -e "$src" ]]; then
    echo "SKIP    $1 (source missing)"
    return
  fi

  local parent
  parent="$(dirname "$dst")"
  mkdir -p "$parent"

  if [[ -L "$dst" ]]; then
    local current
    current="$(readlink "$dst")"
    if [[ "$current" == "$src" ]]; then
      echo "OK      $1"
      return
    fi
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    local backup_dst="$BACKUP/$1"
    mkdir -p "$(dirname "$backup_dst")"
    mv "$dst" "$backup_dst"
    echo "BACKUP  $1 -> $backup_dst"
  fi

  ln -s "$src" "$dst"
  echo "LINK    $1"
}

link_dir() {
  local src="$DOTFILES/$1"
  local dst="$HOME/$1"

  if [[ ! -d "$src" ]]; then
    echo "SKIP    $1/ (source missing)"
    return
  fi

  local parent
  parent="$(dirname "$dst")"
  mkdir -p "$parent"

  if [[ -L "$dst" ]]; then
    local current
    current="$(readlink "$dst")"
    if [[ "$current" == "$src" ]]; then
      echo "OK      $1/"
      return
    fi
    rm "$dst"
  elif [[ -d "$dst" ]]; then
    local backup_dst="$BACKUP/$1"
    mkdir -p "$(dirname "$backup_dst")"
    mv "$dst" "$backup_dst"
    echo "BACKUP  $1/ -> $backup_dst"
  fi

  ln -s "$src" "$dst"
  echo "LINK    $1/"
}

echo "==> Dotfiles: $DOTFILES"
echo "==> OS: $OS"
echo ""

# --- Shared ---
link_file ".gitconfig"
link_file ".config/git/ignore"
link_file ".config/git/hooks/post-checkout"
link_file ".config/starship.toml"
link_dir  ".config/sh"
link_dir  ".config/ghostty"
# Claude Code
link_file ".claude/CLAUDE.md"
link_file ".claude/settings.json"
link_dir  ".claude/skills"

# --- macOS only ---
if [[ "$OS" == "Darwin" ]]; then
  link_file ".zshrc"
  link_dir  ".config/zsh"
fi

# --- Linux only ---
if [[ "$OS" == "Linux" ]]; then
  link_file ".bashrc"
  link_dir  ".config/bash"
  link_dir  ".config/hotglass"
  link_dir  ".config/hypr"
  link_dir  ".config/waybar"
  link_dir  ".config/wofi"
  link_dir  ".config/swaync"
  link_dir  ".config/networkmanager-dmenu"
  link_dir  ".config/backgrounds"
  # Individual files only: the clipse dir also holds history and logs (data)
  link_file ".config/clipse/config.json"
  link_file ".config/clipse/custom_theme.json"
  # Individual file only: the btop dir also holds btop.log (data)
  link_file ".config/btop/btop.conf"
  link_dir  ".config/swappy"
  # GTK: hotglass override layer on Adwaita (nwg-look may replace the
  # settings.ini symlinks with plain files if used — rerun to relink)
  link_file ".config/gtk-3.0/settings.ini"
  link_file ".config/gtk-3.0/gtk.css"
  link_file ".config/gtk-4.0/settings.ini"
  link_file ".config/gtk-4.0/gtk.css"
fi

echo ""
echo "==> Done"
