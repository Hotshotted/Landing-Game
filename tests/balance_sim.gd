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

func load_classes() -> void:
	MAIN = load("res://scripts/Main.gd")
	AF = load("res://scripts/Airfield.gd")
	GR = load("res://scripts/Grading.gd")
	TP = load("res://scripts/TunePanel.gd")
	DF = load("res://scripts/DebugFlags.gd")
	SV = load("res://scripts/Save.gd")
	WIND = load("res://scripts/Wind.gd")
	AC = load("res://scripts/Aircraft.gd")


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
	report("no flare", -1.0, 0.0)
	for bias in [0.0, -12.0, -20.0, -28.0]:
		for fh in [2.5, 4.0, 6.0]:
			aim_bias = bias
			report("smart from %.1f aim%+.0f" % [fh, bias], fh, 0.0)
	aim_bias = -15.0
	for fh in [1.0, 2.0, 3.0, 4.0, 6.0, 10.0]:
		report("hold 5.5 from %.1f aim-15" % fh, fh, 5.5)
	quit()

func report(label: String, flare_h: float, flare_theta: float) -> void:
	var counts := [0, 0, 0, 0, 0]
	var crashes := 0
	var total := 0
	var sinks := 0.0
	var offs := 0.0
	var n := 48
	for i in n:
		main.rng.seed = 1000 + i
		main.start_run()
		main.round_no = 1 + (i % 12)       # spread over the difficulty ramp
		main._begin_round()
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
	while t < 60.0:
		t += 1.0 / 60.0
		var gs: float = maxf(float(ac.gs), 4.0)
		var cmd := 0.0
		if flare_h < 0.0 or ac.y > flare_h:
			var t_go: float = maxf((af.aim_x + aim_bias - ac.x) / gs, 0.5)
			var want_vy: float = clampf(-ac.y / t_go, -5.0, -2.5)
			cmd = (want_vy + float(tn.trim_sink)) / float(tn.pitch_lift_gain)
		elif flare_theta > 0.0:
			cmd = flare_theta
		else:
			var want: float = -(0.25 + 0.3 * float(ac.y))
			cmd = (want + float(tn.trim_sink)) / float(tn.pitch_lift_gain)
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
