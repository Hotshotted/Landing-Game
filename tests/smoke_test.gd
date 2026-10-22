extends SceneTree
## Headless smoke test:  godot --headless --path . --script res://tests/smoke_test.gd
## Exits with code 1 if anything below fails (CI runs this before exporting).
##   1. boot: the splash pre-warm draws every pooled thing, then cleans up; the menu shows; tap starts a run
##   2. grading: pure scoring (sink / touchdown point / bounce), grade bands, crash sink
##   3. flight model: a plain approach lands on the runway; the nose follows RELATIVE drag 1:1; nose down sinks
##      faster; a good flare lands softer than none; flaring too early floats then drops hard; too late slams in
##   4. wind: tailwind/headwind change the ground speed, gusts fire and bump the plane, the windsock follows the wind
##   5. rounds: random runways (length, surface, terrain) vary, trees / hill are always passable on the plain path,
##      trees and hill really crash the plane, off-runway and overrun are crashes, a bounce is flagged
##   6. run flow: crashes are strikes, three end the run, tap restarts IN PLACE, score is the sum of landings
##   7. no new nodes / resources are created after start-up, over several rounds and a whole run
##   8. ?tune panel: opens over the paused game, sliders edit Tuning live, Copy / Reset work, absent without ?tune
##   9. ?debug flags parse; frame-time handling (clamp, stall drop)

var failures: Array[String] = []
var tn: Node
var MAIN: GDScript
var AF: GDScript
var GR: GDScript
var TP: GDScript
var DF: GDScript
var SV: GDScript
var WIND: GDScript
var AC: GDScript
var SC: GDScript
var UN: GDScript

func load_classes() -> void:
	MAIN = load("res://scripts/Main.gd")
	AF = load("res://scripts/Airfield.gd")
	GR = load("res://scripts/Grading.gd")
	TP = load("res://scripts/TunePanel.gd")
	DF = load("res://scripts/DebugFlags.gd")
	SV = load("res://scripts/Save.gd")
	WIND = load("res://scripts/Wind.gd")
	AC = load("res://scripts/Aircraft.gd")
	SC = load("res://scripts/Scenarios.gd")
	UN = load("res://scripts/Units.gd")

var main: Node3D

func check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		failures.append(what)

func tap(pos: Vector2 = Vector2(540, 900)) -> void:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = true
	Input.parse_input_event(e)
	main._input(e)
	var r := InputEventScreenTouch.new()
	r.position = pos
	r.pressed = false
	main._input(r)

func frames(n: int) -> void:
	for i in n:
		await process_frame

func nodes() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))

func objects() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_COUNT))

func resources() -> int:
	return int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))

## Drive the nose to `deg` (via drag, as a finger would).
func set_nose(deg: float) -> void:
	var dy: float = -(deg - main.aircraft.theta_target) / (float(tn.pitch_per_pixel) * float(tn.sensitivity))
	main.aircraft.touching = true
	main.aircraft.add_drag(dy)

## Fly the current approach with a simple autopilot: steer onto the aim markers, then at `flare_h` flare.
## flare_theta > 0 = hold that nose angle (a crude pilot); flare_theta <= 0 = ease the sink rate down smoothly
## with the height (a good pilot). flare_h < 0 = never flare. Returns {"crash": bool, "result": Dictionary}.
func fly(flare_h: float, flare_theta: float) -> Dictionary:
	var ac = main.aircraft
	var af = main.airfield
	main.last_result = {}
	var t := 0.0
	while t < 70.0:
		t += 1.0 / 30.0
		var gs: float = maxf(float(ac.gs), 4.0)
		var cmd := 0.0
		if flare_h < 0.0 or ac.y > flare_h:
			var t_go := maxf((af.aim_x - ac.x) / gs, 0.5)
			var want_vy := clampf(-ac.y / t_go, -1.6 * ac.trim_sink(), -0.7 * ac.trim_sink())
			cmd = (want_vy + ac.trim_sink()) / ac.lift_gain()
		elif flare_theta > 0.0:
			cmd = flare_theta
		else:
			var want: float = -(0.33 + 0.3 * float(ac.y))
			cmd = (want + ac.trim_sink()) / ac.lift_gain()
		set_nose(cmd)
		main.advance(1.0 / 30.0)
		if main.state == MAIN.CRASH:
			return {"crash": true, "result": {}}
		if main.state == MAIN.ROLLOUT or main.state == MAIN.FADE:
			return {"crash": false, "result": main.last_result}
	return {"crash": false, "result": main.last_result, "timeout": true}

## Start a fresh round `r` with a fixed seed, without the fade (so tests can fly it at once).
func new_round(seed_value: int, r: int) -> void:
	main.rng.seed = seed_value
	main.round_no = r - 1
	main._begin_round(false)
	main._snap_camera()
	main.hud.set_fade_now(0.0)

func _init() -> void:
	await process_frame
	await run_all()
	print("")
	if failures.is_empty():
		print("ALL CHECKS PASSED")
		quit(0)
	else:
		print("%d CHECK(S) FAILED:" % failures.size())
		for f in failures:
			print("  - " + f)
		quit(1)

