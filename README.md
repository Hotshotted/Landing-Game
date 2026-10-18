# Greaser

A one-thumb landing skill game for the phone (portrait, Godot 4.5, Compatibility renderer, exported to the web).
Side view, low-poly primitives with black outlines.

**Play:** https://hotshotted.github.io/Landing-Game/

## How to play

- Each round the plane comes in from the left on a descent toward a runway.
- **Drag up / down** to pitch the nose (relative drag, 1:1, like sky-dodge). Hold the nose up near the ground to **flare**.
  Flare too early and the plane floats, runs out of speed and drops hard; too late and it slams in.
- Every approach starts framed on the whole runway and zooms in as you close; a runway-distance readout and four **PAPI** lights beside
  the aim markers show the glide path (all white = too high, 2 white + 2 red = on path, all red = too low).
- Hazards (trees / hill before the field, the runway) have full colour and black outlines, with a blinking beacon on the tallest;
  pure scenery (background trees, far hills, clouds) is faded toward the sky, unoutlined and scrolls slower (parallax).
- Wind: a steady head/tailwind plus gusts that bump the plane (windsock, drifting streaks, wind readout).
- Each landing is graded on touchdown **sink rate**, **touchdown point** (aim markers) and **no bounce**:
  *Greaser!* / Smooth / Good / Firm / Hard. Very hard, off-runway, trees/hill and overrun landings are crashes.
- Endless rounds on random runways (length, surface, trees or a hill before the field). Three crashes end the run;
  the score is the sum of the landings.

## Debug URL flags

`?perf` worst-frame readout and hitch log · `?tune` live tuning panel (TUNE button, **Copy values**) ·
`?nofx=smoke,shake,popup,wind,clouds,sfx,haptic|all` · `?noprewarm` · `?god` · `?round=N` · `?seed=N`.
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
