class_name Career
extends RefCounted
## The career: eight ranks, what each unlocks, and the landing types (with their standards) each rank is trained and tested on.
## You train for the NEXT rank: its landing types fill proficiency meters through practice landings (see Main), and when every
## meter is full the instructor endorses you and the checkride for that rank can be booked.

const RANKS: Array[String] = ["STUDENT", "SPORT", "RECREATIONAL", "PRIVATE", "INSTRUMENT", "COMMERCIAL", "CFI", "AIRLINE CAPTAIN"]

## Aircraft each rank adds (cumulative).
const ADDS_PLANES: Array = [
	[Planes.CUB], [], [Planes.C172], [], [], [Planes.TWIN], [Planes.GLIDER], [Planes.JET]]

## Landing types a rank is trained and tested on (the rank's own list; Student has none: it is where you start).
const TYPES: Array = [
	[],
	[Scenarios.STANDARD, Scenarios.SOFT_FIELD],
	[Scenarios.STANDARD, Scenarios.SOFT_FIELD, Scenarios.SHORT_FIELD, Scenarios.ENGINE_OUT],
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.SOFT_FIELD, Scenarios.ENGINE_OUT, Scenarios.NIGHT],
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.SOFT_FIELD, Scenarios.ENGINE_OUT, Scenarios.NIGHT, Scenarios.INSTRUMENT],
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.SOFT_FIELD, Scenarios.ENGINE_OUT, Scenarios.NIGHT, Scenarios.INSTRUMENT, Scenarios.POWER_OFF],
	[Scenarios.STANDARD, Scenarios.SHORT_FIELD, Scenarios.SOFT_FIELD, Scenarios.ENGINE_OUT, Scenarios.NIGHT, Scenarios.INSTRUMENT, Scenarios.POWER_OFF, Scenarios.MOUNTAIN, Scenarios.WATER, Scenarios.TRUCK],
	[Scenarios.STANDARD, Scenarios.NIGHT, Scenarios.INSTRUMENT, Scenarios.ENGINE_OUT, Scenarios.CARRIER],
]

## The special scenarios also open up in free flight from this rank, even when they are not a training type yet.
const SPECIAL_FROM := {Scenarios.TRUCK: 2, Scenarios.MOUNTAIN: 3, Scenarios.WATER: 5, Scenarios.CARRIER: 7}

## Weather each rank adds.
const ADDS_WEATHER: Array = [
	[Scenarios.CLEAR], [], [], [Scenarios.RAIN, Scenarios.TURBULENCE], [Scenarios.FOG], [Scenarios.SHEAR], [], []]

static func rank_name(r: int) -> String:
	return RANKS[clampi(r, 0, RANKS.size() - 1)]

static func max_rank() -> int:
	return RANKS.size() - 1

static func tier(rank: int) -> int:
	return Standards.tier_for_rank(rank)

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
		if unlock_all or has_scenario(rank, i):
			out.append(i)
	return out

static func has_scenario(rank: int, scn: int) -> bool:
	if scn == Scenarios.STANDARD:
		return true          # a Student already lands normally
	var r := clampi(rank, 0, max_rank())
	for k in range(0, r + 1):
		if (TYPES[k] as Array).has(scn):
			return true
	return SPECIAL_FROM.has(scn) and r >= int(SPECIAL_FROM[scn])

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

## Landing types the checkride for `target` covers.
static func types_for(target: int) -> Array[int]:
	var out: Array[int] = []
	for v in TYPES[clampi(target, 0, max_rank())]:
		out.append(int(v))
	return out

## What reaching `rank` unlocks, as text lines.
static func unlock_lines(rank: int) -> Array[String]:
	var out: Array[String] = []
	var r := clampi(rank, 0, max_rank())
	if not (ADDS_PLANES[r] as Array).is_empty():
		out.append("Aircraft: " + ", ".join((ADDS_PLANES[r] as Array).map(func(i): return Planes.NAMES[i])))
	var fresh: Array[String] = []
	for t in types_for(r):
		if r == 0 or not types_for(r - 1).has(t):
			fresh.append(Scenarios.NAMES[t].capitalize())
	for scn in SPECIAL_FROM:
		if int(SPECIAL_FROM[scn]) == r and not types_for(r).has(scn):
			fresh.append(Scenarios.NAMES[scn].capitalize())
	if not fresh.is_empty():
		out.append("Landings: " + ", ".join(fresh))
	if not (ADDS_WEATHER[r] as Array).is_empty() and r > 0:
		out.append("Weather: " + ", ".join((ADDS_WEATHER[r] as Array).map(func(i): return Scenarios.WX_NAMES[i].capitalize())))
	return out

