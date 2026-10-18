class_name Ads
extends RefCounted
## Ad hooks, as STUBS: no ad SDK, just the places an ad would play and a fake "Ad playing" screen (see Main / Hud).
## A real SDK replaces `play()`'s fake screen later; the rules for WHERE ads may appear live here:
##   - rewarded: only when the player taps a button for it ("retry checkride landing", "double coins")
##   - interstitial: only between rounds in free flight (never mid-approach, never in a checkride or the daily), after
##     `Tuning.ad_interstitial_every` landed rounds and no sooner than `Tuning.ad_min_gap_seconds` after the last ad
## `enabled` is switched off by ?noads and by tests that must not meet an ad.

static var enabled := true
static var rounds_since := 0
static var last_ms := -1000000

static func reset() -> void:
	rounds_since = 0
	last_ms = Time.get_ticks_msec()

## A round was landed (free flight).
static func note_round() -> void:
	rounds_since += 1

## May an interstitial play now (called between rounds)?
static func interstitial_due(now_ms: int) -> bool:
	return enabled and rounds_since >= Tuning.ad_interstitial_every and float(now_ms - last_ms) / 1000.0 >= Tuning.ad_min_gap_seconds

static func played(now_ms: int) -> void:
	rounds_since = 0
	last_ms = now_ms
