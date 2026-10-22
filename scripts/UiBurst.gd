class_name UiBurst
extends Control
## Screen-space particles drawn in one call: coins that fly along a curve to a target (into the pot, out of the pot into the bank)
## and confetti. A fixed pool of slots in packed arrays, so nothing is allocated while it plays. Pre-warmed by `show_all`.

signal coin_arrived

const MAX := 96
const COIN := 0
const CONFETTI := 1
const CONFETTI_COLORS: Array[Color] = [Style.PRIMARY, Style.ACCENT, Style.SUCCESS, Style.DANGER, Style.WARNING, Color.WHITE]

var _on := PackedByteArray()
var _kind := PackedByteArray()
var _p0 := PackedVector2Array()
var _p1 := PackedVector2Array()
var _pc := PackedVector2Array()
var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _t := PackedFloat32Array()
var _dur := PackedFloat32Array()
var _rot := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _col := PackedColorArray()
var _size := PackedFloat32Array()
var _active := 0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_on.resize(MAX)
	_kind.resize(MAX)
	_p0.resize(MAX)
	_p1.resize(MAX)
	_pc.resize(MAX)
	_pos.resize(MAX)
	_vel.resize(MAX)
	_t.resize(MAX)
	_dur.resize(MAX)
	_rot.resize(MAX)
	_spin.resize(MAX)
	_size.resize(MAX)
	_col.resize(MAX)
	_rng.seed = 424242
	set_process(false)

func _slot() -> int:
	for i in MAX:
		if _on[i] == 0:
			return i
	return -1

## `n` coins fly from `from` to `to` (the first leaves after `delay` seconds, the rest a few hundredths apart).
func fly_coins(from: Vector2, to: Vector2, n: int, delay: float = 0.0) -> void:
	for k in n:
		var i := _slot()
		if i < 0:
			return
		_on[i] = 1
		_kind[i] = COIN
		_p0[i] = from + Vector2(_rng.randf_range(-40.0, 40.0), _rng.randf_range(-20.0, 20.0))
		_p1[i] = to
		var mid := (_p0[i] + to) * 0.5
		_pc[i] = mid + Vector2(_rng.randf_range(-160.0, 160.0), -_rng.randf_range(80.0, 260.0))
		_t[i] = -delay - float(k) * 0.045
		_dur[i] = _rng.randf_range(0.55, 0.8)
		_size[i] = 26.0
		_pos[i] = _p0[i]
		_active += 1
	set_process(true)

func confetti(origin: Vector2, n: int) -> void:
	for k in n:
		var i := _slot()
		if i < 0:
			return
		_on[i] = 1
		_kind[i] = CONFETTI
		_pos[i] = origin + Vector2(_rng.randf_range(-300.0, 300.0), _rng.randf_range(-40.0, 40.0))
		_vel[i] = Vector2(_rng.randf_range(-220.0, 220.0), -_rng.randf_range(500.0, 1100.0))
		_t[i] = -_rng.randf_range(0.0, 0.25)
		_dur[i] = _rng.randf_range(2.0, 3.0)
		_rot[i] = _rng.randf() * TAU
		_spin[i] = _rng.randf_range(-9.0, 9.0)
		_col[i] = CONFETTI_COLORS[_rng.randi() % CONFETTI_COLORS.size()]
		_size[i] = _rng.randf_range(12.0, 22.0)
		_active += 1
	set_process(true)

func clear() -> void:
	for i in MAX:
		_on[i] = 0
	_active = 0
	set_process(false)
	queue_redraw()

func active_count() -> int:
	return _active

func _process(delta: float) -> void:
	for i in MAX:
		if _on[i] == 0:
			continue
		_t[i] += delta
		if _t[i] < 0.0:
			continue
		if _kind[i] == COIN:
			var k := clampf(_t[i] / _dur[i], 0.0, 1.0)
			var e := Style.ease_in_cubic(k) * 0.6 + k * 0.4
			var a := _p0[i].lerp(_pc[i], e)
			var b := _pc[i].lerp(_p1[i], e)
			_pos[i] = a.lerp(b, e)
			if k >= 1.0:
				_on[i] = 0
				_active -= 1
				coin_arrived.emit()
		else:
			_vel[i].y += 1500.0 * delta
			_vel[i].x *= 1.0 - delta * 0.8
			_pos[i] += _vel[i] * delta
			_rot[i] += _spin[i] * delta
			if _t[i] >= _dur[i] or _pos[i].y > size.y + 40.0:
				_on[i] = 0
				_active -= 1
	queue_redraw()
	if _active <= 0:
		_active = 0
		set_process(false)

func _draw() -> void:
	for i in MAX:
		if _on[i] == 0 or _t[i] < 0.0:
			continue
		if _kind[i] == COIN:
			var k := clampf(_t[i] / _dur[i], 0.0, 1.0)
			Icons.glyph(self, "coin", _pos[i], _size[i] * (0.8 + 0.4 * sin(k * PI)))
		else:
			var fade := clampf((_dur[i] - _t[i]) / 0.5, 0.0, 1.0)
			var sq := absf(cos(_rot[i] * 1.7))
			draw_set_transform(_pos[i], _rot[i], Vector2(1.0, 0.25 + 0.75 * sq))
			draw_rect(Rect2(-_size[i] * 0.5, -_size[i] * 0.3, _size[i], _size[i] * 0.6), Color(_col[i], fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Pre-warm: every kind of particle drawn once for real.
func show_all() -> void:
	fly_coins(Vector2(300, 600), Vector2(700, 300), 4)
	confetti(Vector2(540, 900), 12)
