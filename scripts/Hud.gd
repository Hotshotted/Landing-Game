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
var _speed_bar: UiBar
var _speed_back: UiBar
var _stall_mark: UiBar
var _speed_band: UiBar          # the Vref tolerance band on the airspeed bar
var _band_lo := 0.9
var _band_hi := 1.15
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
var _menu_buttons := {}                 # id -> UiButton
var _log_root: Control
var _log_stamps: Array[Panel] = []
var _log_stamp_names: Array[Label] = []
var _log_back: UiButton
var _log_slips: Array[Panel] = []
var _log_slip_labels: Array[Label] = []
var _log_more: Label
const MAX_SLIPS := 4
var _log_on := false
const STAMP_COLS := 3
const MAX_TYPE_ROWS := 10
const MAX_PIPS := 5
var _career_root: Control
var _cr_rows: Array[Dictionary] = []     # {name: Label, pips: Array[ColorRect], btn: UiButton}
var _cr_speech: Label
var _cr_speech_panel: Panel
var _cr_status: Label
var _cr_book: UiButton
var _cr_stamp: Label                     # the endorsement stamp on the speech panel
var _cr_on := false
var _instr_nodes: Array[Control] = []    # the instructor portrait (on the career screen)
var _cert_root: Control
var _cert_title: Label
var _cert_rank: Label
var _cert_body: Label
var _cert_date: Label
var _cert_sign: Label
var _cert_on := false
signal hangar_pick(kind: String, idx: int)
signal choice(kind: String)             # "cashout" or "keep" (the choice screen after a landing)
signal pause_action(id: String)         # "pause", "resume", "settings", "settings_back", "quit", "quit_yes", "quit_no"
signal volume_changed(kind: String, value: float)
var _hangar_planes: Array[UiButton] = []
var _hangar_buy: Array[UiButton] = []
var _pot: Label
var _choice_root: Control
var _ch_title: Label
var _ch_icon: UiIcon
var _ch_chip: Panel
var _ch_pot: Label
var _ch_next: Label
var _ch_hint: Label
var _ch_cash: UiButton
var _ch_keep: UiButton
var _ch_count: Label
var _choice_on := false
var _pause_btn: UiButton
var _pause_root: Control
var _pz_title: Label
var _pz_main: Control
var _pz_settings: Control
var _pz_confirm: Control
var _pz_confirm_text: Label
var _pz_sliders := {}
var _pause_on := false
var _hangar_root: Control
var _hangar_paint: Array[UiButton] = []
var _hangar_gear: Array[UiButton] = []
var _hangar_on := false
var _ad_root: ColorRect
var _ad_title: Label
var _ad_sub: Label
var _ad_time: Label
var _ad_on := false
var _sel_row: Control
var _sel_name: Label
var _sel_info: Label
var _strip: ApproachStrip
var _rwy_ind: Panel
var _rwy_ind_label: Label
var _rwy_ind_icon: UiIcon
var _sel_rent: Label
var over_extra := ""                    # extra lines for the run-over screen (rental and damage fees)
var _sel_icon: UiIcon
var _sel_prev: UiButton
var _sel_next: UiButton
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
var _pop_panel: Panel
var _pop_stars: Array[UiIcon] = []
var _pop_grade := -1
var _streak_flame: UiIcon
var _pop_color := Color.WHITE
var _overlay: ColorRect
var _ov_title: Label
var _ov_body: Label
var _ov_prompt: Label
var _fade: ColorRect
var _fade_target := 0.0
var _splash: ColorRect
signal ui_sound(kind: String)
enum { A_SLIDE_R, A_SLIDE_L, A_POP, A_RISE, A_STAMP, A_FILL, A_SIGN, A_FLIP }
const AN_MAX := 128
var _instant := DisplayServer.get_name() == "headless"     # (the smoke tests see end states: no animation in the headless run)
var _an_node: Array = []
var _an_kind := PackedInt32Array()
var _an_t := PackedFloat32Array()
var _an_delay := PackedFloat32Array()
var _an_dur := PackedFloat32Array()
var _an_aux := PackedColorArray()
var _an_hit := PackedByteArray()
var _an_n := 0
var _burst: UiBurst
var _live: MenuScene
var _shake := 0.0
var _back_flag := false
var _bank_icon: UiIcon
var _cr_sig: Label
var _cert_seal: Control
var _slip_seal: Control
var _lost_seal: Control
var _lost_label: Label
var _log_seen := {}
var _pot_shown := 0.0
var _pot_tgt := 0.0
var _pot_mult := 1.0
var _score_shown := 0.0
var _score_tgt := 0.0
var _chpot_shown := 0.0
var _chpot_tgt := 0.0
var _logo_root: ColorRect
var _logo_t := -1.0
const LOGO_SECONDS := 1.8
signal logo_finished
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
	process_mode = Node.PROCESS_MODE_ALWAYS     # (the pause menu works while the game is paused)
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
	_pot = _label(40, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_pot, 0, 0, 24, 148, 520, 48)
	_pot.modulate = Color(1.0, 0.85, 0.3)
	_pot.visible = false
	_streak_label = _label(46, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_streak_label, 0, 0, 96, 236, 520, 70)
	_streak_flame = UiIcon.new()
	_streak_flame.glyph = "flame"
	add_child(_streak_flame)
	_place(_streak_flame, 0, 0, 20, 232, 70, 70)
	_streak_flame.pivot_offset = Vector2(35, 35)
	_streak_flame.visible = false
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
	_speed_back = UiBar.new()
	_speed_back.color = Color(Style.SURFACE_DARK, 0.62)
	_speed_back.radius = 11
	_speed_back.border = Color(Style.LINE, 0.55)
	_speed_back.border_w = 2
	_place(_speed_back, 1, 0, -300, 232, 280, 22)
	add_child(_speed_back)
	_speed_band = UiBar.new()
	_speed_band.color = Color(Style.PRIMARY, 0.55)
	_speed_band.radius = 8
	_place(_speed_band, 1, 0, -300, 228, 40, 30)
	add_child(_speed_band)
	_speed_bar = UiBar.new()
	_speed_bar.radius = 7
	_place(_speed_bar, 1, 0, -296, 236, 100, 14)
	add_child(_speed_bar)
	_stall_mark = UiBar.new()
	_stall_mark.color = Style.DANGER
	_stall_mark.radius = 2
	_stall_mark.border = Style.INK
	_stall_mark.border_w = 1
	_place(_stall_mark, 1, 0, -300, 226, 5, 34)
	add_child(_stall_mark)
	_speed_label = _label(24, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_speed_label, 1, 0, -300, 258, 280, 32)
	_speed_label.text = "AIRSPEED"
	_speed_label.add_theme_font_size_override("font_size", 26)
	_hint = _label(40, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_hint, 0.5, 1, -440, -380, 880, 200)
	_pop_panel = Panel.new()
	_pop_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pop_panel)
	_place(_pop_panel, 0, 0.3, 90, -50, 900, 400)
	_pop_panel.pivot_offset = Vector2(450, 200)
	_pop_panel.modulate.a = 0.0
	for i in 3:
		var st := UiIcon.new()
		st.glyph = "star"
		add_child(st)
		_place(st, 0, 0.3, 370.0 + float(i) * 125.0 - 40.0, -150, 110, 110)
		st.pivot_offset = Vector2(55, 55)
		st.modulate.a = 0.0
		_pop_stars.append(st)
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
	back_style.bg_color = Color(Style.SURFACE_DARK, 0.72)
	back_style.set_corner_radius_all(Style.R_L + 8)
	back_style.set_border_width_all(3)
	back_style.border_color = Color(Style.LINE, 0.6)
	back_style.shadow_color = Style.SHADOW_COLOR
	back_style.shadow_size = Style.SHADOW_SIZE
	back_style.shadow_offset = Style.SHADOW_OFFSET
	_papi_back.add_theme_stylebox_override("panel", back_style)
	_papi_row.add_child(_papi_back)
	for i in 4:
		var light := Panel.new()
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 1, 1)
		st.border_color = Style.INK
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
	card_back.color = Color(Style.SCRIM, 0.7)
	card_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_back.anchor_right = 1.0
	card_back.anchor_top = 0.27
	card_back.anchor_bottom = 0.27
	card_back.offset_bottom = 780
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
	_place(_card_blurb, 0.5, 0.27, -460, 262, 920, 500)
	# the aircraft selector (shown on the menu and game-over screens)
	_sel_row = Control.new()
	_sel_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sel_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sel_row.visible = false
	add_child(_sel_row)
	var sel_card := Panel.new()
	sel_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_card.add_theme_stylebox_override("panel", Style.box(Color(Style.SURFACE_DARK, 0.88), Style.LINE, Style.R_L, 3))
	_sel_row.add_child(sel_card)
	_place(sel_card, 0, 0.52, 16, -10, 1048, 346)
	_sel_icon = UiIcon.new()
	_sel_icon.glyph = "cub"
	_sel_row.add_child(_sel_icon)
	_place(_sel_icon, 0.5, 0.52, -50, -66, 100, 100)
	_sel_name = _label(78, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_sel_name)
	_sel_row.add_child(_sel_name)
	_place(_sel_name, 0, 0.52, 160, 34, 760, 100)
	_sel_rent = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_sel_rent)
	_sel_row.add_child(_sel_rent)
	_place(_sel_rent, 0, 0.52, 60, 284, 960, 48)
	_sel_info = _label(32, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_sel_info)
	_sel_row.add_child(_sel_info)
	_sel_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_sel_info, 0, 0.52, 120, 134, 840, 140)
	_sel_prev = _sel_button("<", -1)
	_place(_sel_prev, 0, 0.52, 24, 34, 120, 100)
	_sel_next = _sel_button(">", 1)
	_place(_sel_next, 0, 0.52, 936, 34, 120, 100)
	_build_menu_buttons()
	_build_logbook()
	_build_hangar()
	_build_choice()
	_build_pause()
	_build_career()
	_build_certificate()
	_build_ad()
	# menu / game-over overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(Style.SCRIM, 0.66)
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
	_stamp = _label(18, HORIZONTAL_ALIGNMENT_LEFT)
	var flags := DebugFlags.summary()
	_stamp.text = "%s  %s" % [BuildInfo.COMMIT, BuildInfo.TIME] + (("\n" + flags) if flags != "" else "")
	_place(_stamp, 0, 1, 10, -64 if flags != "" else -34, 700, 56)
	_stamp.modulate = Color(1, 1, 1, 0.4)
	_stamp.visible = DebugFlags.stamp_enabled()      # (players never see it: only ?debug, ?tune or ?perf)
	if DebugFlags.perf_enabled():
		_perf = _label(26, HORIZONTAL_ALIGNMENT_LEFT)
		_place(_perf, 0, 0, 14, 210, 700, 300)
		_perf.modulate = Color(0.6, 1, 0.6, 0.9)
	# start-up splash (above everything but the stamp)
	_splash = ColorRect.new()
	_splash.color = Style.SURFACE_DARK
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash.visible = false
	add_child(_splash)
	move_child(_sel_row, _splash.get_index())     # (the aircraft selector sits above the dark overlay, below the splash)
	move_child(_menu_row, _splash.get_index())
	move_child(_log_root, _splash.get_index())
	move_child(_hangar_root, _splash.get_index())
	move_child(_career_root, _splash.get_index())
	move_child(_choice_root, _splash.get_index())
	move_child(_pause_btn, _splash.get_index())
	move_child(_pause_root, _splash.get_index())
	move_child(_cert_root, _splash.get_index())
	move_child(_ad_root, _splash.get_index())
	move_child(_stamp, get_child_count() - 1)
	_build_fx()
	_build_logo()
	set_process(true)