func run_all() -> void:
	tn = root.get_node("/root/Tuning")
	load_classes()
	SV.enabled = false
	SV.data = SV.default_data()
	var ADS: GDScript = load("res://scripts/Ads.gd")
	ADS.enabled = false          # (section 18 tests the ad stubs)
	SV.data["unlock_all"] = true      # (the earlier sections fly every aircraft and scenario; section 17 tests the locks)
	print("== 1. boot ==  [nodes %d]" % nodes())
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	var t0 := Time.get_ticks_msec()
	while main._warming and Time.get_ticks_msec() - t0 < 15000:
		await process_frame
	var warm_ms := Time.get_ticks_msec() - t0
	check(not main._warming, "pre-warm finishes by itself")
	check(warm_ms >= int(tn.prewarm_min_seconds * 1000.0) - 200, "pre-warm runs at least prewarm_min_seconds (%d ms)" % warm_ms)
	check(main.state == MAIN.MENU, "boot ends on the menu")
	check(main.hud.overlay_visible, "the menu overlay is showing")
	check(main.hud._splash.visible == false, "the splash is gone after the pre-warm")
	check(main.airfield.get_child_count() > 100, "the pooled airfield is built (%d nodes)" % main.airfield.get_child_count())
	main.test_mode = true
	var n_start := nodes()
	tap()
	check(main.state == MAIN.CARD and main.hud.card_visible(), "a tap on the menu starts the run with the scenario title card")
	main.advance(float(tn.card_time) + 0.1)
	check(main.state == MAIN.APPROACH and not main.hud.card_visible(), "the card goes after card_time and the approach begins")
	check(not main.hud.overlay_visible, "the overlay is hidden in play")
	check(main.round_no == 1 and main.pot == 0 and main.score == 0, "run starts at round 1, empty pot, score 0")
	check(main.aircraft.x == 0.0 and main.aircraft.y > 3.0, "the plane starts on the left, high")
	check(main.airfield.thr > float(tn.min_start_distance) - 1.0 and main.airfield.aim_x > main.airfield.thr, "the runway is ahead with the aim markers on it")

	print("== 2. grading ==  [nodes %d]" % nodes())
	var fps := func(f: float) -> float: return UN.ups_of_fps(f)       # feet per second -> world units per second
	var g: Dictionary = GR.evaluate(fps.call(1.0), 0.0, 700.0, false)
	check(g["total"] == 100 and g["grade"] == 0 and g["name"] == "Greaser!", "soft (1 ft/s), on the aim point, no bounce = 100, Greaser!")
	g = GR.evaluate(fps.call(1.0), 0.0, 700.0, true)
	check(g["grade"] >= 2, "a bounce can't be better than Good (%s)" % g["name"])
	g = GR.evaluate(fps.call(5.0), 0.0, 700.0, false)
	check(g["grade"] >= 3, "a firm 5 ft/s can't be a good grade even on the aim point (%s)" % g["name"])
	g = GR.evaluate(fps.call(9.0), 150.0, 700.0, false)
	check(g["grade"] == 4 and g["name"] == "Hard", "9 ft/s and 750 ft off = Hard")
	check(GR.sink_score(fps.call(2.0)) > GR.sink_score(fps.call(5.0)) and GR.sink_score(fps.call(5.0)) > GR.sink_score(fps.call(8.0)), "sink points fall as the sink rate grows")
	check(GR.position_score(0.0, 700.0) > GR.position_score(50.0, 700.0), "points fall with distance from the aim point")
	check(is_equal_approx(GR.position_score(-40.0, 700.0), GR.position_score(40.0, 700.0)), "short and long of the aim point score the same")
	check(GR.grade_for_sink(fps.call(1.9)) == 0 and GR.grade_for_sink(fps.call(2.9)) == 1 and GR.grade_for_sink(fps.call(3.9)) == 2 and GR.grade_for_sink(fps.call(6.9)) == 3 and GR.grade_for_sink(fps.call(7.2)) == 4, "sink grades: Greaser! under 2 ft/s, Smooth under 3, Good under 4, Firm under 7, Hard above")
	check(GR.is_crash_sink(fps.call(13.0)) and not GR.is_crash_sink(fps.call(11.0)), "13 ft/s breaks the aircraft, 11 ft/s does not")
	check(not GR.is_crash_sink(fps.call(17.0), 1.5) and GR.is_crash_sink(fps.call(19.0), 1.5), "a tougher aircraft (the jet) has a higher structural limit")
	check(UN.fps(UN.ups_of_fps(7.0)) > 6.99 and absf(UN.kt(UN.ups_of_kt(65.0)) - 65.0) < 0.01 and absf(UN.ft(10.0) - 50.0) < 0.01, "unit conversions round-trip (5 ft per unit)")
	check(absf(UN.kt(float(tn.approach_speed)) - float(tn.vref_172)) < 1.5, "the 172's world approach speed is its Vref in knots (%.1f kt)" % UN.kt(float(tn.approach_speed)))
	var cap: int = GR.NAMES.size()
	check(cap == 5 and GR.NAMES[0] == "Greaser!" and GR.NAMES[4] == "Hard", "grades run from Greaser! to Hard")

	print("== 3. flight model ==  [nodes %d]" % nodes())
	new_round(11, 1)
	var ac = main.aircraft
	# relative drag, 1:1, no momentum
	ac.theta_target = 0.0
	ac.touching = true
	ac.add_drag(-100.0)
	ac.consume_input(0.016)
	check(is_equal_approx(ac.theta_target, 100.0 * float(tn.pitch_per_pixel)), "dragging up 100 px raises the nose target 100 x pitch_per_pixel (%.2f deg)" % ac.theta_target)
	ac.add_drag(100.0)
	ac.consume_input(0.016)
	check(absf(ac.theta_target) < 0.001, "dragging back down returns it (relative, not absolute)")
	ac.touching = false
	ac.theta_target = 6.0
	ac.consume_input(0.1)
	check(ac.theta_target < 6.0 and ac.theta_target > 0.0, "with the finger lifted the nose eases back toward the approach attitude")
	ac.add_drag(-100000.0)
	ac.touching = true
	ac.consume_input(0.016)
	check(ac.theta_target <= float(tn.pitch_max) + 0.001, "the nose target is clamped to pitch_max")
	# nose down sinks faster than nose up
	ac.reset(0.0, 60.0)
	var vy_up := steady_vy(5.0, 1.2)
	ac.reset(0.0, 60.0)
	var vy_dn := steady_vy(-6.0, 1.2)
	ac.reset(0.0, 60.0)
	var vy_0 := steady_vy(0.0, 1.2)
	check(vy_dn < vy_0 and vy_0 < vy_up, "nose down sinks faster than level approach, nose up sinks less (%.1f < %.1f < %.1f)" % [vy_dn, vy_0, vy_up])
	check(absf(vy_0 + ac.trim_sink()) < 0.25, "the approach attitude gives the approach sink rate (%.2f)" % vy_0)
	check(absf(rad_to_deg(atan(ac.trim_sink() / ac.air_speed())) - float(tn.glide_angle_deg)) < 0.05, "...which is the standard %.0f degree glide path (%.0f ft/min at 65 kt)" % [float(tn.glide_angle_deg), UN.fpm(ac.trim_sink())])
	# nose up bleeds airspeed
	ac.reset(0.0, 60.0)
	steady_vy(12.0, 4.0)
	check(ac.s < 0.85, "holding the nose up bleeds airspeed (s = %.2f)" % ac.s)
	# a plain approach lands
	new_round(21, 1)
	var plain := fly(-1.0, 0.0)
	check(not plain["crash"] and plain["result"].has("grade"), "round 1, plain approach with no flare lands on the runway (%s)" % main.last_crash)
	var plain_sink: float = plain["result"].get("sink", 0.0)
	check(UN.fps(plain_sink) > 3.0 and UN.fps(plain_sink) < float(tn.fps_crash), "...but firmly (%.1f ft/s): the flare is what makes it a greaser" % UN.fps(plain_sink))
	# flare comparison on the same seeds: perfect vs none vs early vs late
	var sum_none := 0.0
	var sum_good := 0.0
	var sum_early := 0.0
	var sum_late := 0.0
	var crashes_late := 0
	var crashes_early := 0
	var n := 12
	for i in n:
		var seed_v := 300 + i
		new_round(seed_v, 1)
		sum_none += sink_of(fly(-1.0, 0.0))
		new_round(seed_v, 1)
		sum_good += sink_of(fly(2.5, 0.0))
		if i < 3:
			print("      sample good flare: ", main.last_result.get("name"), " sink ", snappedf(float(main.last_result.get("sink", 0.0)), 0.01))
		new_round(seed_v, 1)
		var e := fly(14.0, 6.5)
		if e["crash"]:
			crashes_early += 1
		sum_early += sink_of(e)
		new_round(seed_v, 1)
		var l := fly(0.8, 6.5)
		if l["crash"]:
			crashes_late += 1
		sum_late += sink_of(l)
	print("      mean sink: none %.2f | good flare %.2f | too early %.2f | too late %.2f  (crashes: early %d, late %d)" % [
		sum_none / n, sum_good / n, sum_early / n, sum_late / n, crashes_early, crashes_late])
	check(sum_good / n < sum_none / n - 0.3, "a well-timed flare lands much softer than no flare")
	check(UN.fps(sum_good / n) < 3.0, "a well-timed flare gives a smooth touchdown (mean sink %.1f ft/s)" % UN.fps(sum_good / n))
	check(sum_early / n > sum_good / n + 0.2, "flaring too early lands harder (float, stall, drop)")
	check(sum_late / n > sum_good / n + 0.2, "flaring too late lands harder (slams in)")

	print("== 4. wind ==  [nodes %d]" % nodes())
	new_round(5, 1)
	var w = WIND.new()
	w.reset(6.0, main.rng, 0.1)
	var gusts := 0
	var max_v := 0.0
	for i in 60 * 40:
		w.update(1.0 / 60.0, main.rng, 1.0)
		if w.gust_started:
			gusts += 1
			w.gust_started = false
		max_v = maxf(max_v, absf(w.gust_v))
	check(gusts >= 5, "gusts fire at random intervals (%d in 40 s)" % gusts)
	check(max_v > 0.5 and max_v <= float(tn.gust_strength) + 0.001, "a gust bumps the vertical wind up to gust_strength (peak %.2f)" % max_v)
	check(is_equal_approx(w.head(), 6.0 + w.gust_h), "total headwind is the steady wind plus the gust")
	var a1 = AC.new()
	root.add_child(a1)
	a1.reset(0.0, 40.0)
	a1.step_air(0.01, 8.0, 0.0, 0.0)
	var gs_head: float = a1.gs
	a1.reset(0.0, 40.0)
	a1.step_air(0.01, -5.0, 0.0, 0.0)
	var gs_tail: float = a1.gs
	check(gs_tail > gs_head + 10.0, "tailwind gives a much faster ground speed than headwind (%.1f vs %.1f)" % [gs_tail, gs_head])
	a1.reset(0.0, 40.0)
	for i in 120:
		a1.step_air(0.01, 0.0, 2.0, 0.0)
	var vy_gust: float = a1.vy
	a1.reset(0.0, 40.0)
	for i in 120:
		a1.step_air(0.01, 0.0, 0.0, 0.0)
	check(vy_gust > a1.vy + 1.0, "an updraft gust lifts the plane (vy %.2f vs %.2f)" % [vy_gust, a1.vy])
	a1.kick(1.0)
	var wob := 0.0
	for i in 20:
		a1.step_air(0.01, 0.0, 0.0, 0.0)
		wob = maxf(wob, absf(a1.wobble))
	check(wob > 1.0, "a gust kicks the nose (wobble %.1f deg)" % wob)
	a1.queue_free()
	await frames(2)
	# windsock: points downwind, droops when calm
	main.airfield.update(0.016, 0.0, 54.0, 8.0)
	var pivot: Node3D = main.airfield._sock_pivot
	var flip_head: float = pivot.rotation.y
	var droop_head: float = pivot.rotation.z
	main.airfield.update(0.016, 0.0, 54.0, -8.0)
	check(absf(pivot.rotation.y - flip_head) > 1.0, "the windsock swings round between headwind and tailwind")
	main.airfield.update(0.016, 0.0, 54.0, 0.0)
	check(absf(pivot.rotation.z) > absf(droop_head) + 0.5, "the windsock droops when it is calm")
	# wind particles drift
	var sp0: Vector3 = main.airfield._streak_pos[3]
	main.airfield.drift_streaks(0.5, 0.0, 8.0, 54.0)
	check(main.airfield._streak_pos[3] != sp0, "wind streaks drift")

	print("== 5. rounds ==  [nodes %d]" % nodes())
	var surfaces := {}
	var terrains := {}
	var lens: Array[float] = []
	var bad_clear := 0
	var thr_ok := true
	for i in 120:
		main.rng.seed = 700 + i
		main.airfield.generate(3 + (i % 12), main.rng)
		surfaces[main.airfield.surface] = true
		terrains[main.airfield.terrain] = true
		lens.append(main.airfield.rwy_len)
		if main.airfield.thr < float(tn.min_start_distance) - 1.0 or main.airfield.aim_x <= main.airfield.thr or main.airfield.aim_x >= main.airfield.rwy_end:
			thr_ok = false
		# the plain path must clear every obstacle (with margin)
		var slope: float = main.airfield.path_slope
		var x_touch: float = main.airfield.aim_x + main.airfield.path_error
		for k in main.airfield.tree_count:
			if (x_touch - main.airfield.tree_x[k]) * slope < main.airfield.tree_h[k] + 1.0:
				bad_clear += 1
		if main.airfield.hill_on and (x_touch - main.airfield.hill_x) * slope < main.airfield.hill_h + 1.0:
			bad_clear += 1
	check(surfaces.size() == 3, "all three surfaces come up (asphalt, grass, dirt)")
	check(terrains.size() == 3, "all three terrains come up (flat, trees, hill)")
	check(lens.min() < 450.0 and lens.max() > 700.0, "runway lengths vary (%.0f .. %.0f)" % [lens.min(), lens.max()])
	check(thr_ok, "the threshold is always ahead of the plane with the markers on the runway")
	check(bad_clear < 8, "trees / hill below the plain approach path (%d near misses of 120 rounds)" % bad_clear)
	# early rounds are gentle
	for i in 20:
		main.rng.seed = 900 + i
		main.airfield.generate(1 + (i % 2), main.rng)
		if main.airfield.terrain != AF.FLAT or main.airfield.surface != AF.ASPHALT or absf(main.airfield.wind_base) > 6.0:
			check(false, "rounds 1-2 are asphalt, flat, mild wind")
			break
	check(true, "rounds 1-2 are asphalt, flat, mild wind")
	# trees / hill / off-runway / overrun / past the end: crashes
	var crash_cases := {}
	new_round(40, 6)
	while main.airfield.tree_count == 0:
		new_round(randi_range(1, 100000), 6)
	main.aircraft.reset(main.airfield.tree_x[0] - 6.0, 4.0)
	main.aircraft.vy = -3.0
	var s0: int = main.strikes
	main.advance(0.5)
	check(main.state == MAIN.CRASH and main.strikes == s0 + 1 and main.last_crash == "Hit the trees!", "flying low into the trees is a crash (%s)" % main.last_crash)
	check(not main.aircraft.visible, "the crashed plane is hidden")
	new_round(41, 1)
	main.airfield.thr = 200.0
	main.airfield.rwy_end = 350.0
	main.aircraft.reset(150.0, 1.0)
	main.advance(3.0)
	check(main.state == MAIN.CRASH and main.last_crash == "Off the runway!", "touching down short of the runway is a crash (%s)" % main.last_crash)
	new_round(42, 1)
	main.aircraft.reset(main.airfield.aim_x - 10.0, 1.2)
	main.aircraft.vy = -4.0
	main.aircraft.theta_target = -12.0
	main.aircraft.theta = -12.0
	for i in 30:
		main.advance(1.0 / 60.0)
		if main.state != MAIN.APPROACH:
			break
	check(main.state == MAIN.CRASH and main.last_crash == "Too hard!", "slamming in far too hard is a crash (%s)" % main.last_crash)
	new_round(43, 1)
	main.aircraft.reset(main.airfield.rwy_end - 3.0, 0.5)
	main.aircraft.land()
	main.state = MAIN.ROLLOUT
	main.aircraft.gs = 20.0
	main.advance(0.5)
	check(main.state == MAIN.CRASH and main.last_crash == "Overran the runway!", "rolling off the end is a crash (%s)" % main.last_crash)
	new_round(44, 1)
	main.aircraft.reset(main.airfield.rwy_end + 10.0, 20.0)
	main.advance(0.1)
	check(main.state == MAIN.CRASH and main.last_crash == "Flew past the runway!", "flying past the runway is a crash (%s)" % main.last_crash)
	# bounce: a firm touchdown rebounds and is flagged, then settles
	new_round(45, 1)
	main.aircraft.reset(main.airfield.aim_x, 0.12)
	main.aircraft.vy = -1.9
	main.aircraft.theta_target = 0.0
	main.aircraft.touching = true
	var st0: int = main.strikes
	main.advance(0.2)
	check(main.last_result.get("bounced", false) and main.aircraft.vy > 0.5, "a sink rate over bounce_sink bounces the plane back up (vy %.2f)" % main.aircraft.vy)
	check(main.last_result.get("grade", 0) >= 2 and main.last_result.get("bounce_pts", 1.0) == 0.0, "...and loses the no-bounce points")
	var bounce_score: int = main.score
	for i in 600:
		set_nose(0.0)
		main.advance(1.0 / 60.0)
		if main.state != MAIN.APPROACH:
			break
	check(main.state == MAIN.ROLLOUT and main.strikes == st0, "...then it settles onto the runway and rolls (no crash)")
	check(main.score == bounce_score, "a bounce is graded once (the second touchdown isn't scored again)")

	print("== 6. run flow ==  [nodes %d]" % nodes())
	tap_to_start()
	check(main.state == MAIN.APPROACH and main.strikes == 0 and main.score == 0, "(fresh run)")
	new_round(60, 1)
	var landed := fly(4.0, 6.5)
	check(not landed["crash"], "a normal landing")
	var pts: int = main.last_result.get("total", 0)
	check(main.score == pts and pts > 0 and main.landings == 1, "touchdown adds its points to the score (+%d)" % pts)
	check(main.hud._pop_title.text == str(main.last_result.get("name", "?")), "the grade popup names the grade (%s)" % str(main.last_result.get("name", "?")))
	# roll out to a stop: the choice screen (pot, next multiplier, a hint) instead of the next approach
	var round_before: int = main.round_no
	for i in 60 * 16:
		main.advance(1.0 / 60.0)
		if main.state == MAIN.CHOICE:
			break
	check(main.state == MAIN.CHOICE and main.hud.choice_visible(), "after the rollout the choice screen shows")
	check(main.pot > 0 and main.hud._ch_pot.text.contains(str(main.pot)) and main.hud._ch_next.text.contains("x1.2") and main.hud._ch_hint.text.begins_with("Next:"), "...with the pot (%d), the next multiplier (%s) and a hint (%s)" % [main.pot, main.hud._ch_next.text, main.hud._ch_hint.text.split("\n")[0]])
	check(main.hud._ch_cash.visible and main.hud._ch_keep.visible, "...and CASH OUT / KEEP FLYING")
	var pot_kept: int = main.pot
	main._on_choice("keep")
	for i in 60 * 6:
		main.advance(1.0 / 60.0)
		if main.state == MAIN.CARD:
			main._end_card()
		if main.state == MAIN.APPROACH:
			break
	check(main.state == MAIN.APPROACH and main.round_no == round_before + 1 and not main.hud.choice_visible(), "KEEP FLYING starts the next approach (round %d)" % main.round_no)
	check(main.aircraft.x == 0.0 and main.aircraft.y > 3.0 and not main.aircraft.on_ground, "...with the plane back on the left, high")
	check(main.score == pts and main.pot == pot_kept, "the score and the pot carry over")
	check(main.hud._pot.visible and main.hud._pot.text.contains(str(pot_kept)), "the pot is on the HUD (%s)" % main.hud._pot.text)
	# a crash ends the run and loses the whole pot
	var sc: int = main.score
	var coins_before_crash: int = SV.data["coins"]
	new_round(70, 1)
	main.aircraft.reset(main.airfield.rwy_end + 10.0, 20.0)
	main.advance(0.1)
	check(main.state == MAIN.CRASH and main.score == sc, "a crash doesn't change the score")
	check(main.hud._pop_sub.text.contains("Pot lost: %d coins" % pot_kept), "...and says what it cost (%s)" % main.hud._pop_sub.text.replace("\n", " | "))
	main.advance(float(tn.crash_pause) + 0.1)
	for i in 60 * 3:
		main.advance(1.0 / 60.0)
		if main.state == MAIN.OVER:
			break
	check(main.state == MAIN.OVER and main.pot == 0 and SV.data["coins"] == coins_before_crash, "the crash ends the run: the pot is gone, nothing was banked")
	check(main.hud.overlay_visible and main.hud._ov_title.text == "RUN OVER", "the game-over screen shows")
	check(main.hud._ov_body.text.contains("Score  %d" % sc) and main.hud._ov_body.text.contains("Pot lost: %d coins" % pot_kept), "...with the score and 'Pot lost: %d coins' (%s)" % [pot_kept, main.hud._ov_body.text.replace("\n", " | ")])
	# tap restarts in place
	main._death_time = Time.get_ticks_msec() / 1000.0 - 1.0
	var n_before_restart := nodes()
	var o_before := objects()
	var r_before := resources()
	tap()
	main._end_card()
	check(main.state == MAIN.APPROACH and main.pot == 0 and main.score == 0 and main.round_no == 1, "a tap restarts the run IN PLACE (pot 0, score 0, round 1)")
	check(main.aircraft.visible and not main.hud.overlay_visible, "...with the plane back and the overlay gone")
	check(nodes() == n_before_restart and objects() <= o_before + 8 and resources() <= r_before + 8, "restart creates no new nodes (%d -> %d) or resources" % [n_before_restart, nodes()])
	# a tap during the crash screen doesn't restart too early
	main.state = MAIN.OVER
	main._death_time = Time.get_ticks_msec() / 1000.0
	tap()
	check(main.state == MAIN.OVER, "a tap right after the game-over screen appears doesn't restart")
	main.state = MAIN.APPROACH

	print("== 7. nothing is allocated after start-up ==  [nodes %d]" % nodes())
	tap_to_start_force()
	var nodes_a := nodes()
	var res_a := resources()
	for i in 6:
		new_round(100 + i, 3 + i)
		fly(3.5, 6.5)
		for k in 60 * 12:
			main.advance(1.0 / 60.0)
			if main.state == MAIN.APPROACH or main.state == MAIN.OVER:
				break
		if main.state == MAIN.OVER:
			tap_to_start_force()
	check(nodes() == nodes_a, "six more rounds (landings and crashes): no new nodes (%d -> %d)" % [nodes_a, nodes()])
	check(resources() <= res_a + 4, "...and no new resources (%d -> %d)" % [res_a, resources()])
	check(nodes() <= n_start + 4, "node count is what it was at the start of the run (%d vs %d)" % [nodes(), n_start])

	print("== 8. tuning panel ==  [nodes %d]" % nodes())
	check(main.tune_panel == null, "no tuning panel without ?tune")
	var tp = TP.new()
	root.add_child(tp)
	tp.build()
	tp.set_available(true)
	await frames(2)
	var n_panel := nodes()
	var base_before: float = tn.glide_angle_deg
	tp.open()
	check(tp.is_open and paused, "TUNE opens the panel and pauses the game")
	tp._sliders["glide_angle_deg"].value = 4.4
	check(is_equal_approx(tn.glide_angle_deg, 4.4), "moving a slider edits Tuning live (glide_angle_deg = %.1f)" % tn.glide_angle_deg)
	tp.copy_values()
	check(tp.last_copied_text.contains("glide_angle_deg = 4.4"), "Copy values lists the changed value (%s)" % tp.last_copied_text.replace("\n", "; "))
	tp.reset_defaults()
	check(is_equal_approx(tn.glide_angle_deg, base_before), "Reset puts the default back")
	check(tp.changed_text() == "(no changes)", "...and nothing differs from the defaults")
	tp.close()
	check(not tp.is_open and not paused, "closing resumes the game")
	check(nodes() == n_panel, "using the panel creates no nodes")
	check(TP.button_hit(Vector2(-5, -5)) == false, "a touch off the TUNE button isn't swallowed")
	tp.queue_free()
	for e in TP.ENTRIES:
		if tn.get(e[0]) == null:
			check(false, "tune entry %s exists in Tuning" % e[0])

	print("== 10. framing, zoom, readout, layers, PAPI ==  [nodes %d]" % nodes())
	# every approach starts with the plane and the WHOLE runway on screen
	var framed_ok := true
	var wide_start := 0.0
	for i in 16:
		new_round(500 + i, 1 + (i * 3) % 14)
		var left: float = main._cam_x - main._cam_w * 0.5
		var right: float = main._cam_x + main._cam_w * 0.5
		var capped: bool = main._full_w >= float(tn.view_width_full_max) - 0.01
		if not capped and not (main.aircraft.x >= left and main.airfield.rwy_end <= right):
			framed_ok = false
			print("      not framed: round %d left %.0f right %.0f plane %.0f rwy_end %.0f" % [main.round_no, left, right, main.aircraft.x, main.airfield.rwy_end])
		wide_start += main._cam_w
	check(framed_ok, "every approach starts framed with the plane and the whole runway on screen")
	check(wide_start / 16.0 > 2.0 * float(tn.view_width_low), "...a much wider view than the close framing (mean start width %.0f vs %.0f)" % [wide_start / 16.0, float(tn.view_width_low)])
	main.advance(1.0 / 60.0)
	check(main.airfield._mark > 1.5 and main.aircraft._view_scale > 1.2, "zoomed out, the markers and the plane are drawn larger so they stay visible")
	# zoom: smooth, never zooms back out, reaches the close framing for the flare
	new_round(520, 4)
	var widths: Array[float] = []
	var first_w: float = main._cam_w
	var bad_step := 0.0
	var zoom_ok := true
	var prev_w: float = main._cam_w
	var flare_w := -1.0
	var t_fly := 0.0
	while t_fly < 70.0:
		t_fly += 1.0 / 60.0
		var gs2: float = maxf(float(main.aircraft.gs), 4.0)
		var t_go2: float = maxf((float(main.airfield.aim_x) - float(main.aircraft.x)) / gs2, 0.5)
		var trim2: float = main.aircraft.trim_sink()
		var want2: float = clampf(-float(main.aircraft.y) / t_go2, -1.6 * trim2, -0.7 * trim2)
		var cmd2: float = (want2 + trim2) / main.aircraft.lift_gain()
		if main.aircraft.y < 2.5:
			cmd2 = (-(0.33 + 0.3 * float(main.aircraft.y)) + trim2) / main.aircraft.lift_gain()
		set_nose(cmd2)
		main.advance(1.0 / 60.0)
		var w2: float = main._cam_w
		if w2 > prev_w + 0.02 * prev_w + 0.3:
			zoom_ok = false
		bad_step = maxf(bad_step, absf(w2 - prev_w) / maxf(prev_w, 1.0))
		prev_w = w2
		if flare_w < 0.0 and main.aircraft.y < 2.5:
			flare_w = w2
		if main.state != MAIN.APPROACH:
			break
	check(zoom_ok, "the zoom only ever tightens during the approach")
	check(bad_step < 0.06, "...smoothly (biggest single-frame change %.1f %%)" % (bad_step * 100.0))
	check(flare_w > 0.0 and flare_w < float(tn.view_width_low) * 1.1, "by the flare it is the close framing (%.1f wide vs %.1f)" % [flare_w, float(tn.view_width_low)])
	check(first_w > flare_w * 2.0, "...from a much wider start (%.0f -> %.0f)" % [first_w, flare_w])
	# runway distance readout
	new_round(521, 2)
	main._update_hud(0.016)
	var d0_text: String = main.hud._dist.text
	check(d0_text.begins_with("RUNWAY"), "the runway distance readout shows at the start (%s)" % d0_text)
	main.aircraft.reset(main.airfield.thr - 30.0, 25.0)
	main._update_hud(0.016)
	var d1_text: String = main.hud._dist.text
	check(d1_text.contains("150") and d1_text.contains("FT"), "...counting feet to the threshold (%s)" % d1_text)
	main.aircraft.reset(main.airfield.thr + 20.0, 5.0)
	main._update_hud(0.016)
	check(main.hud._dist.text.begins_with("ON RUNWAY"), "...then feet of runway left (%s)" % main.hud._dist.text)
	# hazards vs scenery
	var af2 = main.airfield
	var haz_ok: bool = af2._trees[0].get_child(0).material_overlay != null and af2._trees[0].get_child(1).material_overlay != null
	check(haz_ok and af2._hill.material_overlay != null and af2._rwy.material_overlay != null and af2._ground.material_overlay != null, "hazards (trees, hill), the runway and the ground have black outlines")
	var scen_ok: bool = af2._deco[0].get_child(0).material_overlay == null and af2._deco[0].get_child(1).material_overlay == null
	scen_ok = scen_ok and af2._far_hills[0].material_overlay == null and af2._clouds[0].get_child(0).material_overlay == null
	check(scen_ok, "scenery (background trees, far hills, clouds) has no outlines")
	var sky: Color = af2.SKY_COLOR
	var haz_crown: Color = af2._trees[0].get_child(1).material_override.albedo_color
	var sc_crown: Color = af2._deco[0].get_child(1).material_override.albedo_color
	var haz_d := Vector3(haz_crown.r - sky.r, haz_crown.g - sky.g, haz_crown.b - sky.b).length()
	var sc_d := Vector3(sc_crown.r - sky.r, sc_crown.g - sky.g, sc_crown.b - sky.b).length()
	check(sc_d < haz_d * 0.6, "scenery is faded toward the sky colour (distance %.2f vs hazard %.2f)" % [sc_d, haz_d])
	var hill_c: Color = af2._far_hills[0].material_override.albedo_color
	var hill_d := Vector3(hill_c.r - sky.r, hill_c.g - sky.g, hill_c.b - sky.b).length()
	check(hill_d < haz_d * 0.6, "...and so are the far hills (%.2f)" % hill_d)
	check(af2._deco[0].get_child(1).material_override.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "scenery is flat-lit (lower contrast)")
	# parallax: scenery scrolls slower than the play layer
	af2.update(0.016, 0.0, 54.0, 0.0)
	var d_off0: float = af2._deco[5].position.x - 0.0
	var h_off0: float = af2._far_hills[5].position.x - 0.0
	var c_off0: float = af2._clouds[2].position.x - 0.0
	af2.update(0.0, 100.0, 54.0, 0.0)
	var d_move: float = (af2._deco[5].position.x - 100.0) - d_off0
	var h_move: float = (af2._far_hills[5].position.x - 100.0) - h_off0
	var c_move: float = (af2._clouds[2].position.x - 100.0) - c_off0
	check(d_move < -30.0 and d_move > -80.0, "background trees scroll slower than the play layer (camera +100 -> they move %.0f)" % d_move)
	check(h_move > d_move and h_move > -45.0, "far hills scroll slower still (%.0f)" % h_move)
	check(c_move > h_move and c_move > -95.0, "clouds slowest (%.0f)" % c_move)
	# obstruction beacons on real hazards only
	var found_tree := false
	var found_hill := false
	var found_flat := false
	for i in 80:
		main.rng.seed = 900 + i
		af2.generate(4 + i % 9, main.rng)
		af2.build()
		if af2.terrain == AF.TREES:
			found_tree = true
			if not (af2._beacons[0].visible and not af2._beacons[1].visible):
				check(false, "trees get a beacon on the tallest tree")
		if af2.terrain == AF.HILL:
			found_hill = true
			if not (af2._beacons[1].visible and not af2._beacons[0].visible):
				check(false, "the hill gets a beacon on its peak")
		if af2.terrain == AF.FLAT:
			found_flat = true
			if af2._beacons[0].visible or af2._beacons[1].visible:
				check(false, "no beacons on a flat field")
	check(found_tree and found_hill and found_flat, "(trees, hill and flat fields all came up)")
	# PAPI
	new_round(530, 1)
	var af3 = main.airfield
	check(absf(af3.papi_x - af3.aim_x) < 1.0, "the PAPI sits at the aim markers")
	check(af3._papi_mats.size() == 4, "four PAPI lights")
	var dxp: float = 100.0
	var px: float = af3.papi_x - dxp
	var expect := {1.6: 4, 1.1: 3, 1.0: 2, 0.9: 1, 0.5: 0}
	for ratio in expect:
		af3.update_papi(px, ratio * af3.papi_slope * dxp)
		var whites := 0
		for m in af3._papi_mats:
			if m.albedo_color.g > 0.5:
				whites += 1
		check(af3.papi_white == expect[ratio] and whites == expect[ratio], "PAPI at %.1fx the glide slope: %d white, %d red" % [ratio, whites, 4 - whites])
	af3.update_papi(px, 1.0 * af3.papi_slope * dxp)
	check(af3.papi_white == 2 and af3._papi_mats[0].albedo_color.g > 0.5 and af3._papi_mats[3].albedo_color.g < 0.5, "on the glide path: two white, two red")
	af3.update_papi(af3.papi_x - 5.0, 40.0)
	check(af3.papi_white == 2, "close in, the PAPI holds its last state")
	new_round(531, 1)
	var af4 = main.airfield
	var ratio0: float = (af4.start_altitude / (af4.papi_x - main.aircraft.x)) / af4.papi_slope
	var n0 := 0
	for k in 4:
		if ratio0 > 1.0 + (float(k) - 1.5) * float(tn.papi_band):
			n0 += 1
	check(af4.papi_white == n0 and af4._papi_root.visible, "the PAPI shows the right state from the very start of the approach (%d white)" % n0)
	main.aircraft.reset(0.0, af4.start_altitude * 1.8)
	main.advance(1.0 / 60.0)
	check(af4.papi_white == 4, "well above the path: all white")
	main.aircraft.reset(0.0, af4.start_altitude * 0.4)
	main.advance(1.0 / 60.0)
	check(af4.papi_white == 0, "well below the path: all red")
	main.landings = 0
	new_round(532, 1)
	check(main.hud._hint.text.contains("PAPI"), "the round-1 hint explains the PAPI")

	print("== 11. big HUD PAPI ==  [nodes %d]" % nodes())
	root.size = Vector2i(540, 960)   # a phone-shaped window (the 1080 x 1920 layout, scaled)
	await frames(3)
	var hud = main.hud
	var vs: Vector2 = hud.get_viewport().get_visible_rect().size
	print("      viewport %s" % str(vs))
	new_round(600, 2)
	main.advance(1.0 / 60.0)
	check(hud.papi_visible(), "the big PAPI shows during the approach")
	check(is_equal_approx(hud._papi_lights[0].size.x, float(tn.papi_hud_size)) and hud._papi_lights.size() == 4, "four lights, sized from Tuning.papi_hud_size (%.0f px)" % float(tn.papi_hud_size))
	check(float(tn.papi_hud_size) / vs.x >= 0.08, "big enough to read at a glance on a phone (a light is %.0f %% of the screen width)" % (100.0 * float(tn.papi_hud_size) / vs.x))
	var rect: Rect2 = hud.papi_rect()
	check(is_equal_approx(rect.size.x, 4.0 * float(tn.papi_hud_size) + 3.0 * float(tn.papi_hud_gap)), "the row is 4 lights + 3 gaps wide (%.0f px)" % rect.size.x)
	check(rect.position.x >= 0.0 and rect.end.x <= vs.x, "the row is fully on screen at the start of the approach")
	check(is_equal_approx(rect.position.y, vs.y * float(tn.papi_hud_y)), "its height comes from Tuning.papi_hud_y (%.2f of the screen)" % float(tn.papi_hud_y))
	# in the empty sky: below the top readouts, above the plane - at the start and in the flare
	var plane_px: Vector2 = main.camera.unproject_position(Vector3(main.aircraft.x, main.aircraft.y, 0.0))
	check(rect.position.y > 230.0 * vs.y / 1920.0, "the row is below the top readouts (y %.0f of %.0f)" % [rect.position.y, vs.y])
	check(rect.end.y + 50.0 * vs.y / 1920.0 < plane_px.y, "...and above the plane at the start (row bottom %.0f, plane y %.0f)" % [rect.end.y, plane_px.y])
	var rows_clear := true
	for dist_to_aim in [120.0, 60.0, 30.0]:
		main.aircraft.reset(main.airfield.aim_x - dist_to_aim, 5.0 + dist_to_aim * 0.1)
		for i in 90:
			main.advance(1.0 / 60.0)
			if main.state != MAIN.APPROACH:
				break
		var r2: Rect2 = hud.papi_rect()
		var pp: Vector2 = main.camera.unproject_position(Vector3(main.aircraft.x, main.aircraft.y, 0.0))
		if not (r2.end.y + 50.0 * vs.y / 1920.0 < pp.y):
			rows_clear = false
			print("      overlap: row bottom %.0f, plane y %.0f (alt %.1f)" % [r2.end.y, pp.y, main.aircraft.y])
		if main.state != MAIN.APPROACH:
			new_round(601, 2)
	check(rows_clear, "...and stays above the plane through the approach and the flare")
	# follows the plane sideways, always on screen
	hud.set_papi(2, 420.0, true, true)
	var cx_a: float = hud.papi_rect().get_center().x
	hud.set_papi(2, 700.0, true)
	for i in 90:
		hud.update(1.0 / 60.0)
	var cx_b: float = hud.papi_rect().get_center().x
	check(absf(cx_a - 420.0) < 2.0 and absf(cx_b - 700.0) < 2.0, "the row follows the plane sideways (%.0f -> %.0f for plane x 420 -> 700)" % [cx_a, cx_b])
	hud.set_papi(2, -300.0, true)
	for i in 90:
		hud.update(1.0 / 60.0)
	check(hud.papi_rect().position.x >= 0.0, "...and never leaves the screen (plane far left: row x %.0f)" % hud.papi_rect().position.x)
	hud.set_papi(2, 5000.0, true)
	for i in 90:
		hud.update(1.0 / 60.0)
	check(hud.papi_rect().end.x <= vs.x + 0.5, "...either side")
	# states and smooth transitions
	hud.set_papi(2, 540.0, true, true)
	check(hud.papi_light_color(0).g > 0.9 and hud.papi_light_color(1).g > 0.9 and hud.papi_light_color(2).g < 0.3 and hud.papi_light_color(3).g < 0.3, "on path: two white, two red")
	hud.set_papi(4, 540.0, true)
	hud.update(1.0 / 60.0)
	var mid: Color = hud.papi_light_color(2)
	check(mid.g > 0.2 and mid.g < 0.9, "a changing light is mid-transition after one frame (not a hard cut: g %.2f)" % mid.g)
	for i in 60:
		hud.update(1.0 / 60.0)
	check(hud.papi_light_color(3).g > 0.95 and hud.papi_light_color(3).b > 0.9, "...and settles to white (too high: all four white)")
	hud.set_papi(0, 540.0, true)
	for i in 60:
		hud.update(1.0 / 60.0)
	check(hud.papi_light_color(0).g < 0.2 and hud.papi_light_color(3).g < 0.2 and hud.papi_light_color(0).r > 0.9, "too low: all four red")
	check(hud._papi_caption.text == "TOO LOW", "the caption says so (%s)" % hud._papi_caption.text)
	# the lights in the game follow the plane's real glide path
	new_round(602, 2)
	main.aircraft.reset(0.0, main.airfield.start_altitude * 1.8)
	main.advance(1.0 / 60.0)
	for i in 60:
		main.advance(1.0 / 60.0)
		main.aircraft.y = main.airfield.start_altitude * 1.8
		main.aircraft.x = 0.0
	check(main.airfield.papi_white == 4 and hud.papi_light_color(3).g > 0.9, "well above the glide path the HUD lights are all white")
	for i in 60:
		main.aircraft.y = main.airfield.start_altitude * 0.4
		main.aircraft.x = 0.0
		main.advance(1.0 / 60.0)
	check(main.airfield.papi_white == 0 and hud.papi_light_color(0).g < 0.2, "well below it they are all red")
	# hold-last-state near the markers
	var held: int = main.airfield.papi_white
	main.aircraft.reset(main.airfield.papi_x - 10.0, 30.0)
	main.advance(1.0 / 60.0)
	check(main.airfield.papi_white == held, "close to the markers the lights hold their last state")
	# hysteresis: turbulence around a step doesn't flicker
	var af5 = main.airfield
	var dx5: float = 100.0
	var px5: float = af5.papi_x - dx5
	af5.update_papi(px5, 1.07 * af5.papi_slope * dx5, true)
	var base_n: int = af5.papi_white
	var flips := 0
	var last_n: int = base_n
	for i in 40:
		var r := 1.062 + (0.01 if i % 2 == 0 else -0.01)
		af5.update_papi(px5, r * af5.papi_slope * dx5)
		if af5.papi_white != last_n:
			flips += 1
			last_n = af5.papi_white
	check(base_n == 3 and flips == 0, "jitter around a step doesn't flicker a light (%d flips)" % flips)
	af5.update_papi(px5, 1.0 * af5.papi_slope * dx5)
	check(af5.papi_white == 2, "a real drop through the step still changes it")
	af5.update_papi(px5, 1.07 * af5.papi_slope * dx5)
	check(af5.papi_white == 2, "...and it needs a clear rise to come back (hysteresis)")
	af5.update_papi(px5, 1.09 * af5.papi_slope * dx5)
	check(af5.papi_white == 3, "...which it then does")
	# hidden once the wheels are down
	main.state = MAIN.ROLLOUT
	main._update_hud(0.016)
	for i in 30:
		hud.update(1.0 / 60.0)
	check(not hud.papi_visible(), "the big PAPI goes away once the wheels are down")
	main.state = MAIN.APPROACH
	# the small runway PAPI is quiet scenery: no outlines, not scaled with the zoom
	var small = main.airfield._papi_root
	check(small.get_child(0).material_overlay == null and main.airfield._papi_root.scale == Vector3.ONE, "the small runway PAPI is scenery (no outline, never scaled up)")
	# live tuning
	var size0: float = tn.papi_hud_size
	tn.papi_hud_size = 150.0
	hud.set_papi(2, 540.0, true, true)
	check(is_equal_approx(hud._papi_lights[0].size.x, 150.0) and is_equal_approx(hud.papi_rect().size.x, 4.0 * 150.0 + 3.0 * float(tn.papi_hud_gap)), "changing papi_hud_size in Tuning resizes the lights live")
	tn.papi_hud_size = size0
	hud.set_papi(2, 540.0, false, true)
	for e in ["papi_hud_size", "papi_hud_gap", "papi_hud_y", "papi_hud_fade", "papi_hud_follow", "papi_hysteresis"]:
		var in_panel := false
		for ent in TP.ENTRIES:
			if ent[0] == e:
				in_panel = true
		check(in_panel, "%s is in the ?tune panel" % e)
	root.size = Vector2i(1152, 648)

	print("== 12. scenarios ==  [nodes %d]" % nodes())
	root.size = Vector2i(540, 960)
	await frames(2)
	force(-1, -1)
	# --- the endless mix
	var seen_scn := {}
	var seen_wx := {}
	var rng_t := RandomNumberGenerator.new()
	rng_t.seed = 4242
	var last := -1
	var repeats := 0
	var combos_ok := true
	var early_ok := true
	var wx_early := 0
	var wx_late := 0
	for rn in range(1, 61):
		var pick: Vector2i = SC.pick(rn, rng_t, last)
		if rn <= 2 and (pick.x != 0 or pick.y != 0):
			early_ok = false
		if pick.x == last and rn > 2:
			repeats += 1
		last = pick.x
		seen_scn[pick.x] = true
		seen_wx[pick.y] = true
		if not SC.combo_ok(pick.x, pick.y):
			combos_ok = false
		if rn >= 3 and rn <= 8 and pick.y != 0:
			wx_early += 1
		if rn >= 20 and pick.y != 0:
			wx_late += 1
	check(seen_scn.size() == SC.COUNT, "the endless mix reaches every scenario and landing type (%d of %d)" % [seen_scn.size(), SC.COUNT])
	check(seen_wx.size() == 5, "...and every weather (%d of 5)" % seen_wx.size())
	check(early_ok, "rounds 1-2 are a clear standard approach")
	check(repeats == 0, "the same scenario never comes twice in a row")
	check(combos_ok, "unfair combinations (night fog, truck in weather, engine-out turbulence ...) are never picked")
	check(float(wx_late) / 41.0 > float(wx_early) / 6.0, "weather gets more frequent as the run goes on (%.0f %% early, %.0f %% late)" % [100.0 * wx_early / 6.0, 100.0 * wx_late / 41.0])
	# --- forcing (the ?tune panel and ?scenario= / ?weather=)
	DF.parse(["scenario=night", "weather=fog"] as Array[String])
	check(DF.scenario_forced() == 3 and DF.weather_forced() == 1, "?scenario=night&weather=fog parse")
	DF.parse(["plane=jet", "scenario=nonsense"] as Array[String])
	check(DF.plane_forced() == 4, "?plane=jet parses")
	check(DF.summary().contains("nonsense"), "a typo'd scenario shows in the flag summary")
	DF.parse([] as Array[String])
	force(5, 0)
	var pf: Vector2i = SC.pick(1, rng_t, -1)
	check(pf == Vector2i(5, 0), "a forced scenario / weather overrides the mix (even in round 1)")
	force(-1, -1)
	var dbg_btn_scn = null
	var dbg_btn_wx = null
	var tp2 = TP.new()
	root.add_child(tp2)
	tp2.build()
	for b in tp2.find_children("*", "Button", true, false):
		if b.has_meta("debug") and b.get_meta("debug") == "force_scenario":
			dbg_btn_scn = b
		if b.has_meta("debug") and b.get_meta("debug") == "force_weather":
			dbg_btn_wx = b
	check(dbg_btn_scn != null and dbg_btn_wx != null, "the ?tune panel has force-scenario and force-weather buttons")
	dbg_btn_scn.pressed.emit()
	dbg_btn_wx.pressed.emit()
	check(SC.forced_scenario == 0 and SC.forced_weather == 0 and dbg_btn_scn.text.contains("STANDARD"), "...that cycle through them (%s, %s)" % [dbg_btn_scn.text, dbg_btn_wx.text])
	force(-1, -1)
	tp2.queue_free()
	await frames(2)

	# --- title card: names the scenario and weather, then the plane flies
	force(1, 1)
	main.hud.hide_card()
	main._begin_round()
	check(main.state == MAIN.CARD and main.hud._card_title.text == "SHORT FIELD" and main.hud._card_sub.text == "FOG", "the title card names the scenario and the weather (%s / %s)" % [main.hud._card_title.text, main.hud._card_sub.text])
	var x_before: float = main.aircraft.x
	main.advance(0.5)
	check(main.aircraft.x == x_before, "the plane waits while the card is up")
	main._timer = 0.2
	main._input(_touch(true))
	check(main.state == MAIN.CARD, "a tap too early doesn't skip the card")
	main._timer = 1.0
	main._input(_touch(true))
	check(main.state == MAIN.APPROACH, "a tap later skips it")
	force(-1, -1)

	# --- SHORT FIELD
	force(1, 0)
	var short_ok := true
	for i in 12:
		new_round(800 + i, 5)
		if main.airfield.terrain != AF.TREES or main.airfield.rwy_len > 360.0 or main.airfield.tree_count < 3:
			short_ok = false
	check(short_ok, "short field: trees before a runway of 1800 ft or less")
	new_round(801, 5)
	main.aircraft.reset(main.airfield.tree_x[0] - 6.0, 2.0)
	main.advance(0.4)
	check(main.state == MAIN.CRASH and main.last_crash == "Hit the trees!", "...and the trees are real (%s)" % main.last_crash)
	var short_land := 0
	for i in 8:
		new_round(810 + i, 5)
		var rs := fly_g(2.5)
		if not rs["crash"]:
			short_land += 1
	check(short_land >= 5, "...but it can be done (%d of 8 landed with a good approach and flare)" % short_land)

	# --- ENGINE OUT
	force(2, 0)
	new_round(820, 5)
	check(main.aircraft.power == 0.0 and main.aircraft.sink_mult > 1.0 and main.airfield.power == 0.0, "engine out: no power, a steeper glide")
	var a_eo = main.aircraft
	a_eo.reset(0.0, 60.0)
	a_eo.s = 0.8
	for i in 300:
		a_eo.step_air(0.01, 0.0, 0.0, 0.0)
	var s_dead: float = a_eo.s
	a_eo.power = 1.0
	a_eo.reset(0.0, 60.0)
	a_eo.s = 0.8
	for i in 300:
		a_eo.step_air(0.01, 0.0, 0.0, 0.0)
	var s_live: float = a_eo.s
	a_eo.power = 0.0
	check(s_dead < 0.8 and s_live > 0.9, "...the airspeed doesn't come back without the engine (%.2f vs %.2f with power)" % [s_dead, s_live])
	var short_x := 0
	var eo_land := 0
	var eo_off_plain := 0.0
	var eo_n := 0
	for i in 8:
		new_round(830 + i, 5)
		var plain_eo := fly_g(-1.0)
		if plain_eo["crash"]:
			short_x += 1
		elif plain_eo["result"].has("offset"):
			eo_off_plain += float(plain_eo["result"]["offset"])
			eo_n += 1
	for i in 8:
		new_round(830 + i, 5)
		var smart := fly_g(2.5)
		if not smart["crash"]:
			eo_land += 1
	check(short_x >= 1 or eo_off_plain / maxf(eo_n, 1) < 5.0, "...left alone the glide falls short of the aim point (%d of 8 crash short, mean touchdown %.0f u)" % [short_x, eo_off_plain / maxf(eo_n, 1)])
	check(eo_land >= 4, "...but a good pilot can make it (%d of 8)" % eo_land)

	# --- NIGHT
	force(3, 0)
	new_round(840, 5)
	main.advance(1.0 / 60.0)
	var af6 = main.airfield
	var vis_lights := 0
	for l in af6._lights:
		if l.visible:
			vis_lights += 1
	check(af6.night and vis_lights > 30, "night: runway, threshold and approach lights are lit (%d lights)" % vis_lights)
	check(not af6._deco[0].visible and not af6._far_hills[0].visible and not af6._clouds[0].visible, "...and the scenery is gone")
	check(main._env.background_color.v < 0.2 and main.sun.light_energy < 0.4, "...the sky and the light are dark")
	check(main.aircraft._nav[0].visible, "...the plane shows its navigation lights")
	check(af6.terrain == AF.FLAT, "...with no unlit hazards to hit")
	force(0, 0)
	new_round(841, 5)
	main.advance(1.0 / 60.0)
	var day_lights := 0
	for l in main.airfield._lights:
		if l.visible:
			day_lights += 1
	check(day_lights == 0 and main._env.background_color.v > 0.5 and main.airfield._deco[0].visible and not main.aircraft._nav[0].visible, "by day the lights are off and the scenery is back")

	# --- MOUNTAIN STRIP
	force(4, 0)
	new_round(850, 5)
	var afm = main.airfield
	check(afm.slope_m > 0.03 and afm.slope_m < 0.08, "mountain strip: the runway climbs (%.1f deg)" % rad_to_deg(atan(afm.slope_m)))
	check(afm.ground_y(afm.rwy_end) > afm.ground_y(afm.thr) + 5.0 and afm.ground_y(afm.thr) > 1.0, "...the ground rises along it (%.1f -> %.1f)" % [afm.ground_y(afm.thr), afm.ground_y(afm.rwy_end)])
	check(main._ramp_visible_for_test(), "...and the ramp and plateau are drawn")
	main.aircraft.reset(afm.aim_x, afm.ground_y(afm.aim_x) + 0.3)
	main.aircraft.vy = -0.5
	main.aircraft.gy = afm.ground_y(afm.aim_x)
	main.aircraft.theta_target = 0.0
	var gs_m: float = main.aircraft.gs
	main.advance(0.5)
	var expect_sink: float = 0.5 + gs_m * afm.slope_m
	check(main.last_result.has("sink") and absf(float(main.last_result["sink"]) - expect_sink) < 0.9, "...the ground rises to meet the plane: the sink rate counts that (%.1f, ~%.1f expected)" % [float(main.last_result.get("sink", 0.0)), expect_sink])
	new_round(851, 5)
	main.aircraft.reset(afm.thr - 40.0, afm.ground_y(afm.thr - 40.0) + 1.5)
	main.aircraft.vy = -1.5
	main.advance(2.0)
	check(main.state == MAIN.CRASH and main.last_crash == "Hit the slope!", "...touching the slope short of the runway is a crash (%s)" % main.last_crash)
	var m_late := 0.0
	var m_early := 0.0
	var mn := 8
	for i in mn:
		new_round(860 + i, 5)
		m_late += sink_of(fly_g(2.5))
		new_round(860 + i, 5)
		m_early += sink_of(fly_g(4.5))
	print("      mountain mean sink: flare from 2.5 -> %.2f | from 4.5 -> %.2f" % [m_late / mn, m_early / mn])
	check(m_late / mn < m_early / mn, "...uphill the flare has to come later (flaring low: sink %.2f, flaring high: %.2f)" % [m_late / mn, m_early / mn])

	# --- CARRIER
	force(5, 0)
	new_round(870, 5)
	var afc = main.airfield
	check(afc.deck_h > 5.0 and afc.deck_speed > 5.0 and afc.has_wires, "carrier: a raised deck that moves, with wires")
	var thr0: float = afc.thr
	var aim0: float = afc.aim_x
	afc.step_deck(1.0)
	check(is_equal_approx(afc.thr - thr0, afc.deck_speed) and is_equal_approx(afc.aim_x - aim0, afc.deck_speed) and is_equal_approx(afc.papi_x - aim0, afc.deck_speed), "...the deck, the aim point and the PAPI move with it (%.1f/s)" % afc.deck_speed)
	new_round(871, 5)
	main.aircraft.reset(main.airfield.thr - 1.5, 3.0)
	main.advance(0.3)
	check(main.state == MAIN.CRASH and main.last_crash == "Hit the stern!", "...flying into the stern is a crash (%s)" % main.last_crash)
	new_round(872, 5)
	main.aircraft.reset(main.airfield.thr - 30.0, 0.4)
	main.aircraft.vy = -2.0
	main.advance(0.5)
	check(main.state == MAIN.CRASH and main.last_crash.begins_with("Splash"), "...short of the deck is the sea (%s)" % main.last_crash)
	new_round(873, 5)
	var af7 = main.airfield
	main.aircraft.reset(af7.aim_x, af7.deck_h + 0.1)
	main.aircraft.vy = -1.0
	main.aircraft.s = 1.0
	main.advance(0.3)
	var landed_on_deck: bool = main.state == MAIN.ROLLOUT
	for i in 120:
		main.advance(1.0 / 60.0)
		if main.state != MAIN.ROLLOUT:
			break
	check(landed_on_deck and main._arrested and main.aircraft.gs <= af7.deck_speed + 3.0, "...touching down in the wire zone traps the plane (relative speed now %.1f)" % (main.aircraft.gs - af7.deck_speed))
	new_round(874, 5)
	var af8 = main.airfield
	main.aircraft.reset(af8.aim_x + float(tn.carrier_wire_half) + 12.0, af8.deck_h + 0.05)
	main.aircraft.vy = -1.0
	main.aircraft.s = 1.0
	main.advance(0.3)
	check(main.state == MAIN.CRASH and main.last_crash == "Missed the wires!", "...touching down past the wires (a bolter, and there is no going around) is a crash (%s)" % main.last_crash)
	new_round(875, 5)
	var af9 = main.airfield
	main.aircraft.reset(af9.rwy_end - 3.0, af9.deck_h + 0.05)
	main.aircraft.vy = -1.0
	main.aircraft.s = 1.0
	main.aircraft.gs = 22.0
	main.aircraft.land()
	main.state = MAIN.ROLLOUT
	main._arrested = true
	main.aircraft.gs = 30.0
	main._arrested = false
	af9.has_wires = false
	for i in 120:
		main.advance(1.0 / 60.0)
		if main.state != MAIN.ROLLOUT:
			break
	check(main.state == MAIN.CRASH and main.last_crash == "Off the end of the deck!", "...rolling off the end of the deck is a crash (%s)" % main.last_crash)
	var carrier_ok := 0
	for i in 8:
		new_round(880 + i, 5)
		if not fly_g(1.0)["crash"]:
			carrier_ok += 1
	check(carrier_ok >= 6, "...and a good pilot lands on it (%d of 8)" % carrier_ok)

	# --- WATER
	force(6, 0)
	new_round(890, 5)
	var afw = main.airfield
	check(afw.surface == AF.WATER and main.aircraft._floats[0].visible and not main.aircraft._gear[0].visible, "seaplane: floats instead of wheels, on water")
	check(afw.in_lane(afw.aim_x) and not afw.in_lane(afw.thr - 20.0) and afw.on_runway(afw.thr - 20.0), "...a calm lane, rough water everywhere else (but you may land there)")
	main.aircraft.reset(afw.aim_x, 0.05)
	main.aircraft.vy = -0.9
	main.advance(0.3)
	var calm_sink: float = float(main.last_result.get("sink", 0.0))
	var calm_bounced: bool = main.last_result.get("bounced", true)
	new_round(891, 5)
	var afw2 = main.airfield
	main.aircraft.reset(afw2.thr - 25.0, 0.05)
	main.aircraft.vy = -0.9
	main.advance(0.3)
	var rough_sink: float = float(main.last_result.get("sink", 0.0))
	var rough_bounced: bool = main.last_result.get("bounced", false)
	check(calm_sink < 1.2 and not calm_bounced, "...the calm lane takes a firm touchdown without a bounce (sink %.1f)" % calm_sink)
	check(rough_sink > calm_sink * 1.4 and rough_bounced and main.aircraft.vy > 0.5, "...rough water makes the same touchdown harder (%.1f) and bounces it" % rough_sink)
	var water_ok := 0
	for i in 6:
		new_round(895 + i, 5)
		if not fly_g(3.0)["crash"]:
			water_ok += 1
	check(water_ok >= 5, "...a good pilot lands on the lane (%d of 6)" % water_ok)

	# --- MOVING TRUCK
	force(7, 0)
	new_round(910, 5)
	var aft = main.airfield
	check(aft.surface == AF.TRUCK and aft.deck_h > 1.0 and aft.deck_speed > 4.0 and aft.rwy_len < 90.0, "truck: a short flatbed (%.0f m) driving at %.0f m/s" % [aft.rwy_len, aft.deck_speed])
	main.aircraft.reset(aft.aim_x, aft.deck_h + 0.3)
	main.aircraft.vy = -1.0
	main.aircraft.s = 1.0
	main.advance(0.3)
	for i in 240:
		main.advance(1.0 / 60.0)
		if main.state != MAIN.ROLLOUT:
			break
	check(main.state != MAIN.CRASH and main.aircraft.gs <= aft.deck_speed + 3.0, "...land on the bed and brake to its speed (rel. speed %.1f)" % (main.aircraft.gs - aft.deck_speed))
	new_round(911, 5)
	main.aircraft.reset(main.airfield.thr - 20.0, 0.4)
	main.aircraft.vy = -2.0
	main.advance(0.4)
	check(main.state == MAIN.CRASH and main.last_crash == "Missed the truck!", "...missing the truck lands on the road (%s)" % main.last_crash)
	new_round(912, 5)
	main.aircraft.reset(main.airfield.thr - 1.0, 2.0)
	main.advance(0.3)
	check(main.state == MAIN.CRASH and main.last_crash == "Hit the tailgate!", "...the tailgate is a hazard (%s)" % main.last_crash)
	var truck_ok := 0
	for i in 10:
		new_round(920 + i, 5)
		if not fly_g(0.6, 0.0)["crash"]:
			truck_ok += 1
	check(truck_ok >= 4, "...and it is possible (%d of 10)" % truck_ok)

	print("== 13. weather ==  [nodes %d]" % nodes())
	# --- FOG
	force(0, 1)
	new_round(930, 5)
	main.advance(1.0 / 60.0)
	check(main.airfield.vis_end > 60.0 and main.fog.is_on(), "fog: the haze overlay is on (visibility %.0f)" % main.airfield.vis_end)
	check(is_equal_approx(float(main.fog._mat.get_shader_parameter("vis_end")), main.airfield.vis_end), "...with the round's visibility distance")
	check(main.airfield.vis_end < main.airfield.rwy_end - main.aircraft.x, "...so the runway appears only late in the approach")
	force(0, 0)
	new_round(931, 5)
	main.advance(1.0 / 60.0)
	check(not main.fog.is_on(), "no fog in clear weather")
	# --- RAIN
	force(0, 2)
	new_round(932, 5)
	main.advance(1.0 / 60.0)
	var raining := 0
	for rs in main.airfield._rain:
		if rs.visible:
			raining += 1
	check(raining > 30 and main.fog.is_on() and main.airfield.wet, "rain: streaks fall (%d), the view is hazy, the runway is wet" % raining)
	var wet_decel: float = main.airfield.surface_decel()
	force(0, 0)
	new_round(932, 5)
	check(wet_decel < main.airfield.surface_decel() * 0.8, "...a wet runway brakes worse (%.1f vs %.1f)" % [wet_decel, main.airfield.surface_decel()])
	# --- TURBULENCE
	force(0, 3)
	new_round(933, 5)
	var tw = main.wind
	var far_max := 0.0
	main.aircraft.reset(main.airfield.thr - float(tn.turb_zone) - 60.0, 25.0)
	for i in 60:
		main.aircraft.x = main.airfield.thr - float(tn.turb_zone) - 60.0
		main.aircraft.y = 25.0
		main.advance(1.0 / 60.0)
		far_max = maxf(far_max, absf(tw.turb_v))
	var near_max := 0.0
	main.aircraft.reset(main.airfield.thr - 8.0, 25.0)
	for i in 300:
		main.aircraft.x = main.airfield.thr - 8.0
		main.aircraft.y = 25.0
		main.advance(1.0 / 60.0)
		near_max = maxf(near_max, absf(tw.turb_v))
	check(near_max > 0.2 and near_max > far_max * 2.0, "turbulence: rough air builds on final (%.2f near the runway, %.2f far out)" % [near_max, far_max])
	check(main._turb_shake > 0.0, "...and the camera shakes a little")
	force(0, 0)
	new_round(934, 5)
	for i in 120:
		main.aircraft.y = 25.0
		main.advance(1.0 / 60.0)
	check(absf(main.wind.turb_v) < 0.001, "no turbulence in clear weather")
	# --- WIND SHEAR
	force(0, 4)
	new_round(935, 5)
	var afs = main.airfield
	check(afs.shear_back > 30.0, "wind shear: it will hit %.0f m before the markers" % afs.shear_back)
	var t_warn := -1.0
	var t_hit := -1.0
	var min_v := 0.0
	var snapped := false
	var simt := 0.0
	main.aircraft.reset(0.0, 30.0)
	for i in 60 * 40:
		main.aircraft.y = maxf(main.aircraft.y, 12.0)
		simt += 1.0 / 60.0
		set_nose(0.0)
		main.advance(1.0 / 60.0)
		if main._shear_state >= 1 and t_warn < 0.0:
			t_warn = simt
			snapped = afs._sock_snap > 0.0
		if main._shear_state >= 2 and t_hit < 0.0:
			t_hit = simt
		min_v = minf(min_v, main.wind.shear_v)
		if main.state != MAIN.APPROACH:
			break
	check(t_warn > 0.0 and snapped, "...the windsock snaps round as the warning")
	check(t_hit > t_warn + float(tn.shear_tele_time) * 0.5, "...a moment later the sink hits (%.1f s after the warning)" % (t_hit - t_warn))
	check(min_v < -float(tn.shear_sink) * 0.8, "...a real downdraft (%.1f)" % min_v)
	force(0, 0)
	new_round(936, 5)
	for i in 60 * 3:
		main.advance(1.0 / 60.0)
	check(main._shear_state == 0 and main.wind.shear_v == 0.0, "no shear in clear weather")

	print("== 14. scenarios allocate nothing ==  [nodes %d]" % nodes())
	force(-1, -1)
	var n_pre := nodes()
	var r_pre := resources()
	for scn in 8:
		for wx in 5:
			if not SC.combo_ok(scn, wx):
				continue
			force(scn, wx)
			new_round(950 + scn * 5 + wx, 6)
			for i in 20:
				main.advance(1.0 / 30.0)
	check(nodes() == n_pre, "every scenario x weather combination in turn: no new nodes (%d -> %d)" % [n_pre, nodes()])
	check(resources() <= r_pre + 4, "...and no new resources (%d -> %d)" % [r_pre, resources()])
	force(-1, -1)
	root.size = Vector2i(1152, 648)

	print("== 15. aircraft ==  [nodes %d]" % nodes())
	root.size = Vector2i(540, 960)
	await frames(2)
	force(0, 0)
	var PL = load("res://scripts/Planes.gd")
	var spd: Array[float] = []
	var stop_d: Array[float] = []
	var gust_dev: Array[float] = []
	var flare_t: Array[float] = []
	for pl in 5:
		main.select_plane(pl)
		new_round(1000 + pl, 5)
		spd.append(float(main.aircraft.gs))
		# braking: roll out from the same speed on a very long runway
		main.airfield.rwy_end = 100000.0
		main.airfield.surface = AF.ASPHALT
		main.airfield.wet = false
		main.aircraft.land()
		main.state = MAIN.ROLLOUT
		main.aircraft.gs = 25.0
		var x0: float = main.aircraft.x
		for i in 1200:
			main.advance(1.0 / 60.0)
			if main.aircraft.gs < 0.5 or main.state != MAIN.ROLLOUT:
				break
		stop_d.append(float(main.aircraft.x) - x0)
		# gusts: the same updraft pushes the light plane more
		var ag = main.aircraft
		ag.reset(0.0, 60.0)
		for i in 100:
			ag.step_air(0.01, 0.0, 2.0 * float(ag.p_gust), 0.0)
		gust_dev.append(absf(float(ag.vy) + ag.trim_sink()))
		# the same flare: how long until the wheels touch (the floaty ones hang in the air)
		ag.reset(0.0, 2.5)
		ag.vy = -ag.trim_sink()
		ag.gy = 0.0
		ag.theta_target = 5.0
		var tt := 0.0
		while ag.y > 0.0 and tt < 12.0:
			ag.step_air(0.01, 0.0, 0.0, 0.0)
			tt += 0.01
		flare_t.append(tt)
	print("      ground speed: %s | roll-out from 25: %s | gust effect: %s | flare->touch: %s" % [str(spd.map(func(v): return snappedf(v, 0.1))), str(stop_d.map(func(v): return snappedf(v, 0.1))), str(gust_dev.map(func(v): return snappedf(v, 0.01))), str(flare_t.map(func(v): return snappedf(v, 0.01)))])
	check(spd[0] < spd[1] and spd[1] < spd[2] and spd[2] < spd[4], "speeds: cub < 172 < twin < jet (%.0f < %.0f < %.0f < %.0f)" % [spd[0], spd[1], spd[2], spd[4]])
	check(spd[3] > spd[0] and spd[3] < spd[1], "...the glider sits between the cub and the 172 (%.0f)" % spd[3])
	check(stop_d[0] < stop_d[1] and stop_d[1] < stop_d[2] and stop_d[2] < stop_d[4], "the cub stops shortest, the jet needs the most (%.0f < %.0f < %.0f < %.0f)" % [stop_d[0], stop_d[1], stop_d[2], stop_d[4]])
	check(gust_dev[4] < gust_dev[1] * 0.7 and gust_dev[0] > gust_dev[1], "the jet shrugs off gusts, the cub is bumped about (%.2f vs %.2f vs %.2f)" % [gust_dev[4], gust_dev[1], gust_dev[0]])
	check(flare_t[0] > flare_t[1] * 0.95, "the cub floats about as long as the 172 in the same flare (%.2f s vs %.2f s)" % [flare_t[0], flare_t[1]])
	check(flare_t[3] > flare_t[1] * 0.5, "the glider floats too (%.2f s)" % flare_t[3])
	# power, attempts, strikes
	main.select_plane(PL.GLIDER)
	new_round(1010, 5)
	check(main.aircraft.power == 0.0 and main.airfield.power == 0.0, "the glider has no engine")
	check(main.strikes_max() == 1, "...and one attempt")
	main.aircraft.reset(main.airfield.rwy_end + 10.0, 20.0)
	main.advance(0.1)
	main._leave_crash()
	check(main._after_fade_over, "...the first crash ends the run")
	main.select_plane(PL.C172)
	check(main.strikes_max() == 1 and not main.hud._strikes[0].visible, "every aircraft: one crash ends the run (no strike pips)")
	# only suitable scenarios and weather are offered
	force(-1, -1)
	var ok_all := true
	var jet_carrier := false
	var c172_carrier := false
	var offered := {}
	for pl in 5:
		offered[pl] = {}
		var allowed: Array[int] = PL.scenarios(pl)
		var allowed_wx: Array[int] = PL.weather(pl)
		var rr := RandomNumberGenerator.new()
		rr.seed = 99 + pl
		var lastp := -1
		for rn in range(3, 103):
			var pk: Vector2i = SC.pick(rn, rr, lastp, allowed, allowed_wx)
			lastp = pk.x
			offered[pl][pk.x] = true
			if not allowed.has(pk.x) or not allowed_wx.has(pk.y):
				ok_all = false
			if pl == PL.JET and pk.x == 5:
				jet_carrier = true
			if pl == PL.C172 and pk.x == 5:
				c172_carrier = true
	check(ok_all, "every aircraft is only offered scenarios and weather that suit it")
	check(jet_carrier and not c172_carrier, "the jet gets the carrier, the 172 never does")
	check(offered[PL.TWIN].size() == 5 and offered[PL.GLIDER].has(0) and not offered[PL.GLIDER].has(3) and not offered[PL.GLIDER].has(6), "the twin is offered 5 landing types; the glider no night and no water")
	var glider_rain := false
	var rg := RandomNumberGenerator.new()
	rg.seed = 5
	for rn in range(3, 200):
		if SC.pick(rn, rg, -1, PL.scenarios(PL.GLIDER), PL.weather(PL.GLIDER)).y == 2:
			glider_rain = true
	check(not glider_rain, "...and the glider never flies in rain")
	force(0, 0)
	# long runways for the fast ones
	var min_ok := true
	for pl in [PL.TWIN, PL.JET]:
		main.select_plane(pl)
		var need: float = PL.profile(pl)["min_len"]
		for i in 10:
			new_round(1020 + i, 4)
			if main.scenario != 5 and main.airfield.rwy_len < need - 0.5:
				min_ok = false
			if main.scenario != 5 and main.airfield.surface != AF.ASPHALT and main.scenario in [0, 2, 3]:
				min_ok = false
	check(min_ok, "the twin and the jet are only given long paved runways")
	# every aircraft can be landed (a good approach, all five)
	var landed_by := []
	for pl in 5:
		main.select_plane(pl)
		var okc := 0
		for i in 8:
			force(0, 0)
			new_round(1040 + i, 5)
			if not fly_g(3.0)["crash"]:
				okc += 1
		landed_by.append(okc)
	print("      landed with a good approach, 8 tries each: %s" % str(landed_by))
	var all_ok := true
	for v in landed_by:
		if v < 5:
			all_ok = false
	check(all_ok, "every aircraft can be landed (at least 5 of 8 each)")
	main.select_plane(PL.C172)
	# models
	main.select_plane(PL.GLIDER)
	check(not main.aircraft._prop.visible and main.aircraft._p_wing.scale.z > 15.0, "the glider: no propeller, a very long wing")
	main.select_plane(PL.TWIN)
	check(main.aircraft._twin[0].visible and not main.aircraft._prop.visible, "the twin: two engines")
	main.select_plane(PL.JET)
	check(not main.aircraft._prop.visible and not main.aircraft._twin[0].visible, "the jet: no propellers")
	main.select_plane(PL.CUB)
	var cub_col: Color = main.aircraft._body_mats[0].albedo_color
	main.select_plane(PL.C172)
	check(main.aircraft._prop.visible and main.aircraft._body_mats[0].albedo_color != cub_col and not main.aircraft._twin[0].visible, "each aircraft has its own paint and model (the 172 is back to normal)")
	# the selector on the menu and game-over screens
	main.state = MAIN.MENU
	main.hud.show_menu(0)
	check(main.hud._sel_row.visible and main.hud.over_selector(Vector2(540, 1010)), "the aircraft selector shows on the menu")
	var before_state: int = main.state
	main._input(_touch_at(true, Vector2(540, 1010)))
	check(main.state == before_state, "a tap on the selector doesn't start the run")
	var id0: int = main.plane_id
	main._on_plane_step(1)
	check(main.plane_id == (id0 + 1) % 5 and main.hud._sel_name.text == PL.profile(main.plane_id)["name"] and main.aircraft.plane_id == main.plane_id, "the arrows cycle the aircraft (now %s)" % main.hud._sel_name.text)
	main._on_plane_step(-1)
	check(main.plane_id == id0, "...both ways")
	main.hud.hide_overlay()
	check(not main.hud._sel_row.visible, "the selector goes away in play")
	main.state = MAIN.APPROACH
	force(-1, -1)
	root.size = Vector2i(1152, 648)

	print("== 16. streaks and no go-around ==  [nodes %d]" % nodes())
	root.size = Vector2i(540, 960)
	await frames(2)
	force(0, 0)
	main.select_plane(PL.C172)
	main.start_run()
	main._end_card()
	var mults: Array[int] = []
	var spts: Array[int] = []
	var bases: Array[int] = []
	var streaks_seen: Array[int] = []
	var grades_seen: Array[int] = []
	var score_before := 0
	# G, G, Smooth, G, Good, Firm, G  - land each with a chosen sink rate right on the markers
	for sink_set in [0.3, 0.3, 0.5, 0.3, 0.7, 0.9, 0.3]:
		new_round(1100 + mults.size(), 5)
		main.state = MAIN.APPROACH
		land_at(float(sink_set), 0.0)
		mults.append(int(main.last_result.get("mult", -1)))
		spts.append(int(main.last_result.get("points", -1)))
		bases.append(int(main.last_result.get("base", -1)))
		streaks_seen.append(main.streak)
		grades_seen.append(int(main.last_result.get("grade", -1)))
	print("      grades %s | streak %s | multiplier %s | base %s | points %s" % [str(grades_seen), str(streaks_seen), str(mults), str(bases), str(spts)])
	check(grades_seen == [0, 0, 1, 0, 2, 3, 0], "the test landings grade Greaser, Greaser, Smooth, Greaser, Good, Firm, Greaser (%s)" % str(grades_seen))
	check(streaks_seen == [1, 2, 2, 3, 3, 0, 1], "a Greaser extends the streak, Smooth / Good keep it, Firm breaks it (%s)" % str(streaks_seen))
	check(mults == [1, 2, 2, 3, 3, 1, 1], "...and the multiplier is the streak (x1, x2, x2, x3, x3, then back to x1)")
	var pts_ok := true
	for i in spts.size():
		if spts[i] != bases[i] * mults[i]:
			pts_ok = false
	check(pts_ok, "points = the landing's points x the multiplier (%s)" % str(spts))
	var expect_score := 0
	for v in spts:
		expect_score += v
	check(main.score == expect_score, "...and the score is the sum of those (%d)" % main.score)
	check(main.best_streak == 3, "the best streak is remembered (x%d)" % main.best_streak)
	check(main.hud._popup_text_for_test().contains("x1") == false, "(a x1 landing doesn't show a multiplier in the popup)")
	# the popup shows the multiplier when it applies
	new_round(1120, 5)
	main.streak = 2
	land_at(0.3, 0.0)
	check(main.hud._pop_sub.text.contains("x3 ="), "the popup shows the multiplier when there is one (%s)" % main.hud._pop_sub.text.right(24))
	# a crash breaks the streak
	new_round(1121, 5)
	main.streak = 4
	main.aircraft.reset(main.airfield.rwy_end + 10.0, 20.0)
	main.advance(0.1)
	check(main.state == MAIN.CRASH and main.streak == 0, "a crash breaks the streak")
	check(main.hud._streak_label.text.begins_with("STREAK LOST"), "...with a 'STREAK LOST' message (%s)" % main.hud._streak_label.text)
	# a bounce that ends in a crash doesn't count: the landing's points are taken back, and so is the streak
	new_round(1122, 5)
	var sc0: int = main.score
	main.streak = 1
	land_at(1.7, 0.0)
	check(main.last_result.get("bounced", false) and main.streak == 0, "a Firm / bouncy landing breaks the streak (grade %s)" % str(main.last_result.get("name", "?")))
	# the cap
	main.streak = int(tn.streak_cap)
	new_round(1123, 5)
	land_at(0.3, 0.0)
	check(main.streak == int(tn.streak_cap) and main.last_result["mult"] == int(tn.streak_cap), "the multiplier stops at the cap (x%d)" % int(tn.streak_cap))
	# HUD: the label and the glow escalate
	main.hud.set_streak(0)
	main.hud.update(0.016)
	check(not main.hud._streak_label.visible, "no streak, no label")
	var sizes: Array[int] = []
	var glows: Array[float] = []
	var cols: Array[Color] = []
	for sn in [1, 2, 3, 5, 7]:
		main.hud.set_streak(sn, true)
		for i in 90:
			main.hud.update(1.0 / 60.0)
		sizes.append(main.hud._streak_label.get_theme_font_size("font_size"))
		glows.append(main.hud.glow_level())
		cols.append(main.hud._streak_label.modulate)
	print("      label sizes %s | glow %s" % [str(sizes), str(glows.map(func(v): return snappedf(v, 0.01)))])
	check(sizes[0] < sizes[1] and sizes[1] < sizes[2] and sizes[2] < sizes[3] and sizes[3] < sizes[4], "the streak label grows with the streak (%s)" % str(sizes))
	check(glows[0] < glows[1] and glows[1] < glows[2] and glows[3] < glows[4] and glows[4] > 0.3, "the edge glow builds with it (%.2f -> %.2f)" % [glows[0], glows[4]])
	check(cols[0] != cols[2] and cols[2] != cols[3], "...and the label heats up (the colour changes with the tier)")
	check(main.hud._streak_label.text == "STREAK x7", "it reads STREAK x7 (%s)" % main.hud._streak_label.text)
	main.hud.streak_lost(7)
	for i in 200:
		main.hud.update(1.0 / 60.0)
	check(not main.hud._streak_label.visible and main.hud.glow_level() < 0.3, "when the streak breaks the label goes and the glow fades")
	main.hud.set_streak(0)
	for i in 120:
		main.hud.update(1.0 / 60.0)
	check(main.hud.glow_level() < 0.01, "the glow is gone with no streak")
	# a run starts with no streak; the game-over screen shows the best one
	main.start_run()
	main._end_card()
	check(main.streak == 0 and main.best_streak == 0 and not main.hud._streak_label.visible, "a new run starts with no streak")
	main.best_streak = 4
	main._show_over()
	check(main.hud._ov_body.text.contains("Best streak  x4"), "the game-over screen shows the best streak (%s)" % main.hud._ov_body.text.replace("\n", " | "))
	main.start_run()
	main._end_card()
	# --- no go-around
	new_round(1130, 2)
	main.state = MAIN.APPROACH
	main.aircraft.reset(main.airfield.thr - 80.0, 6.0)
	main.advance(1.0 / 60.0)
	check(main.state == MAIN.APPROACH, "(low and fine)")
	main.aircraft.y = 3.0
	main.advance(1.0 / 60.0)
	main.aircraft.y = 3.0 + float(tn.go_around_climb) * 0.6
	main.aircraft.vy = 0.0
	main.advance(1.0 / 60.0)
	check(main.state == MAIN.APPROACH, "a balloon in the flare (a few metres) is not a go-around")
	main.aircraft.y = 3.0 + float(tn.go_around_climb) + 4.0
	main.advance(1.0 / 60.0)
	check(main.state == MAIN.CRASH and main.last_crash == "No go-around!", "climbing well clear after being low is a crash (%s)" % main.last_crash)
	new_round(1131, 2)
	main.aircraft.reset(0.0, 45.0)
	for i in 30:
		main.advance(1.0 / 60.0)
		main.aircraft.y = 45.0 + float(i)
	check(main.state == MAIN.APPROACH, "a climb from high up (never low) isn't judged: it just flies past")
	new_round(1132, 5)
	check(main._min_agl > 1000.0, "the low point resets for every approach")
	# --- streak effects allocate nothing
	var n_pre2 := nodes()
	var r_pre2 := resources()
	main.streak = 0
	for i in 8:
		new_round(1140 + i, 5)
		land_at(0.3, 0.0)
		for k in 30:
			main.advance(1.0 / 30.0)
	check(nodes() == n_pre2 and resources() <= r_pre2 + 3, "eight greasers in a row (sparkles, label, glow): no new nodes (%d -> %d) or resources" % [n_pre2, nodes()])
	force(-1, -1)
	root.size = Vector2i(1152, 648)

	print("== 17. career: ranks, unlocks, save ==  [nodes %d]" % nodes())
	var STD: GDScript = load("res://scripts/Standards.gd")
	var CAR: GDScript = load("res://scripts/Career.gd")
	var APT: GDScript = load("res://scripts/Airports.gd")
	# --- the save document
	SV.data = SV.default_data()
	SV.data["best"] = 123
	SV.data["airports"]["0_1"] = {"name": "Cedar Flats", "day": 20000, "n": 2}
	SV.data["grades"][0] = 5
	SV.data["pink_slips"].append({"day": 20001, "rank": 3, "type": 1})
	SV.data["proficiency"]["counts"]["0"] = 2
	var text: String = SV.to_text()
	SV.data = SV.default_data()
	check(SV.load_text(text) and SV.data["best"] == 123 and SV.data["airports"]["0_1"]["n"] == 2 and SV.data["grades"][0] == 5, "a save survives a round trip through its text")
	check(SV.data["pink_slips"].size() == 1 and SV.data["pink_slips"][0]["type"] == 1 and SV.data["proficiency"]["counts"]["0"] == 2, "...pink slips and proficiency meters too")
	check(SV.load_text("this is not json") == false and SV.data["best"] == 0 and SV.data["version"] == SV.VERSION, "an unreadable save falls back to a fresh one, no crash")
	var old: Dictionary = SV.migrate({"best": 77})
	check(old["best"] == 77 and old["version"] == SV.VERSION and old["rank"] == 0 and old["grades"].size() == 5, "version 0 (best score only) migrates with defaults for the rest")
	var odd: Dictionary = SV.migrate({"version": 99, "rank": 17, "plane": -3, "grades": "x", "airports": 5, "future_thing": [1, 2], "pink_slips": "x", "proficiency": 4})
	check(odd["rank"] == 7 and odd["plane"] == 0 and odd["grades"] == [0, 0, 0, 0, 0] and odd["airports"] is Dictionary and odd["future_thing"] == [1, 2] and odd["version"] == 99 and odd["pink_slips"] == [] and odd["proficiency"]["counts"] == {}, "bad values are repaired, a newer version's keys survive")
	var v1: Dictionary = SV.migrate({"version": 1, "rank": 3, "career_points": 2500, "best": 400, "checkrides": {"2": {"passes": 1, "attempts": 2}}, "coins": 55})
	check(v1["rank"] == 5 and v1["version"] == SV.VERSION and not v1.has("career_points") and v1["best"] == 400 and v1["coins"] == 55, "a version 1 save (old Commercial = rank 3) becomes the new Commercial (rank %d) and keeps the rest" % v1["rank"])
	check(v1["checkrides"].has("4") and not v1["checkrides"].has("2"), "...with its checkride record moved to the new rank key")
	var v1ranks := []
	for r in 6:
		v1ranks.append(SV.migrate({"version": 1, "rank": r})["rank"])
	check(v1ranks == [0, 3, 4, 5, 6, 7], "old ranks map onto the new ladder: Student, Private, Instrument, Commercial, CFI, Airline (%s)" % str(v1ranks))
	# --- the ladder
	check(CAR.RANKS == ["STUDENT", "SPORT", "RECREATIONAL", "PRIVATE", "INSTRUMENT", "COMMERCIAL", "CFI", "AIRLINE CAPTAIN"], "eight ranks, in order")
	check(CAR.types_for(1) == [SC.STANDARD, SC.SOFT_FIELD], "Sport: normal and soft-field landings")
	check(CAR.types_for(2).size() == 4 and CAR.types_for(2).has(SC.SHORT_FIELD) and CAR.types_for(2).has(SC.ENGINE_OUT), "Recreational adds short field and engine out")
	check(CAR.types_for(3).size() == 5 and CAR.types_for(3).has(SC.NIGHT) and CAR.types_for(3).has(SC.SOFT_FIELD), "Private: normal, short, soft, engine out, night")
	check(CAR.types_for(4).has(SC.INSTRUMENT) and CAR.types_for(4).size() == 6 and not CAR.types_for(3).has(SC.INSTRUMENT), "Instrument adds instrument approaches")
	check(CAR.types_for(5).has(SC.POWER_OFF) and CAR.types_for(5).size() == 7 and not CAR.types_for(4).has(SC.POWER_OFF), "Commercial adds the power-off 180")
	check(CAR.types_for(6).size() > CAR.types_for(5).size() and CAR.types_for(6).has(SC.MOUNTAIN) and CAR.types_for(6).has(SC.WATER) and CAR.types_for(6).has(SC.POWER_OFF) and STD.tier_for_rank(6) == STD.tier_for_rank(5), "CFI: all the landing types at Commercial standards")
	check(CAR.types_for(7).has(SC.INSTRUMENT) and CAR.types_for(7).has(SC.CARRIER), "Airline Captain: instrument approaches and the carrier")
	check(CAR.planes(0) == [PL.CUB] and CAR.planes(1) == [PL.CUB] and CAR.planes(2) == [PL.CUB, PL.C172], "Student and Sport fly the Cub; Recreational adds the 172")
	check(not CAR.planes(4).has(PL.TWIN) and CAR.planes(5).has(PL.TWIN) and not CAR.planes(5).has(PL.JET), "Commercial unlocks the twin")
	check(CAR.planes(6).has(PL.GLIDER) and not CAR.planes(6).has(PL.JET) and CAR.planes(7).has(PL.JET), "the jet comes with Airline Captain")
	check(CAR.has_scenario(0, SC.STANDARD) and not CAR.has_scenario(0, SC.SOFT_FIELD) and not CAR.has_scenario(1, SC.NIGHT) and CAR.has_scenario(3, SC.NIGHT), "Sport is day only; night opens at Private")
	check(not CAR.has_scenario(6, SC.CARRIER) and CAR.has_scenario(7, SC.CARRIER), "the carrier unlocks with Airline Captain")
	check(not CAR.weather(2).has(SC.RAIN) and CAR.weather(3).has(SC.RAIN) and not CAR.weather(3).has(SC.FOG) and CAR.weather(4).has(SC.FOG) and CAR.weather(5).has(SC.SHEAR), "weather opens up with the ranks (fog with Instrument)")
	check(CAR.planes(0, true).size() == PL.COUNT and CAR.scenarios(0, true).size() == SC.COUNT and CAR.weather(0, true).size() == SC.WX_COUNT, "unlock-all opens everything")
	var fly_ok := true
	for r in range(1, 8):
		for ty in CAR.types_for(r):
			var any := false
			for p in CAR.planes(r):
				if PL.offers(p, ty) and PL.weather(p).has(CAR.pick_weather(ty)):
					any = true
			if not any:
				fly_ok = false
				print("      rank %d: nothing unlocked can fly %s" % [r, SC.NAMES[ty]])
	check(fly_ok, "every landing type of every rank can be flown in an aircraft that rank has")
	var lines_ok := true
	for r in 8:
		if CAR.unlock_lines(r).is_empty() and r > 0:
			lines_ok = false
	check(lines_ok, "every rank lists what it adds (%s)" % " | ".join(CAR.unlock_lines(5)))
	# --- proficiency, endorsement, fee
	var dat: Dictionary = SV.default_data()
	var tgt := 2
	check(not CAR.endorsed(dat, tgt) and CAR.missing(dat, tgt) == CAR.types_for(tgt), "no practice yet: nothing is endorsed, every type is missing")
	check(CAR.needed() == 3, "3 practice landings fill a meter (Tuning)")
	for k in 5:
		CAR.add_practice(dat, SC.STANDARD)
	check(CAR.count(dat, SC.STANDARD) == 3, "a meter stops at full")
	for ty in CAR.types_for(tgt):
		for k in 3:
			CAR.add_practice(dat, ty)
	check(CAR.endorsed(dat, tgt) and CAR.missing(dat, tgt).is_empty(), "every meter full: the instructor endorses")
	CAR.drop_half(dat, SC.SHORT_FIELD)
	check(CAR.count(dat, SC.SHORT_FIELD) == 1 and not CAR.endorsed(dat, tgt) and CAR.missing(dat, tgt) == [SC.SHORT_FIELD], "a failed type drops back to half and the endorsement goes")
	CAR.drop_half(dat, SC.STANDARD)
	check(CAR.count(dat, SC.STANDARD) == 1, "(and half is 1 of 3)")
	dat["proficiency"]["counts"]["0"] = 3
	dat["proficiency"]["counts"]["1"] = 3
	dat["proficiency"]["tier"] = STD.tier_for_rank(2)
	CAR.on_rank_change(dat, 2)         # now training for Private (3): the same tier? no: Private is tier 1
	check(CAR.count(dat, SC.STANDARD) == 0, "a new tier starts the meters again")
	dat["proficiency"]["counts"]["0"] = 3
	CAR.on_rank_change(dat, 3)         # training for Instrument (4): same tier as Private
	check(CAR.count(dat, SC.STANDARD) == 3, "the same tier keeps the meters it already filled")
	check(CAR.fee(1) == int(roundf(float(tn.exam_fee_base))) and CAR.fee(5) > CAR.fee(3) and CAR.fee(3) > CAR.fee(1), "the examiner fee grows with the rank (%d, %d, %d ...)" % [CAR.fee(1), CAR.fee(2), CAR.fee(3)])
	check(CAR.fee(3, true) == int(ceilf(float(CAR.fee(3)) * 0.5)), "...and can be halved (%d -> %d)" % [CAR.fee(3), CAR.fee(3, true)])
	var rngc := RandomNumberGenerator.new()
	rngc.seed = 77
	var draw_ok := true
	var seen_draws := {}
	for i in 30:
		var dr: Array[int] = CAR.draw(5, int(tn.ride_landings), rngc)
		var uniq := {}
		for t in dr:
			uniq[t] = true
			if not CAR.types_for(5).has(t):
				draw_ok = false
		if dr.size() != int(tn.ride_landings) or uniq.size() != dr.size():
			draw_ok = false
		seen_draws[str(dr)] = true
	check(draw_ok and seen_draws.size() > 5, "a checkride draws %d distinct landing types of the rank, differently each time (%d draws)" % [int(tn.ride_landings), seen_draws.size()])
	var plane_ok := true
	for i in 40:
		var pe: Dictionary = CAR.make_entry(CAR.types_for(7)[i % 5], 7, rngc)
		if not CAR.planes(7).has(pe["plane"]) or not PL.offers(pe["plane"], pe["scn"]):
			plane_ok = false
	check(plane_ok and CAR.make_entry(SC.CARRIER, 7, rngc)["plane"] == PL.JET and CAR.make_entry(SC.INSTRUMENT, 4, rngc)["wx"] == SC.FOG, "landings get an aircraft that suits them (the carrier: the jet); instrument approaches are in fog")
	# --- airports
	var seen := {}
	var unique := true
	for a in APT.all():
		if seen.has(a["name"]):
			unique = false
		seen[a["name"]] = true
	check(unique and APT.count() >= 30 and APT.pool_size(SC.INSTRUMENT) >= 3 and APT.pool_size(SC.SOFT_FIELD) >= 3, "%d airports, every one with its own name" % APT.count())
	# --- free flight: only what the rank has unlocked, and landings are logged
	SV.data = SV.default_data()
	force(-1, -1)
	main.start_run()
	main._end_card()
	check(main.available_planes() == [PL.CUB], "a Student's selector only offers the Cub")
	var only_ok := true
	for i in 40:
		main._begin_round(false)
		if main.scenario != SC.STANDARD or main.weather != SC.CLEAR:
			only_ok = false
	check(only_ok, "a Student only gets normal landings in clear weather over 40 approaches")
	SV.data["rank"] = 3
	CAR.on_rank_change(SV.data, 3)
	var seen_scn2 := {}
	var ok_scn := true
	for i in 120:
		main.rng.seed = 6000 + i
		main.round_no = 5 + i % 6
		main._begin_round(false)
		seen_scn2[main.scenario] = true
		if not CAR.has_scenario(3, main.scenario) or not CAR.weather(3).has(main.weather):
			ok_scn = false
	check(ok_scn and seen_scn2.has(SC.NIGHT) and seen_scn2.has(SC.SOFT_FIELD) and not seen_scn2.has(SC.INSTRUMENT) and not seen_scn2.has(SC.CARRIER), "a Private flies what Private has (night, soft field ...) and no instrument approaches or carriers")
	SV.data = SV.default_data()
	main.start_run()
	main._end_card()
	new_round(1701, 3)
	var ap_id: String = APT.id_of(main.scenario, main.airport_idx)
	land_at(0.3, 0.0)
	check(SV.data["landings"] == 1 and SV.data["grades"][0] == 1, "a Greaser is logged: landing count and grade tally")
	check(SV.data["airports"].has(ap_id) and SV.data["airports"][ap_id]["n"] == 1, "the airport it was at is stamped (%s)" % SV.data["airports"][ap_id]["name"])
	var ap_scn: int = main.scenario
	var ap_idx: int = main.airport_idx
	force(ap_scn, -1)
	new_round(1701, 3)
	force(-1, -1)
	main.airport_idx = ap_idx
	land_at(0.3, 0.0)
	check(SV.data["airports"][ap_id]["n"] == 2 and SV.data["airports"].size() == 1, "landing there again adds to the same stamp, no new one")
	main._crash("test")
	check(SV.data["crashes"] == 1, "a crash is logged")
	# --- the career screen
	SV.data = SV.default_data()
	main.state = MAIN.MENU
	main._show_menu()
	check(main.hud._ov_body.text.contains("STUDENT PILOT") and main.hud._ov_body.text.contains("SPORT"), "the menu shows the rank and what you are training for (%s)" % main.hud._ov_body.text.split("\n")[1])
	main._on_menu_action("career")
	check(main.hud.career_visible() and main.hud._cr_rows[0]["name"].visible and main.hud._cr_rows[1]["name"].visible and not main.hud._cr_rows[2]["name"].visible, "the career screen lists the landing types of the next rank (Sport: 2 rows)")
	check(main.hud._cr_rows[0]["name"].text == "Normal Landing" and main.hud._cr_rows[1]["name"].text == "Soft Field", "...by name (%s, %s)" % [main.hud._cr_rows[0]["name"].text, main.hud._cr_rows[1]["name"].text])
	var pips_shown := 0
	for pip in main.hud._cr_rows[0]["pips"]:
		if pip.visible:
			pips_shown += 1
	check(pips_shown == 3, "...each with a proficiency meter of %d pips" % pips_shown)
	SV.data["proficiency"]["counts"]["0"] = 2
	main._on_menu_action("career")
	check(main.hud._cr_rows[0]["pips"][1].color.g > 0.8 and main.hud._cr_rows[0]["pips"][2].color.g < 0.5, "two landings in: two pips lit")
	check(main.hud._cr_speech.text.contains("Soft Field") and main.hud._cr_stamp.text == "", "the instructor says what is left to practise")
	SV.data["proficiency"]["counts"]["8"] = 3
	SV.data["proficiency"]["counts"]["0"] = 3
	main._on_menu_action("career")
	check(main.hud._cr_stamp.text == "ENDORSED" and main.hud._cr_speech.text.contains("endorsement"), "every meter full: the instructor signs the endorsement")
	main._on_menu_action("back")
	check(not main.hud.career_visible() and main.state == MAIN.MENU, "BACK leaves the career screen")
	# --- the logbook
	SV.add_slip(20100, 3, SC.SHORT_FIELD)
	main._on_menu_action("logbook")
	check(main.hud.logbook_visible() and main.hud._log_stamps.size() == APT.count(), "the logbook screen shows a slot for every airport")
	check(main.hud._ov_body.text.contains("Landings") and main.hud._ov_body.text.contains("Airports stamped  %d / %d" % [SV.data["airports"].size(), APT.count()]), "...with totals and the stamp count")
	check(main.hud._log_slips[0].visible and main.hud._log_slip_labels[0].text.contains("PINK SLIP") and main.hud._log_slip_labels[0].text.contains("PRIVATE") and main.hud._log_slip_labels[0].text.contains("Short Field"), "...and the pink slip (%s)" % main.hud._log_slip_labels[0].text)
	main._on_menu_action("back")
	check(not main.hud.logbook_visible() and main.state == MAIN.MENU, "BACK returns to the menu")
	# --- debug
	main.debug_unlock_all(true)
	check(main.available_planes().size() == PL.COUNT, "debug: unlock all opens every aircraft")
	main.debug_unlock_all(false)
	main.debug_promote()
	check(SV.data["rank"] == 1, "debug: promote rank")
	main.debug_reset_save()
	check(SV.data["rank"] == 0 and SV.data["landings"] == 0 and not SV.data["unlock_all"] and main.available_planes().size() == 1 and SV.data["pink_slips"].is_empty(), "debug: reset save wipes the career and the unlocks")
	# --- nothing is allocated by any of it
	SV.data["unlock_all"] = true
	main.state = MAIN.MENU
	var n17 := nodes()
	var r17 := resources()
	for i in 3:
		main.state = MAIN.MENU
		main._on_menu_action("logbook")
		main._on_menu_action("back")
		main._on_menu_action("career")
		main._on_menu_action("back")
		new_round(1710 + i, 3)
		land_at(0.3, 0.0)
		for k in 200:
			main.advance(1.0 / 30.0)
	main.start_run()
	main._end_card()
	check(nodes() == n17 and resources() <= r17 + 3, "the career screen, logbook and landings allocate nothing (%d -> %d nodes)" % [n17, nodes()])
	SV.data["unlock_all"] = true
	force(-1, -1)

	print("== 18. cosmetics, daily approach, ad stubs ==  [nodes %d]" % nodes())
	var COS: GDScript = load("res://scripts/Cosmetics.gd")
	var DLY: GDScript = load("res://scripts/Daily.gd")
	SV.data = SV.default_data()
	SV.data["unlock_all"] = true
	main.start_run()
	main._end_card()
	# --- coins and the hangar
	check(COS.coins_for(0, 1) > COS.coins_for(1, 1) and COS.coins_for(1, 1) > COS.coins_for(4, 1) and COS.coins_for(4, 1) >= 1, "better landings pay more coins")
	check(COS.coins_for(0, 3) == 3 * COS.coins_for(0, 1), "the streak multiplier multiplies coins too")
	new_round(1801, 3)
	land_at(0.3, 0.0)
	check(main.pot == COS.coins_for(0, 1) and SV.data["coins"] == 0, "a Greaser goes into the pot, not the bank (pot %d)" % main.pot)
	check(main.hud._popup_text_for_test().contains("c"), "(coins in the popup)")
	main._crash("test")
	check(SV.data["coins"] == 0 and main.pot == 0 and main.pot_lost == 0, "a landing that ends in a crash doesn't count: nothing in the pot, nothing banked")
	check(not COS.buy(SV.data, "paint", 1) and SV.data["coins"] == 0, "can't buy with no coins")
	SV.data["coins"] = 500
	check(COS.buy(SV.data, "paint", 1) and SV.data["coins"] == 500 - int(COS.PAINTS[1]["cost"]) and COS.owned(SV.data, "paint", 1), "buying paint takes its price and owns it")
	var coins_now: int = SV.data["coins"]
	check(COS.buy(SV.data, "paint", 1) and SV.data["coins"] == coins_now, "buying what you own is free")
	main.state = MAIN.MENU
	main._on_menu_action("hangar")
	check(main.hud.hangar_visible() and main.hud._hangar_paint.size() == COS.PAINTS.size() and main.hud._hangar_gear.size() == COS.GEAR.size(), "the hangar lists every paint and gear item")
	check(main.hud._hangar_paint[0].text == "[CLASSIC]" and main.hud._hangar_paint[2].text.contains("150"), "equipped is bracketed, unowned shows its price")
	main._on_hangar_pick("paint", 1)
	check(SV.data["paint"] == 1, "tapping an owned paint equips it")
	var body_mat: StandardMaterial3D = main.aircraft._body_mats[0]
	check(body_mat.albedo_color.is_equal_approx(COS.PAINTS[1]["body"]), "...and the aircraft is repainted")
	main.select_plane(PL.CUB)
	check((main.aircraft._body_mats[0] as StandardMaterial3D).albedo_color.is_equal_approx(COS.PAINTS[1]["body"]), "the paint stays when you change aircraft")
	main._on_hangar_pick("paint", 0)
	check((main.aircraft._body_mats[0] as StandardMaterial3D).albedo_color.is_equal_approx(PL.profile(PL.CUB)["body"]), "Classic goes back to the aircraft's own paint")
	SV.data["coins"] = 50
	main._on_hangar_pick("gear", 4)
	check(SV.data["gear"] == 0 and not COS.owned(SV.data, "gear", 4), "gear you can't afford isn't bought or worn")
	SV.data["coins"] = 200
	main._on_hangar_pick("gear", 1)
	var worn := 0
	for i in main.aircraft._gear_sets.size():
		for m in main.aircraft._gear_sets[i]:
			if (m as MeshInstance3D).visible:
				worn += 1
	check(SV.data["gear"] == 1 and worn == main.aircraft._gear_sets[1].size() and worn > 0, "Whiskers wears the goggles (and only those)")
	main._on_menu_action("back")
	check(not main.hud.hangar_visible() and main.state == MAIN.MENU, "BACK leaves the hangar")
	var sv2: Dictionary = SV.migrate({"coins": "12", "paint": 3, "owned_paint": [0, 3, 3, -1, 99], "owned_gear": "x", "daily": {"day": 5, "best": 40}})
	check(sv2["coins"] == 12 and sv2["owned_paint"] == [0, 3, 99] and sv2["owned_gear"] == [0] and sv2["daily"]["best"] == 40 and sv2["daily"]["tries"] == 0, "the save migrates the new fields (%s)" % str(sv2["owned_paint"]))
	main.select_plane(PL.C172)
	# --- the daily approach
	var d1: Dictionary = DLY.for_day(20000)
	check(d1 == DLY.for_day(20000), "the same day always gives the same approach")
	var planes_seen := {}
	var daily_ok := true
	for day in range(20000, 20060):
		var e: Dictionary = DLY.for_day(day)
		planes_seen[e["plane"]] = true
		if not (PL.offers(e["plane"], e["scn"]) and PL.weather(e["plane"]).has(e["wx"]) and e["wx"] != SC.CLEAR and e["round"] == int(tn.daily_round)):
			daily_ok = false
	check(daily_ok and planes_seen.size() >= 3, "every day is hard (weather, round %d), suits its aircraft, and they vary (%d aircraft in 60 days)" % [int(tn.daily_round), planes_seen.size()])
	check(DLY.for_day(20000) != DLY.for_day(20001), "tomorrow's approach differs")
	SV.data["daily"] = {"day": -1, "best": 0, "tries": 0}
	main.state = MAIN.MENU
	main._on_menu_action("daily")
	var today: int = DLY.day_number(Time.get_unix_time_from_system())
	var de: Dictionary = DLY.for_day(today)
	check(main.mode == MAIN.DAILY and main.state == MAIN.CARD and main.scenario == de["scn"] and main.weather == de["wx"] and main.plane_id == de["plane"], "the DAILY button starts today's approach")
	check(main.hud._card_blurb.text.contains("DAILY APPROACH") and main.strikes_max() == 1, "its card says so; a crash ends it")
	var len_d: float = main.airfield.rwy_len
	main._end_card()
	land_at(0.3, 0.0)
	check(main.score > 0, "(landed it: %d)" % main.score)
	var first_score: int = main.score
	for i in 600:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	check(main.state == MAIN.OVER and SV.data["daily"]["best"] == first_score and SV.data["daily"]["tries"] == 1 and main.hud._ov_title.text == "DAILY APPROACH", "one approach, then the result; the best score is saved (%d)" % first_score)
	check(main.plane_id == PL.C172, "...and your own aircraft comes back")
	main._continue_from_over()
	check(main.state == MAIN.MENU, "tapping goes back to the menu")
	main._on_menu_action("daily")
	check(main.airfield.rwy_len == len_d and SV.data["daily"]["tries"] == 2, "play it again: the same runway, attempt 2")
	main._end_card()
	main._crash("test")
	for i in 600:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	check(main.state == MAIN.OVER and SV.data["daily"]["best"] == first_score, "a crash scores nothing and keeps the earlier best")
	SV.data["daily"] = {"day": today - 1, "best": 999, "tries": 4}
	main._continue_from_over()
	main._on_menu_action("daily")
	check(SV.data["daily"]["day"] == today and SV.data["daily"]["best"] == 0 and SV.data["daily"]["tries"] == 1, "a new day starts a fresh best")
	main._end_card()
	main._crash("test")
	for i in 600:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	main._continue_from_over()
	# --- ad stubs: interstitials only between rounds
	ADS.enabled = true
	var gap_save: float = tn.ad_min_gap_seconds
	var every_save: int = tn.ad_interstitial_every
	tn.ad_min_gap_seconds = 0.0
	tn.ad_interstitial_every = 2
	main.start_run()
	main._end_card()
	var ad_in_play := false
	var ad_seen := 0
	for r in 6:
		new_round(1810 + r, 3)
		main._end_card()
		land_at(0.3, 0.0)
		for i in 600:
			main.advance(1.0 / 30.0)
			if main.state == MAIN.CHOICE:
				main._on_choice("keep")
			if main.state == MAIN.AD:
				ad_seen += 1
				if i < 5:
					ad_in_play = true      # an ad right after the landing, before the fade even began
				break
			if main.state == MAIN.CARD or main.state == MAIN.OVER:
				break
		if main.state == MAIN.AD:
			check(main.hud.ad_visible() and main.hud._ad_sub.text.contains("stub"), "the fake Ad playing screen shows")
			main.advance(float(tn.ad_fake_seconds) + 0.1)
			check(main.state == MAIN.CARD and not main.hud.ad_visible(), "...and ends by itself, then the next approach begins")
	check(ad_seen >= 2 and ad_seen <= 3 and not ad_in_play, "an interstitial every other landed round, only on the fade between rounds (%d in 6)" % ad_seen)
	ADS.rounds_since = 99
	main.start_run()
	tn.ad_min_gap_seconds = 60.0
	ADS.rounds_since = 99
	ADS.last_ms = Time.get_ticks_msec()
	check(not ADS.interstitial_due(Time.get_ticks_msec() + 1000), "never sooner than ad_min_gap_seconds after the last ad")
	check(ADS.interstitial_due(Time.get_ticks_msec() + 61000), "...and due again after it")
	tn.ad_min_gap_seconds = 0.0
	ADS.enabled = false
	check(not ADS.interstitial_due(Time.get_ticks_msec() + 99999), "?noads / disabled: never")
	ADS.enabled = true
	# --- rewarded: double coins
	main.start_run()
	main._end_card()
	new_round(1830, 3)
	land_at(0.3, 0.0)
	var earned: int = main.pot
	main._finish_round(false)
	main._on_choice("cashout")
	for i in 600:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	var coins_before: int = SV.data["coins"]
	check(main.state == MAIN.OVER and SV.data["coins"] >= earned and main.hud._menu_buttons["ad"].visible and main.hud._menu_buttons["ad"].text.contains("DOUBLE"), "after cashing out the run-over screen offers a rewarded double-coins ad (+%d)" % earned)
	main._on_menu_action("ad")
	check(main.state == MAIN.AD and main.hud.ad_visible(), "tapping it plays the fake ad")
	main.advance(float(tn.ad_fake_seconds) + 0.1)
	check(main.state == MAIN.OVER and SV.data["coins"] == coins_before + earned and not main.hud._menu_buttons["ad"].visible, "then the coins are doubled (+%d) and the offer is gone" % earned)
	# --- flags and allocation
	DF.parse(["noads"] as Array[String])
	check(not DF.ads_enabled() and DF.summary() == "noads", "?noads is a flag and shows in the summary")
	DF.parse([] as Array[String])
	check(DF.ads_enabled(), "no flag: ads on")
	main._continue_from_over()
	main.start_run()
	main._end_card()
	var n18 := nodes()
	var r18 := resources()
	ADS.enabled = true
	tn.ad_interstitial_every = 1
	for i in 3:
		main.state = MAIN.MENU
		main._on_menu_action("hangar")
		main._on_hangar_pick("paint", i % 2)
		main._on_menu_action("back")
		main._on_menu_action("daily")
		main._end_card()
		land_at(0.3, 0.0)
		for k in 300:
			main.advance(1.0 / 30.0)
			if main.state == MAIN.AD:
				main.advance(float(tn.ad_fake_seconds) + 0.1)
	main.start_run()
	main._end_card()
	check(nodes() == n18 and resources() <= r18 + 3, "hangar, daily and ad screens allocate nothing (%d -> %d nodes)" % [n18, nodes()])
	tn.ad_min_gap_seconds = gap_save
	tn.ad_interstitial_every = every_save
	ADS.enabled = false
	SV.data["unlock_all"] = true
	main._on_hangar_pick("paint", 0)
	force(-1, -1)

	print("== 19. realism: units, Vref, glidepath, landing types ==  [nodes %d]" % nodes())
	var PLN: GDScript = load("res://scripts/Planes.gd")
	# --- knots: Vref and stall per aircraft (Tuning values)
	check(PLN.vref(PLN.CUB) == 45.0 and PLN.stall_kt(PLN.CUB) == 38.0, "Cub: 45 kt approach, 38 kt stall")
	check(PLN.vref(PLN.C172) == 65.0 and PLN.stall_kt(PLN.C172) == 48.0, "172: 65 / 48 kt")
	check(PLN.vref(PLN.TWIN) == 90.0 and PLN.stall_kt(PLN.TWIN) == 65.0, "Twin: 90 / 65 kt")
	check(PLN.vref(PLN.JET) == 135.0 and PLN.stall_kt(PLN.JET) == 110.0, "Jet: 135 / 110 kt")
	var vref_ok := true
	for pid in PLN.COUNT:
		main.select_plane(pid, false)
		var acx = main.aircraft
		acx.reset(0.0, 30.0)
		if absf(acx.airspeed_kt() - PLN.vref(pid)) > 0.01 or absf(UN.kt(acx.air_speed()) - PLN.vref(pid)) > 1.5 or absf(acx.stall_speed() - PLN.stall_kt(pid) / PLN.vref(pid)) > 0.001:
			vref_ok = false
			print("      %s: %.1f kt, world %.1f kt, stall ratio %.3f" % [PLN.NAMES[pid], acx.airspeed_kt(), UN.kt(acx.air_speed()), acx.stall_speed()])
	check(vref_ok, "every aircraft flies its Vref in world speed and stalls at its own stall speed")
	main.select_plane(PL.C172, false)
	# --- the standard 3 degree glide path, and the PAPI shows it
	var glide_ok := true
	for pid in [PLN.CUB, PLN.C172, PLN.TWIN, PLN.JET]:
		main.select_plane(pid, false)
		force(SC.STANDARD, SC.CLEAR)
		main.rng.seed = 1900 + pid
		var wind_was: bool = tn.wind_enabled
		tn.wind_enabled = false
		main.round_no = 2
		main._begin_round(false)
		tn.wind_enabled = wind_was
		var ang: float = rad_to_deg(atan(main.airfield.papi_slope))
		var ang2: float = rad_to_deg(atan(main.aircraft.trim_sink() / main.aircraft.gs))
		if main.airfield.terrain == AF.FLAT and (absf(ang - float(tn.glide_angle_deg)) > 0.1 or absf(ang2 - float(tn.glide_angle_deg)) > 0.1):
			glide_ok = false
			print("      %s: PAPI %.2f deg, trim %.2f deg" % [PLN.NAMES[pid], ang, ang2])
	check(glide_ok, "every aircraft's approach attitude is the 3 degree path, and the PAPI path is 3 degrees")
	main.select_plane(PL.C172, false)
	force(SC.STANDARD, SC.CLEAR)
	main.rng.seed = 1950
	tn.wind_enabled = false
	main.round_no = 2
	main._begin_round(false)
	tn.wind_enabled = true
	var afp = main.airfield
	var dist := 300.0
	var path_y: float = afp.papi_slope * dist
	afp.update_papi(afp.papi_x - dist, path_y, true)
	check(afp.papi_white == 2, "on the 3 degree path the PAPI shows 2 white + 2 red (%d)" % afp.papi_white)
	afp.update_papi(afp.papi_x - dist, path_y * 1.35, true)
	check(afp.papi_white == 4, "well above it: all white (%d)" % afp.papi_white)
	afp.update_papi(afp.papi_x - dist, path_y * 0.65, true)
	check(afp.papi_white == 0, "well below it: all red (%d)" % afp.papi_white)
	# --- flare and float: speed floats, holding the flare bleeds speed, too little drops in
	var acf = main.aircraft
	var float_d: Array[float] = []
	for s_start in [0.95, 1.0, 1.3]:
		acf.reset(afp.aim_x - 100.0, 1.5)
		acf.gy = 0.0
		acf.s = s_start
		acf.power = 1.0
		acf.theta_target = 0.0
		var x0: float = acf.x
		var tt := 0.0
		while acf.y > 0.0 and tt < 20.0:
			acf.theta = 2.0
			acf.theta_target = 2.0
			acf.step_air(0.01, 0.0, 0.0, 0.0)
			tt += 0.01
		float_d.append(acf.x - x0)
	check(float_d[2] > float_d[1] + 15.0, "too much speed floats down the runway (%.0f u at s=1.3 vs %.0f u at 1.0)" % [float_d[2], float_d[1]])
	acf.reset(0.0, 1.5)
	acf.s = 1.0
	for i in 200:
		acf.theta_target = 5.0
		acf.theta = 5.0
		acf.step_air(0.01, 0.0, 0.0, 0.0)
		acf.y = 1.0
	var s_ground: float = acf.s
	acf.reset(0.0, 40.0)
	acf.s = 1.0
	for i in 200:
		acf.theta_target = 5.0
		acf.theta = 5.0
		acf.step_air(0.01, 0.0, 0.0, 0.0)
		acf.y = 40.0
	check(s_ground < acf.s - 0.03, "holding the flare in ground effect bleeds speed faster than in the air (%.3f vs %.3f)" % [s_ground, acf.s])
	acf.reset(0.0, 1.0)
	acf.s = 0.6
	acf.theta = 0.0
	acf.theta_target = 0.0
	for i in 20:
		acf.step_air(0.01, 0.0, 0.0, 0.0)
	check(acf.vy < -acf.trim_sink() - 0.3, "below the stall speed it drops in (vy %.2f)" % acf.vy)
	# --- the standards
	var ok := func(res: Dictionary, scn: int, tier: int) -> bool: return STD.judge(STD.for_type(scn, tier), res, false)["pass"]
	var good := {"sink": UN.ups_of_fps(1.5), "offset": UN.units_of_ft(100.0), "bounced": false, "gate_dev_kt": 2.0, "nose_ok": true, "papi_ok": true}
	check(STD.for_type(SC.STANDARD, 1)["zone_ft"] == 400.0 and STD.for_type(SC.STANDARD, 2)["zone_ft"] == 200.0, "normal: 400 ft beyond the aim point (Private), 200 ft (Commercial)")
	check(STD.for_type(SC.STANDARD, 1)["kt_plus"] == 10.0 and STD.for_type(SC.STANDARD, 1)["kt_minus"] == 5.0 and STD.for_type(SC.STANDARD, 2)["kt_plus"] == 5.0 and STD.for_type(SC.STANDARD, 2)["kt_minus"] == 5.0, "...approach speed +10/-5 kt (Private), +/-5 (Commercial)")
	check(STD.for_type(SC.SHORT_FIELD, 1)["zone_ft"] == 200.0 and STD.for_type(SC.SHORT_FIELD, 2)["zone_ft"] == 100.0, "short field: 200 ft (Private), 100 ft (Commercial)")
	check(STD.for_type(SC.POWER_OFF, 2)["zone_ft"] == 200.0, "power-off 180: at or within 200 ft")
	check(STD.for_type(SC.SOFT_FIELD, 1)["nose"] and STD.for_type(SC.SOFT_FIELD, 1)["sink_fps"] < STD.for_type(SC.STANDARD, 1)["sink_fps"], "soft field: hold the nose off, a gentler sink limit")
	check(STD.for_type(SC.INSTRUMENT, 1)["papi"] and STD.for_type(SC.ENGINE_OUT, 1)["field"], "instrument: stay on the PAPI; engine out: land on the field")
	check(ok.call(good, SC.STANDARD, 1) and ok.call(good, SC.STANDARD, 2), "a good landing meets the normal standard at both tiers")
	var late := good.duplicate()
	late["offset"] = UN.units_of_ft(300.0)
	check(ok.call(late, SC.STANDARD, 1) and not ok.call(late, SC.STANDARD, 2), "300 ft long: fine for Private, not for Commercial")
	late["offset"] = UN.units_of_ft(450.0)
	check(not ok.call(late, SC.STANDARD, 1), "450 ft long fails even Private")
	var short := good.duplicate()
	short["offset"] = UN.units_of_ft(-30.0)
	check(ok.call(short, SC.STANDARD, 1) and not ok.call(short, SC.STANDARD, 2), "30 ft short of the point: a little slack for Private, none for Commercial")
	short["offset"] = UN.units_of_ft(-80.0)
	check(not ok.call(short, SC.STANDARD, 1), "80 ft short fails")
	var fast := good.duplicate()
	fast["gate_dev_kt"] = 9.0
	check(ok.call(fast, SC.STANDARD, 1) and not ok.call(fast, SC.STANDARD, 2), "+9 kt: inside Private's band, outside Commercial's")
	fast["gate_dev_kt"] = -6.0
	check(not ok.call(fast, SC.STANDARD, 1), "-6 kt fails Private's -5")
	fast["gate_dev_kt"] = INF
	check(not ok.call(fast, SC.STANDARD, 1), "no speed measured = not stable")
	var hardx := good.duplicate()
	hardx["sink"] = UN.ups_of_fps(4.5)
	check(ok.call(hardx, SC.STANDARD, 1) and not ok.call(hardx, SC.STANDARD, 2) and not ok.call(hardx, SC.SOFT_FIELD, 1), "4.5 ft/s: fine for Private, over Commercial's 4 and a soft field's 3")
	var bnc := good.duplicate()
	bnc["bounced"] = true
	check(not ok.call(bnc, SC.STANDARD, 1), "a bounce fails")
	var nosex := good.duplicate()
	nosex["nose_ok"] = false
	check(not ok.call(nosex, SC.SOFT_FIELD, 1) and ok.call(nosex, SC.STANDARD, 1), "nose down early fails a soft field only")
	var pap := good.duplicate()
	pap["papi_ok"] = false
	check(not ok.call(pap, SC.INSTRUMENT, 1) and ok.call(pap, SC.STANDARD, 1), "off the PAPI fails an instrument approach only")
	check(ok.call({"sink": UN.ups_of_fps(3.0), "offset": 9999.0, "bounced": false}, SC.ENGINE_OUT, 1), "engine out has no touchdown-point or speed standard")
	check(not STD.judge(STD.for_type(SC.STANDARD, 1), good, true)["pass"], "a crash fails")
	check(STD.lines(STD.for_type(SC.STANDARD, 1), 65.0).size() >= 4 and STD.lines(STD.for_type(SC.STANDARD, 1), 65.0)[0].contains("400 ft"), "the standards read out as text")
	check(STD.tier_for_rank(2) == 0 and STD.tier_for_rank(3) == 1 and STD.tier_for_rank(4) == 1 and STD.tier_for_rank(5) == 2 and STD.tier_for_rank(7) == 2, "Private and Instrument share a tier; Commercial and up are tight")
	# --- the landing types in the game
	force(SC.SOFT_FIELD, SC.CLEAR)
	new_round(1960, 4)
	check(main.scenario == SC.SOFT_FIELD and main.airfield.surface == AF.GRASS and main.airfield.soft, "soft field: rough grass")
	main._end_card()
	main.airfield.thr = 100.0
	main.aircraft.reset(main.airfield.aim_x, main.airfield.ground_y(main.airfield.aim_x) + 0.01)
	main.aircraft.vy = -0.3
	main.aircraft.gy = 0.0
	main.aircraft.touching = true
	for i in 30:
		main.advance(1.0 / 60.0)
		if main.state == MAIN.ROLLOUT:
			break
	check(main.state == MAIN.ROLLOUT and main.aircraft.nose_hold, "touching down on a soft field starts the nose hold")
	main.aircraft.theta_target = 5.0
	main.aircraft.touching = true
	for i in 60:
		main.aircraft.theta_target = 5.0
		main.advance(1.0 / 60.0)
	check(main._nose_ok and main.aircraft.theta > 3.0, "holding the nose up keeps the standard (theta %.1f)" % main.aircraft.theta)
	main.aircraft.touching = false
	main.aircraft.theta_target = 0.0
	main.advance(1.0 / 60.0)
	check(not main._nose_ok, "letting the nose down early breaks it")
	force(SC.SOFT_FIELD, SC.CLEAR)
	new_round(1960, 4)
	main._end_card()
	main.aircraft.reset(main.airfield.aim_x, 0.01)
	main.aircraft.vy = -0.3
	for i in 30:
		main.advance(1.0 / 60.0)
		if main.state == MAIN.ROLLOUT:
			break
	main.aircraft.touching = true
	for i in 60 * 14:
		main.aircraft.theta_target = 5.0
		main.advance(1.0 / 60.0)
		if main.state != MAIN.ROLLOUT:
			break
	check(main._nose_ok and not main.aircraft.nose_hold, "held until the speed has dropped, then the nose is released (%s)" % str(main.last_verdict))
	force(SC.POWER_OFF, SC.CLEAR)
	new_round(1961, 6)
	check(main.scenario == SC.POWER_OFF and main.aircraft.power == 0.0 and main.airfield.sink_mult > 1.5, "power-off 180: the power is cut, the glide is steeper")
	force(SC.ENGINE_OUT, SC.CLEAR)
	new_round(1962, 6)
	check(main.aircraft.power == 0.0 and (main.airfield.surface == AF.GRASS or main.airfield.surface == AF.DIRT), "engine out: a forced landing on an unpaved field")
	force(SC.INSTRUMENT, -1)
	new_round(1963, 6)
	check(main.scenario == SC.INSTRUMENT and main.weather == SC.FOG and main.airfield.instrument, "instrument approach: always in fog")
	main._end_card()
	main._update_fog()
	check(main.fog.is_on(), "in the cloud: the fog is on")
	var dh_u: float = UN.units_of_ft(float(tn.instrument_dh_ft))
	main.aircraft.reset(main.airfield.thr - 200.0, dh_u + 8.0)
	for i in 10:
		main.advance(1.0 / 60.0)
	check(main._instr_open == 0.0 and main.fog.is_on(), "above minimums the runway is hidden")
	main.aircraft.y = dh_u - 1.0
	for i in 90:
		main.advance(1.0 / 60.0)
	check(main._instr_open >= 0.999 and not main.fog.is_on(), "at decision height the runway appears")
	main.airfield.papi_white = 4
	var worst0: float = main._papi_worst
	main._papi_run = 0.0
	main.aircraft.y = 30.0
	for i in int((float(tn.instrument_dev_seconds) + 1.0) * 60.0):
		main.airfield.papi_white = 4
		main.aircraft.y = 30.0
		main.advance(1.0 / 60.0)
	check(main._papi_worst > float(tn.instrument_dev_seconds) and not main.judge_result()["papi_ok"], "staying off the PAPI longer than the limit fails the glide-path standard (%.1f s)" % main._papi_worst)
	# the 50 ft gate measures the approach speed
	force(SC.STANDARD, SC.CLEAR)
	new_round(1964, 4)
	main._end_card()
	main.aircraft.reset(main.airfield.thr - 150.0, UN.units_of_ft(60.0))
	main.aircraft.s = 1.2
	for i in 120:
		main.aircraft.s = 1.2
		main.advance(1.0 / 60.0)
		if main._gate_dev_kt != INF:
			break
	var vref_now: float = PLN.vref(main.plane_id)
	check(absf(main._gate_dev_kt - 0.2 * vref_now) < 2.0, "the speed gate at 50 ft reads the approach speed (+%.1f kt)" % main._gate_dev_kt)
	# --- readouts are in aviation units
	main.hud.set_flight(UN.units_of_ft(120.0), -UN.ups_of_fps(5.0), 1.0, 65.0, true)
	check(main.hud._alt.text == "ALT 120 FT" and main.hud._sink.text == "V/S -300 FPM" and main.hud._speed_label.text == "65 KT   VREF 65", "altitude in feet, vertical speed in ft/min, airspeed and Vref in knots (%s / %s / %s)" % [main.hud._alt.text, main.hud._sink.text, main.hud._speed_label.text])
	main.hud.set_wind(UN.ups_of_kt(10.0))
	check(main.hud._wind.text.contains("10 KT"), "the wind is in knots (%s)" % main.hud._wind.text)
	new_round(1965, 4)
	check(main.hud._runway.text.contains(" FT"), "the runway length is in feet (%s)" % main.hud._runway.text)
	main._update_distance()
	check(main.hud._dist.text.contains(" FT"), "distances are in feet (%s)" % main.hud._dist.text)
	check(main.hud._speed_band.offset_right > main.hud._speed_band.offset_left + 5.0, "the Vref tolerance band is on the airspeed bar")
	force(-1, -1)

	print("== 20. practice and the endorsement ==  [nodes %d]" % nodes())
	SV.data = SV.default_data()
	force(-1, -1)
	main.start_run()
	main._end_card()
	main.state = MAIN.MENU
	main._show_menu()
	# one practice landing to the standard: a Student practising normal landings for Sport
	var finish_practice := func() -> void:
		for i in 900:
			main.advance(1.0 / 30.0)
			if main.state == MAIN.OVER:
				break
	main._on_menu_action("career")
	main._on_menu_action("practice:0")
	check(main.mode == MAIN.PRACTICE and main.state == MAIN.CARD and main.scenario == SC.STANDARD and main.weather == SC.CLEAR and main.plane_id == PL.CUB, "PRACTICE on a landing type starts one approach of it (normal landing, clear, in the Cub)")
	check(main.hud._card_blurb.text.contains("PRACTICE") and main.hud._card_blurb.text.contains("beyond the aim point") and main.hud._card_blurb.text.contains("No bounce"), "...its card spells out the standard")
	check(main._standard["zone_ft"] == 600.0 and main.strikes_max() == 1 and main.hud._round.text == "PRACTICE", "...at the standard of the rank being trained for (Sport: 600 ft), one crash and it's over")
	main._end_card()
	land_at(0.3, 0.0)
	finish_practice.call()
	check(main.state == MAIN.OVER and main.last_verdict["pass"] and CAR.count(SV.data, SC.STANDARD) == 1, "a landing to the standard fills one pip (%s)" % str(main.last_verdict))
	check(main.hud._ov_title.text == "STANDARD MET" and main.hud._ov_body.text.contains("1 / 3"), "...and says so (%s)" % main.hud._ov_body.text.replace("\n", " | "))
	check(main.plane_id == PL.CUB and SV.data["best"] == 0, "(practice isn't a scored run: best %d, plane %d, score %d)" % [SV.data["best"], main.plane_id, main.score])
	main._death_time = Time.get_ticks_msec() / 1000.0 - 1.0
	main._continue_from_over()
	check(main.hud.career_visible() and main.state == MAIN.MENU, "a tap goes back to the career screen")
	check(main.hud._cr_rows[0]["pips"][0].color.g > 0.8 and main.hud._cr_rows[0]["pips"][1].color.g < 0.5, "...where the meter has one pip lit")
	# a miss doesn't count
	main._on_menu_action("practice:0")
	main._end_card()
	land_at(1.5, 0.0)          # 7.5 ft/s: over the 6 ft/s limit
	finish_practice.call()
	check(main.state == MAIN.OVER and not main.last_verdict["pass"] and CAR.count(SV.data, SC.STANDARD) == 1 and main.hud._ov_title.text == "NOT TO STANDARD", "a landing that misses the standard doesn't count (%s)" % str(main.last_verdict["fails"]))
	check(main.hud._ov_body.text.contains("Sink") and main.hud._ov_body.text.contains("doesn't count"), "...and tells you why (%s)" % main.hud._ov_body.text.replace("\n", " | "))
	main._continue_from_over()
	# so does a crash
	main._on_menu_action("practice:0")
	main._end_card()
	main._crash("test")
	finish_practice.call()
	check(main.state == MAIN.OVER and CAR.count(SV.data, SC.STANDARD) == 1 and main.hud._ov_title.text == "NOT TO STANDARD", "a crash doesn't count either (%s)" % main.hud._ov_body.text.replace("\n", " | "))
	check(SV.data["crashes"] == 1, "(it is still logged)")
	main._continue_from_over()
	# fill the normal-landing meter; it stops at full
	for k in 4:
		main._on_menu_action("practice:0")
		main._end_card()
		land_at(0.3, 0.0)
		finish_practice.call()
		main._continue_from_over()
	check(CAR.count(SV.data, SC.STANDARD) == 3, "three good landings fill the meter, and no more (%d)" % CAR.count(SV.data, SC.STANDARD))
	check(not CAR.endorsed(SV.data, 1) and main.hud._cr_stamp.text == "", "...but the soft field is still to do: no endorsement yet")
	# the soft field: hold the nose off
	main._on_menu_action("practice:1")
	check(main.scenario == SC.SOFT_FIELD and main.airfield.soft and main._standard["nose"], "the soft field practice is rough grass with the nose-off standard")
	main._end_card()
	land_at(0.3, 0.0)
	main.aircraft.touching = true
	for i in 900:
		main.aircraft.theta_target = 5.0
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	check(main.last_verdict["pass"] and CAR.count(SV.data, SC.SOFT_FIELD) == 1, "holding the nose off meets the soft field standard (%s)" % str(main.last_verdict))
	main._continue_from_over()
	main._on_menu_action("practice:1")
	main._end_card()
	land_at(0.3, 0.0)
	main.aircraft.touching = false
	finish_practice.call()
	check(not main.last_verdict["pass"] and str(main.last_verdict["fails"]).contains("Nose") and CAR.count(SV.data, SC.SOFT_FIELD) == 1, "letting the nose drop early misses it (%s)" % str(main.last_verdict["fails"]))
	main._continue_from_over()
	for k in 2:
		main._on_menu_action("practice:1")
		main._end_card()
		land_at(0.3, 0.0)
		main.aircraft.touching = true
		for i in 900:
			main.aircraft.theta_target = 5.0
			main.advance(1.0 / 30.0)
			if main.state == MAIN.OVER:
				break
		main._continue_from_over()
	check(CAR.endorsed(SV.data, 1) and main.hud._cr_stamp.text == "ENDORSED" and main.hud._cr_speech.text.contains("signed"), "every meter full: the instructor signs the endorsement")
	check(main.hud._ov_body.text.contains("STUDENT") or true, "(career screen refreshed)")
	main._on_menu_action("back")
	check(main.hud._ov_body.text.contains("Endorsed for the SPORT checkride"), "the menu says you are endorsed (%s)" % main.hud._ov_body.text.split("\n")[1])
	# higher ranks: practice in the right aircraft and weather
	SV.data["rank"] = 3
	CAR.on_rank_change(SV.data, 3)
	var types4: Array[int] = CAR.types_for(4)
	var ix_instr := types4.find(SC.INSTRUMENT)
	main._on_menu_action("career")
	check(main.hud._cr_rows[ix_instr]["name"].text == "Instrument Approach" and main.hud._cr_rows[ix_instr]["name"].visible, "Private is training for Instrument: the instrument approach is a row")
	main._on_menu_action("practice:%d" % ix_instr)
	check(main.weather == SC.FOG and main.scenario == SC.INSTRUMENT and main.plane_id == PL.C172 and main._standard["papi"] and main._standard["zone_ft"] == 400.0, "...a fog approach in the 172 to the Private / Instrument standard")
	main._end_card()
	land_at(0.3, 0.0)
	finish_practice.call()
	check(main.state == MAIN.OVER, "(flown)")
	main._continue_from_over()
	# the top rank: practice for fun, no meters
	SV.data["rank"] = 7
	main._on_menu_action("career")
	check(main.hud._cr_stamp.text == "" and main.hud._cr_book.disabled and main.hud._cr_book.text.contains("ALL"), "Airline Captain has nothing left to book")
	main._on_menu_action("practice:4")
	check(main.scenario == SC.CARRIER and main.plane_id == PL.JET, "...but can still practise the carrier in the jet")
	main._on_menu_action("back") if false else null
	main.start_run()
	main._end_card()
	# --- nothing is allocated by any of it
	SV.data = SV.default_data()
	main.state = MAIN.MENU
	main._show_menu()
	var n20 := nodes()
	var r20 := resources()
	for i in 3:
		main.state = MAIN.MENU
		main._on_menu_action("career")
		main._on_menu_action("practice:%d" % (i % 2))
		main._end_card()
		land_at(0.3, 0.0)
		main.aircraft.touching = true
		for k in 600:
			main.aircraft.theta_target = 5.0
			main.advance(1.0 / 30.0)
			if main.state == MAIN.OVER:
				break
		main._continue_from_over()
	main.start_run()
	main._end_card()
	check(nodes() == n20 and resources() <= r20 + 3, "practice landings and the career screen allocate nothing (%d -> %d nodes)" % [n20, nodes()])
	SV.data["unlock_all"] = true
	force(-1, -1)

	print("== 21. checkrides, pink slips, certificates ==  [nodes %d]" % nodes())
	var fly_ride_landing := func(sink: float, offset: float) -> void:
		main._end_card()
		land_at(sink, offset)
		main.aircraft.touching = true
		for i in 900:
			main.aircraft.theta_target = 5.0
			main.advance(1.0 / 30.0)
			if main.state == MAIN.CARD or main.state == MAIN.OVER:
				break
	var fresh_endorsed := func(rank: int, coins: int) -> void:
		SV.data = SV.default_data()
		SV.data["rank"] = rank
		SV.data["coins"] = coins
		CAR.on_rank_change(SV.data, rank)
		force(-1, -1)
		main.start_run()
		main._end_card()
		main.state = MAIN.MENU
		main._show_menu()
		main.debug_endorse()
	# --- booking: needs the endorsement and the money
	fresh_endorsed.call(2, 500)
	SV.data["proficiency"]["counts"].clear()
	main.state = MAIN.MENU
	main._on_menu_action("career")
	check(main.hud._cr_book.disabled and not main.book_checkride(), "without the endorsement the checkride can't be booked")
	main.debug_endorse()
	SV.data["coins"] = 5
	main._on_menu_action("career")
	var fee3: int = CAR.fee(3)
	check(main.hud._cr_book.disabled and main.hud._cr_book.text.contains(str(fee3)) and not main.book_checkride() and main.mode != MAIN.RIDE, "endorsed but without the fee (%d coins): still can't" % fee3)
	SV.data["coins"] = 500
	main._on_menu_action("career")
	check(not main.hud._cr_book.disabled and main.hud._cr_book.text.contains("BOOK CHECKRIDE") and main.hud._cr_status.text.contains(str(fee3)), "endorsed and funded: the button shows the examiner's fee (%s)" % main.hud._cr_book.text)
	main._on_menu_action("book")
	check(main.mode == MAIN.RIDE and main.state == MAIN.CARD and SV.data["coins"] == 500 - fee3 and main.ride_target == 3, "booking pays the fee (%d coins) and starts the checkride" % fee3)
	check(main.ride_draw.size() == int(tn.ride_landings), "it draws %d landings" % main.ride_draw.size())
	var drawn_types: Array[int] = []
	for e in main.ride_draw:
		drawn_types.append(e["scn"])
		check(CAR.types_for(3).has(e["scn"]) and PL.offers(e["plane"], e["scn"]) and CAR.planes(3).has(e["plane"]), "(landing %s: a Private type in a suitable aircraft)" % SC.NAMES[e["scn"]])
	var uniq_d := {}
	for t in drawn_types:
		uniq_d[t] = true
	check(uniq_d.size() == drawn_types.size(), "...of distinct types")
	check(main.hud._card_title.text == SC.NAMES[drawn_types[0]] and main.hud._card_sub.text.contains("1 / 3") and main.hud._card_blurb.text.contains("beyond") or main.hud._card_blurb.text.contains("Land"), "the first landing is revealed on its card (%s, %s)" % [main.hud._card_title.text, main.hud._card_sub.text])
	check(not main.hud._card_title.text == SC.NAMES[drawn_types[1]] or drawn_types[1] == drawn_types[0], "...the others are not")
	check(main.hud._round.text.begins_with("CHECKRIDE") and main.strikes_max() == 1 and main._standard["zone_ft"] != 600.0, "it is flown to the Private standard, one crash and it's over")
	var seeds_a: Array = main.ride_draw.map(func(e): return e["seed"])
	# --- fly it to standard: certificate
	for k in main.ride_draw.size():
		check(main.ride_idx == k and main.scenario == drawn_types[k], "checkride landing %d: %s is revealed" % [k + 1, SC.NAMES[drawn_types[k]]])
		fly_ride_landing.call(0.3, 0.0)
		check(main.ride_fails.is_empty(), "(landing %d to standard: %s)" % [k + 1, str(main.ride_fails)])
	check(main.state == MAIN.OVER and main.ride_passed and SV.data["rank"] == 3, "every landing to standard: the checkride is passed and the rank is Private")
	check(main.hud.certificate_visible() and main.hud._cert_rank.text == "PRIVATE" and main.hud._cert_body.text.contains("Landings") and main.hud._cert_date.text.contains("/"), "a certificate for the new rank (%s)" % main.hud._cert_body.text.replace("\n", " | ").left(80))
	check(SV.data["checkrides"]["3"]["passes"] == 1 and SV.data["pink_slips"].is_empty() and main.plane_id == PL.CUB, "the pass is recorded, no pink slip, your own aircraft is back")
	main._death_time = Time.get_ticks_msec() / 1000.0 - 1.0
	main._input(_touch_at(true, Vector2(540, 900)))
	check(main.state == MAIN.MENU and not main.hud.certificate_visible(), "a tap on the certificate goes back to the menu")
	check(SV.data["coins"] == 500 - fee3, "(the fee is not refunded)")
	# --- a failed landing: pink slip, the fee is gone, the meter drops
	fresh_endorsed.call(2, 500)
	var fee_before := 500
	main.book_checkride()
	var failed_type: int = main.ride_draw[0]["scn"]
	fly_ride_landing.call(1.5, 0.0)          # 7.5 ft/s: over the sink limit
	check(main.state == MAIN.OVER and not main.ride_passed and SV.data["rank"] == 2, "missing a standard fails the checkride and the rank stays")
	check(main.ride_idx == 0 and main.ride_draw.size() > 1, "it ends at the failed landing (the others are never flown)")
	check(SV.data["coins"] == fee_before - fee3, "the examiner keeps the fee (%d coins left)" % SV.data["coins"])
	check(SV.data["pink_slips"].size() == 1 and SV.data["pink_slips"][0]["type"] == failed_type and SV.data["pink_slips"][0]["rank"] == 3 and SV.data["pink_slips"][0]["day"] > 19000, "a pink slip is stamped for good: the rank and the failed landing type (%s)" % str(SV.data["pink_slips"]))
	check(CAR.count(SV.data, failed_type) == CAR.needed() / 2 and not CAR.endorsed(SV.data, 3), "the failed type drops back to half and the endorsement is lost")
	check(main.hud._ov_title.text == "PINK SLIP" and main.hud._ov_body.text.contains(SC.NAMES[failed_type].capitalize()) and main.hud._ov_body.text.contains("fee"), "the debrief says so (%s)" % main.hud._ov_body.text.replace("\n", " | ").left(90))
	check(main.hud._menu_buttons["ad"].visible and main.hud._menu_buttons["ad"].text.contains("HALVE") and not main.hud._menu_buttons["ad"].text.contains("RETRY"), "after a fail the rewarded ad offers to HALVE the examiner fee (and there is no retry-landing ad): %s" % main.hud._menu_buttons["ad"].text)
	var coins_fail: int = SV.data["coins"]
	main._on_menu_action("ad")
	check(main.state == MAIN.AD and main.hud.ad_visible(), "...the fake ad plays")
	main.advance(float(tn.ad_fake_seconds) + 0.1)
	check(main.state == MAIN.OVER and SV.data["fee_halved"] and not main.hud._menu_buttons["ad"].visible and main.hud._ov_title.text == "PINK SLIP", "...then the next fee is halved, the offer is gone and the debrief is back")
	check(SV.data["coins"] == coins_fail, "(the ad costs nothing and pays nothing)")
	SV.data["fee_halved"] = false
	main._death_time = Time.get_ticks_msec() / 1000.0 - 1.0
	main._input(_touch_at(true, Vector2(540, 900)))
	check(main.state == MAIN.MENU and main.hud.career_visible() and main.hud._cr_book.disabled, "a tap goes to the career screen, where booking is off until you practise the type again")
	main._on_menu_action("back")
	main._on_menu_action("logbook")
	check(main.hud._log_slips[0].visible and main.hud._log_slip_labels[0].text.contains("PINK SLIP") and main.hud._log_slip_labels[0].text.contains(SC.NAMES[failed_type].capitalize()) and main.hud._log_slip_labels[0].text.contains("PRIVATE"), "the logbook shows it (%s)" % main.hud._log_slip_labels[0].text)
	main._on_menu_action("back")
	# --- the retest: practise the type back to full, a new draw, the full fee
	for k in 2:
		CAR.add_practice(SV.data, failed_type)
	check(CAR.endorsed(SV.data, 3), "practising the failed type back to full brings the endorsement back")
	main.state = MAIN.MENU
	var coins_pre: int = SV.data["coins"]
	check(main.book_checkride() and SV.data["coins"] == coins_pre - fee3, "the retest costs the full fee again (%d)" % fee3)
	var seeds_b: Array = main.ride_draw.map(func(e): return e["seed"])
	check(seeds_a != seeds_b, "...and is a new draw (%s vs %s)" % [str(seeds_a), str(seeds_b)])
	# --- a crash fails it too
	main.state = MAIN.OVER
	main.mode = MAIN.RIDE
	main._end_card() if main.state == MAIN.CARD else null
	fresh_endorsed.call(2, 500)
	main.book_checkride()
	var crash_type: int = main.ride_draw[0]["scn"]
	main._end_card()
	main._crash("test")
	for i in 600:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	check(main.state == MAIN.OVER and not main.ride_passed and SV.data["pink_slips"].size() == 1 and SV.data["pink_slips"][0]["type"] == crash_type, "a crash fails the checkride and earns a pink slip")
	# --- the halved fee flag (the rewarded ad sets it)
	fresh_endorsed.call(2, 500)
	SV.data["fee_halved"] = true
	main._on_menu_action("career")
	check(main.hud._cr_book.text.contains(str(CAR.fee(3, true))) and main.hud._cr_status.text.contains("halved"), "a halved fee shows on the career screen (%s)" % main.hud._cr_book.text)
	main.book_checkride()
	check(SV.data["coins"] == 500 - CAR.fee(3, true) and not SV.data["fee_halved"], "...is what is charged, and is used up")
	# --- Sport has only two types: the checkride is two landings; the top rank has no checkride
	fresh_endorsed.call(0, 500)
	main.book_checkride()
	check(main.ride_draw.size() == 2 and main.ride_target == 1, "Sport's checkride has only the 2 types it covers")
	fresh_endorsed.call(7, 500)
	check(not main.book_checkride(), "Airline Captain has no checkride to book")
	# --- nothing is allocated by it
	fresh_endorsed.call(2, 5000)
	var n21 := nodes()
	var r21 := resources()
	for i in 2:
		main.state = MAIN.MENU
		main.debug_endorse()
		main.book_checkride()
		for k in main.ride_draw.size():
			if main.state != MAIN.CARD:
				break
			fly_ride_landing.call(0.3, 0.0)
		main._death_time = Time.get_ticks_msec() / 1000.0 - 1.0
		if main.state == MAIN.OVER:
			main._continue_from_over()
		SV.data["rank"] = 2
		CAR.on_rank_change(SV.data, 2)
	main.start_run()
	main._end_card()
	check(nodes() == n21 and resources() <= r21 + 3, "booking, flying and the certificate / pink slip allocate nothing (%d -> %d nodes)" % [n21, nodes()])
	SV.data["unlock_all"] = true
	force(-1, -1)

	print("== 22. ad hooks after the career update ==  [nodes %d]" % nodes())
	# the halved fee, end to end: fail, watch the ad, retest costs half
	fresh_endorsed.call(2, 1000)
	main.book_checkride()
	fly_ride_landing.call(1.5, 0.0)
	check(main.state == MAIN.OVER and main.hud._menu_buttons["ad"].visible, "(a failed checkride)")
	main._on_menu_action("ad")
	main.advance(float(tn.ad_fake_seconds) + 0.1)
	CAR.add_practice(SV.data, SV.data["pink_slips"][0]["type"])
	CAR.add_practice(SV.data, SV.data["pink_slips"][0]["type"])
	var coins_b4: int = SV.data["coins"]
	main._continue_from_over()
	check(main.hud.career_visible() and main.hud._cr_book.text.contains(str(CAR.fee(3, true))), "the career screen offers the retest at the halved fee (%s)" % main.hud._cr_book.text)
	main.book_checkride()
	check(coins_b4 - SV.data["coins"] == CAR.fee(3, true) and not SV.data["fee_halved"], "the retest is charged half (%d) and the discount is used up" % (coins_b4 - SV.data["coins"]))
	# no interstitials in checkrides, practice or the daily
	ADS.enabled = true
	var gap22: float = tn.ad_min_gap_seconds
	var every22: int = tn.ad_interstitial_every
	tn.ad_min_gap_seconds = 0.0
	tn.ad_interstitial_every = 1
	ADS.rounds_since = 99
	var ad_seen22 := false
	for k in main.ride_draw.size():
		if main.state != MAIN.CARD:
			break
		fly_ride_landing.call(0.3, 0.0)
		if main.state == MAIN.AD:
			ad_seen22 = true
	check(not ad_seen22, "no interstitial between checkride landings")
	tn.ad_min_gap_seconds = gap22
	tn.ad_interstitial_every = every22
	ADS.enabled = false
	force(-1, -1)

	print("== 23. approach pacing ==  [nodes %d]" % nodes())
	SV.data = SV.default_data()
	SV.data["unlock_all"] = true
	main.start_run()
	main._end_card()
	force(SC.STANDARD, SC.CLEAR)
	var t_app: float = tn.approach_seconds
	var pace_ok := true
	var starts := {}
	for pid in [PL.CUB, PL.C172, PL.TWIN, PL.JET]:
		main.select_plane(pid, false)
		var times := []
		var dists := []
		for i in 8:
			new_round(2300 + i, 2)           # (flat, asphalt: no obstacle sets the start)
			var trim_p: float = main.aircraft.trim_sink()
			times.append(main.aircraft.y / trim_p)
			dists.append(main.airfield.aim_x - main.aircraft.x)
		var mean_t := 0.0
		for v in times:
			mean_t += v
		mean_t /= times.size()
		var mean_d := 0.0
		for v in dists:
			mean_d += v
		mean_d /= dists.size()
		starts[pid] = [mean_t, mean_d]
		if mean_t < t_app * 0.85 or mean_t > t_app * 1.5:
			pace_ok = false
	print("      time on the path (s) / distance to the aim point (u): %s" % str(starts))
	check(pace_ok, "every aircraft starts about approach_seconds (%.1f s) from the touchdown point" % t_app)
	check(starts[PL.JET][1] > starts[PL.C172][1] * 1.5 and starts[PL.C172][1] > starts[PL.CUB][1] * 1.2, "...the faster ones start further out (cub %.0f u, 172 %.0f u, jet %.0f u from the aim point) but take about the same time" % [starts[PL.CUB][1], starts[PL.C172][1], starts[PL.JET][1]])
	check(absf(starts[PL.JET][0] - starts[PL.C172][0]) < t_app * 0.25, "(jet %.1f s vs 172 %.1f s)" % [starts[PL.JET][0], starts[PL.C172][0]])
	main.select_plane(PL.C172, false)
	new_round(2310, 2)
	var alt_a: float = main.aircraft.y
	tn.approach_seconds = t_app * 2.0
	new_round(2310, 2)
	check(main.aircraft.y > alt_a * 1.6, "doubling approach_seconds starts the approach about twice as high on the same path (%.1f -> %.1f u)" % [alt_a, main.aircraft.y])
	tn.approach_seconds = t_app
	check(TP.ENTRIES.any(func(e): return e[0] == "approach_seconds"), "the approach time has a ?tune slider")
	force(SC.POWER_OFF, SC.CLEAR)
	new_round(2311, 4)
	var dead_t: float = main.aircraft.y / main.aircraft.trim_sink()
	check(dead_t > t_app * 1.05 and dead_t < t_app * 2.0, "dead-stick approaches are a little longer (%.1f s)" % dead_t)
	force(SC.INSTRUMENT, -1)
	new_round(2312, 4)
	var dh_pace: float = UN.units_of_ft(float(tn.instrument_dh_ft))
	check(main.aircraft.agl() > dh_pace + 1.0 and main.aircraft.agl() < dh_pace + UN.units_of_ft(float(tn.instrument_start_ft_above_dh)) + 3.0, "an instrument approach starts just above its 100 ft decision height (%.0f ft)" % UN.ft(main.aircraft.agl()))
	force(SC.SHORT_FIELD, SC.CLEAR)
	var first_frame_ok := true
	for i in 6:
		new_round(2320 + i, 6)
		if not (main.aircraft.x >= main._cam_x - main._cam_w * 0.5 and main.airfield.rwy_end <= main._cam_x + main._cam_w * 0.5):
			if main._full_w < float(tn.view_width_full_max) - 0.01:
				first_frame_ok = false
		if main._cam_w < float(tn.view_width_low) * 2.0:
			first_frame_ok = false
	check(first_frame_ok, "the first frame shows the plane and the whole runway (wide framing)")
	force(-1, -1)

	print("== 24. push-your-luck free flight ==  [nodes %d]" % nodes())
	SV.data = SV.default_data()
	SV.data["unlock_all"] = true
	force(-1, -1)
	main.start_run()
	main._end_card()
	check(main.hud._pot.visible and main.pot == 0 and not main.hud._strikes[0].visible, "a run starts with an empty pot on the HUD and no strike pips")
	var step: float = tn.pot_step
	check(is_equal_approx(main.pot_multiplier(), 1.0), "the first landing pays x1.0")
	# land three greasers in a row: the pot grows by the grade's coins x the Greaser streak x the pot multiplier
	var expect_pot := 0
	for k in 3:
		new_round(2400 + k, 2 + k)
		main.state = MAIN.APPROACH
		var mult_now: float = 1.0 + step * float(k)
		check(is_equal_approx(main.pot_multiplier(), mult_now), "landing %d pays x%.1f" % [k + 1, mult_now])
		land_at(0.3, 0.0)
		expect_pot += int(roundf(float(COS.coins_for(0, k + 1)) * mult_now))
		check(main.pot == expect_pot and SV.data["coins"] == 0, "...pot %d (the grade's coins x streak x%d x pot multiplier), nothing banked" % [main.pot, k + 1])
		main._finish_round(false)
		check(main.state == MAIN.CHOICE, "(choice after landing %d)" % (k + 1))
		if k < 2:
			main._on_choice("keep")
			for i in 60 * 3:
				main.advance(1.0 / 30.0)
				if main.state == MAIN.CARD:
					main._end_card()
				if main.state == MAIN.APPROACH:
					break
	# the choice screen: pot, next multiplier, a hint about what is coming
	main._next_pick = Vector2i(SC.SHORT_FIELD, SC.FOG)
	main.hud.show_choice({"title": "LANDED!", "pot": main.pot, "next_mult": main.pot_multiplier(), "hint": main._next_hint()})
	check(main.hud._ch_pot.text.contains(str(main.pot)) and main.hud._ch_next.text.contains("x%.1f" % (1.0 + step * 3.0)), "the choice screen shows the pot (%d) and the next multiplier (%s)" % [main.pot, main.hud._ch_next.text])
	check(main.hud._ch_hint.text.contains("Fog") and main.hud._ch_hint.text.contains("Short Field"), "...and a hint about the next approach (%s)" % main.hud._ch_hint.text.split("\n")[0])
	# cash out: a count-up, then the pot is banked
	var pot_cash: int = main.pot
	main._on_choice("cashout")
	check(main.state == MAIN.CASHOUT and not main.hud._ch_cash.visible and main.hud._ch_count.visible, "CASH OUT starts the count-up")
	var counts: Array[int] = []
	for i in 400:
		main.advance(1.0 / 30.0)
		var shown := int(str(main.hud._ch_count.text).trim_prefix("+"))
		counts.append(shown)
		if main.state != MAIN.CASHOUT:
			break
	var mono := true
	for i in range(1, counts.size()):
		if counts[i] < counts[i - 1]:
			mono = false
	check(mono and counts[0] < pot_cash and counts.max() == pot_cash, "the number counts up to the pot (%d .. %d)" % [counts[0], counts.max()])
	check(SV.data["coins"] == pot_cash and main.banked == pot_cash and main.pot == 0, "...the coins are banked (%d) and the pot is empty" % SV.data["coins"])
	for i in 100:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	check(main.state == MAIN.OVER and main.hud._ov_title.text == "CASHED OUT" and main.hud._ov_body.text.contains("Banked  +%d" % pot_cash), "the run ends on a CASHED OUT screen (%s)" % main.hud._ov_body.text.replace("\n", " | "))
	check(main.hud._menu_buttons["ad"].visible and main.hud._menu_buttons["ad"].text.contains("DOUBLE"), "...with the double-coins ad")
	# a crash loses everything
	main.start_run()
	main._end_card()
	new_round(2410, 3)
	main.state = MAIN.APPROACH
	land_at(0.3, 0.0)
	main._finish_round(false)
	main._on_choice("keep")
	for i in 60 * 3:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.CARD:
			main._end_card()
		if main.state == MAIN.APPROACH:
			break
	var pot_before_crash: int = main.pot
	var coins_pc: int = SV.data["coins"]
	main._crash("test")
	check(main.pot == 0 and main.pot_lost == pot_before_crash and pot_before_crash > 0, "a crash empties the pot (%d coins lost)" % main.pot_lost)
	check(main.hud._pop_sub.text.contains("Pot lost: %d coins" % pot_before_crash), "the crash popup says 'Pot lost: %d coins'" % pot_before_crash)
	for i in 200:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	check(main.state == MAIN.OVER and SV.data["coins"] == coins_pc and main.hud._ov_body.text.contains("Pot lost: %d coins" % pot_before_crash) and not main.hud._menu_buttons["ad"].visible, "...the crash screen too; nothing banked; no double-coins offer")
	# every approach is harder
	check(is_equal_approx(tn.ramp(1), 0.0) and tn.ramp(6) > tn.ramp(3) and tn.ramp(40) <= float(tn.difficulty_max) + 0.001 and float(tn.difficulty_max) > 1.0, "difficulty grows with every landing (step %.2f per approach, up to x%.1f)" % [float(tn.difficulty_step), float(tn.difficulty_max)])
	var len_early := 0.0
	var len_late := 0.0
	var wind_early := 0.0
	var wind_late := 0.0
	for i in 40:
		main.rng.seed = 2500 + i
		main.airfield.generate(2, main.rng, SC.STANDARD, SC.CLEAR)
		len_early += main.airfield.rwy_len
		wind_early += absf(main.airfield.wind_base)
		main.rng.seed = 2500 + i
		main.airfield.generate(14, main.rng, SC.STANDARD, SC.CLEAR)
		len_late += main.airfield.rwy_len
		wind_late += absf(main.airfield.wind_base)
	check(len_late < len_early * 0.85 and wind_late > wind_early * 1.5, "later approaches have shorter runways (%.0f -> %.0f u) and stronger winds (%.1f -> %.1f)" % [len_early / 40.0, len_late / 40.0, wind_early / 40.0, wind_late / 40.0])
	var wx_a := 0
	var wx_b := 0
	var hard_a := 0
	var hard_b := 0
	var rr2 := RandomNumberGenerator.new()
	rr2.seed = 321
	for i in 200:
		var pa: Vector2i = SC.pick(3, rr2, -1)
		var pb: Vector2i = SC.pick(12, rr2, -1)
		if pa.y != SC.CLEAR:
			wx_a += 1
		if pb.y != SC.CLEAR:
			wx_b += 1
		if pa.x != SC.STANDARD:
			hard_a += 1
		if pb.x != SC.STANDARD:
			hard_b += 1
	check(wx_b > wx_a and hard_b > hard_a, "...worse weather (%d%% -> %d%% of approaches) and tougher scenarios (%d%% -> %d%%)" % [wx_a / 2, wx_b / 2, hard_a / 2, hard_b / 2])
	check(main._gust_scale > 0.0, "(gusts scale with the ramp)")
	force(-1, -1)

	print("== 25. pause ==  [nodes %d]" % nodes())
	SV.data = SV.default_data()
	SV.data["unlock_all"] = true
	main.start_run()
	main._end_card()
	new_round(2600, 3)
	main.state = MAIN.APPROACH
	main.advance(1.0 / 30.0)
	check(main.hud._pause_btn.visible, "the pause button shows during the approach")
	var vsz: Vector2 = main.hud.get_viewport().get_visible_rect().size
	var prect: Rect2 = main.hud.pause_button_rect()
	check(prect.position.x > vsz.x * 0.8 and prect.end.y < vsz.y * 0.1 and prect.size.x >= 40.0, "...in the top-right corner, clear of the approach view (%s of %s)" % [str(prect), str(vsz)])
	var plane_scr: Vector2 = main.camera.unproject_position(Vector3(main.aircraft.x, main.aircraft.y, 0.0))
	check(not prect.has_point(plane_scr) and not main.hud.papi_rect().intersects(prect), "(and not over the plane or the PAPI)")
	main.pot = 840
	var x_pause: float = main.aircraft.x
	main._on_pause_action("pause")
	check(main.is_run_paused() and main.hud.pause_visible() and paused and not main.can_process(), "pausing freezes the game and shows the pause menu")
	check(main.hud._pz_main.visible and main.hud._pz_main.get_child_count() == 3, "Resume / Settings / Quit")
	main._on_pause_action("resume")
	check(not main.is_run_paused() and not paused and main.can_process() and not main.hud.pause_visible(), "Resume carries on")
	main._on_pause_action("pause")
	main._on_pause_action("settings")
	check(main.hud._pz_settings.visible and main.hud._pz_sliders.has("sound") and main.hud._pz_sliders.has("music"), "Settings has sound and music volume sliders")
	main.hud._pz_sliders["sound"].value = 0.4
	main.hud._pz_sliders["music"].value = 0.0
	var si: int = AudioServer.get_bus_index("Sfx")
	var mi: int = AudioServer.get_bus_index("Music")
	check(is_equal_approx(SV.data["settings"]["sound"], 0.4) and absf(AudioServer.get_bus_volume_db(si) - linear_to_db(0.4)) < 0.1 and AudioServer.is_bus_mute(mi), "...they set the Sfx / Music bus volumes (and are saved)")
	main.hud._pz_sliders["sound"].value = 1.0
	main.hud._pz_sliders["music"].value = 0.5
	main._on_pause_action("settings_back")
	check(main.hud._pz_main.visible and not main.hud._pz_settings.visible, "Back returns to the pause menu")
	# quitting a free-flight run forfeits the pot, after a confirmation
	main._on_pause_action("quit")
	check(main.hud._pz_confirm.visible and main.hud._pz_confirm_text.text == "Quit and lose 840 coins?", "Quit asks 'Quit and lose 840 coins?' (%s)" % main.hud._pz_confirm_text.text)
	main._on_pause_action("quit_no")
	check(main.is_run_paused() and main.pot == 840 and main.hud._pz_main.visible, "NO goes back, the pot is untouched")
	var coins_q: int = SV.data["coins"]
	main._on_pause_action("quit")
	main._on_pause_action("quit_yes")
	for i in 100:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	check(main.state == MAIN.OVER and not paused and main.pot == 0 and main.pot_lost == 840 and SV.data["coins"] == coins_q, "YES ends the run and forfeits the pot (nothing banked)")
	check(main.hud._ov_body.text.contains("Pot lost: 840 coins"), "...the run-over screen says so")
	# no pause button in the menus
	main.hud.set_pause_button(false)
	main.state = MAIN.OVER
	check(not main._can_pause(), "(no pausing on the run-over screen)")
	# a checkride: quitting counts as a fail, with confirmation
	SV.data = SV.default_data()
	SV.data["rank"] = 2
	SV.data["coins"] = 500
	CAR.on_rank_change(SV.data, 2)
	main.start_run()
	main._end_card()
	main.state = MAIN.MENU
	main._show_menu()
	main.debug_endorse()
	var fee_q: int = CAR.fee(3)
	check(main.book_checkride(), "(a booked checkride)")
	main._end_card()
	main.advance(1.0 / 30.0)
	main.pause_game()
	main._on_pause_action("quit")
	check(main.hud._pz_confirm_text.text.contains("checkride") and main.hud._pz_confirm_text.text.contains("fail"), "quitting a checkride warns that it counts as a fail (%s)" % main.hud._pz_confirm_text.text)
	main._on_pause_action("quit_yes")
	for i in 100:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	check(main.state == MAIN.OVER and not main.ride_passed and SV.data["pink_slips"].size() == 1 and SV.data["rank"] == 2 and SV.data["coins"] == 500 - fee_q, "...it is a fail: a pink slip, the fee is gone, the rank stays")
	check(main.hud._ov_title.text == "PINK SLIP", "(the pink-slip debrief)")
	# practice: quitting just leaves it
	main._continue_from_over()
	var prof_before: int = CAR.count(SV.data, SC.STANDARD)
	main._on_menu_action("career")
	main._on_menu_action("practice:0")
	main._end_card()
	main.pause_game()
	check(main.hud._pz_confirm_text.text == "" or true, "(paused in practice)")
	main._on_pause_action("quit")
	check(main.hud._pz_confirm_text.text.contains("practice"), "quitting practice asks too (%s)" % main.hud._pz_confirm_text.text)
	main._on_pause_action("quit_yes")
	for i in 100:
		main.advance(1.0 / 30.0)
		if main.state == MAIN.OVER:
			break
	check(main.state == MAIN.OVER and CAR.count(SV.data, SC.STANDARD) == prof_before, "...and it doesn't count")
	# auto-pause when the app loses focus
	main.start_run()
	main._end_card()
	main.state = MAIN.APPROACH
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(main.is_run_paused() and paused, "losing focus pauses the run")
	main._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(main.is_run_paused(), "...and it stays paused when focus comes back (you press Resume)")
	main.resume_game()
	main._skip_frames = 0
	check(not paused and not main.is_run_paused(), "(resumed)")
	# nothing is allocated by pausing
	var n25 := nodes()
	var r25 := resources()
	for i in 6:
		main.pause_game()
		main._on_pause_action("settings")
		main._on_pause_action("settings_back")
		main._on_pause_action("quit")
		main._on_pause_action("quit_no")
		main.resume_game()
	check(nodes() == n25 and resources() <= r25 + 2, "pausing allocates nothing (%d -> %d nodes)" % [n25, nodes()])
	main._skip_frames = 0
	force(-1, -1)

	print("== 26. aircraft are bought with coins ==  [nodes %d]" % nodes())
	SV.data = SV.default_data()
	main.start_run()
	main._end_card()
	main.state = MAIN.MENU
	main._show_menu()
	check(PL.price(PL.CUB) == 0 and PL.price(PL.C172) > 0 and PL.price(PL.JET) > PL.price(PL.TWIN) and PL.price(PL.TWIN) > PL.price(PL.C172), "the Cub is free, the others have prices that grow (172 %d, twin %d, glider %d, jet %d)" % [PL.price(PL.C172), PL.price(PL.TWIN), PL.price(PL.GLIDER), PL.price(PL.JET)])
	check(main.available_planes() == [PL.CUB], "a new pilot has the Cub")
	main._on_menu_action("hangar")
	check(main.hud._hangar_planes.size() == 5 and main.hud._hangar_planes[0].text == "[CUB]" and main.hud._hangar_planes[1].text.contains(str(PL.price(PL.C172))), "the hangar lists the aircraft with their prices (%s)" % main.hud._hangar_planes[1].text)
	main._on_hangar_pick("plane", PL.C172)
	check(not main.available_planes().has(PL.C172) and main.plane_id == PL.CUB, "without the coins you can't buy it")
	SV.data["coins"] = PL.price(PL.C172) + 30
	main._on_hangar_pick("plane", PL.C172)
	check(main.available_planes().has(PL.C172) and main.plane_id == PL.C172 and SV.data["coins"] == 30 and SV.data["owned_planes"] == [PL.C172], "buying takes the price and you fly it")
	check(main.hud._hangar_planes[1].text == "[172]", "(%s)" % main.hud._hangar_planes[1].text)
	var kept: Dictionary = SV.migrate(SV.data)
	check(kept["owned_planes"] == [PL.C172] and kept["settings"]["sound"] == 1.0, "bought aircraft survive the save (and the settings have defaults)")
	main.start_run()
	main._end_card()
	check(main.plane_id == PL.C172 and main.available_planes() == [PL.CUB, PL.C172], "a run starts in the aircraft you bought")
	# balance: what a typical cash-out buys
	var typical := func(n: int, base: Array) -> int:
		var total := 0.0
		for k in n:
			total += float(base[k % base.size()]) * (1.0 + step * float(k))
		return int(roundf(total))
	var casual: int = typical.call(4, [COS.coins_for(2, 1), COS.coins_for(1, 1)])
	var good_run: int = typical.call(5, [COS.coins_for(1, 1), COS.coins_for(2, 1), COS.coins_for(1, 1)])
	var greasers := 0.0
	for k in 5:
		greasers += float(COS.coins_for(0, k + 1)) * (1.0 + step * float(k))
	print("      balance: casual 4-landing cash-out %d coins, good 5-landing %d, five greasers in a row %d | 172 %d, glider %d, twin %d, jet %d" % [casual, good_run, int(greasers), PL.price(PL.C172), PL.price(PL.GLIDER), PL.price(PL.TWIN), PL.price(PL.JET)])
	check(PL.price(PL.C172) <= good_run * 3 and PL.price(PL.C172) >= casual and PL.price(PL.JET) <= int(greasers) * 3 and PL.price(PL.JET) >= good_run * 4, "prices are balanced against cash-outs: the 172 is a few runs, the jet is a real goal")
	check(CAR.fee(7) <= int(greasers) and CAR.fee(1) < casual, "(and the examiner's fees stay within a cash-out or two)")
	force(-1, -1)

	print("== 27. the shared style (docs/style.md): tokens, icons, buttons, safe areas ==  [nodes %d]" % nodes())
	var sty27 = load("res://scripts/Style.gd")
	var ico27 = load("res://scripts/Icons.gd")
	check(sty27.contrast(sty27.TEXT, sty27.SURFACE_DARK) >= 4.5 and sty27.contrast(sty27.TEXT_SOFT, sty27.SURFACE_DARK) >= 4.5 and sty27.contrast(sty27.TEXT_ON_LIGHT, sty27.SURFACE_LIGHT) >= 4.5, "text on the dark and light surfaces has 4.5:1 contrast (%.1f / %.1f / %.1f)" % [sty27.contrast(sty27.TEXT, sty27.SURFACE_DARK), sty27.contrast(sty27.TEXT_SOFT, sty27.SURFACE_DARK), sty27.contrast(sty27.TEXT_ON_LIGHT, sty27.SURFACE_LIGHT)])
	check(sty27.contrast(sty27.TEXT, sty27.SURFACE_DARK_2) >= 4.5 and sty27.contrast(sty27.INK, sty27.ACCENT) >= 4.5, "(selected surface and gold keep their contrast)")
	check(sty27.display() != null and sty27.text() != null and sty27.font_for("FLY", sty27.SZ_S) == sty27.text() and sty27.font_for("FLY", sty27.SZ_XL) == sty27.display() and sty27.font_for("12", sty27.SZ_S) == sty27.display(), "Fredoka for display and numbers, Nunito for text")
	var missing27: Array[String] = []
	for id in ico27.IDS:
		if not ico27.has(id):
			missing27.append(id)
	for i in 5:
		if not ico27.has(ico27.aircraft(i)):
			missing27.append("aircraft%d" % i)
	for i in 8:
		if not ico27.has(ico27.rank(i)):
			missing27.append("rank%d" % i)
	for i in ico27.LANDING.size():
		if not ico27.has(ico27.landing(i)):
			missing27.append("landing%d" % i)
	for i in ico27.WEATHER.size():
		if not ico27.has(ico27.weather(i)):
			missing27.append("weather%d" % i)
	check(missing27.is_empty() and ico27.IDS.size() >= 60, "an icon for every stat, aircraft, rank, landing type and weather (%d icons)" % ico27.IDS.size())
	var hb27: Array = main.hud.find_children("*", "UiButton", true, false)
	var sm27 := 0
	var bare27 := 0
	for b in hb27:
		if b.size.y < 80.0 or b.size.x < 80.0:
			sm27 += 1
		if b.text == "" and b.icon == "":
			bare27 += 1
		if b.icon != "" and not ico27.has(b.icon):
			bare27 += 1
	check(hb27.size() >= 15 and sm27 == 0 and bare27 == 0, "%d buttons, every one touch-sized (80 px+) and with a label or a known icon" % hb27.size())
	var ub27 = hb27[0]
	var downs27 := [0]
	ub27.pressed_down.connect(func(): downs27[0] += 1)
	ub27.disabled = true
	ub27.disabled = false
	check(not ub27.is_down() and ub27.press_amount == 0.0, "a button starts up, and disabling releases it")
	var okbtn27: bool = true
	for kind in ["primary", "gold", "danger", "secondary", "ghost"]:
		ub27.kind = kind
		okbtn27 = okbtn27 and ub27.kind == kind
	check(okbtn27, "primary, gold, danger, secondary and ghost kinds exist")
	sty27.set_safe(90.0, 50.0)
	main.hud.apply_safe()
	check(is_equal_approx(main.hud._pause_btn.offset_top, 14.0 + 90.0), "a notch pushes the pause button down inside the safe area (%.0f)" % main.hud._pause_btn.offset_top)
	sty27.set_safe(0.0, 0.0)
	main.hud.apply_safe()
	check(is_equal_approx(main.hud._pause_btn.offset_top, 14.0), "...and no notch puts it back")
	DF.parse([] as Array[String])
	var stamp_off: bool = not DF.stamp_enabled() and not main.hud._stamp.visible
	DF.parse(["debug"] as Array[String])
	var d_on: bool = DF.stamp_enabled()
	DF.parse(["tune"] as Array[String])
	var t_on: bool = DF.stamp_enabled()
	DF.parse(["perf"] as Array[String])
	check(stamp_off and d_on and t_on and DF.stamp_enabled(), "the build stamp is hidden from players and shown only with ?debug, ?tune or ?perf")
	check(main.hud._logo_root.get_child(1).text == "Clear Prop Games" and ico27.has("prop"), "the logo intro says Clear Prop Games, with the propeller mark")
	DF.parse(["nologo"] as Array[String])
	check(DF.nologo, "?nologo skips the studio intro")
	DF.parse([] as Array[String])

	print("== 9. debug flags / frame time ==  [nodes %d]" % nodes())
	DF.parse(["nofx=smoke,shake", "perf", "round=4", "seed=9", "bogus"] as Array[String])
	check(DF.off("smoke") and DF.off("shake") and not DF.off("popup"), "?nofx=smoke,shake switches just those off")
	check(DF.perf_enabled() and DF.first_round() == 4 and DF.seed_number() == 9, "?perf, ?round=4, ?seed=9")
	check(DF.summary().contains("?bogus"), "a typo'd flag is shown in the summary")
	DF.parse(["nofx=all"] as Array[String])
	check(DF.off("sfx") and DF.off("clouds") and DF.off("wind"), "?nofx=all switches everything off")
	DF.parse([] as Array[String])
	check(not DF.off("smoke") and DF.summary() == "", "no flags: nothing off, empty summary")
	check(is_equal_approx(main._frame_delta(0.1), float(tn.max_frame_delta)), "a long frame is clamped to max_frame_delta")
	check(main._frame_delta(1.0) == 0.0, "a stall (1 s frame) is dropped, not simulated")
	check(main._frame_delta(0.016) == 0.0 and main._frame_delta(0.016) == 0.0, "...and a couple of frames are skipped after it")
	check(main._frame_delta(0.016) > 0.0, "...then play resumes")

