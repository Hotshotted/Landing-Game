class_name Daily
extends RefCounted
## The Daily Approach: one hard approach per calendar day, the same for everyone (seeded by the date). Aircraft, scenario and
## weather come from the seed; the weather is never clear and the difficulty round is `Tuning.daily_round`.

const PLANES: Array[int] = [Planes.C172, Planes.CUB, Planes.TWIN, Planes.JET]

static func day_number(unix_seconds: float) -> int:
	return int(floor(unix_seconds / 86400.0))

static func for_day(day: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = day * 7919 + 13
	var plane: int = PLANES[r.randi_range(0, PLANES.size() - 1)]
	var scns := Planes.scenarios(plane)
	var scn: int = scns[r.randi_range(0, scns.size() - 1)]
	var wxs: Array[int] = []
	for w in Planes.weather(plane):
		if w != Scenarios.CLEAR and Scenarios.combo_ok(scn, w):
			wxs.append(w)
	var wx: int = Scenarios.FOG if (scn == Scenarios.INSTRUMENT or wxs.is_empty()) else wxs[r.randi_range(0, wxs.size() - 1)]
	return {"day": day, "plane": plane, "scn": scn, "wx": wx, "seed": r.randi() % 1000000, "round": Tuning.daily_round}

## "Fri 18 Oct" style label for a day number.
static func label(day: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(day * 86400)
	return "%d/%d/%d" % [d["day"], d["month"], d["year"]]
