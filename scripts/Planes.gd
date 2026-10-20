class_name Planes
extends RefCounted
## The aircraft. Each has a handling profile (multipliers on the Tuning flight-model values, so ?tune still scales
## everything), a look, and the scenarios / weather it is offered.
##   Cub    - slow, floaty, short landings, bumpy in gusts
##   172    - the balanced baseline
##   Twin   - fast, needs long runways
##   Glider - no power, a long float, ONE attempt
##   Jet    - very fast, needs long runways, stable in gusts

enum { CUB, C172, TWIN, GLIDER, JET }
const COUNT := 5
const KEYS: Array[String] = ["cub", "172", "twin", "glider", "jet"]
const NAMES: Array[String] = ["CUB", "172", "TWIN", "GLIDER", "JET"]

## Speed and stall speed are NOT in the table: they come from the Tuning knots (vref_*, stall_*): speed = Vref / 65 (times the
## 172's approach_speed), stall = stall kt / Vref kt (see `profile`).
## sink / lift / response / bleed / recover / ge / decel / gust are multipliers (1.0 = the 172); sink 1.0 = the 3 degree path;
## power 0 = no engine; attempts = crashes allowed per run; min_len = shortest runway it will be given;
## tough = multiplier on the structural touchdown limit; scale = how big it is drawn; body / accent = the paint; kind = which model.
const PROFILES: Array[Dictionary] = [
	{"name": "CUB", "blurb": "Slow and floaty. Lands short, but gusts push it around.",
		"sink": 1.0, "lift": 0.85, "response": 1.15, "bleed": 0.8, "recover": 1.0, "ge": 1.25,
		"decel": 1.4, "gust": 1.25, "power": 1.0, "attempts": 3, "min_len": 0.0, "scale": 0.85, "tough": 1.0,
		"body": Color(1.0, 0.86, 0.25), "accent": Color(0.75, 0.2, 0.15), "kind": 0},
	{"name": "172", "blurb": "The balanced all-rounder.",
		"sink": 1.0, "lift": 1.0, "response": 1.0, "bleed": 1.0, "recover": 1.0, "ge": 1.0,
		"decel": 1.0, "gust": 1.0, "power": 1.0, "attempts": 3, "min_len": 0.0, "scale": 1.0, "tough": 1.0,
		"body": Color(0.96, 0.94, 0.88), "accent": Color(0.86, 0.2, 0.18), "kind": 1},
	{"name": "TWIN", "blurb": "Fast and heavy. Needs a long runway.",
		"sink": 1.0, "lift": 1.0, "response": 0.95, "bleed": 0.9, "recover": 1.2, "ge": 0.9,
		"decel": 0.85, "gust": 0.8, "power": 1.0, "attempts": 3, "min_len": 450.0, "scale": 1.15, "tough": 1.1,
		"body": Color(0.92, 0.94, 0.97), "accent": Color(0.2, 0.35, 0.75), "kind": 2},
	{"name": "GLIDER", "blurb": "No engine. A long, quiet float. One attempt only.",
		"sink": 1.5, "lift": 1.0, "response": 1.2, "bleed": 0.7, "recover": 0.0, "ge": 1.8,
		"decel": 1.0, "gust": 1.1, "power": 0.0, "attempts": 1, "min_len": 0.0, "scale": 1.0, "tough": 0.9,
		"body": Color(0.97, 0.97, 0.99), "accent": Color(1.0, 0.55, 0.12), "kind": 3},
	{"name": "JET", "blurb": "Very fast and very stable. Long runways only.",
		"sink": 1.0, "lift": 1.0, "response": 0.9, "bleed": 0.6, "recover": 1.4, "ge": 0.8,
		"decel": 0.75, "gust": 0.45, "power": 1.0, "attempts": 3, "min_len": 650.0, "scale": 1.1, "tough": 1.5,
		"body": Color(0.72, 0.75, 0.8), "accent": Color(0.2, 0.22, 0.28), "kind": 4},
]

## Scenarios and weather each aircraft is offered (a forced ?scenario= / ?weather= still wins).
const SCENARIOS: Array = [
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.ENGINE_OUT, Scenarios.NIGHT, Scenarios.MOUNTAIN, Scenarios.WATER, Scenarios.TRUCK, Scenarios.SOFT_FIELD, Scenarios.POWER_OFF],
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.ENGINE_OUT, Scenarios.NIGHT, Scenarios.MOUNTAIN, Scenarios.WATER, Scenarios.TRUCK, Scenarios.SOFT_FIELD, Scenarios.POWER_OFF, Scenarios.INSTRUMENT],
	[Scenarios.STANDARD, Scenarios.ENGINE_OUT, Scenarios.NIGHT, Scenarios.POWER_OFF, Scenarios.INSTRUMENT],
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.MOUNTAIN, Scenarios.SOFT_FIELD],
	[Scenarios.STANDARD, Scenarios.NIGHT, Scenarios.CARRIER, Scenarios.ENGINE_OUT, Scenarios.INSTRUMENT],
]
const WEATHER: Array = [
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.RAIN, Scenarios.TURBULENCE, Scenarios.SHEAR],
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.RAIN, Scenarios.TURBULENCE, Scenarios.SHEAR],
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.RAIN, Scenarios.TURBULENCE, Scenarios.SHEAR],
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.TURBULENCE, Scenarios.SHEAR],      # a glider doesn't fly in rain
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.RAIN, Scenarios.TURBULENCE, Scenarios.SHEAR],
]

## The profile with its speeds filled in from Tuning: "vref" / "stall_kt" (knots), "speed" (x the 172's approach speed),
## "stall" (stall speed as a fraction of the approach speed).
static func profile(id: int) -> Dictionary:
	var i := clampi(id, 0, COUNT - 1)
	var pr: Dictionary = (PROFILES[i] as Dictionary).duplicate()
	var v := vref(i)
	pr["vref"] = v
	pr["stall_kt"] = stall_kt(i)
	pr["speed"] = v / Tuning.vref_172
	pr["stall"] = stall_kt(i) / v
	return pr

static func vref(id: int) -> float:
	match clampi(id, 0, COUNT - 1):
		CUB: return Tuning.vref_cub
		C172: return Tuning.vref_172
		TWIN: return Tuning.vref_twin
		GLIDER: return Tuning.vref_glider
	return Tuning.vref_jet

static func stall_kt(id: int) -> float:
	match clampi(id, 0, COUNT - 1):
		CUB: return Tuning.stall_cub
		C172: return Tuning.stall_172
		TWIN: return Tuning.stall_twin
		GLIDER: return Tuning.stall_glider
	return Tuning.stall_jet

static func scenarios(id: int) -> Array[int]:
	var out: Array[int] = []
	for v in SCENARIOS[clampi(id, 0, COUNT - 1)]:
		out.append(int(v))
	return out

static func weather(id: int) -> Array[int]:
	var out: Array[int] = []
	for v in WEATHER[clampi(id, 0, COUNT - 1)]:
		out.append(int(v))
	return out

static func offers(id: int, scn: int) -> bool:
	return (SCENARIOS[clampi(id, 0, COUNT - 1)] as Array).has(scn)

## Coins to buy an aircraft (0 for the Cub, which every pilot has).
static func price(id: int) -> int:
	match clampi(id, 0, COUNT - 1):
		CUB: return 0
		C172: return int(Tuning.price_172)
		TWIN: return int(Tuning.price_twin)
		GLIDER: return int(Tuning.price_glider)
	return int(Tuning.price_jet)

static func attempts(id: int) -> int:
	return int(profile(id)["attempts"])

static func from_key(key: String) -> int:
	return KEYS.find(key.to_lower())
