class_name Aircraft
extends Node3D
## The plane, seen from the side, flying toward +x. A tiny point-mass flight model:
##   * pitch (`theta`, degrees, 0 = approach attitude) follows RELATIVE finger drag (1:1, up = nose up);
##   * the sink rate follows what the nose asks for: nose down sinks faster, nose up sinks less;
##   * nose up also bleeds airspeed; below the stall speed the sink target grows fast. So flaring too
##     early makes the plane float, run out of speed and drop hard, flaring too late slams it in.
## Everything is built once in _ready (a handful of low-poly primitives with black outlines).

const GEAR_H := 1.7     # tyre bottom is this far below the pivot (the centre of gravity)

var x := 0.0
var y := 0.0            # height of the tyres above the ground
var vy := 0.0           # vertical speed (negative = sinking)
var s := 1.0            # airspeed as a fraction of the approach speed
var theta := 0.0        # pitch, degrees
var theta_target := 0.0 # where the finger has put the nose
var gs := 0.0           # ground speed
var on_ground := false
var touching := false   # finger down?
var wobble := 0.0       # gust kick on the drawn nose (degrees)
var _wobble_v := 0.0
var _pending_drag := 0.0
var _vis_pitch := 0.0
var _pivot: Node3D
var _prop: Node3D
var _outline: ShaderMaterial

func _ready() -> void:
	_outline = ShaderMaterial.new()
	_outline.shader = preload("res://shaders/outline.gdshader")
	_outline.set_shader_parameter("thickness", Tuning.outline_thickness)
	_pivot = Node3D.new()
	add_child(_pivot)
	_build_model()
	reset(0.0, 30.0)

func _input(event: InputEvent) -> void:
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and TunePanel.button_hit(event.position):
		return   # that touch is for the tuning panel's TUNE button
	if event is InputEventScreenTouch:
		touching = event.pressed
	elif event is InputEventScreenDrag:
		touching = true
		_pending_drag += event.relative.y

## Add finger movement (viewport pixels, down = positive). Tests use this too.
func add_drag(dy: float) -> void:
	_pending_drag += dy

func clear_input() -> void:
	_pending_drag = 0.0

func reset(start_x: float, start_y: float) -> void:
	x = start_x
	y = start_y
	vy = -Tuning.trim_sink
	s = 1.0
	theta = 0.0
	theta_target = 0.0
	gs = Tuning.approach_speed
	on_ground = false
	wobble = 0.0
	_wobble_v = 0.0
	_pending_drag = 0.0
	_vis_pitch = Tuning.pitch_visual_offset
	visible = true
	update_visual(0.0)

## Once per frame: turn the finger's drag into where the nose should be.
func consume_input(dt: float) -> void:
	if _pending_drag != 0.0:
		theta_target -= _pending_drag * Tuning.pitch_per_pixel * Tuning.sensitivity
		_pending_drag = 0.0
	elif not touching:
		theta_target = move_toward(theta_target, 0.0, Tuning.pitch_return * dt)
	theta_target = clampf(theta_target, Tuning.pitch_min, Tuning.pitch_max)

## One flight sub-step. `head` = total headwind, `gust_v` / `gust_h` = the current gust. Moves x and y.
func step_air(h: float, head: float, gust_v: float, gust_h: float) -> void:
	theta = move_toward(theta, theta_target, Tuning.pitch_rate * h)
	s += (Tuning.speed_recover * (1.0 - s) - Tuning.speed_bleed * theta / 10.0) * h
	s = clampf(s, 0.2, 1.5)
	var s_eff := s + gust_h * Tuning.gust_airspeed_effect
	var target := -Tuning.trim_sink + Tuning.pitch_lift_gain * theta * clampf(s_eff, 0.0, 1.2)
	target -= maxf(Tuning.stall_speed - s_eff, 0.0) * Tuning.stall_sink_gain
	if y < Tuning.ground_effect_height:
		target += Tuning.ground_effect_lift * (1.0 - maxf(y, 0.0) / Tuning.ground_effect_height)
	target += gust_v
	if y >= Tuning.max_altitude:
		target = minf(target, -1.0)
	vy += (target - vy) * (1.0 - exp(-h / maxf(Tuning.response_time, 0.01)))
	y += vy * h
	gs = maxf(Tuning.approach_speed * s - head, 4.0)
	x += gs * h
	_wobble_v += (-60.0 * wobble - 6.0 * _wobble_v) * h
	wobble += _wobble_v * h

## Wheels down: stop sinking and start rolling.
func land() -> void:
	on_ground = true
	vy = 0.0
	y = 0.0

