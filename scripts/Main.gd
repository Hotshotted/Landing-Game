class_name Main
extends Node3D
## Game flow: menu -> title card -> approach -> touchdown (graded) -> rollout -> fade -> next approach (a new scenario and
## weather on a new random runway). A crash (hard landing, off the runway, trees, overrun) is a strike; the third ends the run.
## Everything is built once in _ready (and pre-warmed behind a splash); restarts and new rounds reuse it.

enum { MENU, APPROACH, ROLLOUT, CRASH, FADE, OVER, CARD, AD, CHOICE, CASHOUT }
enum { FREE, RIDE, DAILY, PRACTICE }      # what the current run is: endless free flight, a checkride, the daily approach, or one practice landing

var rng := RandomNumberGenerator.new()
var camera: Camera3D
var sun: DirectionalLight3D
var airfield: Airfield
var aircraft: Aircraft
var fx: Fx
var sfx: Sfx
var _page_hidden := false       # the page is in the background (web) or the window lost focus
var _audio_hold := false        # the sound is held silent until the player taps (Resume, or any tap on a menu)
var hud: Hud
var wind := Wind.new()
var tune_panel: TunePanel
var fog: FogOverlay
var scenario := 0
var weather := 0
var plane_id := Planes.C172     # the aircraft in use
var streak := 0                 # consecutive Greaser! landings
var best_streak := 0
var mode := FREE
var ride_target := 0            # checkride: the rank it earns
var ride_idx := 0               # checkride: which landing (0-based)
var ride_fails: Array[String] = []
var practice_entry: Dictionary = {}       # the practice landing being flown: {scn, wx, plane, seed, round}
var _career_rng := RandomNumberGenerator.new()
var ride_draw: Array[Dictionary] = []     # the checkride's landings, drawn when it is booked: {scn, wx, plane, seed, round}
var ride_passed := false        # the finished checkride was passed
var ride_fee_paid := 0
var ride_fail_type := -1        # the landing type that failed the checkride
var _apt_rng := RandomNumberGenerator.new()   # picks the airport name (its own stream, so the approach itself is unaffected)
var airport_idx := 0            # which named airport of this scenario this approach is at
var _flight_acc := 0.0          # seconds flown since the last save
var _over_kind := ""            # what the OVER screen shows: "run", "ride_fail", "ride_pass"
var _saved_plane := Planes.C172
var run_coins := 0              # coins earned this run (the rewarded ad can double them)
var _coins_award := 0           # coins the latest landing gave (taken back if its bounce ends in a crash)
var _coins_doubled := false
var _daily_day := 0
var _ad_t := 0.0                # fake ad: seconds left
var _ad_kind := ""              # "double", "fee" or "interstitial"
var _standard: Dictionary = {}  # the standard this approach is judged on (Standards.for_type)
var last_verdict: Dictionary = {}    # the verdict on the latest landing: {pass, fails}
var _gate_dev_kt := INF         # airspeed at the 50 ft gate minus Vref (INF = not measured yet)
var _nose_ok := true            # soft field: the nose was held off
var _papi_run := 0.0            # instrument approach: seconds in a row off the glide path
var _papi_worst := 0.0          # ... and the longest such stretch
var _bump_t := 0.0
var _touch_gs := 0.0            # ground speed at the touchdown that started the rollout
var _instr_open := 0.0          # instrument approach: 0 = in the fog, 1 = the runway has appeared
var _min_agl := 9999.0          # lowest the plane has been above the ground this approach (for the no-go-around rule)

var state := MENU
var round_no := 0
var strikes := 0
var pot := 0                    # free flight: coins earned this run and not banked yet (lost with a crash)
var banked := 0                 # coins this run banked by cashing out
var pot_lost := 0               # the pot that went down with the aircraft
var rental_paid := 0            # this run's rental fee
var damage_paid := 0            # this run's damage fee (a rented aircraft crashed)
var _lesson_active := false     # the practice landing in progress is a paid instructor lesson (counts double)
var _next_pick := Vector2i(-1, -1)   # the next approach's scenario / weather, chosen when the choice screen shows its hint
var _cash_t := 0.0
var _next_round := -1           # the round number _next_pick is for
var _cash_shown := 0
var _paused_run := false        # the pause menu is up
var _pause_confirm := ""        # "quit" while the quit confirmation is showing
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
var _turb_shake := 0.0         # a steady little camera shake in turbulence
var _puff_t := 0.0
var _cam_w := 54.0
var _cam_x := 0.0
var _cam_y := 0.0
var _cam_dx := 0.0
var _tilt := 9.0
var _full_w := 120.0          # this round's wide framing (plane start .. runway end) ...
var _full_left := 0.0         # ... and its left edge
var _start_agl := 20.0          # the plane's height above the ground at the start of the approach
var _start_x := 0.0           # where the plane started this approach
var _dist_key := -1           # what the runway distance readout shows (rebuilt only when it changes)
var _env: Environment
var _last_scenario := -1
var _arrested := false        # carrier: the hook has caught a wire
var _shear_state := 0         # wind shear: 0 = not yet, 1 = warned (windsock snapped), 2 = hit
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
	_apt_rng.randomize()
	_career_rng.randomize()
	if not DebugFlags.ads_enabled():
		Ads.enabled = false
	Save.load_data()
	best = Save.load_best()
	_setup_audio()
	sun = DirectionalLight3D.new()
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.35, -0.7, -0.62))
	sun.shadow_enabled = false
	sun.light_energy = 1.0
	camera = Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.near = 3.0
	camera.far = 160.0
	camera.size = Tuning.view_width_low
	_setup_environment()
	if DebugFlags.scenario_forced() >= 0:
		Scenarios.forced_scenario = DebugFlags.scenario_forced()
	if DebugFlags.weather_forced() >= 0:
		Scenarios.forced_weather = DebugFlags.weather_forced()
	airfield = Airfield.new()
	add_child(airfield)
	aircraft = Aircraft.new()
	add_child(aircraft)
	fx = Fx.new()
	add_child(fx)
	sfx = Sfx.new()
	add_child(sfx)
	fog = FogOverlay.new()
	add_child(fog)
	hud = Hud.new()
	add_child(hud)
	UiButton.on_down = _on_button_down
	Style.detect_safe(get_viewport().get_visible_rect().size)
	hud.apply_safe()
	hud.ui_sound.connect(_on_ui_sound)
	sfx.page_hidden.connect(_on_page_hidden)
	hud.plane_step.connect(_on_plane_step)
	hud.menu_action.connect(_on_menu_action)
	hud.choice.connect(_on_choice)
	hud.pause_action.connect(_on_pause_action)
	hud.volume_changed.connect(_on_volume_changed)
	hud.hangar_pick.connect(_on_hangar_pick)
	if DebugFlags.tune_enabled():
		tune_panel = TunePanel.new()
		add_child(tune_panel)
		tune_panel.build()
		tune_panel.changed.connect(_on_tuning_changed)
		tune_panel.skip_round.connect(skip_round)
		tune_panel.debug_action.connect(_on_debug_action)
	plane_id = clampi(int(Save.data["plane"]), 0, Planes.COUNT - 1)
	if not available_planes().has(plane_id):
		plane_id = available_planes()[0]
	if DebugFlags.plane_forced() >= 0:
		plane_id = DebugFlags.plane_forced()
	round_no = DebugFlags.first_round() - 1
	_refresh_selector()
	_apply_cosmetics()
	_begin_round(false)
	_snap_camera()
	if not _warmed:
		_warmed = true
		if DebugFlags.prewarm_enabled():
			_prewarm()
	if not _warming:
		await _logo_intro()
		_show_menu()
		if tune_panel:
			tune_panel.set_available(true)
		_open_debug_screen()

func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS      # the sky is a gradient shader on a canvas layer behind the 3D world
	env.background_canvas_max_layer = -1
	env.background_color = Color(0.55, 0.78, 0.96)
	_sky_layer = CanvasLayer.new()
	_sky_layer.layer = -1
	add_child(_sky_layer)
	_sky_rect = ColorRect.new()
	_sky_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = preload("res://shaders/sky.gdshader")
	_sky_rect.material = _sky_mat
	_sky_layer.add_child(_sky_rect)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 0.55
	_env = env
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

## The studio logo, once, at the first start (skipped headless, with ?nologo and when a screen is opened on purpose).
func _logo_intro() -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.gameReady && window.gameReady()")     # (the page's loading screen fades out)
	if DebugFlags.nologo or DisplayServer.get_name() == "headless" or DebugFlags.screen() != "":
		return
	hud.start_logo()
	await hud.logo_finished

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
	await _logo_intro()
	_show_menu()
	_open_debug_screen()

# ---------- run / round flow ----------

## ?screen=...: open one of the career screens at start so it can be looked at.
func _open_debug_screen() -> void:
	match DebugFlags.screen():
		"certificate":
			var r := mini(int(Save.data["rank"]) + 1, Career.max_rank())
			hud.show_certificate(Career.rank_name(r), "This certifies that WHISKERS has shown the skill and judgement of a %s pilot and is awarded the rating.\n\n%s" % [Career.rank_name(r).to_lower(), "\n".join(Career.unlock_lines(r))], date_text(Daily.day_number(Time.get_unix_time_from_system())))
		"slip":
			_show_notice("PINK SLIP", "Private checkride  -  landing 2 of 3\nFailed: Short Field\n150 ft past the aim point (limit 200)\n\nThe examiner keeps the fee (84 coins).", "TAP FOR THE CAREER SCREEN", Color(1.0, 0.55, 0.7))
		"career":
			hud.show_career(career_info())
		"logbook":
			hud.show_logbook(logbook_text(), Save.data["airports"], _slips_for_logbook())
		"hangar":
			_show_hangar()
		"choice":
			hud.show_choice({"title": "LANDED!", "pot": 137, "next_mult": 1.4, "hint": "Next: Fog, Short Field\n(winds, gusts and runways get tougher)"})
		"pause":
			hud.show_pause()

## The aircraft selector: the aircraft and what it costs to fly it.
func _refresh_selector() -> void:
	hud.set_plane_choice(plane_id, Economy.rent_text(Save.data, plane_id), Economy.owns(Save.data, plane_id))

func _show_menu() -> void:
	state = MENU
	_refresh_selector()
	_set_base_tension(0.0)
	hud.hide_card()
	mode = FREE
	hud.set_pot(0, 1.0, false)
	hud.hide_logbook()
	hud.hide_hangar()
	hud.set_ad_button("", false)
	hud.show_menu(best, _career_text())
	_refresh_menu_buttons()
	hud.set_flight(0.0, 0.0, 1.0, 65.0, false)
	hud.set_hint("")

