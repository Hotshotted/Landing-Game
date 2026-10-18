class_name Fx
extends Node3D
## Pooled particle effects: tire smoke / dust puffs and the crash fireball. Every emitter is created
## once in _ready and re-fired (restart) - nothing is created while playing.

const SMOKE_EMITTERS := 5
const FIRE_EMITTERS := 2

var _smoke: Array[CPUParticles3D] = []
var _fire: Array[CPUParticles3D] = []
var _next_smoke := 0
var _next_fire := 0

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

func clear() -> void:
	for p in _smoke:
		p.emitting = false
		p.visible = false   # (hiding drops the particles still in flight)
	for p in _fire:
		p.emitting = false
		p.visible = false
