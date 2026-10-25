-- Hyprland config (lua, 0.55+) — entry point.
-- Refer to https://wiki.hypr.land/Configuring/ for more information.


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- Set in ~/.config/uwsm/env (session-wide) and env-hyprland, not hl.env:
-- under uwsm those reach systemd units and D-Bus-activated apps too.


------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Targeted by description, not port — the Dell moved from DP-2 to DP-1 once
-- already and silently fell back to 60Hz.
hl.monitor({
    output   = "desc:Dell Inc. AW3425DWM 2ZJ4444",
    mode     = "3440x1440@180",
    position = "auto",
    scale    = "auto",
    vrr      = 1,
    bitdepth = 10,
})


-------------------
---- AUTOSTART ----
-------------------

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
--
-- Most of the session starts outside this file, via uwsm:
--   waybar, hypridle, hyprpaper  systemd units enabled by install.sh
--                                (Restart=on-failure, logs in journalctl --user)
--   1password, dropbox           XDG autostart (~/.config/autostart, written by
--                                the apps themselves)
-- Only things without either live here, wrapped in `uwsm app` so they get
-- their own unit too.

hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- clipse -listen")
    -- One-shot, so no unit: sets the case fans to the accent colour.
    hl.exec_cmd("~/.config/hypr/scripts/case-rgb.sh on")
end)


-----------------
---- MODULES ----
-----------------

require("look")
require("input")
require("binds")
require("rules")
