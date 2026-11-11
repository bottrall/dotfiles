# hotglass 2.0

The design system for this desktop: black glass, one hot pink used as a mark, sharp edges, two typefaces. Every themed surface is generated from `tokens.yml`; this document is the contract for applying it to anything new.

2.0 keeps 1.0's foundation (one token file, black glass, a single accent, alpha neutrals, color reserved for attention, radius 0) and changes how the system speaks: focus is shown with light and depth instead of pink frames, type has two voices and a real scale, and notifications are rebuilt around what you can take in within a second.

## Principles

1. **Black glass, always blurred.** Every surface is translucent black and every glass surface is blurred, in three opacity tiers by elevation. Nothing may depend on what's behind the glass; `./generate --check` proves contrast over black, white and the wallpaper's brightest sky.
2. **One accent, used as a mark.** Voltage `#FF52AB` is the only identity color, and it appears small: a 2–3px indicator, the caret, the prompt arrow, a progress fill, a switch track, the keyboard focus ring. It never outlines anything larger than a control. Fills that carry text use `accent.deep`.
3. **Neutrals by role.** Every neutral is white at an alpha, named by its job: `text`, `fill`, `edge`. Contexts that can't composite use the same values flattened over black.
4. **Color means attention.** The status rail appears only when something needs you. Healthy state is neutral. Red is ember (`#FF6A4D`, 41° from voltage) so attention never reads as identity.
5. **Sharp.** Radius 0 with no exceptions, switches included. Edges are 1px everywhere; 3px is reserved for the mark and the critical stripe, never a frame.
6. **Depth by light.** Focus and elevation are shown with edge brightness, shadow, blur and dimming.
7. **Two voices.** Adwaita Sans for the interface, CaskaydiaCove for the machine (terminal, prompt, code). Hierarchy comes from size and weight first, tone second.
8. **Quiet by default.** Healthy state recedes: tertiary stats, transient media toasts, short timeouts, silent low-urgency notifications.

## The focus model

One signal per question, so each can be quiet.

| Question | Signal | Where |
|---|---|---|
| Which window am I typing into? | 1px `edge.strong` + window shadow; unfocused windows get `edge.hairline` and 12% dimming. A lone tiled window gets no edge or shadow. | Hyprland |
| Where am I in this list? | `fill.active` + 3px accent mark on the leading edge; label stays primary. Under `:backdrop` the mark turns tertiary. | wofi, bar menus, GTK sidebars and lists |
| Where is the keyboard? | 2px accent ring, 2px offset, `:focus-visible` only | GTK, swaync |
| What's active or on? | Accent mark (workspace) or `accent.deep` fill on a small control (switch) | waybar, control center |
| What needs me? | Status color as a 3px stripe, icon tint or value color. Never a frame. | toasts, bar values, lock input |

## Tokens

Edit `tokens.yml`, then run `./generate`. It audits contrast first and writes nothing if any check fails; `./generate --check` prints the full table.

### Color

| Group | Tokens | Use |
|---|---|---|
| accent | `base` voltage · `deep` · `soft` (16%) | marks · fills carrying white text · text-selection ground |
| status | `red` ember · `yellow` · `green` · `blue` | error/critical/destructive · warning, caps lock, idle inhibited · success only · info |
| text | `primary` .94 · `secondary` .68 · `tertiary` .46 · `disabled` .28 | titles and values · body and resting labels · meta, timestamps, healthy stats · unavailable |
| fill | `subtle` .04 · `hover` .08 · `active` .12 · `control` .18 | cards inside panels · hover · selected/pressed · switch track, troughs |
| edge | `hairline` .08 · `default` .14 · `strong` .32 · `highlight` .10 | separators, inactive window · overlay edges, inputs · focused window · inner top light on overlays |
| surface | `window` .78 · `bar` .66 · `overlay` .72 (black @) | level 1 · level 2 · level 3 |
| raise | `raise_1/2/3` | opaque fallbacks: prompt segments, TUIs, popovers |

### Elevation

| Level | Surface | Edge | Shadow | Members |
|---|---|---|---|---|
| 0 Wallpaper | — | — | — | never covered by chrome without glass |
| 1 Window | `surface.window` | hairline; strong when focused; none when alone | focused only | ghostty, GTK apps, floating btop / clipse / satty |
| 2 Bar | `surface.bar` | hairline bottom | none | waybar |
| 3 Overlay | `surface.overlay` | default + inner highlight | deep | wofi, swaync, tooltips, swayosd, hyprlock input |

Blur is Hyprland's (size 6, 3 passes, a little noise for grain), on windows, popups and the `waybar`, `wofi`, `swaync-*` and `swayosd` layers with `ignore_alpha 0.5` so drop shadows aren't blurred.

### Type

