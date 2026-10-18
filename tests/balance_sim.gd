extends SceneTree
## Autopilot balance check:  godot --headless --path . --script res://tests/balance_sim.gd
## Flies many rounds with a simple autopilot (steer onto the aim markers, then flare at a chosen height) and
## prints how the landings grade, so the feel values in Tuning can be judged without a phone. Not run by CI.

var main: Node3D
var tn: Node
var aim_bias := 0.0
var reasons := {}
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


func _init() -> void:
	await process_frame
	tn = root.get_node("/root/Tuning")
	load_classes()
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.test_mode = true
	SV.enabled = false
	for scn in range(8):
		SC.forced_scenario = scn
		SC.forced_weather = 0
		for fh in [2.5, 4.0]:
			report("%-10s smart from %.1f" % [SC.KEYS[scn], fh], fh, 0.0)
	SC.forced_scenario = 0
	for wx in range(1, 5):
		SC.forced_weather = wx
		report("std + %-10s" % SC.WX_KEYS[wx], 3.0, 0.0)
	quit()

func report(label: String, flare_h: float, flare_theta: float) -> void:
	var counts := [0, 0, 0, 0, 0]
	var crashes := 0
	var total := 0
	var sinks := 0.0
	var offs := 0.0
	var n := 20
	for i in n:
		main.rng.seed = 1000 + i
		main.start_run()
		main.round_no = 3 + (i % 10)       # spread over the difficulty ramp
		main._begin_round(false)
		var res := fly(flare_h, flare_theta)
		if res == "crash":
			crashes += 1
			reasons[main.last_crash] = int(reasons.get(main.last_crash, 0)) + 1
		elif main.last_result.has("grade"):
			counts[main.last_result["grade"]] += 1
			total += int(main.last_result["total"])
			sinks += float(main.last_result["sink"])
			offs += absf(float(main.last_result["offset"]))
	var landed := n - crashes
	var rs := ""
	for k in reasons:
		rs += " %s x%d" % [k, reasons[k]]
	reasons.clear()
	print("%-28s crashes %2d | Greaser %2d Smooth %2d Good %2d Firm %2d Hard %2d | avg pts %3.0f sink %.2f |off| %.1f" % [
		label, crashes, counts[0], counts[1], counts[2], counts[3], counts[4],
		float(total) / maxf(landed, 1), sinks / maxf(landed, 1), offs / maxf(landed, 1)]  + rs)

## Fly one approach to the end; "crash" or "landed". flare_theta > 0 holds that nose angle, <= 0 eases the sink down with height.
func fly(flare_h: float, flare_theta: float) -> String:
	var ac = main.aircraft
	var af = main.airfield
	main.last_result = {}
	var t := 0.0
	while t < 70.0:
		t += 1.0 / 60.0
		var gs: float = maxf(float(ac.gs), 4.0)
		var m: float = af.slope_at(ac.x)
		var agl: float = ac.agl()
		var cmd: float = 0.0
		var power_trim: float = float(tn.trim_sink) * float(ac.sink_mult)
		if flare_h < 0.0 or agl > flare_h:
			var closing: float = maxf(gs - float(af.deck_speed), 4.0)
			var t_go: float = maxf((af.aim_x + aim_bias - ac.x) / closing, 0.5)
			var want_rel: float = clampf(-agl / t_go, -5.0, -2.5)
			cmd = (want_rel + gs * m + power_trim) / float(tn.pitch_lift_gain)
		else:
			var want: float = -(0.25 + 0.3 * agl) + gs * m
			cmd = (want + power_trim) / float(tn.pitch_lift_gain)
		var dy: float = -(cmd - ac.theta_target) / (float(tn.pitch_per_pixel) * float(tn.sensitivity))
		ac.touching = true
		ac.add_drag(dy)
		main.advance(1.0 / 60.0)
		if main.state == MAIN.CRASH:
			main.advance(float(tn.crash_pause) + 0.1)
			return "crash"
		if main.state == MAIN.ROLLOUT or main.state == MAIN.FADE:
			return "landed"
	return "timeout"
