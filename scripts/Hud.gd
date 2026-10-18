class_name Hud
extends CanvasLayer
## All 2D UI: score / strikes / wind / runway info, the flight readout (altitude, sink rate, airspeed
## bar), the grade popup, the menu / game-over overlay, the round-change fade, the build stamp and
## the ?perf readout. Everything is created once; after that only text, colours and visibility change.


var _score: Label
var _round: Label
var _strikes: Array[ColorRect] = []
var _wind: Label
var _runway: Label
var _alt: Label
var _sink: Label
var _speed_bar: ColorRect
var _speed_back: ColorRect
var _stall_mark: ColorRect
var _speed_label: Label
var _gust: Label
var _dist: Label
var _streak_label: Label
var _glow: ColorRect
var _glow_mat: ShaderMaterial
var _streak_n := 0
var _streak_pop := 0.0
var _streak_lost_t := 0.0
var _glow_level := 0.0
signal plane_step(dir: int)
signal menu_action(id: String)          # "fly", "ride", "logbook", "back" (more are added by the later phases)
var _menu_row: Control
var _menu_buttons := {}                 # id -> Button
var _log_root: Control
var _log_stamps: Array[Panel] = []
var _log_stamp_names: Array[Label] = []
var _log_back: Button
var _log_on := false
const STAMP_COLS := 3
signal hangar_pick(kind: String, idx: int)
var _hangar_root: Control
var _hangar_paint: Array[Button] = []
var _hangar_gear: Array[Button] = []
var _hangar_on := false
var _ad_root: ColorRect
var _ad_title: Label
var _ad_sub: Label
var _ad_time: Label
var _ad_on := false
var _sel_row: Control
var _sel_name: Label
var _sel_info: Label
var _sel_prev: Button
var _sel_next: Button
var stall_marker := 0.72
var _scn_label: Label
var _card_root: Control
var _card_title: Label
var _card_sub: Label
var _card_blurb: Label
var _card_t := 0.0
var _card_on := false
# the big PAPI in the sky above the plane (four round lights + a caption), animated in update()
var _papi_row: Control
var _papi_back: Panel
var _papi_lights: Array[Panel] = []
var _papi_styles: Array[StyleBoxFlat] = []
var _papi_cols: Array[Color] = []          # the colours the lights are showing right now (they ease toward the target)
var _papi_pop := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
var _papi_caption: Label
var _papi_target := 2                      # how many lights should be white
var _papi_shown_n := -1
var _papi_x := 540.0                       # row centre, screen pixels (eases toward _papi_x_target)
var _papi_x_target := 540.0
var _papi_alpha := 0.0
var _papi_show := false
var _papi_built_size := -1.0
var _hint: Label
var _pop_title: Label
var _pop_sub: Label
var _pop_t := 99.0
var _pop_len := 1.7
var _pop_color := Color.WHITE
var _overlay: ColorRect
var _ov_title: Label
var _ov_body: Label
var _ov_prompt: Label
var _fade: ColorRect
var _fade_target := 0.0
var _splash: ColorRect
var _stamp: Label
var _perf: Label
var _perf_worst := 0.0
var _perf_window_start := 0
var _perf_shown := 0.0
var _hitch_log: Array[String] = []
var _hitch_count := 0
var _clock_text := ""
var _t := 0.0
var overlay_visible := false