Two families: `type.ui` Adwaita Sans (variable, Inter lineage, true tabular figures) with Nerd glyphs falling back per-glyph to `type.glyphs` CaskaydiaCove Nerd Font Propo; `type.mono` CaskaydiaCove Nerd Font at 13.

| Step | px / weight / tracking | Use |
|---|---|---|
| display | 168 / 200 / −0.04em | lock clock |
| title | 17 / 600 / −0.01em | panel titles |
| headline | 15 / 600 | toast summary, launcher rows (at 500) |
| body | 14 / 400 | toast body, control center rows |
| ui | 13 / 500 | bar, buttons |
| caption | 12 / 500 | timestamps, hints |
| overline | 11 / 650 / +0.08em, caps | group headers, the lock date |

Numbers that change in place (bar, OSD, clocks, timestamps) use tabular figures. A component uses at most three steps, two weights and three tones.

### Space, shape, motion

- **Space** 4 · 8 · 12 · 16 · 20 · 24 · 32. Templates call `px(n)`, which refuses anything off the scale. **Grid** 12: 12px between windows (`gaps_in` 6) and to every edge; **Overlay offset** 24: toasts, control center and bar menus sit 2 × grid from the bar and the edge, never on the grid itself, so their edges never line up with a window edge behind them.
- **Shape** radius 0 · edge 1px · mark 3px (2px on the bar).
- **Motion** fast 120ms (hover, focus edge) · base 200ms enter / 140ms exit (windows, layers, toasts) · slow 320ms (workspaces, `slidefade 12%`). Enter decelerates `(0.22, 1, 0.36, 1)`; exit accelerates `(0.4, 0, 1, 1)`.

### Reference (generated)

<!-- hotglass:tokens:begin -->
<!-- GENERATED by hotglass/generate from tokens.yml — edit tokens.yml or templates/ and rerun; do not edit this file. -->
| Token | Value |
|---|---|
| `accent` | `#FF52AB` |
| `accent.deep` | `#C40869` |
| `accent.soft` | `rgba(255, 82, 171, 0.16)` |
| `red` | `#FF6A4D` |
| `yellow` | `#FFC44D` |
| `green` | `#3DE383` |
| `blue` | `#4FA8FF` |
| `white` | `#FFFFFF` |
| `ink` | `#000000` |
| `text.primary` | `rgba(255, 255, 255, 0.94)` |
| `text.secondary` | `rgba(255, 255, 255, 0.68)` |
| `text.tertiary` | `rgba(255, 255, 255, 0.46)` |
| `text.disabled` | `rgba(255, 255, 255, 0.28)` |
| `fill.subtle` | `rgba(255, 255, 255, 0.04)` |
| `fill.hover` | `rgba(255, 255, 255, 0.08)` |
| `fill.active` | `rgba(255, 255, 255, 0.12)` |
| `fill.control` | `rgba(255, 255, 255, 0.18)` |
| `edge.hairline` | `rgba(255, 255, 255, 0.08)` |
| `edge.default` | `rgba(255, 255, 255, 0.14)` |
| `edge.strong` | `rgba(255, 255, 255, 0.32)` |
| `edge.highlight` | `rgba(255, 255, 255, 0.1)` |
| `surface.window` | `rgba(0, 0, 0, 0.78)` |
| `surface.bar` | `rgba(0, 0, 0, 0.66)` |
| `surface.overlay` | `rgba(0, 0, 0, 0.72)` |
| `raise.1` | `#242424` |
| `raise.2` | `#171717` |
| `raise.3` | `#0D0D0D` |
<!-- hotglass:tokens:end -->

## Components

**Bar (waybar).** Workspaces left; the centre is reserved and empty because the webcam sits over it. The right side runs at an even 24px rhythm (12px padding per module, which is also the hover target); tone, not spacing, does the grouping. The clock anchors the right side: the only primary item at 600, its date dimmed. Network and volume are secondary; healthy stats tertiary, turning yellow/ember at thresholds (CPU and memory 70/90%, temperature 80/90°, Claude usage 80/95%). Workspaces are 32px cells; the active one carries a 16 × 2px accent mark, an urgent one an ember mark. Unread notifications turn the bell accent.

**Tooltips.** Small overlays (overlay glass, inner top highlight, 12 × 16 padding) with one three-line shape, set with Pango markup in `waybar/config.jsonc`: what it is (600, primary), its values (secondary), what a click does (tertiary). Tray icons have none: an app's name beside its own icon adds nothing.

