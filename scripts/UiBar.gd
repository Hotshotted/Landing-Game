class_name UiBar
extends Control
## A rounded, flat bar (the airspeed track, its fill, the Vref band, the stall tick). Same `color` property as a ColorRect,
## so the HUD code that sets `.color` and the offsets keeps working; the corners and the ink border come from the style guide.

var color := Color.WHITE:
	set(v):
		color = v
		queue_redraw()
var radius := 8.0
var border := Color(0, 0, 0, 0)
var border_w := 0.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	var r := int(minf(radius, minf(size.x, size.y) * 0.5))
	sb.set_corner_radius_all(r)
	if border_w > 0.0:
		sb.set_border_width_all(int(border_w))
		sb.border_color = border
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
