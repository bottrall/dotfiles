#!/usr/bin/env sh
# Toggle a hotglass bar menu: toggle.sh calendar|power|wifi
# When menus.rb is resident (Hyprland starts it at login) this is a ~15ms
# D-Bus call; otherwise it starts the script with the menu name, which takes
# about a second to load GTK and then stays resident.
menu="${1:?usage: toggle.sh calendar|power|wifi}"
gdbus call --session --dest dev.jake.hotglass.menus \
  --object-path /dev/jake/hotglass/menus \
  --method org.freedesktop.Application.ActivateAction "$menu" "[]" "{}" >/dev/null 2>&1 \
  || exec "$(dirname "$0")/menus.rb" "$menu"
