#!/usr/bin/env bash
# Power menu (hotglass 2.0, see ~/.config/hotglass/DESIGN.md). Fixed order,
# safe actions first: --cache-file /dev/null stops wofi re-sorting by usage.
# Anything that ends the session ("…") opens a two-item confirm menu with the
# destructive label in the status red, so a stray Enter can't power off.
set -euo pipefail

red="$(sed -n 's/^@define-color red \(#[0-9A-Fa-f]*\);$/\1/p' "$HOME/.config/hotglass/colors.css")"

menu() {
  local prompt="$1" height="$2"
  shift 2
  wofi --dmenu --cache-file /dev/null --prompt "$prompt" --width 320 --height "$height" "$@"
}

confirm() {
  local label="$1" answer
  answer="$(printf '%s\n' "<span foreground='${red}'>${label}</span>" "Cancel" \
    | menu "${label} now?" 164 --allow-markup)" || return 1
  [[ "$answer" == *"$label"* ]]
}

choice="$(printf '%s\n' \
  "󰌾  Lock" \
  "󰤄  Suspend" \
  "󰍃  Log out…" \
  "󰜉  Restart…" \
  "󰐥  Shut down…" \
  | menu Power 296)" || exit 0

case "$choice" in
  *Lock) hyprlock ;;
  *Suspend) systemctl suspend ;;
  *"Log out…") confirm "Log out" && hyprctl eval "hl.dispatch(hl.dsp.exit())" ;;
  *"Restart…") confirm "Restart" && systemctl reboot ;;
  *"Shut down…") confirm "Shut down" && systemctl poweroff ;;
esac
