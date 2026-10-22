# Greaser visual style

Greaser is made by **Clear Prop Games**, the studio behind Pattern-Control, and uses the same style system
(`scripts/Style.gd` holds every token; this page is the written version). Anything not listed here follows Pattern-Control's `docs/style.md`.

## Studio mark
A bold three-blade propeller (sky blue, ink outline, gold hub) above the wordmark "Clear Prop Games" in Fredoka SemiBold.
Drawn in code (`Icons` glyph `prop`) for the in-game logo intro and as SVG in `web/shell.html` for the web loading page.

## Palette
| Token | Value | Use |
|---|---|---|
| PRIMARY | `#3d8bff` | brand, selection, primary actions |
| ACCENT | `#ffc933` | coins, stars, rewards |
| SUCCESS | `#35c98a` | go / earned |
| WARNING / DANGER | `#ff9f2e` / `#ff5c4d` | caution / failure |
| INK | `#0a1020` | outlines, deepest dark |
| SURFACE_DARK / _2 | `#14213d` / `#1d3157` | cards, selected card |
| TEXT / SOFT / QUIET | `#fff` / `#bcd0ec` / `#8497b8` | copy |
Text on every surface keeps 4.5:1 contrast (checked by the smoke test).

## Typography
Fredoka SemiBold (display, numbers, anything 56 px and up) and Nunito Bold (text). Sizes: XL 110, L 76, M 56, S 30.
All text is outlined in INK so it reads over any sky. Both fonts are OFL (`assets/fonts`).

## Shape, spacing, motion
Radii 14 / 26 / 40 / pill 60. Spacing 8 / 16 / 24 / 40 / 64, gutter 40. Shadow `#030814` 45 %, blur 16, offset (0, 8). Chunky lip 10 px.
Motion: fast 0.12 s, base 0.30 s, slow 0.5 s, stagger 0.05 s; ease-out-cubic, ease-in-cubic, ease-out-back (overshoot).

## Buttons (`UiButton`)
One node, drawn in code. Kinds: **primary** (green, FLY / RESUME / KEEP FLYING), **gold** (rewards: CASH OUT, ads, checkride booking),
**danger** (red, destructive confirm), **secondary** (dark card, light border), **ghost** (round translucent chip, icon only: back arrows, pause).
Every kind has normal, pressed (face squashes into the lip) and disabled looks; `accent` marks a selected / equipped item.
A press plays the shared tap sound and a light haptic.

## Icons (`Icons`, `UiIcon`)
One vector set, no emoji, no image files: stats and interface, five aircraft, eight ranks, eleven landing types, five weather types, the studio mark.
Bold silhouettes, round proportions, strokes r/6; two-tone only where colour is the meaning (coin gold, danger red).
The same icon always means the same thing.

## Safe areas
`Style.detect_safe` reads the device's insets (CSS `env(safe-area-inset-*)` on the web); `Hud.apply_safe` moves anything pinned to a screen edge inside them.

## Deviations from Pattern-Control
- Extra tokens for the world behind the interface: `SKY_DAY`, `SKY_DAY_HORIZON`, `SKY_DUSK`, `SKY_NIGHT`, `SKY_RAIN`, `SKY_FOG`; extra size `SZ_L` (76).
- The icon set adds aircraft, ranks, landing types, weather and the propeller mark.
- Text carries an INK outline everywhere (the HUD sits over a moving sky); Pattern-Control's flat HUD does not need it.
- The HUD is built from Control nodes (pooled, built once) instead of one custom-drawn control, so the screens can stay editable; the buttons themselves are single drawn nodes as in Pattern-Control.

## Loading and the build stamp
The web page shows `web/shell.html`'s loader (brand background, propeller, progress bar, no text) until the game reports its first screen is ready.
The build stamp (commit, time, flags) is hidden from players: it shows only with `?debug`, `?tune` or `?perf`, small, bottom-left.
