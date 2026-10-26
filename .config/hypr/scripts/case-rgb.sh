#!/usr/bin/env bash
# Set the case fan RGB, wired to the motherboard's JRAINBOW headers (MSI
# Mystic Light). "on" fades up to a static hot pink to suit the magenta case —
# picked by eye rather than from hotglass, since the theme's pinks wash out on
# these LEDs (any green in the mix reads as white). Off by default: login
# runs "off"; run "on" by hand to light them.
#
# Goes through the openrgb.service SDK server, where a call takes ~30ms, so
# the fade can step quickly. Without it, each call detects hardware locally
# (~3s), so "on" skips the fade.
set -euo pipefail

command -v openrgb >/dev/null || exit 0

device="MSI PRO B650M-P"
color="FF0080"
fade_steps=30

# The server opens its port before it has finished detecting devices, so at
# login wait for the board to show up. A client that connects mid-detection
# can hang for good, hence the timeout. --nodetect stops each try falling back
# to a local scan.
server_ready() {
  systemctl --user is-active --quiet openrgb.service || return 1
  local deadline=$((SECONDS + 10))
  while ((SECONDS < deadline)); do
    [[ "$(timeout 1 openrgb --nodetect -l)" == *"$device"* ]] && return 0
    sleep 0.2
  done
  return 1
}

# Colours from black up to $color, gamma-eased so the steps look even to the
# eye rather than rushing to full brightness.
fade_ramp() {
  awk -v hex="$color" -v n="$fade_steps" 'BEGIN {
    r = strtonum("0x" substr(hex, 1, 2))
    g = strtonum("0x" substr(hex, 3, 2))
    b = strtonum("0x" substr(hex, 5, 2))
    for (i = 1; i <= n; i++) {
      t = (i / n) ^ 2.2
      printf "%02X%02X%02X\n", r * t + 0.5, g * t + 0.5, b * t + 0.5
    }
  }'
}

if server_ready; then
  connection=--nodetect
  fade=true
else
  connection=--noautoconnect
  fade=false
fi

rgb() {
  openrgb "$connection" -d "$device" "$@"
}

# JRAINBOW zones default to 0 LEDs, and the controller ignores mode changes
# until they're sized. Sized once per run, not per fade step: the server
# saves sizes to disk on every resize.
sized_rgb() {
  openrgb "$connection" \
    -d "$device" -z 2 -sz 30 \
    -d "$device" -z 3 -sz 30 \
    -d "$device" "$@"
}

# Ramps in direct mode, then settles on static: the steady state the board
# holds on its own.
fade_on() {
  sized_rgb -m direct -c 000000
  fade_ramp | while read -r step; do
    rgb -c "$step"
    sleep 0.02
  done
  rgb -m static -c "$color"
}

case "${1:-}" in
  on) if $fade; then fade_on; else sized_rgb -m static -c "$color"; fi ;;
  off) sized_rgb -m direct -c 000000 ;;
  *) echo "usage: $0 on|off" >&2; exit 1 ;;
esac
