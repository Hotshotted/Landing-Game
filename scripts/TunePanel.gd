class_name TunePanel
extends Node
## On-screen tuning panel, built ONLY when the page URL has ?tune (players never see it).
## A TUNE button (top-right) opens a panel over the paused game; closing it resumes. Each slider
## edits the matching Tuning value live. "Copy values" puts the values that differ from the
## defaults on the clipboard as text (and shows them), and "Reset" restores the defaults.
## Everything is created once at start-up, drawn during the pre-warm, and only shown / hidden after
## that, like every other pooled part of the game.

## Emitted after a value changed (by a slider or Reset), with the Tuning property name.
signal changed(property: String)
## "Next round" pressed.
signal skip_round
signal debug_action(id: String)      # career debug: unlock_all, plane, reset_save, promote, coins, endorse

## [Tuning property, label, min, max, step]
const ENTRIES := [
	["pitch_per_pixel", "Pitch per pixel (deg)", 0.02, 0.2, 0.005],
	["sensitivity", "Sensitivity (1.0 = 1:1)", 0.3, 2.5, 0.05],
	["pitch_rate", "Pitch rate (deg/s)", 10.0, 120.0, 1.0],
	["pitch_return", "Nose return when released", 0.0, 60.0, 1.0],
	["approach_speed", "172 approach speed (u/s)", 12.0, 40.0, 0.5],
	["glide_angle_deg", "Glide path (deg)", 2.0, 5.0, 0.1],
	["approach_seconds", "Approach time (s)", 3.0, 40.0, 0.5],
	["dead_stick_time_mult", "Dead-stick approach x time", 1.0, 2.5, 0.05],
	["instrument_start_ft_above_dh", "Instrument start above DH (ft)", 10.0, 300.0, 5.0],
	["min_start_distance", "Closest start to threshold (u)", 10.0, 150.0, 5.0],
	["vref_cub", "Cub Vref (kt)", 30.0, 70.0, 1.0],
	["stall_cub", "Cub stall (kt)", 25.0, 60.0, 1.0],
	["vref_172", "172 Vref (kt)", 45.0, 90.0, 1.0],
	["stall_172", "172 stall (kt)", 35.0, 70.0, 1.0],
	["vref_twin", "Twin Vref (kt)", 60.0, 120.0, 1.0],
	["stall_twin", "Twin stall (kt)", 45.0, 100.0, 1.0],
	["vref_glider", "Glider Vref (kt)", 40.0, 80.0, 1.0],
	["stall_glider", "Glider stall (kt)", 30.0, 60.0, 1.0],
	["vref_jet", "Jet Vref (kt)", 100.0, 170.0, 1.0],
	["stall_jet", "Jet stall (kt)", 80.0, 150.0, 1.0],
	["pitch_lift_gain", "Sink change per deg", 0.05, 0.6, 0.01],
	["response_time", "Sink response (s)", 0.1, 1.2, 0.01],
	["speed_bleed", "Speed bleed, nose up", 0.0, 1.0, 0.01],
	["speed_recover", "Speed recovery", 0.05, 1.0, 0.01],
	["stall_sink_gain", "Stall sink gain", 0.0, 40.0, 0.5],
	["ground_effect_lift", "Ground-effect float", 0.0, 1.5, 0.02],
	["ground_effect_bleed", "Flare bleed in ground effect", 0.0, 4.0, 0.1],
	["wind_head_max", "Max headwind", 0.0, 20.0, 0.5],
	["wind_tail_max", "Max tailwind", 0.0, 12.0, 0.5],
	["gust_strength", "Gust strength (vertical)", 0.0, 6.0, 0.1],
	["gust_horizontal", "Gust strength (horizontal)", 0.0, 8.0, 0.1],
	["gust_interval_min", "Gust gap min (s)", 0.5, 8.0, 0.1],
	["gust_interval_max", "Gust gap max (s)", 1.0, 12.0, 0.1],
	["fps_greaser", "Greaser under (ft/s)", 0.5, 4.0, 0.1],
	["fps_smooth", "Smooth under (ft/s)", 1.0, 6.0, 0.1],
	["fps_good", "Good under (ft/s)", 2.0, 8.0, 0.1],
	["fps_firm", "Firm under (ft/s)", 3.0, 12.0, 0.1],
	["fps_zero", "Sink points reach zero (ft/s)", 4.0, 16.0, 0.5],
	["fps_crash", "Structural limit (ft/s)", 6.0, 24.0, 0.5],
	["fps_bounce", "Bounce above (ft/s)", 3.0, 16.0, 0.5],
	["bounce_restitution", "Bounce height", 0.0, 0.9, 0.01],
	["position_perfect_ft", "Aim zone, perfect (ft)", 10.0, 200.0, 5.0],
	["position_zero_ft", "Aim zone, zero points (ft)", 100.0, 1000.0, 10.0],
	["grade_greaser", "Greaser! needs points", 60.0, 100.0, 1.0],
	["grade_smooth", "Smooth needs points", 40.0, 95.0, 1.0],
	["grade_good", "Good needs points", 20.0, 80.0, 1.0],
	["grade_firm", "Firm needs points", 5.0, 60.0, 1.0],
	["decel_asphalt", "Braking, asphalt", 1.0, 15.0, 0.1],
	["decel_grass", "Braking, grass", 1.0, 15.0, 0.1],
	["decel_dirt", "Braking, dirt", 1.0, 15.0, 0.1],
	["path_error_max", "Approach miss (max, u)", 0.0, 120.0, 1.0],
	["ramp_rounds", "Rounds to full difficulty", 1.0, 30.0, 1.0],
	["streak_glow_max", "Streak glow", 0.0, 1.0, 0.05],
	["go_around_low", "Go-around: low point", 5.0, 40.0, 1.0],
	["go_around_climb", "Go-around: climb that counts", 5.0, 40.0, 1.0],
	["gate_height_ft", "Speed gate height (ft)", 20.0, 150.0, 5.0],
	["soft_nose_deg", "Soft field: nose held above (deg)", 0.0, 8.0, 0.5],
	["soft_release", "Soft field: nose may drop below (x speed)", 0.2, 0.9, 0.05],
	["soft_decel_mult", "Soft field drag", 1.0, 2.5, 0.05],
	["instrument_dh_ft", "Instrument decision height (ft)", 50.0, 300.0, 10.0],
	["instrument_dev_seconds", "Instrument: seconds off path allowed", 0.5, 8.0, 0.5],
	["ad_fake_seconds", "Ad stub: seconds", 0.5, 6.0, 0.5],
	["ad_interstitial_every", "Interstitial every N rounds", 2.0, 10.0, 1.0],
	["engine_out_drag", "Engine out: speed decay", 0.0, 0.12, 0.005],
	["turb_strength", "Turbulence strength", 0.0, 4.0, 0.1],
	["shear_sink", "Wind shear downdraft", 0.0, 8.0, 0.1],
	["shear_tele_time", "Wind shear warning (s)", 0.3, 3.0, 0.1],
	["fog_end_min", "Fog visibility (min)", 40.0, 300.0, 5.0],
	["carrier_wire_half", "Carrier wire zone", 4.0, 30.0, 0.5],
	["water_rough_mult", "Rough water sink x", 1.0, 3.0, 0.05],
	["card_time", "Title card time (s)", 0.3, 4.0, 0.1],
	["papi_hud_size", "HUD PAPI: light size", 50.0, 200.0, 1.0],
	["papi_hud_gap", "HUD PAPI: gap", 0.0, 60.0, 1.0],
	["papi_hud_y", "HUD PAPI: height (screen fraction)", 0.1, 0.6, 0.01],
	["papi_hud_fade", "HUD PAPI: colour speed", 2.0, 30.0, 0.5],
	["papi_hud_follow", "HUD PAPI: follow speed", 2.0, 30.0, 0.5],
	["papi_band", "PAPI step spacing", 0.04, 0.3, 0.01],
	["papi_hysteresis", "PAPI hysteresis", 0.0, 0.5, 0.01],
	["shake_per_sink", "Shake per sink rate", 0.0, 0.8, 0.01],
	["shake_size", "Shake size", 0.0, 3.0, 0.1],
	["smoke_count", "Smoke puffs", 4.0, 60.0, 1.0],
]

