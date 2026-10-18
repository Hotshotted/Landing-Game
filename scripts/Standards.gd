class_name Standards
extends RefCounted
## What each landing type is judged on, and how strict it is. Three tiers: 0 = Student / Sport / Recreational (loose),
## 1 = Private / Instrument, 2 = Commercial and above (tight). All values are Tuning values (feet, knots, feet per second).
##
## A standard is a Dictionary:
##   zone_ft   touch down at or within this many feet BEYOND the aim point (< 0 = no touchdown-point standard)
##   short_ft  ... and no more than this many feet SHORT of it
##   speed     the approach speed (measured at 50 ft) must be within Vref - kt_minus .. Vref + kt_plus
##   sink_fps  touchdown sink rate limit (feet per second)
##   nose      soft field: hold the nose off after touchdown
##   papi      instrument approach: stay within one light of the glide path until minimums
##   field     engine out: land on the field (the runway)

## tier of each rank (see Career.RANKS)
static func tier_for_rank(rank: int) -> int:
	if rank <= 2:
		return 0
	if rank <= 4:
		return 1
	return 2

static func _t(arr: Array, tier: int) -> float:
	return float(arr[clampi(tier, 0, arr.size() - 1)])

static func for_type(scn: int, tier: int) -> Dictionary:
	var st := {"zone_ft": -1.0, "short_ft": _t(Tuning.std_short_tol_ft, tier), "speed": false,
		"kt_minus": _t(Tuning.std_kt_minus, tier), "kt_plus": _t(Tuning.std_kt_plus, tier),
		"sink_fps": _t(Tuning.std_sink_fps, tier), "nose": false, "papi": false, "field": false}
	match scn:
		Scenarios.STANDARD, Scenarios.NIGHT:
			st["zone_ft"] = _t(Tuning.std_zone_normal_ft, tier)
			st["speed"] = true
		Scenarios.SHORT_FIELD:
			st["zone_ft"] = _t(Tuning.std_zone_short_ft, tier)
			st["speed"] = true
		Scenarios.SOFT_FIELD:
			st["zone_ft"] = _t(Tuning.std_zone_normal_ft, tier)
			st["speed"] = true
			st["sink_fps"] = _t(Tuning.std_sink_fps_soft, tier)
			st["nose"] = true
		Scenarios.POWER_OFF:
			st["zone_ft"] = Tuning.std_zone_power_off_ft
			st["speed"] = true
		Scenarios.ENGINE_OUT:
			st["field"] = true
		Scenarios.INSTRUMENT:
			st["zone_ft"] = _t(Tuning.std_zone_normal_ft, tier)
			st["speed"] = true
			st["papi"] = true
	return st

## The standard as lines of text for the title card ("Touch down at or within 400 ft beyond the aim point", ...).
static func lines(st: Dictionary, vref_kt: float) -> Array[String]:
	var out: Array[String] = []
	if float(st["zone_ft"]) >= 0.0:
		out.append("Touch down at or within %d ft beyond the aim point" % int(st["zone_ft"]))
	if bool(st["field"]):
		out.append("Land on the field")
	if bool(st["speed"]):
		out.append("Speed at 50 ft: %d to %d kt (Vref %d)" % [int(roundf(vref_kt - float(st["kt_minus"]))), int(roundf(vref_kt + float(st["kt_plus"]))), int(roundf(vref_kt))])
	if bool(st["papi"]):
		out.append("Stay within one light of the PAPI to minimums")
	out.append("Sink under %.1f ft/s" % float(st["sink_fps"]))
	if bool(st["nose"]):
		out.append("Hold the nose off")
	out.append("No bounce")
	return out

## Judge one landing. `result` = {sink (units/s), offset (units from the aim point), bounced, gate_dev_kt (airspeed at 50 ft minus
## Vref, or INF when never measured), nose_ok, papi_ok}; `crashed` = the approach ended in a crash.
## Returns {"pass": bool, "fails": Array[String]}.
static func judge(st: Dictionary, result: Dictionary, crashed: bool) -> Dictionary:
	var fails: Array[String] = []
	if crashed:
		fails.append("Crashed")
		return {"pass": false, "fails": fails}
	var off_ft := Units.ft(float(result.get("offset", 0.0)))
	var zone := float(st["zone_ft"])
	if zone >= 0.0:
		if off_ft > zone:
			fails.append("%d ft past the aim point (limit %d)" % [int(roundf(off_ft)), int(zone)])
		elif off_ft < -float(st["short_ft"]):
			fails.append("%d ft short of the aim point" % int(roundf(-off_ft)))
	if bool(st["speed"]):
		var dev := float(result.get("gate_dev_kt", INF))
		if dev == INF:
			fails.append("Speed not stable at 50 ft")
		elif dev > float(st["kt_plus"]):
			fails.append("%d kt fast at 50 ft (limit +%d)" % [int(roundf(dev)), int(st["kt_plus"])])
		elif dev < -float(st["kt_minus"]):
			fails.append("%d kt slow at 50 ft (limit -%d)" % [int(roundf(-dev)), int(st["kt_minus"])])
	var fps := Units.fps(float(result.get("sink", 99.0)))
	if fps > float(st["sink_fps"]):
		fails.append("Sink %.1f ft/s (limit %.1f)" % [fps, float(st["sink_fps"])])
	if bool(result.get("bounced", false)):
		fails.append("Bounced")
	if bool(st["nose"]) and not bool(result.get("nose_ok", true)):
		fails.append("Nose came down early")
	if bool(st["papi"]) and not bool(result.get("papi_ok", true)):
		fails.append("Off the glide path")
	return {"pass": fails.is_empty(), "fails": fails}
