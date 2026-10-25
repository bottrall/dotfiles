#!/usr/bin/env bash
# Set the case fan RGB, wired to the motherboard's JRAINBOW headers (MSI
# Mystic Light). "on" is a static hot pink to suit the magenta case — picked
# by eye rather than from hotglass, since the theme's pinks wash out on these
# LEDs (any green in the mix reads as white). Called at login, and by
# hypridle: off when the screen turns off, back on when activity resumes.
set -euo pipefail

command -v openrgb >/dev/null || exit 0

device="MSI PRO B650M-P"
color="FF0080"

# JRAINBOW zones default to 0 LEDs, and the controller ignores mode changes
# until they're sized.
set_rgb() {
  openrgb --noautoconnect \
    -d "$device" -z 2 -sz 30 \
    -d "$device" -z 3 -sz 30 \
    -d "$device" "$@"
}

case "${1:-}" in
  on) set_rgb -m static -c "$color" ;;
  off) set_rgb -m direct -c 000000 ;;
  *) echo "usage: $0 on|off" >&2; exit 1 ;;
esac