## The buttons under the aircraft selector (menu and run-over screens). Built once; only shown / hidden / re-texted.
func _build_menu_buttons() -> void:
	_menu_row = Control.new()
	_menu_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_row.visible = false
	add_child(_menu_row)
	var ids := ["fly", "career", "logbook"]
	var texts := ["FLY", "CAREER", "LOGBOOK"]
	var icons := ["play", "career", "book"]
	for i in ids.size():
		var b := UiButton.new()
		b.text = texts[i]
		b.font_px = 40
		b.icon = icons[i]
		b.kind = "primary" if i == 0 else "secondary"
		var id: String = ids[i]
		b.pressed.connect(func(): menu_action.emit(id))
		_menu_row.add_child(b)
		_place(b, 0, 0.78, 30 + i * 342, 0, 330, 120)
		_menu_buttons[id] = b
	var ids2 := ["daily", "hangar"]
	var texts2 := ["DAILY", "HANGAR"]
	var icons2 := ["daily", "hangar"]
	for i in ids2.size():
		var b2 := UiButton.new()
		b2.text = texts2[i]
		b2.font_px = 40
		b2.icon = icons2[i]
		var id2: String = ids2[i]
		b2.pressed.connect(func(): menu_action.emit(id2))
		_menu_row.add_child(b2)
		_place(b2, 0, 0.78, 30 + i * 342, 140, 330, 120)
		_menu_buttons[id2] = b2
	# the rewarded-ad button (a stub; shown only where an ad can be offered)
	var ad := UiButton.new()
	ad.text = "WATCH AD"
	ad.font_px = 36
	ad.icon = "ad"
	ad.kind = "gold"
	ad.pressed.connect(func(): menu_action.emit("ad"))
	_menu_row.add_child(ad)
	_place(ad, 0, 0.78, 372, 140, 678, 120)
	ad.visible = false
	_menu_buttons["ad"] = ad

func set_ad_button(text: String, shown: bool) -> void:
	var b: UiButton = _menu_buttons["ad"]
	b.text = text
	b.visible = shown

## A flat coloured rounded box (portraits, certificate, meters).
func _box(parent: Control, x: float, y: float, w: float, h: float, color: Color, radius: int = 0, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(radius)
	if border_w > 0:
		st.set_border_width_all(border_w)
		st.border_color = border
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	_place(p, 0, 0, x, y, w, h)
	return p

## The instructor, Captain Wiggins: a simple flat portrait (a uniform, a face, a cap and a moustache).
func _build_instructor(parent: Control, x: float, y: float, size: float) -> Array[Control]:
	var k := size / 200.0
	var out: Array[Control] = []
	out.append(_box(parent, x + 25 * k, y + 120 * k, 150 * k, 80 * k, Color(0.16, 0.24, 0.45), int(30 * k)))     # uniform
	out.append(_box(parent, x + 85 * k, y + 120 * k, 30 * k, 60 * k, Color(0.95, 0.95, 0.95), int(6 * k)))      # shirt
	out.append(_box(parent, x + 97 * k, y + 125 * k, 6 * k, 55 * k, Color(0.8, 0.2, 0.2)))                       # tie
	out.append(_box(parent, x + 55 * k, y + 40 * k, 90 * k, 90 * k, Color(0.95, 0.78, 0.62), int(40 * k)))      # face
	out.append(_box(parent, x + 48 * k, y + 14 * k, 104 * k, 40 * k, Color(0.12, 0.18, 0.36), int(14 * k)))     # cap
	out.append(_box(parent, x + 40 * k, y + 46 * k, 120 * k, 12 * k, Color(0.08, 0.12, 0.26), int(6 * k)))      # brim
	out.append(_box(parent, x + 90 * k, y + 22 * k, 20 * k, 16 * k, Color(0.95, 0.8, 0.25), int(4 * k)))        # badge
	out.append(_box(parent, x + 72 * k, y + 78 * k, 12 * k, 12 * k, Color(0.1, 0.1, 0.12), int(6 * k)))         # eyes
	out.append(_box(parent, x + 116 * k, y + 78 * k, 12 * k, 12 * k, Color(0.1, 0.1, 0.12), int(6 * k)))
	out.append(_box(parent, x + 70 * k, y + 98 * k, 60 * k, 14 * k, Color(0.35, 0.25, 0.2), int(7 * k)))        # moustache
	return out

## The career screen: the instructor with a speech panel (or the endorsement), one row per landing type of the rank being
## trained for (name, proficiency pips, PRACTICE) and the BOOK CHECKRIDE button. Built once.
func _build_career() -> void:
	_career_root = Control.new()
	_career_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_career_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_career_root.visible = false
	add_child(_career_root)
	_instr_nodes = _build_instructor(_career_root, 30.0, 470.0, 230.0)
	_cr_speech_panel = _box(_career_root, 285, 480, 765, 215, Color(0.97, 0.94, 0.85, 0.96), 16, Color(0.5, 0.4, 0.25), 4)
	_cr_speech = _label(34, HORIZONTAL_ALIGNMENT_LEFT)
	remove_child(_cr_speech)
	_cr_speech_panel.add_child(_cr_speech)
	_cr_speech.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cr_speech.offset_left = 20
	_cr_speech.offset_right = -20
	_cr_speech.offset_top = 10
	_cr_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cr_speech.add_theme_color_override("font_color", Color(0.15, 0.12, 0.08))
	_cr_speech.add_theme_color_override("font_outline_color", Color(0.97, 0.94, 0.85, 0.0))
	_cr_stamp = _label(40, HORIZONTAL_ALIGNMENT_RIGHT)
	remove_child(_cr_stamp)
	_cr_speech_panel.add_child(_cr_stamp)
	_cr_stamp.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_cr_stamp.offset_left = -420
	_cr_stamp.offset_top = -58
	_cr_stamp.offset_right = -20
	_cr_stamp.offset_bottom = -8
	_cr_stamp.add_theme_color_override("font_color", Color(0.1, 0.45, 0.2))
	_cr_stamp.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.0))
	_cr_status = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_cr_status)
	_career_root.add_child(_cr_status)
	_place(_cr_status, 0, 0, 30, 706, 1020, 96)
	_cr_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cr_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for i in MAX_TYPE_ROWS:
		var y := 815.0 + float(i) * 86.0
		var row := {}
		var nm := _label(36, HORIZONTAL_ALIGNMENT_LEFT)
		remove_child(nm)
		_career_root.add_child(nm)
		_place(nm, 0, 0, 30, y, 470, 70)
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row["name"] = nm
		var pips: Array[ColorRect] = []
		for k in MAX_PIPS:
			var pip := ColorRect.new()
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_career_root.add_child(pip)
			_place(pip, 0, 0, 440.0 + float(k) * 46.0, y + 15.0, 36, 40)
			pips.append(pip)
		row["pips"] = pips
		var b := UiButton.new()
		b.text = "PRACTICE"
		b.font_px = 32
		b.icon = "play"
		var idx := i
		b.pressed.connect(func(): menu_action.emit("practice:%d" % idx))
		_career_root.add_child(b)
		_place(b, 0, 0, 640, y, 220, 80)
		b.font_px = 24
		row["btn"] = b
		var lb := UiButton.new()
		lb.text = "LESSON"
		lb.font_px = 24
		lb.kind = "gold"
		lb.icon = "cap"
		var lidx := i
		lb.pressed.connect(func(): menu_action.emit("lesson:%d" % lidx))
		_career_root.add_child(lb)
		_place(lb, 0, 0, 870, y, 190, 80)
		row["lesson"] = lb
		_cr_rows.append(row)
	_cr_book = UiButton.new()
	_cr_book.font_px = 34
	_cr_book.kind = "gold"
	_cr_book.icon = "stamp"
	_cr_book.pressed.connect(func(): menu_action.emit("book"))
	_career_root.add_child(_cr_book)
	_place(_cr_book, 0, 0, 30, 1700, 700, 120)
	var back := UiButton.new()
	back.text = "BACK"
	back.font_px = 44
	back.kind = "ghost"
	back.icon = "back"
	back.pressed.connect(func(): menu_action.emit("back"))
	_career_root.add_child(back)
	_place(back, 0, 0, 750, 1700, 300, 120)

