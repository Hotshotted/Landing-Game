class_name Icons
extends RefCounted
## One vector icon set, drawn in code (no emoji, no image files). Bold filled silhouettes and thick strokes, round proportions;
## two-tone only where the colour is the meaning (coin gold, star gold, danger red, sun yellow, water blue). The same icon is
## always used for the same thing: stats, buttons, every aircraft, every rank, every landing type. Same set and rules as
## Pattern-Control's (docs/style.md), plus the aircraft / ranks / landing types of this game.
##   Icons.glyph(canvas_item, "coin", centre, radius, colour)
## Icons sit in a box of radius r; strokes are r / 6 (at least 3 px).

const IDS: Array[String] = [
	# stats and interface
	"coin", "pot", "star", "star_off", "clock", "play", "pause", "back", "forward", "chev_down", "chev_up", "home", "restart", "lock",
	"check", "cross", "speaker", "note", "settings", "quit", "wind", "speed", "altitude", "book", "career", "hangar", "daily",
	"stamp", "slip", "certificate", "cash", "keep", "ad", "flame", "trophy", "multiplier", "paint", "gear", "cap", "shirt",
	# aircraft
	"cub", "c172", "twin", "glider", "jet",
	# the studio mark (Clear Prop Games)
	"prop",
	# ranks
	"rank0", "rank1", "rank2", "rank3", "rank4", "rank5", "rank6", "rank7",
	# landing types and weather
	"normal", "short", "engineout", "night", "mountain", "carrier", "water", "truck", "soft", "poweroff", "instrument",
	"clear", "fog", "rain", "turbulence", "shear",
]

const AIRCRAFT: Array[String] = ["cub", "c172", "twin", "glider", "jet"]
## Landing types by scenario id (see Scenarios): STANDARD, SHORT_FIELD, ENGINE_OUT, NIGHT, MOUNTAIN, CARRIER, WATER, TRUCK,
## SOFT_FIELD, POWER_OFF, INSTRUMENT.
const LANDING: Array[String] = ["normal", "short", "engineout", "night", "mountain", "carrier", "water", "truck", "soft", "poweroff", "instrument"]
const WEATHER: Array[String] = ["clear", "fog", "rain", "turbulence", "shear"]

static func has(id: String) -> bool:
	return IDS.has(id)

static func aircraft(plane_id: int) -> String:
	return AIRCRAFT[clampi(plane_id, 0, AIRCRAFT.size() - 1)]

static func rank(rank_id: int) -> String:
	return "rank%d" % clampi(rank_id, 0, 7)

static func landing(scn: int) -> String:
	return LANDING[clampi(scn, 0, LANDING.size() - 1)]

static func weather(wx: int) -> String:
	return WEATHER[clampi(wx, 0, WEATHER.size() - 1)]

# ---------- shapes ----------

static func tri(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c]), col)

static func quad(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([a, b, c, d]), col)

static func poly(ci: CanvasItem, pts: Array, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array(pts), col)

static func line3(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, col: Color, w: float) -> void:
	ci.draw_polyline(PackedVector2Array([a, b, c]), col, w)

static func star_shape(ci: CanvasItem, c: Vector2, r: float, fill: Color, outline: bool = true) -> void:
	var pts := PackedVector2Array()
	pts.resize(10)
	for k in 10:
		var a := -PI * 0.5 + k * PI / 5.0
		pts[k] = c + Vector2(cos(a), sin(a)) * ((r if k % 2 == 0 else r * 0.45) + (4.0 if outline else 0.0))
	if outline:
		ci.draw_colored_polygon(pts, Color(0, 0, 0, fill.a))
		for k in 10:
			var a := -PI * 0.5 + k * PI / 5.0
			pts[k] = c + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45)
	ci.draw_colored_polygon(pts, fill)

## A rounded rectangle filled with `col` (a thick line with round caps would do too, but this keeps the corners exact).
static func rrect(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(rad))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, r)

# ---------- the icons ----------

