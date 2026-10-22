class_name Fx
extends Node3D
## Pooled particle effects: tire smoke / dust puffs and the crash fireball. Every emitter is created
## once in _ready and re-fired (restart) - nothing is created while playing.

const SMOKE_EMITTERS := 5
const FIRE_EMITTERS := 2
const GOLD_EMITTERS := 3

var _smoke: Array[CPUParticles3D] = []
var _fire: Array[CPUParticles3D] = []
var _next_smoke := 0
var _next_fire := 0
var _gold: Array[CPUParticles3D] = []
const TIRE_EMITTERS := 3
const DEBRIS := 16
var _tire: Array[CPUParticles3D] = []
var _next_tire := 0
var _burn: CPUParticles3D                      # the smoke column over a crash
var _deb: Array[MeshInstance3D] = []
var _deb_mat: Array[StandardMaterial3D] = []
var _deb_vel := PackedVector3Array()
var _deb_spin := PackedVector3Array()
var _deb_age := PackedFloat32Array()
var _deb_ground := 0.0
var _slow := 1.0                               # slow motion on impact: 0.4 -> 1.0
var _next_gold := 0

func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	var ramp := Gradient.new()   # solid -> faded
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0)])
	ramp.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var curve := Curve.new()      # puffs grow as they drift
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 1.0))
	for i in SMOKE_EMITTERS:
		var p := CPUParticles3D.new()
		p.mesh = quad
		p.color_ramp = ramp
		p.scale_amount_curve = curve
		p.amount = Tuning.smoke_count
		p.lifetime = 1.1
		p.one_shot = true
		p.explosiveness = 0.85
		p.local_coords = false
		p.direction = Vector3(-1.0, 0.35, 0.3)
		p.spread = 40.0
		p.initial_velocity_min = 2.0
		p.initial_velocity_max = 8.0
		p.gravity = Vector3(0, 0.6, 0)
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.7
		p.emitting = false
		add_child(p)
		_smoke.append(p)
	var gquad := QuadMesh.new()
	gquad.size = Vector2(0.45, 0.45)
	var gmat := StandardMaterial3D.new()
	gmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gmat.vertex_color_use_as_albedo = true
	gmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gquad.material = gmat
	var gramp := Gradient.new()   # white-hot -> gold -> gone
	gramp.colors = PackedColorArray([Color(1, 1, 0.9, 1), Color(1, 0.85, 0.3, 1), Color(1, 0.6, 0.1, 0)])
	gramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	for i in GOLD_EMITTERS:
		var p := CPUParticles3D.new()
		p.mesh = gquad
		p.color_ramp = gramp
		p.amount = 36
		p.lifetime = 1.0
		p.one_shot = true
		p.explosiveness = 0.95
		p.local_coords = false
		p.direction = Vector3(0, 1, 0)
		p.spread = 180.0
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 9.0
		p.gravity = Vector3(0, -4.0, 0)
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		p.emitting = false
		add_child(p)
		_gold.append(p)
	var fquad := QuadMesh.new()
	fquad.size = Vector2(1.0, 1.0)
	var fmat := StandardMaterial3D.new()
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fmat.vertex_color_use_as_albedo = true
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fquad.material = fmat
	var framp := Gradient.new()   # white-hot -> orange -> black smoke -> gone
	framp.colors = PackedColorArray([Color(1, 1, 0.8, 1), Color(1, 0.55, 0.1, 1), Color(0.2, 0.2, 0.22, 0.8), Color(0.1, 0.1, 0.1, 0)])
	framp.offsets = PackedFloat32Array([0.0, 0.25, 0.65, 1.0])
	for i in FIRE_EMITTERS:
		var p := CPUParticles3D.new()
		p.mesh = fquad
		p.color_ramp = framp
		p.amount = 40
		p.lifetime = 1.4
		p.one_shot = true
		p.explosiveness = 0.95
		p.local_coords = false
		p.direction = Vector3(0, 1, 0)
		p.spread = 80.0
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 14.0
		p.gravity = Vector3(0, -6.0, 0)
		p.scale_amount_min = 1.0
		p.scale_amount_max = 3.2
		p.emitting = false
		add_child(p)
		_fire.append(p)
	_build_extra()