## `info`: {title, body, speech, endorsed (bool), status, rows: [{name, count, needed}], practice (bool), book_text, book (bool)}
func show_career(info: Dictionary) -> void:
	_cr_on = true
	hide_logbook()
	hide_hangar()
	_set_overlay(true)
	_ov_title.text = "CAREER"
	_ov_title.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0))
	_ov_title.add_theme_font_size_override("font_size", 110)
	_ov_body.text = str(info["body"])
	_ov_prompt.text = ""
	_cr_speech.text = str(info["speech"])
	_cr_stamp.text = "ENDORSED" if bool(info["endorsed"]) else ""
	var sp: StyleBoxFlat = _cr_speech_panel.get_theme_stylebox("panel")
	sp.border_color = Color(0.2, 0.6, 0.3) if bool(info["endorsed"]) else Color(0.5, 0.4, 0.25)
	_cr_status.text = str(info["status"])
	_cr_status.add_theme_color_override("font_color", Style.WARNING if str(info.get("lock", "")) != "" else Color.WHITE)
	var rows: Array = info["rows"]
	for i in MAX_TYPE_ROWS:
		var row: Dictionary = _cr_rows[i]
		var on := i < rows.size()
		(row["name"] as Label).visible = on
		(row["btn"] as UiButton).visible = on
		(row["lesson"] as UiButton).visible = on
		for pip in row["pips"]:
			(pip as ColorRect).visible = false
		if not on:
			continue
		var r: Dictionary = rows[i]
		(row["name"] as Label).text = str(r["name"])
		(row["btn"] as UiButton).disabled = not bool(info["practice"])
		(row["btn"] as UiButton).kind = "primary" if bool(r.get("missing", false)) else "secondary"
		(row["lesson"] as UiButton).disabled = not bool(r.get("lesson_ok", false))
		(row["lesson"] as UiButton).text = "LESSON %dc" % int(r.get("lesson_fee", 0))
		var needed := mini(int(r["needed"]), MAX_PIPS)
		for k in needed:
			var pip: ColorRect = row["pips"][k]
			pip.visible = true
			pip.color = Color(0.4, 0.95, 0.5) if k < int(r["count"]) else Color(0.2, 0.24, 0.3, 0.9)
	_cr_book.text = str(info["book_text"])
	_cr_book.disabled = not bool(info["book"])
	_menu_row.visible = false
	_sel_row.visible = false
	if _reveal(_career_root, A_SLIDE_R):
		_career_fx(info)
	elif not _instant and bool(info["endorsed"]):
		_cr_sig.visible = true

func _career_fx(info: Dictionary) -> void:
	var rows: Array = info["rows"]
	_cr_sig.visible = bool(info["endorsed"])
	if _instant:
		_cr_sig.visible_ratio = 1.0
		return
	for i in mini(rows.size(), MAX_TYPE_ROWS):
		var r: Dictionary = rows[i]
		var needed := mini(int(r["needed"]), MAX_PIPS)
		for k in mini(int(r["count"]), needed):
			var pip: ColorRect = _cr_rows[i]["pips"][k]
			_anim(pip, A_FILL, 0.35 + float(i) * 0.12 + float(k) * 0.1, 0.4, Color(0.4, 0.95, 0.5))
	if bool(info["endorsed"]):
		_anim(_cr_sig, A_SIGN, 0.9, 1.1)
		_anim(_cr_stamp, A_STAMP, 2.1, 0.55, Color(0, 0, 0, 0))

func hide_career() -> void:
	if _cr_on:
		_back_flag = true
	_cr_on = false
	_career_root.visible = false

func career_visible() -> bool:
	return _cr_on

## The certificate for a new rank.
func _build_certificate() -> void:
	_cert_root = Control.new()
	_cert_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cert_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cert_root.visible = false
	add_child(_cert_root)
	_box(_cert_root, 60, 330, 960, 1060, Color(0.98, 0.95, 0.85), 12, Color(0.78, 0.6, 0.2), 14)
	_box(_cert_root, 90, 360, 900, 1000, Color(0, 0, 0, 0), 6, Color(0.78, 0.6, 0.2), 4)
	_cert_title = _label(54, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_cert_title)
	_cert_root.add_child(_cert_title)
	_place(_cert_title, 0, 0, 100, 400, 880, 80)
	_cert_title.text = "CERTIFICATE OF ACHIEVEMENT"
	_cert_rank = _label(92, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_cert_rank)
	_cert_root.add_child(_cert_rank)
	_place(_cert_rank, 0, 0, 100, 560, 880, 130)
	_cert_body = _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_cert_body)
	_cert_root.add_child(_cert_body)
	_cert_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_cert_body, 0, 0, 130, 730, 820, 380)
	_cert_date = _label(32, HORIZONTAL_ALIGNMENT_LEFT)
	remove_child(_cert_date)
	_cert_root.add_child(_cert_date)
	_place(_cert_date, 0, 0, 130, 1280, 400, 50)
	_cert_sign = _label(36, HORIZONTAL_ALIGNMENT_RIGHT)
	remove_child(_cert_sign)
	_cert_root.add_child(_cert_sign)
	_place(_cert_sign, 0, 0, 520, 1280, 440, 50)
	for l in [_cert_title, _cert_rank, _cert_body, _cert_date, _cert_sign]:
		l.add_theme_color_override("font_color", Color(0.25, 0.18, 0.08))
		l.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.0))
	_cert_rank.add_theme_color_override("font_color", Color(0.7, 0.2, 0.15))
	_build_instructor(_cert_root, 750.0, 1130.0, 150.0)
	_box(_cert_root, 520, 1325, 440, 4, Color(0.25, 0.18, 0.08))

func show_certificate(rank_name: String, body: String, date_text: String) -> void:
	_cert_on = true
	hide_career()
	_set_overlay(true)
	_ov_title.text = ""
	_ov_body.text = ""
	_ov_prompt.text = "TAP TO CONTINUE"
	_cert_rank.text = rank_name
	_cert_body.text = body
	_cert_date.text = date_text
	_cert_sign.text = "Capt. Wiggins, CFI"
	_menu_row.visible = false
	_sel_row.visible = false
	if _reveal(_cert_root, A_RISE):
		_anim(_cert_root, A_SLIDE_R, 0.0, 0.5)
		_cert_seal.modulate.a = 0.0
		_anim(_cert_seal, A_STAMP, 1.0, 0.55, Color(0, 0, 0, 0))

func hide_certificate() -> void:
	_cert_on = false
	_cert_root.visible = false

func certificate_visible() -> bool:
	return _cert_on

## The pot of the free-flight run (coins earned, not banked) and the multiplier the next landing pays.
func set_pot(coins: int, mult: float, show: bool) -> void:
	_pot.visible = show
	_pot_tgt = float(coins)
	_pot_mult = mult
	if _instant or coins < int(_pot_shown) or not show:
		_pot_shown = float(coins)
	_pot.text = "POT %d   x%.1f" % [int(roundf(_pot_shown)), mult]

## The choice after a landing: CASH OUT (bank the pot) or KEEP FLYING (a harder approach). Built once.
func _build_choice() -> void:
	_choice_root = Control.new()
	_choice_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_root.visible = false
	add_child(_choice_root)
	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.06, 0.12, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_choice_root.add_child(dim)
	var card := Panel.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cs := Style.box(Color(Style.SURFACE_DARK, 0.9), Style.LINE, Style.R_L, 4)
	card.add_theme_stylebox_override("panel", cs)
	_choice_root.add_child(card)
	_place(card, 0, 0, 40, 300, 1000, 760)
	_ch_icon = UiIcon.new()
	_ch_icon.glyph = "pot"
	_choice_root.add_child(_ch_icon)
	_place(_ch_icon, 0.5, 0, -75, 470, 150, 150)
	_ch_icon.pivot_offset = Vector2(75, 75)
	var chip := Panel.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", Style.box(Color(Style.ACCENT, 0.18), Style.ACCENT, Style.R_PILL, 3, false))
	_choice_root.add_child(chip)
	_place(chip, 0.5, 0, -400, 800, 800, 84)
	_ch_chip = chip
	_ch_title = _label(Style.SZ_XL, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_ch_title)
	_choice_root.add_child(_ch_title)
	_place(_ch_title, 0, 0, 0, 320, 1080, 140)
	_ch_title.anchor_right = 1.0
	_ch_title.offset_right = 0
	_ch_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.7))
	_ch_pot = _label(Style.SZ_XL - 8, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_ch_pot)
	_choice_root.add_child(_ch_pot)
	_place(_ch_pot, 0, 0, 0, 640, 1080, 130)
	_ch_pot.anchor_right = 1.0
	_ch_pot.offset_right = 0
	_ch_pot.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_ch_next = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_ch_next)
	_choice_root.add_child(_ch_next)
	_place(_ch_next, 0, 0, 0, 808, 1080, 64)
	_ch_next.add_theme_color_override("font_color", Style.ACCENT)
	_ch_next.anchor_right = 1.0
	_ch_next.offset_right = 0
	_ch_hint = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_ch_hint)
	_choice_root.add_child(_ch_hint)
	_ch_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_ch_hint, 0.5, 0, -460, 905, 920, 130)
	_ch_hint.add_theme_color_override("font_color", Color(0.7, 0.88, 1.0))
	_ch_cash = UiButton.new()
	_ch_cash.text = "CASH OUT"
	_ch_cash.font_px = 56
	_ch_cash.kind = "gold"
	_ch_cash.icon = "cash"
	_ch_cash.pressed.connect(func(): choice.emit("cashout"))
	_choice_root.add_child(_ch_cash)
	_place(_ch_cash, 0, 0, 40, 1110, 480, 230)
	_ch_keep = UiButton.new()
	_ch_keep.text = "KEEP FLYING"
	_ch_keep.font_px = 56
	_ch_keep.kind = "primary"
	_ch_keep.icon = "keep"
	_ch_keep.pressed.connect(func(): choice.emit("keep"))
	_choice_root.add_child(_ch_keep)
	_place(_ch_keep, 0, 0, 560, 1110, 480, 230)
	_ch_count = _label(180, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_ch_count)
	_choice_root.add_child(_ch_count)
	_place(_ch_count, 0, 0, 0, 630, 1080, 200)
	_ch_count.anchor_right = 1.0
	_ch_count.offset_right = 0
	_ch_count.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	_ch_count.visible = false

## `info`: {title, pot (int), next_mult (float), hint (String)}
func show_choice(info: Dictionary) -> void:
	_choice_on = true
	_ch_title.text = str(info["title"])
	_chpot_tgt = float(info["pot"])
	_chpot_shown = _chpot_tgt if _instant else 0.0
	_ch_pot.text = "POT  %d coins" % int(roundf(_chpot_shown))
	_ch_next.text = "Next landing pays  x%.1f" % float(info["next_mult"])
	_ch_hint.text = str(info["hint"])
	_ch_cash.text = "CASH OUT"
	_ch_cash.sub = "+%d" % int(info["pot"])
	_ch_cash.visible = true
	_ch_keep.visible = true
	_ch_count.visible = false
	_ch_next.visible = true
	_ch_hint.visible = true
	_ch_pot.visible = true
	_ch_chip.visible = true
	_sel_row.visible = false
	_menu_row.visible = false
	_bank_icon.visible = false
	_reveal(_choice_root, A_POP)