## Bounce: rebound upward with `v`; the plane is airborne again.
func bounce(v: float) -> void:
	on_ground = false
	vy = v
	y = 0.02
	s = maxf(s, 0.8)    # the rebound keeps its speed

## One rolling sub-step with braking `decel`.
func step_ground(h: float, decel: float) -> void:
	gs = maxf(gs - decel * h, 0.0)
	x += gs * h
	_wobble_v += (-60.0 * wobble - 6.0 * _wobble_v) * h
	wobble += _wobble_v * h

## A gust kicks the nose (called by Main when a gust starts).
func kick(sign_dir: float) -> void:
	_wobble_v += sign_dir * Tuning.gust_wobble * 6.0

## Per frame: place the model and set the drawn attitude.
func update_visual(dt: float) -> void:
	var goal := Tuning.pitch_visual_offset + theta * Tuning.pitch_visual_scale
	if on_ground:
		_vis_pitch = move_toward(_vis_pitch, 0.0, Tuning.nose_settle_rate * dt)
		_pivot.rotation.z = deg_to_rad(_vis_pitch + wobble * 0.3)
	else:
		_vis_pitch = lerpf(_vis_pitch, goal, 1.0 - exp(-10.0 * dt))
		_pivot.rotation.z = deg_to_rad(_vis_pitch + wobble)
	_pivot.position = Vector3(x, y + GEAR_H, 0.0)
	_prop.rotation.x += 45.0 * dt

# ---------- model ----------

func _build_model() -> void:
	var white := Color(0.96, 0.94, 0.88)
	var red := Color(0.86, 0.2, 0.18)
	var dark := Color(0.16, 0.16, 0.18)
	_part(BoxMesh.new(), Vector3(5.0, 1.2, 1.2), Vector3(0.0, 0.0, 0.0), white)               # fuselage
	_part(_cone(), Vector3(1.4, 1.4, 1.4), Vector3(3.2, 0.0, 0.0), red, Vector3(0, 0, -90))      # nose (apex +x)
	_part(_cone(), Vector3(1.2, 1.2, 1.2), Vector3(-3.1, 0.0, 0.0), white, Vector3(0, 0, 90))    # tail cone (apex -x)
	_part(BoxMesh.new(), Vector3(1.8, 0.18, 9.0), Vector3(0.3, -0.25, 0.0), red)               # wing
	_part(BoxMesh.new(), Vector3(1.0, 0.14, 3.6), Vector3(-3.5, 0.35, 0.0), red)               # tailplane
	var fin := PrismMesh.new()
	_part(fin, Vector3(1.7, 1.9, 0.18), Vector3(-3.5, 1.4, 0.0), red)                          # fin
	_part(BoxMesh.new(), Vector3(1.3, 0.55, 1.0), Vector3(0.9, 0.85, 0.0), Color(0.55, 0.8, 0.95)) # canopy
	_part(BoxMesh.new(), Vector3(0.14, 0.9, 0.14), Vector3(0.5, -0.85, 0.5), dark)             # main gear struts
	_part(BoxMesh.new(), Vector3(0.14, 0.9, 0.14), Vector3(0.5, -0.85, -0.5), dark)
	_part(_wheel(), Vector3(0.76, 0.2, 0.76), Vector3(0.5, -1.32, 0.5), dark, Vector3(90, 0, 0))
	_part(_wheel(), Vector3(0.76, 0.2, 0.76), Vector3(0.5, -1.32, -0.5), dark, Vector3(90, 0, 0))
	_part(BoxMesh.new(), Vector3(0.12, 0.8, 0.12), Vector3(2.2, -0.8, 0.0), dark)              # nose gear
	_part(_wheel(), Vector3(0.6, 0.18, 0.6), Vector3(2.2, -1.4, 0.0), dark, Vector3(90, 0, 0))
	_prop = Node3D.new()
	_prop.position = Vector3(4.0, 0.0, 0.0)
	_pivot.add_child(_prop)
	var blade := MeshInstance3D.new()
	blade.mesh = BoxMesh.new()
	blade.scale = Vector3(0.1, 2.3, 0.24)
	blade.material_override = _mat(dark)
	_prop.add_child(blade)

func _cone() -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = 8
	c.rings = 1
	return c

func _wheel() -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.5
	c.height = 1.0
	c.radial_segments = 8
	c.rings = 1
	return c

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func _part(mesh: Mesh, size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.material_overlay = _outline
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = size
	_pivot.add_child(mi)
	return mi
