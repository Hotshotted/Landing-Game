class_name Save
extends RefCounted
## Everything that persists, as one versioned JSON document in user:// (browser storage on web): best scores, career rank and
## points, logbook totals, airport stamps and checkride records. Tests switch the file off (`enabled = false`) and work on the
## in-memory `data`; `to_text()` / `load_text()` let them check the round trip and the migrations.
##
## Versions: 0 = the old best-score-only file (user://greaser.cfg); 1 = the first JSON document (six ranks, career points);
## 2 = this one (eight ranks, proficiency meters, pink slips). A document from a NEWER build is
## kept as it is (unknown keys survive), and anything unreadable falls back to a fresh save instead of crashing.

const VERSION := 2
## Version 1 had six ranks (Student, Private, Instrument, Commercial, CFI, Airline); where they sit on the eight-rank ladder.
const RANK_MAP_V1: Array[int] = [0, 3, 4, 5, 6, 7]
const OLD_PATH := "user://greaser.cfg"

static var enabled := true
static var path := "user://greaser.json"
static var data: Dictionary = default_data()

static func default_data() -> Dictionary:
	return {
		"version": VERSION,
		"best": 0,               # best run score
		"best_streak": 0,        # best Greaser streak
		"rank": 0,               # 0 Student .. 7 Airline Captain (see Career.RANKS)
		"landings": 0,
		"crashes": 0,
		"flight_seconds": 0.0,
		"grades": [0, 0, 0, 0, 0],   # landings per grade: Greaser! / Smooth / Good / Firm / Hard
		"airports": {},          # airport id -> {"name": String, "day": int (first visit, days since 1970), "n": landings}
		"checkrides": {},        # target rank (as text) -> {"passes": int, "attempts": int}
		"proficiency": {"tier": 0, "counts": {}},   # practice landings that met the standard, per landing type (scenario id as text)
		"pink_slips": [],        # failed checkrides, for good: {"day": int, "rank": int (the rank tried for), "type": int (the failed landing type)}
		"fee_halved": false,     # the rewarded ad: the next examiner fee is halved
		"plane": 1,              # the aircraft last flown
		"unlock_all": false,     # ?tune debug: every rank, aircraft and scenario open
		"coins": 0,              # spent on paint and pilot gear
		"paint": 0,              # equipped paint scheme (index into Cosmetics.PAINTS)
		"gear": 0,               # equipped pilot gear (index into Cosmetics.GEAR)
		"owned_paint": [0],
		"owned_gear": [0],
		"daily": {"day": -1, "best": 0, "tries": 0},   # the daily approach: which day, best score, attempts that day
	}

## Read the save file (or migrate the old one). With the file switched off the in-memory data is left alone.
static func load_data() -> void:
	if not enabled:
		return
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			load_text(f.get_as_text())
			return
	var cfg := ConfigFile.new()
	if cfg.load(OLD_PATH) == OK:        # version 0: only the best score
		data = migrate({"best": int(cfg.get_value("run", "best", 0))})
		return
	data = default_data()

static func store() -> void:
	if not enabled:
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(to_text())

static func to_text() -> String:
	return JSON.stringify(data)

## Load a save document from text. Returns false (and starts a fresh save) if it can't be read.
static func load_text(text: String) -> bool:
	var parsed = JSON.parse_string(text)
	if not (parsed is Dictionary):
		data = default_data()
		return false
	data = migrate(parsed as Dictionary)
	return true

