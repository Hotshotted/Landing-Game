class_name Sfx
extends Node
## Greaser's sound: soft, rounded, cozy, all in C major pentatonic (docs/style.md, "Audio"; the studio's direction, shared with
## Pattern-Control). NOTHING is synthesised at run time: every sound is a pre-rendered 44.1 kHz 16-bit WAV in assets/audio/ (made by
## tools/render_audio.gd from scripts/SfxSynth.gd). One-shots play from a pool of players, always on a FREE player so a sounding
## one is never cut off. The continuous sounds (the music layers, the engine beds, wind and rain) are loops: on the web the PAGE
## plays them (PWAudio in web/shell.html: native, gapless AudioBufferSource loops off the main thread, which Godot's own web
## loops are not) and this script only tells it the level of each layer; elsewhere (the editor, the tests) they are ordinary
## looping players. Buses come from default_bus_layout.tres and are never created at run time.

enum { SQUEAK, THUD, CRASH, CHIME, WHOOSH, TAP, COIN, STAMP, TROMBONE, SIGN, FANFARE, SKID, BOOM, BACK, CONFIRM, DENY, PAGE }
const NAMES := ["squeak", "thud", "crash", "chime", "whoosh", "tap", "coin", "stamp", "trombone", "sign", "fanfare", "skid", "boom", "back", "confirm", "deny", "page"]
const STEPS := 7               # chimes and coin plinks: this many steps up the scale
const POOL := 8
const LAYERS := ["calm", "hot", "tense", "engine_cub", "engine_172", "engine_twin", "engine_jet", "wind", "rain"]
const ENGINE_LAYERS := ["engine_cub", "engine_172", "engine_twin", "", "engine_jet"]      # by aircraft kind (the glider has none)
const FADE_DB_PER_S := 60.0
const MENU_CALM_DB := -8.0
const FLIGHT_CALM_DB := -4.0

signal page_hidden(hidden: bool)
var enabled := true
var plays := {}                # sound name -> how many times it was triggered
var held := false              # audio is held (the page went to the background): the Master bus is muted
var web_loops := false         # the page plays the loops (web build)
var unlocked := false          # the first user gesture has happened (browsers keep audio suspended until then)
var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _players := {}             # layer -> its looping player (not on the web)
var _goal_db := {}             # layer -> the level it should have (dB, before its bus)
var _cur_db := {}              # ... and the level it has now (it glides, so nothing jumps)
var _js_sent := {}             # layer -> the level last sent to the page
var _mood := 0.0               # 0 = menu music, 1 = flying music (eases)
var _mood_goal := 0.0
var _tension := 0.0
var _tension_goal := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS       # (the levels keep gliding and the page is watched while the game is paused)
	_rng.randomize()
	for n in NAMES:
		plays[n] = 0
	for l in LAYERS:
		_goal_db[l] = -80.0
		_cur_db[l] = -80.0
	if DebugFlags.off("sfx"):
		enabled = false
		return
	web_loops = OS.has_feature("web") and bool(JavaScriptBridge.eval("!!(window.PWAudio && window.PWAudio.enabled)"))
	for n in NAMES:
		if n == "chime" or n == "coin":
			for k in STEPS:
				_streams["%s_%d" % [n, k]] = load("res://assets/audio/%s_%d.wav" % [n, k])
		else:
			_streams[n] = load("res://assets/audio/%s.wav" % n)
	for i in POOL:
		_pool.append(_player("SFX"))
	if not web_loops:
		for l in LAYERS:
			_players[l] = _loop_player(l, "Music" if l == "calm" or l == "hot" or l == "tense" else "Ambience")

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus if AudioServer.get_bus_index(bus) >= 0 else "Master"      # (a missing bus must never be named: the web build aborts)
	add_child(p)
	return p