## Start a fresh run IN PLACE: nothing is reloaded, created or freed.
func start_run() -> void:
	mode = FREE
	_over_kind = "run"
	run_coins = 0
	_coins_award = 0
	_coins_doubled = false
	pot = 0
	banked = 0
	pot_lost = 0
	_next_pick = Vector2i(-1, -1)
	Ads.reset()
	hud.set_ad_button("", false)
	if not available_planes().has(plane_id):
		select_plane(available_planes()[0])      # (e.g. after a reset: fly something you have)
	rental_paid = 0
	damage_paid = 0
	if not Economy.can_rent(Save.data, plane_id):
		var asked := plane_id
		select_plane(_cheapest_flyable())
		hud.toast("Can't pay the %s rental: flying the %s" % [Planes.NAMES[asked], Planes.NAMES[plane_id]], Color(1.0, 0.7, 0.4))
	rental_paid = Economy.rental_due(Save.data, plane_id)
	if rental_paid > 0:
		Save.add("coins", -rental_paid)
		hud.toast("Rental  -%d coins" % rental_paid, Color(1.0, 0.85, 0.4))
	score = 0
	strikes = 0
	landings = 0
	round_no = DebugFlags.first_round() - 1
	last_result = {}
	last_crash = ""
	sim_time = 0.0
	streak = 0
	best_streak = 0
	hud.set_streak(0)
	hud.hide_overlay()
	hud.hide_choice()
	hud.clear_popup()
	hud.set_score(0)
	hud.set_strikes(0, 0)
	hud.set_pot(0, pot_multiplier(), true)
	hud.set_fade_now(0.0)
	fx.clear()
	get_tree().paused = false
	_begin_round()
	_snap_camera()

## The aircraft you can fly that costs least to rent (the Cub's fee is waived when you are broke, so there is always one).
func _cheapest_flyable() -> int:
	var best_id := -1
	for p in available_planes():
		if Economy.can_rent(Save.data, p) and (best_id < 0 or Economy.rental_due(Save.data, p) < Economy.rental_due(Save.data, best_id)):
			best_id = p
	return best_id if best_id >= 0 else available_planes()[0]

## Choose the scenario and weather, lay out the next runway and put the plane on its approach. `card` shows the title card
## first (the plane waits); tests pass false.
## The scenario and weather of free-flight approach `rn` (what the rank and the aircraft allow; harder as the run goes on).
func _pick_free(rn: int) -> Vector2i:
	var tgt := career_target()
	var open: Array[int] = Career.scenarios(Save.data["rank"], Save.data["unlock_all"])
	var train: Array[int] = Career.types_for(mini(tgt, Career.max_rank()))
	for t in train:
		if not open.has(t):
			open.append(t)                  # (the landing types you are training for are flown in free flight too)
	var scn_ok := _intersect(Planes.scenarios(plane_id), open)
	var wx_ok := _intersect(Planes.weather(plane_id), Career.weather(Save.data["rank"], Save.data["unlock_all"]))
	# favour the types whose proficiency meter isn't full, else the rank's own types: normal play progresses the career
	var prefer: Array[int] = []
	if int(Save.data["rank"]) < Career.max_rank():
		prefer = Career.missing(Save.data, tgt)
	if prefer.is_empty():
		prefer = train
	return Scenarios.pick(rn, rng, _last_scenario, scn_ok, wx_ok, prefer)

func _begin_round(card: bool = true) -> void:
	var entry: Dictionary = {}
	if mode == RIDE or mode == DAILY or mode == PRACTICE:
		entry = _ride_entry() if mode == RIDE else (Daily.for_day(_daily_day) if mode == DAILY else practice_entry)
		round_no = int(entry["round"])
		rng.seed = int(entry["seed"])
		select_plane(int(entry["plane"]), false)
		scenario = int(entry["scn"])
		weather = int(entry["wx"])
	else:
		round_no += 1
		var pick := _next_pick if (_next_pick.x >= 0 and _next_round == round_no and Scenarios.forced_scenario < 0) else _pick_free(round_no)
		_next_pick = Vector2i(-1, -1)
		scenario = pick.x
		weather = pick.y
	_last_scenario = scenario
	airfield.set_plane(plane_id)
	airfield.generate(round_no, rng, scenario, weather)
	if mode == RIDE:
		_apt_rng.seed = int(entry["seed"]) + 7
	airport_idx = Airports.pick(scenario, _apt_rng)
	airfield.build()
	var r := Tuning.ramp(round_no)
	wind.reset(airfield.wind_base, rng, rng.randf_range(2.0, 3.5))
	aircraft.apply_plane(plane_id)
	hud.set_stall(aircraft.stall_speed())
	aircraft.power = airfield.power
	aircraft.sink_mult = airfield.sink_mult
	aircraft.gy = 0.0
	aircraft.ground_tilt = 0.0
	aircraft.set_floats(scenario == Scenarios.WATER)
	aircraft.set_night(airfield.night)
	aircraft.reset(0.0, airfield.start_altitude)
	if DebugFlags.closeup_enabled():       # (screenshots: start just before the threshold, low, to look at the runway)
		aircraft.x = airfield.thr - 10.0
		aircraft.y = airfield.ground_y(aircraft.x) + 5.0
	_start_x = aircraft.x
	_start_agl = aircraft.agl()
	_standard = Standards.for_type(scenario, _tier())
	var vref := Planes.vref(plane_id)
	hud.set_speed_band(1.0 - float(_standard["kt_minus"]) / vref, 1.0 + float(_standard["kt_plus"]) / vref)
	_gate_dev_kt = INF
	_nose_ok = true
	_papi_run = 0.0
	_papi_worst = 0.0
	_instr_open = 0.0
	last_verdict = {}
	_compute_full_frame()
	airfield.update_papi(aircraft.x, aircraft.y, true)
	_dist_key = -1
	_graded = false
	_awarded = 0
	_coins_award = 0
	_arrested = false
	_shear_state = 0
	_min_agl = 9999.0
	_timer = 0.0
	_puff_t = 0.0
	_shake = 0.0
	_apply_environment()
	state = APPROACH
	if mode == PRACTICE:
		hud.set_round_text("PRACTICE")
	elif mode == DAILY:
		hud.set_round_text("DAILY APPROACH")
	elif mode == RIDE:
		hud.set_round_text("CHECKRIDE %d/%d" % [ride_idx + 1, ride_draw.size()])
	else:
		hud.set_round(round_no)
	hud.set_runway("%s  %d FT  %s" % [Airfield.SURFACE_NAMES[airfield.surface].to_upper(), int(roundf(Units.ft(airfield.rwy_len) / 50.0)) * 50, _terrain_text()])
	hud.set_scenario_text(_scenario_line())
	hud.set_pot(pot, pot_multiplier(), mode == FREE)
	hud.set_wind(wind.head())
	hud.set_hint("Drag UP to raise the nose, DOWN to lower it.\nKeep the PAPI lights 2 white + 2 red.\nFlare just before touchdown." if round_no == 1 and landings == 0 else "")
	hud.set_fade_now(hud.fade_alpha())
	hud.fade_to(0.0)
	_gust_scale = 0.5 + 0.5 * r
	if weather == Scenarios.TURBULENCE:
		_gust_scale *= 1.3
	if not card:
		_announce()
	if card:
		state = CARD
		var sub: String = Scenarios.WX_NAMES[weather] if weather != Scenarios.CLEAR else ""
		if mode == RIDE:
			sub = ("CHECKRIDE  %d / %d" % [ride_idx + 1, ride_draw.size()]) + (("  -  " + Scenarios.WX_NAMES[weather]) if weather != Scenarios.CLEAR else "")
		hud.show_card(Scenarios.NAMES[scenario], sub, _card_blurb(entry), Scenarios.COLORS[scenario])

## (tests) is the mountain ramp drawn?
func _ramp_visible_for_test() -> bool:
	return airfield._ramp_root.visible and airfield._plateau.visible

func _card_blurb(entry: Dictionary = {}) -> String:
	var t: String = Airports.name_of(scenario, airport_idx) + "\n" + Scenarios.BLURBS[scenario]
	if not entry.is_empty():
		if mode == RIDE or mode == PRACTICE:
			t = ("PRACTICE  -  " if mode == PRACTICE else "") + t + "\n" + "\n".join(Standards.lines(_standard, Planes.vref(plane_id)))
		else:
			t = "DAILY APPROACH  " + Daily.label(_daily_day) + "\n" + t + "\nOne approach. Best score counts."
	if weather != Scenarios.CLEAR:
		t += "\n" + Scenarios.WX_BLURBS[weather]
	return t

func _scenario_line() -> String:
	var t: String = Airports.name_of(scenario, airport_idx)
	if weather != Scenarios.CLEAR:
		t += "  -  " + Scenarios.WX_NAMES[weather]
	return t

## What the approach starts with: the power cut of a power-off 180 / an engine failure.
func _announce() -> void:
	if scenario == Scenarios.POWER_OFF:
		hud.flash_warning("POWER CUT - abeam the point!", Color(1.0, 0.6, 0.4))
	elif scenario == Scenarios.ENGINE_OUT or Planes.profile(plane_id)["power"] == 0.0:
		hud.flash_warning("NO POWER", Color(1.0, 0.6, 0.4))

## The tier (Standards) this approach is flown to: the rank's, or the checkride's.
func _tier() -> int:
	if mode == RIDE:
		return Standards.tier_for_rank(ride_target)
	if mode == PRACTICE:
		return Standards.tier_for_rank(career_target())
	return Standards.tier_for_rank(int(Save.data["rank"]))

## The result of the landing so far, as Standards.judge wants it.
func judge_result() -> Dictionary:
	var r := last_result.duplicate()
	r["gate_dev_kt"] = _gate_dev_kt
	r["nose_ok"] = _nose_ok
	r["papi_ok"] = _papi_worst <= Tuning.instrument_dev_seconds
	return r

## The title card is over (timer or tap): the approach begins.
func _end_card() -> void:
	if state != CARD:
		return
	state = APPROACH
	_timer = 0.0
	hud.hide_card()
	_announce()

## Night / rain tint the sky and the light; fog and rain are drawn by the FogOverlay (see _update_fog).
func _apply_environment() -> void:
	var tod := time_of_day()
	var top := Color("4a8ff0")
	var mid := Color("8fc8ff")
	var horizon := Color("d6ecff")
	var sun_c := Color(1.0, 0.95, 0.8)
	var sun_xy := Vector2(0.78, 0.26)
	var sun_glow := 0.35
	var stars := 0.0
	var ambient := Color(0.85, 0.88, 0.95)
	var energy := 0.55
	var sun_energy := 1.0
	var light_c := Color.WHITE
	var sun_pitch := -0.7
	if tod == 1:      # golden hour: warm low sun
		top = Color("5a6fc8")
		mid = Color("ffb08a")
		horizon = Color("ffe0b0")
		sun_c = Color(1.0, 0.72, 0.4)
		sun_xy = Vector2(0.82, 0.5)
		sun_glow = 0.6
		ambient = Color(1.0, 0.82, 0.7)
		energy = 0.5
		sun_energy = 1.05
		light_c = Color(1.0, 0.8, 0.6)
		sun_pitch = -0.32
	if airfield.night:
		top = Color("050a1c")
		mid = Color("0b1530")
		horizon = Color("1c2c52")
		sun_c = Color(0.8, 0.85, 1.0)
		sun_xy = Vector2(0.2, 0.2)
		sun_glow = 0.1
		stars = 1.0
		ambient = Color(0.4, 0.46, 0.7)
		energy = 0.34
		sun_energy = 0.14
		light_c = Color(0.7, 0.78, 1.0)
	elif weather == Scenarios.RAIN:
		top = Color("56626f")
		mid = Color("7f93ab")
		horizon = Color("a9b8c8")
		sun_glow = 0.0
		ambient = Color(0.75, 0.78, 0.85)
		sun_energy = 0.7
	elif weather == Scenarios.FOG:
		top = Color("b7c2cc")
		mid = Color("c9d3dc")
		horizon = Color("dfe6ec")
		sun_glow = 0.1
		ambient = Color(0.85, 0.88, 0.92)
		sun_energy = 0.85
	elif weather == Scenarios.TURBULENCE or weather == Scenarios.SHEAR:
		top = top.darkened(0.12)
		mid = mid.lerp(Color("9aa8b8"), 0.35)
		sun_glow *= 0.7
	_sky_mat.set_shader_parameter("top", top)
	_sky_mat.set_shader_parameter("mid", mid)
	_sky_mat.set_shader_parameter("horizon", horizon)
	_sky_mat.set_shader_parameter("sun_color", sun_c)
	_sky_mat.set_shader_parameter("sun_pos", sun_xy)
	_sky_mat.set_shader_parameter("sun_glow", sun_glow)
	_sky_mat.set_shader_parameter("stars", stars)
	_env.background_color = mid
	_env.ambient_light_color = ambient
	_env.ambient_light_energy = energy
	sun.light_energy = sun_energy
	sun.light_color = light_c
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.35, sun_pitch, -0.62))