## CASH OUT was chosen: the buttons go, a big number counts up.
func show_cashout() -> void:
	_ch_cash.visible = false
	_ch_keep.visible = false
	_ch_next.visible = false
	_ch_hint.visible = false
	_ch_title.text = "BANKED!"
	_ch_pot.visible = false
	_ch_chip.visible = false
	_anim(_ch_title, A_POP, 0.0, 0.5)
	_ch_count.visible = true
	_ch_count.text = "+0"

func set_cash_count(n: int, pop: float = 0.0) -> void:
	_ch_count.text = "+%d" % n
	_ch_count.scale = Vector2.ONE * (1.0 + 0.12 * pop)
	_ch_count.pivot_offset = _ch_count.size * 0.5

func hide_choice() -> void:
	_choice_on = false
	_choice_root.visible = false

func choice_visible() -> bool:
	return _choice_on

## The pause button (top-right, clear of the approach view) and the pause menu: Resume / Settings (sound and music volume) / Quit
## (with a confirmation). Built once.
func _build_pause() -> void:
	_pause_btn = UiButton.new()
	_pause_btn.kind = "ghost"
	_pause_btn.icon = "pause"
	_pause_btn.focus_mode = Control.FOCUS_NONE
	_pause_btn.pressed.connect(func(): pause_action.emit("pause"))
	add_child(_pause_btn)
	_place(_pause_btn, 1, 0, -106 - (190.0 if DebugFlags.tune_enabled() else 0.0), 14, 86, 86)
	_pause_btn.visible = false
	_pause_root = Control.new()
	_pause_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.visible = false
	add_child(_pause_root)
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.05, 0.1, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.add_child(dim)
	_pz_title = _label(120, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_pz_title)
	_pause_root.add_child(_pz_title)
	_place(_pz_title, 0, 0, 0, 380, 1080, 150)
	_pz_title.anchor_right = 1.0
	_pz_title.offset_right = 0
	_pz_title.text = "PAUSED"
	_pz_main = _pz_group()
	for i in 3:
		var ids := ["resume", "settings", "quit"]
		var texts := ["RESUME", "SETTINGS", "QUIT"]
		var b := UiButton.new()
		b.text = texts[i]
		b.font_px = 48
		b.kind = "primary" if i == 0 else "secondary"
		var id: String = ids[i]
		b.pressed.connect(func(): pause_action.emit(id))
		_pz_main.add_child(b)
		_place(b, 0, 0, 190, 600 + i * 180, 700, 140)
	_pz_settings = _pz_group()
	var names := ["sound", "music"]
	var caps := ["SOUND", "MUSIC"]
	for i in 2:
		var l := _label(48, HORIZONTAL_ALIGNMENT_LEFT)
		remove_child(l)
		_pz_settings.add_child(l)
		l.text = caps[i]
		_place(l, 0, 0, 120, 600 + i * 190, 600, 70)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = 1.0
		var nm: String = names[i]
		sl.value_changed.connect(func(v: float): volume_changed.emit(nm, v))
		_pz_settings.add_child(sl)
		_place(sl, 0, 0, 120, 680 + i * 190, 840, 70)
		_pz_sliders[nm] = sl
	var sb := UiButton.new()
	sb.text = "BACK"
	sb.font_px = 48
	sb.icon = "back"
	sb.pressed.connect(func(): pause_action.emit("settings_back"))
	_pz_settings.add_child(sb)
	_place(sb, 0, 0, 190, 1040, 700, 140)
	_pz_confirm = _pz_group()
	_pz_confirm_text = _label(56, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_pz_confirm_text)
	_pz_confirm.add_child(_pz_confirm_text)
	_pz_confirm_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_pz_confirm_text, 0.5, 0, -440, 560, 880, 300)
	var yes := UiButton.new()
	yes.text = "YES, QUIT"
	yes.font_px = 48
	yes.kind = "danger"
	yes.icon = "quit"
	yes.pressed.connect(func(): pause_action.emit("quit_yes"))
	_pz_confirm.add_child(yes)
	_place(yes, 0, 0, 60, 960, 450, 150)
	var no := UiButton.new()
	no.text = "NO"
	no.font_px = 48
	no.kind = "primary"
	no.pressed.connect(func(): pause_action.emit("quit_no"))
	_pz_confirm.add_child(no)
	_place(no, 0, 0, 570, 960, 450, 150)

func _pz_group() -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	_pause_root.add_child(c)
	return c

func set_pause_button(on: bool) -> void:
	_pause_btn.visible = on and not _pause_on

## Where the pause menu's first button (RESUME) is, in viewport pixels (the audio check taps it).
func resume_center() -> Vector2:
	for c in _pz_main.get_children():
		if c is UiButton:
			return (c as UiButton).global_position + (c as UiButton).size * 0.5
	return Vector2(540, 670)

func pause_button_rect() -> Rect2:
	return Rect2(_pause_btn.global_position, _pause_btn.size)

func show_pause() -> void:
	_pause_on = true
	_pause_btn.visible = false
	_sel_row.visible = false
	_menu_row.visible = false
	_reveal(_pause_root, A_POP)
	show_pause_main()

func show_pause_main() -> void:
	_pz_title.text = "PAUSED"
	_pz_main.visible = true
	_pz_settings.visible = false
	_pz_confirm.visible = false

func show_pause_settings(sound: float, music: float) -> void:
	_pz_title.text = "SETTINGS"
	_pz_main.visible = false
	_pz_settings.visible = true
	_pz_confirm.visible = false
	(_pz_sliders["sound"] as HSlider).set_value_no_signal(sound)
	(_pz_sliders["music"] as HSlider).set_value_no_signal(music)

func show_pause_confirm(text: String) -> void:
	_pz_title.text = "QUIT?"
	_pz_confirm_text.text = text
	_pz_main.visible = false
	_pz_settings.visible = false
	_pz_confirm.visible = true

func hide_pause() -> void:
	_pause_on = false
	_pause_root.visible = false

func pause_visible() -> bool:
	return _pause_on

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
	_place(h1, 0, 0, 0, 495, 1080, 44)
	h1.anchor_right = 1.0
	h1.offset_right = 0
	for i in Cosmetics.PAINTS.size():
		_hangar_paint.append(_hangar_button("paint", i, 545 + (i / 2) * 84))
	var h2 := _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(h2)
	_hangar_root.add_child(h2)
	h2.text = "WHISKERS' GEAR"
	_place(h2, 0, 0, 0, 805, 1080, 44)
	h2.anchor_right = 1.0
	h2.offset_right = 0
	for i in Cosmetics.GEAR.size():
		_hangar_gear.append(_hangar_button("gear", i, 850 + (i / 2) * 84))
	var back := UiButton.new()
	back.text = "BACK"
	back.font_px = 44
	back.icon = "back"
	back.pressed.connect(func(): menu_action.emit("back"))
	_hangar_root.add_child(back)
	_place(back, 0.5, 0, -170, 1730, 340, 110)
	var h3 := _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(h3)
	_hangar_root.add_child(h3)
	h3.text = "AIRCRAFT"
	_place(h3, 0, 0, 0, 1112, 1080, 44)
	h3.anchor_right = 1.0
	h3.offset_right = 0
	for i in Planes.COUNT:
		_hangar_planes.append(_hangar_button("plane", i, 1160.0 + float(i) * 90.0, 30.0, 600.0))
		var bb := _hangar_button("plane_buy", i, 1160.0 + float(i) * 90.0, 650.0, 400.0)
		bb.kind = "gold"
		_hangar_buy.append(bb)

func _hangar_button(kind: String, idx: int, y: float, x: float = -1.0, w: float = 500.0) -> UiButton:
	var b := UiButton.new()
	b.font_px = 30
	b.icon = "paint" if kind == "paint" else ("cap" if kind == "gear" else ("coin" if kind == "plane_buy" else ""))
	b.pressed.connect(func(): hangar_pick.emit(kind, idx))
	_hangar_root.add_child(b)
	_place(b, 0, 0, (30.0 + float(idx % 2) * 520.0) if x < 0.0 else x, y, w, 80)
	return b

## Refresh the hangar's buttons from the save: "[NAME]" equipped, "NAME" owned, "NAME  150c" for sale.
func show_hangar(data: Dictionary, planes_avail: Array = [], plane_now: int = -1) -> void:
	_hangar_on = true
	_set_overlay(true)
	_ov_title.text = "HANGAR"
	_ov_title.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_ov_title.add_theme_font_size_override("font_size", 110)
	_ov_body.text = "Coins  %d\nOwning an aircraft ends its rental fee." % int(data["coins"])
	_ov_prompt.text = ""
	for i in _hangar_paint.size():
		var p: Dictionary = Cosmetics.PAINTS[i]
		_hangar_paint[i].text = _hangar_label(p["name"], p["cost"], (data["owned_paint"] as Array).has(i), int(data["paint"]) == i)
		_hangar_paint[i].accent = int(data["paint"]) == i
		_hangar_paint[i].disabled = false
	for i in _hangar_gear.size():
		var g: Dictionary = Cosmetics.GEAR[i]
		_hangar_gear[i].text = _hangar_label(g["name"], g["cost"], (data["owned_gear"] as Array).has(i), int(data["gear"]) == i)
		_hangar_gear[i].accent = int(data["gear"]) == i
	for i in _hangar_planes.size():
		var pn: String = Planes.NAMES[i]
		var owned: bool = (data["owned_planes"] as Array).has(i)
		var avail := planes_avail.has(i)
		var eq := plane_now == i
		var line := ("[%s]" % pn) if eq else pn
		if owned:
			line += "   owned" if not eq else ""
		elif avail:
			line += "   rent %d" % Economy.rent(i)
		else:
			line += "   locked"
		_hangar_planes[i].text = line
		_hangar_planes[i].accent = eq
		_hangar_planes[i].disabled = not avail
		_hangar_planes[i].icon = Icons.aircraft(i)
		var price := Planes.price(i)
		_hangar_buy[i].text = "OWNED" if owned else "BUY  %d" % price
		_hangar_buy[i].disabled = owned or int(data["coins"]) < price
		_hangar_buy[i].kind = "secondary" if owned else "gold"
	_menu_row.visible = false
	_sel_row.visible = false
	_reveal(_hangar_root, A_SLIDE_R)