# ---------- proficiency and the endorsement ----------

static func needed() -> int:
	return maxi(int(Tuning.proficiency_needed), 1)

static func _prof(data: Dictionary) -> Dictionary:
	return data["proficiency"]

static func count(data: Dictionary, scn: int) -> int:
	return int((_prof(data)["counts"] as Dictionary).get(str(scn), 0))

## A practice landing that met the standard: one more on that meter (capped).
static func add_practice(data: Dictionary, scn: int) -> int:
	var counts: Dictionary = _prof(data)["counts"]
	counts[str(scn)] = mini(count(data, scn) + 1, needed())
	return int(counts[str(scn)])

## The types of the rank being trained for whose meter isn't full yet.
static func missing(data: Dictionary, target: int) -> Array[int]:
	var out: Array[int] = []
	for t in types_for(target):
		if count(data, t) < needed():
			out.append(t)
	return out

static func endorsed(data: Dictionary, target: int) -> bool:
	return target <= max_rank() and not types_for(target).is_empty() and missing(data, target).is_empty()

## A failed checkride: the failed type's meter drops back to half.
static func drop_half(data: Dictionary, scn: int) -> void:
	var counts: Dictionary = _prof(data)["counts"]
	counts[str(scn)] = mini(count(data, scn), needed() / 2)

## The rank changed: meters earned at the same standard tier carry over, others start again.
static func on_rank_change(data: Dictionary, new_rank: int) -> void:
	var t := tier(new_rank + 1)
	if int(_prof(data)["tier"]) != t:
		_prof(data)["counts"] = {}
	_prof(data)["tier"] = t
	# only keep meters for types the new target actually asks for
	var keep: Dictionary = {}
	for ty in types_for(new_rank + 1):
		if (_prof(data)["counts"] as Dictionary).has(str(ty)):
			keep[str(ty)] = _prof(data)["counts"][str(ty)]
	_prof(data)["counts"] = keep

# ---------- examiner fee ----------

static func fee(target: int, halved: bool = false) -> int:
	var f := int(roundf(Tuning.exam_fee_base * pow(Tuning.exam_fee_growth, float(maxi(target - 1, 0)))))
	return int(ceilf(float(f) * 0.5)) if halved else f

# ---------- drawing a checkride / a practice landing ----------

## `n` distinct landing types drawn at random from the rank's list.
static func draw(target: int, n: int, rng: RandomNumberGenerator) -> Array[int]:
	var pool := types_for(target)
	var out: Array[int] = []
	while out.size() < n and not pool.is_empty():
		var i := rng.randi_range(0, pool.size() - 1)
		out.append(pool[i])
		pool.remove_at(i)
	return out

## An aircraft for a landing type: any aircraft the target rank flies that suits the type (the newest is likelier).
static func pick_plane(scn: int, target: int, rng: RandomNumberGenerator) -> int:
	var cands: Array[int] = []
	for p in planes(target):
		if Planes.offers(p, scn):
			cands.append(p)
	if cands.is_empty():
		for p in Planes.COUNT:
			if Planes.offers(p, scn):
				cands.append(p)
	var weights: Array[float] = []
	var total := 0.0
	for p in cands:
		var w := 1.0 + (2.0 if _has_new(p, target) else 0.0)
		weights.append(w)
		total += w
	var u := rng.randf() * total
	for i in cands.size():
		u -= weights[i]
		if u <= 0.0:
			return cands[i]
	return cands[cands.size() - 1]

static func _has_new(plane: int, rank: int) -> bool:
	return (ADDS_PLANES[clampi(rank, 0, max_rank())] as Array).has(plane)

static func pick_weather(scn: int) -> int:
	return Scenarios.FOG if scn == Scenarios.INSTRUMENT else Scenarios.CLEAR

## The difficulty round a landing of this rank is flown at.
static func difficulty_round(target: int) -> int:
	return clampi(2 + target, 3, 10)

## One landing as the game plays it: {scn, wx, plane, seed, round}.
static func make_entry(scn: int, target: int, rng: RandomNumberGenerator) -> Dictionary:
	return {"scn": scn, "wx": pick_weather(scn), "plane": pick_plane(scn, target, rng), "seed": rng.randi() % 1000000 + 1, "round": difficulty_round(target)}
