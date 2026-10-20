class_name Music
extends Node
## A quiet synthesised pad loop (no audio files) on the "Music" bus, so the settings have something to turn down. Generated once.

const RATE := 11025
const LENGTH := 12.0
## Four chords, three seconds each (A minor, F, C, G): root notes in Hz and the intervals above them.
const ROOTS := [110.0, 87.31, 130.81, 98.0]
const INTERVALS := [1.0, 1.2, 1.5, 2.0]

var _player: AudioStreamPlayer

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
