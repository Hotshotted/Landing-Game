class_name Sfx
extends Node
## Tiny synthesised sound effects (no audio files): tyre squeak, thud, crash, chime, gust whoosh.
## All streams are generated once at start-up; a small pool of players plays them.

enum { SQUEAK, THUD, CRASH, CHIME, WHOOSH, TAP, COIN, STAMP, TROMBONE, SIGN }
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
