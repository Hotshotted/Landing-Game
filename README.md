# Greaser

A one-thumb landing skill game for the phone (portrait, Godot 4.5, Compatibility renderer, exported to the web).
Side view, low-poly primitives with black outlines. By **Clear Prop Games**.

The look is one shared style system (palette, fonts, icons, buttons, motion), written down in `docs/style.md`. The web build has its own loading page (`web/shell.html`). The build stamp is hidden unless you add `?debug` (or `?tune` / `?perf`) to the URL. Icons and the splash come from `icon.svg` and `tools/splash.html` (`node tools/make_icons.js`); before / after screenshots of every screen are in `docs/screens/`.

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

## Cosmetics, daily approach, ad stubs (phase 5)

- **Coins** come from every free-flight / daily landing (Greaser! pays most, times the streak multiplier; a landing that ends in a
  crash gives them back). The **Hangar** spends them on paint schemes (applied to whichever aircraft you fly) and gear for the pilot,
  Whiskers the cat (goggles, cap, scarf, crown). Purely visual.
- **Daily Approach**: one hard approach per calendar day, the same for everyone (seeded by the date; weather is never clear,
  difficulty round `daily_round`). One landing; the best score of the day is saved locally (retries allowed, same approach).
- **Ad hooks** are stubs (`Ads.gd`) with a fake "Ad playing" screen of `ad_fake_seconds`: rewarded *Halve your examiner fee* (offered
  after a failed checkride; the retest costs half, once) and *Double coins*; an interstitial only on the fade between free-flight rounds, every `ad_interstitial_every`
  landed rounds and at least `ad_min_gap_seconds` apart - never mid-approach, in a checkride or in the daily. `?noads` switches
  them off. A real ad SDK replaces the fake screen later.
- `?tune`: Unlock all, Next aircraft, Checkride, Reset save, +500 coins (plus the earlier force scenario / weather buttons and
  `?scenario=`, `?weather=`, `?plane=` flags).

## Realism (career update, part 1)

- **Units**: one world unit is 5 ft (`feet_per_unit`), so the 172's 22 units/s approach is 65 kt. Everything you read is in aviation
  terms: airspeed in knots with Vref and a tolerance band on the bar, altitude in feet, vertical speed in ft/min, distances and
  runway lengths in feet, wind in knots, touchdown sink in ft/s (`Units.gd`).
- **Aircraft speeds** (Tuning knots, Vref / stall): Cub 45/38, 172 65/48, Twin 90/65, Glider 55/40, Jet 135/110.
- **Glide path**: the approach attitude descends at 3 degrees (`glide_angle_deg`); the PAPI shows that path (power-off landings show
  their steeper glide). Approaches last ~24 s (`approach_seconds`).
- **Flare and float**: ground effect lift grows with the square of the airspeed (carry too much speed and you float down the runway),
  holding the flare in ground effect bleeds speed faster, below the stall speed the plane drops in.
- **Grading by sink rate**: Greaser! under 2 ft/s, Smooth under 3, Good under 4, Firm under 7, Hard above; each aircraft has a
  structural limit (12 ft/s, the jet 18) above which it breaks (all Tuning values: `fps_*`).
- **Landing types**, each judged on its own standard (`Standards.gd`; three tiers - Student/Sport/Recreational, Private/Instrument,
  Commercial and up): normal / night (touch down at or within 600/400/200 ft beyond the aim point, approach speed measured at 50 ft within
  Vref +15/-10, +10/-5, +/-5 kt, sink and no bounce), short field (300/200/100 ft), soft field (rough grass; minimum sink and hold the
  nose off), power-off 180 (power cut abeam the point; within 200 ft), engine out (a forced landing on an unpaved field), instrument
  approach (fog; fly the PAPI glide path to the 100 ft minimums, then the runway appears), plus the special scenarios (mountain strip,
  seaplane, carrier, moving truck). Every landing shows STANDARD MET / MISSED.

## Ranks (career update, part 2)

Eight ranks: Student, Sport, Recreational, Private, Instrument, Commercial, CFI, Airline Captain. Each lists its landing types
(you train and are tested on the NEXT rank's list, at that rank's standard tier):
Sport - normal and soft field (light-sport: the Cub, day only); Recreational - adds short field and engine out (and the 172);
Private - normal, short, soft, engine out, night; Instrument - adds instrument approaches; Commercial - adds the power-off 180, tighter
tolerances, unlocks the twin; CFI - all the landing types at Commercial standards (adds mountain strip, seaplane, flatbed; the glider);
Airline Captain - the jet, instrument approaches, the carrier. Weather opens up with the ranks (rain / turbulence at Private, fog at
Instrument, wind shear at Commercial). The save is version 2: a version 1 save's six ranks move onto the new ladder.

