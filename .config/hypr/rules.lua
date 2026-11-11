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

-- satty: float the screenshot editor; it sizes itself to the image
hl.window_rule({
    name  = "satty",
    match = { class = "^com\\.gabm\\.satty$" },

    float  = true,
    center = true,
})

-- Games: force fullscreen. Hyprland 0.56 tiles XWayland windows that ask for
-- fullscreen before they map (SDL and Wine both do), which leaves CS2 under
-- the bar and crashes DOOM Eternal during its intro videos. Match the game
-- window itself, not the whole steam_app_<id> class — Proton launchers (DOOM's
-- idTech launcher) share it and shouldn't be fullscreened.
hl.window_rule({
    name  = "cs2-fullscreen",
    match = { class = "^cs2$" },

    fullscreen = true,
})

hl.window_rule({
    name  = "doom-eternal-fullscreen",
    match = { class = "^steam_app_782330$", title = "^DOOMEternal$" },

    fullscreen = true,
})

-- hotglass: a lone tiled window has nothing to be distinguished from, so it
-- gets no focus edge and no shadow (see hotglass/DESIGN.md, focus model).
hl.workspace_rule({
    workspace   = "w[tv1]",
    border_size = 0,
    no_shadow   = true,
})

-- hotglass: every glass layer is blurred. ignore_alpha 0.5 blurs behind the
-- glass itself (surfaces are .66–.72 black) but not behind the transparent
-- margins or the low-alpha drop shadows drawn inside them.
hl.layer_rule({
    name  = "glass-blur",
    match = { namespace = "^(waybar|wofi|swayosd|swaync-.*)$" },

    blur         = true,
    ignore_alpha = 0.5,
})

-- The launcher and menus settle in instead of fading flat.
hl.layer_rule({
    name  = "wofi-popin",
    match = { namespace = "^wofi$" },

    animation = "popin 96%",
})