func _hangar_label(item_name: String, cost: int, owned: bool, equipped: bool) -> String:
	if equipped:
		return "[%s]" % item_name
	return item_name if owned else "%s  %dc" % [item_name, cost]

func hide_hangar() -> void:
	if _hangar_on:
		_back_flag = true
	_hangar_on = false
	_hangar_root.visible = false
	_ov_title.add_theme_font_size_override("font_size", 150)

func hangar_visible() -> bool:
	return _hangar_on

## The fake "Ad playing" screen (a stub for a real ad SDK): covers everything but the splash.
func _build_ad() -> void:
	_ad_root = ColorRect.new()
	_ad_root.color = Color(Style.SCRIM, 0.96)
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
	var b: UiButton = _menu_buttons[id]
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
	var page := Panel.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_theme_stylebox_override("panel", Style.box(Color(Style.SURFACE_DARK, 0.55), Style.LINE, Style.R_L, 3))
	_log_root.add_child(page)
	_place(page, 0, 0, 14, 682, 1052, float(rows) * 60.0 + 76.0 + float(MAX_SLIPS) * 66.0)
	for i in n:
		var pn := Panel.new()
		pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxFlat.new()
		st.bg_color = Color(Style.SURFACE_DARK, 0.7)
		st.set_border_width_all(3)
		st.border_color = Color(Style.LINE, 0.35)
		st.set_corner_radius_all(Style.R_S)
		pn.add_theme_stylebox_override("panel", st)
		_log_root.add_child(pn)
		var col := i % STAMP_COLS
		var row := i / STAMP_COLS
		_place(pn, 0, 0.0, 30 + col * 342, 700 + row * 60, 330, 52)
		var lb := _label(24, HORIZONTAL_ALIGNMENT_CENTER)
		remove_child(lb)
		pn.add_child(lb)
		lb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_log_stamps.append(pn)
		_log_stamp_names.append(lb)
	_log_back = UiButton.new()
	_log_back.text = "BACK"
	_log_back.font_px = 44
	_log_back.icon = "back"
	_log_back.pressed.connect(func(): menu_action.emit("back"))
	_log_root.add_child(_log_back)
	_place(_log_back, 0.5, 0.0, -170, 1790, 340, 100)
	for i in MAX_SLIPS:     # pink slips: failed checkrides, kept for good
		var sp := _box(_log_root, 30, 700 + float(rows) * 60.0 + 16.0 + float(i) * 66.0, 1020, 58, Color(1.0, 0.72, 0.8, 0.95), 8, Color(0.8, 0.3, 0.45), 3)
		var sl := _label(28, HORIZONTAL_ALIGNMENT_LEFT)
		remove_child(sl)
		sp.add_child(sl)
		sl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sl.offset_left = 16
		sl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sl.add_theme_color_override("font_color", Color(0.45, 0.05, 0.2))
		sl.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.0))
		sp.visible = false
		_log_slips.append(sp)
		_log_slip_labels.append(sl)
	_log_more = _label(26, HORIZONTAL_ALIGNMENT_RIGHT)
	remove_child(_log_more)
	_log_root.add_child(_log_more)
	_place(_log_more, 0, 0, 530, 700 + float(rows) * 60.0 - 14.0, 520, 36)

func _sel_button(text: String, dir: int) -> UiButton:
	var b := UiButton.new()
	b.text = text
	b.font_px = 56
	b.kind = "ghost"
	b.icon = "back" if dir < 0 else "forward"
	b.text = ""
	b.pressed.connect(func(): plane_step.emit(dir))
	_sel_row.add_child(b)
	return b

## Show the chosen aircraft's name and a line about how it flies.
func set_plane_choice(id: int, rent_line: String = "", owned: bool = true) -> void:
	_sel_rent.text = rent_line
	_sel_rent.add_theme_color_override("font_color", Style.SUCCESS if owned else Style.ACCENT)
	_sel_rent.visible = rent_line != ""
	var pr: Dictionary = Planes.profile(id)
	_sel_name.text = pr["name"]
	_sel_icon.glyph = Icons.aircraft(id)
	if _live != null:
		_live.plane_glyph = Icons.aircraft(id)
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
	if _log_on or _hangar_on or _ad_on or _cr_on:
		return true
	if not _sel_row.visible:
		return false
	return Rect2(0.0, vs.y * 0.52 - 10.0, vs.x, 346.0).has_point(pos) or Rect2(0.0, vs.y * 0.78 - 10.0, vs.x, 440.0).has_point(pos)

## Where the airspeed bar draws its stall mark (the aircraft's stall speed).
func set_stall(v: float) -> void:
	stall_marker = v

func _label(size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.horizontal_alignment = align
	l.add_theme_font_override("font", Style.font_for("", size))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", maxi(size / 8, 4))
	l.add_theme_color_override("font_outline_color", Color(Style.INK, 0.92))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

## The studio logo intro: the Clear Prop Games propeller (spinning up, then easing) and its wordmark, fading in and out; a tap skips it. Built once, drawn only while `_logo_t` runs.
func _build_logo() -> void:
	_logo_root = ColorRect.new()
	_logo_root.color = Style.SURFACE_DARK
	_logo_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_logo_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_logo_root.visible = false
	add_child(_logo_root)
	var mark := UiIcon.new()
	mark.glyph = "prop"
	mark.tint = Style.PRIMARY
	_logo_root.add_child(mark)
	_place(mark, 0.5, 0.42, -110, -110, 220, 220)
	mark.pivot_offset = Vector2(110, 110)
	var nm := _label(Style.SZ_L, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(nm)
	_logo_root.add_child(nm)
	nm.text = "Clear Prop Games"
	_place(nm, 0.5, 0.42, -500, 130, 1000, 110)
	_logo_root.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.is_pressed():
			_logo_t = LOGO_SECONDS)

func start_logo() -> void:
	_logo_t = 0.0
	for k in _logo_root.get_children():
		(k as Control).modulate.a = 0.0
	_logo_root.visible = true
	set_process(true)

func logo_running() -> bool:
	return _logo_t >= 0.0

func _process(delta: float) -> void:
	_update_anims(delta)
	_update_rolls(delta)
	_update_toast(delta)
	if _live != null:
		_live.visible = _menu_row.visible and not _splash.visible
	if _logo_t < 0.0:
		return
	_logo_t += delta
	var a := clampf(_logo_t / 0.4, 0.0, 1.0) * clampf((LOGO_SECONDS - _logo_t) / 0.4, 0.0, 1.0)
	for k in _logo_root.get_children():
		(k as Control).modulate.a = a      # (the dark backdrop stays solid: the game behind it is not ready to be seen)
	var mk: Control = _logo_root.get_child(0)
	mk.scale = Vector2.ONE * (0.9 + 0.1 * Style.ease_out_back(clampf(_logo_t / 0.6, 0.0, 1.0)))
	mk.rotation = 14.0 * (1.0 - pow(1.0 - clampf(_logo_t / LOGO_SECONDS, 0.0, 1.0), 3.0))
	if _logo_t >= LOGO_SECONDS:
		_logo_t = -1.0
		_logo_root.visible = false
		logo_finished.emit()

# ---------- motion: screen transitions, entrances, stamps ----------

func _build_fx() -> void:
	_an_node.resize(AN_MAX)
	_an_kind.resize(AN_MAX)
	_an_t.resize(AN_MAX)
	_an_delay.resize(AN_MAX)
	_an_dur.resize(AN_MAX)
	_an_aux.resize(AN_MAX)
	_an_hit.resize(AN_MAX)
	_live = MenuScene.new()
	add_child(_live)
	move_child(_live, mini(_sel_row.get_index(), _menu_row.get_index()))
	_burst = UiBurst.new()
	add_child(_burst)
	move_child(_burst, _splash.get_index())
	_burst.coin_arrived.connect(_on_coin_arrived)
	_bank_icon = UiIcon.new()
	_bank_icon.glyph = "coin"
	_choice_root.add_child(_bank_icon)
	_place(_bank_icon, 0, 0, 40, 130, 110, 110)
	_bank_icon.pivot_offset = Vector2(55, 55)
	_bank_icon.visible = false
	_build_strip()
	_toast_panel = Panel.new()
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_panel)
	move_child(_toast_panel, _splash.get_index())
	_place(_toast_panel, 0.5, 0, -470, 1372, 940, 84)
	_toast_panel.pivot_offset = Vector2(470, 42)
	_toast_panel.visible = false
	_toast_label = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_toast_label)
	_toast_panel.add_child(_toast_label)
	_toast_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_cr_sig = _label(Style.SZ_M, HORIZONTAL_ALIGNMENT_LEFT)
	remove_child(_cr_sig)
	_cr_speech_panel.add_child(_cr_sig)
	_cr_sig.text = "Capt. Wiggins"
	_cr_sig.rotation = -0.06
	_cr_sig.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_cr_sig.offset_left = 24
	_cr_sig.offset_top = -66
	_cr_sig.offset_right = 360
	_cr_sig.offset_bottom = -6
	_cr_sig.add_theme_color_override("font_color", Color(0.12, 0.2, 0.55))
	_cr_sig.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.0))
	_cr_sig.visible = false
	_cert_seal = _seal(_cert_root, "APPROVED", Color(0.75, 0.15, 0.12), 560.0, 1000.0, 400.0, 120.0)
	var slip_holder := Control.new()
	slip_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slip_holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(slip_holder)
	move_child(slip_holder, _splash.get_index())
	_slip_seal = _seal(slip_holder, "FAILED", Color(0.85, 0.15, 0.3), 320.0, 770.0, 440.0, 130.0)
	_slip_seal.visible = false
	_lost_seal = _seal(slip_holder, "POT LOST", Color(1.0, 0.36, 0.3), 190.0, 1060.0, 700.0, 150.0)
	_lost_label = _lost_seal.get_child(0) as Label
	_lost_seal.visible = false