## Practice and the endorsement (career update, part 3)

The career screen lists the landing types of the rank you are training for, each with a proficiency meter (3 pips, `proficiency_needed`)
and a PRACTICE button. A practice landing is one approach in a suitable aircraft (the newest one is likelier) flown to that rank's
standard; meeting every standard fills a pip, while a miss or a crash doesn't count and says why. Meters earned at the same standard
tier carry over to the next rank, a new tier starts them again. When every meter is full the instructor (Captain Wiggins, a small
flat portrait) signs an endorsement - the checkride can then be booked. `?tune`: Promote rank, Fill meters, +500 coins.

## Checkrides and consequences (career update, part 4)

With the instructor's endorsement and the examiner's fee in coins (`exam_fee_base` x `exam_fee_growth` ^ (rank - 1), so it grows with the
rank) you can book the checkride from the career screen. It draws `ride_landings` (3) landing types at random from the rank's list and
reveals them one at a time on the title card, each flown to the rank's standard. Miss any standard (or crash) and it is over: the
fee is gone, a **pink slip** (date, rank, failed landing type) is stamped in the logbook for good, and the failed type's meter drops back
to half - so you practise it again to be re-endorsed before a **retest**: a full checkride with a new random draw at the full fee.
Pass and a certificate for the new rank is shown. `?screen=certificate|slip|career|logbook|hangar` opens a screen at start.

## Approach pacing

Every approach starts `approach_seconds` (default 7.5, a `?tune` slider) of descent on the 3 degree path before the touchdown point:
the start altitude is that time x the aircraft's sink rate, so a faster aircraft starts further out but takes about the same time
(172 ~150 u / 750 ft from the aim point, Cub ~120 u, twin ~210 u, jet ~325 u). With the flare and float an approach lasts about 10 s
(the pre-realism pacing). Dead-stick approaches (engine out, power-off 180, the glider) get `dead_stick_time_mult` (1.3) times longer;
an instrument approach starts 25 ft above its 100 ft decision height (so it is the longest: ~23 s in the 172, ~12 s in the jet - the
decision height alone is 17 s of path at 65 kt); obstacles and a mountain ramp set how close a start can be. The opening frame is the
wide framing showing the plane and the whole runway; the zoom tightens from there.

## Push-your-luck free flight, pause, buying aircraft

- **The pot**: a free-flight run has no strikes any more. Coins earned in the run go into an unbanked **pot** on the HUD, multiplied by
  1 + `pot_step` (0.2) for every landing survived (x1.0, x1.2, x1.4 ...), with the Greaser streak bonus on top. After every landing
  a choice screen shows the pot, the next multiplier and a hint about the next approach ("Next: Fog, Short Field"): **CASH OUT**
  banks the pot with a count-up and ends the run, **KEEP FLYING** starts the next approach. A crash ends the run and loses the whole
  pot ("Pot lost: 840 coins"). Each approach is harder (`difficulty_step` 0.1 per landing up to `difficulty_max` 1.6: tougher
  scenarios, worse and more frequent weather, shorter runways, stronger winds and gusts).
- **Aircraft are bought with coins** in the hangar (or unlocked by rank): 172 200, glider 450, twin 600, jet 1200 (Tuning `price_*`).
  Typical cash-outs: ~50 coins (casual, 4 landings), ~70-250 (good), ~460 (five greasers in a row); examiner fees 40-372.
- **Pause**: a button in the top-right corner. Resume / Settings (sound and music volume, saved) / Quit. Quitting a free-flight run
  forfeits the pot (confirmation: "Quit and lose 840 coins?"); quitting a checkride counts as a fail (confirmation first). The game
  also pauses itself when the app loses focus. `?screen=choice|pause` shows those screens.

## Career, free flight and the flight-school economy

- Every landing that meets the current standard for its landing type fills that type's proficiency meter, in free flight, practice and the daily approach (a toast says "Short Field +1, 2/3"). Free flight favours the landing types you are training for.
- Aircraft: rent per flight, or buy to end the rental; a crash in a rented one adds a damage fee. Instructor lessons count double. The checkride lock on the career screen says exactly which types are missing. See `docs/economy.md` (with the two-hour simulation: `godot --headless --path . --script res://tools/economy_sim.gd`).
- Ground layers (runway, paint, edge stripes, aim marks, wires, road) each have their own height, 0.02 apart, and the camera's depth range hugs the view, so nothing z-fights; `docs/screens/ground/` shows every scenario, weather and time of day.
