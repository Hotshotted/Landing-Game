extends Node
## Every "feel" value of the game lives here, in one place.
## Registered as the autoload `Tuning`, so any script can read `Tuning.some_value`.
## They are plain vars (not consts) so the ?tune panel can edit them live.
## Units: world units ~ metres, seconds, degrees. The camera looks along -z: screen-right = +x,
## screen-up = +y. The plane flies toward +x and lands on the runway, ground is y = 0.

# ---------- Units ----------
## One world unit is this many feet (so a 22 unit/s approach is a 172 at 65 kt, and the 5-unit model is a 25 ft aeroplane).
## Everything shown to the player is converted with this (see Units.gd).
var feet_per_unit := 5.0

# ---------- Frame time ----------
## The simulation never advances more than this per frame (seconds), whatever the real frame took.
var max_frame_delta := 0.05
## A frame longer than this (a tab switch, a long hitch) is a stall: it is not simulated at all.
var stall_delta := 0.25
## Frames skipped (no simulation) after a stall or the window coming back, so nothing catches up.
var resume_skip_frames := 2
## The flight model runs in sub-steps of at most this many seconds (so a fast sink can't tunnel the ground).
var sim_step := 0.008

# ---------- Camera ----------
## Camera tilt looking down onto the field, so the runway's top surface shows as a band.
var camera_tilt_deg := 9.0
## Every approach starts framed to show the plane and the whole runway (the width needed, capped here) and
## zooms smoothly in as the plane gets closer, reaching view_width_low (the close flare framing) once the plane
## is zoom_close_distance from the aim markers. A low altitude also forces the close framing
## (fully close at zoom_low_altitude, none above zoom_high_altitude).
var view_width_low := 38.0
var view_width_full_max := 1500.0
var zoom_close_distance := 110.0
var zoom_high_altitude := 22.0
var zoom_low_altitude := 10.0
## Where the plane sits across the screen in the close framing (0 = left edge, 1 = right edge).
var plane_screen_x := 0.26
## Where the ground sits up from the bottom of the screen, close framing / wide framing.
var ground_screen_y := 0.2
var ground_screen_y_wide := 0.38
## The camera looks down a bit more when zoomed out, so the runway shows as a fatter band.
var camera_tilt_wide_deg := 26.0
## How fast the camera catches up with the zoom (per second).
var camera_smoothing := 5.0

# ---------- Controls ----------
## Degrees of pitch per pixel of finger drag (relative drag: up = nose up, 1:1, no momentum).
var pitch_per_pixel := 0.07
var sensitivity := 1.0
## The nose cannot move faster than this (degrees / second).
var pitch_rate := 45.0
var pitch_min := -12.0
var pitch_max := 16.0
## With the finger lifted the nose eases back to the approach attitude at this rate (degrees / second).
var pitch_return := 18.0
## How much the drawn nose moves per degree of pitch, and the drawn attitude when pitch = 0.
var pitch_visual_scale := 1.4
var pitch_visual_offset := -2.0

# ---------- Flight model ----------
## Airspeed at the approach attitude of the 172 (units / second, = 65 kt); every aircraft scales this by its Vref / 65.
var approach_speed := 22.0
## The standard glide path: the approach attitude descends at this angle (so the sink rate is speed x tan(angle)). The PAPI
## shows this path.
var glide_angle_deg := 3.0
## Seconds an approach lasts (sets how high and far back it starts).
var approach_seconds := 24.0
## Vref (approach speed) and stall speed in knots for each aircraft.
var vref_cub := 45.0
var stall_cub := 38.0
var vref_172 := 65.0
var stall_172 := 48.0
var vref_twin := 90.0
var stall_twin := 65.0
var vref_glider := 55.0
var stall_glider := 40.0
var vref_jet := 135.0
var stall_jet := 110.0
## Sink-rate change per degree of pitch (nose up = less sink, nose down = more).
var pitch_lift_gain := 0.18
## How quickly the sink rate follows what the nose asks for (seconds, smaller = snappier).
var response_time := 0.5
## Airspeed (as a fraction of the approach speed) comes back to 1.0 at this rate...
var speed_recover := 0.25
## ...and nose-up bleeds it away at this rate per 10 degrees (nose down gains speed).
var speed_bleed := 0.08
## Below the stall speed (its stall kt / Vref) the wing stalls: the sink target grows by stall_sink_gain per 1.0 of deficit.
var stall_sink_gain := 12.0
## Ground effect: within this height the plane gets up to ground_effect_lift of extra lift, growing with the square of the
## airspeed (carry too much speed and it floats down the runway)...
var ground_effect_height := 3.5
var ground_effect_lift := 0.34
## ...and holding the flare in ground effect bleeds speed this much faster (1 = double at the ground).
var ground_effect_bleed := 1.2
## The plane cannot climb above this.
var max_altitude := 140.0

