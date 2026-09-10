#!/usr/bin/env bash
set -euo pipefail

choice="$(printf '%s\n' \
  "󰌾  Lock" \
  "󰤄  Suspend" \
  "󰍃  Logout" \
  "󰜉  Reboot" \
  "󰐥  Shutdown" \
  | wofi --dmenu --prompt "Power" --width 320 --height 320)" || exit 0

case "$choice" in
  *Lock) hyprlock ;;
  *Suspend) systemctl suspend ;;
  *Logout) hyprctl eval "hl.dsp.exit()" ;;
  *Reboot) systemctl reboot ;;
  *Shutdown) systemctl poweroff ;;
esac
