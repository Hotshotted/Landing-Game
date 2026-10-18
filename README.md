# Greaser

A one-thumb landing skill game for the phone (portrait, Godot 4.5, Compatibility renderer, exported to the web).
Side view, low-poly primitives with black outlines.

**Play:** https://hotshotted.github.io/Landing-Game/

## How to play

- Each round the plane comes in from the left on a descent toward a runway.
- **Drag up / down** to pitch the nose (relative drag, 1:1, like sky-dodge). Hold the nose up near the ground to **flare**.
  Flare too early and the plane floats, runs out of speed and drops hard; too late and it slams in.
- Every approach starts framed on the whole runway and zooms in as you close; a runway-distance readout and a big four-light **PAPI** in the sky
  above the plane (following it sideways) show the glide path: all white = too high, 2 white + 2 red = on path, all red = too low
  (a small matching PAPI stands by the runway as scenery). Size / position / speed are `papi_hud_*` in `Tuning.gd` and `?tune`.
- Hazards (trees / hill before the field, the runway) have full colour and black outlines, with a blinking beacon on the tallest;
  pure scenery (background trees, far hills, clouds) is faded toward the sky, unoutlined and scrolls slower (parallax).
- Wind: a steady head/tailwind plus gusts that bump the plane (windsock, drifting streaks, wind readout).
- Each landing is graded on touchdown **sink rate**, **touchdown point** (aim markers) and **no bounce**:
  *Greaser!* / Smooth / Good / Firm / Hard. Very hard, off-runway, trees/hill and overrun landings are crashes.
- **Scenarios** (each opens with a short title card): Short Field (trees before a short runway), Engine Out (no power: glide to the
  runway), Night (only the runway and approach lights), Mountain Strip (uphill runway: the ground rises to meet you, so flare later),
  Carrier (moving deck: touch down in the wire zone), Seaplane (calm water lane; rough water bounces), Moving Truck (land on a flatbed).
- **Aircraft** with distinct handling, each only offered the scenarios that suit it: Cub (slow, floaty, short landings), 172 (balanced),
  Twin (fast, long runways), Glider (no power, one attempt), Jet (very fast, stable, long runways, carrier). Pick on the menu or with `?plane=`.
- **Weather** on top: fog (the runway appears late), rain (reduced visibility, wet runway), turbulence on final, wind shear (the
  windsock snaps round as a warning, then a sudden sink just before the flare). Endless mode mixes scenarios and weather with
  rising difficulty. Force one with `?scenario=` / `?weather=` or the `?tune` panel.
- **Streaks:** consecutive *Greaser!* landings multiply the points (x2, x3 ... up to x10), with an escalating label, edge glow and
  sparkle. A Smooth or Good landing keeps the streak; a Firm or Hard landing or a crash breaks it. **No go-arounds:** every
  approach is landed or crashed (climbing well clear after being low is a crash).
- Endless rounds on random runways (length, surface, trees or a hill before the field). Three crashes end the run;
  the score is the sum of the landings.

## Debug URL flags

`?perf` worst-frame readout and hitch log · `?tune` live tuning panel (TUNE button, **Copy values**) ·
`?nofx=smoke,shake,popup,wind,clouds,sfx,haptic|all` · `?noprewarm` · `?god` · `?round=N` · `?seed=N` · `?plane=cub|172|twin|glider|jet` · `?scenario=short|engineout|night|mountain|carrier|water|truck|standard` · `?weather=fog|rain|turbulence|shear|clear`.
Flags are listed under the build stamp (bottom-left).

## Conventions (same as sky-dodge)

- Every feel value lives in `scripts/Tuning.gd`; the `?tune` panel edits them live.
- Everything is pooled / pre-built in `_ready` and pre-warmed behind a splash; nothing is allocated in play;
  restarts and new rounds reuse the same nodes in place.
- CI (`.github/workflows/deploy.yml`) imports, runs the headless smoke test (`tests/smoke_test.gd`), exports the web build under a
  commit-stamped name, and deploys to Pages. The build stamp (commit + UTC time) is in the corner; the page hops to the newest
  deploy if a stale copy is cached.
- `tests/balance_sim.gd` flies autopilots over many rounds and prints how landings grade (for tuning, not run by CI).

## Deploying

Pushes to `main` build and deploy through GitHub Pages (Settings -> Pages -> Source: GitHub Actions).

## Career and logbook (phase 4)

Six ranks - Student, Private, Instrument, Commercial, CFI, Airline Captain. Points from free-flight landings open each rank's
**checkride**: a fixed set of 3-5 landings (fixed scenario, weather, aircraft and runway) with standards - touch down within a
zone of the markers, stay under a sink rate, no bounce. Miss any standard (or crash) and the checkride ends; retry it from
landing 1. Pass and the rank rises, unlocking aircraft, scenarios and weather (Private: mountain strip, engine out, rain;
Instrument: twin, night, fog; Commercial: glider, seaplane, truck, turbulence; CFI: wind shear; Airline Captain: jet and carrier).
The **logbook** shows flight time, landings, crashes, the grade tally, best run / streak and one stamp per named airport
(27 of them), earned the first time you land there. Everything is saved as one versioned JSON document (`Save.gd`, migrates the
old best-score file; unreadable saves start fresh). `?tune` has Unlock all, Next aircraft, Checkride and Reset save buttons.
