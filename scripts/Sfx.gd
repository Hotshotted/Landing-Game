class_name Sfx
extends Node
## Tiny synthesised sound effects (no audio files): tyre squeak, thud, crash, chime, gust whoosh.
## All streams are generated once at start-up; a small pool of players plays them.

enum { SQUEAK, THUD, CRASH, CHIME, WHOOSH, TAP, COIN, STAMP, TROMBONE, SIGN, FANFARE, SKID, BOOM, BACK, CONFIRM, DENY, PAGE }
const RATE := 22050
const POOL := 4

var _streams: Array[AudioStreamWAV] = []
var _players: Array[AudioStreamPlayer] = []
var _next := 0

func _ready() -> void:
	_streams.append(_make(0.22, func(t: float, n: float) -> float:
		var f := 1900.0 - 900.0 * t
		return (sin(TAU * f * t) * 0.55 + sin(TAU * f * 1.5 * t) * 0.25 + n * 0.2) * (1.0 - t / 0.22) * minf(t * 80.0, 1.0)))
	_streams.append(_make(0.3, func(t: float, n: float) -> float:
		var f := 110.0 - 200.0 * t
		return (sin(TAU * f * t) * 0.9 + n * 0.25) * exp(-t * 14.0)))
	_streams.append(_make(0.9, func(t: float, n: float) -> float:
		return (n * 0.9 + sin(TAU * 70.0 * t) * 0.5) * exp(-t * 4.0)))
	_streams.append(_make(0.5, func(t: float, _n: float) -> float:
		var e := exp(-t * 5.0)
		var a := sin(TAU * 784.0 * t) * 0.5
		var b := sin(TAU * 1175.0 * maxf(t - 0.12, 0.0)) * 0.5 if t > 0.12 else 0.0
		return (a + b) * e))
	_streams.append(_make(0.6, func(t: float, n: float) -> float:
		return n * 0.4 * sin(PI * t / 0.6)))
	_streams.append(_make(0.08, func(t: float, _n: float) -> float:
		return sin(TAU * (520.0 - 1800.0 * t) * t) * exp(-t * 38.0) * 0.8))
	_streams.append(_make(0.18, func(t: float, _n: float) -> float:       # COIN: a bright two-note ping
		var f := 1318.0 if t < 0.06 else 1760.0
		return (sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.0 * t) * 0.15) * exp(-t * 16.0)))
	_streams.append(_make(0.35, func(t: float, n: float) -> float:       # STAMP: a dull thump and a paper slap
		return (sin(TAU * (90.0 - 120.0 * t) * t) * 0.9 + n * 0.5 * exp(-t * 60.0)) * exp(-t * 11.0)))
	_streams.append(_make(1.5, func(t: float, _n: float) -> float:       # TROMBONE: a sad "wah wah wah wahhh"
		var f := 233.0
		if t < 0.35:
			f = 233.0
		elif t < 0.7:
			f = 220.0
		elif t < 1.05:
			f = 208.0
		else:
			f = 196.0 - 22.0 * (t - 1.05)
		var vib := 1.0 + 0.02 * sin(TAU * 6.0 * t) * float(t > 1.05)
		var env := (0.55 + 0.45 * absf(sin(PI * t / 0.35))) if t < 1.05 else exp(-(t - 1.05) * 2.2)
		var ph := f * vib * t
		return (sin(TAU * ph) * 0.45 + sin(TAU * 2.0 * ph) * 0.3 + sin(TAU * 3.0 * ph) * 0.15) * env * minf(t * 40.0, 1.0)))
	_streams.append(_make(0.45, func(t: float, n: float) -> float:        # SIGN: a pen scratching
		return n * 0.35 * (0.5 + 0.5 * sin(TAU * 11.0 * t)) * sin(PI * t / 0.45)))
	_streams.append(_make(0.9, func(t: float, _n: float) -> float:        # FANFARE: a bright rising arpeggio
		var notes := [523.25, 659.25, 783.99, 1046.5]
		var v := 0.0
		for k in 4:
			var tt: float = t - float(k) * 0.09
			if tt > 0.0:
				var f: float = notes[k]
				v += (sin(TAU * f * tt) * 0.4 + sin(TAU * f * 2.0 * tt) * 0.12) * exp(-tt * (5.0 if k < 3 else 3.2))
		return v * 0.7))
	_streams.append(_make(0.55, func(t: float, n: float) -> float:        # SKID: tyres biting and chirping
		var f := 640.0 + 260.0 * sin(TAU * 7.0 * t)
		return (n * 0.35 + sin(TAU * f * t) * 0.28) * exp(-t * 5.0) * minf(t * 60.0, 1.0)))
	_streams.append(_make(1.1, func(t: float, n: float) -> float:        # BOOM: a low thud under the crash, for the lost pot
		return (sin(TAU * (60.0 - 30.0 * t) * t) * 0.9 + n * 0.25 * exp(-t * 20.0)) * exp(-t * 3.5)))
	_streams.append(_make(0.1, func(t: float, _n: float) -> float:        # BACK: a lower, softer tap
		return sin(TAU * (330.0 - 900.0 * t) * t) * exp(-t * 32.0) * 0.7))
	_streams.append(_make(0.2, func(t: float, _n: float) -> float:       # CONFIRM: two quick rising notes
		var f := 660.0 if t < 0.07 else 990.0
		return sin(TAU * f * t) * exp(-fmod(t, 0.07) * 20.0) * exp(-t * 6.0) * 0.6))
	_streams.append(_make(0.22, func(t: float, _n: float) -> float:      # DENY: a short low buzz
		return (sin(TAU * 110.0 * t) * 0.5 + sin(TAU * 117.0 * t) * 0.4) * exp(-t * 9.0) * minf(t * 80.0, 1.0)))
	_streams.append(_make(0.28, func(t: float, n: float) -> float:       # PAGE: paper swish
		return n * 0.45 * sin(PI * t / 0.28) * (0.4 + 0.6 * t / 0.28)))
	_build_loops()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"Sfx"
		add_child(p)
		_players.append(p)

