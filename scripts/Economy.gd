class_name Economy
extends RefCounted
## The flight-school money: renting an aircraft you don't own (a fee per free-flight run), the damage fee when a rented aircraft
## crashes, buying an aircraft (no more rent), and instructor lessons. Pure functions of Tuning and the save, so the economy
## simulation (tools/economy_sim.gd) and the smoke tests use exactly what the game uses.

static func rent(id: int) -> int:
	match clampi(id, 0, Planes.COUNT - 1):
		Planes.CUB: return int(Tuning.rent_cub)
		Planes.C172: return int(Tuning.rent_172)
		Planes.GLIDER: return int(Tuning.rent_glider)
		Planes.TWIN: return int(Tuning.rent_twin)
	return int(Tuning.rent_jet)

static func damage_fee(id: int) -> int:
	return int(roundf(float(rent(id)) * Tuning.damage_mult))

static func owns(data: Dictionary, id: int) -> bool:
	return (data["owned_planes"] as Array).has(id)

## What starting a free-flight run in this aircraft costs now: nothing if you own it; the Cub's fee is waived when you can't pay it.
static func rental_due(data: Dictionary, id: int) -> int:
	if owns(data, id):
		return 0
	var fee := rent(id)
	if id == Planes.CUB and int(data["coins"]) < fee:
		return 0
	return fee

static func can_rent(data: Dictionary, id: int) -> bool:
	return rental_due(data, id) <= int(data["coins"])

## The damage fee a crash costs (0 for an aircraft you own); you can only lose what you have.
static func damage_due(data: Dictionary, id: int) -> int:
	if owns(data, id):
		return 0
	return mini(damage_fee(id), int(data["coins"]))

static func lesson_fee(target: int) -> int:
	return int(roundf(Tuning.lesson_fee_base * pow(Tuning.lesson_fee_growth, float(maxi(target - 1, 0)))))

## The selector's line under the aircraft: what it costs to fly.
static func rent_text(data: Dictionary, id: int) -> String:
	if owns(data, id):
		return "OWNED  -  no rental"
	var due := rental_due(data, id)
	if due == 0:
		return "WAIVED  -  you can't afford the %d coin rental" % rent(id)
	return "RENT  %d coins per flight" % due
