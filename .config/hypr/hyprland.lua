-- Hyprland config (lua, 0.55+) — entry point.
-- Refer to https://wiki.hypr.land/Configuring/ for more information.


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland")


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

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("clipse -listen")
    hl.exec_cmd("1password")
end)


-----------------
---- MODULES ----
-----------------

require("look")
require("input")
require("binds")
require("rules")