# ---------- Wind ----------
## Steady wind range. Headwind slows the ground speed (a steeper, slower approach), tailwind speeds it up.
var wind_head_max := 6.0
var wind_tail_max := 3.0
## Gusts: vertical bump (units/s of sink target), horizontal bump (units/s of wind), time between, length.
var gust_strength := 0.8
var gust_horizontal := 2.0
var gust_interval_min := 2.0
var gust_interval_max := 4.5
var gust_duration := 0.9
## A headwind gust adds airspeed: fraction per unit/s.
var gust_airspeed_effect := 0.02
## Degrees of nose wobble a gust kicks into the drawn plane.
var gust_wobble := 14.0
## Wind speed at which the windsock sticks out straight.
var sock_full_wind := 5.0
var wind_enabled := true

# ---------- Touchdown & grading ----------
## Touchdown sink rate in FEET PER SECOND. Grades: Greaser! up to fps_greaser, Smooth up to fps_smooth, Good up to fps_good,
## Firm up to fps_firm, Hard above. fps_zero is where the sink part of the score reaches nothing.
var fps_greaser := 2.0
var fps_smooth := 3.0
var fps_good := 4.0
var fps_firm := 7.0
var fps_zero := 9.0
## Touching down at or above this sink rate breaks the aircraft (structural limit); each aircraft has its own multiplier.
var fps_crash := 12.0
## Touching down above this sink rate bounces; the plane rebounds at restitution x the sink rate.
var fps_bounce := 8.0
var bounce_restitution := 0.35
## Points: sink rate, touchdown point, no bounce (they add up to 100).
var sink_points := 60.0
var position_points := 30.0
var bounce_points := 10.0
## Touchdown point: full points within position_perfect_ft of the aim markers, nothing at position_zero_ft.
var position_perfect_ft := 60.0
var position_zero_ft := 500.0
## Total points needed for each grade (Greaser! / Smooth / Good / Firm; below is Hard)...
var grade_greaser := 88.0
var grade_smooth := 72.0
var grade_good := 52.0
var grade_firm := 32.0

# ---------- Landing standards (tiers: Student / Sport / Recreational, Private / Instrument, Commercial and above) ----------
## Touch down at or within this many feet beyond the aim point: normal (and night, instrument, soft field), short field.
var std_zone_normal_ft := [600.0, 400.0, 200.0]
var std_zone_short_ft := [300.0, 200.0, 100.0]
## Power-off 180: at or within this beyond the point.
var std_zone_power_off_ft := 200.0
## ... and at most this far SHORT of the point.
var std_short_tol_ft := [75.0, 50.0, 25.0]
## Approach speed (measured at gate_height_ft above the ground) within Vref minus / plus this many knots.
var std_kt_minus := [10.0, 5.0, 5.0]
var std_kt_plus := [15.0, 10.0, 5.0]
var gate_height_ft := 50.0
## Touchdown sink rate limit (ft/s); soft fields allow less.
var std_sink_fps := [6.0, 5.0, 4.0]
var std_sink_fps_soft := [4.0, 3.0, 2.5]
## Soft field: after touchdown the nose target must stay above this many degrees until the speed has dropped to this
## fraction of the touchdown speed.
var soft_nose_deg := 2.0
var soft_release := 0.55
var soft_decel_mult := 1.35
## Instrument approach: the runway appears at this height (decision height, feet), the fog until then is this thick
## (units of visibility), and being off the glide path (all four PAPI lights the same colour) for longer than
## instrument_dev_seconds fails.
var instrument_dh_ft := 100.0
var instrument_vis := 22.0
var instrument_dev_seconds := 2.5

