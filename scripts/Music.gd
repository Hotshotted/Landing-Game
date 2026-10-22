class_name Music
extends Node
## A quiet synthesised pad loop (no audio files) on the "Music" bus, so the settings have something to turn down. Generated once.

const RATE := 11025
const LENGTH := 12.0
## Four chords, three seconds each (A minor, F, C, G): root notes in Hz and the intervals above them.
const ROOTS := [110.0, 87.31, 130.81, 98.0]
const INTERVALS := [1.0, 1.2, 1.5, 2.0]

const FLIGHT_ROOTS := [130.81, 98.0, 110.0, 87.31]
const FLIGHT_INTERVALS := [1.0, 1.26, 1.5, 2.0]
var _player: AudioStreamPlayer
var _player2: AudioStreamPlayer
var _mood := 0.0             # 0 = menu pad, 1 = flight pad (eases)
var _mood_goal := 0.0
var _tension_player: AudioStreamPlayer
var _tension := 0.0          # where it is (eases)
var _tension_goal := 0.0     # where it should be, 0 (calm) .. 1 (the pot is on the line)

func _ready() -> void:
	if DebugFlags.off("sfx"):
		return
	# two moods on the same 12-second grid, so they crossfade without ever drifting apart: a dark pad for the menus and a
	# brighter, gently moving one for flying
	_player = _pad_player(_make_pad(ROOTS, INTERVALS, false), -12.0)
	_player2 = _pad_player(_make_pad(FLIGHT_ROOTS, FLIGHT_INTERVALS, true), -80.0)

	_build_tension()

## A second loop under the pad: a slow heartbeat and two notes a semitone apart. Silent until `set_tension` raises it.
func _build_tension() -> void:
	var len_s := 4.0
	var n := int(len_s * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var beat := fmod(t, 4.0 / 6.0)              # 90 beats a minute
		var thump := sin(TAU * 52.0 * beat) * exp(-beat * 16.0)
		thump += 0.6 * sin(TAU * 52.0 * maxf(beat - 0.18, 0.0)) * exp(-maxf(beat - 0.18, 0.0) * 18.0) * float(beat > 0.18)
		var drone := sin(TAU * 98.0 * t) * 0.18 + sin(TAU * 103.8 * t) * 0.18 + sin(TAU * 196.0 * t + sin(TAU * 0.5 * t)) * 0.08
		data.encode_s16(i * 2, int(clampf(thump * 0.8 + drone, -1.0, 1.0) * 22000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_tension_player = AudioStreamPlayer.new()
	_tension_player.stream = w
	_tension_player.bus = &"Music"
	_tension_player.volume_db = -60.0
	add_child(_tension_player)
	_tension_player.play()

func set_tension(level: float) -> void:
	_tension_goal = clampf(level, 0.0, 1.0)

func tension() -> float:
	return _tension

func _process(delta: float) -> void:
	_mood = move_toward(_mood, _mood_goal, delta / 1.2)
	if _player != null and _player2 != null:
		_player.volume_db = -12.0 + linear_to_db(maxf(cos(_mood * PI * 0.5), 0.0001))
		_player2.volume_db = -13.0 + linear_to_db(maxf(sin(_mood * PI * 0.5), 0.0001))
	_tension = move_toward(_tension, _tension_goal, delta * (0.9 if _tension_goal > _tension else 0.5))
	if _tension_player != null:
		_tension_player.volume_db = -60.0 + 48.0 * sqrt(_tension) if _tension > 0.005 else -80.0

func _pad_player(stream: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = &"Music"
	p.volume_db = db
	add_child(p)
	p.play()
	return p

## Four chords, three seconds each; `arp` adds a soft broken-chord figure on top.
func _make_pad(roots: Array, intervals: Array, arp: bool) -> AudioStreamWAV:
	var n := int(LENGTH * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var chord := int(t / 3.0) % 4
		var local := fmod(t, 3.0)
		var env := minf(local / 0.8, 1.0) * minf((3.0 - local) / 0.8, 1.0)
		var v := 0.0
		for k in intervals.size():
			var f: float = float(roots[chord]) * float(intervals[k])
			v += sin(TAU * f * t) * (0.5 if k == 0 else 0.25)
		v *= env * (0.8 + 0.2 * sin(TAU * 0.25 * t)) * 0.45
		if arp:
			var step := int(t / 0.375)
			var tt := fmod(t, 0.375)
			var f2: float = float(roots[chord]) * 2.0 * float(intervals[[0, 1, 2, 1][step % 4]])
			v += sin(TAU * f2 * tt) * exp(-tt * 9.0) * 0.16 * minf(tt * 200.0, 1.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 24000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w

## 0 = the menu pad, 1 = the flying pad: they crossfade over about a second.
func set_mood(m: float) -> void:
	_mood_goal = clampf(m, 0.0, 1.0)

func mood() -> float:
	return _mood
