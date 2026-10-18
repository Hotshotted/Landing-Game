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
	_gust = _label(36, HORIZONTAL_ALIGNMENT_CENTER)
	_gust.modulate = Color(1, 0.9, 0.4, 0)
	_gust.text = "GUST!"
	_place(_gust, 0.5, 0, -270, 118, 540, 44)
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
	_place(_hint, 0.5, 1, -440, -330, 880, 150)
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
	# menu / game-over overlay
	_overlay = ColorRect.new()
	_overlay.color = Color(0.05, 0.08, 0.14, 0.62)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_ov_title = _label(150, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_ov_title, 0, 0.18, 0, 0, 1080, 190)
	_ov_title.anchor_right = 1.0
	_ov_title.offset_right = 0
	_ov_body = _label(46, HORIZONTAL_ALIGNMENT_CENTER)
	_ov_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_place(_ov_body, 0.5, 0.18, -420, 220, 840, 600)
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
	move_child(_stamp, get_child_count() - 1)

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

func set_strikes(n: int) -> void:
	for i in _strikes.size():
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

func flash_gust() -> void:
	_gust.modulate.a = 1.0

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
	_speed_bar.color = Color(1, 0.35, 0.3) if s < Tuning.stall_speed + 0.04 else Color(0.5, 0.95, 0.6)
	_stall_mark.offset_left = -300.0 + 280.0 * clampf(Tuning.stall_speed / 1.3, 0.0, 1.0)
	_stall_mark.offset_right = _stall_mark.offset_left + 4.0

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

func clear_popup() -> void:
	_pop_t = 99.0
	_pop_title.modulate.a = 0.0
	_pop_sub.modulate.a = 0.0

# ---------- overlay / fade ----------

func show_menu(best: int) -> void:
	_set_overlay(true)
	_ov_title.text = "GREASER"
	_ov_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_ov_body.text = "Land it soft.\n\nDrag up / down to pitch the nose.\nFlare just before touchdown - too early and you float then drop, too late and you slam in.\n\nTouch down on the aim markers.\nThree crashes end the run." + (("\n\nBest: %d" % best) if best > 0 else "")
	_ov_prompt.text = "TAP TO START"

func show_over(total: int, best: int, landings: int, new_best: bool) -> void:
	_set_overlay(true)
	_ov_title.text = "RUN OVER"
	_ov_title.add_theme_color_override("font_color", Color(1.0, 0.4, 0.35))
	_ov_body.text = "Score  %d\nLandings  %d\n%s" % [total, landings, "NEW BEST!" if new_best else "Best  %d" % best]
	_ov_prompt.text = "TAP TO FLY AGAIN"

func hide_overlay() -> void:
	_set_overlay(false)

func _set_overlay(on: bool) -> void:
	overlay_visible = on
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

# ---------- per frame ----------

func update(delta: float) -> void:
	_t += delta
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
	_ov_title.text = "GREASER"
	_ov_body.text = "0123456789 Greaser! Smooth Good Firm Hard CRASH Off the runway! Hit the trees!"
	_ov_prompt.text = "TAP"
	if not DebugFlags.off("popup"):
		_pop_title.text = "Greaser!"
		_pop_sub.text = "Sink 0.5   Aim +2   No bounce   +96"
		_pop_title.modulate.a = 1.0
		_pop_sub.modulate.a = 1.0
	_gust.modulate.a = 1.0

func prewarm_popups() -> void:
	for g in Grading.NAMES:
		_pop_title.text = g
	_pop_title.text = "Greaser!"

func end_prewarm() -> void:
	_splash.visible = false
	_set_overlay(false)
	clear_popup()
	_gust.modulate.a = 0.0
