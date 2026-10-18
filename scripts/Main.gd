class_name Main
extends Node3D
## Game flow: menu -> approach -> touchdown (graded) -> rollout -> fade -> next approach on a new random
## runway. A crash (hard landing, off the runway, trees, overrun) is a strike; the third ends the run.
## Everything is built once in _ready (and pre-warmed behind a splash); restarts and new rounds reuse it.

enum { MENU, APPROACH, ROLLOUT, CRASH, FADE, OVER }

var rng := RandomNumberGenerator.new()
var camera: Camera3D
var sun: DirectionalLight3D
var airfield: Airfield
var aircraft: Aircraft
var fx: Fx
var sfx: Sfx
var hud: Hud
var wind := Wind.new()
var tune_panel: TunePanel

var state := MENU
var round_no := 0
var strikes := 0
var score := 0
var best := 0
var landings := 0
var last_result: Dictionary = {}     # the latest graded landing
var last_crash := ""                 # why the latest crash happened
var test_mode := false               # tests drive advance() themselves
var sim_time := 0.0

var _timer := 0.0                    # seconds in the current state
var _graded := false                 # this approach's touchdown has been graded (a bounce is still flying)
var _awarded := 0                    # points that landing gave (taken back if the bounce ends in a crash)
var _shake := 0.0
var _puff_t := 0.0
var _cam_w := 54.0
var _cam_x := 0.0
var _cam_y := 0.0
var _cam_dx := 0.0
var _tilt := 9.0
var _full_w := 120.0          # this round's wide framing (plane start .. runway end) ...
var _full_left := 0.0         # ... and its left edge
var _start_x := 0.0           # where the plane started this approach
var _dist_key := -1           # what the runway distance readout shows (rebuilt only when it changes)
var _after_fade_over := false
var _death_time := 0.0
var _warming := false
var _haptic_warmed := false
static var _warmed := false

func _ready() -> void:
	Engine.max_physics_steps_per_frame = 1   # no physics here: a stall can never trigger catch-up steps
	if DebugFlags.seed_number() >= 0:
		rng.seed = DebugFlags.seed_number()
	else:
		rng.randomize()
	best = Save.load_best()
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.35, -0.7, -0.62))
	sun.shadow_enabled = false
	sun.light_energy = 1.0
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = 0.1
	camera.far = 400.0
	camera.size = Tuning.view_width_low
	_setup_environment()
	airfield = Airfield.new()
	add_child(airfield)
	aircraft = Aircraft.new()
	add_child(aircraft)
	fx = Fx.new()
	add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)
	hud = Hud.new()
	add_child(hud)
	if DebugFlags.tune_enabled():
		tune_panel = TunePanel.new()
		add_child(tune_panel)
		tune_panel.build()
		tune_panel.changed.connect(_on_tuning_changed)
		tune_panel.skip_round.connect(skip_round)
	round_no = DebugFlags.first_round() - 1
	_begin_round()
	_snap_camera()
	if not _warmed:
		_warmed = true
		if DebugFlags.prewarm_enabled():
			_prewarm()
	if not _warming:
		_show_menu()
		if tune_panel:
			tune_panel.set_available(true)

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.78, 0.96)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

## First-use stutter fix: GL shaders / particle buffers / font glyphs set themselves up the first time they are
## used. So at boot, behind a splash, draw EVERY pooled thing for real (every tree, dash, streak, smoke and fire
## emitter, popup and overlay text) and KEEP drawing until frame times settle. Then hide it all. Runs once;
## new rounds and restarts never reload anything. Skip with ?noprewarm.
func _prewarm() -> void:
	_warming = true
	var spot := Vector3(aircraft.x + 8.0, 2.0, 0.0)
	hud.begin_prewarm()
	airfield.prewarm_show()
	if tune_panel:
		tune_panel.prewarm_show(true)
	var t_start := Time.get_ticks_msec()
	var t_last := t_start
	var t_refresh := -100000
	var calm_frames := 0
	while true:
		var now := Time.get_ticks_msec()
		if now - t_refresh > 350:
			t_refresh = now
			fx.show_all(spot)
			hud.prewarm_popups()
		airfield.update(0.016, _cam_x, _cam_w, 4.0)
		await get_tree().process_frame
		var t := Time.get_ticks_msec()
		calm_frames = calm_frames + 1 if (t - t_last) < Tuning.prewarm_stable_ms else 0
		t_last = t
		var elapsed_s := (t - t_start) / 1000.0
		if elapsed_s >= Tuning.prewarm_max_seconds:
			break
		if elapsed_s >= Tuning.prewarm_min_seconds and calm_frames >= Tuning.prewarm_stable_frames:
			break
	fx.clear()
	airfield.prewarm_hide()
	hud.end_prewarm()
	if tune_panel:
		tune_panel.prewarm_show(false)
		tune_panel.set_available(true)
	_warming = false
	_show_menu()

