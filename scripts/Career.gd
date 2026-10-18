class_name Career
extends RefCounted
## The career: six ranks, what each unlocks, and the checkride (a fixed set of landings with standards) that earns the next rank.

const RANKS: Array[String] = ["STUDENT", "PRIVATE", "INSTRUMENT", "COMMERCIAL", "CFI", "AIRLINE CAPTAIN"]
## Career points needed before the checkride for rank i (index i) can be taken.
const POINTS_NEEDED: Array[int] = [0, 300, 900, 2000, 3600, 6000]

## What each rank adds (cumulative: a higher rank has everything below it).
const ADDS_PLANES: Array = [
	[Planes.C172, Planes.CUB], [], [Planes.TWIN], [Planes.GLIDER], [], [Planes.JET]]
const ADDS_SCENARIOS: Array = [
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD],
	[Scenarios.MOUNTAIN, Scenarios.ENGINE_OUT],
	[Scenarios.NIGHT],
	[Scenarios.WATER, Scenarios.TRUCK],
	[],
	[Scenarios.CARRIER]]
const ADDS_WEATHER: Array = [
	[Scenarios.CLEAR],
	[Scenarios.RAIN],
	[Scenarios.FOG],
	[Scenarios.TURBULENCE],
	[Scenarios.SHEAR],
	[]]

## The checkrides: RIDES[i] earns rank i + 1. Each landing is fixed (scenario, weather, aircraft, seed, difficulty round)
## with standards: touch down within `zone` of the markers, sink rate under `sink`, no bounce.
const RIDES: Array[Dictionary] = [
	{"landings": [
		{"scn": Scenarios.STANDARD, "wx": Scenarios.CLEAR, "plane": Planes.C172, "seed": 11, "round": 1, "zone": 14.0, "sink": 2.4},
		{"scn": Scenarios.SHORT_FIELD, "wx": Scenarios.CLEAR, "plane": Planes.C172, "seed": 12, "round": 3, "zone": 14.0, "sink": 2.4},
		{"scn": Scenarios.STANDARD, "wx": Scenarios.CLEAR, "plane": Planes.CUB, "seed": 13, "round": 2, "zone": 14.0, "sink": 2.4}]},
	{"landings": [
		{"scn": Scenarios.ENGINE_OUT, "wx": Scenarios.CLEAR, "plane": Planes.C172, "seed": 21, "round": 3, "zone": 12.0, "sink": 2.2},
		{"scn": Scenarios.MOUNTAIN, "wx": Scenarios.CLEAR, "plane": Planes.C172, "seed": 22, "round": 3, "zone": 12.0, "sink": 2.2},
		{"scn": Scenarios.STANDARD, "wx": Scenarios.RAIN, "plane": Planes.C172, "seed": 23, "round": 4, "zone": 12.0, "sink": 2.2},
		{"scn": Scenarios.SHORT_FIELD, "wx": Scenarios.CLEAR, "plane": Planes.CUB, "seed": 24, "round": 4, "zone": 12.0, "sink": 2.2}]},
	{"landings": [
		{"scn": Scenarios.NIGHT, "wx": Scenarios.CLEAR, "plane": Planes.C172, "seed": 31, "round": 4, "zone": 10.0, "sink": 2.0},
		{"scn": Scenarios.STANDARD, "wx": Scenarios.FOG, "plane": Planes.C172, "seed": 32, "round": 4, "zone": 10.0, "sink": 2.0},
		{"scn": Scenarios.STANDARD, "wx": Scenarios.CLEAR, "plane": Planes.TWIN, "seed": 33, "round": 5, "zone": 10.0, "sink": 2.0},
		{"scn": Scenarios.NIGHT, "wx": Scenarios.CLEAR, "plane": Planes.TWIN, "seed": 34, "round": 5, "zone": 10.0, "sink": 2.0}]},
	{"landings": [
		{"scn": Scenarios.WATER, "wx": Scenarios.CLEAR, "plane": Planes.C172, "seed": 41, "round": 5, "zone": 14.0, "sink": 1.9},
		{"scn": Scenarios.TRUCK, "wx": Scenarios.CLEAR, "plane": Planes.CUB, "seed": 42, "round": 5, "zone": 14.0, "sink": 2.4},
		{"scn": Scenarios.STANDARD, "wx": Scenarios.CLEAR, "plane": Planes.GLIDER, "seed": 43, "round": 5, "zone": 10.0, "sink": 1.9},
		{"scn": Scenarios.STANDARD, "wx": Scenarios.TURBULENCE, "plane": Planes.C172, "seed": 44, "round": 6, "zone": 10.0, "sink": 1.9}]},
	{"landings": [
		{"scn": Scenarios.MOUNTAIN, "wx": Scenarios.FOG, "plane": Planes.C172, "seed": 51, "round": 6, "zone": 10.0, "sink": 2.0},
		{"scn": Scenarios.STANDARD, "wx": Scenarios.SHEAR, "plane": Planes.C172, "seed": 52, "round": 6, "zone": 8.0, "sink": 1.6},
		{"scn": Scenarios.ENGINE_OUT, "wx": Scenarios.CLEAR, "plane": Planes.TWIN, "seed": 53, "round": 6, "zone": 8.0, "sink": 1.6},
		{"scn": Scenarios.NIGHT, "wx": Scenarios.CLEAR, "plane": Planes.TWIN, "seed": 54, "round": 7, "zone": 8.0, "sink": 1.6},
		{"scn": Scenarios.SHORT_FIELD, "wx": Scenarios.FOG, "plane": Planes.C172, "seed": 55, "round": 7, "zone": 8.0, "sink": 1.6}]},
]

