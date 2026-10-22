class_name Music
extends Node
## A quiet synthesised pad loop (no audio files) on the "Music" bus, so the settings have something to turn down. Generated once.

const RATE := 11025
const LENGTH := 12.0
## Four chords, three seconds each (A minor, F, C, G): root notes in Hz and the intervals above them.
const ROOTS := [110.0, 87.31, 130.81, 98.0]
const INTERVALS := [1.0, 1.2, 1.5, 2.0]

var _player: AudioStreamPlayer
var _tension_player: AudioStreamPlayer
var _tension := 0.0          # where it is (eases)
var _tension_goal := 0.0     # where it should be, 0 (calm) .. 1 (the pot is on the line)

func _ready() -> void:
	if DebugFlags.off("sfx"):
		return
	var n := int(LENGTH * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var chord := int(t / 3.0) % 4
		var local := fmod(t, 3.0)
		var env := minf(local / 0.8, 1.0) * minf((3.0 - local) / 0.8, 1.0)
		var v := 0.0
		for k in INTERVALS.size():
			var f: float = ROOTS[chord] * INTERVALS[k]
			v += sin(TAU * f * t) * (0.5 if k == 0 else 0.25)
		v *= env * (0.8 + 0.2 * sin(TAU * 0.25 * t)) * 0.45
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 24000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_player = AudioStreamPlayer.new()
	_player.stream = w
	_player.bus = &"Music"
	_player.volume_db = -12.0
	add_child(_player)
	_player.play()

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
	_tension = move_toward(_tension, _tension_goal, delta * (0.9 if _tension_goal > _tension else 0.5))
	if _tension_player != null:
		_tension_player.volume_db = -60.0 + 48.0 * sqrt(_tension) if _tension > 0.005 else -80.0