## [Tuning property, label]: on/off switches.
const TOGGLES := [
	["wind_enabled", "Wind and gusts"],
]

## Screen rect of the TUNE button, so the game can ignore touches that land on it.
static var _button_rect := Rect2()

## True if a touch at `pos` (viewport coordinates) is on the TUNE button.
static func button_hit(pos: Vector2) -> bool:
	return _button_rect.has_point(pos)

var is_open := false
var last_copied_text := ""          # what the Copy button last put on the clipboard
var _defaults := {}                 # property -> default value, captured at build time
var _sliders := {}                  # property -> HSlider
var _value_labels := {}             # property -> Label
var _toggles := {}                  # property -> CheckButton
var _button_layer: CanvasLayer
var _panel_layer: CanvasLayer
var _button: Button
var _panel: Control
var _out: Label

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused

## Create everything (called once by Main, only when ?tune is on).
func build() -> void:
	for e in ENTRIES:
		_defaults[e[0]] = Tuning.get(e[0])
	for t in TOGGLES:
		_defaults[t[0]] = Tuning.get(t[0])
	# Shared look for every slider: a thick track and a big round handle (the default is tiny on a phone).
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.22, 0.27, 0.36)
	track.set_corner_radius_all(8)
	track.content_margin_top = 8
	track.content_margin_bottom = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.25, 0.8, 0.5)
	fill.set_corner_radius_all(8)
	fill.content_margin_top = 8
	fill.content_margin_bottom = 8
	var knob := _circle_texture(52, Color(0.95, 0.97, 1.0))
	var tick_off := _ring_texture(52, Color(0.7, 0.75, 0.85))
	var tick_on := _circle_texture(52, Color(0.25, 0.9, 0.5))
	# The panel: a dark overlay over the whole screen. Hidden until opened; layer 0 so that during
	# the start-up pre-warm it is drawn UNDER the splash screen.
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 0
	add_child(_panel_layer)
	_panel = Control.new()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	_panel_layer.add_child(_panel)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.11, 0.94)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	margin.add_theme_constant_override("margin_top", 110)   # leaves room for the TUNE / CLOSE button
	_panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	column.add_child(_make_label("TUNING  (live)", 44, HORIZONTAL_ALIGNMENT_LEFT))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for e in ENTRIES:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var head := HBoxContainer.new()
		var name_label := _make_label(e[1], 32, HORIZONTAL_ALIGNMENT_LEFT)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var value_label := _make_label("", 32, HORIZONTAL_ALIGNMENT_RIGHT)
		value_label.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
		head.add_child(name_label)
		head.add_child(value_label)
		row.add_child(head)
		var slider := HSlider.new()
		slider.min_value = e[2]
		slider.max_value = e[3]
		slider.step = e[4]
		slider.custom_minimum_size = Vector2(0, 60)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.add_theme_stylebox_override("slider", track)
		slider.add_theme_stylebox_override("grabber_area", fill)
		slider.add_theme_stylebox_override("grabber_area_highlight", fill)
		for icon in ["grabber", "grabber_highlight", "grabber_disabled"]:
			slider.add_theme_icon_override(icon, knob)
		slider.value = Tuning.get(e[0])
		slider.value_changed.connect(_on_slider.bind(e[0]))
		row.add_child(slider)
		list.add_child(row)
		_sliders[e[0]] = slider
		_value_labels[e[0]] = value_label
		_show_value(e[0])
	for t in TOGGLES:
		var check := CheckButton.new()
		check.text = t[1]
		check.add_theme_font_size_override("font_size", 32)
		check.custom_minimum_size = Vector2(0, 76)
		check.button_pressed = Tuning.get(t[0])
		check.add_theme_icon_override("unchecked", tick_off)
		check.add_theme_icon_override("checked", tick_on)
		check.toggled.connect(_on_toggle.bind(t[0]))
		list.add_child(check)
		_toggles[t[0]] = check
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 20)
	var reset := _make_button("Reset", 36)
	reset.pressed.connect(reset_defaults)
	var copy := _make_button("Copy values", 36)
	copy.pressed.connect(copy_values)
	var next := _make_button("Next round", 36)
	next.pressed.connect(func(): skip_round.emit(); close())
	buttons.add_child(reset)
	buttons.add_child(copy)
	buttons.add_child(next)
	column.add_child(buttons)
	# force a scenario / weather for every following approach (AUTO = the normal mix); press "Next round" to see it
	var force_row := HBoxContainer.new()
	force_row.add_theme_constant_override("separation", 20)
	var scn_btn := _make_button("Scenario: AUTO", 28)
	scn_btn.set_meta("debug", "force_scenario")
	scn_btn.pressed.connect(func():
		Scenarios.forced_scenario = Scenarios.forced_scenario + 1 if Scenarios.forced_scenario + 1 < Scenarios.COUNT else -1
		scn_btn.text = "Scenario: " + (Scenarios.KEYS[Scenarios.forced_scenario].to_upper() if Scenarios.forced_scenario >= 0 else "AUTO"))
	var wx_btn := _make_button("Weather: AUTO", 28)
	wx_btn.set_meta("debug", "force_weather")
	wx_btn.pressed.connect(func():
		Scenarios.forced_weather = Scenarios.forced_weather + 1 if Scenarios.forced_weather + 1 < Scenarios.WX_COUNT else -1
		wx_btn.text = "Weather: " + (Scenarios.WX_KEYS[Scenarios.forced_weather].to_upper() if Scenarios.forced_weather >= 0 else "AUTO"))
	force_row.add_child(scn_btn)
	force_row.add_child(wx_btn)
	column.add_child(force_row)
	var career_row := HBoxContainer.new()
	career_row.add_theme_constant_override("separation", 20)
	var unlock_btn := _make_button("Unlock all: " + ("ON" if Save.data["unlock_all"] else "OFF"), 28)
	unlock_btn.set_meta("debug", "unlock_all")
	unlock_btn.pressed.connect(func():
		debug_action.emit("unlock_all")
		unlock_btn.text = "Unlock all: " + ("ON" if Save.data["unlock_all"] else "OFF"))
	var plane_btn := _make_button("Next aircraft", 28)
	plane_btn.set_meta("debug", "plane")
	plane_btn.pressed.connect(func(): debug_action.emit("plane"))
	var ride_btn := _make_button("Promote rank", 28)
	ride_btn.set_meta("debug", "promote")
	ride_btn.pressed.connect(func(): debug_action.emit("promote"))
	var wipe_btn := _make_button("Reset save", 28)
	wipe_btn.set_meta("debug", "reset_save")
	wipe_btn.pressed.connect(func():
		debug_action.emit("reset_save")
		unlock_btn.text = "Unlock all: OFF")
	career_row.add_child(unlock_btn)
	career_row.add_child(plane_btn)
	career_row.add_child(ride_btn)
	career_row.add_child(wipe_btn)
	column.add_child(career_row)
	var coin_row := HBoxContainer.new()
	coin_row.add_theme_constant_override("separation", 20)
	var coin_btn := _make_button("+500 coins", 28)
	coin_btn.set_meta("debug", "coins")
	coin_btn.pressed.connect(func(): debug_action.emit("coins"))
	coin_row.add_child(coin_btn)
	var endorse_btn := _make_button("Fill meters", 28)
	endorse_btn.set_meta("debug", "endorse")
	endorse_btn.pressed.connect(func(): debug_action.emit("endorse"))
	coin_row.add_child(endorse_btn)
	column.add_child(coin_row)
	_out = _make_label("", 26, HORIZONTAL_ALIGNMENT_LEFT)
	_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_out.custom_minimum_size = Vector2(0, 150)
	column.add_child(_out)
	# The TUNE / CLOSE button, always on top, top-right. Hidden until the game has finished starting.
	_button_layer = CanvasLayer.new()
	_button_layer.layer = 20
	add_child(_button_layer)
	_button = _make_button("TUNE", 32)
	_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_button.offset_left = -190.0
	_button.offset_right = -20.0
	_button.offset_top = 20.0
	_button.offset_bottom = 96.0
	_button.pressed.connect(toggle)
	_button.visible = false
	_button_layer.add_child(_button)

