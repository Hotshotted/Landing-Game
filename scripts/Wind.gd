class_name Wind
extends RefCounted
## Steady wind plus random gusts. `base` > 0 is a headwind, < 0 a tailwind (the plane flies toward +x).
## A gust is a short smooth bump: a vertical push (up or down) and a horizontal push.

var base := 0.0
var gust_v := 0.0          # current vertical push (+ = up), units/s of sink target
var gust_h := 0.0          # current horizontal push (+ = more headwind)
var gust_started := false  # true for the one update in which a gust began (Main reads and clears it)
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

## Total headwind right now (steady + gust).
func head() -> float:
	return base + gust_h

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
