class_name MenuScene
extends Control
## The living menu: behind the buttons a small airfield and the chosen aircraft flying its pattern, landing, rolling out and
## taxiing back, over and over. Drawn in one control from the Icons glyphs; the timeline is a pure function of time.

const LOOP := 21.0
const RW_Y := 1846.0            # runway surface (viewport px)
const ALT_Y := 1382.0           # pattern altitude
const RW_X0 := 130.0
const RW_X1 := 950.0

var plane_glyph := "cub":
	set(v):
		plane_glyph = v
		queue_redraw()
var _t := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_t = fmod(_t + delta, LOOP)
	queue_redraw()

## Position (x, y), a pitch in radians, a facing (+1 right, -1 left) and a size factor (far legs are smaller) at time t.
static func pose(t: float) -> Dictionary:
	var x := 0.0
	var y := RW_Y
	var pitch := 0.0
	var face := 1.0
	var s := 1.0
	if t < 2.6:                                     # take-off roll
		var k := t / 2.6
		x = 250.0 + 560.0 * k * k
		y = RW_Y
	elif t < 5.6:                                   # climb out
		var k := (t - 2.6) / 3.0
		x = 810.0 + 150.0 * k
		y = lerpf(RW_Y, ALT_Y, Style.ease_out_cubic(k))
		pitch = -0.28 * (1.0 - k)
	elif t < 7.0:                                   # turn (the plane swings away from us and back)
		var k := (t - 5.6) / 1.4
		x = 960.0 + 70.0 * sin(k * PI)
		y = ALT_Y - 38.0 * k
		face = cos(k * PI)
		s = 1.0 - 0.18 * k
	elif t < 11.2:                                  # downwind, flying left, further away
		var k := (t - 7.0) / 4.2
		x = lerpf(960.0, 120.0, k)
		y = ALT_Y - 38.0
		face = -1.0
		s = 0.82
	elif t < 12.6:                                  # turn onto base / final
		var k := (t - 11.2) / 1.4
		x = 120.0 - 70.0 * sin(k * PI)
		y = lerpf(ALT_Y - 38.0, ALT_Y - 10.0, k)
		face = -cos(k * PI)
		s = 0.82 + 0.18 * k
	elif t < 16.0:                                  # final: the glide to the runway
		var k := (t - 12.6) / 3.4
		x = lerpf(120.0, 300.0 + 160.0, k)
		y = lerpf(ALT_Y - 10.0, RW_Y, k * k * 0.35 + k * 0.65)
		pitch = 0.1 * (1.0 - k) - 0.05 * k
	elif t < 18.4:                                  # roll-out
		var k := (t - 16.0) / 2.4
		x = 460.0 + 330.0 * (1.0 - pow(1.0 - k, 2.0))
		y = RW_Y
	else:                                           # taxi back to the start
		var k := clampf((t - 18.4) / 2.6, 0.0, 1.0)
		x = lerpf(790.0, 250.0, k)
		y = RW_Y
		face = -1.0
	return {"x": x, "y": y, "pitch": pitch, "face": face, "s": s}

func _draw() -> void:
	var w := size.x
	var h := size.y
	# a sheet of ground under the buttons: hills, a hangar, trees, the runway
	var ground := Color("3f7f4a")
	var hill := Color("2f6a3e")
	draw_rect(Rect2(0, 1780.0, w, h - 1780.0), ground)
	var pts := PackedVector2Array([Vector2(0, 1790), Vector2(0, 1700)])
	for i in 9:
		var xx := float(i) / 8.0 * w
		pts.append(Vector2(xx, 1700.0 - 36.0 * sin(float(i) * 1.3 + 0.6) - 18.0 * sin(float(i) * 2.9)))
	pts.append(Vector2(w, 1790))
	draw_colored_polygon(pts, hill)
	draw_rect(Rect2(RW_X0 - 30.0, 1822.0, RW_X1 - RW_X0 + 60.0, 52.0), Color("34383f"))
	for i in 12:
		draw_rect(Rect2(RW_X0 + 20.0 + float(i) * 72.0, 1846.0, 36.0, 5.0), Color(1, 1, 1, 0.9))
	# hangar + windsock + trees
	draw_rect(Rect2(960.0, 1760.0, 92.0, 62.0), Color("c8d2de"))
	draw_colored_polygon(PackedVector2Array([Vector2(954, 1762), Vector2(1006, 1730), Vector2(1058, 1762)]), Style.DANGER)
	draw_rect(Rect2(988.0, 1788.0, 36.0, 34.0), Color("4a5668"))
	draw_line(Vector2(60, 1822), Vector2(60, 1768), Style.INK, 5.0)
	var sway := sin(_t * 2.2) * 6.0
	draw_colored_polygon(PackedVector2Array([Vector2(60, 1770), Vector2(112 + sway, 1776), Vector2(112 + sway, 1790), Vector2(60, 1792)]), Style.WARNING)
	for tx in [30.0, 1030.0, 1062.0]:
		draw_rect(Rect2(tx - 5.0, 1770.0, 10.0, 22.0), Color("5a3b22"))
		draw_circle(Vector2(tx, 1756.0), 26.0, Color("287040"))
	# the aircraft: a soft shadow on the ground, the glyph with an ink outline
	var p := pose(_t)
	var px: float = p["x"]
	var py: float = p["y"]
	var sc: float = p["s"]
	var face: float = p["face"]
	var gr := clampf((RW_Y - py) / (RW_Y - ALT_Y), 0.0, 1.0)
	draw_set_transform(Vector2(px, RW_Y + 6.0), 0.0, Vector2(1.0, 1.0))
	draw_circle(Vector2.ZERO, 40.0 * (1.0 - 0.4 * gr) * sc, Color(0, 0, 0, 0.25 * (1.0 - 0.6 * gr)))
	var r := 60.0 * sc
	draw_set_transform(Vector2(px, py - r * 0.6), float(p["pitch"]) * signf(face), Vector2(face if absf(face) > 0.02 else 0.02, 1.0))
	Icons.glyph(self, plane_glyph, Vector2(3.0, 4.0), r, Style.INK)
	Icons.glyph(self, plane_glyph, Vector2.ZERO, r, Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