## Bring a save document up to the current version: missing keys get defaults, wrong types are repaired, unknown keys survive.
static func migrate(d: Dictionary) -> Dictionary:
	var out := default_data()
	var v := int(d.get("version", 0))
	for k in d:
		out[k] = d[k]
	for k in ["best", "best_streak", "rank", "landings", "crashes", "plane", "coins", "paint", "gear"]:
		out[k] = int(d.get(k, out[k]))
	out.erase("career_points")
	if v < 2:
		out["rank"] = RANK_MAP_V1[clampi(int(d.get("rank", 0)), 0, RANK_MAP_V1.size() - 1)]
		var old_cr: Dictionary = d.get("checkrides", {}) if d.get("checkrides", {}) is Dictionary else {}
		var new_cr: Dictionary = {}
		for k in old_cr:
			new_cr[str(RANK_MAP_V1[clampi(int(k), 0, RANK_MAP_V1.size() - 1)])] = old_cr[k]
		out["checkrides"] = new_cr
	out["rank"] = clampi(int(out["rank"]), 0, 7)
	out["plane"] = clampi(int(out["plane"]), 0, 4)
	out["flight_seconds"] = float(d.get("flight_seconds", 0.0))
	var g: Array = [0, 0, 0, 0, 0]
	var gin = d.get("grades", g)
	if gin is Array:
		for i in mini((gin as Array).size(), 5):
			g[i] = int((gin as Array)[i])
	out["grades"] = g
	for k in ["airports", "checkrides"]:
		if k == "checkrides" and v < 2:
			continue          # (already mapped to the new ladder above)
		var dv = d.get(k, {})
		out[k] = dv if dv is Dictionary else {}
	out["unlock_all"] = bool(d.get("unlock_all", false))
	out["fee_halved"] = bool(d.get("fee_halved", false))
	var pf: Dictionary = {"tier": 0, "counts": {}}
	var pin = d.get("proficiency", {})
	if pin is Dictionary:
		pf["tier"] = int((pin as Dictionary).get("tier", 0))
		var cin = (pin as Dictionary).get("counts", {})
		if cin is Dictionary:
			for k in cin:
				pf["counts"][str(k)] = maxi(int(cin[k]), 0)
	out["proficiency"] = pf
	var slips: Array = []
	var sin = d.get("pink_slips", [])
	if sin is Array:
		for it in sin:
			if it is Dictionary:
				slips.append({"day": int(it.get("day", 0)), "rank": int(it.get("rank", 1)), "type": int(it.get("type", 0))})
	out["pink_slips"] = slips
	for k in ["owned_paint", "owned_gear"]:
		var own: Array = [0]
		var oin = d.get(k, own)
		if oin is Array:
			for item in oin:
				if int(item) > 0 and not own.has(int(item)):
					own.append(int(item))
		out[k] = own
	out["paint"] = clampi(int(out["paint"]), 0, 99)
	out["gear"] = clampi(int(out["gear"]), 0, 99)
	var dl = d.get("daily", {})
	var daily: Dictionary = {"day": -1, "best": 0, "tries": 0}
	if dl is Dictionary:
		for k in daily:
			daily[k] = int((dl as Dictionary).get(k, daily[k]))
	out["daily"] = daily
	out["version"] = maxi(v, VERSION)
	return out

static func reset_all() -> void:
	data = default_data()
	store()

static func load_best() -> int:
	return int(data["best"])

static func store_best(v: int) -> void:
	data["best"] = v
	store()

static func add(key: String, n: Variant) -> void:
	data[key] = data[key] + n

static func add_grade(grade: int, n: int = 1) -> void:
	var g: Array = data["grades"]
	g[clampi(grade, 0, 4)] = int(g[clampi(grade, 0, 4)]) + n

## Record a landing at an airport (first visit stamps it). Returns true if this was the first visit.
static func stamp_airport(id: String, airport_name: String, day: int) -> bool:
	var ap: Dictionary = data["airports"]
	if ap.has(id):
		ap[id]["n"] = int(ap[id]["n"]) + 1
		return false
	ap[id] = {"name": airport_name, "day": day, "n": 1}
	return true

static func record_checkride(to_rank: int, passed: bool) -> void:
	var cr: Dictionary = data["checkrides"]
	var key := str(to_rank)
	var rec: Dictionary = cr.get(key, {"passes": 0, "attempts": 0})
	rec["attempts"] = int(rec["attempts"]) + 1
	if passed:
		rec["passes"] = int(rec["passes"]) + 1
	cr[key] = rec

## A failed checkride goes in the logbook for good.
static func add_slip(day: int, rank: int, type: int) -> void:
	(data["pink_slips"] as Array).append({"day": day, "rank": rank, "type": type})
