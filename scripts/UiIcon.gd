class_name UiIcon
extends Control
## A small control that draws one Icons glyph (redrawn only when the id / colour / size changes).

var glyph := "":
	set(v):
		if v != glyph:
			glyph = v
			queue_redraw()
var tint := Color.WHITE:
	set(v):
		if v != tint:
			tint = v
			queue_redraw()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	if glyph == "":
		return
	var r := minf(size.x, size.y) * 0.5
	Icons.glyph(self, glyph, size * 0.5, r * 0.82, tint)
