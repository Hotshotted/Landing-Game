class_name SfxSynth
extends RefCounted
## Renders every sound of Greaser (see docs/style.md, "Audio"; the direction is the studio's, shared with Pattern-Control) as float samples. Run offline by tools/render_audio.gd, which
## writes the 44.1 kHz 16-bit WAV files in assets/audio/ that the game loads; the game itself never synthesises anything.
## Soft sines and filtered noise, raised-cosine envelopes, a baked-in room, everything in C major pentatonic.
## (No autoload references: the smoke test re-renders everything and compares it with the committed files.)

const STEPS := 7               # landing chimes / coin plinks: this many steps up the scale
const BEAT := 0.75             # music: seconds per beat, 8 beats per loop (6 s)
const C4 := 261.6256
const PENTA := [0, 2, 4, 7, 9]  # C D E G A

# Loudness by role (peak, linear), with the MUSIC as the reference: the music as it is heard (the calm layer's peak 0.35 played at
# MUSIC_DB in Sfx.gd) peaks at MUSIC_REF; gameplay sounds sit at or below 0.8 of it, UI sounds at or below 0.5 of it.
const MUSIC_REF := 0.22
const LVL_UI := 0.09           # taps, ticks, clicks (<= 0.5 x MUSIC_REF)
const LVL_GAME := 0.14         # landings, fines, go-arounds, wind (<= 0.8 x MUSIC_REF)
const LVL_BIG := 0.16          # stars, a new airport, the results slam (<= 0.8 x MUSIC_REF)

var rate := 44100

## Every one-shot: name -> samples.
func clips() -> Dictionary:
	var out := {}
	_build_effects_into(out)
	return out

## Every loop: name -> samples. Music layers (calm, hot, tense; 6 s), the engine beds (low and quiet, 2 s), wind and rain (2 s).
func loops() -> Dictionary:
	return {"calm": _music(false), "hot": _music(true), "tense": _music_tense_loop(),
		"engine_cub": _engine_bed(49.0, 6.0, 0.0), "engine_172": _engine_bed(55.0, 7.0, 0.0),
		"engine_twin": _engine_bed(65.5, 6.0, 66.0), "engine_jet": _jet_bed(),
		"wind": _air_loop(300.0, 0.5, LVL_BED * 0.8, 4141), "rain": _rain_loop()}

# ---------- The key ----------

## Frequency of scale degree `deg` of C major pentatonic: 0 = C4, 1 = D4, 2 = E4, 3 = G4, 4 = A4, 5 = C5, ...
static func note_hz(deg: int) -> float:
	var oct := floori(float(deg) / 5.0)
	return C4 * pow(2.0, float(PENTA[posmod(deg, 5)] + 12 * oct) / 12.0)

# ---------- The clips ----------

