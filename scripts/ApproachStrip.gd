class_name ApproachStrip
extends Control
## The approach profile: a slim strip like the profile view of an approach plate, across the top of the screen. It shows the
## WHOLE approach from the start to touchdown and never moves: the terrain (the mountain's slope, the deck), the runway with its
## threshold, aim point and end, the 3-degree glidepath, every obstacle (trees, the hill) at its true distance and height, and
## the plane as a dot moving along it in real time. The vertical scale is exaggerated (like a plate) so a 6-unit tree is readable.
## Built once; `set_profile` is called when a round is laid out, `set_plane` every frame.

var x0 := 0.0                  # world x at the strip's left edge (the start of the approach) ...
var x1 := 100.0                # ... and at its right edge (just past the runway end)
var y_min := 0.0
var y_max := 10.0
var thr := 0.0
var rwy_end := 0.0
var aim_x := 0.0
var path_slope := 0.06         # the glidepath: descent per unit of run, through the aim point
var aim_y := 0.0
var terrain := PackedFloat32Array()      # the ground and obstacle outline, sampled across [x0, x1]
var tops: Array[Vector2] = []            # the top of each obstacle (world x, height)
var plane := Vector2.ZERO
var _plane_set := false

const PAD_X := 18.0
const PAD_TOP := 10.0
const PAD_BOTTOM := 16.0
const SAMPLES := 96

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## Lay the profile out for a round from the airfield (its obstacles, runway and path) and where the plane starts.
func set_profile(af: Airfield, start_x: float, start_y: float) -> void:
	x0 = start_x - 6.0
	x1 = af.rwy_end + 14.0
	thr = af.thr
	rwy_end = af.rwy_end
	aim_x = af.aim_x
	path_slope = af.papi_slope
	aim_y = af.ground_y(af.aim_x)
	terrain.resize(SAMPLES)
	var top := maxf(start_y, aim_y + (aim_x - x0) * path_slope)
	var bottom := 0.0
	for i in SAMPLES:
		var x := x0 + (x1 - x0) * float(i) / float(SAMPLES - 1)
		var h := maxf(af.ground_y(x), af.height_at(x))
		terrain[i] = h
		top = maxf(top, h)
		bottom = minf(bottom, af.ground_y(x))
	tops.clear()
	for i in af.tree_count:
		tops.append(Vector2(af.tree_x[i], af.tree_h[i]))
		top = maxf(top, af.tree_h[i])
	if af.hill_on:
		tops.append(Vector2(af.hill_x, af.hill_h))
	y_min = bottom - 0.4
	y_max = top + 1.5
	_plane_set = false
	queue_redraw()

func set_plane(x: float, y: float, thr_now: float, end_now: float) -> void:
	plane = Vector2(x, y)
	thr = thr_now          # (a moving deck carries its runway along)
	rwy_end = end_now
	_plane_set = true
	queue_redraw()

func _map(x: float, y: float) -> Vector2:
	var fx := clampf((x - x0) / maxf(x1 - x0, 1.0), -0.02, 1.02)
	var fy := clampf((y - y_min) / maxf(y_max - y_min, 1.0), -0.05, 1.05)
	return Vector2(PAD_X + fx * (size.x - 2.0 * PAD_X), size.y - PAD_BOTTOM - fy * (size.y - PAD_TOP - PAD_BOTTOM))

func _draw() -> void:
	draw_style_box(Style.box(Color(Style.SURFACE_DARK, 0.78), Color(Style.LINE, 0.55), Style.R_M, 3), Rect2(Vector2.ZERO, size))
	if terrain.size() < 2:
		return
	var floor_y := _map(x0, y_min).y
	# the terrain and the obstacles on it: one filled outline
	var poly := PackedVector2Array()
	poly.append(Vector2(_map(x0, 0.0).x, floor_y + 2.0))
	for i in SAMPLES:
		poly.append(_map(x0 + (x1 - x0) * float(i) / float(SAMPLES - 1), terrain[i]))
	poly.append(Vector2(_map(x1, 0.0).x, floor_y + 2.0))
	draw_colored_polygon(poly, Color("2f6a3e"))
	var line := PackedVector2Array()
	for i in range(1, poly.size() - 1):
		line.append(poly[i])
	draw_polyline(line, Color("7fd89a"), 2.5, true)
	# the glidepath: a dashed gold line from the start down to the aim point, with its 3-degree label
	var a := _map(x0, aim_y + (aim_x - x0) * path_slope)
	var b := _map(aim_x, aim_y)
	draw_dashed_line(a, b, Style.ACCENT, 3.0, 9.0)
	draw_string(Style.text(), a + Vector2(8.0, -6.0), "3°", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Style.ACCENT)
	# the runway: a pale slab on the ground, with its threshold (white), aim point (orange) and end (red)
	var r0 := _map(thr, aim_y)
	var r1 := _map(rwy_end, aim_y)
	draw_line(r0 + Vector2(0, 1), r1 + Vector2(0, 1), Style.INK, 11.0)
	draw_line(r0 + Vector2(0, 1), r1 + Vector2(0, 1), Color("c5cfdc"), 7.0)
	draw_line(r0 + Vector2(0, -9), r0 + Vector2(0, 6), Color.WHITE, 3.0)
	draw_line(r1 + Vector2(0, -9), r1 + Vector2(0, 6), Style.DANGER, 3.0)
	var am := _map(aim_x, aim_y)
	draw_colored_polygon(PackedVector2Array([am + Vector2(0, -9), am + Vector2(6, -3), am + Vector2(0, 3), am + Vector2(-6, -3)]), Style.WARNING)
	draw_string(Style.text(), r0 + Vector2(-2.0, -12.0), "RWY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Style.TEXT_SOFT)
	# every obstacle: a marker at its top
	for t in tops:
		var tp := _map(t.x, t.y)
		draw_circle(tp, 5.5, Style.INK)
		draw_circle(tp, 3.8, Style.DANGER)
	# the plane
	if _plane_set:
		var pp := _map(plane.x, plane.y)
		draw_line(pp, Vector2(pp.x, _map(plane.x, maxf(float(terrain[clampi(int((plane.x - x0) / maxf(x1 - x0, 1.0) * float(SAMPLES - 1)), 0, SAMPLES - 1)]), 0.0)).y), Color(1, 1, 1, 0.28), 2.0)
		draw_circle(pp, 10.0, Style.INK)
		draw_circle(pp, 7.5, Color.WHITE)