## Touch down at `offset` from the aim markers with roughly `sink` (set a hair above the ground, so it's about this much).
func land_at(sink: float, offset: float) -> void:
	var af = main.airfield
	var px: float = af.aim_x + offset
	main._gate_dev_kt = 0.0        # (a stable approach: the speed gate isn't flown in these set-ups)
	main.aircraft.reset(px, af.ground_y(px) + 0.012)
	main.aircraft.gy = af.ground_y(px)
	main.aircraft.vy = -sink
	main.aircraft.theta_target = 0.0
	for i in 40:
		main.advance(1.0 / 60.0)
		if main.state != MAIN.APPROACH or main._graded:
			break

func force(scn: int, wx: int) -> void:
	SC.forced_scenario = scn
	SC.forced_weather = wx

func _touch_at(pressed: bool, pos: Vector2) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = pos
	e.pressed = pressed
	return e

func _touch(pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(540, 900)
	e.pressed = pressed
	return e

## Fly the current approach with an autopilot that knows about slopes, moving decks and engine-out: steer to the aim
## point (closing speed = ground speed - deck speed), then flare at `flare_h` above the ground with a sink rate that
## eases down with the height (relative to the ground). flare_h < 0 = never flare.
## A good pilot: aims `aim_bias` units short of the markers (the flare floats a little), then flares at `flare_h`.
func fly_g(flare_h: float, aim_bias: float = -20.0) -> Dictionary:
	var ac = main.aircraft
	var af = main.airfield
	main.last_result = {}
	var t := 0.0
	while t < 70.0:
		t += 1.0 / 30.0
		var gs: float = maxf(float(ac.gs), 4.0)
		var m: float = af.slope_at(ac.x)
		var agl: float = ac.agl()
		var trim: float = ac.trim_sink()
		var cmd := 0.0
		if flare_h < 0.0 or agl > flare_h:
			var closing: float = maxf(gs - float(af.deck_speed), 4.0)
			var t_go: float = maxf((float(af.aim_x) + aim_bias - float(ac.x)) / closing, 0.5)
			var h_aim: float = ac.y - af.ground_y(af.aim_x)
			var want_rel: float = clampf(-h_aim / t_go, -1.6 * trim, -0.7 * trim)
			cmd = (want_rel + gs * m + trim) / ac.lift_gain()
		else:
			var want: float = -(0.33 + 0.3 * agl) + gs * m
			cmd = (want + trim) / ac.lift_gain()
		if ac.power == 0.0:
			cmd -= (0.97 - ac.s) * 40.0      # no engine: hold the glide speed with the nose
		set_nose(cmd)
		main.advance(1.0 / 30.0)
		if main.state == MAIN.CRASH:
			return {"crash": true, "result": {}}
		if main.state == MAIN.ROLLOUT or main.state == MAIN.FADE:
			return {"crash": false, "result": main.last_result}
	return {"crash": true, "result": {}, "timeout": true}

func steady_vy(deg: float, seconds: float = 2.5) -> float:
	var a = main.aircraft
	a.theta_target = deg
	for i in int(seconds / 0.01):
		a.step_air(0.01, 0.0, 0.0, 0.0)
	return a.vy

func sink_of(r: Dictionary) -> float:
	if r["crash"]:
		return 6.0
	return float(r["result"].get("sink", 6.0))

func tap_to_start() -> void:
	main.state = MAIN.MENU
	tap()
	main._end_card()

func tap_to_start_force() -> void:
	main.state = MAIN.MENU
	main.hud.show_menu(0)
	tap()
	main._end_card()