## A looping layer as an ordinary looping player (the editor and the tests; on the web the page does this).
func _loop_player(layer: String, bus: String) -> AudioStreamPlayer:
	var p := _player(bus)
	var st = load("res://assets/audio/loops/%s.wav" % layer)
	if st is AudioStreamWAV:
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_begin = 0
		st.loop_end = st.data.size() / 2
		p.stream = st
	p.volume_db = -80.0
	return p

# ---------- one-shots ----------

## A one-shot by kind. `pitch` is ignored (the sounds are in key and never shifted; each play gets about +-1%); `db` can only make
## it quieter: no gameplay sound may be louder than the music.
func play(kind: int, _pitch: float = 1.0, db: float = 0.0) -> void:
	var nm: String = NAMES[clampi(kind, 0, NAMES.size() - 1)]
	if nm == "chime" or nm == "coin":
		play_step(kind, 0, db)
		return
	plays[nm] = int(plays.get(nm, 0)) + 1
	if not enabled or not _streams.has(nm):
		return
	_fire(_streams[nm], minf(db, 0.0))

## A chime or a coin plink `step` notes up the scale (0..STEPS-1): streaks and the cash-out count climb it.
func play_step(kind: int, step: int, db: float = 0.0) -> void:
	var nm: String = NAMES[clampi(kind, 0, NAMES.size() - 1)]
	plays[nm] = int(plays.get(nm, 0)) + 1
	if not enabled:
		return
	var key := "%s_%d" % [nm, clampi(step, 0, STEPS - 1)]
	if _streams.has(key):
		_fire(_streams[key], minf(db, 0.0))

func _fire(stream: AudioStream, db: float) -> void:
	var p := _pool[_next]
	for k in POOL:     # a free player first: taking over one that is still sounding would cut it off with a click
		var q := _pool[(_next + k) % POOL]
		if not q.playing:
			p = q
			_next = (_next + k) % POOL
			break
	_next = (_next + 1) % POOL
	p.stream = stream
	p.pitch_scale = _rng.randf_range(0.99, 1.01)
	p.volume_db = _rng.randf_range(-0.5, 0.0) + db
	p.play()

# ---------- continuous layers: music, engines, wind, rain ----------

## The engine bed of aircraft `kind` (0 Cub, 1 172, 2 twin, 3 glider, 4 jet), the wind and the rain, each 0..1. (`pitch` is ignored:
## the beds are in key.) The levels glide in _process.
func set_loops(kind: int, engine: float, _pitch: float, wind: float, rain: float) -> void:
	var eng_layer: String = ENGINE_LAYERS[clampi(kind, 0, 4)]
	for l in ENGINE_LAYERS:
		if l != "":
			_goal_db[l] = (linear_to_db(maxf(engine, 0.0001)) - 3.0) if (l == eng_layer and engine > 0.01) else -80.0
	_goal_db["wind"] = (linear_to_db(maxf(wind, 0.0001)) - 3.0) if wind > 0.01 else -80.0
	_goal_db["rain"] = (linear_to_db(maxf(rain, 0.0001)) - 3.0) if rain > 0.01 else -80.0

func loops_off() -> void:
	for l in ["engine_cub", "engine_172", "engine_twin", "engine_jet", "wind", "rain"]:
		_goal_db[l] = -80.0

## How loud the engine bed of the current aircraft is now (0..1).
func engine_level() -> float:
	var best := -80.0
	for l in ENGINE_LAYERS:
		if l != "":
			best = maxf(best, float(_cur_db[l]))
	return db_to_linear(best + 3.0) if best > -75.0 else 0.0

## 0 = the menu's calm music, 1 = the flying music (a calm pad plus a soft arpeggio): they crossfade smoothly.
func set_mood(m: float) -> void:
	_mood_goal = clampf(m, 0.0, 1.0)

func mood() -> float:
	return _mood

## The heartbeat of the push-your-luck: a low, soft, tense drone under the music that rises with `level` (0..1) and brings the
## arpeggio forward. The key never changes.
func set_tension(level: float) -> void:
	_tension_goal = clampf(level, 0.0, 1.0)

