class_name Wind
extends RefCounted
## Steady wind plus random gusts. `base` > 0 is a headwind, < 0 a tailwind (the plane flies toward +x).
## A gust is a short smooth bump: a vertical push (up or down) and a horizontal push.

var base := 0.0
var gust_v := 0.0          # current vertical push (+ = up), units/s of sink target
var gust_h := 0.0          # current horizontal push (+ = more headwind)
var gust_started := false  # true for the one update in which a gust began (Main reads and clears it)
var turb_v := 0.0          # turbulence on final: continuous vertical noise (weather)
var shear_v := 0.0         # wind shear: a sudden downdraft ...
var shear_h := 0.0         # ... and a sudden loss of headwind
var _tt := 0.0
var _shear_t := -1.0       # time into a shear (< 0 = none running)
var _t := 0.0              # time into the current gust
var _dur := 1.0
var _peak_v := 0.0
var _peak_h := 0.0
var _active := false
var _next_in := 2.0

func reset(base_wind: float, rng: RandomNumberGenerator, first_gust_in: float = 2.5) -> void:
	base = base_wind
	gust_v = 0.0
	gust_h = 0.0
	gust_started = false
	_active = false
	_t = 0.0
	_next_in = first_gust_in
	turb_v = 0.0
	shear_v = 0.0
	shear_h = 0.0
	_shear_t = -1.0

## Total headwind right now (steady + gust + shear).
func head() -> float:
	return base + gust_h + shear_h

## Total vertical push (gust + turbulence + shear) and horizontal push (gust + shear).
func v_total() -> float:
	return gust_v + turb_v + shear_v

func h_total() -> float:
	return gust_h + shear_h

## Wind shear: a sudden downdraft and a headwind loss that fade in and out over Tuning.shear_duration.
func start_shear() -> void:
	_shear_t = 0.0

func shear_running() -> bool:
	return _shear_t >= 0.0

## Turbulence: `amp` (units/s) of smooth vertical noise, scaled by `zone` (0..1: how far into the rough air).
func update_turbulence(dt: float, amp: float, zone: float) -> void:
	_tt += dt
	var n := sin(_tt * 2.3) * 0.5 + sin(_tt * 5.1 + 1.0) * 0.35 + sin(_tt * 9.7 + 2.0) * 0.15
	turb_v = amp * zone * n

func update_shear(dt: float) -> void:
	if _shear_t < 0.0:
		return
	_shear_t += dt
	var dur := maxf(Tuning.shear_duration, 0.1)
	if _shear_t >= dur:
		_shear_t = -1.0
		shear_v = 0.0
		shear_h = 0.0
		return
	var bell := sin(PI * _shear_t / dur)
	bell *= bell
	shear_v = -Tuning.shear_sink * bell
	shear_h = -Tuning.shear_head_drop * bell

## `scale` (0..1+) is the round's difficulty scaling of the gust strength.
func update(dt: float, rng: RandomNumberGenerator, scale: float) -> void:
	if not Tuning.wind_enabled:
		gust_v = 0.0
		gust_h = 0.0
		return
	if _active:
		_t += dt
		if _t >= _dur:
			_active = false
			gust_v = 0.0
			gust_h = 0.0
			_next_in = rng.randf_range(Tuning.gust_interval_min, Tuning.gust_interval_max)
		else:
			var bell := sin(PI * _t / _dur)
			bell *= bell
			gust_v = _peak_v * bell
			gust_h = _peak_h * bell
	else:
		_next_in -= dt
		if _next_in <= 0.0:
			_active = true
			_t = 0.0
			_dur = Tuning.gust_duration * rng.randf_range(0.7, 1.4)
			var strength := Tuning.gust_strength * scale * rng.randf_range(0.5, 1.0)
			_peak_v = strength if rng.randf() < 0.5 else -strength
			_peak_h = Tuning.gust_horizontal * scale * rng.randf_range(-0.7, 1.0)
			gust_started = true

func is_gusting() -> bool:
	return _active
