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
var power := 1.0        # 1 = engine running, 0 = engine out (no speed recovery, a little drag)
var sink_mult := 1.0    # multiplies the approach sink rate (an engine-out glide is steeper)
var gy := 0.0           # height of the ground under the plane (mountain slope, carrier deck, truck bed)
var ground_tilt := 0.0  # slope of that ground in degrees (the drawn plane follows it while rolling)
# handling profile (multipliers on the Tuning values; set by apply_plane)
var plane_id := 1
var p_speed := 1.0
var p_sink := 1.0
var p_lift := 1.0
var p_response := 1.0
var p_bleed := 1.0
var p_recover := 1.0
var p_stall := 1.0
var p_ge := 1.0
var p_decel := 1.0
var p_gust := 1.0
var _model_scale := 1.0
var _wobble_v := 0.0
var _pending_drag := 0.0
var _vis_pitch := 0.0
var _view_scale := 1.0   # drawn bigger when the camera is zoomed far out, so the plane stays easy to see
var _pivot: Node3D
var _prop: Node3D
var _outline: ShaderMaterial
var _body_mats: Array[StandardMaterial3D] = []    # painted with the aircraft's body colour
var _accent_mats: Array[StandardMaterial3D] = []  # ... and its accent colour
var _p_fuselage: MeshInstance3D
var _p_nose: MeshInstance3D
var _p_tail: MeshInstance3D
var _p_wing: MeshInstance3D
var _p_tailplane: MeshInstance3D
var _p_fin: MeshInstance3D
var _twin: Array[Node3D] = []      # the second pair of engines
var _prop2: Node3D
var _prop3: Node3D
var _gear: Array[Node3D] = []     # wheels and struts, hidden when the plane has floats (seaplane)
var _floats: Array[Node3D] = []
var _nav: Array[MeshInstance3D] = []   # navigation lights (shown at night)

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
	vy = -trim_sink()
	s = 1.0
	theta = 0.0
	theta_target = 0.0
	gs = air_speed()
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
	s += (Tuning.speed_recover * p_recover * power * (1.0 - s) - Tuning.speed_bleed * p_bleed * theta / 10.0 - (1.0 - power) * Tuning.engine_out_drag * (0.4 if p_recover == 0.0 else 1.0)) * h
	s = clampf(s, 0.2, 1.5)
	var s_eff := s + gust_h * Tuning.gust_airspeed_effect
	var target := -trim_sink() + Tuning.pitch_lift_gain * p_lift * theta * clampf(s_eff, 0.0, 1.2)
	target -= maxf(stall_speed() - s_eff, 0.0) * Tuning.stall_sink_gain
	var agl := y - gy
	if agl < Tuning.ground_effect_height:
		target += Tuning.ground_effect_lift * p_ge * (1.0 - maxf(agl, 0.0) / Tuning.ground_effect_height)
	target += gust_v
	if y >= Tuning.max_altitude:
		target = minf(target, -1.0)
	vy += (target - vy) * (1.0 - exp(-h / maxf(Tuning.response_time * p_response, 0.01)))
	y += vy * h
	gs = maxf(air_speed() * s - head, 4.0)
	x += gs * h
	_wobble_v += (-60.0 * wobble - 6.0 * _wobble_v) * h
	wobble += _wobble_v * h

## Wheels down: stop sinking and start rolling.
func land() -> void:
	on_ground = true
	vy = 0.0
	y = gy

## Bounce: rebound upward with `v`; the plane is airborne again.
func bounce(v: float) -> void:
	on_ground = false
	vy = v
	y = gy + 0.02
	s = maxf(s, 0.8)    # the rebound keeps its speed

## One rolling sub-step with braking `decel`.
func step_ground(h: float, decel: float, floor_speed: float = 0.0) -> void:
	gs = maxf(gs - decel * h, floor_speed)   # (a moving deck / truck carries the plane along: it never stops below the deck speed)
	x += gs * h
	_wobble_v += (-60.0 * wobble - 6.0 * _wobble_v) * h
	wobble += _wobble_v * h

## A gust kicks the nose (called by Main when a gust starts).
func kick(sign_dir: float) -> void:
	_wobble_v += sign_dir * Tuning.gust_wobble * 6.0

