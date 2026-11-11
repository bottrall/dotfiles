#!/usr/bin/env sh
# Toggle the clock dropdown. When calendar.rb is already resident (Hyprland
# pre-starts it at login) this is a ~15ms D-Bus call; otherwise it starts the
# script, which takes about a second to load GTK and then stays resident.
gdbus call --session --dest dev.jake.hotglass.calendar \
  --object-path /dev/jake/hotglass/calendar \
  --method org.freedesktop.Application.Activate "{}" >/dev/null 2>&1 \
  || exec "$(dirname "$0")/calendar.rb"
