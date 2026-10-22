extends SceneTree
## The coin economy over the first two hours for a cautious, a balanced and a greedy player:
##   godot --headless --path . --script res://tools/economy_sim.gd
## Prints a report (docs/economy.md keeps the last one).

func _init() -> void:
	await process_frame
	var tn = root.get_node("/root/Tuning")
	var Sim = load("res://scripts/EconomySim.gd")
	var Pl = load("res://scripts/Planes.gd")
	print("# Coin economy, first 2 hours (average of 12 simulated players per type)\n")
	print("Rent per flight: Cub %d, 172 %d, glider %d, twin %d, jet %d. Damage fee x%.1f. Prices: Cub %d, 172 %d, glider %d, twin %d, jet %d." % [tn.rent_cub, tn.rent_172, tn.rent_glider, tn.rent_twin, tn.rent_jet, tn.damage_mult, tn.price_cub, tn.price_172, tn.price_glider, tn.price_twin, tn.price_jet])
	for name in ["cautious", "balanced", "greedy"]:
		var r: Dictionary = Sim.average(name)
		print("\n## %s" % name)
		var line := "balance every 10 min:"
		for b in r["balance"]:
			line += " %d" % int(b)
		print(line)
		var own := "bought at (minute, median):"
		for id in Sim.BUY_ORDER:
			own += "  %s %s" % [Pl.NAMES[id], ("%.0f" % r["bought"][id]) if r["bought"][id] >= 0.0 else "not in 2 h"]
		print(own)
		var able := "balance first covers the price:"
		for id in Sim.BUY_ORDER:
			able += "  %s %s" % [Pl.NAMES[id], ("%.0f" % r["ownable"][id]) if r["ownable"][id] >= 0.0 else "not in 2 h"]
		print(able)
		print("runs %.0f (crashes %.0f), earned %d, rental %d, damage %d, examiner fees %d, lessons %d, rank at 2 h %.1f" % [r["runs"], r["crashes"], r["earned"], r["rental"], r["damage"], r["fees"], r["lessons"], r["rank"]])
		print("checkrides taken %.1f, passed %d%%, balance covered the fee %.1fx on average when booked" % [r["rides"], int(r["ride_pass"] * 100.0), r["ride_cover"]])
	quit()
