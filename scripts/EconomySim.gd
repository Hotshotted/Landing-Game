class_name EconomySim
extends RefCounted
## A player model for the coin economy: it flies free-flight runs the way a cautious, a balanced or a greedy player would, pays
## rentals, damage, lessons and examiner fees, buys aircraft, and reports the coin balance over time. It uses the game's own
## functions (Economy, Cosmetics, Career, Tuning), so a change to a Tuning number shows up here. tools/economy_sim.gd prints it;
## docs/economy.md keeps the last report; the smoke test checks the milestones.

const BUY_ORDER: Array[int] = [Planes.CUB, Planes.C172, Planes.GLIDER, Planes.TWIN, Planes.JET]
const FLY_ORDER: Array[int] = [Planes.JET, Planes.TWIN, Planes.C172, Planes.CUB]      # (the glider is a special aircraft: not flown for coins)

const PROFILES := {
	"cautious": {"grades": [0.10, 0.30, 0.35, 0.18, 0.07], "crash": 0.02, "crash_step": 0.01, "max_landings": 2, "std_free": 0.65, "std_ride": 0.82,
		"rent_reserve": 3.0, "ride_reserve": 1.3, "lesson_reserve": 4.0, "lesson_prob": 0.25},
	"balanced": {"grades": [0.14, 0.31, 0.33, 0.16, 0.06], "crash": 0.03, "crash_step": 0.02, "max_landings": 4, "std_free": 0.58, "std_ride": 0.78,
		"rent_reserve": 2.5, "ride_reserve": 1.2, "lesson_reserve": 6.0, "lesson_prob": 0.2},
	"greedy": {"grades": [0.18, 0.32, 0.30, 0.15, 0.05], "crash": 0.04, "crash_step": 0.035, "max_landings": 8, "std_free": 0.5, "std_ride": 0.72,
		"rent_reserve": 2.0, "ride_reserve": 1.1, "lesson_reserve": 99.0, "lesson_prob": 0.0},
}

const SECONDS_PER_LANDING := 50.0
const SECONDS_PER_RUN := 15.0

## One simulated player for `minutes`. Returns {samples (balance every 10 min), bought {plane: minute}, rides, lessons, rental, damage,
## fees, runs, crashes, rank, ownable {plane: minute the balance first covered its price}, earned}.
static func run(profile_name: String, seed_value: int, minutes: float = 120.0) -> Dictionary:
	var pf: Dictionary = PROFILES[profile_name]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var data := Save.default_data()
	var coins := 0
	var t := 0.0
	var next_sample := 600.0
	var out := {"samples": [], "bought": {}, "rides": [], "lessons": 0, "rental": 0, "damage": 0, "fees": 0, "runs": 0, "crashes": 0,
		"rank": 0, "ownable": {}, "earned": 0, "lesson_spend": 0, "buy_spend": 0}
	var limit := minutes * 60.0
	while t < limit:
		data["coins"] = coins
		# ---- between runs: checkride, lesson, purchase
		var rank := int(data["rank"])
		var tgt := mini(rank + 1, Career.max_rank())
		if rank < Career.max_rank():
			if Career.endorsed(data, tgt):
				var fee := Career.fee(tgt, false)
				if float(coins) >= float(fee) * float(pf["ride_reserve"]):
					coins -= fee
					out["fees"] += fee
					var ok := true
					var types := Career.types_for(tgt)
					for k in mini(int(Tuning.ride_landings), types.size()):
						if rng.randf() > float(pf["std_ride"]):
							ok = false
							break
					(out["rides"] as Array).append({"minute": t / 60.0, "fee": fee, "balance_before": coins + fee, "rank": tgt, "pass": ok})
					t += 240.0
					if ok:
						data["rank"] = tgt
						Career.on_rank_change(data, tgt)
					else:
						var ty: int = types[rng.randi() % types.size()]
						Career.drop_half(data, ty)
					continue
			else:
				var miss := Career.missing(data, tgt)
				var lfee := Economy.lesson_fee(tgt)
				if not miss.is_empty() and float(coins) >= float(lfee) * float(pf["lesson_reserve"]) and rng.randf() < float(pf["lesson_prob"]):
					coins -= lfee
					out["lessons"] += 1
					out["lesson_spend"] += lfee
					if rng.randf() < 0.8:
						Career.add_practice(data, miss[rng.randi() % miss.size()], int(Tuning.lesson_credit))
					t += 80.0
					continue
		for id in BUY_ORDER:
			if Economy.owns(data, id):
				continue
			var price := Planes.price(id)
			if not out["ownable"].has(id) and coins >= price:
				out["ownable"][id] = t / 60.0
			if float(coins) >= float(price) + 2.0 * float(Economy.rent(id)):
				coins -= price
				(data["owned_planes"] as Array).append(id)
				out["bought"][id] = t / 60.0
				out["buy_spend"] += price
			break                                            # (one purchase goal at a time, cheapest first)
		# ---- a free-flight run
		data["coins"] = coins
		var avail: Array[int] = Career.planes(int(data["rank"]))
		for o in data["owned_planes"]:
			if not avail.has(int(o)):
				avail.append(int(o))
		var plane := Planes.CUB
		for id in FLY_ORDER:
			if avail.has(id) and (Economy.owns(data, id) or float(coins) >= float(Economy.rent(id)) * float(pf["rent_reserve"])):
				plane = id
				break
		var due := Economy.rental_due(data, plane)
		coins -= due
		out["rental"] += due
		out["runs"] += 1
		t += SECONDS_PER_RUN
		var pot := 0
		var streak := 0
		var k := 0
		var crashed := false
		while true:
			var p_crash: float = float(pf["crash"]) + float(pf["crash_step"]) * float(k)
			t += SECONDS_PER_LANDING
			if rng.randf() < p_crash:
				crashed = true
				break
			var gr := _grade(pf["grades"], rng)
			if gr == 0:
				streak += 1
			elif gr >= 3:
				streak = 0
			var award := int(roundf(float(Cosmetics.coins_for(gr, clampi(maxi(streak, 1), 1, int(Tuning.streak_cap)))) * (1.0 + Tuning.pot_step * float(k))))
			pot += award
			_credit(data, rng, float(pf["std_free"]))
			k += 1
			if k >= int(pf["max_landings"]):
				break
		if crashed:
			out["crashes"] += 1
			data["coins"] = coins
			var dmg := Economy.damage_due(data, plane)
			coins -= dmg
			out["damage"] += dmg
			t += 10.0
		else:
			coins += pot
			out["earned"] += pot
		coins = maxi(coins, 0)
		while t >= next_sample and next_sample <= limit:
			(out["samples"] as Array).append(coins)
			next_sample += 600.0
	out["rank"] = int(data["rank"])
	out["coins"] = coins
	return out