# ---------- run / round flow ----------

func _show_menu() -> void:
	state = MENU
	hud.show_menu(best)
	hud.set_flight(0.0, 0.0, 1.0, false)
	hud.set_hint("")

## Start a fresh run IN PLACE: nothing is reloaded, created or freed.
func start_run() -> void:
	score = 0
	strikes = 0
	landings = 0
	round_no = DebugFlags.first_round() - 1
	last_result = {}
	last_crash = ""
	sim_time = 0.0
	hud.hide_overlay()
	hud.clear_popup()
	hud.set_score(0)
	hud.set_strikes(0)
	hud.set_fade_now(0.0)
	fx.clear()
	get_tree().paused = false
	_begin_round()
	_snap_camera()

## Choose and lay out the next runway and put the plane on its approach.
func _begin_round() -> void:
	round_no += 1
	airfield.generate(round_no, rng)
	airfield.build()
	var r := Tuning.ramp(round_no)
	wind.reset(airfield.wind_base, rng, rng.randf_range(2.0, 3.5))
	aircraft.reset(0.0, airfield.start_altitude)
	_start_x = aircraft.x
	_compute_full_frame()
	airfield.update_papi(aircraft.x, aircraft.y)
	_dist_key = -1
	_graded = false
	_awarded = 0
	_timer = 0.0
	_puff_t = 0.0
	_shake = 0.0
	state = APPROACH
	hud.set_round(round_no)
	hud.set_runway("%s  %d m  %s" % [Airfield.SURFACE_NAMES[airfield.surface].to_upper(), int(airfield.rwy_len), _terrain_text()])
	hud.set_wind(wind.head())
	hud.set_hint("Drag UP to raise the nose, DOWN to lower it.\nKeep the PAPI lights 2 white + 2 red.\nFlare just before touchdown." if round_no == 1 and landings == 0 else "")
	hud.set_fade_now(hud.fade_alpha())
	hud.fade_to(0.0)
	_gust_scale = 0.5 + 0.5 * r

var _gust_scale := 0.5

func _terrain_text() -> String:
	match airfield.terrain:
		Airfield.TREES:
			return "trees ahead"
		Airfield.HILL:
			return "hill ahead"
	return ""

## ?tune "Next round" and tests: abandon this approach and fly a new one.
func skip_round() -> void:
	if state == APPROACH or state == ROLLOUT:
		_begin_round()
		_snap_camera()

# ---------- frame loop ----------

var _skip_frames := 0
var _suspended := false
var _paused_since_ms := 0
var _paused_total_ms := 0
var _run_start_ms := 0
var _event := ""
var _event_frame := -100

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if not _suspended:
				_suspended = true
				_paused_since_ms = Time.get_ticks_msec()
				_event = "window went to the background"
				_event_frame = Engine.get_process_frames()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if _suspended:
				_suspended = false
				_paused_total_ms += Time.get_ticks_msec() - _paused_since_ms
				_skip_frames = Tuning.resume_skip_frames
				aircraft.clear_input()   # (the drag that piled up while away must not jerk the nose)
				_event = "window came back"
				_event_frame = Engine.get_process_frames()

## The part of this real frame (`raw` seconds) the simulation may use: 0 to skip it. However long the frame
## was, the simulation advances by at most max_frame_delta; a stall (a tab switch) is dropped, not simulated.
func _frame_delta(raw: float) -> float:
	var used := 0.0
	var why := ""
	if _suspended:
		why = "window in the background"
	elif _skip_frames > 0:
		_skip_frames -= 1
		why = "skipped (resuming)"
	elif raw > Tuning.stall_delta:
		_skip_frames = Tuning.resume_skip_frames
		why = "stall dropped"
	else:
		used = minf(raw, Tuning.max_frame_delta)
		why = "clamped" if raw > Tuning.max_frame_delta else ""
	if raw > 0.05 and DebugFlags.perf_enabled():
		var ctx := _event if Engine.get_process_frames() - _event_frame <= 4 and _event != "" else "state %d" % state
		hud.note_hitch(raw, used, why, ctx)
	return used

