class_name Cosmetics
extends RefCounted
## Purely visual: aircraft paint schemes and gear for the pilot, Whiskers. Bought with coins earned from landings.
## Index 0 of each list is free (the aircraft's own paint / no gear).

## {name, body, accent, cost}; the first scheme keeps each aircraft's own colours.
const PAINTS: Array[Dictionary] = [
	{"name": "CLASSIC", "body": Color(1, 1, 1), "accent": Color(1, 1, 1), "cost": 0},
	{"name": "SUNSET", "body": Color(1.0, 0.62, 0.3), "accent": Color(0.75, 0.15, 0.3), "cost": 120},
	{"name": "MINT", "body": Color(0.7, 0.95, 0.82), "accent": Color(0.15, 0.55, 0.5), "cost": 150},
	{"name": "MIDNIGHT", "body": Color(0.22, 0.26, 0.45), "accent": Color(0.95, 0.8, 0.25), "cost": 200},
	{"name": "CANDY", "body": Color(1.0, 0.78, 0.88), "accent": Color(0.45, 0.35, 0.9), "cost": 250},
	{"name": "GOLD", "body": Color(1.0, 0.84, 0.3), "accent": Color(0.25, 0.2, 0.15), "cost": 400},
]

## {name, cost}: 0 = nothing.
const GEAR: Array[Dictionary] = [
	{"name": "NONE", "cost": 0},
	{"name": "GOGGLES", "cost": 100},
	{"name": "PILOT CAP", "cost": 150},
	{"name": "SCARF", "cost": 200},
	{"name": "CROWN", "cost": 300},
]

static func coins_for(grade: int, mult: int) -> int:
	var base := [Tuning.coins_greaser, Tuning.coins_smooth, Tuning.coins_good, Tuning.coins_firm, Tuning.coins_hard]
	return int(base[clampi(grade, 0, 4)]) * maxi(mult, 1)

static func paint_has_scheme(idx: int) -> bool:
	return idx > 0

## Try to buy item `idx` of `kind` ("paint" or "gear") from the save. Returns true if it is now owned.
static func buy(data: Dictionary, kind: String, idx: int) -> bool:
	if kind == "plane":
		return buy_plane(data, idx)
	var list: Array[Dictionary] = PAINTS if kind == "paint" else GEAR
	if idx < 0 or idx >= list.size():
		return false
	var own: Array = data["owned_" + kind]
	if own.has(idx):
		return true
	var cost: int = list[idx]["cost"]
	if int(data["coins"]) < cost:
		return false
	data["coins"] = int(data["coins"]) - cost
	own.append(idx)
	return true

## Buy an aircraft with coins (does nothing if it is free, already bought or can't be afforded).
static func buy_plane(data: Dictionary, id: int) -> bool:
	var own: Array = data["owned_planes"]
	if own.has(id):
		return true
	if int(data["coins"]) < Planes.price(id):
		return false
	data["coins"] = int(data["coins"]) - Planes.price(id)
	own.append(id)
	return true

static func owned(data: Dictionary, kind: String, idx: int) -> bool:
	return (data["owned_" + kind] as Array).has(idx)
