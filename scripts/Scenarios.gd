class_name Scenarios
extends RefCounted
## What kind of approach this is (scenario) and what the sky is doing (weather). Endless mode mixes them with rising
## difficulty; ?scenario= / ?weather= and the ?tune panel can force one.

## STANDARD is the normal landing. SOFT_FIELD, POWER_OFF (power-off 180) and INSTRUMENT (a fog approach to minimums) are the
## landing types the career adds; MOUNTAIN, CARRIER, WATER and TRUCK are the special scenarios.
enum { STANDARD, SHORT_FIELD, ENGINE_OUT, NIGHT, MOUNTAIN, CARRIER, WATER, TRUCK, SOFT_FIELD, POWER_OFF, INSTRUMENT }
enum { CLEAR, FOG, RAIN, TURBULENCE, SHEAR }

const COUNT := 11
const WX_COUNT := 5
const NAMES: Array[String] = ["NORMAL LANDING", "SHORT FIELD", "ENGINE OUT", "NIGHT", "MOUNTAIN STRIP", "CARRIER", "SEAPLANE", "MOVING TRUCK", "SOFT FIELD", "POWER-OFF 180", "INSTRUMENT APPROACH"]
const KEYS: Array[String] = ["standard", "short", "engineout", "night", "mountain", "carrier", "water", "truck", "soft", "poweroff", "instrument"]
const BLURBS: Array[String] = [
	"Flat field. Flare for a soft touchdown.",
	"Trees before a short runway. Clear them, then get it down.",
	"No power. Glide to the runway or fall short.",
	"Only the runway and approach lights. Trust the PAPI.",
	"The runway climbs. The ground rises to meet you.",
	"Moving deck. Touch down in the wire zone.",
	"Calm lane = smooth. Rough water bounces.",
	"Land on the flatbed. Yes, really.",
	"Rough grass. Touch down gently and hold the nose off.",
	"Power cut abeam the point. Glide it in and land on the spot.",
	"Fog. Fly the glidepath on the PAPI; the runway appears at minimums.",
]
const WX_NAMES: Array[String] = ["CLEAR", "FOG", "RAIN", "TURBULENCE", "WIND SHEAR"]
const WX_KEYS: Array[String] = ["clear", "fog", "rain", "turbulence", "shear"]
const WX_BLURBS: Array[String] = ["", "The runway appears late.", "Poor visibility, wet runway.", "Rough air on final.", "Watch the windsock - the sink comes before the flare."]
const COLORS: Array[Color] = [
	Color(0.9, 0.95, 1.0), Color(1.0, 0.75, 0.3), Color(1.0, 0.45, 0.4), Color(0.55, 0.65, 1.0),
	Color(0.7, 0.9, 0.5), Color(0.5, 0.85, 1.0), Color(0.4, 0.9, 0.95), Color(1.0, 0.85, 0.3),
	Color(0.6, 0.85, 0.4), Color(1.0, 0.6, 0.45), Color(0.75, 0.8, 0.9)]

## Debug overrides (-1 = none): ?scenario=, ?weather= and the ?tune panel.
static var forced_scenario := -1
static var forced_weather := -1

static func scenario_from_key(key: String) -> int:
	if key.to_lower() == "normal":
		return STANDARD
	return KEYS.find(key.to_lower())

static func weather_from_key(key: String) -> int:
	return WX_KEYS.find(key.to_lower())

## Is this scenario / weather combination fair? (no turbulence on an engine-out glide, no weather on the joke truck ...)
static func combo_ok(scn: int, wx: int) -> bool:
	if scn == TRUCK and wx != CLEAR:
		return false
	if (scn == ENGINE_OUT or scn == POWER_OFF) and (wx == TURBULENCE or wx == SHEAR):
		return false
	if scn == INSTRUMENT and wx != FOG:
		return false
	if scn == NIGHT and wx == FOG:
		return false
	if scn == CARRIER and wx == FOG:
		return false
	return true

## Choose the next approach: Vector2i(scenario, weather). `allowed_*` limit the choice (career unlocks, aircraft); empty =
## everything. `last` is the previous scenario (not repeated when there is a choice).
## `prefer`: landing types to favour (the ones being trained for): they get a bigger share, the others are still mixed in.
static func pick(round_no: int, rng: RandomNumberGenerator, last: int = -1, allowed_scn: Array[int] = [], allowed_wx: Array[int] = [], prefer: Array[int] = []) -> Vector2i:
	var r := Tuning.ramp(round_no)
	var scn := STANDARD
	var wx := CLEAR
	if round_no > 2:
		var w: Array[float] = [
			maxf(2.5 - 1.7 * r, 0.8), 2.0, 1.2 if r > 0.1 else 0.0, 1.2 if r > 0.05 else 0.0,
			1.5, 1.2 if r > 0.15 else 0.0, 1.2, 0.5 if r > 0.25 else 0.0,
			1.4, 0.9 if r > 0.2 else 0.0, 1.0 if r > 0.2 else 0.0]
		for i in COUNT:
			if prefer.has(i):
				w[i] = maxf(w[i], 0.8) * 2.2
			if (not allowed_scn.is_empty() and not allowed_scn.has(i)) or i == last:
				w[i] = 0.0
		scn = _weighted(w, rng, STANDARD)
		var tries := 0
		if scn == INSTRUMENT:
			tries = 99           # an instrument approach is always flown in fog
		while true:
			var ww: Array[float] = [maxf(3.0 * (1.0 - 0.8 * r), 0.6), 0.5 + 0.9 * r, 0.5 + 0.8 * r, 0.4 + 0.9 * r, (0.3 + 1.0 * r) if round_no > 3 else 0.0]
			for j in WX_COUNT:
				if not allowed_wx.is_empty() and not allowed_wx.has(j):
					ww[j] = 0.0
			wx = _weighted(ww, rng, CLEAR)
			tries += 1
			if combo_ok(scn, wx) or tries > 8:
				break
		if scn == INSTRUMENT:
			wx = FOG
		elif not combo_ok(scn, wx):
			wx = CLEAR
	if forced_scenario >= 0:
		scn = forced_scenario
	if forced_weather >= 0:
		wx = forced_weather
	if scn == INSTRUMENT and forced_weather < 0:
		wx = FOG
	return Vector2i(scn, wx)

static func _weighted(w: Array[float], rng: RandomNumberGenerator, fallback: int) -> int:
	var total := 0.0
	for x in w:
		total += x
	if total <= 0.0:
		return fallback
	var u := rng.randf() * total
	for i in w.size():
		u -= w[i]
		if u <= 0.0:
			return i
	return fallback