static func rank_name(r: int) -> String:
	return RANKS[clampi(r, 0, RANKS.size() - 1)]

static func max_rank() -> int:
	return RANKS.size() - 1

## The aircraft / scenarios / weather open at a rank (everything with `unlock_all`).
static func planes(rank: int, unlock_all: bool = false) -> Array[int]:
	var out: Array[int] = []
	for i in Planes.COUNT:
		if unlock_all or _has(ADDS_PLANES, rank, i):
			out.append(i)
	return out

static func scenarios(rank: int, unlock_all: bool = false) -> Array[int]:
	var out: Array[int] = []
	for i in Scenarios.COUNT:
		if unlock_all or _has(ADDS_SCENARIOS, rank, i):
			out.append(i)
	return out

static func weather(rank: int, unlock_all: bool = false) -> Array[int]:
	var out: Array[int] = []
	for i in Scenarios.WX_COUNT:
		if unlock_all or _has(ADDS_WEATHER, rank, i):
			out.append(i)
	return out

static func _has(table: Array, rank: int, item: int) -> bool:
	for r in range(0, clampi(rank, 0, table.size() - 1) + 1):
		if (table[r] as Array).has(item):
			return true
	return false

## What reaching `rank` unlocks, as text lines ("Aircraft: TWIN", "Scenarios: NIGHT", "Weather: FOG").
static func unlock_lines(rank: int) -> Array[String]:
	var out: Array[String] = []
	var ap: Array = ADDS_PLANES[clampi(rank, 0, ADDS_PLANES.size() - 1)]
	var asc: Array = ADDS_SCENARIOS[clampi(rank, 0, ADDS_SCENARIOS.size() - 1)]
	var aw: Array = ADDS_WEATHER[clampi(rank, 0, ADDS_WEATHER.size() - 1)]
	if not ap.is_empty():
		out.append("Aircraft: " + ", ".join(ap.map(func(i): return Planes.NAMES[i])))
	if not asc.is_empty():
		out.append("Scenarios: " + ", ".join(asc.map(func(i): return Scenarios.NAMES[i].capitalize())))
	if not aw.is_empty():
		out.append("Weather: " + ", ".join(aw.map(func(i): return Scenarios.WX_NAMES[i].capitalize())))
	return out

## Career points needed to take the checkride for the next rank (0 at the top).
static func points_for_next(rank: int) -> int:
	return POINTS_NEEDED[rank + 1] if rank < max_rank() else 0

static func eligible(rank: int, points: int) -> bool:
	return rank < max_rank() and points >= POINTS_NEEDED[rank + 1]

## The checkride that earns rank + 1 ({} at the top).
static func ride_for(rank: int) -> Dictionary:
	if rank >= max_rank():
		return {}
	return RIDES[rank]

static func standard_lines(entry: Dictionary) -> Array[String]:
	return ["Touch down within %.0f m of the markers" % float(entry["zone"]), "Sink rate under %.1f" % float(entry["sink"]), "No bounce"]

## Judge one checkride landing. `result` = {sink, offset, bounced}; `crashed` = the approach ended in a crash.
## Returns {"pass": bool, "fails": Array[String]}.
static func judge(entry: Dictionary, result: Dictionary, crashed: bool) -> Dictionary:
	var fails: Array[String] = []
	if crashed:
		fails.append("Crashed")
	else:
		var off := absf(float(result.get("offset", 999.0)))
		if off > float(entry["zone"]):
			fails.append("%.0f m from the markers (limit %.0f)" % [off, float(entry["zone"])])
		var sink := float(result.get("sink", 99.0))
		if sink > float(entry["sink"]):
			fails.append("Sink %.1f (limit %.1f)" % [sink, float(entry["sink"])])
		if bool(result.get("bounced", false)):
			fails.append("Bounced")
	return {"pass": fails.is_empty(), "fails": fails}