func _ready() -> void:
	layer = 5
	_glow = ColorRect.new()
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glow_mat = ShaderMaterial.new()
	_glow_mat.shader = preload("res://shaders/streak_glow.gdshader")
	_glow.material = _glow_mat
	_glow.visible = false
	add_child(_glow)
	_score = _label(64, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_score, 0, 0, 24, 16, 400, 90)
	_round = _label(34, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_round, 0, 0, 24, 98, 400, 44)
	for i in 3:
		var r := ColorRect.new()
		r.color = Color(0.25, 0.28, 0.34, 0.8)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_place(r, 0, 0, 28 + i * 52, 150, 40, 40)
		add_child(r)
		_strikes.append(r)
	_wind = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_wind, 0.5, 0, -270, 18, 540, 52)
	_runway = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_runway, 0.5, 0, -270, 72, 540, 40)
	_dist = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_dist, 0.5, 0, -270, 110, 540, 42)
	_streak_label = _label(46, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_streak_label, 0, 0, 24, 236, 520, 70)
	_streak_label.visible = false
	_scn_label = _label(26, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_scn_label, 0, 0, 24, 198, 520, 34)
	_scn_label.modulate = Color(1, 1, 1, 0.8)
	_gust = _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	_gust.modulate = Color(1, 0.9, 0.4, 0)
	_gust.text = "GUST!"
	_place(_gust, 0.5, 0, -270, 154, 540, 44)
	_alt = _label(32, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_alt, 1, 0, -300, 118, 280, 40)
	_sink = _label(46, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_sink, 1, 0, -400, 160, 380, 56)
	_speed_back = ColorRect.new()
	_speed_back.color = Color(0, 0, 0, 0.45)
	_speed_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_speed_back, 1, 0, -300, 232, 280, 22)
	add_child(_speed_back)
	_speed_bar = ColorRect.new()
	_speed_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_speed_bar, 1, 0, -296, 236, 100, 14)
	add_child(_speed_bar)
	_stall_mark = ColorRect.new()
	_stall_mark.color = Color(1, 0.3, 0.25)
	_stall_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(_stall_mark, 1, 0, -300, 228, 4, 30)
	add_child(_stall_mark)
	_speed_label = _label(24, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_speed_label, 1, 0, -300, 258, 280, 32)
	_speed_label.text = "AIRSPEED"
	_hint = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_hint, 0.5, 1, -440, -380, 880, 200)
	_pop_title = _label(140, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_pop_title, 0, 0.3, 0, 0, 1080, 170)
	_pop_title.anchor_right = 1.0
	_pop_title.offset_right = 0
	_pop_sub = _label(48, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_pop_sub, 0, 0.3, 0, 175, 1080, 140)
	_pop_sub.anchor_right = 1.0
	_pop_sub.offset_right = 0
	_pop_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pop_title.modulate.a = 0.0
	_pop_sub.modulate.a = 0.0
	# the big PAPI: a dark pill with four round lights and a caption, in the empty sky above the plane
	_papi_row = Control.new()
	_papi_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_papi_row.visible = false
	add_child(_papi_row)
	_papi_back = Panel.new()
	_papi_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back_style := StyleBoxFlat.new()
	back_style.bg_color = Color(0.04, 0.06, 0.1, 0.5)
	back_style.set_corner_radius_all(48)
	_papi_back.add_theme_stylebox_override("panel", back_style)
	_papi_row.add_child(_papi_back)
	for i in 4:
		var light := Panel.new()
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 1, 1)
		st.border_color = Color(0, 0, 0, 0.95)
		light.add_theme_stylebox_override("panel", st)
		_papi_row.add_child(light)
		_papi_lights.append(light)
		_papi_styles.append(st)
		_papi_cols.append(Color(1, 1, 1))
	_papi_caption = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_papi_caption)
	_papi_row.add_child(_papi_caption)
	_papi_caption.text = "ON PATH"
	_papi_shown_n = 2
	# the scenario title card
	_card_root = Control.new()
	_card_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_root.visible = false
	add_child(_card_root)
	var card_back := ColorRect.new()
	card_back.color = Color(0.03, 0.05, 0.09, 0.62)
	card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_back.anchor_right = 1.0
	card_back.anchor_top = 0.27
	card_back.anchor_bottom = 0.27
	card_back.offset_bottom = 520
	_card_root.add_child(card_back)
	_card_title = _label(104, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_card_title)
	_card_root.add_child(_card_title)
	_place(_card_title, 0, 0.27, 0, 40, 1080, 130)
	_card_title.anchor_right = 1.0
	_card_title.offset_right = 0
	_card_sub = _label(54, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_card_sub)
	_card_root.add_child(_card_sub)
	_place(_card_sub, 0, 0.27, 0, 180, 1080, 70)
	_card_sub.anchor_right = 1.0
	_card_sub.offset_right = 0
	_card_blurb = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_card_blurb)
	_card_root.add_child(_card_blurb)
	_card_blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_card_blurb, 0.5, 0.27, -440, 270, 880, 220)
	# the aircraft selector (shown on the menu and game-over screens)
	_sel_row = Control.new()
	_sel_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sel_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sel_row.visible = false
	add_child(_sel_row)
	_sel_name = _label(78, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_sel_name)
	_sel_row.add_child(_sel_name)
	_place(_sel_name, 0, 0.52, 160, 0, 760, 100)
	_sel_info = _label(32, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_sel_info)
	_sel_row.add_child(_sel_info)
	_sel_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_sel_info, 0, 0.52, 120, 110, 840, 150)
	_sel_prev = _sel_button("<", -1)
	_place(_sel_prev, 0, 0.52, 24, 0, 120, 100)
	_sel_next = _sel_button(">", 1)
	_place(_sel_next, 0, 0.52, 936, 0, 120, 100)
	_build_menu_buttons()
	_build_logbook()
	_build_hangar()
	_build_ad()
	# menu / game-over overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.08, 0.14, 0.62)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_ov_title = _label(150, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_ov_title, 0, 0.09, 0, 0, 1080, 190)
	_ov_title.anchor_right = 1.0
	_ov_title.offset_right = 0
	_ov_body = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_ov_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_ov_body, 0.5, 0.09, -440, 190, 880, 560)
	_ov_prompt = _label(56, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_ov_prompt, 0, 0.72, 0, 0, 1080, 80)
	_ov_prompt.anchor_right = 1.0
	_ov_prompt.offset_right = 0
	_overlay.visible = false
	_ov_title.visible = false
	_ov_body.visible = false
	_ov_prompt.visible = false
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)
	# build stamp + active debug flags, bottom-left
	_stamp = _label(24, HORIZONTAL_ALIGNMENT_LEFT)
	var flags := DebugFlags.summary()
	_stamp.text = "%s  %s" % [BuildInfo.COMMIT, BuildInfo.TIME] + (("\n" + flags) if flags != "" else "")
	_place(_stamp, 0, 1, 14, -84 if flags != "" else -48, 700, 70)
	_stamp.modulate = Color(1, 1, 1, 0.55)
	if DebugFlags.perf_enabled():
		_perf = _label(26, HORIZONTAL_ALIGNMENT_LEFT)
		_place(_perf, 0, 0, 14, 210, 700, 300)
		_perf.modulate = Color(0.6, 1, 0.6, 0.9)
	# start-up splash (above everything but the stamp)
	_splash = ColorRect.new()
	_splash.color = Color(0.08, 0.14, 0.24, 0.97)
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash.visible = false
	add_child(_splash)
	move_child(_sel_row, _splash.get_index())     # (the aircraft selector sits above the dark overlay, below the splash)
	move_child(_menu_row, _splash.get_index())
	move_child(_log_root, _splash.get_index())
	move_child(_hangar_root, _splash.get_index())
	move_child(_ad_root, _splash.get_index())
	move_child(_stamp, get_child_count() - 1)