func _process(_delta: float) -> void:
	_button_rect = _button.get_global_rect() if _button.visible else Rect2()

## Show or hide the TUNE button (hidden while the game is still starting up).
func set_available(on: bool) -> void:
	_button.visible = on

## Start-up pre-warm: draw the panel (under the splash) so its fonts and widgets are set up.
func prewarm_show(on: bool) -> void:
	_panel.visible = on

func toggle() -> void:
	if is_open:
		close()
	else:
		open()

## Open the panel over the game and pause it.
func open() -> void:
	is_open = true
	_panel_layer.layer = 19
	_panel.visible = true
	_button.text = "CLOSE"
	_out.text = ""
	get_tree().paused = true

## Close the panel and resume the game.
func close() -> void:
	is_open = false
	_panel.visible = false
	_panel_layer.layer = 0
	_button.text = "TUNE"
	get_tree().paused = false

func _on_slider(value: float, property: String) -> void:
	Tuning.set(property, value)
	_show_value(property)
	changed.emit(property)

func _on_toggle(on: bool, property: String) -> void:
	Tuning.set(property, on)
	changed.emit(property)

## Put every tuned value back to its default (as captured when the panel was built).
func reset_defaults() -> void:
	for t in TOGGLES:
		var name: String = t[0]
		Tuning.set(name, _defaults[name])
		_toggles[name].set_pressed_no_signal(_defaults[name])
		changed.emit(name)
	for e in ENTRIES:
		var property: String = e[0]
		Tuning.set(property, _defaults[property])
		_sliders[property].set_value_no_signal(_defaults[property])
		_show_value(property)
		changed.emit(property)
	_out.text = "Reset to defaults."

