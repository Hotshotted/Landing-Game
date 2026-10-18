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

## speed / sink / lift / response / bleed / recover / stall / ge / decel / gust are multipliers (1.0 = the 172);
## power 0 = no engine; attempts = crashes allowed per run; min_len = shortest runway it will be given;
## scale = how big it is drawn; body / accent = the paint; kind = which model.
const PROFILES: Array[Dictionary] = [
	{"name": "CUB", "blurb": "Slow and floaty. Lands short, but gusts push it around.",
		"speed": 0.72, "sink": 0.8, "lift": 0.85, "response": 1.15, "bleed": 0.8, "recover": 1.0, "stall": 0.66, "ge": 1.35,
		"decel": 1.4, "gust": 1.25, "power": 1.0, "attempts": 3, "min_len": 0.0, "scale": 0.85,
		"body": Color(1.0, 0.86, 0.25), "accent": Color(0.75, 0.2, 0.15), "kind": 0},
	{"name": "172", "blurb": "The balanced all-rounder.",
		"speed": 1.0, "sink": 1.0, "lift": 1.0, "response": 1.0, "bleed": 1.0, "recover": 1.0, "stall": 1.0, "ge": 1.0,
		"decel": 1.0, "gust": 1.0, "power": 1.0, "attempts": 3, "min_len": 0.0, "scale": 1.0,
		"body": Color(0.96, 0.94, 0.88), "accent": Color(0.86, 0.2, 0.18), "kind": 1},
	{"name": "TWIN", "blurb": "Fast and heavy. Needs a long runway.",
		"speed": 1.25, "sink": 1.0, "lift": 1.0, "response": 0.95, "bleed": 0.9, "recover": 1.2, "stall": 1.0, "ge": 0.9,
		"decel": 0.85, "gust": 0.8, "power": 1.0, "attempts": 3, "min_len": 170.0, "scale": 1.15,
		"body": Color(0.92, 0.94, 0.97), "accent": Color(0.2, 0.35, 0.75), "kind": 2},
	{"name": "GLIDER", "blurb": "No engine. A long, quiet float. One attempt only.",
		"speed": 0.85, "sink": 0.6, "lift": 1.0, "response": 1.2, "bleed": 0.7, "recover": 0.0, "stall": 0.64, "ge": 1.6,
		"decel": 1.0, "gust": 1.1, "power": 0.0, "attempts": 1, "min_len": 0.0, "scale": 1.0,
		"body": Color(0.97, 0.97, 0.99), "accent": Color(1.0, 0.55, 0.12), "kind": 3},
	{"name": "JET", "blurb": "Very fast and very stable. Long runways only.",
		"speed": 1.55, "sink": 1.0, "lift": 1.0, "response": 0.9, "bleed": 0.6, "recover": 1.4, "stall": 0.95, "ge": 0.8,
		"decel": 0.75, "gust": 0.45, "power": 1.0, "attempts": 3, "min_len": 230.0, "scale": 1.1,
		"body": Color(0.72, 0.75, 0.8), "accent": Color(0.2, 0.22, 0.28), "kind": 4},
]

## Scenarios and weather each aircraft is offered (a forced ?scenario= / ?weather= still wins).
const SCENARIOS: Array = [
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.ENGINE_OUT, Scenarios.NIGHT, Scenarios.MOUNTAIN, Scenarios.WATER, Scenarios.TRUCK],
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.ENGINE_OUT, Scenarios.NIGHT, Scenarios.MOUNTAIN, Scenarios.WATER, Scenarios.TRUCK],
	[Scenarios.STANDARD, Scenarios.ENGINE_OUT, Scenarios.NIGHT],
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.MOUNTAIN],
	[Scenarios.STANDARD, Scenarios.NIGHT, Scenarios.CARRIER, Scenarios.ENGINE_OUT],
]
const WEATHER: Array = [
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.RAIN, Scenarios.TURBULENCE, Scenarios.SHEAR],
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.RAIN, Scenarios.TURBULENCE, Scenarios.SHEAR],
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.RAIN, Scenarios.TURBULENCE, Scenarios.SHEAR],
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.TURBULENCE, Scenarios.SHEAR],      # a glider doesn't fly in rain
	[Scenarios.CLEAR, Scenarios.FOG, Scenarios.RAIN, Scenarios.TURBULENCE, Scenarios.SHEAR],
]

static func profile(id: int) -> Dictionary:
	return PROFILES[clampi(id, 0, COUNT - 1)]

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

static func attempts(id: int) -> int:
	return int(profile(id)["attempts"])

static func from_key(key: String) -> int:
	return KEYS.find(key.to_lower())
