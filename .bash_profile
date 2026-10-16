#
# ~/.bash_profile
#

[[ -f ~/.bashrc ]] && . ~/.bashrc

# Hyprland runs as a uwsm-managed systemd session: graphical-session.target,
# the session env exported to systemd/D-Bus activation, and waybar etc. as
# supervised units. hyprland.desktop execs start-hyprland, so its watchdog
# still applies. `may-start` only passes on tty1 (with graphical.target up and
# no session already running), so other ttys — or a missing uwsm — fall back to
# a bare start-hyprland session as an escape hatch.
if [[ -z "$WAYLAND_DISPLAY" && "$(tty)" == /dev/tty* ]]; then
    if command -v uwsm >/dev/null && uwsm check may-start; then
        exec uwsm start hyprland.desktop
    fi
    exec start-hyprland
fi