## The values that differ from the defaults, one "name = value" per line, ready to paste.
func changed_text() -> String:
	var lines: Array[String] = []
	for e in ENTRIES:
		var property: String = e[0]
		var v: float = Tuning.get(property)
		if not is_equal_approx(v, _defaults[property]):
			lines.append("%s = %s" % [property, _format(v, e[4])])
	for t in TOGGLES:
		var name: String = t[0]
		if bool(Tuning.get(name)) != bool(_defaults[name]):
			lines.append("%s = %s" % [name, str(bool(Tuning.get(name))).to_lower()])
	return "(no changes)" if lines.is_empty() else "\n".join(lines)

## Copy the changed values to the clipboard and show them on screen too (in case the browser
## doesn't allow clipboard access).
func copy_values() -> void:
	last_copied_text = changed_text()
	DisplayServer.clipboard_set(last_copied_text)
	_out.text = "Copied:\n" + last_copied_text

func _show_value(property: String) -> void:
	var step: float = 0.0
	for e in ENTRIES:
		if e[0] == property:
			step = e[4]
	var v: float = Tuning.get(property)
	var text := _format(v, step)
	if not is_equal_approx(v, _defaults.get(property, v)):
		text += "   (default %s)" % _format(_defaults[property], step)
	_value_labels[property].text = text

