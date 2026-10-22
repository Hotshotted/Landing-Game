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

## Motion (what the code does)
Screens open with a transition by direction: forward (menu to career, logbook, hangar, certificate) slides in from the right, back slides the menu in from the left,
modal cards (pause, choice) pop with an overshoot, the logbook turns like a page. Cards and buttons then enter one after another (`Style.STAGGER`).
Stamps (certificate APPROVED, pink slip FAILED, POT LOST, logbook airports, ENDORSED) fall, slam, shake the screen and play a thump.
Numbers roll up (score, pot); coins fly into the pot on a landing and from the pot into the bank on a cash-out; the certificate throws confetti.
All of it is drawn or moved by `Hud` / `UiBurst` from fixed pools: nothing is allocated while it plays, and the headless smoke tests skip it (they check end states and,
in section 28, run the animations by hand).

## Audio
Everything is synthesised at start-up (no audio files). Interface: tap (secondary), back (ghost), confirm (primary / gold), deny (danger), page, whoosh, stamp, coin, fanfare, trombone.
Flight: a loop per engine (Cub, 172, twin with two engines beating, jet whine; the glider has none), wind that follows airspeed and rain; tyre skid and thud at touchdown.
Music: a menu pad and a brighter flying pad on the same 12 s grid crossfade over 1.2 s; a heartbeat layer builds on the final approach and stays under KEEP FLYING while a pot is at stake.

## App icon, splash, loading
`icon.svg` (a Cessna with Whiskers' ears landing, PAPI lights top left, sun top right) is the source of `icons/icon-512.png`, `icon-192.png`, `apple-touch-icon.png`.
`tools/splash.html` makes `assets/splash.png` (the native boot splash). `node tools/make_icons.js` regenerates all of them. The web build uses `web/shell.html` for its loading page.

## Performance (`?perf`)
Heaviest scene: night + rain + jet. Rain and wind streaks are one MultiMesh draw each, small details skip the outline pass, edge lights have no glow.
The smoke test simulates it at 60 fps and fails on any frame over 33 ms of CPU time; in the browser with a software renderer (no GPU) `?perf` shows about 226 draw calls.