## The pot of one run: `grades` is the grade index of each landing in order (0 Greaser .. 4 Hard); the Greaser streak and the pot multiplier apply.
static func pot_for(grades: Array) -> int:
	var pot := 0
	var streak := 0
	for k in grades.size():
		var gr := int(grades[k])
		if gr == 0:
			streak += 1
		elif gr >= 3:
			streak = 0
		pot += int(roundf(float(Cosmetics.coins_for(gr, clampi(maxi(streak, 1), 1, int(Tuning.streak_cap)))) * (1.0 + Tuning.pot_step * float(k))))
	return pot

static func _grade(w: Array, rng: RandomNumberGenerator) -> int:
	var u := rng.randf()
	for i in w.size():
		u -= float(w[i])
		if u <= 0.0:
			return i
	return w.size() - 1

## A landing in free flight: its type is drawn favouring the types still to fill; meeting the standard fills the meter.
static func _credit(data: Dictionary, rng: RandomNumberGenerator, p_std: float) -> void:
	var rank := int(data["rank"])
	if rank >= Career.max_rank():
		return
	var tgt := rank + 1
	var types := Career.types_for(tgt)
	var miss := Career.missing(data, tgt)
	var ty := -1
	if not miss.is_empty() and rng.randf() < 0.55:
		ty = miss[rng.randi() % miss.size()]
	elif rng.randf() < 0.45:
		ty = types[rng.randi() % types.size()]
	if ty >= 0 and rng.randf() < p_std:
		Career.add_practice(data, ty)

## The average of several seeds: balances over time and the milestone minutes (-1 = not within the time).
static func average(profile_name: String, seeds: int = 12, minutes: float = 120.0) -> Dictionary:
	var runs: Array[Dictionary] = []
	for sd in seeds:
		runs.append(run(profile_name, 1000 + sd * 31, minutes))
	var n_samples := int(minutes / 10.0)
	var bal: Array[float] = []
	for i in n_samples:
		var tot := 0.0
		for r in runs:
			tot += float((r["samples"] as Array)[i]) if i < (r["samples"] as Array).size() else 0.0
		bal.append(tot / float(runs.size()))
	var bought := {}
	var ownable := {}
	for id in BUY_ORDER:
		var bs: Array[float] = []
		var os_: Array[float] = []
		for r in runs:
			if (r["bought"] as Dictionary).has(id):
				bs.append(float(r["bought"][id]))
			if (r["ownable"] as Dictionary).has(id):
				os_.append(float(r["ownable"][id]))
		bs.sort()
		os_.sort()
		bought[id] = bs[bs.size() / 2] if bs.size() * 2 >= runs.size() else -1.0       # (the median, if most players got there)
		ownable[id] = os_[os_.size() / 2] if os_.size() * 2 >= runs.size() else -1.0
	var rides_total := 0
	var rides_afford := 0.0
	var ride_pass := 0
	var rank_sum := 0.0
	var rental := 0.0
	var damage := 0.0
	var fees := 0.0
	var lessons := 0.0
	var earned := 0.0
	var runs_n := 0.0
	var crashes := 0.0
	for r in runs:
		rank_sum += float(r["rank"])
		rental += float(r["rental"])
		damage += float(r["damage"])
		fees += float(r["fees"])
		lessons += float(r["lesson_spend"])
		earned += float(r["earned"])
		runs_n += float(r["runs"])
		crashes += float(r["crashes"])
		for rd in r["rides"]:
			rides_total += 1
			rides_afford += float(rd["balance_before"]) / float(rd["fee"])
			ride_pass += 1 if bool(rd["pass"]) else 0
	var m := float(runs.size())
	return {"balance": bal, "bought": bought, "ownable": ownable, "rank": rank_sum / m, "rental": rental / m, "damage": damage / m, "fees": fees / m,
		"lessons": lessons / m, "earned": earned / m, "runs": runs_n / m, "crashes": crashes / m, "rides": float(rides_total) / m,
		"ride_cover": rides_afford / maxf(float(rides_total), 1.0), "ride_pass": float(ride_pass) / maxf(float(rides_total), 1.0)}