func tension() -> float:
	return _tension

func _process(delta: float) -> void:
	_poll_page(delta)
	if not enabled:
		return
	_mood = move_toward(_mood, _mood_goal, delta / 1.2)
	_tension = move_toward(_tension, _tension_goal, delta * (0.9 if _tension_goal > _tension else 0.5))
	_goal_db["calm"] = lerpf(MENU_CALM_DB, FLIGHT_CALM_DB, _mood)
	_goal_db["hot"] = (linear_to_db(maxf(_mood * (0.3 + 0.7 * _tension) * 0.8, 0.0001)) - 6.0) if _mood > 0.02 else -80.0
	_goal_db["tense"] = (linear_to_db(maxf(_tension * 0.9, 0.0001)) - 9.0) if _tension > 0.02 else -80.0
	for l in LAYERS:
		_cur_db[l] = move_toward(float(_cur_db[l]), float(_goal_db[l]), FADE_DB_PER_S * delta)
		_apply(l)
	if web_loops:
		_push_levels()

func _apply(layer: String) -> void:
	var p: AudioStreamPlayer = _players.get(layer)
	if p == null:
		return
	var db := float(_cur_db[layer])
	if db <= -75.0:
		if p.playing and float(_goal_db[layer]) <= -75.0:
			p.stop()
		p.volume_db = -80.0
		return
	if not p.playing and p.stream != null:
		p.play()
	p.volume_db = db

# ---------- the page, the first tap, the background ----------

var _poll_t := 0.0
var _page_was_hidden := false

## Web: the page keeps `window.__pwHidden` (visibilitychange, pagehide, blur); tell the game when it changes.
func _poll_page(delta: float) -> void:
	if not OS.has_feature("web"):
		return
	_poll_t += delta
	if _poll_t < 0.25:
		return
	_poll_t = 0.0
	var h := bool(JavaScriptBridge.eval("!!window.__pwHidden"))
	if h != _page_was_hidden:
		_page_was_hidden = h
		page_hidden.emit(h)


## The first touch: browsers only let audio run after a gesture. Looping players started while the page was still locked are
## restarted now, so they begin cleanly with the audio context running.
func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	if not enabled:
		return
	for p in _players.values():
		if p.playing:
			p.stop()
			p.play()

## The page went to the background (or the phone was locked): hold everything silent. Nothing resumes until `release()`.
func hold() -> void:
	held = true
	AudioServer.set_bus_mute(0, true)
	if web_loops:
		JavaScriptBridge.eval("window.PWAudio && PWAudio.setHeld(true)")

## The player is back and tapped (Resume): sound may run again.
func release() -> void:
	held = false
	AudioServer.set_bus_mute(0, false)
	if web_loops:
		JavaScriptBridge.eval("window.PWAudio && PWAudio.setHeld(false)")

## The bus a layer sits on: Music for the music, Ambience for the engines, wind and rain (their volume sliders and mutes apply).
func _bus_db(layer: String) -> float:
	var idx := AudioServer.get_bus_index("Music" if layer == "calm" or layer == "hot" or layer == "tense" else "Ambience")
	if idx < 0:
		return 0.0
	return -80.0 if AudioServer.is_bus_mute(idx) else AudioServer.get_bus_volume_db(idx)

## Tell the page the level of every layer that changed (one small call per frame at most).
func _push_levels() -> void:
	var changed := ""
	for n in LAYERS:
		var out_db := maxf(float(_cur_db[n]) + _bus_db(n), -80.0)
		if not _js_sent.has(n) or absf(out_db - float(_js_sent[n])) > 0.05:
			_js_sent[n] = out_db
			changed += "%s:%.2f," % [n, out_db]
	if changed != "":
		JavaScriptBridge.eval("window.PWAudio.setMany({" + changed + "})")