func play(kind: int, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if DebugFlags.off("sfx"):
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = _streams[kind]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()

## Render a mono 16-bit clip. `fn(t, noise)` returns the sample (-1..1) at time t seconds.
func _make(length: float, fn: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var lp := 0.0
	for i in n:
		var noise := rng.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.3          # a little low-pass so the noise isn't harsh
		var v := clampf(fn.call(float(i) / RATE, lp * 1.6) as float, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

# ---------- continuous loops: engines per aircraft, wind, rain ----------

const LOOP_RATE := 11025
var _engine_streams: Array[AudioStreamWAV] = []     # per aircraft kind (0 Cub, 1 172, 2 twin, 3 glider, 4 jet)
var _engine_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _rain_player: AudioStreamPlayer
var _engine_kind := -1
var _engine_goal := 0.0       # 0..1 loudness the engine should have
var _engine_pitch_goal := 1.0
var _wind_goal := 0.0
var _rain_goal := 0.0
var _engine_level := 0.0
var _wind_level := 0.0
var _rain_level := 0.0

## One-second loops built from whole-number frequencies, so they repeat without a click.
func _loop(fn: Callable) -> AudioStreamWAV:
	var n := LOOP_RATE
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var lp := 0.0
	for i in n:
		var t := float(i) / float(LOOP_RATE)
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.25
		data.encode_s16(i * 2, int(clampf(fn.call(t, lp * 1.7) as float, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = LOOP_RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

## A piston engine: a fundamental with its harmonics and a firing pulse (`pulse` Hz, whole numbers), a little grit.
func _piston(base: float, pulse: float, detune: float) -> AudioStreamWAV:
	return _loop(func(t: float, n: float) -> float:
		var fire := 0.55 + 0.45 * pow(0.5 + 0.5 * sin(TAU * pulse * t), 2.0)
		var v := 0.0
		for k in range(1, 6):
			v += sin(TAU * base * float(k) * t) / float(k) * (1.0 if k < 4 else 0.7)
			if detune > 0.0:
				v += sin(TAU * (base + detune) * float(k) * t) / float(k) * 0.8
		return (v * 0.32 * fire + n * 0.10) * 0.8)

func _build_loops() -> void:
	_engine_streams = [
		_piston(37.0, 18.0, 0.0),       # Cub: slow, popping
		_piston(48.0, 24.0, 0.0),       # 172: smoother
		_piston(54.0, 27.0, 2.0),       # twin: two engines a little apart (they beat)
		null,                           # glider: no engine
		_loop(func(t: float, n: float) -> float:       # jet: a rush of noise and a high whine
			return n * 0.55 + sin(TAU * 820.0 * t) * 0.10 + sin(TAU * 1230.0 * t) * 0.06 + sin(TAU * 61.0 * t) * 0.18),
	]
	_engine_player = AudioStreamPlayer.new()
	_engine_player.bus = &"Sfx"
	_engine_player.volume_db = -80.0
	add_child(_engine_player)
	_wind_player = AudioStreamPlayer.new()
	_wind_player.bus = &"Sfx"
	_wind_player.volume_db = -80.0
	_wind_player.stream = _loop(func(t: float, n: float) -> float:
		return n * 0.5 * (0.7 + 0.3 * sin(TAU * 2.0 * t)) * (0.8 + 0.2 * sin(TAU * 3.0 * t + 1.0)))
	add_child(_wind_player)
	_rain_player = AudioStreamPlayer.new()
	_rain_player.bus = &"Sfx"
	_rain_player.volume_db = -80.0
	_rain_player.stream = _loop(func(t: float, n: float) -> float:
		return n * 0.45 * (0.85 + 0.15 * sin(TAU * 13.0 * t)))
	add_child(_rain_player)

## Aim the loops: `kind` is the aircraft kind (-1 = silence), `engine` 0..1 loudness, `pitch` around 1, `wind` / `rain` 0..1.
## The volumes ease toward these in _process, so nothing ever jumps.
func set_loops(kind: int, engine: float, pitch: float, wind: float, rain: float) -> void:
	if kind != _engine_kind and kind >= 0 and kind < _engine_streams.size():
		_engine_kind = kind
		_engine_player.stream = _engine_streams[kind]
		if _engine_player.stream != null and not _engine_player.playing:
			_engine_player.play()
	_engine_goal = engine if (kind >= 0 and kind < _engine_streams.size() and _engine_streams[kind] != null) else 0.0
	_engine_pitch_goal = pitch
	_wind_goal = wind
	_rain_goal = rain

func loops_off() -> void:
	set_loops(_engine_kind, 0.0, 1.0, 0.0, 0.0)

func engine_level() -> float:
	return _engine_level

func _process(delta: float) -> void:
	if DebugFlags.off("sfx") or _engine_player == null:
		return
	var k := minf(delta * 3.0, 1.0)
	_engine_level += (_engine_goal - _engine_level) * k
	_wind_level += (_wind_goal - _wind_level) * k
	_rain_level += (_rain_goal - _rain_level) * k
	_engine_player.volume_db = -80.0 if _engine_level < 0.01 else -34.0 + 22.0 * _engine_level
	_engine_player.pitch_scale = lerpf(_engine_player.pitch_scale, clampf(_engine_pitch_goal, 0.6, 1.8), minf(delta * 4.0, 1.0))
	if _engine_level >= 0.01 and not _engine_player.playing and _engine_player.stream != null:
		_engine_player.play()
	_set_loop_player(_wind_player, _wind_level, -40.0, -16.0)
	_set_loop_player(_rain_player, _rain_level, -42.0, -18.0)

func _set_loop_player(p: AudioStreamPlayer, level: float, quiet: float, loud: float) -> void:
	if level < 0.01:
		p.volume_db = -80.0
		if p.playing:
			p.stop()
		return
	if not p.playing:
		p.play()
	p.volume_db = lerpf(quiet, loud, level)
