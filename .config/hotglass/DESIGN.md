# hotglass

A from-scratch design system for this desktop: pure-black glass, one electric pink, sharp edges. Every themed surface derives from the tokens in `tokens.yml`; this document is the contract for applying it to anything new.

## Principles

1. **Black glass foundation.** Backgrounds are pure neutral black at tokenized opacity — the wallpaper glows through shell chrome. The system is wallpaper-agnostic: nothing may depend on what's behind the glass.
2. **One accent.** A single pink — *voltage* `#FF52AB` — does all identity work: selection, focus, active workspace, focused borders, prompt identity. Nothing else gets a signature color.
3. **Alpha-based neutrals.** Every neutral is white at a tokenized alpha. Contexts that can't composite (TUIs, hyprlock, GTK chrome) use the same values flattened over black — the generated `-ink` fallbacks — never hand-picked grays.
4. **Color means attention.** The status rail (red/yellow/green/blue) appears only when something needs attention: errors, warnings, dirty state, urgent notifications. Healthy state is neutral. Status colors never do identity work — no permanently-green anything.
5. **Sharp and sparse.** `border-radius: 0` everywhere. Borders are 1px (subtle) or 3px (emphasis) — nothing in between. Chrome typography is CaskaydiaCove Nerd Font.

## Tokens

Colors live in `tokens.yml`; run `./generate` after any edit. Derived files (`colors.css`, `hotglass.conf`, `hotglass.lua`, clipse theme, starship palette block, icon theme) are committed but never hand-edited.

| Token | Value | Role |
|---|---|---|
| `accent` | `#FF52AB` | selection, focus, active, identity |
| `accent-deep` | `#C40869` | same hue, lower lightness — filled blocks carrying light text (e.g. the prompt directory); bright voltage is too glaring a ground for text |
| `red` | `#FF5C6C` | error, critical, failed command |
| `yellow` | `#FFC44D` | warning, dirty state, capslock |
| `green` | `#3DE383` | success confirmation |
| `blue` | `#4FA8FF` | info |
| `text` | white @ 100% | primary text |
| `text-dim` | white @ 65% | secondary text |
| `text-muted` | white @ 40% | tertiary text, passive icons |
| `edge-idle` | white @ 25% | inactive window border, quiet outlines |
| `overlay-hover` | white @ 12% | hover surface |
| `edge-subtle` | white @ 8% | hairline separators |
| `edge-focus` | accent @ 90% | frames of focused chrome |
| `edge-focus-dim` | accent @ 40% | quieter framed elements |
| `glass` | black @ 75% | panels: bar, launcher, terminal, GTK4 app windows |
| `glass-thin` | black @ 55% | notification layer (stacks on translucent surfaces) |
| `ink` | `#000000` | opaque ground |
| `raise-1/2/3` | white @ 14/9/5% on ink | opaque raised surfaces: prompt segments, GTK floating chrome (popovers, dialogs) |

Shape and type constants (no runtime carrier — apply by hand, cite this doc):

| Constant | Value |
|---|---|
| radius | `0`, always |
| border | `1px` subtle / `3px` emphasis |
| gaps | `5` inner / `10` outer |
| chrome font | CaskaydiaCove Nerd Font, 15px (bar/notifications) / 18px (launcher) |
| GTK app font | Adwaita Sans 11 (proportional stays for app content) |

## Scope

**In:** waybar, wofi (networkmanager-dmenu inherits), swaync, hyprlock, hyprland borders, starship, clipse, ghostty background/opacity, GTK4 via a libadwaita named-color override on Adwaita (this includes file pickers: `xdg-desktop-portal/` routes the portal's FileChooser to Nautilus itself, which Electron/Chromium apps like VS Code go through), GTK 3 via Adwaita-dark + the same named colors (GTK3 Adwaita bakes its colors to literals, so this is nominal — GTK3 is off the daily path now), icon theme (generated folder + file glyphs; everything else inherits Adwaita).

**Out:** ghostty's ANSI-16 palette and everything that merely inherits it (git diff, btop), wallpaper, cursor theme.

Boundary rule: *apps whose colors we configure get tokens; the ANSI palette and anything that merely inherits it stays stock.*

Hooks for later: Nautilus is now the daily-driven GUI file manager — revisit GTK depth (does the override layer hold up under heavy content views?); GTK3's theme name must stay the built-in `Adwaita` + prefer-dark (`Adwaita-dark` is a gnome-themes-extra directory, and GTK3 falls back to *light* Adwaita when it's missing); a GTK3 surface that matters again would need selector-based CSS, not named colors; btop can join by the boundary rule if its colors ever get configured.

## Prompt (state-driven)

The starship prompt keeps its powerline shape but sits on neutral raise tiers; the directory block is the one accent surface. Segment identity comes from icons and position. Color is reserved for state: `git_status` renders yellow only when the tree is dirty, and the prompt character flips red after a failed command. A color change in the prompt always means something changed.
