class_name UiButton
extends Control
## The one button of the style guide (docs/style.md): primary (green, a chunky lip you press into), gold (rewards, the pot),
## danger (red), secondary (dark card with a light border), ghost (a translucent round chip, icon only). Every kind has a
## normal, pressed and disabled look. Pressing squashes the face and releasing bounces it back; the press plays the shared
## tap sound and a light haptic through `on_down`. Everything is drawn here, so a button is one node.

signal pressed
signal pressed_down

## Set once by Main: called whenever a finger goes down on an enabled button (sound + light haptic).
static var on_down := Callable()
static var on_up := Callable()

var kind := "secondary":
	set(v):
		kind = v
		queue_redraw()
var text := "":
	set(v):
		text = v
		queue_redraw()
var sub := "":                     # a second, smaller line (an amount, a price)
	set(v):
		sub = v
		queue_redraw()
var icon := "":
	set(v):
		icon = v
		queue_redraw()
var disabled := false:
	set(v):
		disabled = v
		if v:
			_down = false
		queue_redraw()
var accent := false:               # selected / affordable: a green fill
	set(v):
		accent = v
		queue_redraw()
var font_px := Style.SZ_S:
	set(v):
		font_px = v
		queue_redraw()
var icon_color := Color.WHITE
var press_amount := 0.0            # 0 = up .. 1 = fully pressed (animated)
var bounce := 0.0                  # the release overshoot (a damped spring around 0)
var _bounce_v := 0.0
var _down := false
var _pop_t := 99.0                 # seconds since the button popped in (ease-out-back)
var _pop_delay := 0.0
var _animating := false

static var _boxes := {}            # cached style boxes, shared by every button

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5
		queue_redraw()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			_down = false
			press_amount = 0.0

## Pop in (scale + fade, ease-out-back) after `delay` seconds: used for staggered entrances.
func pop_in(delay: float = 0.0) -> void:
	_pop_t = -delay
	_pop_delay = delay
	_animating = true
	set_process(true)
	scale = Vector2.ONE * 0.8
	modulate.a = 0.0

func is_down() -> bool:
	return _down

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			accept_event()                    # (a disabled button swallows the tap: it never reaches the game)
			if disabled:
				return
			_down = true
			pressed_down.emit()
			if on_down.is_valid():
				on_down.call(kind)
			_start_anim()
		elif _down:
			accept_event()
			_down = false
			var inside := Rect2(Vector2.ZERO, size).has_point(event.position)
			_bounce_v = 9.0
			_start_anim()
			if on_up.is_valid() and inside:
				on_up.call(kind)
			if inside:
				pressed.emit()
	elif event is InputEventMouseMotion and _down:
		if not Rect2(Vector2.ZERO, size).grow(30.0).has_point(event.position):
			_down = false
			_start_anim()

func _start_anim() -> void:
	_animating = true
	set_process(true)

func _process(delta: float) -> void:
	var busy := false
	var target := 1.0 if _down else 0.0
	press_amount = move_toward(press_amount, target, delta / Style.T_FAST)
	if press_amount != target:
		busy = true
	# the release bounce: a damped spring
	if absf(bounce) > 0.002 or absf(_bounce_v) > 0.02:
		_bounce_v += (-170.0 * bounce - 14.0 * _bounce_v) * delta
		bounce += _bounce_v * delta
		busy = true
	else:
		bounce = 0.0
		_bounce_v = 0.0
	if _pop_t < 1.0:
		_pop_t += delta / Style.T_BASE
		var k := Style.ease_out_back(clampf(_pop_t, 0.0, 1.0)) if _pop_t > 0.0 else 0.0
		modulate.a = clampf(_pop_t * 4.0, 0.0, 1.0) if _pop_t > 0.0 else 0.0
		scale = Vector2.ONE * (0.8 + 0.2 * k)
		busy = true
	elif scale != Vector2.ONE and not _down and absf(bounce) <= 0.002:
		scale = Vector2.ONE
	if _pop_t >= 1.0 and modulate.a < 1.0:
		modulate.a = 1.0
	queue_redraw()
	if not busy:
		_animating = false
		set_process(false)

# ---------- drawing ----------

static func _box(key: String, fill: Color, border: Color, radius: int, border_w: int, shadow: bool) -> StyleBoxFlat:
	if not _boxes.has(key):
		_boxes[key] = Style.box(fill, border, radius, border_w, shadow)
	return _boxes[key]