# ---------- Career ----------
## Practice landings that meet the standard to fill one landing type's proficiency meter.
var proficiency_needed := 3
## Landings in a checkride (drawn at random from the rank's types).
var ride_landings := 3
## Examiner fee in coins for the checkride to rank r: exam_fee_base x exam_fee_growth ^ (r - 1). Failing loses it.
var exam_fee_base := 40.0
var exam_fee_growth := 1.45

# ---------- Rollout ----------
## Braking per surface (units/s^2): asphalt, grass, dirt.
var decel_asphalt := 4.6
var decel_grass := 3.3
var decel_dirt := 2.7
## Rolling past the end of the runway faster than this is an overrun crash.
var overrun_speed := 1.0
## The landing is over when the plane has slowed below this (and shown for at least rollout_min_time).
var rollout_rest_speed := 1.0
var rollout_min_time := 1.6
var rollout_max_time := 14.0
## Nose-down settle after touchdown (degrees / second).
var nose_settle_rate := 30.0

# ---------- Rounds ----------
## Three crashes end the run.
var strikes_max := 3
## Difficulty (wind, gusts, short fields, terrain) ramps up over this many rounds.
var ramp_rounds := 10
## How far (units) the plain approach path can miss the aim markers, early rounds scaled down.
var path_error_max := 55.0
## Aim markers sit this fraction of the runway length past the threshold (clamped, units).
var aim_fraction := 0.2
var aim_min := 55.0
var aim_max := 190.0
## Runway lengths in units (x 5 = feet): asphalt 2600-4500 ft, grass 1900-2800, dirt 1600-2400.
var runway_length_asphalt_min := 520.0
var runway_length_asphalt_max := 900.0
var runway_length_grass_min := 380.0
var runway_length_grass_max := 560.0
var runway_length_dirt_min := 320.0
var runway_length_dirt_max := 480.0
## Short fields (units): 1300-1700 ft, soft fields 1800-2600 ft.
var short_field_min := 260.0
var short_field_max := 340.0
var soft_field_min := 360.0
var soft_field_max := 520.0
## Late rounds shorten the fields by up to this fraction.
var runway_shrink := 0.25

# ---------- Feedback ----------
## Camera shake from a landing: starts above shake_min_sink, grows per unit of sink, capped at shake_max (0..1).
var shake_min_sink := 0.7
var shake_per_sink := 0.7
var shake_max := 1.0
var shake_decay := 5.0
var shake_size := 1.2
## How long the grade popup stays up, and the pause after a crash.
var popup_time := 1.7
var crash_pause := 1.9
var fade_time := 0.25
## Tire smoke and dust.
var smoke_count := 22
var roll_puff_interval := 0.09
## Black outline width around every hazard / play-layer shape, in world units (grows when zoomed out so it stays visible).
var outline_thickness := 0.16
## Scenery (background trees, far hills, clouds) is faded toward the sky colour by this much (0 = full colour, 1 = sky)
## and scrolls at this fraction of the camera speed (1 = same as the play layer).
var scenery_haze_trees := 0.6
var scenery_haze_hills := 0.72
var parallax_trees := 0.6
var parallax_hills := 0.3
var parallax_clouds := 0.15

# ---------- PAPI ----------
## Four lights beside the aim markers: all white = too high, 2 white + 2 red = on the glide path, all red = too low.
## Each light flips when the plane's glide slope (relative to the path to the markers) crosses its step; the steps
## are papi_band apart (0.12 = 12 % of the slope).
var papi_band := 0.12
## Inside this distance of the markers the lights hold their last state (the angle swings wildly right at the end).
var papi_hold_distance := 20.0
## A light flips back only after passing its step by this fraction of papi_band (stops flicker in turbulence).
var papi_hysteresis := 0.15
## The big HUD PAPI in the sky above the plane: light diameter and gap (screen pixels at the 1080 px wide layout),
## height of the row as a fraction of the screen height, and the clearance kept from the screen edges.
var papi_hud_size := 112.0
var papi_hud_gap := 22.0
var papi_hud_y := 0.27
var papi_hud_margin := 24.0
## How fast a light changes colour and how fast the row follows the plane sideways (per second; higher = snappier).
var papi_hud_fade := 9.0
var papi_hud_follow := 10.0