## The buttons under the aircraft selector (menu and run-over screens). Built once; only shown / hidden / re-texted.
func _build_menu_buttons() -> void:
	_menu_row = Control.new()
	_menu_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_row.visible = false
	add_child(_menu_row)
	var ids := ["fly", "ride", "logbook"]
	var texts := ["FLY", "CHECKRIDE", "LOGBOOK"]
	for i in ids.size():
		var b := Button.new()
		b.text = texts[i]
		b.add_theme_font_size_override("font_size", 44)
		var id: String = ids[i]
		b.pressed.connect(func(): menu_action.emit(id))
		_menu_row.add_child(b)
		_place(b, 0, 0.78, 30 + i * 342, 0, 330, 120)
		_menu_buttons[id] = b
	var ids2 := ["daily", "hangar"]
	var texts2 := ["DAILY", "HANGAR"]
	for i in ids2.size():
		var b2 := Button.new()
		b2.text = texts2[i]
		b2.add_theme_font_size_override("font_size", 44)
		var id2: String = ids2[i]
		b2.pressed.connect(func(): menu_action.emit(id2))
		_menu_row.add_child(b2)
		_place(b2, 0, 0.78, 30 + i * 342, 140, 330, 120)
		_menu_buttons[id2] = b2
	# the rewarded-ad button (a stub; shown only where an ad can be offered)
	var ad := Button.new()
	ad.text = "WATCH AD"
	ad.add_theme_font_size_override("font_size", 40)
	ad.pressed.connect(func(): menu_action.emit("ad"))
	_menu_row.add_child(ad)
	_place(ad, 0, 0.78, 372, 140, 678, 120)
	ad.visible = false
	_menu_buttons["ad"] = ad

func set_ad_button(text: String, shown: bool) -> void:
	var b: Button = _menu_buttons["ad"]
	b.text = text
	b.visible = shown

## The hangar: paint schemes and pilot gear as buttons (buy / equip), built once.
func _build_hangar() -> void:
	_hangar_root = Control.new()
	_hangar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hangar_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hangar_root.visible = false
	add_child(_hangar_root)
	var h1 := _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(h1)
	_hangar_root.add_child(h1)
	h1.text = "PAINT"
	_place(h1, 0, 0, 0, 500, 1080, 50)
	h1.anchor_right = 1.0
	h1.offset_right = 0
	for i in Cosmetics.PAINTS.size():
		_hangar_paint.append(_hangar_button("paint", i, 560 + (i / 2) * 110))
	var h2 := _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(h2)
	_hangar_root.add_child(h2)
	h2.text = "WHISKERS' GEAR"
	_place(h2, 0, 0, 0, 910, 1080, 50)
	h2.anchor_right = 1.0
	h2.offset_right = 0
	for i in Cosmetics.GEAR.size():
		_hangar_gear.append(_hangar_button("gear", i, 970 + (i / 2) * 110))
	var back := Button.new()
	back.text = "BACK"
	back.add_theme_font_size_override("font_size", 48)
	back.pressed.connect(func(): menu_action.emit("back"))
	_hangar_root.add_child(back)
	_place(back, 0.5, 0, -170, 1330, 340, 110)

func _hangar_button(kind: String, idx: int, y: float) -> Button:
	var b := Button.new()
	b.add_theme_font_size_override("font_size", 32)
	b.pressed.connect(func(): hangar_pick.emit(kind, idx))
	_hangar_root.add_child(b)
	_place(b, 0, 0, 30 + (idx % 2) * 520, y, 500, 96)
	return b

## Refresh the hangar's buttons from the save: "[NAME]" equipped, "NAME" owned, "NAME  150c" for sale.
func show_hangar(data: Dictionary) -> void:
	_hangar_on = true
	_set_overlay(true)
	_ov_title.text = "HANGAR"
	_ov_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_ov_title.add_theme_font_size_override("font_size", 110)
	_ov_body.text = "Coins  %d\nPaint and gear are just for looks." % int(data["coins"])
	_ov_prompt.text = ""
	for i in _hangar_paint.size():
		var p: Dictionary = Cosmetics.PAINTS[i]
		_hangar_paint[i].text = _hangar_label(p["name"], p["cost"], (data["owned_paint"] as Array).has(i), int(data["paint"]) == i)
		_hangar_paint[i].disabled = false
	for i in _hangar_gear.size():
		var g: Dictionary = Cosmetics.GEAR[i]
		_hangar_gear[i].text = _hangar_label(g["name"], g["cost"], (data["owned_gear"] as Array).has(i), int(data["gear"]) == i)
	_hangar_root.visible = true
	_menu_row.visible = false
	_sel_row.visible = false