func _process(raw_delta: float) -> void:
	if _warming or test_mode:
		return
	var dt := _frame_delta(raw_delta)
	if DebugFlags.perf_enabled():
		hud.set_clock(sim_time, maxf((Time.get_ticks_msec() - _run_start_ms - _paused_total_ms) / 1000.0, 0.0))
	advance(dt)

## One frame of the whole game (tests call this directly with a fixed dt).
func advance(dt: float) -> void:
	if dt > 0.0:
		_timer += dt
		match state:
			APPROACH:
				_step_approach(dt)
			ROLLOUT:
				_step_rollout(dt)
			CRASH:
				if _timer >= Tuning.crash_pause:
					_leave_crash()
			FADE:
				if hud.fade_alpha() >= 0.999 and _timer >= Tuning.fade_time:
					if _after_fade_over:
						_show_over()
					else:
						_begin_round()
						_snap_camera()
		if state == APPROACH or state == ROLLOUT:
			sim_time += dt
		_shake = maxf(_shake - Tuning.shake_decay * dt * (0.4 + _shake), 0.0)
	aircraft.update_visual(dt)
	_update_camera(dt)
	airfield.drift_streaks(dt, _cam_dx, wind.head(), _cam_w)
	airfield.update(dt, _cam_x, _cam_w, wind.head())
	_update_hud(dt)

func _step_approach(dt: float) -> void:
	wind.update(dt, rng, _gust_scale)
	if wind.gust_started:
		wind.gust_started = false
		aircraft.kick(1.0 if wind.gust_v > 0.0 else -1.0)
		hud.flash_gust()
		sfx.play(Sfx.WHOOSH, rng.randf_range(0.9, 1.2), -12.0)
	aircraft.consume_input(dt)
	airfield.update_papi(aircraft.x, aircraft.y)
	var n := maxi(ceili(dt / Tuning.sim_step), 1)
	var h := dt / float(n)
	for i in n:
		aircraft.step_air(h, wind.head(), wind.gust_v, wind.gust_h)
		# trees / hill
		var obstacle := airfield.height_at(aircraft.x)
		if obstacle > 0.0 and aircraft.y < obstacle and not DebugFlags.god_enabled():
			_crash("Hit the trees!" if airfield.terrain == Airfield.TREES else "Hit the hill!")
			return
		if aircraft.y <= 0.0:
			_touchdown()
			return
		if aircraft.x > airfield.rwy_end + 4.0 and not DebugFlags.god_enabled():
			_crash("Flew past the runway!")
			return

func _step_rollout(dt: float) -> void:
	wind.update(dt, rng, _gust_scale * 0.3)
	var decel := airfield.surface_decel()
	var n := maxi(ceili(dt / Tuning.sim_step), 1)
	var h := dt / float(n)
	for i in n:
		aircraft.step_ground(h, decel)
		if aircraft.x > airfield.rwy_end and aircraft.gs > Tuning.overrun_speed and not DebugFlags.god_enabled():
			_crash("Overran the runway!")
			return
	# puffs of dust / smoke while the wheels still bite hard
	_puff_t -= dt
	if _puff_t <= 0.0 and aircraft.gs > 6.0 and (airfield.surface != Airfield.ASPHALT or _timer < 0.6):
		_puff_t = Tuning.roll_puff_interval * 3.0
		fx.smoke(Vector3(aircraft.x - 1.0, 0.3, 1.0), 0.25 + aircraft.gs / 60.0, airfield.smoke_color())
	var rest := aircraft.gs <= Tuning.rollout_rest_speed and _timer >= Tuning.rollout_min_time
	if rest or _timer >= Tuning.rollout_max_time:
		_finish_round(false)

# ---------- touchdown ----------