# ---------- Streaks ----------
## Consecutive "Greaser!" landings multiply the points (x2, x3 ...) up to this cap. A Smooth or Good landing keeps the streak
## (and still earns the multiplier); a Firm or Hard landing, or a crash, breaks it.
var streak_cap := 10
## How bright the screen-edge glow gets at the top of the streak ramp (0..1).
var streak_glow_max := 0.6
## No go-around: once the plane has been below go_around_low above the ground, climbing go_around_climb above its lowest point is a
## go-around attempt - and that is a crash. (A balloon in the flare is nowhere near this.)
var go_around_low := 15.0
var go_around_climb := 10.0

# ---------- Coins, daily approach, ad stubs ----------
## Coins per landing by grade (Greaser! .. Hard), times the streak multiplier. They only buy paint and pilot gear.
var coins_greaser := 10
var coins_smooth := 6
var coins_good := 4
var coins_firm := 2
var coins_hard := 1
## The daily approach is always flown at this difficulty round.
var daily_round := 8
## The fake "Ad playing" screen lasts this long (seconds). Real ad SDKs replace Ads.gd's stubs later.
var ad_fake_seconds := 2.0
## An interstitial (between rounds only) is offered after this many landed rounds ...
var ad_interstitial_every := 4
## ... and never sooner than this many seconds after the last ad.
var ad_min_gap_seconds := 60.0

# ---------- Scenarios ----------
## The title card at the start of each approach (seconds; a tap skips it).
var card_time := 1.7
## Mountain strip: the runway climbs at this angle (degrees); the ground starts rising 25 units before the threshold.
var mountain_slope_min := 2.0
var mountain_slope_max := 4.0
## Carrier: deck height, speed, the wire zone (half width around the aim point) and the arrested stop.
var carrier_deck_height := 9.0
var carrier_speed_min := 7.0
var carrier_speed_max := 10.0
var carrier_wire_half := 28.0
var carrier_arrest_decel := 55.0
var deck_decel := 8.0
## Moving truck: bed length, speed, height and braking.
var truck_len_min := 60.0
var truck_len_max := 76.0
var truck_speed_min := 4.5
var truck_speed_max := 6.5
var truck_height := 2.4
var truck_decel := 16.0
## Seaplane: braking on water, and how much harder a touchdown on rough water (outside the calm lane) counts.
var water_decel := 2.4
var water_rough_mult := 1.7
## Engine out: drag on the airspeed and how much steeper the glide is.
var engine_out_drag := 0.004
var engine_out_sink_mult := 2.0

# ---------- Weather ----------
## Fog: how far the runway can be seen (units), where the fade starts.
var fog_end_min := 90.0
var fog_end_max := 140.0
var fog_start := 20.0
## Rain: visibility, and how much the wet runway cuts the braking.
var rain_vis_end := 600.0
var rain_wet_decel := 0.65
## Turbulence on final: vertical noise (units/s), building from nothing this far before the threshold to full strength at it.
var turb_strength := 0.6
var turb_zone := 250.0
## Wind shear: the downdraft (units/s), the headwind it takes away, how long it lasts, and the warning (windsock snap)
## before it hits (seconds).
var shear_sink := 1.7
var shear_head_drop := 5.0
var shear_duration := 1.2
var shear_tele_time := 1.4

# ---------- Start-up pre-warm ----------
var prewarm_min_seconds := 1.5
var prewarm_stable_frames := 10
var prewarm_stable_ms := 45.0
var prewarm_max_seconds := 6.0

## 0 in round 1 up to 1 from round ramp_rounds + 1 on.
func ramp(round_no: int) -> float:
	return clampf(float(round_no - 1) / maxf(float(ramp_rounds), 1.0), 0.0, 1.0)