func _colors() -> Array:
	# [face, lip, border, text]
	if disabled:
		return [Color(Style.SURFACE_DARK_2, 0.55), Color(0, 0, 0, 0), Color(Style.LINE, 0.25), Style.TEXT_QUIET]
	match kind:
		"primary":
			return [Style.SUCCESS, Style.SUCCESS_DARK, Color(1, 1, 1, 0.75), Style.TEXT]
		"gold":
			return [Style.ACCENT, Style.ACCENT_DARK, Color(1, 1, 1, 0.75), Style.TEXT_ON_LIGHT]
		"danger":
			return [Style.DANGER, Style.DANGER_DARK, Color(1, 1, 1, 0.7), Style.TEXT]
		"ghost":
			return [Color(Style.SURFACE_DARK, 0.62), Color(0, 0, 0, 0), Color(Style.LINE, 0.6), Style.TEXT]
	if accent:
		return [Style.SUCCESS_DARK, Color(0, 0, 0, 0), Color(Style.SUCCESS, 0.9), Style.TEXT]
	return [Style.SURFACE_DARK, Color(0, 0, 0, 0), Color(Style.LINE, 0.55), Style.TEXT]

func _draw() -> void:
	var col := _colors()
	var has_lip := (kind == "primary" or kind == "gold" or kind == "danger") and not disabled
	var lip := Style.LIP if has_lip else 0.0
	var h := size.y - lip
	var push := press_amount * (lip * 0.5 if has_lip else 2.0)
	# squash while pressed, overshoot on release
	var sq := 1.0 - 0.05 * press_amount + 0.05 * bounce
	draw_set_transform(Vector2(0, push * 0.5), 0.0, Vector2(1.0 + (1.0 - sq) * 0.5, sq))
	var radius := Style.R_L if (kind == "primary" or kind == "gold" or kind == "danger") else (Style.R_PILL if kind == "ghost" and size.x <= size.y * 1.3 else Style.R_M)
	var rect := Rect2(0, 0, size.x, h)
	if has_lip:
		draw_style_box(_box("lip%s" % kind, col[1], col[1], radius, 0, false), Rect2(0, lip, size.x, h))
	var shadow := not disabled and kind != "ghost" and not has_lip
	var bw := 5 if has_lip else 3
	draw_style_box(_box("%s_%s_%s_%d" % [kind, str(disabled), str(accent), radius], col[0], col[2], radius, bw, shadow), Rect2(0, push, size.x, h))
	if not disabled:
		draw_style_box(_sheen(radius), Rect2(bw, push + bw, size.x - bw * 2, h * 0.42))
	var cy := push + h * 0.5
	var tcol: Color = col[3]
	var has_text := text != ""
	var f := Style.font_for(text, font_px)
	var isz := font_px * 0.55
	if has_text:
		var lines := text.split("\n")
		var tw := f.get_string_size(lines[0], HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x
		var total := tw + (isz * 2.6 if icon != "" else 0.0)
		var x0 := (size.x - total) * 0.5
		if icon != "":
			Icons.glyph(self, icon, Vector2(x0 + isz, cy - (font_px * 0.5 if sub != "" else 0.0) * 0.0), isz, Color(icon_color, tcol.a))
			x0 += isz * 2.6
		var ty := cy + font_px * 0.34 - (font_px * 0.45 if (sub != "" or lines.size() > 1) else 0.0)
		_text(f, lines[0], Vector2(x0, ty), font_px, tcol, tw + 4.0)
		if lines.size() > 1:
			_text(Style.font_for(lines[1], Style.SZ_S), lines[1], Vector2(0, ty + font_px * 0.95), Style.SZ_S, Style.ACCENT if kind != "gold" else Style.TEXT_ON_LIGHT, size.x, true)
		elif sub != "":
			_text(Style.font_for(sub, Style.SZ_S), sub, Vector2(0, ty + font_px * 0.95), Style.SZ_S, Style.ACCENT if kind != "gold" else Style.TEXT_ON_LIGHT, size.x, true)
	elif icon != "":
		var ir := minf(size.x, h) * 0.3
		Icons.glyph(self, icon, Vector2(size.x * 0.5, cy), ir, Color(icon_color, tcol.a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _text(f: Font, s: String, pos: Vector2, px: int, c: Color, width: float, centered: bool = false) -> void:
	var dark := Style.INK if kind != "gold" and c != Style.TEXT_ON_LIGHT else Color(1, 1, 1, 0.0)
	var al := HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	if dark.a > 0.0 and not disabled:
		draw_string_outline(f, pos, s, al, width, px, maxi(px / 8, 4), Color(dark, c.a))
	draw_string(f, pos, s, al, width, px, c)

static var _sheen_boxes := {}
static func _sheen(radius: int) -> StyleBoxFlat:
	if not _sheen_boxes.has(radius):
		_sheen_boxes[radius] = Style.sheen(maxi(radius - 4, 6), 0.16)
	return _sheen_boxes[radius]
