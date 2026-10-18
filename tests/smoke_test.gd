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
	while t < 60.0:
		t += 1.0 / 60.0
		var gs: float = maxf(float(ac.gs), 4.0)
		var cmd := 0.0
		if flare_h < 0.0 or ac.y > flare_h:
			var t_go := maxf((af.aim_x - ac.x) / gs, 0.5)
			var want_vy := clampf(-ac.y / t_go, -5.0, -2.5)
			cmd = (want_vy + float(tn.trim_sink)) / float(tn.pitch_lift_gain)
		elif flare_theta > 0.0:
			cmd = flare_theta
		else:
			var want: float = -(0.25 + 0.3 * float(ac.y))
			cmd = (want + float(tn.trim_sink)) / float(tn.pitch_lift_gain)
		set_nose(cmd)
		main.advance(1.0 / 60.0)
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
	check(main.round_no == 1 and main.strikes == 0 and main.score == 0, "run starts at round 1, no strikes, score 0")
	check(main.aircraft.x == 0.0 and main.aircraft.y > 25.0, "the plane starts on the left, high")
	check(main.airfield.thr > 55.0 and main.airfield.aim_x > main.airfield.thr, "the runway is ahead with the aim markers on it")

	print("== 2. grading ==  [nodes %d]" % nodes())
	var g: Dictionary = GR.evaluate(0.5, 0.0, 200.0, false)
	check(g["total"] == 100 and g["grade"] == 0 and g["name"] == "Greaser!", "soft, on the markers, no bounce = 100, Greaser!")
	g = GR.evaluate(0.5, 0.0, 200.0, true)
	check(g["grade"] >= 2, "a bounce can't be better than Good (%s)" % g["name"])
	g = GR.evaluate(3.0, 0.0, 200.0, false)
	check(g["grade"] >= 3, "a firm 3.0 sink can't be a good grade even on the markers (%s)" % g["name"])
	g = GR.evaluate(4.5, 30.0, 200.0, false)
	check(g["grade"] == 4 and g["name"] == "Hard", "sink 4.5 and 30 m off = Hard")
	check(GR.sink_score(0.9) > GR.sink_score(2.0) and GR.sink_score(2.0) > GR.sink_score(4.0), "sink points fall as the sink rate grows")
	check(GR.position_score(0.0, 200.0) > GR.position_score(15.0, 200.0), "points fall with distance from the markers")
	check(is_equal_approx(GR.position_score(-12.0, 200.0), GR.position_score(12.0, 200.0)), "short and long of the markers score the same")
	check(GR.is_crash_sink(6.0) and not GR.is_crash_sink(5.0), "sink rate 6.0 is a crash, 5.0 is not")
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
	check(absf(vy_0 + float(tn.trim_sink)) < 0.25, "the approach attitude gives the approach sink rate (%.2f)" % vy_0)
	# nose up bleeds airspeed
	ac.reset(0.0, 60.0)
	steady_vy(8.0, 3.0)
	check(ac.s < 0.85, "holding the nose up bleeds airspeed (s = %.2f)" % ac.s)
	# a plain approach lands
	new_round(21, 1)
	var plain := fly(-1.0, 0.0)
	check(not plain["crash"] and plain["result"].has("grade"), "round 1, plain approach with no flare lands on the runway (%s)" % main.last_crash)
	var plain_sink: float = plain["result"].get("sink", 0.0)
	check(plain_sink > 2.0 and plain_sink < float(tn.crash_sink), "...but firmly (sink %.2f): the flare is what makes it a greaser" % plain_sink)
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
	check(sum_good / n < sum_none / n - 1.5, "a well-timed flare lands much softer than no flare")
	check(sum_good / n < 1.2, "a well-timed flare gives a smooth touchdown (mean sink %.2f)" % (sum_good / n))
	check(sum_early / n > sum_good / n + 0.5, "flaring too early lands harder (float, stall, drop)")
	check(sum_late / n > sum_good / n + 0.5, "flaring too late lands harder (slams in)")

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
		if main.airfield.thr < 59.0 or main.airfield.aim_x <= main.airfield.thr or main.airfield.aim_x >= main.airfield.rwy_end:
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
	check(lens.min() < 110.0 and lens.max() > 150.0, "runway lengths vary (%.0f .. %.0f)" % [lens.min(), lens.max()])
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
	main.aircraft.reset(150.0, 3.0)
	main.advance(1.0)
	check(main.state == MAIN.CRASH and main.last_crash == "Off the runway!", "touching down short of the runway is a crash (%s)" % main.last_crash)
	new_round(42, 1)
	main.aircraft.reset(main.airfield.aim_x - 10.0, 4.0)
	main.aircraft.vy = -8.0
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
	main.aircraft.reset(main.airfield.aim_x, 0.4)
	main.aircraft.vy = -4.2
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
	# roll out to a stop, fade, next round on a new runway
	var round_before: int = main.round_no
	var thr_before: float = main.airfield.thr
	for i in 60 * 16:
		main.advance(1.0 / 60.0)
		if main.state == MAIN.CARD:
			main._end_card()
		if main.state == MAIN.APPROACH:
			break
	check(main.state == MAIN.APPROACH and main.round_no == round_before + 1, "after the rollout a new approach starts straight away (round %d)" % main.round_no)
	check(main.aircraft.x == 0.0 and main.aircraft.y > 25.0 and not main.aircraft.on_ground, "...with the plane back on the left, high")
	check(main.score == pts, "the score carries over")
	# three crashes end the run
	var sc: int = main.score
	for k in 3:
		new_round(70 + k, 1)
		main.aircraft.reset(main.airfield.rwy_end + 10.0, 20.0)
		main.advance(0.1)
		check(main.state == MAIN.CRASH and main.strikes == k + 1, "crash %d is strike %d" % [k + 1, k + 1])
		check(main.score == sc, "a crash doesn't change the score")
		main.advance(float(tn.crash_pause) + 0.1)
		if k < 2:
			for i in 60 * 3:
				main.advance(1.0 / 60.0)
				if main.state == MAIN.CARD:
					main._end_card()
				if main.state == MAIN.APPROACH:
					break
			check(main.state == MAIN.APPROACH, "after strike %d the run goes on with a new approach" % (k + 1))
		else:
			for i in 60 * 3:
				main.advance(1.0 / 60.0)
				if main.state == MAIN.OVER:
					break
	check(main.state == MAIN.OVER, "the third crash ends the run")
	check(main.hud.overlay_visible and main.hud._ov_title.text == "RUN OVER", "the game-over screen shows")
	check(main.hud._ov_body.text.contains("Score  %d" % sc), "...with the score (the sum of the landings: %d)" % sc)
	# tap restarts in place
	main._death_time = Time.get_ticks_msec() / 1000.0 - 1.0
	var n_before_restart := nodes()
	var o_before := objects()
	var r_before := resources()
	tap()
	main._end_card()
	check(main.state == MAIN.APPROACH and main.strikes == 0 and main.score == 0 and main.round_no == 1, "a tap restarts the run IN PLACE (strikes 0, score 0, round 1)")
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
	var base_before: float = tn.trim_sink
	tp.open()
	check(tp.is_open and paused, "TUNE opens the panel and pauses the game")
	tp._sliders["trim_sink"].value = 4.4
	check(is_equal_approx(tn.trim_sink, 4.4), "moving a slider edits Tuning live (trim_sink = %.1f)" % tn.trim_sink)
	tp.copy_values()
	check(tp.last_copied_text.contains("trim_sink = 4.4"), "Copy values lists the changed value (%s)" % tp.last_copied_text.replace("\n", "; "))
	tp.reset_defaults()
	check(is_equal_approx(tn.trim_sink, base_before), "Reset puts the default back")
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
	while t_fly < 40.0:
		t_fly += 1.0 / 60.0
		var gs2: float = maxf(float(main.aircraft.gs), 4.0)
		var t_go2: float = maxf((float(main.airfield.aim_x) - float(main.aircraft.x)) / gs2, 0.5)
		var want2: float = clampf(-float(main.aircraft.y) / t_go2, -5.0, -2.5)
		var cmd2: float = (want2 + float(tn.trim_sink)) / float(tn.pitch_lift_gain)
		if main.aircraft.y < 2.5:
			cmd2 = (-(0.25 + 0.3 * float(main.aircraft.y)) + float(tn.trim_sink)) / float(tn.pitch_lift_gain)
		set_nose(cmd2)
		main.advance(1.0 / 60.0)
		var w2: float = main._cam_w
		if w2 > prev_w + 0.02 * prev_w + 0.3:
			zoom_ok = false
		bad_step = maxf(bad_step, absf(w2 - prev_w) / maxf(prev_w, 1.0))
		prev_w = w2
		if flare_w < 0.0 and main.aircraft.y < 6.0:
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
	check(d1_text.contains("30"), "...counting metres to the threshold (%s)" % d1_text)
	main.aircraft.reset(main.airfield.thr + 20.0, 5.0)
	main._update_hud(0.016)
	check(main.hud._dist.text.begins_with("ON RUNWAY"), "...then metres of runway left (%s)" % main.hud._dist.text)
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
	check(seen_scn.size() == 8, "the endless mix reaches every scenario (%d of 8)" % seen_scn.size())
	check(seen_wx.size() == 5, "...and every weather (%d of 5)" % seen_wx.size())
	check(early_ok, "rounds 1-2 are a clear standard approach")
	check(repeats == 0, "the same scenario never comes twice in a row")
	check(combos_ok, "unfair combinations (night fog, truck in weather, engine-out turbulence ...) are never picked")
	check(float(wx_late) / 41.0 > float(wx_early) / 6.0, "weather gets more frequent as the run goes on (%.0f %% early, %.0f %% late)" % [100.0 * wx_early / 6.0, 100.0 * wx_late / 41.0])
	# --- forcing (the ?tune panel and ?scenario= / ?weather=)
	DF.parse(["scenario=night", "weather=fog"] as Array[String])
	check(DF.scenario_forced() == 3 and DF.weather_forced() == 1, "?scenario=night&weather=fog parse")
	DF.parse(["scenario=nonsense"] as Array[String])
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
		if main.airfield.terrain != AF.TREES or main.airfield.rwy_len > 100.0 or main.airfield.tree_count < 3:
			short_ok = false
	check(short_ok, "short field: trees before a runway of 100 m or less")
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
	for i in 8:
		new_round(830 + i, 5)
		var plain_eo := fly_g(-1.0)
		if plain_eo["crash"]:
			short_x += 1
	for i in 8:
		new_round(830 + i, 5)
		var smart := fly_g(2.5)
		if not smart["crash"]:
			eo_land += 1
	check(short_x >= 3, "...left alone the glide falls short (%d of 8 crash short)" % short_x)
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
	check(afm.slope_m > 0.06 and afm.slope_m < 0.14, "mountain strip: the runway climbs (%.1f deg)" % rad_to_deg(atan(afm.slope_m)))
	check(afm.ground_y(afm.rwy_end) > afm.ground_y(afm.thr) + 5.0 and afm.ground_y(afm.thr) > 1.0, "...the ground rises along it (%.1f -> %.1f)" % [afm.ground_y(afm.thr), afm.ground_y(afm.rwy_end)])
	check(main._ramp_visible_for_test(), "...and the ramp and plateau are drawn")
	main.aircraft.reset(afm.aim_x, afm.ground_y(afm.aim_x) + 0.3)
	main.aircraft.vy = -2.0
	main.aircraft.gy = afm.ground_y(afm.aim_x)
	var gs_m: float = main.aircraft.gs
	main.advance(0.5)
	var expect_sink: float = 2.0 + gs_m * afm.slope_m
	check(main.last_result.has("sink") and absf(float(main.last_result["sink"]) - expect_sink) < 0.9, "...the ground rises to meet the plane: the sink rate counts that (%.1f, ~%.1f expected)" % [float(main.last_result.get("sink", 0.0)), expect_sink])
	new_round(851, 5)
	main.aircraft.reset(afm.thr - 40.0, afm.ground_y(afm.thr - 40.0) + 3.0)
	main.aircraft.vy = -3.0
	main.advance(1.5)
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
	main.aircraft.reset(af7.aim_x, af7.deck_h + 0.3)
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
		if not fly_g(3.0)["crash"]:
			carrier_ok += 1
	check(carrier_ok >= 6, "...and a good pilot lands on it (%d of 8)" % carrier_ok)

	# --- WATER
	force(6, 0)
	new_round(890, 5)
	var afw = main.airfield
	check(afw.surface == AF.WATER and main.aircraft._floats[0].visible and not main.aircraft._gear[0].visible, "seaplane: floats instead of wheels, on water")
	check(afw.in_lane(afw.aim_x) and not afw.in_lane(afw.thr - 20.0) and afw.on_runway(afw.thr - 20.0), "...a calm lane, rough water everywhere else (but you may land there)")
	main.aircraft.reset(afw.aim_x, 0.05)
	main.aircraft.vy = -1.6
	main.advance(0.3)
	var calm_sink: float = float(main.last_result.get("sink", 0.0))
	var calm_bounced: bool = main.last_result.get("bounced", true)
	new_round(891, 5)
	var afw2 = main.airfield
	main.aircraft.reset(afw2.thr - 25.0, 0.05)
	main.aircraft.vy = -1.6
	main.advance(0.3)
	var rough_sink: float = float(main.last_result.get("sink", 0.0))
	var rough_bounced: bool = main.last_result.get("bounced", false)
	check(calm_sink < 2.4 and not calm_bounced, "...the calm lane takes a firm touchdown without a bounce (sink %.1f)" % calm_sink)
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
	check(aft.surface == AF.TRUCK and aft.deck_h > 1.0 and aft.deck_speed > 5.0 and aft.rwy_len < 40.0, "truck: a short flatbed (%.0f m) driving at %.0f m/s" % [aft.rwy_len, aft.deck_speed])
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
		if not fly_g(2.0)["crash"]:
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
	for i in 60:
		main.advance(1.0 / 60.0)
		far_max = maxf(far_max, absf(tw.turb_v))
	var near_max := 0.0
	main.aircraft.reset(main.airfield.thr - 8.0, 25.0)
	for i in 300:
		main.aircraft.x = main.airfield.thr - 8.0
		main.aircraft.y = 25.0
		main.advance(1.0 / 60.0)
		near_max = maxf(near_max, absf(tw.turb_v))
	check(near_max > 0.6 and near_max > far_max * 2.0, "turbulence: rough air builds on final (%.2f near the runway, %.2f far out)" % [near_max, far_max])
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