**Bar menus (waybar/menus/).** The clock opens a calendar, the power icon the power menu, the network module the Wi-Fi menu. All are 300–360px overlays right-aligned `overlay_offset` under the bar, built from one anatomy: a header (overline, title, caption, optional trailing control) split by a hairline, then 44px rows (glyph, label, trailing caption) with the standard selection mark, or the calendar grid. One click activates a row. Opening a menu closes any other; Esc or a click anywhere else closes it (the bar included). Clicks outside land on a click catcher, an invisible full-screen layer beneath the menu, rather than closing on focus loss: with `follow_mouse`, merely crossing a window on the way to the menu moves keyboard focus. As with most menus, the dismissing click isn't passed through.
- *Calendar:* "Today" or the weekday, the date, ISO week and day of year; the grid marks today in primary 700 with a 16 × 2px accent mark, the selected day on `fill.active`.
- *Power:* "jake on poppy" with uptime; Lock, Suspend, a hairline, then Log out…, Restart…, Shut down…, which swap the list for an inline confirm with the destructive button in ember.
- *Wi-Fi:* the connected network as title with signal as caption and a radio switch; networks below (connected in accent, then saved, then by signal; a lock for secured ones). Saved and open networks connect on click; new secured ones open an inline password field. Status (scanning, connecting, a failure in ember) lives in the caption. nmcli calls are async.

They're Ruby (ruby-gnome `gtk4` gem) in one resident process, layer-shell surfaces (`hotglass-menu`) sharing the overlay blur and pop-in rules. Hyprland pre-starts it and the bar toggles menus over D-Bus with `toggle.sh <menu>`, ~15ms instead of the ~1s the gems take to load. Styles: `templates/menus.css.erb`.

**Notifications (swaync).** Toasts are 380px overlay cards, `overlay_offset` (24px) below the bar and from the edge, 8px apart. Overlays never sit on the 12px window grid: there their edges line up exactly with the window edges behind them and read as stuck to the window. Anatomy: 40px image (usually the app's own icon; swaync's app badge is hidden because it would just repeat it) · headline (15/600) and relative time · body (14/400 secondary, clamped) · text-button actions split by hairlines. swaync 0.12 has no app-name label on a toast, so identity comes from that image; the control center's group headers carry the app name as an overline. Urgency changes behaviour as well as looks: low is quieter (secondary headline), 4s and silent; normal is 6s with the message sound; critical gets the 3px ember stripe, stays until dismissed and plays the warning sound. The control center fits its content, starts with title / Do not disturb (a square switch) / media, and separates cards by fill instead of lines. Spotify's track-change toasts are transient (shown, never kept).

**Launcher (wofi).** 680 × 520, top-anchored 280px down. 56px search field with a placeholder, hairline, 44px rows with 28px icons, the standard selection mark. Only the app launcher uses wofi; menus that need no search are bar menus.

**Lock (hyprlock).** One centred column on the wallpaper blurred and dimmed to 50%: overline date, display clock, 360 × 48 password field (overlay glass, 1px edge that turns accent while checking, ember on failure, yellow with Caps Lock), caption hint; user and host bottom-left.

**OSD (swayosd).** 320 × 56 overlay, bottom centre; accent level fill, tertiary when muted. Volume and caps-lock binds use it when `swayosd` is installed and fall back to plain `wpctl` otherwise.

**Windows (Hyprland).** See the focus model. Two motion curves plus linear; windows pop in at 95%.

**Terminal and prompt.** Ghostty uses CaskaydiaCove at 13, 16 × 12 padding, `surface.window` glass, accent caret, `accent.deep` selection, and the ANSI status subset (red, green, yellow, blue, magenta → rail and accent; black, white, cyan stock). The starship prompt keeps its powerline shape on raise tiers with the `accent.deep` directory block; `git_status` turns yellow only when dirty and the arrow turns ember after a failed command.

**GTK.** libadwaita named colors on Adwaita dark: window glass, `accent.deep` suggested buttons with white text, the selection mark in sidebars and lists, square everything (window controls included), accent focus rings on `:focus-visible` only. GTK3 gets a nominal layer.

## Generator

`generate` (Ruby, stdlib) renders `templates/*.erb` with literal values — GTK3 consumers can't resolve CSS custom properties — to the paths in its `TEMPLATES` table, and writes `colors.css` (GTK `@define-color` set for ad-hoc stylesheets), `hotglass.lua` (the Hyprland token table that `hypr/look.lua` reads at runtime), the clipse theme, the starship and satty palette blocks, the reference table above, and the icon theme. Generated files are committed and carry a "do not edit" header.

## Scope

**In:** waybar and its menus, wofi, swaync, swayosd, hyprlock, Hyprland decoration and motion, starship, clipse, satty, ghostty (font, glass, padding, caret, selection, ANSI status subset), GTK4 via libadwaita named colors (including the Nautilus-backed file chooser), GTK3 nominally, the icon theme.

**Out:** the rest of the ANSI-16 palette (black, white, cyan) and anything that only inherits it, btop's own theme, wallpaper, cursor theme.

Notes: GTK3's theme name must stay the built-in `Adwaita` + prefer-dark (`Adwaita-dark` is a gnome-themes-extra directory, and GTK3 falls back to *light* Adwaita when it's missing). The monospace gsetting (`monospace-font-name`) is set by `install.sh`.