func _touchdown() -> void:
	var sink := -aircraft.vy
	var px := aircraft.x
	aircraft.y = 0.0
	var wheels := Vector3(px - 0.4, 0.25, 1.0)
	if Grading.is_crash_sink(sink) and not DebugFlags.god_enabled():
		_crash("Too hard!" if airfield.on_runway(px) else "Off the runway!")
		return
	if not airfield.on_runway(px) and not DebugFlags.god_enabled():
		_crash("Off the runway!")
		return
	var bounced := sink > Tuning.bounce_sink
	if not _graded:
		_graded = true
		last_result = Grading.evaluate(sink, px - airfield.aim_x, airfield.rwy_len, bounced)
		last_result["sink"] = sink
		last_result["offset"] = px - airfield.aim_x
		last_result["bounced"] = bounced
		_awarded = int(last_result["total"])
		score += _awarded
		landings += 1
		hud.set_score(score)
		var g: int = last_result["grade"]
		var sub := "Sink %.1f   %s%.0f m from the markers   %s   +%d" % [
			sink, "+" if px >= airfield.aim_x else "", px - airfield.aim_x, "BOUNCED" if bounced else "no bounce", _awarded]
		hud.popup(Grading.NAMES[g], sub, Grading.COLORS[g], Tuning.popup_time)
		hud.set_hint("")
		if g <= 1:
			sfx.play(Sfx.CHIME, 1.0 + 0.12 * float(1 - g), -6.0)
	var power := clampf(0.25 + sink / 5.0, 0.2, 1.0)
	fx.smoke(wheels, power, airfield.smoke_color())
	sfx.play(Sfx.SQUEAK, rng.randf_range(0.9, 1.15), -4.0 + minf(sink, 4.0))
	if sink > 1.6:
		sfx.play(Sfx.THUD, rng.randf_range(0.9, 1.1), -6.0 + minf(sink, 4.0) * 1.5)
	if not DebugFlags.off("shake"):
		_shake = maxf(_shake, clampf((sink - Tuning.shake_min_sink) * Tuning.shake_per_sink, 0.0, Tuning.shake_max))
	if sink > 1.2 and not DebugFlags.off("haptic"):
		Input.vibrate_handheld(int(clampf(sink * 25.0, 20.0, 150.0)))
	if bounced:
		aircraft.bounce(sink * Tuning.bounce_restitution)
		return
	aircraft.land()
	state = ROLLOUT
	_timer = 0.0
	_puff_t = 0.0

# ---------- crash / round end ----------

func _crash(reason: String) -> void:
	last_crash = reason
	strikes += 1
	score -= _awarded            # a landing that ends in a crash (bounce into trees) doesn't count
	if _awarded > 0:
		landings -= 1
		hud.set_score(score)
	_awarded = 0
	hud.set_strikes(strikes)
	hud.popup("CRASH", reason, Color(1.0, 0.35, 0.3), Tuning.crash_pause)
	hud.set_hint("")
	fx.crash(Vector3(aircraft.x, maxf(aircraft.y, 0.0) + 1.5, 0.5))
	fx.smoke(Vector3(aircraft.x, 0.4, 1.0), 1.0, Color(0.25, 0.25, 0.25))
	sfx.play(Sfx.CRASH, 1.0, 0.0)
	if not DebugFlags.off("shake"):
		_shake = 1.0
	if not DebugFlags.off("haptic"):
		Input.vibrate_handheld(300)
	aircraft.visible = false
	state = CRASH
	_timer = 0.0

func _leave_crash() -> void:
	_finish_round(strikes >= Tuning.strikes_max)

## The landing (or crash) is over: fade out, then a new approach (or the end of the run).
func _finish_round(over: bool) -> void:
	_after_fade_over = over
	state = FADE
	_timer = 0.0
	hud.fade_to(1.0)

func _show_over() -> void:
	state = OVER
	_death_time = Time.get_ticks_msec() / 1000.0
	var new_best := score > best
	if new_best:
		best = score
		Save.store_best(best)
	hud.fade_to(0.0)
	hud.clear_popup()
	hud.show_over(score, best, landings, new_best)

# ---------- camera / HUD ----------

## This round's wide framing: the plane at the left edge and the whole runway on screen.
func _compute_full_frame() -> void:
	var span := airfield.rwy_end + 30.0 - _start_x
	_full_w = clampf(span * 1.1, Tuning.view_width_low * 1.5, Tuning.view_width_full_max)
	_full_left = _start_x - 0.07 * _full_w

## 0 = the wide framing at the start of the approach, 1 = the close flare framing. Driven by the distance to the aim
## markers (and forced by a low altitude), eased so the zoom starts and ends gently.
func _closeness() -> float:
	var d0 := maxf(airfield.aim_x - _start_x, 1.0)
	var d := airfield.aim_x - aircraft.x
	var by_dist := clampf((d0 - d) / maxf(d0 - Tuning.zoom_close_distance, 1.0), 0.0, 1.0)
	var by_alt := clampf((Tuning.zoom_high_altitude - aircraft.y) / maxf(Tuning.zoom_high_altitude - Tuning.zoom_low_altitude, 1.0), 0.0, 1.0)
	return smoothstep(0.0, 1.0, maxf(by_dist, by_alt))