func _hangar_label(item_name: String, cost: int, owned: bool, equipped: bool) -> String:
	if equipped:
		return "[%s]" % item_name
	return item_name if owned else "%s  %dc" % [item_name, cost]

func hide_hangar() -> void:
	_hangar_on = false
	_hangar_root.visible = false
	_ov_title.add_theme_font_size_override("font_size", 150)

func hangar_visible() -> bool:
	return _hangar_on

## The fake "Ad playing" screen (a stub for a real ad SDK): covers everything but the splash.
func _build_ad() -> void:
	_ad_root = ColorRect.new()
	_ad_root.color = Color(0.04, 0.04, 0.06, 0.96)
	_ad_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ad_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ad_root.visible = false
	add_child(_ad_root)
	_ad_title = _label(110, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_ad_title)
	_ad_root.add_child(_ad_title)
	_ad_title.text = "AD PLAYING"
	_place(_ad_title, 0, 0.36, 0, 0, 1080, 140)
	_ad_title.anchor_right = 1.0
	_ad_title.offset_right = 0
	_ad_sub = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_ad_sub)
	_ad_root.add_child(_ad_sub)
	_ad_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_ad_sub, 0.5, 0.36, -420, 160, 840, 140)
	_ad_time = _label(80, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_ad_time)
	_ad_root.add_child(_ad_time)
	_place(_ad_time, 0, 0.36, 0, 330, 1080, 100)
	_ad_time.anchor_right = 1.0
	_ad_time.offset_right = 0

func show_ad(sub: String, seconds: float) -> void:
	_ad_on = true
	_ad_root.visible = true
	_ad_sub.text = sub
	set_ad_time(seconds)

func set_ad_time(seconds: float) -> void:
	_ad_time.text = "%.0f" % ceilf(maxf(seconds, 0.0))

func hide_ad() -> void:
	_ad_on = false
	_ad_root.visible = false

func ad_visible() -> bool:
	return _ad_on

func set_menu_button(id: String, text: String, enabled: bool = true) -> void:
	var b: Button = _menu_buttons[id]
	b.text = text
	b.disabled = not enabled

## The logbook: a grid of stamp slots (one per airport; blank until first landed at), built once.
func _build_logbook() -> void:
	_log_root = Control.new()
	_log_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_log_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_log_root.visible = false
	add_child(_log_root)
	var n := Airports.count()
	var rows := int(ceil(float(n) / float(STAMP_COLS)))
	for i in n:
		var pn := Panel.new()
		pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.1, 0.12, 0.18, 0.7)
		st.set_border_width_all(3)
		st.border_color = Color(0.4, 0.45, 0.55, 0.6)
		st.set_corner_radius_all(10)
		pn.add_theme_stylebox_override("panel", st)
		_log_root.add_child(pn)
		var col := i % STAMP_COLS
		var row := i / STAMP_COLS
		_place(pn, 0, 0.0, 30 + col * 342, 760 + row * 78, 330, 68)
		var lb := _label(24, HORIZONTAL_ALIGNMENT_CENTER)
		remove_child(lb)
		pn.add_child(lb)
		lb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_log_stamps.append(pn)
		_log_stamp_names.append(lb)
	_log_back = Button.new()
	_log_back.text = "BACK"
	_log_back.add_theme_font_size_override("font_size", 48)
	_log_back.pressed.connect(func(): menu_action.emit("back"))
	_log_root.add_child(_log_back)
	_place(_log_back, 0.5, 0.0, -170, 760 + rows * 78 + 20, 340, 110)

func _sel_button(text: String, dir: int) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 64)
	b.pressed.connect(func(): plane_step.emit(dir))
	_sel_row.add_child(b)
	return b

## Show the chosen aircraft's name and a line about how it flies.
func set_plane_choice(id: int) -> void:
	var pr: Dictionary = Planes.profile(id)
	_sel_name.text = pr["name"]
	var bars := func(v: float, lo: float, hi: float) -> String:
		var n := clampi(int(roundf((v - lo) / (hi - lo) * 4.0)) + 1, 1, 5)
		return "#".repeat(n) + "-".repeat(5 - n)
	var extra := ""
	if float(pr["power"]) == 0.0:
		extra += "  NO ENGINE"
	if int(pr["attempts"]) == 1:
		extra += "  ONE ATTEMPT"
	if float(pr["min_len"]) > 0.0:
		extra += "  LONG RUNWAYS"
	_sel_info.text = "%s\nSpeed %s   Float %s   Braking %s%s" % [pr["blurb"], bars.call(float(pr["speed"]), 0.7, 1.6), bars.call(float(pr["ge"]) / maxf(float(pr["sink"]), 0.3), 1.0, 4.0), bars.call(float(pr["decel"]), 0.7, 1.4), extra]

## Is this screen position on the aircraft selector (so a tap there doesn't start the run)?
func over_selector(pos: Vector2) -> bool:
	var vs := get_viewport().get_visible_rect().size
	if _log_on or _hangar_on or _ad_on:
		return true
	if not _sel_row.visible:
		return false
	return Rect2(0.0, vs.y * 0.52 - 10.0, vs.x, 280.0).has_point(pos) or Rect2(0.0, vs.y * 0.78 - 10.0, vs.x, 440.0).has_point(pos)