static func glyph(ci: CanvasItem, id: String, c: Vector2, r: float, col: Color = Color.WHITE) -> void:
	var w := maxf(r * 0.16, 3.0)
	var ink := Color(Style.INK, col.a)
	match id:
		"coin":
			ci.draw_circle(c, r, Color(0, 0, 0, col.a))
			ci.draw_circle(c, r - 3.0, Color(Style.ACCENT, col.a))
			ci.draw_arc(c, r * 0.62, 0.0, TAU, 20, Color(Style.ACCENT_DARK, col.a), w * 0.8)
		"pot":    # a stack of coins: the unbanked pot
			for k in 3:
				var cc := c + Vector2(0, r * 0.45 - k * r * 0.42)
				ci.draw_circle(cc + Vector2(0, 0), r * 0.62, Color(0, 0, 0, col.a))
				ci.draw_circle(cc, r * 0.62 - 2.5, Color(Style.ACCENT, col.a))
				ci.draw_arc(cc, r * 0.38, 0.0, TAU, 14, Color(Style.ACCENT_DARK, col.a), w * 0.6)
		"star":
			star_shape(ci, c, r, Color(Style.ACCENT, col.a), true)
		"star_off":
			star_shape(ci, c, r, Color(0.28, 0.3, 0.38, col.a), true)
		"clock":
			ci.draw_arc(c, r, 0.0, TAU, 28, col, w)
			ci.draw_line(c, c + Vector2(0, -r * 0.65), col, w)
			ci.draw_line(c, c + Vector2(r * 0.45, r * 0.2), col, w)
		"play":
			tri(ci, c + Vector2(-r * 0.5, -r * 0.7), c + Vector2(-r * 0.5, r * 0.7), c + Vector2(r * 0.75, 0), col)
		"pause":
			ci.draw_rect(Rect2(c.x - r * 0.55, c.y - r * 0.7, r * 0.4, r * 1.4), col)
			ci.draw_rect(Rect2(c.x + r * 0.15, c.y - r * 0.7, r * 0.4, r * 1.4), col)
		"back":
			line3(ci, c + Vector2(r * 0.4, -r * 0.7), c + Vector2(-r * 0.4, 0), c + Vector2(r * 0.4, r * 0.7), col, w * 1.6)
		"forward":
			line3(ci, c + Vector2(-r * 0.4, -r * 0.7), c + Vector2(r * 0.4, 0), c + Vector2(-r * 0.4, r * 0.7), col, w * 1.6)
		"chev_down":
			line3(ci, c + Vector2(-r * 0.7, -r * 0.3), c + Vector2(0, r * 0.4), c + Vector2(r * 0.7, -r * 0.3), col, w * 1.4)
		"chev_up":
			line3(ci, c + Vector2(-r * 0.7, r * 0.3), c + Vector2(0, -r * 0.4), c + Vector2(r * 0.7, r * 0.3), col, w * 1.4)
		"home":
			tri(ci, c + Vector2(-r * 0.9, -r * 0.05), c + Vector2(0, -r * 0.85), c + Vector2(r * 0.9, -r * 0.05), col)
			ci.draw_rect(Rect2(c.x - r * 0.6, c.y - r * 0.05, r * 1.2, r * 0.85), col)
			ci.draw_rect(Rect2(c.x - r * 0.17, c.y + r * 0.3, r * 0.34, r * 0.5), ink)
		"restart":
			ci.draw_arc(c, r * 0.7, -PI * 0.15, PI * 1.5, 24, col, w * 1.5)
			tri(ci, c + Vector2(r * 0.95, -r * 0.05), c + Vector2(r * 0.3, -r * 0.2), c + Vector2(r * 0.85, -r * 0.8), col)
		"lock":
			ci.draw_rect(Rect2(c.x - r * 0.65, c.y - r * 0.1, r * 1.3, r * 0.95), col)
			ci.draw_arc(c + Vector2(0, -r * 0.1), r * 0.45, PI, TAU, 12, col, w * 1.3)
		"check":
			line3(ci, c + Vector2(-r * 0.7, 0.0), c + Vector2(-r * 0.2, r * 0.55), c + Vector2(r * 0.8, -r * 0.55), col, w * 1.8)
		"cross":
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.6), c + Vector2(r * 0.6, r * 0.6), col, w * 1.8)
			ci.draw_line(c + Vector2(r * 0.6, -r * 0.6), c + Vector2(-r * 0.6, r * 0.6), col, w * 1.8)
		"speaker":
			quad(ci, c + Vector2(-r * 0.9, -r * 0.35), c + Vector2(-r * 0.4, -r * 0.35), c + Vector2(-r * 0.4, r * 0.35), c + Vector2(-r * 0.9, r * 0.35), col)
			tri(ci, c + Vector2(-r * 0.4, -r * 0.35), c + Vector2(r * 0.15, -r * 0.8), c + Vector2(r * 0.15, r * 0.8), col)
			tri(ci, c + Vector2(-r * 0.4, r * 0.35), c + Vector2(r * 0.15, -r * 0.8), c + Vector2(r * 0.15, r * 0.8), col)
			ci.draw_arc(c + Vector2(r * 0.15, 0), r * 0.55, -PI * 0.35, PI * 0.35, 8, col, w)
			ci.draw_arc(c + Vector2(r * 0.15, 0), r * 0.95, -PI * 0.35, PI * 0.35, 8, col, w)
		"note":
			ci.draw_circle(c + Vector2(-r * 0.4, r * 0.55), r * 0.38, col)
			ci.draw_line(c + Vector2(-r * 0.05, r * 0.5), c + Vector2(-r * 0.05, -r * 0.8), col, w * 1.3)
			tri(ci, c + Vector2(-r * 0.05, -r * 0.8), c + Vector2(r * 0.7, -r * 0.4), c + Vector2(-r * 0.05, -r * 0.2), col)
		"settings":    # a gear
			ci.draw_circle(c, r * 0.62, col)
			for k in 8:
				var a := k * PI / 4.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.6, c + Vector2(cos(a), sin(a)) * r * 0.95, col, w * 1.9)
			ci.draw_circle(c, r * 0.26, ink)
		"quit":    # a door with an arrow leaving
			ci.draw_rect(Rect2(c.x - r * 0.85, c.y - r * 0.8, r * 0.85, r * 1.6), col, false, w * 1.2)
			ci.draw_line(c + Vector2(-r * 0.2, 0), c + Vector2(r * 0.8, 0), col, w * 1.4)
			tri(ci, c + Vector2(r * 0.95, 0), c + Vector2(r * 0.4, -r * 0.45), c + Vector2(r * 0.4, r * 0.45), col)
		"wind":
			ci.draw_line(c + Vector2(-r * 0.9, -r * 0.3), c + Vector2(r * 0.5, -r * 0.3), col, w * 1.2)
			ci.draw_line(c + Vector2(-r * 0.9, r * 0.25), c + Vector2(r * 0.8, r * 0.25), col, w * 1.2)
			ci.draw_arc(c + Vector2(r * 0.5, -r * 0.55), r * 0.25, PI * 0.5, PI * 2.0, 8, col, w * 1.2)
		"speed":    # a gauge
			ci.draw_arc(c + Vector2(0, r * 0.2), r * 0.9, PI * 1.1, PI * 1.9 + PI * 0.0, 16, col, w * 1.4)
			ci.draw_line(c + Vector2(0, r * 0.2), c + Vector2(r * 0.5, -r * 0.4), col, w * 1.3)
			ci.draw_circle(c + Vector2(0, r * 0.2), w * 1.1, col)
		"altitude":
			ci.draw_line(c + Vector2(0, r * 0.8), c + Vector2(0, -r * 0.7), col, w * 1.5)
			tri(ci, c + Vector2(-r * 0.55, -r * 0.3), c + Vector2(r * 0.55, -r * 0.3), c + Vector2(0, -r * 0.95), col)
			ci.draw_line(c + Vector2(-r * 0.6, r * 0.85), c + Vector2(r * 0.6, r * 0.85), col, w)
		"book":
			rrect(ci, Rect2(c.x - r * 0.8, c.y - r * 0.85, r * 1.6, r * 1.7), r * 0.18, col)
			ci.draw_line(c + Vector2(-r * 0.35, -r * 0.4), c + Vector2(r * 0.4, -r * 0.4), ink, w)
			ci.draw_line(c + Vector2(-r * 0.35, 0.0), c + Vector2(r * 0.4, 0.0), ink, w)
			ci.draw_line(c + Vector2(-r * 0.35, r * 0.4), c + Vector2(r * 0.1, r * 0.4), ink, w)
		"career":    # a graduation cap
			poly(ci, [c + Vector2(0, -r * 0.8), c + Vector2(r * 1.0, -r * 0.2), c + Vector2(0, r * 0.4), c + Vector2(-r * 1.0, -r * 0.2)], col)
			ci.draw_rect(Rect2(c.x - r * 0.5, c.y + r * 0.1, r * 1.0, r * 0.55), col)
			ci.draw_line(c + Vector2(r * 0.9, -r * 0.15), c + Vector2(r * 0.9, r * 0.6), col, w)
		"hangar":
			poly(ci, [c + Vector2(-r * 0.95, r * 0.8), c + Vector2(-r * 0.95, -r * 0.1), c + Vector2(0, -r * 0.85), c + Vector2(r * 0.95, -r * 0.1), c + Vector2(r * 0.95, r * 0.8)], col)
			ci.draw_rect(Rect2(c.x - r * 0.45, c.y + r * 0.05, r * 0.9, r * 0.75), ink)
		"daily":
			ci.draw_circle(c, r * 0.45, Color(Style.ACCENT, col.a))
			for k in 8:
				var a := k * PI / 4.0
				ci.draw_line(c + Vector2(cos(a), sin(a)) * r * 0.7, c + Vector2(cos(a), sin(a)) * r * 1.0, Color(Style.ACCENT, col.a), w * 1.3)
		"stamp":
			ci.draw_rect(Rect2(c.x - r * 0.3, c.y - r * 0.9, r * 0.6, r * 0.7), col)
			ci.draw_circle(c + Vector2(0, -r * 0.2), r * 0.35, col)
			rrect(ci, Rect2(c.x - r * 0.85, c.y + r * 0.1, r * 1.7, r * 0.8), r * 0.15, col)
		"slip":    # the pink slip: a torn sheet with a cross
			poly(ci, [c + Vector2(-r * 0.7, -r * 0.9), c + Vector2(r * 0.7, -r * 0.9), c + Vector2(r * 0.7, r * 0.6), c + Vector2(r * 0.35, r * 0.9), c + Vector2(0, r * 0.6), c + Vector2(-r * 0.35, r * 0.9), c + Vector2(-r * 0.7, r * 0.6)], Color(1.0, 0.62, 0.74, col.a))
			ci.draw_line(c + Vector2(-r * 0.3, -r * 0.35), c + Vector2(r * 0.3, r * 0.15), ink, w * 1.3)
			ci.draw_line(c + Vector2(r * 0.3, -r * 0.35), c + Vector2(-r * 0.3, r * 0.15), ink, w * 1.3)
		"certificate":
			rrect(ci, Rect2(c.x - r * 0.95, c.y - r * 0.7, r * 1.9, r * 1.4), r * 0.12, col)
			ci.draw_circle(c + Vector2(r * 0.5, r * 0.45), r * 0.3, Color(Style.ACCENT, col.a))
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.3), c + Vector2(r * 0.4, -r * 0.3), ink, w)
			ci.draw_line(c + Vector2(-r * 0.6, r * 0.05), c + Vector2(r * 0.1, r * 0.05), ink, w)
		"cash":    # coins going into a bank slot
			ci.draw_circle(c + Vector2(0, -r * 0.4), r * 0.5, Color(Style.ACCENT, col.a))
			rrect(ci, Rect2(c.x - r * 0.9, c.y + r * 0.2, r * 1.8, r * 0.7), r * 0.2, col)
			ci.draw_line(c + Vector2(-r * 0.5, r * 0.55), c + Vector2(r * 0.5, r * 0.55), ink, w)
		"keep":
			tri(ci, c + Vector2(-r * 0.9, -r * 0.55), c + Vector2(-r * 0.9, r * 0.55), c + Vector2(-r * 0.1, 0), col)
			tri(ci, c + Vector2(-r * 0.1, -r * 0.55), c + Vector2(-r * 0.1, r * 0.55), c + Vector2(r * 0.8, 0), col)
		"ad":
			ci.draw_rect(Rect2(c.x - r * 0.9, c.y - r * 0.6, r * 1.8, r * 1.2), col, false, w)
			tri(ci, c + Vector2(-r * 0.25, -r * 0.35), c + Vector2(-r * 0.25, r * 0.35), c + Vector2(r * 0.4, 0), col)
		"flame":
			ci.draw_circle(c + Vector2(0, r * 0.2), r * 0.6, Color(1.0, 0.55, 0.15, col.a))
			tri(ci, c + Vector2(-r * 0.5, r * 0.1), c + Vector2(r * 0.5, r * 0.1), c + Vector2(0, -r * 0.95), Color(1.0, 0.55, 0.15, col.a))
		"trophy":
			poly(ci, [c + Vector2(-r * 0.7, -r * 0.8), c + Vector2(r * 0.7, -r * 0.8), c + Vector2(r * 0.45, r * 0.2), c + Vector2(-r * 0.45, r * 0.2)], Color(Style.ACCENT, col.a))
			ci.draw_rect(Rect2(c.x - r * 0.12, c.y + r * 0.2, r * 0.24, r * 0.45), Color(Style.ACCENT, col.a))
			ci.draw_rect(Rect2(c.x - r * 0.5, c.y + r * 0.65, r * 1.0, r * 0.25), Color(Style.ACCENT_DARK, col.a))
		"multiplier":
			ci.draw_line(c + Vector2(-r * 0.6, -r * 0.6), c + Vector2(r * 0.6, r * 0.6), col, w * 2.0)
			ci.draw_line(c + Vector2(r * 0.6, -r * 0.6), c + Vector2(-r * 0.6, r * 0.6), col, w * 2.0)
		"paint":    # a paint drop
			ci.draw_circle(c + Vector2(0, r * 0.25), r * 0.62, col)
			tri(ci, c + Vector2(-r * 0.55, r * 0.05), c + Vector2(r * 0.55, r * 0.05), c + Vector2(0, -r * 0.95), col)
		"gear":
			glyph(ci, "settings", c, r, col)
		"cap":    # a pilot cap
			ci.draw_arc(c + Vector2(0, r * 0.2), r * 0.85, PI, TAU, 14, col, r * 0.5)
			ci.draw_rect(Rect2(c.x - r * 0.9, c.y + r * 0.1, r * 1.8, r * 0.3), col)
			ci.draw_rect(Rect2(c.x + r * 0.2, c.y + r * 0.3, r * 0.8, r * 0.18), col)
		"shirt":
			glyph_shirt(ci, c, r, col)
		"prop":    # the studio mark: a bold three-blade propeller seen from the front, gold hub
			for k in 3:
				var a := -PI * 0.5 + TAU / 3.0 * float(k)
				var d := Vector2(cos(a), sin(a))
				var n := Vector2(-d.y, d.x)
				var pts: Array = [c + n * r * 0.16, c + d * r * 0.35 + n * r * 0.30, c + d * r * 0.88 + n * r * 0.27, c + d * r * 1.0 + n * r * 0.05,
					c + d * r * 0.95 - n * r * 0.14, c + d * r * 0.5 - n * r * 0.2, c - n * r * 0.16]
				poly(ci, pts, col)
			ci.draw_circle(c, r * 0.3, ink)
			ci.draw_circle(c, r * 0.22, Color(Style.ACCENT, col.a))
		# ---- aircraft: side views, nose to the right ----
		"cub":
			rrect(ci, Rect2(c.x - r * 0.75, c.y - r * 0.2, r * 1.5, r * 0.5), r * 0.25, col)
			tri(ci, c + Vector2(-r * 0.7, -r * 0.1), c + Vector2(-r * 1.0, -r * 0.7), c + Vector2(-r * 0.4, -r * 0.1), col)
			ci.draw_line(c + Vector2(-r * 0.3, -r * 0.55), c + Vector2(r * 0.4, -r * 0.55), col, w * 1.3)
			ci.draw_line(c + Vector2(-r * 0.1, -r * 0.2), c + Vector2(-r * 0.1, -r * 0.55), col, w * 0.8)
			ci.draw_line(c + Vector2(r * 0.3, -r * 0.2), c + Vector2(r * 0.3, -r * 0.55), col, w * 0.8)
			ci.draw_line(c + Vector2(r * 0.85, -r * 0.45), c + Vector2(r * 0.85, r * 0.2), col, w * 0.8)
			ci.draw_circle(c + Vector2(-r * 0.1, r * 0.55), r * 0.2, col)
			ci.draw_circle(c + Vector2(r * 0.35, r * 0.55), r * 0.2, col)
		"c172":
			rrect(ci, Rect2(c.x - r * 0.8, c.y - r * 0.15, r * 1.6, r * 0.45), r * 0.22, col)
			tri(ci, c + Vector2(-r * 0.75, -r * 0.05), c + Vector2(-r * 1.0, -r * 0.7), c + Vector2(-r * 0.45, -r * 0.05), col)
			ci.draw_line(c + Vector2(-r * 0.4, -r * 0.55), c + Vector2(r * 0.55, -r * 0.55), col, w * 1.3)
			ci.draw_line(c + Vector2(r * 0.0, -r * 0.15), c + Vector2(r * 0.0, -r * 0.55), col, w * 0.8)
			ci.draw_line(c + Vector2(r * 0.9, -r * 0.4), c + Vector2(r * 0.9, r * 0.25), col, w * 0.8)
			ci.draw_circle(c + Vector2(-r * 0.05, r * 0.6), r * 0.18, col)
			ci.draw_circle(c + Vector2(r * 0.55, r * 0.6), r * 0.18, col)
		"twin":
			rrect(ci, Rect2(c.x - r * 0.9, c.y - r * 0.15, r * 1.8, r * 0.4), r * 0.2, col)
			tri(ci, c + Vector2(-r * 0.85, -r * 0.05), c + Vector2(-r * 1.0, -r * 0.8), c + Vector2(-r * 0.55, -r * 0.05), col)
			rrect(ci, Rect2(c.x - r * 0.25, c.y + r * 0.2, r * 0.9, r * 0.28), r * 0.14, col)
			ci.draw_line(c + Vector2(-r * 0.5, r * 0.05), c + Vector2(r * 0.5, r * 0.05), col, w * 1.6)
			ci.draw_line(c + Vector2(r * 0.95, -r * 0.35), c + Vector2(r * 0.95, r * 0.45), col, w * 0.8)
		"glider":
			rrect(ci, Rect2(c.x - r * 0.9, c.y - r * 0.12, r * 1.8, r * 0.3), r * 0.15, col)
			tri(ci, c + Vector2(-r * 0.85, -r * 0.0), c + Vector2(-r * 1.05, -r * 0.65), c + Vector2(-r * 0.55, -r * 0.0), col)
			ci.draw_line(c + Vector2(-r * 0.2, -r * 0.2), c + Vector2(-r * 0.2, -r * 0.2), col, w)
			ci.draw_line(c + Vector2(-r * 0.7, -r * 0.35), c + Vector2(r * 0.55, -r * 0.35), col, w * 1.1)
			ci.draw_line(c + Vector2(-r * 0.7, -r * 0.35), c + Vector2(-r * 0.7, -r * 0.35), col, w)
			ci.draw_circle(c + Vector2(r * 0.1, r * 0.35), r * 0.14, col)
		"jet":
			poly(ci, [c + Vector2(-r * 0.95, -r * 0.1), c + Vector2(r * 0.7, -r * 0.2), c + Vector2(r * 1.05, r * 0.05), c + Vector2(r * 0.6, r * 0.25), c + Vector2(-r * 0.9, r * 0.2)], col)
			tri(ci, c + Vector2(-r * 0.95, -r * 0.1), c + Vector2(-r * 1.05, -r * 0.8), c + Vector2(-r * 0.55, -r * 0.1), col)
			tri(ci, c + Vector2(-r * 0.1, 0.0), c + Vector2(r * 0.4, 0.0), c + Vector2(-r * 0.4, r * 0.8), col)
			rrect(ci, Rect2(c.x - r * 0.1, c.y + r * 0.2, r * 0.55, r * 0.22), r * 0.1, col)
		# ---- ranks: a badge with wings and one to four chevrons / stars ----
		"rank0", "rank1", "rank2", "rank3", "rank4", "rank5", "rank6", "rank7":
			var n := int(id.substr(4))
			ci.draw_circle(c, r, Color(0, 0, 0, col.a))
			ci.draw_circle(c, r - 3.0, Color(Style.PRIMARY if n < 3 else (Style.SUCCESS if n < 6 else Style.ACCENT), col.a))
			ci.draw_arc(c, r * 0.8, 0.0, TAU, 20, Color(1, 1, 1, col.a * 0.5), w * 0.6)
			if n == 0:
				ci.draw_line(c + Vector2(-r * 0.2, -r * 0.5), c + Vector2(-r * 0.2, r * 0.5), Color.WHITE, w * 1.8)
				ci.draw_line(c + Vector2(-r * 0.2, r * 0.5), c + Vector2(r * 0.45, r * 0.5), Color.WHITE, w * 1.8)
			else:
				var stripes := mini(n, 4)
				for k in stripes:
					var y := c.y + r * 0.35 - k * r * 0.32
					line3(ci, Vector2(c.x - r * 0.5, y + r * 0.2), Vector2(c.x, y - r * 0.12), Vector2(c.x + r * 0.5, y + r * 0.2), Color.WHITE, w * 1.5)
				if n >= 5:
					star_shape(ci, c + Vector2(0, -r * 0.5), r * 0.22, Color.WHITE, false)
				if n >= 7:
					star_shape(ci, c + Vector2(-r * 0.45, -r * 0.35), r * 0.16, Color.WHITE, false)
					star_shape(ci, c + Vector2(r * 0.45, -r * 0.35), r * 0.16, Color.WHITE, false)
		# ---- landing types and weather ----
		"normal":    # a runway in perspective
			quad(ci, c + Vector2(-r * 0.25, -r * 0.8), c + Vector2(r * 0.25, -r * 0.8), c + Vector2(r * 0.9, r * 0.85), c + Vector2(-r * 0.9, r * 0.85), col)
			for k in 3:
				ci.draw_line(c + Vector2(0, -r * 0.6 + k * r * 0.5), c + Vector2(0, -r * 0.4 + k * r * 0.5), ink, w * (0.7 + k * 0.4))
		"short":    # a runway with a tree before it
			ci.draw_rect(Rect2(c.x - r * 0.1, c.y + r * 0.35, r * 1.05, r * 0.4), col)
			tri(ci, c + Vector2(-r * 0.9, r * 0.5), c + Vector2(-r * 0.4, r * 0.5), c + Vector2(-r * 0.65, -r * 0.7), Color(0.35, 0.8, 0.45, col.a))
			ci.draw_rect(Rect2(c.x - r * 0.7, c.y + r * 0.5, r * 0.1, r * 0.3), col)
		"engineout":
			ci.draw_circle(c + Vector2(r * 0.1, r * 0.1), r * 0.55, col)
			ci.draw_line(c + Vector2(-r * 0.9, -r * 0.4), c + Vector2(-r * 0.2, -r * 0.1), col, w * 1.5)
			for k in 3:
				ci.draw_circle(c + Vector2(-r * 0.2 + k * r * 0.35, -r * 0.65 - k * r * 0.12), r * (0.2 + k * 0.06), Color(0.8, 0.82, 0.88, col.a * 0.9))
		"night":    # a moon
			ci.draw_circle(c, r * 0.8, col)
			ci.draw_circle(c + Vector2(r * 0.38, -r * 0.25), r * 0.7, Color(Style.SURFACE_DARK, col.a))
		"mountain":
			tri(ci, c + Vector2(-r, r * 0.8), c + Vector2(-r * 0.05, -r * 0.8), c + Vector2(r * 0.7, r * 0.8), col)
			tri(ci, c + Vector2(r * 0.2, r * 0.8), c + Vector2(r * 0.65, -r * 0.1), c + Vector2(r * 1.0, r * 0.8), col)
			tri(ci, c + Vector2(-r * 0.3, -r * 0.3), c + Vector2(-r * 0.05, -r * 0.8), c + Vector2(r * 0.2, -r * 0.3), Color(1, 1, 1, col.a))
		"carrier":
			poly(ci, [c + Vector2(-r, r * 0.1), c + Vector2(r, r * 0.1), c + Vector2(r * 0.75, r * 0.6), c + Vector2(-r * 0.8, r * 0.6)], col)
			ci.draw_rect(Rect2(c.x + r * 0.2, c.y - r * 0.5, r * 0.35, r * 0.6), col)
			ci.draw_arc(c + Vector2(0, r * 0.85), r * 0.9, PI * 1.1, PI * 1.9, 10, Color(0.45, 0.75, 1.0, col.a), w)
		"water":
			for k in 3:
				ci.draw_arc(c + Vector2(-r * 0.5, -r * 0.35 + k * r * 0.45), r * 0.35, PI, TAU, 8, Color(0.45, 0.75, 1.0, col.a), w * 1.2)
				ci.draw_arc(c + Vector2(r * 0.2, -r * 0.35 + k * r * 0.45), r * 0.35, PI, TAU, 8, Color(0.45, 0.75, 1.0, col.a), w * 1.2)
		"truck":
			ci.draw_rect(Rect2(c.x - r * 0.95, c.y - r * 0.45, r * 1.2, r * 0.8), col)
			quad(ci, c + Vector2(r * 0.3, -r * 0.2), c + Vector2(r * 0.65, -r * 0.2), c + Vector2(r * 0.95, r * 0.1), c + Vector2(r * 0.95, r * 0.35), col)
			ci.draw_rect(Rect2(c.x + r * 0.3, c.y + r * 0.0, r * 0.65, r * 0.35), col)
			ci.draw_circle(c + Vector2(-r * 0.5, r * 0.5), r * 0.25, ink)
			ci.draw_circle(c + Vector2(r * 0.6, r * 0.5), r * 0.25, ink)
			ci.draw_circle(c + Vector2(-r * 0.5, r * 0.5), r * 0.12, col)
			ci.draw_circle(c + Vector2(r * 0.6, r * 0.5), r * 0.12, col)
		"soft":    # grass blades
			for k in 5:
				var x := c.x - r * 0.7 + k * r * 0.35
				tri(ci, Vector2(x - r * 0.12, c.y + r * 0.8), Vector2(x + r * 0.12, c.y + r * 0.8), Vector2(x + (k - 2) * r * 0.1, c.y - r * (0.2 + 0.25 * (k % 2))), Color(0.45, 0.85, 0.45, col.a))
		"poweroff":    # a propeller with a slash
			ci.draw_line(c + Vector2(0, -r * 0.8), c + Vector2(0, r * 0.8), col, w * 1.8)
			ci.draw_line(c + Vector2(-r * 0.8, 0), c + Vector2(r * 0.8, 0), col, w * 1.8)
			ci.draw_line(c + Vector2(-r * 0.9, r * 0.9), c + Vector2(r * 0.9, -r * 0.9), Color(Style.DANGER, col.a), w * 1.6)
		"instrument":    # a cloud over a gauge
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.45, col)
			ci.draw_circle(c + Vector2(r * 0.25, -r * 0.3), r * 0.55, col)
			ci.draw_rect(Rect2(c.x - r * 0.7, c.y - r * 0.2, r * 1.4, r * 0.5), col)
			ci.draw_line(c + Vector2(0, r * 0.4), c + Vector2(0, r * 0.95), ink, w)
			ci.draw_circle(c + Vector2(0, r * 0.7), w * 0.9, ink)
		"clear":
			glyph(ci, "daily", c, r, col)
		"fog":
			for k in 3:
				ci.draw_line(c + Vector2(-r * 0.9 + k * r * 0.2, -r * 0.6 + k * r * 0.6), c + Vector2(r * 0.9 - (2 - k) * r * 0.2, -r * 0.6 + k * r * 0.6), col, w * 1.3)
		"rain":
			ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.3), r * 0.45, col)
			ci.draw_circle(c + Vector2(r * 0.3, -r * 0.2), r * 0.55, col)
			for k in 3:
				ci.draw_line(c + Vector2(-r * 0.5 + k * r * 0.5, r * 0.3), c + Vector2(-r * 0.65 + k * r * 0.5, r * 0.85), Color(0.5, 0.78, 1.0, col.a), w * 1.2)
		"turbulence":
			line3(ci, c + Vector2(-r * 0.9, -r * 0.3), c + Vector2(-r * 0.3, r * 0.3), c + Vector2(r * 0.2, -r * 0.3), col, w * 1.4)
			line3(ci, c + Vector2(-r * 0.3, -r * 0.3), c + Vector2(r * 0.2, r * 0.3), c + Vector2(r * 0.9, -r * 0.3), col, w * 1.4)
		"shear":
			ci.draw_line(c + Vector2(-r * 0.2, -r * 0.9), c + Vector2(-r * 0.2, r * 0.6), col, w * 1.5)
			tri(ci, c + Vector2(-r * 0.7, r * 0.3), c + Vector2(r * 0.3, r * 0.3), c + Vector2(-r * 0.2, r * 0.95), col)
			ci.draw_line(c + Vector2(r * 0.4, -r * 0.5), c + Vector2(r * 0.95, -r * 0.5), col, w)
			ci.draw_line(c + Vector2(r * 0.4, -r * 0.1), c + Vector2(r * 0.8, -r * 0.1), col, w)
		_:
			ci.draw_circle(c, r * 0.5, col)

static func glyph_shirt(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var pts: Array = [c + Vector2(-r * 0.3, -r * 0.8), c + Vector2(-r * 0.95, -r * 0.35), c + Vector2(-r * 0.7, r * 0.05), c + Vector2(-r * 0.5, -r * 0.1),
		c + Vector2(-r * 0.5, r * 0.85), c + Vector2(r * 0.5, r * 0.85), c + Vector2(r * 0.5, -r * 0.1), c + Vector2(r * 0.7, r * 0.05),
		c + Vector2(r * 0.95, -r * 0.35), c + Vector2(r * 0.3, -r * 0.8), c + Vector2(0, -r * 0.5)]
	poly(ci, pts, col)
