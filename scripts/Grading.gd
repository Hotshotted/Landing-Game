class_name Grading
extends RefCounted
## Pure scoring of one landing: touchdown sink rate, touchdown point and bounce. No state, so tests can feed it.

const NAMES: Array[String] = ["Greaser!", "Smooth", "Good", "Firm", "Hard"]
const COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.2), Color(0.45, 0.95, 0.55), Color(0.55, 0.85, 1.0), Color(1.0, 0.65, 0.3), Color(1.0, 0.4, 0.35)]

## Sink points: full at or below greaser_sink, none at or above hard_sink.
static func sink_score(sink: float) -> float:
	var t := (sink - Tuning.greaser_sink) / maxf(Tuning.hard_sink - Tuning.greaser_sink, 0.01)
	return Tuning.sink_points * (1.0 - clampf(t, 0.0, 1.0))

## Touchdown-point points: full within position_perfect of the aim markers (either side), none at position_zero
## (or a bit less on a short field).
static func position_score(dist_from_aim: float, runway_len: float) -> float:
	var zero := minf(Tuning.position_zero, runway_len * 0.4)
	var t := (absf(dist_from_aim) - Tuning.position_perfect) / maxf(zero - Tuning.position_perfect, 0.01)
	return Tuning.position_points * (1.0 - clampf(t, 0.0, 1.0))

## Grade index (0 = Greaser! .. 4 = Hard) for a point total.
static func grade_for_points(total: float) -> int:
	if total >= Tuning.grade_greaser:
		return 0
	if total >= Tuning.grade_smooth:
		return 1
	if total >= Tuning.grade_good:
		return 2
	if total >= Tuning.grade_firm:
		return 3
	return 4

## The best grade a sink rate allows.
static func grade_for_sink(sink: float) -> int:
	if sink <= Tuning.sink_cap_greaser:
		return 0
	if sink <= Tuning.sink_cap_smooth:
		return 1
	if sink <= Tuning.sink_cap_good:
		return 2
	if sink <= Tuning.sink_cap_firm:
		return 3
	return 4

static func is_crash_sink(sink: float) -> bool:
	return sink >= Tuning.crash_sink

## {sink_pts, pos_pts, bounce_pts, total (rounded points), grade (index), name}
static func evaluate(sink: float, dist_from_aim: float, runway_len: float, bounced: bool) -> Dictionary:
	var sp := sink_score(sink)
	var pp := position_score(dist_from_aim, runway_len)
	var bp := 0.0 if bounced else Tuning.bounce_points
	var total := sp + pp + bp
	var grade := maxi(grade_for_points(total), grade_for_sink(sink))
	if bounced:
		grade = maxi(grade, 2)   # a bounce can't be better than "Good"
	return {"sink_pts": sp, "pos_pts": pp, "bounce_pts": bp, "total": int(roundf(total)), "grade": grade, "name": NAMES[grade]}