func force(scn: int, wx: int) -> void:
	SC.forced_scenario = scn
	SC.forced_weather = wx

func _touch(pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.position = Vector2(540, 900)
	e.pressed = pressed
	return e

## Fly the current approach with an autopilot that knows about slopes, moving decks and engine-out: steer to the aim
## point (closing speed = ground speed - deck speed), then flare at `flare_h` above the ground with a sink rate that
## eases down with the height (relative to the ground). flare_h < 0 = never flare.
func fly_g(flare_h: float) -> Dictionary:
	var ac = main.aircraft
	var af = main.airfield
	main.last_result = {}
	var t := 0.0
	while t < 70.0:
		t += 1.0 / 60.0
		var gs: float = maxf(float(ac.gs), 4.0)
		var m: float = af.slope_at(ac.x)
		var agl: float = ac.agl()
		var trim: float = float(tn.trim_sink) * float(ac.sink_mult)
		var cmd := 0.0
		if flare_h < 0.0 or agl > flare_h:
			var closing: float = maxf(gs - float(af.deck_speed), 4.0)
			var t_go: float = maxf((float(af.aim_x) - float(ac.x)) / closing, 0.5)
			var want_rel: float = clampf(-agl / t_go, -5.0, -2.5)
			cmd = (want_rel + gs * m + trim) / float(tn.pitch_lift_gain)
		else:
			var want: float = -(0.25 + 0.3 * agl) + gs * m
			cmd = (want + trim) / float(tn.pitch_lift_gain)
		set_nose(cmd)
		main.advance(1.0 / 60.0)
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
