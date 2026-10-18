class_name Units
extends RefCounted
## Aviation units. The world is in "units" (1 unit = Tuning.feet_per_unit feet, 5 by default, so 22 units/s is the 172's
## 65 kt approach); everything the player reads is converted here: feet, knots, feet per second / minute.

const FT_PER_NM := 6076.12
const FT_PER_S_PER_KT := 1.68781

static func ft(units: float) -> float:
	return units * Tuning.feet_per_unit

static func units_of_ft(feet: float) -> float:
	return feet / Tuning.feet_per_unit

## World speed (units / s) -> knots, and back.
static func kt(ups: float) -> float:
	return ups * Tuning.feet_per_unit / FT_PER_S_PER_KT

static func ups_of_kt(knots: float) -> float:
	return knots * FT_PER_S_PER_KT / Tuning.feet_per_unit

## Vertical speed: units / s -> feet per second / feet per minute, and feet per second -> units / s.
static func fps(ups: float) -> float:
	return ups * Tuning.feet_per_unit

static func fpm(ups: float) -> float:
	return ups * Tuning.feet_per_unit * 60.0

static func ups_of_fps(feet_per_s: float) -> float:
	return feet_per_s / Tuning.feet_per_unit