## Where the airspeed bar draws its stall mark (the aircraft's stall speed).
func set_stall(v: float) -> void:
	stall_marker = v

func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", maxi(size / 8, 4))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

## Anchor at (ax, ay) (fractions of the screen) then offset by (x, y) with size (w, h) in pixels.
func _place(c: Control, ax: float, ay: float, x: float, y: float, w: float, h: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = x
	c.offset_right = x + w
	c.offset_top = y
	c.offset_bottom = y + h

# ---------- game readouts ----------

func set_score(v: int) -> void:
	_score.text = str(v)

func set_round(n: int) -> void:
	_round.text = "ROUND %d" % n

func set_round_text(t: String) -> void:
	_round.text = t

func set_strikes(n: int, max_n: int = 3) -> void:
	for i in _strikes.size():
		_strikes[i].visible = i < max_n
		_strikes[i].color = Color(0.95, 0.25, 0.22, 0.95) if i < n else Color(0.25, 0.28, 0.34, 0.8)

func set_runway(text: String) -> void:
	_runway.text = text

## `head` > 0 headwind, < 0 tailwind.
func set_wind(head: float) -> void:
	var a := absf(head)
	if a < 0.5:
		_wind.text = "WIND  calm"
	elif head > 0.0:
		_wind.text = "WIND  %.0f  headwind  <<" % a
	else:
		_wind.text = "WIND  %.0f  tailwind  >>" % a

const STREAK_COLORS: Array[Color] = [
	Color(1, 1, 1), Color(1.0, 0.92, 0.3), Color(1.0, 0.72, 0.2), Color(1.0, 0.5, 0.15), Color(1.0, 0.3, 0.2), Color(1.0, 0.25, 0.55), Color(0.85, 0.35, 1.0)]

## The Greaser streak: `n` consecutive greasers (the multiplier is the streak, at least 1). `pop` = it just went up: the
## label punches. The label grows, heats up and pulses with the streak, and a glow builds around the screen edges.
func set_streak(n: int, pop: bool = false) -> void:
	_streak_n = n
	if pop:
		_streak_pop = 1.0
	_streak_lost_t = 0.0
	_streak_label.visible = n > 0
	if n > 0:
		_streak_label.text = "STREAK x%d" % mini(n, Tuning.streak_cap)

func streak_tier() -> int:
	return clampi(_streak_n - 1, 0, 6)

## The streak just broke (`old` was its length): a grey "STREAK LOST" for a moment.
func streak_lost(old: int) -> void:
	_streak_n = 0
	if old >= 2:
		_streak_label.visible = true
		_streak_label.text = "STREAK LOST  x%d" % mini(old, Tuning.streak_cap)
		_streak_lost_t = 1.4
	else:
		_streak_label.visible = false

func glow_level() -> float:
	return _glow_level

func _update_streak(dt: float) -> void:
	var tier := streak_tier()
	var target := float(tier) / 6.0 * Tuning.streak_glow_max if _streak_n > 0 else 0.0
	if _streak_n >= 2:
		target = maxf(target, 0.08 * Tuning.streak_glow_max)
	_glow_level = move_toward(_glow_level, target, dt * 0.8)
	_glow.visible = _glow_level > 0.005
	if _glow.visible:
		var pulse := 0.8 + 0.2 * sin(_t * (3.0 + float(tier)))
		_glow_mat.set_shader_parameter("intensity", _glow_level * pulse)
		_glow_mat.set_shader_parameter("glow_color", STREAK_COLORS[tier])
	if _streak_lost_t > 0.0:
		_streak_lost_t -= dt
		_streak_label.modulate = Color(0.7, 0.72, 0.78, clampf(_streak_lost_t * 2.0, 0.0, 1.0))
		_streak_label.scale = Vector2.ONE
		if _streak_lost_t <= 0.0:
			_streak_label.visible = false
		return
	if not _streak_label.visible:
		return
	_streak_pop = maxf(_streak_pop - dt * 3.0, 0.0)
	var size := 44 + 7 * tier
	_streak_label.add_theme_font_size_override("font_size", size)
	var col: Color = STREAK_COLORS[tier]
	if tier >= 6:   # top of the ramp: the colour cycles
		col = Color.from_hsv(fposmod(_t * 0.6, 1.0), 0.65, 1.0)
	_streak_label.modulate = col
	_streak_label.pivot_offset = Vector2(0.0, float(size) * 0.5)
	var pulse2 := 1.0 + (0.03 + 0.012 * float(tier)) * sin(_t * (5.0 + 1.5 * float(tier))) + 0.35 * _streak_pop
	_streak_label.scale = Vector2(pulse2, pulse2)
	_streak_label.rotation = deg_to_rad(sin(_t * 31.0) * float(maxi(tier - 3, 0)) * 0.6)

## A short warning under the wind readout ("GUST!", "WIND SHEAR!", "TRAPPED!").
func flash_warning(text: String, color: Color = Color(1, 0.9, 0.4)) -> void:
	_gust.text = text
	_gust.modulate = Color(color.r, color.g, color.b, 1.0)

## The scenario + weather line under the strikes.
func set_scenario_text(text: String) -> void:
	_scn_label.text = text

## The scenario title card: big name, weather line, one-line briefing. It fades in; hide_card() removes it.
func show_card(title: String, sub: String, blurb: String, color: Color) -> void:
	_card_title.text = title
	_card_title.add_theme_color_override("font_color", color)
	_card_sub.text = sub
	_card_blurb.text = blurb
	_card_t = 0.0
	_card_on = true
	_card_root.visible = true
	_card_root.modulate.a = 0.0

func hide_card() -> void:
	_card_on = false
	_card_root.visible = false

func card_visible() -> bool:
	return _card_root.visible

## Per-frame flight readout: altitude, sink rate (colour = how the touchdown would grade), airspeed fraction.
func set_flight(alt: float, vy: float, s: float, show: bool) -> void:
	_alt.visible = show
	_sink.visible = show
	_speed_bar.visible = show
	_speed_back.visible = show
	_stall_mark.visible = show
	_speed_label.visible = show
	if not show:
		return
	_alt.text = "ALT %d" % int(roundf(alt))
	var sink := -vy
	_sink.text = "SINK %.1f" % maxf(sink, 0.0) if sink >= 0.0 else "CLIMB %.1f" % -sink
	_sink.modulate = Grading.COLORS[Grading.grade_for_sink(maxf(sink, 0.0))]
	var frac := clampf(s / 1.3, 0.0, 1.0)
	_speed_bar.offset_right = _speed_bar.offset_left + 272.0 * frac
	_speed_bar.color = Color(1, 0.35, 0.3) if s < stall_marker + 0.04 else Color(0.5, 0.95, 0.6)
	_stall_mark.offset_left = -300.0 + 280.0 * clampf(stall_marker / 1.3, 0.0, 1.0)
	_stall_mark.offset_right = _stall_mark.offset_left + 4.0

## Runway distance readout under the runway info ("" hides it).
func set_distance(text: String) -> void:
	_dist.text = text

func set_hint(text: String) -> void:
	_hint.text = text

# ---------- popup ----------

## Big title (grade / CRASH) with a smaller line under it; scales in, holds, fades.
func popup(title: String, sub: String, color: Color, seconds: float) -> void:
	if DebugFlags.off("popup"):
		return
	_pop_title.text = title
	_pop_sub.text = sub
	_pop_color = color
	_pop_t = 0.0
	_pop_len = seconds

## (tests) the grade popup's big text.
func _popup_text_for_test() -> String:
	return _pop_title.text + " " + _pop_sub.text

func clear_popup() -> void:
	_pop_t = 99.0
	_pop_title.modulate.a = 0.0
	_pop_sub.modulate.a = 0.0

# ---------- overlay / fade ----------

func show_menu(best: int, career_text: String = "") -> void:
	_set_overlay(true)
	_ov_title.text = "GREASER"
	_ov_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_ov_body.text = career_text + "Drag up / down to pitch the nose. Flare just before touchdown.\nTouch down on the aim markers. Three crashes end the run. No go-arounds." + (("\n\nBest: %d" % best) if best > 0 else "")
	_ov_prompt.text = "TAP TO FLY"

## A result screen (checkride passed / failed, rank-up): title, body and prompt.
func show_notice(title: String, body: String, prompt: String, color: Color) -> void:
	_set_overlay(true)
	_ov_title.text = title
	_ov_title.add_theme_font_size_override("font_size", 90)
	_ov_title.add_theme_color_override("font_color", color)
	_ov_body.text = body
	_ov_prompt.text = prompt

## The logbook screen. `stamped` maps airport id -> {"name", "day", "n"}.
func show_logbook(body: String, stamped: Dictionary) -> void:
	_log_on = true
	hide_hangar()
	_set_overlay(true)
	_ov_title.text = "LOGBOOK"
	_ov_title.add_theme_color_override("font_color", Color(0.95, 0.9, 0.7))
	_ov_title.add_theme_font_size_override("font_size", 110)
	_ov_body.text = body
	_ov_prompt.text = ""
	var list := Airports.all()
	for i in list.size():
		var a: Dictionary = list[i]
		var st: StyleBoxFlat = _log_stamps[i].get_theme_stylebox("panel")
		if stamped.has(a["id"]):
			_log_stamp_names[i].text = "%s  x%d" % [a["name"], int(stamped[a["id"]]["n"])]
			_log_stamp_names[i].modulate = Color(1, 0.95, 0.75)
			st.border_color = Color(0.95, 0.75, 0.25, 0.95)
			st.bg_color = Color(0.3, 0.2, 0.08, 0.75)
		else:
			_log_stamp_names[i].text = "- - -"
			_log_stamp_names[i].modulate = Color(1, 1, 1, 0.35)
			st.border_color = Color(0.4, 0.45, 0.55, 0.6)
			st.bg_color = Color(0.1, 0.12, 0.18, 0.7)
	_log_root.visible = true
	_menu_row.visible = false
	_sel_row.visible = false

func hide_logbook() -> void:
	_log_on = false
	_log_root.visible = false
	_ov_title.add_theme_font_size_override("font_size", 150)

func logbook_visible() -> bool:
	return _log_on

func show_over(total: int, best: int, landings: int, new_best: bool, best_streak: int = 0) -> void:
	_set_overlay(true)
	_ov_title.text = "RUN OVER"
	_ov_title.add_theme_font_size_override("font_size", 150)
	_ov_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	_ov_body.text = "Score  %d\nLandings  %d\nBest streak  x%d\n%s" % [total, landings, maxi(best_streak, 1) if best_streak > 0 else 0, "NEW BEST!" if new_best else "Best  %d" % best]
	_ov_prompt.text = "TAP TO FLY AGAIN"
	_menu_row.visible = true

func hide_overlay() -> void:
	_set_overlay(false)

func _set_overlay(on: bool) -> void:
	overlay_visible = on
	if not on:
		hide_logbook()
		hide_hangar()
	_sel_row.visible = on and not _splash.visible
	_menu_row.visible = on and not _splash.visible and not _log_on and not _hangar_on
	_overlay.visible = on
	_ov_title.visible = on
	_ov_body.visible = on
	_ov_prompt.visible = on

## Fade to black (1) or back to clear (0).
func fade_to(v: float) -> void:
	_fade_target = v

func set_fade_now(v: float) -> void:
	_fade_target = v
	_fade.color.a = v

func fade_alpha() -> float:
	return _fade.color.a

# ---------- the big PAPI ----------

const PAPI_WHITE := Color(0.98, 0.98, 0.94)
const PAPI_RED := Color(1.0, 0.13, 0.1)
const PAPI_CAPTIONS: Array[String] = ["TOO LOW", "A LITTLE LOW", "ON PATH", "A LITTLE HIGH", "TOO HIGH"]

## Feed the PAPI: `white` = how many of the four lights are white (4 = too high, 2 = on path, 0 = too low), `screen_x` =
## where the plane is on screen (the row follows it sideways), `show` = visible (during the approach). `snap` jumps
## there at once (a new round).
func set_papi(white: int, screen_x: float, show: bool, snap: bool = false) -> void:
	_papi_target = clampi(white, 0, 4)
	_papi_x_target = screen_x
	_papi_show = show
	if snap:
		_papi_x = screen_x
		_papi_alpha = 1.0 if show else 0.0
		for i in 4:
			_papi_cols[i] = PAPI_WHITE if i < _papi_target else PAPI_RED
			_papi_pop[i] = 0.0
		_papi_shown_n = -1
		_papi_row.visible = show
		_layout_papi(0.0)

## The colour light `i` is showing right now (it eases toward its target, so mid-change it is a blend).
func papi_light_color(i: int) -> Color:
	return _papi_cols[i]

## The row's screen rectangle (tests and layout checks).
func papi_rect() -> Rect2:
	return Rect2(_papi_row.position, _papi_row.size)

func papi_visible() -> bool:
	return _papi_row.visible and _papi_alpha > 0.5

func _layout_papi(dt: float) -> void:
	var sz := Tuning.papi_hud_size
	var gap := Tuning.papi_hud_gap
	var w := 4.0 * sz + 3.0 * gap
	var pad := 18.0
	var vs := get_viewport().get_visible_rect().size
	# follow the plane sideways, always fully on screen
	var k := 1.0 - exp(-Tuning.papi_hud_follow * dt) if dt > 0.0 else 1.0
	_papi_x = lerpf(_papi_x, _papi_x_target, k)
	var half := w * 0.5 + pad + Tuning.papi_hud_margin
	var cx := clampf(_papi_x, minf(half, vs.x * 0.5), maxf(vs.x - half, vs.x * 0.5))
	_papi_row.position = Vector2(cx - w * 0.5, vs.y * Tuning.papi_hud_y)
	_papi_row.size = Vector2(w, sz)
	_papi_back.position = Vector2(-pad, -pad)
	_papi_back.size = Vector2(w + 2.0 * pad, sz + 2.0 * pad + 44.0)
	if sz != _papi_built_size:                 # (live-tuned size: reshape the round lights)
		_papi_built_size = sz
		for st in _papi_styles:
			st.set_corner_radius_all(int(sz * 0.5))
			st.set_border_width_all(maxi(int(sz * 0.07), 3))
	for i in 4:
		var light := _papi_lights[i]
		light.size = Vector2(sz, sz)
		light.position = Vector2(float(i) * (sz + gap), 0.0)
		light.pivot_offset = Vector2(sz, sz) * 0.5
		var pop := 1.0 + 0.16 * _papi_pop[i]
		light.scale = Vector2(pop, pop)
		_papi_styles[i].bg_color = _papi_cols[i]
	_papi_caption.position = Vector2(0.0, sz + 8.0)
	_papi_caption.size = Vector2(w, 40.0)

func _update_papi(dt: float) -> void:
	_papi_alpha = move_toward(_papi_alpha, 1.0 if _papi_show else 0.0, dt / 0.2)
	_papi_row.visible = _papi_alpha > 0.01
	if not _papi_row.visible:
		return
	_papi_row.modulate.a = _papi_alpha
	# colours ease toward white / red: a change is easy to see (and pops a little) but never flickers
	var ck := 1.0 - exp(-Tuning.papi_hud_fade * dt)
	for i in 4:
		var goal := PAPI_WHITE if i < _papi_target else PAPI_RED
		_papi_cols[i] = _papi_cols[i].lerp(goal, ck)
		_papi_pop[i] = maxf(_papi_pop[i] - dt * 4.0, 0.0)
	if _papi_target != _papi_shown_n:
		if _papi_shown_n >= 0:
			var lo := mini(_papi_target, _papi_shown_n)
			var hi := maxi(_papi_target, _papi_shown_n)
			for i in range(lo, hi):
				_papi_pop[i] = 1.0
		_papi_shown_n = _papi_target
		_papi_caption.text = PAPI_CAPTIONS[_papi_target]
		_papi_caption.modulate = PAPI_RED.lerp(PAPI_WHITE, 0.55) if _papi_target != 2 else Color(0.6, 1.0, 0.65)
	_layout_papi(dt)

# ---------- per frame ----------

func update(delta: float) -> void:
	_t += delta
	if _card_on:
		_card_t += delta
		_card_root.modulate.a = clampf(_card_t / 0.18, 0.0, 1.0)
	if _pop_t < _pop_len + 0.1:
		_pop_t += delta
		var k := _pop_t / maxf(_pop_len, 0.01)
		var pop := 1.0 + 0.45 * maxf(1.0 - _pop_t * 6.0, 0.0)
		var a := clampf((1.0 - k) * 4.0, 0.0, 1.0)
		_pop_title.pivot_offset = _pop_title.size * 0.5
		_pop_title.scale = Vector2(pop, pop)
		_pop_title.modulate = Color(_pop_color.r, _pop_color.g, _pop_color.b, a)
		_pop_sub.modulate = Color(1, 1, 1, a)
	elif _pop_title.modulate.a > 0.0:
		_pop_title.modulate.a = 0.0
		_pop_sub.modulate.a = 0.0
	if _gust.modulate.a > 0.0:
		_gust.modulate.a = maxf(_gust.modulate.a - delta * 1.6, 0.0)
	_fade.color.a = move_toward(_fade.color.a, _fade_target, delta / maxf(Tuning.fade_time, 0.01))
	if overlay_visible:
		_ov_prompt.modulate.a = 0.55 + 0.45 * sin(_t * 4.0)
	_update_papi(delta)
	_update_streak(delta)
	_update_perf(delta)

# ---------- ?perf ----------

func note_hitch(raw: float, used: float, why: String, context: String) -> void:
	_hitch_count += 1
	var line := "#%d %.0f ms (simulated %.0f ms) %s | %s" % [_hitch_count, raw * 1000.0, used * 1000.0, why, context]
	_hitch_log.append(line)
	if _hitch_log.size() > 5:
		_hitch_log.pop_front()
	print("[hitch] " + line)

func set_clock(sim: float, wall: float) -> void:
	_clock_text = "sim %.1f s / wall %.1f s" % [sim, wall]

func _update_perf(delta: float) -> void:
	if _perf == null:
		return
	var ms := delta * 1000.0
	_perf_worst = maxf(_perf_worst, ms)
	var now := Time.get_ticks_msec()
	if now - _perf_window_start > 3000:
		_perf_shown = _perf_worst
		_perf_worst = 0.0
		_perf_window_start = now
	_perf.text = "worst frame (3s): %.0f ms   %.0f fps\ndraw calls %d   %s\nhitches (over 50 ms):\n%s" % [
		_perf_shown, Engine.get_frames_per_second(),
		int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), _clock_text, "\n".join(_hitch_log)]

