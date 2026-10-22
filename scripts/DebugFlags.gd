class_name DebugFlags
extends RefCounted
## Debug switches, read from the page URL on web (or "--flag=value" user args elsewhere), so a
## suspected cause of a hitch can be switched off from a phone without a new build:
##   ?nofx=smoke,shake,popup,wind,clouds,sfx,haptic   turn those effects off
##   ?nofx=all                                         turn all of them off
##   ?noprewarm                                        skip the start-up pre-warm and splash
##   ?perf                                             show a worst-frame-time readout
##   ?tune                                             show the on-screen tuning panel (TUNE button, top-right)
##   ?god                                              obstacles and crash-level sink can't crash the plane (to look around)
##   ?round=N                                          start the run at round N (difficulty, terrain)
##   ?seed=N                                           fixed random seed (same rounds every run)
##   ?scenario=short|engineout|night|mountain|carrier|water|truck|standard   force that scenario every approach
##   ?weather=fog|rain|turbulence|shear|clear          force that weather every approach
##   ?plane=cub|172|twin|glider|jet                    start in that aircraft
##   ?debug                                            show the build stamp (also shown with ?tune and ?perf)
##   ?tod=day|dusk                                     force the time of day (cosmetic)
##   ?closeup                                          frame the aircraft close from the start (screenshots)
##   ?nologo                                           skip the studio logo intro
##   ?noads                                            no ad stubs (interstitials)
##   ?screen=certificate|slip|career|logbook|hangar|choice|pause     open that screen at start (to look at it)
## Combine with "&", e.g.  ?nofx=smoke&noprewarm&perf
## The active flags are printed under the build stamp.

const EFFECTS := ["smoke", "shake", "popup", "wind", "clouds", "sfx", "haptic"]

static var _loaded := false
static var _off := {}                  # effect name -> true
static var _bad: Array[String] = []    # unknown names (typos), shown in the summary
static var noprewarm := false
static var perf := false
static var tune := false
static var god := false
static var start_round := 1
static var seed_value := -1
static var scenario_value := -1
static var weather_value := -1
static var plane_value := -1
static var noads := false
static var nologo := false
static var closeup := false
static var tod_value := -1
static var debug := false
static var screen_value := ""

## True if the named effect has been switched off.
static func off(effect: String) -> bool:
	_load()
	return _off.has(effect)

static func prewarm_enabled() -> bool:
	_load()
	return not noprewarm

static func perf_enabled() -> bool:
	_load()
	return perf

## The build stamp (commit, time, active flags) shows only for ?debug, ?tune or ?perf.
static func tod_forced() -> int:
	_load()
	return tod_value

static func closeup_enabled() -> bool:
	_load()
	return closeup

static func stamp_enabled() -> bool:
	_load()
	return debug or tune or perf

static func tune_enabled() -> bool:
	_load()
	return tune

static func god_enabled() -> bool:
	_load()
	return god

static func first_round() -> int:
	_load()
	return start_round

static func seed_number() -> int:
	_load()
	return seed_value

static func scenario_forced() -> int:
	_load()
	return scenario_value

static func weather_forced() -> int:
	_load()
	return weather_value

static func screen() -> String:
	_load()
	return screen_value

static func ads_enabled() -> bool:
	_load()
	return not noads

static func plane_forced() -> int:
	_load()
	return plane_value

## One-line description of the active flags ("" when none), shown next to the build stamp.
static func summary() -> String:
	_load()
	var parts: Array[String] = []
	if not _off.is_empty():
		var names: Array[String] = []
		for e in EFFECTS:
			if _off.has(e):
				names.append(e)
		parts.append("nofx=" + ",".join(names))
	if noprewarm:
		parts.append("noprewarm")
	if perf:
		parts.append("perf")
	if tune:
		parts.append("tune")
	if god:
		parts.append("god")
	if start_round > 1:
		parts.append("round=%d" % start_round)
	if seed_value >= 0:
		parts.append("seed=%d" % seed_value)
	if scenario_value >= 0:
		parts.append("scenario=" + Scenarios.KEYS[scenario_value])
	if weather_value >= 0:
		parts.append("weather=" + Scenarios.WX_KEYS[weather_value])
	if plane_value >= 0:
		parts.append("plane=" + Planes.KEYS[plane_value])
	if noads:
		parts.append("noads")
	if screen_value != "":
		parts.append("screen=" + screen_value)
	for b in _bad:
		parts.append("?" + b)
	return " ".join(parts)

static func _load() -> void:
	if _loaded:
		return
	var args: Array[String] = []
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search")
		if q is String:
			for part in (q as String).trim_prefix("?").split("&", false):
				args.append(part)
	for a in OS.get_cmdline_user_args():
		args.append(a.trim_prefix("--"))
	parse(args)

## Parse "key" / "key=value" strings. Public so tests can feed it.
static func parse(args: Array[String]) -> void:
	_loaded = true
	_off.clear()
	_bad.clear()
	noprewarm = false
	perf = false
	tune = false
	god = false
	start_round = 1
	seed_value = -1
	scenario_value = -1
	weather_value = -1
	plane_value = -1
	noads = false
	nologo = false
	closeup = false
	tod_value = -1
	debug = false
	screen_value = ""
	for a in args:
		var kv := a.split("=", true, 1)
		var key := kv[0].uri_decode().to_lower()
		var val := kv[1].uri_decode().to_lower() if kv.size() > 1 else ""
		match key:
			"nofx":
				for name in val.split(",", false):
					if name == "all":
						for e in EFFECTS:
							_off[e] = true
					elif EFFECTS.has(name):
						_off[name] = true
					else:
						_bad.append(name)
			"noprewarm":
				noprewarm = true
			"noads":
				noads = true
			"nologo":
				nologo = true
			"tod":
				tod_value = 1 if val == "dusk" else 0
			"closeup":
				closeup = true
			"debug":
				debug = true
			"screen":
				screen_value = val
			"perf":
				perf = true
			"tune":
				tune = true
			"god":
				god = true
			"round":
				start_round = maxi(int(val), 1)
			"seed":
				seed_value = maxi(int(val), 0)
			"scenario":
				scenario_value = Scenarios.scenario_from_key(val)
				if scenario_value < 0:
					_bad.append("scenario=" + val)
			"plane":
				plane_value = Planes.from_key(val)
				if plane_value < 0:
					_bad.append("plane=" + val)
			"weather":
				weather_value = Scenarios.weather_from_key(val)
				if weather_value < 0:
					_bad.append("weather=" + val)
			"v":
				pass  # cache-busting parameter added by the page, not a flag
			_:
				_bad.append(key)