## Choose the aircraft: its handling profile and its model.
func apply_plane(id: int) -> void:
	plane_id = clampi(id, 0, Planes.COUNT - 1)
	var pr: Dictionary = Planes.profile(plane_id)
	p_speed = pr["speed"]
	p_sink = pr["sink"]
	p_lift = pr["lift"]
	p_response = pr["response"]
	p_bleed = pr["bleed"]
	p_recover = pr["recover"]
	p_stall = pr["stall"]
	p_ge = pr["ge"]
	p_decel = pr["decel"]
	p_gust = pr["gust"]
	_model_scale = pr["scale"]
	paint(pr["body"], pr["accent"])
	# model: reset to the 172, then reshape
	_p_fuselage.scale = Vector3(5.0, 1.2, 1.2)
	_p_nose.scale = Vector3(1.4, 1.4, 1.4)
	_p_nose.position = Vector3(3.2, 0.0, 0.0)
	_p_wing.scale = Vector3(1.8, 0.18, 9.0)
	_p_tailplane.scale = Vector3(1.0, 0.14, 3.6)
	_p_fin.scale = Vector3(1.7, 1.9, 0.18)
	_prop.visible = true
	for t in _twin:
		t.visible = false
	match int(pr["kind"]):
		2:   # twin: wider wing, two engines (the nose engine goes)
			_p_wing.scale = Vector3(2.0, 0.2, 11.0)
			_prop.visible = false
			for t in _twin:
				t.visible = true
			_p_nose.scale = Vector3(1.5, 1.3, 1.3)
		3:   # glider: long thin wing, slim fuselage, no propeller
			_p_wing.scale = Vector3(1.3, 0.14, 18.0)
			_p_fuselage.scale = Vector3(5.0, 0.9, 0.9)
			_p_nose.scale = Vector3(1.2, 1.0, 1.0)
			_p_tailplane.scale = Vector3(0.9, 0.12, 4.4)
			_prop.visible = false
		4:   # jet: short stubby wing, long pointed nose, big fin, no propeller
			_p_wing.scale = Vector3(2.4, 0.14, 6.4)
			_p_fuselage.scale = Vector3(5.6, 1.1, 1.1)
			_p_nose.scale = Vector3(2.0, 1.1, 1.1)
			_p_nose.position = Vector3(3.6, 0.0, 0.0)
			_p_fin.scale = Vector3(2.2, 2.4, 0.2)
			_prop.visible = false
	update_visual(0.0)

## Repaint: `body` is the fuselage colour, `accent` the nose / wings / tail (cosmetic paint schemes use this too).
func paint(body: Color, accent: Color) -> void:
	for m in _body_mats:
		m.albedo_color = body
	for m in _accent_mats:
		m.albedo_color = accent

## Seaplane: floats instead of wheels.
func set_floats(on: bool) -> void:
	for g in _gear:
		g.visible = not on
	for f in _floats:
		f.visible = on

## Night: light the navigation lights.
func set_night(on: bool) -> void:
	for n in _nav:
		n.visible = on

## The approach sink rate, airspeed, stall speed (as a fraction of the approach speed) and pitch lift for this plane.
func trim_sink() -> float:
	return Tuning.trim_sink * sink_mult * p_sink

func air_speed() -> float:
	return Tuning.approach_speed * p_speed

func stall_speed() -> float:
	return Tuning.stall_speed * p_stall

func lift_gain() -> float:
	return Tuning.pitch_lift_gain * p_lift

## Height above the ground under the plane.
func agl() -> float:
	return y - gy

## Draw the plane larger (and its outline thicker) the further the camera is zoomed out; collision is unaffected.
func set_view_scale(view_w: float) -> void:
	_view_scale = clampf(view_w / 108.0, 1.0, 6.0)
	_outline.set_shader_parameter("thickness", Tuning.outline_thickness * clampf(view_w / 54.0, 1.0, 8.0))

## Per frame: place the model and set the drawn attitude.
func update_visual(dt: float) -> void:
	var goal := Tuning.pitch_visual_offset + theta * Tuning.pitch_visual_scale
	if on_ground:
		_vis_pitch = move_toward(_vis_pitch, ground_tilt, Tuning.nose_settle_rate * dt)
		_pivot.rotation.z = deg_to_rad(_vis_pitch + wobble * 0.3)
	else:
		_vis_pitch = lerpf(_vis_pitch, goal, 1.0 - exp(-10.0 * dt))
		_pivot.rotation.z = deg_to_rad(_vis_pitch + wobble)
	var sc := _view_scale * _model_scale
	_pivot.scale = Vector3.ONE * sc
	_pivot.position = Vector3(x, y + GEAR_H * sc, 0.0)   # (the tyres stay on the ground however big it is drawn)
	if power > 0.0:
		_prop.rotation.x += 45.0 * dt
		_prop2.rotation.x += 45.0 * dt
		_prop3.rotation.x -= 45.0 * dt

# ---------- model ----------