## 0 = day, 1 = golden hour: chosen per round from the round number and seed (cosmetic only; it never touches the game's random numbers).
func time_of_day() -> int:
	if DebugFlags.tod_forced() >= 0:
		return DebugFlags.tod_forced()
	return 1 if (hash(round_no * 7919 + DebugFlags.seed_number() + 3) % 100) < 30 else 0

var _gust_scale := 0.5
var _sky_layer: CanvasLayer
var _sky_rect: ColorRect
var _sky_mat: ShaderMaterial

func _terrain_text() -> String:
	match airfield.terrain:
		Airfield.TREES:
			return "trees ahead"
		Airfield.HILL:
			return "hill ahead"
	return ""

## The points multiplier right now: the streak, at least 1, capped.
func streak_multiplier() -> int:
	return clampi(streak, 1, Tuning.streak_cap)

## Crashes allowed in a run: three, but only one for the glider.
func strikes_max() -> int:
	return 1                      # one crash ends any run: free flight loses the pot, a checkride is failed

## Switch aircraft (the menu / game-over selector). Takes effect on the next approach.
func select_plane(id: int, remember: bool = true) -> void:
	plane_id = clampi(id, 0, Planes.COUNT - 1)
	if remember:
		Save.data["plane"] = plane_id
	aircraft.apply_plane(plane_id)
	_refresh_selector()
	hud.set_strikes(0, 0) if mode == FREE else hud.set_strikes(strikes, strikes_max())

## The aircraft you may pick: the ones your rank has unlocked.
func available_planes() -> Array[int]:
	var out := Career.planes(int(Save.data["rank"]), bool(Save.data["unlock_all"]))
	for p in Save.data["owned_planes"]:
		if not out.has(int(p)):
			out.append(int(p))
	if DebugFlags.plane_forced() >= 0 and not out.has(DebugFlags.plane_forced()):
		out.append(DebugFlags.plane_forced())        # (?plane=jet flies it whatever your rank)
	out.sort()
	return out

## The pot multiplier the NEXT landing pays: x1.0, then +pot_step for every landing survived in this run.
func pot_multiplier() -> float:
	return 1.0 + Tuning.pot_step * float(landings)