# ---------- start-up pre-warm ----------

## Splash over the game while everything is drawn once (see Main._prewarm); popups and overlay text are drawn too
## (behind the splash) so their font glyphs are built.
func begin_prewarm() -> void:
	_splash.visible = true
	_set_overlay(true)
	_sel_row.visible = true     # (the selector's buttons are drawn behind the splash too)
	_menu_row.visible = true
	show_logbook("0123456789 Greaser", {})     # (and the logbook's stamps, the hangar, an ad)
	_log_root.visible = true
	_hangar_root.visible = true
	_ad_root.visible = true
	_menu_row.visible = true
	_ov_title.text = "GREASER"
	_ov_body.text = "0123456789 Greaser! Smooth Good Firm Hard CRASH Off the runway! Hit the trees!"
	_ov_prompt.text = "TAP"
	if not DebugFlags.off("popup"):
		_pop_title.text = "Greaser!"
		_pop_sub.text = "Sink 0.5   Aim +2   No bounce   +96"
		_pop_title.modulate.a = 1.0
		_pop_sub.modulate.a = 1.0
	_gust.modulate.a = 1.0
	set_papi(2, 540.0, true, true)   # the big PAPI is drawn for real too
	set_streak(7, true)               # ... and a high streak (label, glow)

func prewarm_popups() -> void:
	for g in Grading.NAMES:
		_pop_title.text = g
	_pop_title.text = "Greaser!"

func end_prewarm() -> void:
	set_papi(2, 540.0, false, true)
	set_streak(0)
	_glow_level = 0.0
	_glow.visible = false
	_splash.visible = false
	hide_logbook()
	hide_hangar()
	hide_ad()
	_set_overlay(false)
	clear_popup()
	_gust.modulate.a = 0.0
