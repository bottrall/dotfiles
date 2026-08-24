#!/usr/bin/env sh
# Played by swaync when a notification arrives (see "scripts" in config.json).
# Usage: sound.sh <freedesktop-sound-name>
# Silent while Do Not Disturb is on.
[ "$(swaync-client -D)" = "true" ] && exit 0
exec pw-play "/usr/share/sounds/freedesktop/stereo/$1.oga"
