class_name FogOverlay
extends CanvasLayer
## Fog / rain haze over the 3D view, below the HUD. One full-screen rect with a shader; only uniforms change.

var _rect: ColorRect
var _mat: ShaderMaterial

func _ready() -> void:
	layer = 2
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/fog.gdshader")
	_rect.material = _mat
	_rect.visible = false
	add_child(_rect)

## Show the haze: `plane_px` = the plane's screen x, `px_per_unit` = screen pixels per world unit.
func set_fog(on: bool, plane_px: float, px_per_unit: float, view_px: float, vis_start: float, vis_end: float, color: Color, strength: float, base_haze: float = 0.0) -> void:
	_rect.visible = on
	if not on:
		return
	_mat.set_shader_parameter("plane_px", plane_px)
	_mat.set_shader_parameter("px_per_unit", px_per_unit)
	_mat.set_shader_parameter("view_px", view_px)
	_mat.set_shader_parameter("vis_start", vis_start)
	_mat.set_shader_parameter("vis_end", vis_end)
	_mat.set_shader_parameter("fog_color", color)
	_mat.set_shader_parameter("strength", strength)
	_mat.set_shader_parameter("base_haze", base_haze)

func is_on() -> bool:
	return _rect.visible