func _intersect(a: Array[int], b: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for x in a:
		if b.has(x):
			out.append(x)
	return out if not out.is_empty() else a

func _on_plane_step(dir: int) -> void:
	var list := available_planes()
	var i := list.find(plane_id)
	select_plane(list[posmod(i + dir, list.size())])

## ?tune "Next round" and tests: abandon this approach and fly a new one.
func skip_round() -> void:
	if state == APPROACH or state == ROLLOUT or state == CARD:
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
			if sfx != null:
				_background()     # silence everything (held until the player taps Resume) and pause a run in progress
			if not _suspended:
				_suspended = true
				_paused_since_ms = Time.get_ticks_msec()
				_event = "window went to the background"
				_event_frame = Engine.get_process_frames()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if sfx != null:
				_foreground()
			if _suspended:
				_suspended = false
				_paused_total_ms += Time.get_ticks_msec() - _paused_since_ms
				_skip_frames = Tuning.resume_skip_frames
				aircraft.clear_input()   # (the drag that piled up while away must not jerk the nose)
				_event = "window came back"
				_event_frame = Engine.get_process_frames()

# ---------- background audio ----------

## The page was hidden, blurred or the phone locked: silence everything and pause a run in progress. Nothing resumes by itself:
## the player comes back and taps Resume (or, on a menu, anywhere).
func _background() -> void:
	_page_hidden = true
	if not _audio_hold:
		_audio_hold = true
		sfx.hold()
	pause_game()
	_publish_state()

func _foreground() -> void:
	_page_hidden = false
	_publish_state()

## The player is back and has tapped (Resume, or any tap on a menu): sound may run again.
func _release_audio() -> void:
	if _page_hidden:
		return
	if _audio_hold:
		_audio_hold = false
		sfx.release()
		if OS.has_feature("web"):
			JavaScriptBridge.eval("window.__pwRelease && window.__pwRelease()")
	_publish_state()

## The page tells us about visibility (a hidden tab, a locked phone) in case the engine's own focus notifications do not arrive.
func _on_page_hidden(hidden: bool) -> void:
	if hidden and not _page_hidden:
		_background()
	elif not hidden and _page_hidden:
		_foreground()

## For the automated audio check (tools/web_audio_check.js): what the game is doing and where its Resume button is.
func _publish_state() -> void:
	if not OS.has_feature("web"):
		return
	var rc := hud.resume_center()
	var sc := float(JavaScriptBridge.eval("window.innerWidth")) / maxf(get_viewport().get_visible_rect().size.x, 1.0)
	JavaScriptBridge.eval("window.__pw = {paused: %s, muted: %s, held: %s, resume: [%.1f, %.1f]}" % [str(_paused_run).to_lower(), str(AudioServer.is_bus_mute(0)).to_lower(), str(_audio_hold).to_lower(), rc.x * sc, rc.y * sc])

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
	_update_audio(dt)

## One frame of the whole game (tests call this directly with a fixed dt).
func advance(dt: float) -> void:
	if dt > 0.0:
		_timer += dt
		match state:
			CARD:
				if _timer >= Tuning.card_time:
					_end_card()
			APPROACH:
				airfield.step_deck(dt)
				_step_approach(dt)
			ROLLOUT:
				airfield.step_deck(dt)
				_step_rollout(dt)
			CRASH:
				if _timer >= Tuning.crash_pause:
					_leave_crash()
			CASHOUT:
				_step_cashout(dt)
			AD:
				_ad_t -= dt
				hud.set_ad_time(_ad_t)
				if _ad_t <= 0.0:
					_finish_ad()
			FADE:
				if hud.fade_alpha() >= 0.999 and _timer >= Tuning.fade_time:
					if _after_fade_over:
						_show_over()
					elif mode == FREE and Ads.interstitial_due(Time.get_ticks_msec()):
						_play_ad("interstitial")      # only here: between rounds, never mid-approach
					else:
						_begin_round()
						_snap_camera()
		if state == APPROACH or state == ROLLOUT:
			sim_time += dt
			_flight_acc += dt
		_shake = maxf(_shake - Tuning.shake_decay * dt * (0.4 + _shake), 0.0)
	aircraft.update_visual(dt)
	_update_camera(dt)
	airfield.drift_streaks(dt, _cam_dx, wind.head(), _cam_w)
	airfield.update(dt, _cam_x, _cam_w, wind.head(), _cam_y)
	_update_fog()
	_update_hud(dt)

func _step_approach(dt: float) -> void:
	wind.update(dt, rng, _gust_scale)
	if wind.gust_started:
		wind.gust_started = false
		aircraft.kick(1.0 if wind.gust_v > 0.0 else -1.0)
		hud.flash_warning("GUST!", Color(1, 0.9, 0.4))
		sfx.play(Sfx.WHOOSH, rng.randf_range(0.9, 1.2), -12.0)
	# weather: turbulence builds as the plane nears the runway; wind shear is warned (windsock snaps) then hits just before the flare
	if airfield.turb > 0.0:
		var zone := clampf(1.0 - (airfield.thr - aircraft.x) / Tuning.turb_zone, 0.0, 1.0)
		wind.update_turbulence(dt, airfield.turb, zone)
		_turb_shake = 0.18 * zone
	else:
		_turb_shake = 0.0
	if airfield.shear_back > 0.0 and _shear_state < 2:
		var to_aim := airfield.aim_x - aircraft.x
		if _shear_state == 0 and to_aim <= airfield.shear_back + aircraft.gs * Tuning.shear_tele_time:
			_shear_state = 1
			airfield.snap_sock()
			hud.flash_warning("WIND SHEAR!", Color(1.0, 0.45, 0.35))
			sfx.play(Sfx.WHOOSH, 0.7, -4.0)
		if _shear_state == 1 and to_aim <= airfield.shear_back:
			_shear_state = 2
			wind.start_shear()
			aircraft.kick(-1.0)
	wind.update_shear(dt)
	aircraft.consume_input(dt)
	airfield.update_papi(aircraft.x, aircraft.y)
	var n := maxi(ceili(dt / Tuning.sim_step), 1)
	var h := dt / float(n)
	for i in n:
		aircraft.gy = airfield.ground_y(aircraft.x)
		aircraft.step_air(h, wind.head(), wind.v_total() * aircraft.p_gust, wind.h_total() * aircraft.p_gust)
		# trees / hill / the stern of the carrier or truck
		var obstacle := airfield.height_at(aircraft.x)
		if obstacle > 0.0 and aircraft.y < obstacle and not DebugFlags.god_enabled():
			_crash(_hazard_text())
			return
		var gy := airfield.ground_y(aircraft.x)
		if aircraft.y <= gy:
			aircraft.gy = gy
			_touchdown()
			return
		if aircraft.x > airfield.rwy_end + 4.0 and not DebugFlags.god_enabled():
			_crash(_flew_past_text())
			return
	var agl := aircraft.agl()
	# the 50 ft gate: the approach speed is judged here
	if _gate_dev_kt == INF and agl <= Units.units_of_ft(Tuning.gate_height_ft) and aircraft.vy < 0.0:
		_gate_dev_kt = aircraft.airspeed_kt() - Planes.vref(plane_id)
	# instrument approach: the PAPI is the glide-path guidance (all lights one colour = a full dot off); the runway appears at minimums
	if airfield.instrument:
		if airfield.papi_white == 0 or airfield.papi_white == 4:
			_papi_run += dt
			_papi_worst = maxf(_papi_worst, _papi_run)
		else:
			_papi_run = 0.0
		if agl <= airfield.dh:
			if _instr_open == 0.0:
				hud.flash_warning("MINIMUMS - runway in sight", Color(0.6, 1.0, 0.7))
			_instr_open = minf(_instr_open + dt * 1.6, 1.0)
	# no go-around: once the plane has been low, climbing well clear again is a go-around attempt - which is a crash
	_min_agl = minf(_min_agl, agl)
	if _min_agl < Tuning.go_around_low and agl > _min_agl + Tuning.go_around_climb and not DebugFlags.god_enabled():
		_crash("No go-around!")

func _hazard_text() -> String:
	match scenario:
		Scenarios.CARRIER:
			return "Hit the stern!"
		Scenarios.TRUCK:
			return "Hit the tailgate!"
	return "Hit the trees!" if airfield.terrain == Airfield.TREES else "Hit the hill!"

func _flew_past_text() -> String:
	match scenario:
		Scenarios.CARRIER:
			return "Missed the deck!"
		Scenarios.TRUCK:
			return "Overshot the truck!"
		Scenarios.WATER:
			return "Flew on over the water!"
	return "Flew past the runway!"

func _off_text() -> String:
	match scenario:
		Scenarios.CARRIER:
			return "Splash! Short of the deck"
		Scenarios.TRUCK:
			return "Missed the truck!"
		Scenarios.MOUNTAIN:
			return "Hit the slope!"
	return "Off the runway!"

func _overrun_text() -> String:
	match scenario:
		Scenarios.CARRIER:
			return "Off the end of the deck!"
		Scenarios.TRUCK:
			return "Fell off the truck!"
	return "Overran the runway!"

func _step_rollout(dt: float) -> void:
	wind.update(dt, rng, _gust_scale * 0.3)
	if aircraft.nose_hold:
		aircraft.ground_pitch(dt)
		if aircraft.gs > _touch_gs * Tuning.soft_release:
			if aircraft.theta_target < Tuning.soft_nose_deg and _nose_ok:
				_nose_ok = false
				hud.flash_warning("NOSE DOWN TOO EARLY!", Color(1.0, 0.5, 0.35))
		else:
			aircraft.nose_hold = false
		_bump_t -= dt
		if _bump_t <= 0.0 and not DebugFlags.off("shake"):
			_bump_t = 0.3
			_shake = maxf(_shake, 0.12)       # rough grass
	var decel := airfield.surface_decel() * aircraft.p_decel
	var n := maxi(ceili(dt / Tuning.sim_step), 1)
	var h := dt / float(n)
	for i in n:
		# carrier: the hook catches a wire if the plane rolls over the wire zone
		if airfield.has_wires and not _arrested and absf(aircraft.x - airfield.aim_x) <= Tuning.carrier_wire_half:
			_arrested = true
			hud.flash_warning("TRAPPED!", Color(0.5, 0.95, 1.0))
		aircraft.step_ground(h, Tuning.carrier_arrest_decel if _arrested else decel, airfield.deck_speed)
		aircraft.gy = airfield.ground_y(aircraft.x)
		aircraft.y = aircraft.gy
		aircraft.ground_tilt = rad_to_deg(atan(airfield.slope_at(aircraft.x)))
		if airfield.surface != Airfield.WATER and aircraft.x > airfield.rwy_end and aircraft.gs > airfield.deck_speed + Tuning.overrun_speed and not DebugFlags.god_enabled():
			_crash(_overrun_text())
			return
	# puffs of dust / smoke while the wheels still bite hard
	_puff_t -= dt
	if _puff_t <= 0.0 and aircraft.gs > airfield.deck_speed + 6.0 and (airfield.surface != Airfield.ASPHALT or _timer < 0.6):
		_puff_t = Tuning.roll_puff_interval * 3.0
		fx.smoke(Vector3(aircraft.x - 1.0, aircraft.gy + 0.3, 1.0), 0.25 + (aircraft.gs - airfield.deck_speed) / 60.0, airfield.smoke_color())
	var rest := aircraft.gs <= airfield.deck_speed + Tuning.rollout_rest_speed and _timer >= Tuning.rollout_min_time
	if rest or _timer >= Tuning.rollout_max_time:
		_finish_round(false)

# ---------- touchdown ----------

func _touchdown() -> void:
	var px := aircraft.x
	var gy := airfield.ground_y(px)
	# sink rate relative to the ground: an uphill slope rises to meet the plane, so it adds to the closing speed
	var sink := maxf(-(aircraft.vy - aircraft.gs * airfield.slope_at(px)), 0.0)
	aircraft.y = gy
	aircraft.gy = gy
	var wheels := Vector3(px - 0.4, gy + 0.25, 1.0)
	var rough := airfield.surface == Airfield.WATER and not airfield.in_lane(px)
	if rough:
		sink *= Tuning.water_rough_mult    # rough water outside the calm lane: a much harder landing
	if Grading.is_crash_sink(sink, float(Planes.profile(plane_id)["tough"])) and not DebugFlags.god_enabled():
		_crash("Too hard!" if airfield.on_runway(px) else _off_text())
		return
	if not airfield.on_runway(px) and not DebugFlags.god_enabled():
		_crash(_off_text())
		return
	if airfield.has_wires and px > airfield.aim_x + Tuning.carrier_wire_half + 2.0 and not DebugFlags.god_enabled():
		_crash("Missed the wires!")      # a bolter: there is no going around, so it is a crash
		return
	var bounced := Grading.is_bounce_sink(sink, 0.5 if rough else 1.0)
	if not _graded:
		_graded = true
		last_result = Grading.evaluate(sink, px - airfield.aim_x, airfield.rwy_len, bounced)
		last_result["sink"] = sink
		last_result["offset"] = px - airfield.aim_x
		last_result["bounced"] = bounced
		var g0: int = last_result["grade"]
		var had_streak := streak
		if g0 == 0:
			streak = mini(streak + 1, Tuning.streak_cap)     # a Greaser! extends the streak
		elif g0 >= 3:
			streak = 0                                      # Firm / Hard breaks it (Smooth and Good keep it)
		var mult := streak_multiplier()
		last_result["base"] = int(last_result["total"])
		last_result["mult"] = mult
		_awarded = int(last_result["total"]) * mult
		last_result["points"] = _awarded
		best_streak = maxi(best_streak, streak)
		_record_landing(g0)
		score += _awarded
		landings += 1
		hud.set_score(score)
		var g: int = last_result["grade"]
		var sub := "Sink %.1f ft/s   %s%.0f ft from the aim point   %s   +%d%s" % [
			Units.fps(sink), "+" if px >= airfield.aim_x else "", Units.ft(px - airfield.aim_x), "BOUNCED" if bounced else "no bounce", int(last_result["total"]),
			(" x%d = %d" % [mult, _awarded]) if mult > 1 else ""]
		if _coins_award > 0:
			sub += "   +%dc" % _coins_award
		if rough:
			sub = "ROUGH WATER   " + sub
		hud.popup(Grading.NAMES[g], sub, Grading.COLORS[g], Tuning.popup_time)
		if mode == FREE and _coins_award > 0:
			hud.fly_coins_to_pot(camera.unproject_position(Vector3(px, gy + 3.0, 0.0)), _coins_award / 6)
		if g0 >= 3:
			hud.streak_lost(had_streak)
		else:
			hud.set_streak(streak, g0 == 0)
		if g0 == 0:
			fx.sparkle(Vector3(px, gy + 3.0, 1.0), streak - 1)
			sfx.play_step(Sfx.CHIME, mini(streak, 8) - 1, -2.0)
		hud.set_hint("")
		if g <= 1:
			sfx.play_step(Sfx.CHIME, 1 - g, -3.0)
	var power := clampf(0.25 + sink / 5.0, 0.2, 1.0)
	fx.smoke(wheels, power, airfield.smoke_color())
	if airfield.surface == Airfield.ASPHALT or airfield.surface == Airfield.DECK:
		fx.tire(wheels, power)
		sfx.play(Sfx.SKID, rng.randf_range(0.9, 1.1), -9.0 + minf(sink, 4.0) * 1.5)
	sfx.play(Sfx.SQUEAK, rng.randf_range(0.9, 1.15), -4.0 + minf(sink, 4.0))
	if sink > 1.6:
		sfx.play(Sfx.THUD, rng.randf_range(0.9, 1.1), -6.0 + minf(sink, 4.0) * 1.5)
	if not DebugFlags.off("shake"):
		_shake = maxf(_shake, clampf((sink - Tuning.shake_min_sink) * Tuning.shake_per_sink, 0.0, Tuning.shake_max))
	if sink > 1.2 and not DebugFlags.off("haptic"):
		Input.vibrate_handheld(int(clampf(sink * 25.0, 20.0, 150.0)))
	if bounced:
		aircraft.bounce(sink * Tuning.bounce_restitution * (1.35 if rough else 1.0))
		return
	aircraft.land()
	_touch_gs = aircraft.gs
	aircraft.nose_hold = airfield.soft
	state = ROLLOUT
	_timer = 0.0
	_puff_t = 0.0

# ---------- crash / round end ----------

func _crash(reason: String) -> void:
	last_crash = reason
	last_verdict = {"pass": false, "fails": ["Crashed: " + reason] as Array[String]}
	strikes += 1
	if streak > 0:
		hud.streak_lost(streak)
	streak = 0
	Save.add("crashes", 1)
	if mode == RIDE:
		ride_fails.append("Crashed: " + reason)
		ride_fail_type = scenario
	score -= _awarded            # a landing that ends in a crash (bounce into trees) doesn't count
	if _awarded > 0:
		landings -= 1
		hud.set_score(score)
	var lost_text := ""
	if mode == FREE:
		pot -= _coins_award               # (a landing that ends in a crash doesn't count)
		_coins_award = 0
		pot_lost = maxi(pot, 0)
		pot = 0
		hud.set_pot(0, 1.0, true)
		if pot_lost > 0:
			lost_text = "\nPot lost: %d coins" % pot_lost
	elif _coins_award > 0:
		Save.add("coins", -_coins_award)
		run_coins -= _coins_award
		_coins_award = 0
	if mode == FREE:
		var dmg := Economy.damage_due(Save.data, plane_id)
		if dmg > 0:
			Save.add("coins", -dmg)
			damage_paid += dmg
			lost_text += "\nDamage fee: -%d coins" % dmg
	_awarded = 0
	hud.set_strikes(0, 0) if mode == FREE else hud.set_strikes(strikes, strikes_max())
	_set_base_tension(0.0)
	hud.popup("CRASH", reason + lost_text, Color(1.0, 0.35, 0.3), Tuning.crash_pause)
	hud.set_hint("")
	fx.crash(Vector3(aircraft.x, maxf(aircraft.y, aircraft.gy) + 1.5, 0.5))
	fx.smoke(Vector3(aircraft.x, aircraft.gy + 0.4, 1.0), 1.0, Color(0.25, 0.25, 0.25))
	var pr: Dictionary = Planes.profile(plane_id)
	fx.debris(Vector3(aircraft.x, maxf(aircraft.y, aircraft.gy) + 1.0, 0.5), pr["body"], pr["accent"], aircraft.gy)
	fx.burn(Vector3(aircraft.x, aircraft.gy + 0.6, 1.0))
	sfx.play(Sfx.CRASH, 1.0, 0.0)
	if mode == FREE and pot_lost > 0:
		hud.show_pot_lost(pot_lost)
		sfx.play(Sfx.BOOM, 1.0, -2.0)
	if not DebugFlags.off("shake"):
		_shake = 1.0
	if not DebugFlags.off("haptic"):
		Input.vibrate_handheld(300)
	aircraft.visible = false
	state = CRASH
	_timer = 0.0

func _leave_crash() -> void:
	hud.hide_pot_lost()
	_finish_round(strikes >= strikes_max())

## A landing that met this rank's standard fills its landing type's proficiency meter, in free flight, practice and the daily
## approach alike. A toast says so ("Short Field +1, 2/3"). `double`: the instructor lesson counts more.
func _credit_proficiency(lesson: bool) -> Dictionary:
	var rank := int(Save.data["rank"])
	if rank >= Career.max_rank():
		return {}
	var tgt := career_target()
	if not Career.types_for(tgt).has(scenario):
		return {}
	var before := Career.count(Save.data, scenario)
	var n := Career.add_practice(Save.data, scenario, int(Tuning.lesson_credit) if lesson else 1)
	var name_t: String = Scenarios.NAMES[scenario].capitalize()
	var text := "%s  +%d,  %d/%d" % [name_t, n - before, n, Career.needed()] if n > before else "%s  %d/%d (full)" % [name_t, n, Career.needed()]
	if lesson:
		text += "  (lesson x2)"
	hud.toast(text, Color(0.55, 1.0, 0.65))
	if before < Career.needed() and n >= Career.needed() and Career.endorsed(Save.data, tgt):
		hud.toast("Endorsed! Book the %s checkride in CAREER" % Career.rank_name(tgt), Color(1.0, 0.85, 0.35))
		sfx.play_step(Sfx.CHIME, 4)
	Save.store()
	_refresh_menu_buttons()
	return {"n": n, "gain": n - before}

## The landing (or crash) is over: fade out, then a new approach (or the end of the run).
func _finish_round(over: bool) -> void:
	if state != CRASH and not last_result.is_empty() and _graded:
		last_verdict = Standards.judge(_standard, judge_result(), false)
		if mode != RIDE:
			if last_verdict["pass"]:
				hud.flash_warning("STANDARD MET", Color(0.5, 1.0, 0.6))
				if mode != PRACTICE:
					_credit_proficiency(false)          # (practice credits in its result screen, with the lesson bonus)
			else:
				hud.flash_warning("STANDARD MISSED: " + str(last_verdict["fails"][0]), Color(1.0, 0.55, 0.4))
		elif not last_verdict["pass"]:
			ride_fails.append_array(last_verdict["fails"])
			ride_fail_type = scenario
	if mode == DAILY or mode == PRACTICE:
		over = true             # one approach
	elif mode == RIDE:
		if not ride_fails.is_empty():
			over = true
		else:
			ride_idx += 1
			over = ride_idx >= ride_draw.size()
	Save.add("flight_seconds", _flight_acc)
	_flight_acc = 0.0
	Save.store()
	if mode == FREE and not over:
		_enter_choice()           # landed: cash out the pot or keep flying
		return
	_after_fade_over = over
	state = FADE
	_timer = 0.0
	hud.fade_to(1.0)

## "Rental -20   Damage -40" for the run-over screen ("" when there were none).
func _fees_text() -> String:
	var parts: Array[String] = []
	if rental_paid > 0:
		parts.append("Rental  -%d" % rental_paid)
	if damage_paid > 0:
		parts.append("Damage  -%d" % damage_paid)
	return "   ".join(parts)

func _show_over() -> void:
	state = OVER
	_death_time = Time.get_ticks_msec() / 1000.0
	if mode == DAILY:
		_show_daily_result()
		return
	if mode == PRACTICE:
		_show_practice_result()
		return
	if mode == RIDE:
		_show_ride_result()
		return
	_over_kind = "run"
	_hide_pause_ui()
	hud.set_pot(0, 1.0, false)
	var new_best := score > best
	if new_best:
		best = score
		Save.store_best(best)
	Save.data["best_streak"] = maxi(int(Save.data["best_streak"]), best_streak)
	Save.store()
	_refresh_menu_buttons()
	hud.fade_to(0.0)
	hud.clear_popup()
	hud.over_extra = _fees_text()
	hud.show_over(score, best, landings, new_best, best_streak, banked, pot_lost)
	_refresh_ad_button()

# ---------- camera / HUD ----------

## This round's wide framing: the plane at the left edge and the whole runway on screen.
func _compute_full_frame() -> void:
	var span := airfield.rwy_end + 30.0 - _start_x
	_full_w = clampf(span * 1.1, Tuning.view_width_low * 1.5, Tuning.view_width_full_max)
	_full_left = _start_x - 0.07 * _full_w

## 0 = the wide framing at the start of the approach, 1 = the close flare framing. Driven by the distance to the aim
## markers (and forced by a low altitude), eased so the zoom starts and ends gently.
func _closeness() -> float:
	if DebugFlags.closeup_enabled():
		return 1.0
	var d0 := maxf(airfield.aim_x - _start_x, 1.0)
	var d := airfield.aim_x - aircraft.x
	var by_dist := clampf((d0 - d) / maxf(d0 - Tuning.zoom_close_distance, 1.0), 0.0, 1.0)
	var hi := maxf(_start_agl, Tuning.zoom_low_altitude + 1.0)
	var by_alt := clampf((hi - aircraft.agl()) / maxf(hi - Tuning.zoom_low_altitude, 0.5), 0.0, 1.0)
	return smoothstep(0.0, 1.0, maxf(by_dist, by_alt))

func _snap_camera() -> void:
	_update_camera(0.0, true)
	hud.set_papi(airfield.papi_white, _plane_screen_x(), state == APPROACH and not _graded, true)
	_update_fog()

## Where the plane is on screen (viewport pixels): the big PAPI follows it sideways.
func _plane_screen_x() -> float:
	return camera.unproject_position(Vector3(aircraft.x, aircraft.y + Aircraft.GEAR_H, 0.0)).x

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
	if state == CRASH:      # the camera eases in on the wreck and stays with it
		_cam_w = lerpf(_cam_w, Tuning.view_width_low * 0.7, k)
		left = lerpf(left, aircraft.x - _cam_w * 0.5, 0.5)
	var old_x := _cam_x
	_cam_x = left + _cam_w * 0.5
	_cam_dx = 0.0 if snap else _cam_x - old_x
	var wide := clampf((_cam_w - Tuning.view_width_low) / 200.0, 0.0, 1.0)
	_tilt = lerpf(Tuning.camera_tilt_deg, Tuning.camera_tilt_wide_deg, wide)
	var h := _cam_w * _aspect()
	var ground_y := lerpf(Tuning.ground_screen_y, Tuning.ground_screen_y_wide, wide)
	var slope_lift := 0.6 * airfield.ground_y(aircraft.x) if airfield.slope_m > 0.0 else 0.0
	_cam_y = lerpf(_cam_y, (0.5 - ground_y) * h / cos(deg_to_rad(_tilt)) + slope_lift, k)
	aircraft.set_view_scale(_cam_w)
	_apply_camera()

func _apply_camera() -> void:
	camera.size = _cam_w
	var tilt := deg_to_rad(_tilt)
	var dist := 80.0
	var ox := 0.0
	var oy := 0.0
	var sh := maxf(_shake, _turb_shake)
	if sh > 0.001:
		ox = rng.randf_range(-1.0, 1.0) * sh * Tuning.shake_size
		oy = rng.randf_range(-1.0, 1.0) * sh * Tuning.shake_size
	# a tight depth range (just what the view can see) keeps the ground layers apart even on a 16-bit depth buffer
	var span := _cam_w * _aspect() * 0.5 * sin(tilt) + 70.0
	camera.near = maxf(dist - span, 1.0)
	camera.far = dist + span
	camera.position = Vector3(_cam_x + ox, _cam_y + oy + dist * sin(tilt), dist * cos(tilt))
	camera.rotation = Vector3(-tilt, 0.0, 0.0)

func _update_hud(dt: float) -> void:
	var flying := state == APPROACH
	hud.set_flight(aircraft.agl(), aircraft.vy - aircraft.gs * airfield.slope_at(aircraft.x) if not aircraft.on_ground else 0.0, aircraft.s, Planes.vref(plane_id), flying and not hud.overlay_visible)
	hud.set_papi(airfield.papi_white, _plane_screen_x(), flying and not _graded and not hud.overlay_visible)
	if state == APPROACH or state == ROLLOUT:
		hud.set_wind(wind.head())
		_update_distance()
	elif _dist_key != -1:
		_dist_key = -1
		hud.set_distance("")
	hud.set_pause_button(_can_pause() and not hud.overlay_visible and state != FADE)
	hud.update(dt)

## Runway distance readout: metres to the threshold, then metres of runway left. Text rebuilt only when the number changes.
func _update_distance() -> void:
	var to_thr := airfield.thr - aircraft.x
	var key := -1
	var text := ""
	if to_thr > 0.5:
		key = int(roundf(Units.ft(to_thr) / 10.0)) * 10
		text = "RUNWAY  %d FT" % key
	elif aircraft.x <= airfield.rwy_end:
		key = 1000000 + int(roundf(Units.ft(airfield.rwy_end - aircraft.x) / 10.0)) * 10
		text = "ON RUNWAY  %d FT left" % (key - 1000000)
	if key != _dist_key:
		_dist_key = key
		hud.set_distance(text)

## Fog / rain haze over the 3D view: the runway (and the trees) appear only inside the visibility distance.
func _update_fog() -> void:
	if airfield.vis_end <= 0.0 or state == MENU or state == OVER:
		fog.set_fog(false, 0.0, 1.0, 1.0, 0.0, 1.0, Color.WHITE, 0.0)
		return
	var vs := get_viewport().get_visible_rect().size
	var col := Color(0.8, 0.85, 0.9)
	var strength := 0.97
	var haze := 0.0
	if airfield.weather == Scenarios.RAIN:
		col = Color(0.5, 0.56, 0.63)
		strength = 0.72
		haze = 0.07
	if airfield.night:
		col = col.darkened(0.9)
	var vis := airfield.vis_end
	if airfield.instrument:
		if _instr_open >= 0.999:
			fog.set_fog(false, 0.0, 1.0, 1.0, 0.0, 1.0, Color.WHITE, 0.0)
			return
		vis = lerpf(airfield.vis_end, 700.0, _instr_open * _instr_open)      # the runway appears at minimums
	fog.set_fog(true, _plane_screen_x(), vs.x / maxf(_cam_w, 1.0), vs.x, minf(Tuning.fog_start, vis * 0.4), vis, col, strength, haze)

var _coin_step := 0              # each coin that reaches the counter plinks one note higher
var _coin_ms := 0
var _tension_base := 0.0         # from the push-your-luck pot
var _final_tension := 0.0        # builds on the final approach

func _set_base_tension(v: float) -> void:
	_tension_base = v
	sfx.set_tension(maxf(_tension_base, _final_tension))

## Every frame: the engine, wind and rain loops follow the flight, the music mood follows the state, and the heartbeat builds
## on the final approach (and stays while a pot is at stake).
func _update_audio(dt: float) -> void:
	var flying := (state == APPROACH or state == ROLLOUT) and not _paused_run
	var wx_rain := 0.7 if weather == Scenarios.RAIN else 0.0
	if flying:
		var kind := int(Planes.profile(plane_id)["kind"])
		var sp := clampf(aircraft.s, 0.0, 1.4)
		if state == APPROACH:
			var eng := (0.5 + 0.3 * clampf(sp - 0.6, 0.0, 0.8)) * (1.0 if aircraft.power > 0.0 else 0.0)
			sfx.set_loops(kind, eng, 0.7 + 0.5 * sp, 0.2 + 0.5 * sp + (0.2 if airfield.turb > 0.0 else 0.0), wx_rain)
		else:
			var g := clampf(aircraft.gs / maxf(_touch_gs, 1.0), 0.0, 1.0)
			sfx.set_loops(kind, 0.3 + 0.15 * g, 0.65 + 0.3 * g, 0.5 * g, wx_rain * 0.8)
	else:
		sfx.loops_off()
	sfx.set_mood(1.0 if (state == APPROACH or state == ROLLOUT or state == CARD or state == CRASH or state == CHOICE or state == CASHOUT) else 0.0)
	var goal := 0.0
	if state == APPROACH and not _graded:
		goal = smoothstep(0.55, 1.0, _closeness()) * 0.55
	_final_tension = move_toward(_final_tension, goal, dt * 0.5)
	sfx.set_tension(maxf(_tension_base, _final_tension))

## A finger went down on a button: its own sound by kind, and a light haptic.
func _on_button_down(kind: String) -> void:
	match kind:
		"ghost":
			sfx.play(Sfx.BACK, 1.0, -7.0)
		"primary", "gold":
			sfx.play(Sfx.CONFIRM, 1.0, -9.0)
		"danger":
			sfx.play(Sfx.DENY, 1.0, -10.0)
		_:
			sfx.play(Sfx.TAP, 1.0, -8.0)
	if DisplayServer.get_name() != "headless":
		Input.vibrate_handheld(8)

func _on_ui_sound(kind: String) -> void:
	match kind:
		"stamp":
			sfx.play(Sfx.STAMP, 1.0, -2.0)
		"trombone":
			sfx.play(Sfx.TROMBONE, 1.0, -4.0)
		"coin":
			var now_ms := Time.get_ticks_msec()
			if now_ms - _coin_ms > 900:
				_coin_step = 0
			_coin_ms = now_ms
			sfx.play_step(Sfx.COIN, _coin_step)
			_coin_step += 1
		"sign":
			sfx.play(Sfx.SIGN, 1.0, -8.0)
		"whoosh":
			sfx.play(Sfx.WHOOSH, 1.4, -16.0)
		"page":
			sfx.play(Sfx.PAGE, 1.0, -10.0)
		"fanfare":
			sfx.play(Sfx.FANFARE, 1.0, -9.0)

func _on_tuning_changed(property: String) -> void:
	if property == "outline_thickness":
		pass
	if property == "wind_enabled":
		wind.reset(airfield.wind_base if Tuning.wind_enabled else 0.0, rng)

# ---------- input ----------

func _input(event: InputEvent) -> void:
	if hud.logo_running():
		return
	# A touch on the tuning panel's TUNE button belongs to the button, not the game.
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and TunePanel.button_hit(event.position):
		return
	# Browsers only allow vibration after a touch, and the first real call connects to the device's vibration
	# service: make an imperceptible 1 ms pulse on the very first touch, not on the first landing.
	if (event is InputEventScreenTouch and event.pressed) and (state == MENU or state == OVER or state == CARD):
		_release_audio()          # (back from the background, on a menu: any tap brings the sound back)
	if not _haptic_warmed and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		sfx.unlock()
		_haptic_warmed = true
		if not DebugFlags.off("haptic"):
			Input.vibrate_handheld(1)
	if event is InputEventScreenTouch and event.pressed:
		if state == CARD and _timer > 0.35:
			_end_card()
		elif hud.over_selector(event.position):
			pass
		elif state == MENU and not _warming:
			_run_start_ms = Time.get_ticks_msec()
			_paused_total_ms = 0
			start_run()
		elif state == OVER and Time.get_ticks_msec() / 1000.0 - _death_time > 0.6:
			_run_start_ms = Time.get_ticks_msec()
			_paused_total_ms = 0
			_continue_from_over()

# ---------- career: ranks, practice, checkrides, logbook ----------

## The rank being trained for (the checkride the endorsement opens).
func career_target() -> int:
	return mini(int(Save.data["rank"]) + 1, Career.max_rank())

func _types_text(types: Array[int]) -> String:
	var names: Array[String] = []
	for t in types:
		names.append(Scenarios.NAMES[t].capitalize())
	return ", ".join(names)

func _career_text() -> String:
	var rank := int(Save.data["rank"])
	var t := "%s PILOT\n" % Career.rank_name(rank)
	if rank < Career.max_rank():
		var tgt := career_target()
		var ready := Career.types_for(tgt).size() - Career.missing(Save.data, tgt).size()
		if Career.endorsed(Save.data, tgt):
			t += "Endorsed for the %s checkride\n" % Career.rank_name(tgt)
		else:
			t += "Training for %s: %d / %d landing types ready\n" % [Career.rank_name(tgt), ready, Career.types_for(tgt).size()]
	else:
		t += "Every rating earned\n"
	t += "Coins  %d\n\n" % int(Save.data["coins"])
	return t

## What the career screen shows (see Hud.show_career).
func career_info() -> Dictionary:
	var rank := int(Save.data["rank"])
	var tgt := career_target()
	var top := rank >= Career.max_rank()
	var types := Career.types_for(tgt) if not top else Career.types_for(Career.max_rank())
	var endorsed := (not top) and Career.endorsed(Save.data, tgt)
	var lesson_fee := Economy.lesson_fee(tgt)
	var rows: Array[Dictionary] = []
	for ty in types:
		var cnt := Career.count(Save.data, ty) if not top else Career.needed()
		rows.append({"name": Scenarios.NAMES[ty].capitalize(), "count": cnt, "needed": Career.needed(), "type": ty,
			"missing": cnt < Career.needed(), "lesson_fee": lesson_fee, "lesson_ok": (not top) and cnt < Career.needed() and int(Save.data["coins"]) >= lesson_fee})
	var speech := ""
	var status := ""
	var lock := ""
	var book_text := "BOOK CHECKRIDE"
	var can_book := false
	if top:
		speech = "\"Captain on the flight deck. There is nothing left to examine you on - but the instructor will never stop you flying.\""
		status = "Airline Captain: the top of the ladder"
		book_text = "ALL RATINGS EARNED"
	else:
		var miss := Career.missing(Save.data, tgt)
		var fee := Career.fee(tgt, bool(Save.data["fee_halved"]))
		book_text = "BOOK CHECKRIDE   %d COINS" % fee
		if endorsed:
			speech = "\"Well flown, Whiskers. I've signed your endorsement for the %s checkride. The examiner will draw %d landing types.\"" % [Career.rank_name(tgt), mini(int(Tuning.ride_landings), types.size())]
			status = "Examiner fee  %d coins%s    You have  %d" % [fee, " (halved!)" if bool(Save.data["fee_halved"]) else "", int(Save.data["coins"])]
			can_book = int(Save.data["coins"]) >= fee
			if not can_book:
				lock = "Examiner fee %d coins: you have %d. Fly more, or take it from the pot." % [fee, int(Save.data["coins"])]
		else:
			speech = "\"Practise each landing to the %s standard %d times. Still to do: %s.\"" % [Career.rank_name(tgt), Career.needed(), _types_text(miss)]
			status = "Needs endorsement:  %s" % _progress_text(miss)
			lock = status
	return {"body": "%s PILOT" % Career.rank_name(rank), "speech": speech, "endorsed": endorsed, "status": status, "rows": rows,
		"practice": CAREER_PRACTICE, "book_text": book_text, "book": can_book and CAREER_BOOKING, "lock": lock}

## "Short Field 1/3, Soft Field 0/3" for the types still to fill.
func _progress_text(types: Array[int]) -> String:
	var parts: Array[String] = []
	for t in types:
		parts.append("%s %d/%d" % [Scenarios.NAMES[t].capitalize(), Career.count(Save.data, t), Career.needed()])
	return ", ".join(parts)

const CAREER_PRACTICE := true
const CAREER_BOOKING := true

func _refresh_menu_buttons() -> void:
	hud.set_menu_button("career", "CAREER")
	var dl: Dictionary = Save.data["daily"]
	var today := Daily.day_number(Time.get_unix_time_from_system())
	hud.set_menu_button("daily", "DAILY  %d" % int(dl["best"]) if int(dl["day"]) == today and int(dl["best"]) > 0 else "DAILY")

func _on_menu_action(id: String) -> void:
	if state != MENU and state != OVER:
		return
	match id:
		"fly":
			_run_start_ms = Time.get_ticks_msec()
			_paused_total_ms = 0
			start_run()
		"career":
			hud.show_career(career_info())
		"book":
			book_checkride()
		_ when id.begins_with("practice:"):
			var rows: Array = career_info()["rows"]
			var ix := int(id.get_slice(":", 1))
			if ix >= 0 and ix < rows.size():
				_run_start_ms = Time.get_ticks_msec()
				_paused_total_ms = 0
				start_practice(int(rows[ix]["type"]))
		_ when id.begins_with("lesson:"):
			var lrows: Array = career_info()["rows"]
			var lix := int(id.get_slice(":", 1))
			if lix >= 0 and lix < lrows.size():
				_run_start_ms = Time.get_ticks_msec()
				_paused_total_ms = 0
				start_lesson(int(lrows[lix]["type"]))
		"logbook":
			hud.show_logbook(logbook_text(), Save.data["airports"], _slips_for_logbook())
		"daily":
			_run_start_ms = Time.get_ticks_msec()
			_paused_total_ms = 0
			start_daily()
		"hangar":
			_show_hangar()
		"ad":
			_start_rewarded()
		"back":
			hud.hide_logbook()
			hud.hide_hangar()
			hud.hide_career()
			if state == MENU:
				_show_menu()
			else:
				_redraw_over()

func logbook_text() -> String:
	var g: Array = Save.data["grades"]
	var secs := float(Save.data["flight_seconds"])
	var rank := int(Save.data["rank"])
	return "%s PILOT\nFlight time  %d:%02d h    Landings  %d    Crashes  %d\nGreaser! %d   Smooth %d   Good %d\nFirm %d   Hard %d\nBest run  %d    Best streak  x%d\nAirports stamped  %d / %d" % [
		Career.rank_name(rank), int(secs / 3600.0), int(secs / 60.0) % 60, int(Save.data["landings"]), int(Save.data["crashes"]),
		int(g[0]), int(g[1]), int(g[2]), int(g[3]), int(g[4]), int(Save.data["best"]), int(Save.data["best_streak"]),
		(Save.data["airports"] as Dictionary).size(), Airports.count()]

func date_text(day: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(day * 86400)
	return "%d/%d/%d" % [d["day"], d["month"], d["year"]]

## The pink slips as the logbook shows them: [{date, rank, type}] oldest first.
func _slips_for_logbook() -> Array:
	var out: Array = []
	for sl in Save.data["pink_slips"]:
		out.append({"date": date_text(int(sl["day"])), "rank": Career.rank_name(int(sl["rank"])), "type": Scenarios.NAMES[int(sl["type"])].capitalize()})
	return out

## Book the checkride for the rank being trained for: the instructor must have endorsed you and you must be able to pay the
## examiner's fee. It draws `ride_landings` landing types at random from the rank's list; they are revealed one at a time.
func book_checkride() -> bool:
	if state != MENU and state != OVER:
		return false
	var tgt := career_target()
	if int(Save.data["rank"]) >= Career.max_rank() or not Career.endorsed(Save.data, tgt):
		return false
	var fee := Career.fee(tgt, bool(Save.data["fee_halved"]))
	if int(Save.data["coins"]) < fee:
		hud.flash_warning("Not enough coins for the examiner", Color(1.0, 0.5, 0.4))
		sfx.play(Sfx.DENY, 1.0, -6.0)
		return false
	Save.add("coins", -fee)
	Save.data["fee_halved"] = false
	ride_fee_paid = fee
	ride_target = tgt
	ride_draw.clear()
	for ty in Career.draw(tgt, int(Tuning.ride_landings), _career_rng):
		ride_draw.append(Career.make_entry(ty, tgt, _career_rng))
	ride_idx = 0
	ride_fails.clear()
	ride_passed = false
	ride_fail_type = -1
	mode = RIDE
	_over_kind = "ride"
	_notice = {}
	_saved_plane = plane_id
	score = 0
	strikes = 0
	landings = 0
	last_result = {}
	last_crash = ""
	last_verdict = {}
	sim_time = 0.0
	streak = 0
	best_streak = 0
	run_coins = 0
	_coins_award = 0
	Save.store()
	hud.set_ad_button("", false)
	hud.set_streak(0)
	hud.hide_overlay()
	hud.clear_popup()
	hud.set_score(0)
	hud.set_strikes(0, 1)
	hud.set_fade_now(0.0)
	fx.clear()
	get_tree().paused = false
	_begin_round()
	_snap_camera()
	return true

func _ride_entry() -> Dictionary:
	return ride_draw[clampi(ride_idx, 0, maxi(ride_draw.size() - 1, 0))] if not ride_draw.is_empty() else {}

## What the over / result screen is showing, so BACK from a sub-screen can put it back.
var _notice: Dictionary = {}

func _show_notice(title: String, body: String, prompt: String, color: Color) -> void:
	_notice = {"title": title, "body": body, "prompt": prompt, "color": color}
	hud.show_notice(title, body, prompt, color)

## The checkride is over: a certificate for the new rank, or a pink slip.
func _show_ride_result() -> void:
	select_plane(_saved_plane, false)
	hud.fade_to(0.0)
	hud.clear_popup()
	var tgt := ride_target
	var today := Daily.day_number(Time.get_unix_time_from_system())
	if ride_fails.is_empty():
		ride_passed = true
		_over_kind = "ride_pass"
		Save.record_checkride(tgt, true)
		Save.data["rank"] = tgt
		Career.on_rank_change(Save.data, tgt)
		_notice = {}
		var lines := Career.unlock_lines(tgt)
		var body := "This certifies that WHISKERS has shown the skill and judgement of a %s pilot and is awarded the rating.\n\n%s" % [Career.rank_name(tgt).to_lower(), "\n".join(lines)]
		hud.show_certificate(Career.rank_name(tgt), body, date_text(today))
		sfx.play_step(Sfx.CHIME, 4)
	else:
		ride_passed = false
		_over_kind = "ride_fail"
		Save.record_checkride(tgt, false)
		Save.add_slip(today, tgt, ride_fail_type)
		Career.drop_half(Save.data, ride_fail_type)
		var tname: String = Scenarios.NAMES[ride_fail_type].capitalize()
		var body := "%s checkride  -  landing %d of %d\nFailed: %s\n%s\n\nThe examiner keeps the fee (%d coins). Your %s proficiency drops back to %d / %d: practise it again to be endorsed, then book a retest - a full checkride, a new draw, the full fee." % [
			Career.rank_name(tgt), ride_idx + 1, ride_draw.size(), tname, "\n".join(ride_fails.slice(0, 2)), ride_fee_paid, tname, Career.count(Save.data, ride_fail_type), Career.needed()]
		_show_notice("PINK SLIP", body, "TAP FOR THE CAREER SCREEN", Color(1.0, 0.55, 0.7))
	Save.store()
	_refresh_menu_buttons()
	_refresh_ad_button()

func _redraw_over() -> void:
	if _over_kind == "run":
		hud.over_extra = _fees_text()
		hud.show_over(score, best, landings, false, best_streak, banked, pot_lost)
	elif not _notice.is_empty():
		hud.show_notice(_notice["title"], _notice["body"], _notice["prompt"], _notice["color"])
	_refresh_ad_button()

func _continue_from_over() -> void:
	match _over_kind:
		"daily":
			_show_menu()
		"practice", "ride_fail":
			_show_menu()
			hud.show_career(career_info())
		"ride_pass":
			_show_menu()
		_:
			start_run()

## Count a graded landing in the logbook: totals, grade tally, airport stamp and (free flight) career points.
func _record_landing(grade: int) -> void:
	Save.add("landings", 1)
	Save.add_grade(grade)
	if mode == FREE:
		Ads.note_round()
	_coins_award = 0
	if mode == FREE:
		# the pot: the grade's coins (times the Greaser streak) times the pot multiplier; not banked until you cash out
		_coins_award = int(roundf(float(Cosmetics.coins_for(grade, streak_multiplier())) * pot_multiplier()))
		pot += _coins_award
		hud.set_pot(pot, 1.0 + Tuning.pot_step * float(landings + 1), true)
	elif mode != RIDE:
		_coins_award = Cosmetics.coins_for(grade, streak_multiplier())
		Save.add("coins", _coins_award)
		run_coins += _coins_award
	var id := Airports.id_of(scenario, airport_idx)
	if Save.stamp_airport(id, Airports.name_of(scenario, airport_idx), int(Time.get_unix_time_from_system() / 86400.0)):
		hud.flash_warning("NEW STAMP: " + Airports.name_of(scenario, airport_idx), Color(1.0, 0.85, 0.3))

# ---------- debug (?tune) ----------

func debug_unlock_all(on: bool) -> void:
	Save.data["unlock_all"] = on
	Save.store()
	_refresh_selector()
	_refresh_menu_buttons()

func debug_promote() -> void:
	var r := mini(int(Save.data["rank"]) + 1, Career.max_rank())
	Save.data["rank"] = r
	Career.on_rank_change(Save.data, r)
	Save.store()
	select_plane(plane_id)
	_refresh_menu_buttons()
	if state == MENU:
		_show_menu()

func debug_endorse() -> void:
	for t in Career.types_for(career_target()):
		for k in Career.needed():
			Career.add_practice(Save.data, t)
	Save.store()
	if hud.career_visible():
		hud.show_career(career_info())

func debug_coins() -> void:
	Save.add("coins", 500)
	if hud.hangar_visible():
		_show_hangar()

func debug_cycle_plane() -> void:
	var list := available_planes()
	select_plane(list[(list.find(plane_id) + 1) % list.size()])

func debug_reset_save() -> void:
	Save.reset_all()
	best = 0
	plane_id = Planes.C172
	select_plane(plane_id)
	_refresh_menu_buttons()
	if state == MENU:
		_show_menu()

func _on_debug_action(id: String) -> void:
	match id:
		"unlock_all":
			debug_unlock_all(not bool(Save.data["unlock_all"]))
		"plane":
			debug_cycle_plane()
		"reset_save":
			debug_reset_save()
		"coins":
			debug_coins()
		"promote":
			debug_promote()
		"endorse":
			debug_endorse()

# ---------- practice landings ----------

## One practice landing of `scn`, flown to the standard of the rank being trained for. Meeting the standard fills a proficiency
## pip; a miss or a crash doesn't count.
func start_practice(scn: int) -> void:
	_lesson_active = false
	mode = PRACTICE
	_over_kind = "practice"
	practice_entry = Career.make_entry(scn, career_target(), _career_rng)
	_saved_plane = plane_id
	score = 0
	strikes = 0
	landings = 0
	last_result = {}
	last_crash = ""
	last_verdict = {}
	sim_time = 0.0
	streak = 0
	best_streak = 0
	run_coins = 0
	_coins_award = 0
	hud.set_ad_button("", false)
	hud.set_streak(0)
	hud.hide_overlay()
	hud.clear_popup()
	hud.set_score(0)
	hud.set_strikes(0, 1)
	hud.set_fade_now(0.0)
	fx.clear()
	get_tree().paused = false
	_begin_round()
	_snap_camera()

## An instructor lesson: pay the fee, then fly one practice landing of `scn` that counts double if it meets the standard.
func start_lesson(scn: int) -> bool:
	var fee := Economy.lesson_fee(career_target())
	if int(Save.data["coins"]) < fee or int(Save.data["rank"]) >= Career.max_rank() or Career.count(Save.data, scn) >= Career.needed():
		hud.flash_warning("Not enough coins for the lesson", Color(1.0, 0.5, 0.4))
		sfx.play(Sfx.DENY, 1.0, -6.0)
		return false
	Save.add("coins", -fee)
	Save.store()
	start_practice(scn)
	_lesson_active = true
	hud.set_round_text("LESSON  x2")
	hud.toast("Lesson  -%d coins: a qualifying landing counts double" % fee, Color(1.0, 0.85, 0.4))
	return true

func _show_practice_result() -> void:
	select_plane(_saved_plane, false)
	hud.fade_to(0.0)
	hud.clear_popup()
	var scn := int(practice_entry["scn"])
	var tgt := career_target()
	var top := int(Save.data["rank"]) >= Career.max_rank()
	var name_t: String = Scenarios.NAMES[scn].capitalize()
	var verdict := last_verdict if not last_verdict.is_empty() else {"pass": false, "fails": ["No landing"] as Array[String]}
	var title := ""
	var body := ""
	var color := Color(1.0, 0.55, 0.4)
	if bool(verdict["pass"]):
		title = "STANDARD MET"
		color = Color(0.55, 1.0, 0.6)
		if top:
			body = "%s\nTo the %s standard." % [name_t, Career.rank_name(tgt)]
		else:
			var cr := _credit_proficiency(_lesson_active)
			var n := int(cr.get("n", Career.count(Save.data, scn)))
			body = "%s\nProficiency  %d / %d%s" % [name_t, n, Career.needed(), "   (instructor lesson: counts double)" if _lesson_active else ""]
			if Career.endorsed(Save.data, tgt):
				body += "\n\nEvery landing type is ready: the instructor signs your endorsement for the %s checkride!" % Career.rank_name(tgt)
				sfx.play_step(Sfx.CHIME, 4)
	else:
		title = "NOT TO STANDARD"
		var why: Array = verdict["fails"]
		body = "%s\n%s\n\nIt doesn't count." % [name_t, "\n".join(why.slice(0, 3))]
	_lesson_active = false
	Save.store()
	_refresh_menu_buttons()
	_show_notice(title, body, "TAP FOR THE CAREER SCREEN", color)
	_refresh_ad_button()

# ---------- daily approach ----------

func start_daily() -> void:
	mode = DAILY
	_over_kind = "daily"
	_daily_day = Daily.day_number(Time.get_unix_time_from_system())
	var dl: Dictionary = Save.data["daily"]
	if int(dl["day"]) != _daily_day:
		dl["day"] = _daily_day
		dl["best"] = 0
		dl["tries"] = 0
	dl["tries"] = int(dl["tries"]) + 1
	_saved_plane = plane_id
	score = 0
	strikes = 0
	landings = 0
	last_result = {}
	last_crash = ""
	sim_time = 0.0
	streak = 0
	best_streak = 0
	run_coins = 0
	_coins_award = 0
	hud.set_ad_button("", false)
	hud.set_streak(0)
	hud.hide_overlay()
	hud.clear_popup()
	hud.set_score(0)
	hud.set_strikes(0, 1)
	hud.set_fade_now(0.0)
	fx.clear()
	get_tree().paused = false
	_begin_round()
	_snap_camera()

func _show_daily_result() -> void:
	select_plane(_saved_plane, false)
	var dl: Dictionary = Save.data["daily"]
	var new_best := score > int(dl["best"])
	if new_best:
		dl["best"] = score
	Save.store()
	_refresh_menu_buttons()
	hud.fade_to(0.0)
	hud.clear_popup()
	var e := Daily.for_day(_daily_day)
	var what := "%s, %s, %s" % [Planes.NAMES[e["plane"]], Scenarios.NAMES[e["scn"]].capitalize(), Scenarios.WX_NAMES[e["wx"]].capitalize()]
	_show_notice("DAILY APPROACH", "%s\n%s\n\nScore  %d\n%s\nAttempts today  %d" % [Daily.label(_daily_day), what, score, "NEW BEST!" if new_best else "Best  %d" % int(dl["best"]), int(dl["tries"])], "TAP FOR MENU", Color(1.0, 0.8, 0.35))
	hud.set_ad_button("", false)

# ---------- cosmetics ----------

func _apply_cosmetics() -> void:
	var pi := int(Save.data["paint"])
	if pi > 0 and pi < Cosmetics.PAINTS.size():
		aircraft.set_scheme(Cosmetics.PAINTS[pi]["body"], Cosmetics.PAINTS[pi]["accent"])
	else:
		aircraft.clear_scheme()
	aircraft.set_pilot_gear(clampi(int(Save.data["gear"]), 0, Cosmetics.GEAR.size() - 1))

func _show_hangar() -> void:
	hud.show_hangar(Save.data, available_planes(), plane_id)

func _on_hangar_pick(kind: String, idx: int) -> void:
	if state != MENU and state != OVER:
		return
	if kind == "plane":
		if not available_planes().has(idx):
			hud.flash_warning("Locked: not unlocked by your rank yet. Buy it to own it.", Color(1.0, 0.5, 0.4))
			return
		select_plane(idx)
		Save.store()
		_show_hangar()
		return
	if kind == "plane_buy":
		if Economy.owns(Save.data, idx):
			return
		if not Cosmetics.buy_plane(Save.data, idx):
			hud.flash_warning("Not enough coins", Color(1.0, 0.5, 0.4))
			sfx.play(Sfx.DENY, 1.0, -6.0)
			return
		sfx.play(Sfx.FANFARE, 1.0, -8.0)
		hud.toast("%s is yours: no more rental fees" % Planes.NAMES[idx], Color(1.0, 0.85, 0.35))
		select_plane(idx)
		Save.store()
		_show_hangar()
		return
	if not Cosmetics.owned(Save.data, kind, idx):
		if not Cosmetics.buy(Save.data, kind, idx):
			hud.flash_warning("Not enough coins", Color(1.0, 0.5, 0.4))
			return
	Save.data[kind] = idx
	Save.store()
	_apply_cosmetics()
	_show_hangar()

# ---------- ads (stubs) ----------

func _play_ad(kind: String) -> void:
	_ad_kind = kind
	_ad_t = Tuning.ad_fake_seconds
	state = AD
	hud.show_ad({"double": "Rewarded: double your coins", "fee": "Rewarded: halve your examiner fee", "interstitial": "Interstitial"}[kind] + "\n(stub - no real ad)", _ad_t)

func _finish_ad() -> void:
	hud.hide_ad()
	Ads.played(Time.get_ticks_msec())
	match _ad_kind:
		"double":
			Save.add("coins", run_coins)
			_coins_doubled = true
			hud.flash_warning("+%d coins!" % run_coins, Color(1.0, 0.85, 0.3))
			Save.store()
			state = OVER
			_death_time = Time.get_ticks_msec() / 1000.0
			hud.over_extra = _fees_text()
			hud.show_over(score, best, landings, false, best_streak, banked, pot_lost)
			_refresh_ad_button()
		"fee":
			Save.data["fee_halved"] = true
			Save.store()
			hud.flash_warning("Next examiner fee: %d coins" % Career.fee(career_target(), true), Color(1.0, 0.85, 0.3))
			state = OVER
			_death_time = Time.get_ticks_msec() / 1000.0
			_redraw_over()
		_:
			_begin_round()
			_snap_camera()

## The rewarded button on the run-over / checkride-failed screens.
func _refresh_ad_button() -> void:
	if state != OVER:
		hud.set_ad_button("", false)
		return
	if _over_kind == "run" and run_coins > 0 and not _coins_doubled and DebugFlags.ads_enabled():
		hud.set_ad_button("WATCH AD: DOUBLE COINS (+%d)" % run_coins, true)
	elif _over_kind == "ride_fail" and not bool(Save.data["fee_halved"]) and DebugFlags.ads_enabled():
		hud.set_ad_button("WATCH AD: HALVE YOUR EXAMINER FEE", true)
	else:
		hud.set_ad_button("", false)

func _start_rewarded() -> void:
	if state != OVER:
		return
	if _over_kind == "run" and run_coins > 0 and not _coins_doubled:
		_play_ad("double")
	elif _over_kind == "ride_fail" and not bool(Save.data["fee_halved"]):
		_play_ad("fee")


# ---------- free flight: the choice after a landing, cashing out ----------

## What the hint on the choice screen says about the next approach: "Next: Fog, Short Field".
func _next_hint() -> String:
	var parts: Array[String] = []
	if _next_pick.y != Scenarios.CLEAR:
		parts.append(Scenarios.WX_NAMES[_next_pick.y].capitalize())
	if _next_pick.x != Scenarios.STANDARD:
		parts.append(Scenarios.NAMES[_next_pick.x].capitalize())
	if parts.is_empty():
		parts.append("a plain approach")
	var harder := "winds, gusts and runways get tougher"
	return "Next: %s\n(%s)" % [", ".join(parts), harder]

func _enter_choice() -> void:
	state = CHOICE
	_timer = 0.0
	_next_pick = _pick_free(round_no + 1)
	_next_round = round_no + 1
	hud.set_hint("")
	hud.show_choice({"title": "LANDED!", "pot": pot, "next_mult": pot_multiplier(), "hint": _next_hint()})
	sfx.play_step(Sfx.CHIME, 0, -3.0)
	_set_base_tension(clampf(0.5 + 0.1 * float(landings), 0.5, 1.0))      # the heartbeat comes in: the pot is on the line

func _on_choice(kind: String) -> void:
	if state != CHOICE:
		return
	match kind:
		"keep":
			_set_base_tension(clampf(0.3 + 0.1 * float(landings), 0.3, 0.9))     # ... and stays under the next approach
			hud.hide_choice()
			_after_fade_over = false
			state = FADE
			_timer = 0.0
			hud.fade_to(1.0)
		"cashout":
			_start_cashout()

func _start_cashout() -> void:
	state = CASHOUT
	_cash_t = 0.0
	_cash_shown = 0
	hud.show_cashout()
	hud.fly_coins_to_bank(pot)
	hud.confetti_burst()
	_set_base_tension(0.0)

## The count-up: the number eases up to the pot with a tick for every few coins, gold sparkles at the end, then the run is over.
func _step_cashout(dt: float) -> void:
	_cash_t += dt
	var dur := maxf(Tuning.cashout_seconds, 0.1)
	var p := clampf(_cash_t / dur, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - p, 3.0)
	var n := int(roundf(float(pot) * eased))
	if n != _cash_shown:
		if n / 5 != _cash_shown / 5 and p < 1.0:
			sfx.play_step(Sfx.CHIME, int(p * 6.0), -8.0)
		_cash_shown = n
		hud.set_cash_count(n, 1.0 - p)
	if p >= 1.0 and not _cash_done:
		_cash_done = true
		hud.set_cash_count(pot, 1.0)
		sfx.play_step(Sfx.CHIME, 6)
		fx.sparkle(Vector3(aircraft.x, 6.0, 1.0), 4)
		fx.sparkle(Vector3(aircraft.x + 6.0, 9.0, 1.0), 3)
		hud.confetti_burst()
		sfx.play(Sfx.FANFARE, 1.0, -6.0)
	if p >= 1.0 and _cash_t >= dur + 0.7:
		_finish_cashout()

func _finish_cashout() -> void:
	banked = pot
	run_coins = banked
	Save.add("coins", banked)
	pot = 0
	hud.set_pot(0, 1.0, true)
	Save.store()
	hud.hide_choice()
	_cash_done = false
	_after_fade_over = true
	state = FADE
	_timer = 0.0
	hud.fade_to(1.0)

var _cash_done := false

# ---------- pause ----------

func is_run_paused() -> bool:
	return _paused_run

## States in which the pause button works.
func _can_pause() -> bool:
	return state == CARD or state == APPROACH or state == ROLLOUT or state == CRASH or state == FADE or state == CHOICE or state == CASHOUT

func pause_game() -> void:
	if _paused_run or not _can_pause():
		return
	_paused_run = true
	_pause_confirm = ""
	get_tree().paused = true
	aircraft.clear_input()
	hud.show_pause()

func resume_game() -> void:
	if not _paused_run:
		return
	_paused_run = false
	_pause_confirm = ""
	hud.hide_pause()
	get_tree().paused = false
	aircraft.clear_input()
	_skip_frames = Tuning.resume_skip_frames

func _hide_pause_ui() -> void:
	_paused_run = false
	hud.hide_pause()

func _on_pause_action(id: String) -> void:
	match id:
		"pause":
			pause_game()
		"resume":
			resume_game()
			_release_audio()
		"settings":
			hud.show_pause_settings(float(Save.data["settings"]["sound"]), float(Save.data["settings"]["music"]))
		"settings_back":
			Save.store()
			hud.show_pause_main()
		"quit":
			_pause_confirm = "quit"
			hud.show_pause_confirm(_quit_text())
		"quit_no":
			_pause_confirm = ""
			hud.show_pause_main()
		"quit_yes":
			_quit_run()

## What quitting costs, as the confirmation says it.
func _quit_text() -> String:
	match mode:
		FREE:
			return "Quit and lose %d coins?" % pot if pot > 0 else "Quit this run?"
		RIDE:
			return "Quit the checkride? It counts as a fail: the fee is lost and you get a pink slip."
		PRACTICE:
			return "Quit this practice landing? It won't count."
	return "Quit the daily approach? This attempt is over."

func _quit_run() -> void:
	_paused_run = false
	_pause_confirm = ""
	hud.hide_pause()
	get_tree().paused = false
	hud.hide_choice()
	hud.clear_popup()
	hud.set_hint("")
	match mode:
		FREE:
			pot_lost = pot
			pot = 0
			streak = 0
			hud.set_streak(0)
			_after_fade_over = true
		RIDE:
			ride_fails.append("Quit the checkride")
			ride_fail_type = scenario
			_after_fade_over = true
		PRACTICE:
			last_verdict = {"pass": false, "fails": ["Quit"] as Array[String]}
			_after_fade_over = true
		DAILY:
			_after_fade_over = true
	Save.add("flight_seconds", _flight_acc)
	_flight_acc = 0.0
	Save.store()
	state = FADE
	_timer = 0.0
	hud.fade_to(1.0)

func _on_volume_changed(kind: String, value: float) -> void:
	Save.data["settings"][kind] = clampf(value, 0.0, 1.0)
	_apply_volumes()

## The SFX, Music and Ambience buses come from default_bus_layout.tres (loaded before the audio driver starts). They are NEVER
## created here: adding a bus at run time silences the single-threaded web export.
func _setup_audio() -> void:
	_apply_volumes()

func _apply_volumes() -> void:
	var st: Dictionary = Save.data["settings"]
	for pair in [["SFX", float(st["sound"])], ["Ambience", float(st["sound"])], ["Music", float(st["music"])]]:
		var idx := AudioServer.get_bus_index(pair[0])
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(pair[1], 0.0001)))
			AudioServer.set_bus_mute(idx, pair[1] <= 0.001)