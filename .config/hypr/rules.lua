-- Window and layer rules.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

-- Ignore maximize requests from apps.
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

-- Fix some dragging issues with XWayland
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

-- Ensure focus on activate (i.e. clicking a link focuses the browser that opens it)
hl.window_rule({
    name  = "focus-on-activate",
    match = { class = ".*" },

    focus_on_activate = true,
})

-- clipse
hl.window_rule({
    name  = "clipse",
    match = { class = "^dev\\.jake\\.clipse$" },

    float        = true,
    size         = "1750 652",
    stay_focused = true,
})

-- waybar click actions (floating terminal apps)
hl.window_rule({
    name  = "btop",
    match = { class = "^dev\\.jake\\.btop$" },

    float = true,
    size  = "1400 800",
})

-- swaync notifications + control center: blur like regular windows.
-- ignore_alpha 0 keeps the fully-transparent parts of the layer surface
-- (the area around the toasts) from being blurred too.
hl.layer_rule({
    name  = "swaync-blur",
    match = { namespace = "^swaync-" },

    blur         = true,
    ignore_alpha = 0,
})
