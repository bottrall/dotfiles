-- Look and feel: general, decoration, animations, layouts, misc.
-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/

-- hotglass 2.0 design tokens (generated) — see ~/.config/hotglass/DESIGN.md.
-- Focus is shown with light, not color: the focused window gets a brighter
-- 1px edge and a soft shadow; unfocused windows get a hairline and a 12% dim.
-- A lone tiled window gets neither (see the w[tv1] rule in rules.lua).
local t = dofile(os.getenv("HOME") .. "/.config/hotglass/hotglass.lua")

hl.config({
    general = {
        gaps_in  = t.gapsIn,
        gaps_out = t.gapsOut,

        border_size = t.border,

        col = {
            active_border   = t.color.edgeStrong,
            inactive_border = t.color.edgeHairline,
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = true,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 0,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        dim_inactive = true,
        dim_strength = t.dimInactive,

        shadow = {
            enabled        = true,
            range          = t.shadow.range,
            render_power   = 3,
            offset         = t.shadow.offset,
            color          = t.shadow.color,
            color_inactive = "rgba(00000000)",
        },

        -- Popups (menus, tooltips) blur too; ignorealpha keeps their
        -- low-alpha drop shadows from being blurred into a halo.
        blur = {
            enabled            = true,
            size               = t.blur.size,
            passes             = t.blur.passes,
            noise              = t.blur.noise,
            vibrancy           = t.blur.vibrancy,
            popups             = true,
            popups_ignorealpha = 0.5,
        },
    },

    animations = {
        enabled = true,
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
    dwindle = {
        preserve_split = true, -- You probably want this
        force_split    = 2,
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = -1,    -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo   = false, -- If true disables the random hyprland logo / anime girl background. :(
    },
})

-- Motion: things decelerate in and accelerate out, and exits are faster
-- than entrances. Speeds come from the tokens (Hyprland speed = 100ms).
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("enter",  { type = "bezier", points = t.curve.enter })
hl.curve("exit",   { type = "bezier", points = t.curve.exit })
hl.curve("linear", { type = "bezier", points = { {0, 0}, {1, 1} } })

hl.animation({ leaf = "global",        enabled = true, speed = t.speed.base, bezier = "enter" })
hl.animation({ leaf = "border",        enabled = true, speed = t.speed.fast, bezier = "enter" })
hl.animation({ leaf = "windows",       enabled = true, speed = t.speed.base, bezier = "enter" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = t.speed.base, bezier = "enter", style = "popin 95%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = t.speed.exit, bezier = "exit",  style = "popin 95%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = t.speed.base, bezier = "enter" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = t.speed.exit, bezier = "exit" })
hl.animation({ leaf = "fade",          enabled = true, speed = t.speed.fast, bezier = "enter" })
hl.animation({ leaf = "fadeDim",       enabled = true, speed = t.speed.base, bezier = "enter" })
hl.animation({ leaf = "layers",        enabled = true, speed = t.speed.base, bezier = "enter" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = t.speed.base, bezier = "enter", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = t.speed.exit, bezier = "exit",  style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = t.speed.base, bezier = "enter" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = t.speed.exit, bezier = "exit" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = t.speed.slow, bezier = "enter", style = "slidefade 12%" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = t.speed.slow, bezier = "enter", style = "slidefade 12%" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = t.speed.slow, bezier = "enter", style = "slidefade 12%" })