## The approach profile strip across the top, the HUD's top row moved down under it, and the off-screen runway arrow.
const STRIP_SHIFT := 140.0
func _build_strip() -> void:
	_strip = ApproachStrip.new()
	add_child(_strip)
	move_child(_strip, _splash.get_index())
	var right_gap := 110.0 + (190.0 if DebugFlags.tune_enabled() else 0.0)
	_place(_strip, 0, 0, 24, 14, 1080.0 - 48.0 - right_gap, 120)
	_strip.set_meta("top_hud", true)
	_pause_btn.set_meta("top_hud", true)
	for c in [_score, _round, _wind, _runway, _dist, _pot, _streak_label, _streak_flame, _scn_label, _gust, _alt, _sink, _speed_back, _speed_band, _speed_bar, _stall_mark, _speed_label]:
		(c as Control).offset_top += STRIP_SHIFT
		(c as Control).offset_bottom += STRIP_SHIFT
		c.set_meta("top_hud", true)
	for c in _strikes:
		c.offset_top += STRIP_SHIFT
		c.offset_bottom += STRIP_SHIFT
		c.set_meta("top_hud", true)
	_rwy_ind = Panel.new()
	_rwy_ind.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rwy_ind.add_theme_stylebox_override("panel", Style.box(Color(Style.SURFACE_DARK, 0.86), Style.ACCENT, Style.R_PILL, 3))
	add_child(_rwy_ind)
	move_child(_rwy_ind, _splash.get_index())
	_place(_rwy_ind, 1, 0, -318, 1370, 306, 70)
	_rwy_ind.visible = false
	_rwy_ind_label = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(_rwy_ind_label)
	_rwy_ind.add_child(_rwy_ind_label)
	_rwy_ind_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rwy_ind_label.offset_left = 14
	_rwy_ind_label.offset_right = -60
	_rwy_ind_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_rwy_ind_icon = UiIcon.new()
	_rwy_ind_icon.glyph = "forward"
	_rwy_ind_icon.tint = Style.ACCENT
	_rwy_ind.add_child(_rwy_ind_icon)
	_rwy_ind_icon.position = Vector2(250, 12)
	_rwy_ind_icon.size = Vector2(46, 46)

## A round was laid out: draw its profile (the obstacles, the runway, the glidepath) on the strip.
func set_profile(af: Airfield, start_x: float, start_y: float) -> void:
	_strip.set_profile(af, start_x, start_y)

## Every frame: the plane's dot on the strip and, while the runway is off the right edge of the screen, the arrow pointing at it.
## `show`: the strip is visible; `ind_ft` >= 0 shows "RWY n ft" at screen height `ind_y`.
func set_strip(x: float, y: float, thr_now: float, end_now: float, show: bool, ind_ft: float = -1.0, ind_y: float = 0.0) -> void:
	_strip.visible = show
	if show:
		_strip.set_plane(x, y, thr_now, end_now)
	var on := show and ind_ft >= 0.0
	_rwy_ind.visible = on
	if on:
		var n := int(roundf(ind_ft / 10.0)) * 10
		_rwy_ind_label.text = "RWY %s ft" % _thousands(n)
		var vs := get_viewport().get_visible_rect().size
		_rwy_ind.offset_top = vs.y * 0.46 - 35.0      # (mid-screen on the right: clear of the obstacles and the ground ahead)
		_rwy_ind.offset_bottom = _rwy_ind.offset_top + 70.0

static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	for i in s.length():
		if i > 0 and (s.length() - i) % 3 == 0:
			out += ","
		out += s[i]
	return ("-" if n < 0 else "") + out

## Where everything at the top of the screen is, in viewport pixels: "group.name" -> the rect of the element's ink (a label's
## text, not its box). The smoke test checks that no two elements of different groups overlap on 9:16 and 9:20.
func layout_rects() -> Dictionary:
	var ink := func(c: Control) -> Rect2:
		var cr := c.get_global_rect()
		if c is Label:
			var lb := c as Label
			var ms := lb.get_minimum_size()
			var w := minf(ms.x, cr.size.x)
			var x := cr.position.x
			if lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER:
				x = cr.position.x + (cr.size.x - w) * 0.5
			elif lb.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT:
				x = cr.end.x - w
			cr = Rect2(x, cr.position.y, w, minf(ms.y, cr.size.y))
		return cr
	var out := {
		"strip.strip": _strip.get_global_rect(),
		"pause.pause": pause_button_rect(),
		"papi.papi": Rect2(papi_rect().position - Vector2(18, 18), papi_rect().size + Vector2(36, 36 + 44)),
	}
	var groups := {"speed": [_alt, _sink, _speed_back, _speed_band, _speed_label], "left": [_score, _round, _pot, _scn_label, _streak_label],
		"center": [_wind, _runway, _dist]}
	for g in groups:
		for c in groups[g]:
			out["%s.%d" % [g, (c as Control).get_instance_id()]] = ink.call(c)
	return out

## ---------- toasts: short messages on a pill ("Short Field +1, 2/3", "Rental -20 coins"), one after another ----------

var _toast_q: Array[String] = []
var _toast_cols: Array[Color] = []
var _toast_panel: Panel
var _toast_label: Label
var _toast_t := -1.0
var toast_log: Array[String] = []         # (tests) every toast shown, oldest first

func toast(text: String, color: Color = Color(1, 1, 1)) -> void:
	toast_log.append(text)
	if toast_log.size() > 50:
		toast_log.pop_front()
	if _instant:
		_toast_label.text = text
		return
	if _toast_q.size() >= 4:
		_toast_q.pop_front()
		_toast_cols.pop_front()
	_toast_q.append(text)
	_toast_cols.append(color)
	if _toast_t < 0.0:
		_next_toast()

func _next_toast() -> void:
	if _toast_q.is_empty():
		_toast_t = -1.0
		_toast_panel.visible = false
		return
	_toast_label.text = _toast_q.pop_front()
	var col: Color = _toast_cols.pop_front()
	_toast_label.add_theme_color_override("font_color", col)
	_toast_panel.add_theme_stylebox_override("panel", Style.box(Color(Style.SURFACE_DARK, 0.94), col, Style.R_PILL, 4))
	_toast_panel.visible = true
	_toast_t = 0.0

func _update_toast(delta: float) -> void:
	if _toast_t < 0.0:
		return
	_toast_t += delta
	var k := _toast_t / 2.6
	var a := clampf(_toast_t / 0.2, 0.0, 1.0) * clampf((2.6 - _toast_t) / 0.3, 0.0, 1.0)
	_toast_panel.modulate.a = a
	_toast_panel.scale = Vector2.ONE * (0.85 + 0.15 * Style.ease_out_back(clampf(_toast_t / 0.3, 0.0, 1.0)))
	if k >= 1.0:
		_next_toast()

## A rubber stamp: a bordered, slightly tilted word.
func _seal(parent: Control, text: String, color: Color, x: float, y: float, w: float, h: float) -> Control:
	var pn := Panel.new()
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(color, 0.0)
	st.set_border_width_all(10)
	st.border_color = color
	st.set_corner_radius_all(18)
	pn.add_theme_stylebox_override("panel", st)
	parent.add_child(pn)
	_place(pn, 0, 0, x, y, w, h)
	pn.pivot_offset = Vector2(w, h) * 0.5
	pn.rotation = -0.2
	var lb := _label(Style.SZ_M + 8, HORIZONTAL_ALIGNMENT_CENTER)
	remove_child(lb)
	pn.add_child(lb)
	lb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lb.text = text
	lb.add_theme_color_override("font_color", color)
	lb.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.0))
	return pn

func _anim(node: Control, kind: int, delay: float = 0.0, dur: float = -1.0, aux: Color = Color.WHITE) -> void:
	if _instant or node == null:
		return
	var i := _an_node.find(node)
	if i < 0 or i >= _an_n:
		if _an_n >= AN_MAX:
			return
		i = _an_n
		_an_n += 1
		_an_node[i] = node
	_an_kind[i] = kind
	_an_t[i] = -delay
	_an_dur[i] = dur if dur > 0.0 else (0.55 if kind == A_STAMP else (1.0 if kind == A_SIGN else Style.T_BASE + 0.1))
	_an_aux[i] = aux
	_an_hit[i] = 0
	node.pivot_offset = node.size * 0.5
	if kind == A_FLIP:
		node.pivot_offset = Vector2(0.0, node.size.y * 0.5)
	_apply_anim(i, 0.0)

func _apply_anim(i: int, k: float) -> void:
	var n: Control = _an_node[i]
	var e := Style.ease_out_cubic(k)
	match _an_kind[i]:
		A_SLIDE_R, A_SLIDE_L:
			n.position.x = (1.0 - e) * (160.0 if _an_kind[i] == A_SLIDE_R else -160.0)
			n.modulate.a = e
		A_POP:
			n.scale = Vector2.ONE * (0.82 + 0.18 * Style.ease_out_back(k))
			n.modulate.a = clampf(k * 4.0, 0.0, 1.0)
		A_RISE:
			n.scale = Vector2.ONE * (0.88 + 0.12 * Style.ease_out_back(k))
			n.modulate.a = clampf(k * 3.0, 0.0, 1.0)
		A_STAMP:
			var base: float = _an_aux[i].r
			var fall := clampf(k / 0.6, 0.0, 1.0)
			var sc := lerpf(3.2, 1.0, Style.ease_in_cubic(fall))
			if k > 0.6:
				sc = 1.0 + 0.08 * sin((k - 0.6) / 0.4 * PI)
			n.scale = Vector2.ONE * sc
			n.rotation = base + 0.25 * (1.0 - fall)
			n.modulate.a = clampf(k * 6.0, 0.0, 1.0)
			if k >= 0.6 and _an_hit[i] == 0:
				_an_hit[i] = 1
				_shake = 0.35
				ui_sound.emit("stamp")
				if n == _cert_seal:
					confetti_burst()
				elif n == _slip_seal:
					ui_sound.emit("trombone")
		A_FILL:
			var col: Color = _an_aux[i]
			(n as ColorRect).color = Color(0.2, 0.24, 0.3, 0.9).lerp(col, e)
			n.scale = Vector2.ONE * (1.0 + 0.45 * sin(k * PI))
		A_SIGN:
			(n as Label).visible_ratio = k
		A_FLIP:
			n.scale.x = maxf(e, 0.02)
			n.modulate.a = clampf(k * 3.0, 0.0, 1.0)

func _finish_anim(i: int) -> void:
	var n: Control = _an_node[i]
	n.position.x = 0.0 if (_an_kind[i] == A_SLIDE_R or _an_kind[i] == A_SLIDE_L) else n.position.x
	n.modulate.a = 1.0
	n.scale = Vector2.ONE
	match _an_kind[i]:
		A_STAMP:
			n.rotation = _an_aux[i].r
		A_FILL:
			(n as ColorRect).color = _an_aux[i]
		A_SIGN:
			(n as Label).visible_ratio = 1.0