func _build_model() -> void:
	var white := Color(0.96, 0.94, 0.88)
	var red := Color(0.86, 0.2, 0.18)
	var dark := Color(0.16, 0.16, 0.18)
	_p_fuselage = _part(BoxMesh.new(), Vector3(5.0, 1.2, 1.2), Vector3(0.0, 0.0, 0.0), white, Vector3.ZERO, "body")               # fuselage
	_p_nose = _part(_cone(), Vector3(1.4, 1.4, 1.4), Vector3(3.2, 0.0, 0.0), red, Vector3(0, 0, -90), "accent")      # nose (apex +x)
	_p_tail = _part(_cone(), Vector3(1.2, 1.2, 1.2), Vector3(-3.1, 0.0, 0.0), white, Vector3(0, 0, 90), "body")    # tail cone (apex -x)
	_p_wing = _part(BoxMesh.new(), Vector3(1.8, 0.18, 9.0), Vector3(0.3, -0.25, 0.0), red, Vector3.ZERO, "accent")               # wing
	_p_tailplane = _part(BoxMesh.new(), Vector3(1.0, 0.14, 3.6), Vector3(-3.5, 0.35, 0.0), red, Vector3.ZERO, "accent")               # tailplane
	var fin := PrismMesh.new()
	_p_fin = _part(fin, Vector3(1.7, 1.9, 0.18), Vector3(-3.5, 1.4, 0.0), red, Vector3.ZERO, "accent")                          # fin
	_part(BoxMesh.new(), Vector3(1.3, 0.55, 1.0), Vector3(0.9, 0.85, 0.0), Color(0.55, 0.8, 0.95)) # canopy
	_gear.append(_part(BoxMesh.new(), Vector3(0.14, 0.9, 0.14), Vector3(0.5, -0.85, 0.5), dark))             # main gear struts
	_gear.append(_part(BoxMesh.new(), Vector3(0.14, 0.9, 0.14), Vector3(0.5, -0.85, -0.5), dark))
	_gear.append(_part(_wheel(), Vector3(0.76, 0.2, 0.76), Vector3(0.5, -1.32, 0.5), dark, Vector3(90, 0, 0)))
	_gear.append(_part(_wheel(), Vector3(0.76, 0.2, 0.76), Vector3(0.5, -1.32, -0.5), dark, Vector3(90, 0, 0)))
	_gear.append(_part(BoxMesh.new(), Vector3(0.12, 0.8, 0.12), Vector3(2.2, -0.8, 0.0), dark))              # nose gear
	_gear.append(_part(_wheel(), Vector3(0.6, 0.18, 0.6), Vector3(2.2, -1.4, 0.0), dark, Vector3(90, 0, 0)))
	# floats (seaplane): two long pontoons on struts, hidden unless the scenario uses them
	for side in [-1.0, 1.0]:
		var pont := _part(BoxMesh.new(), Vector3(4.6, 0.5, 0.55), Vector3(0.6, -1.45, side * 1.2), red)
		var strut := _part(BoxMesh.new(), Vector3(0.14, 1.0, 0.14), Vector3(0.6, -0.85, side * 1.2), dark)
		pont.visible = false
		strut.visible = false
		_floats.append(pont)
		_floats.append(strut)
	# navigation lights on the wing tips and tail (lit at night)
	for nl in [[Vector3(0.3, -0.2, 4.4), Color(0.2, 1.0, 0.3)], [Vector3(0.3, -0.2, -4.4), Color(1.0, 0.15, 0.1)], [Vector3(-3.9, 0.9, 0.0), Color(1, 1, 1)]]:
		var n := MeshInstance3D.new()
		n.mesh = BoxMesh.new()
		var nm := StandardMaterial3D.new()
		nm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		nm.albedo_color = nl[1]
		n.material_override = nm
		n.position = nl[0]
		n.scale = Vector3(0.45, 0.45, 0.45)
		n.visible = false
		_pivot.add_child(n)
		_nav.append(n)
	_prop = Node3D.new()
	_prop.position = Vector3(4.0, 0.0, 0.0)
	_pivot.add_child(_prop)
	var blade := MeshInstance3D.new()
	blade.mesh = BoxMesh.new()
	blade.scale = Vector3(0.1, 2.3, 0.24)
	blade.material_override = _mat(dark)
	_prop.add_child(blade)
	# twin: two engine nacelles on the wings, each with a propeller (hidden unless the aircraft is the twin)
	for side in [-1.0, 1.0]:
		var nac := _part(BoxMesh.new(), Vector3(1.9, 0.85, 0.85), Vector3(1.2, -0.3, side * 2.6), dark)
		nac.visible = false
		_twin.append(nac)
		var pr := Node3D.new()
		pr.position = Vector3(2.3, -0.3, side * 2.6)
		_pivot.add_child(pr)
		var bl := MeshInstance3D.new()
		bl.mesh = BoxMesh.new()
		bl.scale = Vector3(0.1, 1.9, 0.22)
		bl.material_override = _mat(dark)
		pr.add_child(bl)
		pr.visible = false
		_twin.append(pr)
		if side < 0.0:
			_prop2 = pr
		else:
			_prop3 = pr

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

func _part(mesh: Mesh, size: Vector3, pos: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO, role: String = "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var pm := _mat(color)
	mi.material_override = pm
	if role == "body":
		_body_mats.append(pm)
	elif role == "accent":
		_accent_mats.append(pm)
	mi.material_overlay = _outline
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = size
	_pivot.add_child(mi)
	return mi