## A number with as many decimals as the slider's step has (0.5 -> 1, 0.01 -> 2, 5 -> 0).
func _format(v: float, step: float) -> String:
	var decimals := 0
	var s := step
	while decimals < 4 and absf(s - roundf(s)) > 0.0001:
		s *= 10.0
		decimals += 1
	return ("%." + str(decimals) + "f") % v   # keeps trailing zeros: 0.50, not 0.5

func _make_label(text: String, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _make_button(text: String, size: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(170, 76)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return b

## A hollow ring, used as the "off" icon of the switch.
func _ring_texture(diameter: int, color: Color) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var c := (diameter - 1) * 0.5
	for y in diameter:
		for x in diameter:
			var d := Vector2(x - c, y - c).length()
			var edge := clampf(c + 0.5 - d, 0.0, 1.0) * clampf(d - (c - 6.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, edge))
	return ImageTexture.create_from_image(img)

## A filled circle, used as the slider handle.
func _circle_texture(diameter: int, color: Color) -> ImageTexture:
	var img := Image.create(diameter, diameter, false, Image.FORMAT_RGBA8)
	var c := (diameter - 1) * 0.5
	for y in diameter:
		for x in diameter:
			var d := Vector2(x - c, y - c).length()
			img.set_pixel(x, y, Color(color.r, color.g, color.b, clampf(c + 0.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