func _update_anims(delta: float) -> void:
	if _shake > 0.0:
		_shake = maxf(_shake - delta, 0.0)
		var o := Vector2(sin(float(Time.get_ticks_msec()) * 0.09), cos(float(Time.get_ticks_msec()) * 0.077)) * _shake * 24.0
		offset = o if _shake > 0.0 else Vector2.ZERO
	var i := 0
	while i < _an_n:
		_an_t[i] += delta
		if _an_t[i] < 0.0:
			i += 1
			continue
		var k := clampf(_an_t[i] / _an_dur[i], 0.0, 1.0)
		_apply_anim(i, k)
		if k >= 1.0:
			_finish_anim(i)
			_an_n -= 1
			_an_node[i] = _an_node[_an_n]
			_an_kind[i] = _an_kind[_an_n]
			_an_t[i] = _an_t[_an_n]
			_an_delay[i] = _an_delay[_an_n]
			_an_dur[i] = _an_dur[_an_n]
			_an_aux[i] = _an_aux[_an_n]
			_an_hit[i] = _an_hit[_an_n]
			_an_node[_an_n] = null
		else:
			i += 1

## Show a screen root with its transition (slide from the side, or pop) and its children entering one after another.
## Returns false (and does nothing more) when it was already showing, so refreshing a screen doesn't replay it.
func _reveal(root: Control, kind: int) -> bool:
	var was := root.visible
	root.visible = true
	if was:
		return false
	if _instant:
		return true
	_anim(root, kind)
	ui_sound.emit("page" if kind == A_FLIP else "whoosh")
	var d := 0
	for c in root.get_children():
		if not (c is Control) or not (c as Control).visible:
			continue
		var delay := minf(float(d) * Style.STAGGER * 0.6, 0.5) + 0.06
		if c is UiButton:
			(c as UiButton).pop_in(delay)
		else:
			_anim(c as Control, A_RISE, delay)
		d += 1
	return true

func _on_coin_arrived() -> void:
	ui_sound.emit("coin")
	if _bank_icon.visible:
		_bank_icon.scale = Vector2.ONE * 1.3
	_pot.scale = Vector2.ONE * 1.25

## Coins fly from `from` into the pot readout.
func fly_coins_to_pot(from: Vector2, n: int) -> void:
	if _instant:
		return
	_pot.pivot_offset = Vector2(60, 24)
	_burst.fly_coins(from, _pot.global_position + Vector2(80, 24), clampi(n, 3, 10), 0.15)

## Coins fly from the big pot number into the bank (the coin at the top-left).
func fly_coins_to_bank(n: int) -> void:
	_bank_icon.visible = true
	_bank_icon.scale = Vector2.ONE
	if _instant:
		return
	_burst.fly_coins(Vector2(540, 640), Vector2(95, 185), clampi(n / 8, 6, 24), 0.0)

## "POT LOST  -840": the pot's coins spill out and a red stamp slams down (the crash popup says it in words too).
func show_pot_lost(n: int) -> void:
	_lost_label.text = "POT LOST  -%d" % n
	_lost_seal.visible = true
	if _instant:
		return
	_lost_seal.modulate.a = 0.0
	_anim(_lost_seal, A_STAMP, 0.55, 0.55, Color(0, 0, 0, 0))
	_burst.scatter_coins(_pot.global_position + Vector2(80, 24), clampi(n / 20, 6, 20))

func _ch_card_ok() -> bool:
	return _ch_chip != null and _ch_pot != null

func hide_pot_lost() -> void:
	_lost_seal.visible = false

func confetti_burst() -> void:
	if not _instant:
		_burst.confetti(Vector2(540, 1150), 70)

# ---------- rolling numbers ----------

func _update_rolls(delta: float) -> void:
	var k := minf(delta * 7.0, 1.0)
	if _choice_on and _ch_cash.visible:
		var tt := float(Time.get_ticks_msec()) * 0.001
		_ch_cash.pivot_offset = _ch_cash.size * 0.5
		_ch_cash.scale = Vector2.ONE * (1.0 + 0.035 * sin(tt * 5.5))
		_ch_icon.scale = Vector2.ONE * (1.0 + 0.06 * sin(tt * 3.0))
		_ch_icon.rotation = 0.06 * sin(tt * 2.3)
	if _pot.scale.x > 1.0:
		_pot.scale = Vector2.ONE * maxf(_pot.scale.x - delta * 1.6, 1.0)
	if _bank_icon.visible and _bank_icon.scale.x > 1.0:
		_bank_icon.scale = Vector2.ONE * maxf(_bank_icon.scale.x - delta * 2.0, 1.0)
	if absf(_pot_shown - _pot_tgt) > 0.4:
		_pot_shown += (_pot_tgt - _pot_shown) * k + signf(_pot_tgt - _pot_shown) * 0.3
		_pot.text = "POT %d   x%.1f" % [int(roundf(_pot_shown)), _pot_mult]
	if absf(_score_shown - _score_tgt) > 0.4:
		_score_shown += (_score_tgt - _score_shown) * k + signf(_score_tgt - _score_shown) * 0.3
		_score.text = str(int(roundf(_score_shown)))
	if absf(_chpot_shown - _chpot_tgt) > 0.4:
		_chpot_shown += (_chpot_tgt - _chpot_shown) * k + signf(_chpot_tgt - _chpot_shown) * 0.3
		_ch_pot.text = "POT  %d coins" % int(roundf(_chpot_shown))

## Move everything that hugs the top or bottom edge inside the safe area (notch, home bar). Idempotent: works from the designed offsets.
func apply_safe() -> void:
	var vs := get_viewport().get_visible_rect().size
	for c in get_children():
		if c is Control:
			_pin_safe(c as Control, vs, true)

func _pin_safe(c: Control, vs: Vector2, top_level: bool) -> void:
	var full := c.anchor_right == 1.0 and c.anchor_bottom == 1.0 and c.anchor_left == 0.0 and c.anchor_top == 0.0
	if full and c.offset_right == 0.0 and c.offset_bottom == 0.0:
		for k in c.get_children():
			if k is Control:
				_pin_safe(k as Control, vs, false)
		return
	if c.anchor_top != c.anchor_bottom:
		return
	if not c.has_meta("base_top"):
		c.set_meta("base_top", c.offset_top)
		c.set_meta("base_bottom", c.offset_bottom)
		c.set_meta("base_left", c.offset_left)
		c.set_meta("base_right", c.offset_right)
	var y: float = c.anchor_top * vs.y + float(c.get_meta("base_top"))
	var dy := 0.0
	if c.has_meta("top_hud"):
		dy = Style.safe_top
	elif c.anchor_top == 0.0 and y < Style.safe_top + 60.0 and not (c is ColorRect and c.size.x > 600.0):
		dy = Style.safe_top
	elif c.anchor_top == 1.0 or y + c.size.y > vs.y - 140.0 - Style.safe_bottom and c.anchor_top > 0.5 and y > vs.y * 0.8:
		dy = -Style.safe_bottom
	c.offset_top = float(c.get_meta("base_top")) + dy
	c.offset_bottom = float(c.get_meta("base_bottom")) + dy
	if c.anchor_left == 1.0:
		c.offset_left = float(c.get_meta("base_left")) - Style.safe_right
		c.offset_right = float(c.get_meta("base_right")) - Style.safe_right
	elif c.anchor_left == 0.0 and c.anchor_right == 0.0:
		c.offset_left = float(c.get_meta("base_left")) + Style.safe_left
		c.offset_right = float(c.get_meta("base_right")) + Style.safe_left

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
	_score_tgt = float(v)
	if _instant or v < int(_score_shown) or v == 0:
		_score_shown = float(v)
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
	var a := Units.kt(absf(head))
	if a < 1.0:
		_wind.text = "WIND  calm"
	elif head > 0.0:
		_wind.text = "WIND  %.0f KT headwind  <<" % a
	else:
		_wind.text = "WIND  %.0f KT tailwind  >>" % a

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
	_streak_flame.visible = n > 0
	if n > 0:
		_streak_label.text = "STREAK x%d" % mini(n, Tuning.streak_cap)
		if pop and not _instant and (n == 3 or n == 5 or n >= 7):
			_burst.confetti(Vector2(180, 300), 10 + 4 * mini(n, 8))      # a little party at each step up
			ui_sound.emit("fanfare")

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
		_streak_flame.visible = false

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
		_streak_flame.modulate = Color(0.6, 0.62, 0.7, clampf(_streak_lost_t * 2.0, 0.0, 1.0))
		_streak_label.scale = Vector2.ONE
		if _streak_lost_t <= 0.0:
			_streak_label.visible = false
			_streak_flame.visible = false
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
	_streak_flame.modulate = col
	_streak_flame.scale = Vector2.ONE * (0.8 + 0.12 * float(tier) + 0.08 * sin(_t * 9.0) + 0.3 * _streak_pop)
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
	_card_blurb.add_theme_font_size_override("font_size", 40 if blurb.length() < 150 else 30)
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
## Where the Vref tolerance band sits on the airspeed bar, as fractions of Vref (e.g. 0.92 .. 1.15).
func set_speed_band(lo: float, hi: float) -> void:
	_band_lo = lo
	_band_hi = hi
	_speed_band.offset_left = -300.0 + 280.0 * clampf(lo / 1.3, 0.0, 1.0)
	_speed_band.offset_right = -300.0 + 280.0 * clampf(hi / 1.3, 0.0, 1.0)