func _snap_camera() -> void:
	_update_camera(0.0, true)

func _aspect() -> float:
	var vs := get_viewport().get_visible_rect().size
	return vs.y / maxf(vs.x, 1.0)

## Frame the camera: width from the zoom progress, the left edge sliding from "plane at the far left, runway ahead"
## to "plane at plane_screen_x", the tilt and ground height easing with the width. `snap` jumps there at once.
func _update_camera(dt: float, snap: bool = false) -> void:
	var k := 1.0 if snap else (1.0 - exp(-Tuning.camera_smoothing * dt) if dt > 0.0 else 0.0)
	var b := _closeness()
	_cam_w = lerpf(_cam_w, lerpf(_full_w, Tuning.view_width_low, b), k)
	var left := lerpf(_full_left, aircraft.x - _cam_w * Tuning.plane_screen_x, b)
	var old_x := _cam_x
	_cam_x = left + _cam_w * 0.5
	_cam_dx = 0.0 if snap else _cam_x - old_x
	var wide := clampf((_cam_w - Tuning.view_width_low) / 200.0, 0.0, 1.0)
	_tilt = lerpf(Tuning.camera_tilt_deg, Tuning.camera_tilt_wide_deg, wide)
	var h := _cam_w * _aspect()
	var ground_y := lerpf(Tuning.ground_screen_y, Tuning.ground_screen_y_wide, wide)
	_cam_y = lerpf(_cam_y, (0.5 - ground_y) * h / cos(deg_to_rad(_tilt)), k)
	aircraft.set_view_scale(_cam_w)
	_apply_camera()

func _apply_camera() -> void:
	camera.size = _cam_w
	var tilt := deg_to_rad(_tilt)
	var dist := 80.0
	var ox := 0.0
	var oy := 0.0
	if _shake > 0.001:
		ox = rng.randf_range(-1.0, 1.0) * _shake * Tuning.shake_size
		oy = rng.randf_range(-1.0, 1.0) * _shake * Tuning.shake_size
	camera.position = Vector3(_cam_x + ox, _cam_y + oy + dist * sin(tilt), dist * cos(tilt))
	camera.rotation = Vector3(-tilt, 0.0, 0.0)

func _update_hud(dt: float) -> void:
	var flying := state == APPROACH
	hud.set_flight(aircraft.y, aircraft.vy, aircraft.s, flying and not hud.overlay_visible)
	if state == APPROACH or state == ROLLOUT:
		hud.set_wind(wind.head())
		_update_distance()
	elif _dist_key != -1:
		_dist_key = -1
		hud.set_distance("")
	hud.update(dt)

## Runway distance readout: metres to the threshold, then metres of runway left. Text rebuilt only when the number changes.
func _update_distance() -> void:
	var to_thr := airfield.thr - aircraft.x
	var key := -1
	var text := ""
	if to_thr > 0.5:
		key = int(roundf(to_thr))
		text = "RUNWAY  %d m" % key
	elif aircraft.x <= airfield.rwy_end:
		key = 100000 + int(roundf(airfield.rwy_end - aircraft.x))
		text = "ON RUNWAY  %d m left" % (key - 100000)
	if key != _dist_key:
		_dist_key = key
		hud.set_distance(text)

func _on_tuning_changed(property: String) -> void:
	if property == "outline_thickness":
		pass
	if property == "wind_enabled":
		wind.reset(airfield.wind_base if Tuning.wind_enabled else 0.0, rng)

# ---------- input ----------

func _input(event: InputEvent) -> void:
	# A touch on the tuning panel's TUNE button belongs to the button, not the game.
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and TunePanel.button_hit(event.position):
		return
	# Browsers only allow vibration after a touch, and the first real call connects to the device's vibration
	# service: make an imperceptible 1 ms pulse on the very first touch, not on the first landing.
	if not _haptic_warmed and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		_haptic_warmed = true
		if not DebugFlags.off("haptic"):
			Input.vibrate_handheld(1)
	if event is InputEventScreenTouch and event.pressed:
		if state == MENU and not _warming:
			_run_start_ms = Time.get_ticks_msec()
			_paused_total_ms = 0
			start_run()
		elif state == OVER and Time.get_ticks_msec() / 1000.0 - _death_time > 0.6:
			_run_start_ms = Time.get_ticks_msec()
			_paused_total_ms = 0
			start_run()