## Tire puffs, the burning smoke column and the debris pieces (all built once).
func _build_extra() -> void:
	var tq := QuadMesh.new()
	tq.size = Vector2(0.55, 0.55)
	var tmat := StandardMaterial3D.new()
	tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	tmat.vertex_color_use_as_albedo = true
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tq.material = tmat
	var tramp := Gradient.new()
	tramp.colors = PackedColorArray([Color(1, 1, 1, 0.85), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0)])
	tramp.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	for i in TIRE_EMITTERS:
		var p := CPUParticles3D.new()
		p.mesh = tq
		p.color_ramp = tramp
		p.amount = 22
		p.lifetime = 0.7
		p.one_shot = true
		p.explosiveness = 0.9
		p.local_coords = false
		p.direction = Vector3(-1.0, 0.12, 0.25)
		p.spread = 22.0
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 16.0
		p.gravity = Vector3(0, 0.3, 0)
		p.scale_amount_min = 0.6
		p.scale_amount_max = 1.5
		p.emitting = false
		add_child(p)
		_tire.append(p)
	var bq := QuadMesh.new()
	bq.size = Vector2(1.0, 1.0)
	var bmat := StandardMaterial3D.new()
	bmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bmat.vertex_color_use_as_albedo = true
	bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bq.material = bmat
	var bramp := Gradient.new()
	bramp.colors = PackedColorArray([Color(0.12, 0.12, 0.13, 0.9), Color(0.22, 0.22, 0.24, 0.6), Color(0.35, 0.35, 0.38, 0)])
	bramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var bcurve := Curve.new()
	bcurve.add_point(Vector2(0.0, 0.4))
	bcurve.add_point(Vector2(1.0, 1.0))
	_burn = CPUParticles3D.new()
	_burn.mesh = bq
	_burn.color_ramp = bramp
	_burn.scale_amount_curve = bcurve
	_burn.amount = 26
	_burn.lifetime = 2.4
	_burn.one_shot = false
	_burn.explosiveness = 0.0
	_burn.local_coords = false
	_burn.direction = Vector3(0.15, 1.0, 0.1)
	_burn.spread = 14.0
	_burn.initial_velocity_min = 4.0
	_burn.initial_velocity_max = 8.0
	_burn.gravity = Vector3(0, 1.2, 0)
	_burn.scale_amount_min = 1.2
	_burn.scale_amount_max = 3.4
	_burn.emitting = false
	add_child(_burn)
	var outline := ShaderMaterial.new()
	outline.shader = preload("res://shaders/outline.gdshader")
	outline.set_shader_parameter("thickness", Tuning.outline_thickness)
	_deb_vel.resize(DEBRIS)
	_deb_spin.resize(DEBRIS)
	_deb_age.resize(DEBRIS)
	for i in DEBRIS:
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		var m := StandardMaterial3D.new()
		m.roughness = 1.0
		mi.material_override = m
		mi.material_overlay = outline
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_deb.append(mi)
		_deb_mat.append(m)
		_deb_age[i] = 99.0

## Chunks of the aircraft in its own colours thrown out of the crash, tumbling and bouncing on the ground.
func debris(pos: Vector3, body: Color, accent: Color, ground_y: float) -> void:
	_deb_ground = ground_y
	var cols: Array[Color] = [body, accent, Color(0.16, 0.16, 0.18), accent, body]
	for i in DEBRIS:
		var mi := _deb[i]
		mi.visible = true
		mi.position = pos + Vector3(float(i % 5) * 0.3 - 0.6, float(i % 3) * 0.2, 0.0)
		var k := float(i)
		mi.scale = Vector3(0.5 + fmod(k * 0.37, 1.1), 0.18 + fmod(k * 0.23, 0.35), 0.4 + fmod(k * 0.19, 0.9))
		mi.rotation = Vector3(k, k * 2.0, k * 0.5)
		_deb_mat[i].albedo_color = cols[i % cols.size()]
		var dir := -1.0 if (i % 2 == 0) else 1.0
		_deb_vel[i] = Vector3(dir * (3.0 + fmod(k * 2.7, 9.0)), 7.0 + fmod(k * 3.1, 10.0), (fmod(k * 1.7, 6.0)) - 3.0)
		_deb_spin[i] = Vector3(fmod(k * 4.3, 9.0) - 4.5, fmod(k * 3.7, 9.0) - 4.5, fmod(k * 5.1, 9.0) - 4.5)
		_deb_age[i] = 0.0
	_slow = 0.4