## The flight readouts: height above the ground (units -> feet), vertical speed (units/s -> feet per minute), airspeed as a fraction
## of Vref and Vref in knots.
func set_flight(alt: float, vy: float, s: float, vref_kt: float, show: bool) -> void:
	_alt.visible = show
	_sink.visible = show
	_speed_bar.visible = show
	_speed_back.visible = show
	_speed_band.visible = show
	_stall_mark.visible = show
	_speed_label.visible = show
	if not show:
		return
	_alt.text = "ALT %d FT" % (int(roundf(Units.ft(alt) / 5.0)) * 5)
	var sink := -vy
	var fpm := int(roundf(Units.fpm(vy) / 10.0)) * 10
	_sink.text = "V/S %d FPM" % fpm
	_sink.modulate = Grading.COLORS[Grading.grade_for_sink(maxf(sink, 0.0))] if sink >= 0.0 else Color(0.6, 0.9, 1.0)
	var frac := clampf(s / 1.3, 0.0, 1.0)
	_speed_bar.offset_right = _speed_bar.offset_left + 272.0 * frac
	if s < stall_marker + 0.04:
		_speed_bar.color = Style.DANGER
	elif s >= _band_lo and s <= _band_hi:
		_speed_bar.color = Style.SUCCESS
	else:
		_speed_bar.color = Style.ACCENT
	_speed_label.text = "%d KT   VREF %d" % [int(roundf(s * vref_kt)), int(roundf(vref_kt))]
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
	_pop_grade = Grading.NAMES.find(title)
	var stars := [3, 2, 2, 1, 0]
	for i in 3:
		var on: bool = _pop_grade >= 0 and i < int(stars[_pop_grade])
		_pop_stars[i].glyph = "star" if on else "star_off"
		_pop_stars[i].visible = _pop_grade >= 0
	var sb := Style.box(Color(Style.SURFACE_DARK, 0.93), color, Style.R_L, 6)
	sb.shadow_color = Color(color, 0.45 if _pop_grade == 0 else 0.2)
	sb.shadow_size = 40 if _pop_grade == 0 else 18
	sb.shadow_offset = Vector2.ZERO
	_pop_panel.add_theme_stylebox_override("panel", sb)
	if _pop_grade == 0 and not _instant:
		_burst.confetti(Vector2(540, 640), 40)
		ui_sound.emit("fanfare")

## (tests) the grade popup's big text.
func _popup_text_for_test() -> String:
	return _pop_title.text + " " + _pop_sub.text

func clear_popup() -> void:
	_pop_t = 99.0
	_pop_panel.modulate.a = 0.0
	for st in _pop_stars:
		st.modulate.a = 0.0
	_pop_title.modulate.a = 0.0
	_pop_sub.modulate.a = 0.0

# ---------- overlay / fade ----------

func show_menu(best: int, career_text: String = "") -> void:
	hide_career()
	hide_certificate()
	_set_overlay(true)
	_ov_title.text = "GREASER"
	_ov_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_ov_body.text = career_text + "Drag up / down to pitch the nose. Flare just before touchdown.\nTouch down on the aim markers. A crash loses the pot. No go-arounds." + (("\n\nBest: %d" % best) if best > 0 else "")
	_ov_prompt.text = "TAP TO FLY"
	if _back_flag and not _instant:
		_anim(_sel_row, A_SLIDE_L)
		_anim(_menu_row, A_SLIDE_L, 0.05)
	_back_flag = false

## A result screen (checkride passed / failed, rank-up): title, body and prompt.
func show_notice(title: String, body: String, prompt: String, color: Color) -> void:
	hide_career()
	hide_certificate()
	_set_overlay(true)
	_ov_title.text = title
	_ov_title.add_theme_font_size_override("font_size", 90)
	_ov_title.add_theme_color_override("font_color", color)
	_ov_body.text = body
	_ov_prompt.text = prompt
	var slip := title == "PINK SLIP"
	if slip and not _slip_seal.visible:
		_slip_seal.visible = true
		_slip_seal.modulate.a = 0.0
		_anim(_slip_seal, A_STAMP, 0.7, 0.55, Color(0, 0, 0, 0))
		if _instant:
			_slip_seal.modulate.a = 1.0
	elif not slip:
		_slip_seal.visible = false

## The logbook screen. `stamped` maps airport id -> {"name", "day", "n"}.
func show_logbook(body: String, stamped: Dictionary, slips: Array = []) -> void:
	_log_on = true
	hide_hangar()
	hide_career()
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
			st.border_color = Style.ACCENT
			st.bg_color = Color(Style.ACCENT_DARK, 0.35)
		else:
			_log_stamp_names[i].text = "- - -"
			_log_stamp_names[i].modulate = Color(1, 1, 1, 0.35)
			st.border_color = Color(Style.LINE, 0.35)
			st.bg_color = Color(Style.SURFACE_DARK, 0.7)
	var shown := mini(slips.size(), MAX_SLIPS)
	for i in MAX_SLIPS:
		_log_slips[i].visible = i < shown
		if i < shown:
			var sl: Dictionary = slips[slips.size() - 1 - i]       # newest first
			_log_slip_labels[i].text = "PINK SLIP   %s   %s checkride   %s" % [sl["date"], sl["rank"], sl["type"]]
	_log_more.text = ("+%d earlier pink slips" % (slips.size() - shown)) if slips.size() > shown else ""
	_menu_row.visible = false
	_sel_row.visible = false
	var fresh := _reveal(_log_root, A_FLIP)
	var d := 0
	for i in list.size():
		var id: String = list[i]["id"]
		if stamped.has(id) and not _log_seen.has(id):
			_log_seen[id] = true
			if fresh and not _instant:
				_anim(_log_stamps[i], A_STAMP, 0.7 + float(d) * 0.45, 0.5, Color(0, 0, 0, 0))
				d += 1
		elif stamped.has(id):
			_log_seen[id] = true
	if fresh and not _instant and shown > 0:
		_anim(_log_slips[0], A_STAMP, 0.7 + float(d) * 0.45, 0.5, Color(0, 0, 0, 0.0))

func hide_logbook() -> void:
	if _log_on:
		_back_flag = true
	_log_on = false
	_log_root.visible = false
	_ov_title.add_theme_font_size_override("font_size", 150)

func logbook_visible() -> bool:
	return _log_on

## The end of a free-flight run: cashed out (`banked` coins went into your account) or lost (`lost` = the pot that went down
## with the aircraft).
func show_over(total: int, best: int, landings: int, new_best: bool, best_streak: int = 0, banked: int = 0, lost: int = 0) -> void:
	hide_career()
	hide_certificate()
	hide_choice()
	_set_overlay(true)
	var cashed := banked > 0 and lost == 0
	_ov_title.text = "CASHED OUT" if cashed else "RUN OVER"
	_ov_title.add_theme_font_size_override("font_size", 120 if cashed else 150)
	_ov_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if cashed else Color(1.0, 0.4, 0.35))
	var money := ""
	if lost > 0:
		money = "\nPot lost: %d coins" % lost
	elif banked > 0:
		money = "\nBanked  +%d coins" % banked
	if over_extra != "":
		money += "\n" + over_extra
	_ov_body.text = "Score  %d\nLandings  %d\nBest streak  x%d\n%s%s" % [total, landings, maxi(best_streak, 1) if best_streak > 0 else 0, "NEW BEST!" if new_best else "Best  %d" % best, money]
	_ov_prompt.text = "TAP TO FLY AGAIN"
	_menu_row.visible = true

func hide_overlay() -> void:
	_set_overlay(false)

func _set_overlay(on: bool) -> void:
	if on and not overlay_visible and not _instant:
		_overlay.modulate.a = 0.0
		_anim(_overlay, A_RISE, 0.0, 0.3)
		_anim(_ov_title, A_POP, 0.05, 0.45)
		_anim(_ov_body, A_RISE, 0.15, 0.4)
		_anim(_ov_prompt, A_RISE, 0.3, 0.4)
	overlay_visible = on
	if not on:
		hide_logbook()
		hide_hangar()
		hide_career()
		hide_certificate()
	if not on:
		_slip_seal.visible = false
	_sel_row.visible = on and not _splash.visible
	_menu_row.visible = on and not _splash.visible and not _log_on and not _hangar_on and not _cr_on and not _cert_on
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
		var grow := 0.55 + 0.45 * Style.ease_out_back(clampf(_pop_t / 0.34, 0.0, 1.0))
		var pop := grow * (1.18 if _pop_grade == 0 else 1.0)
		var a := clampf((1.0 - k) * 4.0, 0.0, 1.0)
		_pop_title.pivot_offset = _pop_title.size * 0.5
		_pop_title.scale = Vector2(pop, pop)
		_pop_title.rotation = deg_to_rad(sin(_pop_t * 38.0) * 2.5 * maxf(1.0 - _pop_t * 3.0, 0.0)) if _pop_grade == 0 else 0.0
		_pop_title.modulate = Color(_pop_color.r, _pop_color.g, _pop_color.b, a)
		_pop_sub.modulate = Color(1, 1, 1, a)
		_pop_panel.scale = Vector2.ONE * grow
		_pop_panel.modulate.a = a
		for i in 3:
			var d := clampf((_pop_t - 0.12 - 0.1 * float(i)) / 0.3, 0.0, 1.0)
			_pop_stars[i].scale = Vector2.ONE * (0.2 + 0.8 * Style.ease_out_back(d))
			_pop_stars[i].rotation = (1.0 - d) * 0.8
			_pop_stars[i].modulate.a = a * d
	elif _pop_title.modulate.a > 0.0:
		_pop_title.modulate.a = 0.0
		_pop_sub.modulate.a = 0.0
		_pop_panel.modulate.a = 0.0
		for st in _pop_stars:
			st.modulate.a = 0.0
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
	_career_root.visible = true
	_cert_root.visible = true
	_choice_root.visible = true
	_pause_root.visible = true
	_pz_main.visible = true
	_pause_btn.visible = true
	_menu_row.visible = true
	_ov_title.text = "GREASER"
	_ov_body.text = "0123456789 Greaser! Smooth Good Firm Hard CRASH Off the runway! Hit the trees!"
	_ov_prompt.text = "TAP"
	if not DebugFlags.off("popup"):
		_pop_title.text = "Greaser!"
		_pop_sub.text = "Sink 0.5   Aim +2   No bounce   +96"
		_pop_title.modulate.a = 1.0
		_pop_sub.modulate.a = 1.0
		_pop_panel.modulate.a = 1.0
		for st in _pop_stars:
			st.modulate.a = 1.0
			st.visible = true
	_gust.modulate.a = 1.0
	set_papi(2, 540.0, true, true)   # the big PAPI is drawn for real too
	set_streak(7, true)               # ... and a high streak (label, glow)
	_burst.show_all()
	_live.visible = true
	_bank_icon.visible = true
	_cr_sig.visible = true
	_slip_seal.visible = true
	_lost_seal.visible = true
	_lost_label.text = "POT LOST  -0123456789"

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
	_burst.clear()
	_lost_seal.visible = false
	_bank_icon.visible = false
	_cr_sig.visible = false
	_slip_seal.visible = false
	hide_logbook()
	hide_hangar()
	hide_career()
	hide_certificate()
	hide_choice()
	hide_pause()
	_pause_btn.visible = false
	hide_ad()
	_set_overlay(false)
	clear_popup()
	_gust.modulate.a = 0.0
