class_name Grading
extends RefCounted
## Pure scoring of one landing: touchdown sink rate, touchdown point and bounce. No state, so tests can feed it.

const NAMES: Array[String] = ["Greaser!", "Smooth", "Good", "Firm", "Hard"]
const COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.2), Color(0.45, 0.95, 0.55), Color(0.55, 0.85, 1.0), Color(1.0, 0.65, 0.3), Color(1.0, 0.4, 0.35)]

## Sink points (sink in world units / s): full at or below fps_greaser, none at or above fps_zero.
static func sink_score(sink: float) -> float:
	var f := Units.fps(sink)
	var t := (f - Tuning.fps_greaser) / maxf(Tuning.fps_zero - Tuning.fps_greaser, 0.01)
	return Tuning.sink_points * (1.0 - clampf(t, 0.0, 1.0))

## Touchdown-point points: full within position_perfect_ft of the aim markers (either side), none at position_zero_ft
## (or a bit less on a short field). Distances in world units.
static func position_score(dist_from_aim: float, runway_len: float) -> float:
	var d := Units.ft(absf(dist_from_aim))
	var zero := minf(Tuning.position_zero_ft, Units.ft(runway_len) * 0.4)
	var perfect := minf(Tuning.position_perfect_ft, zero * 0.5)
	var t := (d - perfect) / maxf(zero - perfect, 0.01)
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

## The best grade a sink rate (units / s) allows: Greaser! under fps_greaser ft/s, Smooth under fps_smooth, Good under fps_good,
## Firm under fps_firm, Hard above.
static func grade_for_sink(sink: float) -> int:
	var f := Units.fps(sink)
	if f <= Tuning.fps_greaser:
		return 0
	if f <= Tuning.fps_smooth:
		return 1
	if f <= Tuning.fps_good:
		return 2
	if f <= Tuning.fps_firm:
		return 3
	return 4

## Touching down at or above the structural limit (ft/s; `tough` is the aircraft's multiplier) breaks the aircraft.
static func is_crash_sink(sink: float, tough: float = 1.0) -> bool:
	return Units.fps(sink) >= Tuning.fps_crash * tough

static func is_bounce_sink(sink: float, factor: float = 1.0) -> bool:
	return Units.fps(sink) > Tuning.fps_bounce * factor

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