func _build_effects_into(clips: Dictionary) -> void:
	# Tyres: a soft rubber chirp (a low-passed puff of air with a soft A4 under it) and a longer, softer skid.
	clips["squeak"] = _norm(_tailfade(_mix_at(_lp(_lp(_noise_burst(0.12, 1), 900.0), 900.0), _soft(note_hz(4), 0.12, 0.6), 0), 0.03), LVL_UI * 0.8)
	clips["skid"] = _norm(_tailfade(_lp(_lp(_noise_burst(0.4, 2), 700.0), 700.0), 0.04), LVL_UI * 0.9)
	# Touchdown: a soft, low thump, far below the chime.
	clips["thud"] = _norm(_lp(_lp(_thud(0.3), 240.0), 240.0), LVL_GAME * 0.6)
	# A crash: a low muted thud, a little debris (low-passed) and a soft descending pair (A3, E3, C3) over it. Never harsh.
	var dbris := _lp(_lp(_lp(_noise_burst(0.4, 3), 380.0), 380.0), 380.0)
	var crash := _mix_at(_mix_at(_mix_at(_thud(0.7), dbris, int(0.02 * rate)), _soft(note_hz(4) * 0.5, 0.3, 0.8), int(0.05 * rate)), _soft(note_hz(2) * 0.5, 0.4, 0.8), int(0.3 * rate))
	clips["crash"] = _norm(_reverb(_mix_at(crash, _soft(note_hz(0) * 0.5, 0.7, 0.8), int(0.62 * rate)), 0.25, 0.5), LVL_BIG)
	# The pot is lost: a deep soft boom.
	clips["boom"] = _norm(_reverb(_lp(_thud(0.9), 160.0), 0.3, 0.6), LVL_BIG * 0.9)
	# Chimes: ONE soft bell in the key, each in a row one step up the scale (streaks, the cash-out count). Coins: tiny plinks.
	for k in STEPS:
		clips["chime_%d" % k] = _norm(_reverb(_bell(note_hz(5 + k), 1.0, 1.0, 0.6), 0.3, 0.5), LVL_GAME * 0.9)
		clips["coin_%d" % k] = _norm(_reverb(_bell(note_hz(7 + k), 0.4, 1.0, 0.8), 0.25, 0.35), LVL_GAME * 0.4)
	# Stamp: a warm thud with a bell on top. Trombone: a soft sad descent (G E D C) in the key.
	clips["stamp"] = _norm(_reverb(_mix_at(_thud(0.45), _bell(note_hz(10), 0.8, 0.7, 0.8), int(0.03 * rate)), 0.3, 0.5), LVL_BIG)
	var tb := PackedFloat32Array()
	var tb_t := [0.0, 0.34, 0.68, 1.02]
	var tb_d := [3, 2, 1, 0]
	var tb_len := [0.34, 0.34, 0.34, 0.8]
	for k in 4:
		tb = _mix_at(tb, _soft(note_hz(tb_d[k]) * 0.5, tb_len[k], 1.0), int(tb_t[k] * rate))
	clips["trombone"] = _norm(_reverb(tb, 0.25, 0.5), LVL_BIG * 0.9)
	# A pen signing: a soft, slow swish. A page turning: a short soft swish. A whoosh: a screen sliding.
	clips["sign"] = _norm(_whoosh(0.4, 600.0, 1500.0), LVL_UI)
	clips["page"] = _norm(_whoosh(0.2, 400.0, 900.0), LVL_UI * 0.9)
	clips["whoosh"] = _norm(_whoosh(0.25, 500.0, 1100.0), LVL_UI * 1.1)
	# Fanfare: a rising figure of bells (C E G A C) for a Greaser, a streak step, a new aircraft, the banked cash.
	var un := PackedFloat32Array()
	for k in 5:
		un = _mix_at(un, _bell(note_hz([5, 7, 8, 10, 12][k]), 0.9, 1.0, 0.9), int(k * 0.12 * rate))
	clips["fanfare"] = _norm(_reverb(un, 0.45, 0.8), LVL_BIG)
	# UI: very quiet, very short, soft clicks (tap, back, confirm, deny).
	clips["tap"] = _norm(_knock(520.0, 0.06), LVL_UI)
	clips["back"] = _norm(_mix_at(_knock(440.0, 0.05), _knock(330.0, 0.07), int(0.05 * rate)), LVL_UI)
	clips["confirm"] = _norm(_reverb(_mix_at(_bell(note_hz(5), 0.3, 1.0, 0.8), _bell(note_hz(7), 0.4, 0.9, 0.8), int(0.07 * rate)), 0.2, 0.3), LVL_UI * 1.2)
	clips["deny"] = _norm(_soft(note_hz(2) * 0.5, 0.16, 0.9), LVL_UI * 1.2)

## Fade the last `secs` seconds to silence (raised cosine).
func _tailfade(x: PackedFloat32Array, secs: float) -> PackedFloat32Array:
	var out := x.duplicate()
	var m := mini(int(secs * rate), out.size())
	for k in m:
		var c := cos(PI * 0.5 * float(k) / float(m))
		out[out.size() - m + k] *= c * c
	return out

## A burst of noise with a soft raised-cosine envelope (the raw material of rubber and debris, always low-passed after).
func _noise_burst(dur: float, seed_v: int) -> PackedFloat32Array:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var s := seed_v * 7919
	for i in n:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		out[i] = (float(s) / 1073741823.5 - 1.0) * sin(PI * float(i) / n)
	return out