func _process(delta: float) -> void:
	_slow = move_toward(_slow, 1.0, delta / 1.1)
	for p in _fire:
		p.speed_scale = _slow
	_burn.speed_scale = _slow
	var dt := delta * _slow
	for i in DEBRIS:
		if _deb_age[i] >= 4.0:
			continue
		_deb_age[i] += delta
		var mi := _deb[i]
		_deb_vel[i].y -= 34.0 * dt
		mi.position += _deb_vel[i] * dt
		mi.rotation += _deb_spin[i] * dt
		if mi.position.y < _deb_ground + 0.2:
			mi.position.y = _deb_ground + 0.2
			if absf(_deb_vel[i].y) > 2.0:
				_deb_vel[i].y *= -0.35
				_deb_vel[i].x *= 0.6
				_deb_vel[i].z *= 0.6
				_deb_spin[i] *= 0.5
			else:
				_deb_vel[i] = Vector3.ZERO
				_deb_spin[i] = Vector3.ZERO
		if _deb_age[i] >= 4.0:
			mi.visible = false

## The smoke column over the wreck.
func burn(pos: Vector3) -> void:
	_burn.global_position = pos
	_burn.visible = true
	_burn.restart()
	_burn.emitting = true

## Rubber and white tyre smoke streaming back along the runway at touchdown.
func tire(pos: Vector3, power: float) -> void:
	if DebugFlags.off("smoke"):
		return
	var p := _tire[_next_tire]
	_next_tire = (_next_tire + 1) % TIRE_EMITTERS
	power = clampf(power, 0.2, 1.0)
	p.initial_velocity_max = 8.0 + 14.0 * power
	p.scale_amount_max = 1.0 + 1.0 * power
	p.global_position = pos
	p.visible = true
	p.restart()
	p.emitting = true

## The streak sparkle: a gold burst that gets bigger and hotter the higher the streak tier (0..6).
func sparkle(pos: Vector3, tier: int) -> void:
	var p := _gold[_next_gold]
	_next_gold = (_next_gold + 1) % GOLD_EMITTERS
	var t := clampi(tier, 0, 6)
	p.color = Color(1.0, 0.9 - 0.12 * float(t), 0.35 - 0.05 * float(t))
	p.initial_velocity_max = 8.0 + 2.5 * float(t)
	p.scale_amount_max = 0.8 + 0.25 * float(t)
	p.global_position = pos
	p.visible = true
	p.restart()
	p.emitting = true

## Tire smoke / dust at `pos`. `power` 0..1 scales the puff size and speed, `color` tints it.
func smoke(pos: Vector3, power: float, color: Color) -> void:
	if DebugFlags.off("smoke"):
		return
	var p := _smoke[_next_smoke]
	_next_smoke = (_next_smoke + 1) % SMOKE_EMITTERS
	if p.amount != Tuning.smoke_count:   # only touch when live-tuned (it reallocates buffers)
		p.amount = Tuning.smoke_count
	power = clampf(power, 0.15, 1.0)
	p.color = color
	p.scale_amount_min = 0.5 + 0.6 * power
	p.scale_amount_max = 1.0 + 1.6 * power
	p.initial_velocity_max = 3.0 + 6.0 * power
	p.global_position = pos
	p.visible = true
	p.restart()
	p.emitting = true

## The crash fireball.
func crash(pos: Vector3) -> void:
	var p := _fire[_next_fire]
	_next_fire = (_next_fire + 1) % FIRE_EMITTERS
	p.global_position = pos
	p.visible = true
	p.restart()
	p.emitting = true

## Pre-warm: fire everything once, in view.
func show_all(pos: Vector3) -> void:
	for i in SMOKE_EMITTERS:
		smoke(pos + Vector3(float(i) * 1.5 - 3.0, 0.3, 1.0), 1.0, Color.WHITE)
	for i in FIRE_EMITTERS:
		crash(pos + Vector3(float(i) * 3.0 - 1.5, 3.0, 1.0))
	for i in GOLD_EMITTERS:
		sparkle(pos + Vector3(float(i) * 2.0 - 2.0, 4.0, 1.0), 6)
	for i in TIRE_EMITTERS:
		tire(pos + Vector3(float(i) * 2.0 - 2.0, 0.5, 1.0), 1.0)
	debris(pos + Vector3(0, 3.0, 0), Color.WHITE, Color.RED, pos.y - 1.5)
	burn(pos + Vector3(0, 2.0, 0))

func clear() -> void:
	for p in _tire:
		p.emitting = false
		p.visible = false
	_burn.emitting = false
	_burn.visible = false
	for i in DEBRIS:
		_deb[i].visible = false
		_deb_age[i] = 99.0
	_slow = 1.0
	for p in _smoke:
		p.emitting = false
		p.visible = false   # (hiding drops the particles still in flight)
	for p in _fire:
		p.emitting = false
		p.visible = false
	for p in _gold:
		p.emitting = false
		p.visible = false
