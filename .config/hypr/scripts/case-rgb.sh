#!/usr/bin/env bash
# Set the case fan RGB, wired to the motherboard's JRAINBOW headers (MSI
# Mystic Light). "on" is a static hotglass accent, so the fans follow the
# theme. Called at login, and by hypridle: off when the screen turns off,
# back on when activity resumes.
set -euo pipefail

command -v openrgb >/dev/null || exit 0

device="MSI PRO B650M-P"

accent() {
  awk '/^accent:/ { in_accent = 1 }
       in_accent && /hex:/ { gsub(/"/, "", $2); print $2; exit }' \
    "$HOME/.config/hotglass/tokens.yml"
}

# JRAINBOW zones default to 0 LEDs, and the controller ignores mode changes
# until they're sized.
set_rgb() {
  openrgb --noautoconnect \
    -d "$device" -z 2 -sz 30 \
    -d "$device" -z 3 -sz 30 \
    -d "$device" "$@"
}

case "${1:-}" in
  on) set_rgb -m static -c "$(accent)" ;;
  off) set_rgb -m direct -c 000000 ;;
  *) echo "usage: $0 on|off" >&2; exit 1 ;;
esac