## An 8-beat loop (6 s) in C major: C, Am, F, G, two beats each. The calm layer is a warm pad with a soft bass; the intense
## layer is a plucked pentatonic arpeggio with a very soft pulse underneath. Both loops are seamless, and equally long.
func _music(hot: bool) -> PackedFloat32Array:
	var n := int(BEAT * 8.0 * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	if not hot:
		var chords := [[130.81, 261.63, 329.63, 392.0], [110.0, 220.0, 261.63, 329.63], [87.31, 174.61, 220.0, 261.63], [98.0, 196.0, 246.94, 293.66]]
		var seg := 2.0 * BEAT
		for c in 4:
			var start := c * seg - 0.25
			var length := seg + 0.5
			var start_i := int(round(start * rate))
			for f_v in chords[c]:
				var f: float = f_v
				for i in int(length * rate):
					var t := float(i) / rate
					var w := minf(smoothstep(0.0, 0.45, t), smoothstep(0.0, 0.45, length - t))
					var idx := posmod(start_i + i, n)
					var ph: float = TAU * f * (start + t)
					out[idx] += (sin(ph) + 0.25 * sin(2.0 * ph)) * w * (0.28 if f > 150.0 else 0.4)
		return _norm(out, 0.35)
	var arps := [[5, 7, 8, 7], [4, 5, 7, 5], [4, 5, 6, 5], [3, 6, 8, 6]]
	var eighth := BEAT * 0.5
	for c in 4:
		for k in 4:
			var at := int((c * 4 + k) * eighth * rate)
			var note := _bell(note_hz(arps[c][k]), 0.9, 0.55 if k > 0 else 0.7, 0.5)
			for i in note.size():
				out[posmod(at + i, n)] += note[i]
	for b in 8:
		var at2 := int(b * BEAT * rate)
		for i in int(0.22 * rate):
			var t2 := float(i) / rate
			out[posmod(at2 + i, n)] += 0.22 * sin(TAU * lerpf(80.0, 50.0, minf(t2 * 6.0, 1.0)) * t2) * exp(-t2 * 14.0) * smoothstep(0.0, 0.012, t2)
	out = _reverb_loop(out, 0.3)
	return _norm(out, 0.35)

const LVL_BED := 0.075         # engine beds, wind, rain: low and quiet (<= 0.5 x MUSIC_REF)
const LOOP2 := 2.0             # the beds are two-second loops of whole cycles

## A piston engine as a low, quiet bed: a pentatonic low note and its first overtones with a soft firing pulse. Every frequency is
## a whole number of cycles per 2 s, so the loop is seamless. `f2` (> 0) adds a second engine a hair away (the twin: the two beat).
func _engine_bed(f: float, pulse_hz: float, f2: float) -> PackedFloat32Array:
	var n := int(LOOP2 * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var fa := roundf(f * LOOP2) / LOOP2
	var fb := roundf(f2 * LOOP2) / LOOP2
	var pz := roundf(pulse_hz * LOOP2) / LOOP2
	for i in n:
		var t := float(i) / rate
		var v := sin(TAU * fa * t) + 0.45 * sin(TAU * fa * 2.0 * t) + 0.18 * sin(TAU * fa * 3.0 * t)
		if f2 > 0.0:
			v += sin(TAU * fb * t) + 0.45 * sin(TAU * fb * 2.0 * t)
		out[i] = v * (0.8 + 0.2 * sin(TAU * pz * t))
	return _norm(out, LVL_BED)

## The jet: a soft rush of low air and a faint whine on G3, both in the key.
func _jet_bed() -> PackedFloat32Array:
	var air := _air_loop(180.0, 0.5, 1.0, 9191)
	var n := air.size()
	var out := PackedFloat32Array()
	out.resize(n)
	var fw := roundf(note_hz(3) * 0.5 * LOOP2) / LOOP2        # G3
	for i in n:
		out[i] = air[i] + 0.25 * sin(TAU * fw * float(i) / rate)
	return _norm(out, LVL_BED)

## Soft, slow breath of filtered air: a two-second loop whose ends are crossfaded (so it is seamless).
func _air_loop(cutoff: float, mod_hz: float, peak: float, seed_v: int) -> PackedFloat32Array:
	var n := int(LOOP2 * rate)
	var fade := rate / 4
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var lp := 0.0
	var lp2 := 0.0
	var fa := 1.0 - exp(-TAU * cutoff / rate)
	var fb := 1.0 - exp(-TAU * cutoff * 2.0 / rate)
	var s := seed_v
	for i in n + fade:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var noise := float(s) / 1073741823.5 - 1.0
		lp += (noise - lp) * fa
		lp2 += (lp - lp2) * fb
		raw[i] = lp2 * (0.65 + 0.35 * sin(TAU * mod_hz * float(i) / rate))
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		if i < fade:
			var a := float(i) / fade
			out[i] = raw[i] * a + raw[n + i] * (1.0 - a)
		else:
			out[i] = raw[i]
	return _norm(out, peak)

## Rain: a soft, steady patter of low-passed noise (nothing above about 2 kHz), crossfaded into a loop.
func _rain_loop() -> PackedFloat32Array:
	var n := int(LOOP2 * rate)
	var fade := rate / 4
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var s := 6006
	var lp := 0.0
	var lp2 := 0.0
	var lo := 0.0
	var fa := 1.0 - exp(-TAU * 1800.0 / rate)
	var fl := 1.0 - exp(-TAU * 350.0 / rate)
	for i in n + fade:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var noise := float(s) / 1073741823.5 - 1.0
		lp += (noise - lp) * fa
		lp2 += (lp - lp2) * fa
		lo += (lp2 - lo) * fl
		raw[i] = (lp2 - lo) * (0.8 + 0.2 * sin(TAU * 3.0 * float(i) / rate))
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		if i < fade:
			var a := float(i) / fade
			out[i] = raw[i] * a + raw[n + i] * (1.0 - a)
		else:
			out[i] = raw[i]
	return _norm(out, LVL_BED * 0.8)

## A low, tense but soft drone for fog: a tritone pair that slowly shivers, in the same 6 s length as the music.
func _music_tense_loop() -> PackedFloat32Array:
	var secs := BEAT * 8.0
	var n := int(secs * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var f1 := roundf(55.0 * secs) / secs          # whole cycles per loop: no click at the seam
	var f2 := roundf(77.8 * secs) / secs
	var ft := roundf(2.0 * secs) / secs
	for i in n:
		var t := float(i) / rate
		var trem := 0.7 + 0.3 * sin(TAU * ft * t)
		out[i] = (sin(TAU * f1 * t) + 0.7 * sin(TAU * f2 * t) + 0.2 * sin(TAU * f2 * 2.0 * t)) * trem
	return _norm(out, 0.3)

# ---------- Voices and DSP ----------

## Smooth fade in over `a` samples and out over `r` samples (raised-cosine): no clicks, ever.
static func _win(i: int, n: int, a: int, r: int) -> float:
	var v := 1.0
	if i < a:
		var s := sin(PI * 0.5 * float(i) / maxf(a, 1))
		v = s * s
	var j := n - 1 - i
	if j < r:
		var s2 := sin(PI * 0.5 * float(j) / maxf(r, 1))
		v *= s2 * s2
	return v

## A bell: a sine with two softer, quicker-fading overtones. `bright` scales the overtones.
func _bell(f: float, dur: float, amp: float, bright: float = 1.0) -> PackedFloat32Array:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var a_n := int(0.008 * rate)
	var r_n := int(0.04 * rate)
	for i in n:
		var t := float(i) / rate
		var v := sin(TAU * f * t) * exp(-t * 4.5)
		if f * 2.0 < rate * 0.5:
			v += 0.3 * bright * sin(TAU * f * 2.0 * t) * exp(-t * 8.0)
		if f * 3.0 < rate * 0.5:
			v += 0.08 * bright * sin(TAU * f * 3.0 * t) * exp(-t * 13.0)
		out[i] = v * amp * _win(i, n, a_n, r_n)
	return out

## A soft, slightly hollow tone (a sine with a touch of triangle), lowpassed: for the muted "bonk" and the descending pair.
func _soft(f: float, dur: float, amp: float) -> PackedFloat32Array:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var a_n := int(0.012 * rate)
	var r_n := int(0.06 * rate)
	for i in n:
		var t := float(i) / rate
		var ph := fposmod(f * t, 1.0)
		var tri := 4.0 * absf(ph - 0.5) - 1.0
		out[i] = (0.8 * sin(TAU * f * t) + 0.2 * tri) * exp(-t * 6.0) * amp * _win(i, n, a_n, r_n)
	return _lp(out, 900.0)

## A warm chord: sines with a slow bloom and a long release.
func _chord(freqs: Array, dur: float) -> PackedFloat32Array:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var a_n := int(0.25 * rate)
	var r_n := int(0.5 * rate)
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for f in freqs:
			v += sin(TAU * float(f) * t) + 0.2 * sin(TAU * float(f) * 2.0 * t)
		out[i] = v / freqs.size() * exp(-t * 1.6) * _win(i, n, a_n, r_n)
	return out

## A low thud: a sine falling from 120 to 55 Hz with a soft attack and a rounded decay.
func _thud(dur: float) -> PackedFloat32Array:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var a_n := int(0.01 * rate)
	var r_n := int(0.08 * rate)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		ph += TAU * lerpf(120.0, 55.0, minf(t * 5.0, 1.0)) / rate
		out[i] = sin(ph) * exp(-t * 9.0) * _win(i, n, a_n, r_n)
	return _lp(out, 500.0)

## A tiny soft knock: a short sine with a rounded start.
func _knock(f: float, dur: float) -> PackedFloat32Array:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var a_n := int(0.006 * rate)
	var r_n := int(0.014 * rate)
	for i in n:
		var t := float(i) / rate
		out[i] = sin(TAU * f * t) * exp(-t * 60.0) * _win(i, n, a_n, r_n)
	return _lp(out, 1400.0)

## Filtered noise that rises and falls in brightness: a swish.
func _whoosh(dur: float, f0: float, f1: float) -> PackedFloat32Array:
	var n := int(dur * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var seed_v := 777
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise := float(seed_v) / 1073741823.5 - 1.0
		var k := float(i) / n
		var fc := lerpf(f0, f1, sin(PI * k))
		var a := 1.0 - exp(-TAU * fc / rate)
		lp += (noise - lp) * a
		lp2 += (lp - lp2) * a
		out[i] = lp2 * sin(PI * k)
	return out

## One-pole lowpass (applied to taste: twice is 12 dB per octave).
func _lp(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / rate)
	var y := 0.0
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in x.size():
		y += a * (x[i] - y)
		out[i] = y
	return out

## Scale a clip so its peak is `peak`.
func _norm(x: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in x:
		m = maxf(m, absf(v))
	var g := peak / m
	var out := PackedFloat32Array()
	out.resize(x.size())
	for i in x.size():
		out[i] = x[i] * g
	return out

## Add `src` into `dst` starting at sample `at` (growing `dst` as needed).
func _mix_at(dst: PackedFloat32Array, src: PackedFloat32Array, at: int) -> PackedFloat32Array:
	var out := dst.duplicate()
	if out.size() < at + src.size():
		out.resize(at + src.size())
	for i in src.size():
		out[at + i] += src[i]
	return out

## A short shared "room": four damped combs and a tail, mixed in at `wet`. The clip grows by `tail` seconds.
func _reverb(x: PackedFloat32Array, wet: float, tail: float) -> PackedFloat32Array:
	var n := x.size() + int(tail * rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var d := [int(0.0297 * rate), int(0.0371 * rate), int(0.0411 * rate), int(0.0437 * rate)]
	var fb := [0.74, 0.72, 0.7, 0.68]
	var b0 := PackedFloat32Array()
	var b1 := PackedFloat32Array()
	var b2 := PackedFloat32Array()
	var b3 := PackedFloat32Array()
	b0.resize(d[0])
	b1.resize(d[1])
	b2.resize(d[2])
	b3.resize(d[3])
	var i0 := 0
	var i1 := 0
	var i2 := 0
	var i3 := 0
	var s0 := 0.0
	var s1 := 0.0
	var s2 := 0.0
	var s3 := 0.0
	for i in n:
		var inp := x[i] if i < x.size() else 0.0
		var o0 := b0[i0]
		var o1 := b1[i1]
		var o2 := b2[i2]
		var o3 := b3[i3]
		s0 += 0.45 * (o0 - s0)
		s1 += 0.45 * (o1 - s1)
		s2 += 0.45 * (o2 - s2)
		s3 += 0.45 * (o3 - s3)
		b0[i0] = inp + s0 * fb[0]
		b1[i1] = inp + s1 * fb[1]
		b2[i2] = inp + s2 * fb[2]
		b3[i3] = inp + s3 * fb[3]
		i0 = (i0 + 1) % d[0]
		i1 = (i1 + 1) % d[1]
		i2 = (i2 + 1) % d[2]
		i3 = (i3 + 1) % d[3]
		var tailv := t_fade(i, x.size(), n)
		out[i] = inp + wet * 0.25 * (o0 + o1 + o2 + o3) * tailv
	return out

## The tail fades out smoothly over the last third of its length (so a clip never ends on a sound).
static func t_fade(i: int, body: int, n: int) -> float:
	var tail := n - body
	if tail <= 0 or i < n - tail / 3:
		return 1.0
	var k := float(n - i) / maxf(tail / 3.0, 1.0)
	return k * k

## The room for a loop: run the loop twice through the reverb and keep the second pass (a seamless tail).
func _reverb_loop(x: PackedFloat32Array, wet: float) -> PackedFloat32Array:
	var two := PackedFloat32Array()
	two.resize(x.size() * 2)
	for i in x.size():
		two[i] = x[i]
		two[x.size() + i] = x[i]
	var r := _reverb(two, wet, 0.0)
	return r.slice(x.size(), x.size() * 2)
