class_name Airfield
extends Node3D
## The play layer and the scenery layer.
##   * PLAY LAYER = everything the plane can hit or must read: the ground, the runway and its markings, the trees /
##     hill before it, the PAPI lights, the aim / end posts, the windsock, a mountain slope, a carrier deck, a truck.
##     Full colour and black outlines.
##   * SCENERY = background trees, far hills, clouds. Faded toward the sky colour, unshaded, NO outlines, and
##     scrolling slower than the play layer (parallax), so it can never be mistaken for a hazard.
## Every node is created ONCE in build_pools() and only moved / scaled / shown / hidden for each new round
## (generate() picks the round, build() lays it out), so nothing is allocated in play.

enum { ASPHALT, GRASS, DIRT, WATER, DECK, TRUCK }
enum { FLAT, TREES, HILL }

const SURFACE_NAMES: Array[String] = ["asphalt", "grass", "dirt", "water lane", "carrier deck", "flatbed"]
const TERRAIN_NAMES: Array[String] = ["flat", "trees", "hill"]
const SURFACE_COLORS: Array[Color] = [Color(0.27, 0.28, 0.32), Color(0.5, 0.78, 0.36), Color(0.64, 0.48, 0.32),
	Color(0.62, 0.86, 0.96), Color(0.3, 0.32, 0.37), Color(0.5, 0.5, 0.56)]
const SMOKE_COLORS: Array[Color] = [Color(0.95, 0.95, 0.95), Color(0.7, 0.8, 0.55), Color(0.78, 0.65, 0.48),
	Color(0.95, 0.98, 1.0), Color(0.85, 0.85, 0.85), Color(0.8, 0.8, 0.8)]
const GROUND_COLOR := Color(0.34, 0.6, 0.3)
const SEA_COLOR := Color(0.16, 0.38, 0.62)
const ROAD_COLOR := Color(0.28, 0.28, 0.31)
const ROCK_COLOR := Color(0.55, 0.47, 0.36)
const SKY_COLOR := Color(0.55, 0.78, 0.96)        # the environment background: scenery fades toward this
const HAZARD_CROWN := Color(0.07, 0.4, 0.15)
const HAZARD_TRUNK := Color(0.42, 0.26, 0.12)
const HAZARD_HILL := Color(0.58, 0.7, 0.2)
const MAX_TREES := 8
const MAX_DECO := 30
const MAX_DASHES := 40
const MAX_BARS := 6
const MAX_HILLS := 14
const MAX_CLOUDS := 6
const MAX_STREAKS := 40
const MAX_LIGHTS := 96
const MAX_RAIN := 70
const MAX_WAVES := 30
const DECO_SPAN := 700.0       # scenery wraps around the camera over this many units
const HILL_SPAN := 840.0
const CLOUD_SPAN := 900.0
const RWY_HALF_DEPTH := 6.0

# ---- the round (set by generate()) ----
var scenario := 0
var weather := 0
# the aircraft this round is for (its speed and sink change the glide path; it may need a long runway or have no engine)
var plane_speed := 1.0
var plane_sink := 1.0
var plane_min_len := 0.0
var plane_power := 1.0
var surface := ASPHALT
var terrain := FLAT
var thr := 0.0          # runway threshold (x) - moves with a carrier / truck
var rwy_len := 150.0
var rwy_end := 150.0
var aim_x := 0.0        # centre of the aim markers
var aim_off := 30.0     # aim markers' distance past the threshold
var start_altitude := 34.0
var wind_base := 0.0
var path_slope := 0.16  # nominal descent slope (sink / ground speed) for this wind
var path_error := 0.0   # where the plain approach path would touch down relative to the aim markers
var tree_count := 0
var tree_x := PackedFloat32Array()
var tree_h := PackedFloat32Array()
var tree_hw := PackedFloat32Array()
var hill_on := false
var hill_x := 0.0
var hill_hw := 0.0
var hill_h := 0.0
var papi_x := 0.0       # the PAPI row is centred here (at the aim markers)
var papi_slope := 0.16  # the glide slope the PAPI calls "on path": the descent that reaches the markers
var papi_white := 2     # how many of the four lights show white right now (4 = too high, 2 = on path, 0 = too low)
# scenario state
var slope_m := 0.0      # mountain strip: ground rises this much per unit (0 = flat)
var ramp_x := 0.0       # ... starting here (a little before the threshold)
var deck_h := 0.0       # carrier deck / truck bed height above the sea / road (0 = solid ground)
var deck_speed := 0.0   # ... and how fast it moves (+x)
var deck_off := 0.0     # how far it has moved since the round began
var has_wires := false  # carrier: arrestor wires around the aim point
var night := false
var power := 1.0        # 0 = engine out
var sink_mult := 1.0
var wet := false        # rain: the runway is slippery
var vis_end := 0.0      # fog / rain: how far you can see (0 = unlimited)
var turb := 0.0         # turbulence strength on final (0 = none)
var shear_back := 0.0   # wind shear hits this far before the aim point (0 = none)

var _box := BoxMesh.new()
var _cone := CylinderMesh.new()
var _cyl := CylinderMesh.new()
var _prism := PrismMesh.new()
var _outline: ShaderMaterial
var _ground: MeshInstance3D
var _slope_root: Node3D      # carries the runway: tilted on a mountain strip, moves with a carrier / truck
var _pivot0 := 0.0
var _thr0 := 0.0
var _half_z := RWY_HALF_DEPTH
var _rwy: MeshInstance3D
var _rwy_mat: StandardMaterial3D
var _rwy_root: Node3D        # the runway and its paint: scaled in z when zoomed out so the band stays visible
var _end_bar: MeshInstance3D
var _end_posts: Array[Node3D] = []
var _dashes: Array[MeshInstance3D] = []
var _bars: Array[MeshInstance3D] = []
var _aim_slabs: Array[MeshInstance3D] = []
var _aim_posts: Array[Node3D] = []
var _wires: Array[MeshInstance3D] = []
var _lights: Array[MeshInstance3D] = []
var _light_mats: Array[StandardMaterial3D] = []
var _light_used := 0
var _approach_first := 0
var _approach_count := 0
var _ramp_root: Node3D
var _ramp: MeshInstance3D
var _plateau: MeshInstance3D
var _extras_root: Node3D     # carrier hull + island, truck cab + chassis + wheels
var _hull: MeshInstance3D
var _island: MeshInstance3D
var _cab: MeshInstance3D
var _chassis: MeshInstance3D
var _wheels: Array[MeshInstance3D] = []
var _road: MeshInstance3D
var _waves: Array[MeshInstance3D] = []
var _wave_x := PackedFloat32Array()
var _rain: Array[MeshInstance3D] = []
var _rain_pos := PackedVector3Array()
var _trees: Array[Node3D] = []
var _deco: Array[Node3D] = []
var _deco_base := PackedFloat32Array()
var _hill: MeshInstance3D
var _far_hills: Array[MeshInstance3D] = []
var _hill_base := PackedFloat32Array()
var _clouds: Array[Node3D] = []
var _cloud_base := PackedFloat32Array()
var _cloud_speed := PackedFloat32Array()
var _papi_root: Node3D
var _papi_mats: Array[StandardMaterial3D] = []
var _beacons: Array[Node3D] = []              # [tallest tree top, hill peak]: blinking obstruction lights on the hazards
var _beacon_mats: Array[StandardMaterial3D] = []
var _zs := 1.0                                # current runway z-stretch
var _mark := 1.0                              # current marker scale (posts, PAPI, beacons, windsock)
var _streaks: Array[MeshInstance3D] = []
var _streak_pos := PackedVector3Array()
var _sock_root: Node3D
var _sock_pivot: Node3D
var _sock_snap := 0.0                         # > 0: the windsock has snapped round (the wind-shear warning)
var _prewarm_all := false
var _t := 0.0

func _ready() -> void:
	_cone.top_radius = 0.0
	_cone.bottom_radius = 0.5
	_cone.height = 1.0
	_cone.radial_segments = 6
	_cone.rings = 1
	_cyl.top_radius = 0.5
	_cyl.bottom_radius = 0.5
	_cyl.height = 1.0
	_cyl.radial_segments = 8
	_cyl.rings = 1
	_outline = ShaderMaterial.new()
	_outline.shader = preload("res://shaders/outline.gdshader")
	_outline.set_shader_parameter("thickness", Tuning.outline_thickness)
	build_pools()

func build_pools() -> void:
	tree_x.resize(MAX_TREES)
	tree_h.resize(MAX_TREES)
	tree_hw.resize(MAX_TREES)
	_ground = _mi(_box, GROUND_COLOR, true)
	_slope_root = Node3D.new()
	add_child(_slope_root)
	_rwy_root = Node3D.new()
	_slope_root.add_child(_rwy_root)
	_rwy_mat = StandardMaterial3D.new()
	_rwy_mat.roughness = 1.0
	_rwy = _mi(_box, SURFACE_COLORS[0], true, _rwy_root)
	_rwy.material_override = _rwy_mat
	for i in MAX_DASHES:
		_dashes.append(_mi(_box, Color(0.95, 0.95, 0.9), false, _rwy_root))
	for i in MAX_BARS:
		_bars.append(_mi(_box, Color(0.95, 0.95, 0.9), false, _rwy_root))
	for i in 2:
		_aim_slabs.append(_mi(_box, Color(0.97, 0.97, 0.95), false, _rwy_root))
		_aim_posts.append(_make_post(Color(1.0, 0.55, 0.1), Vector3(0.5, 2.8, 0.5)))
		_end_posts.append(_make_post(Color(0.9, 0.2, 0.15), Vector3(0.6, 3.2, 0.6)))
	_end_bar = _mi(_box, Color(0.9, 0.2, 0.15), false, _rwy_root)
	# --- play layer: hazards (full colour, black outlines)
	for i in MAX_TREES:
		_trees.append(_make_tree(HAZARD_CROWN, HAZARD_TRUNK, true))
	_hill = _mi(_prism, HAZARD_HILL, true)
	# --- scenery: faded toward the sky, unshaded, no outlines, parallax (positions set in update())
	for i in MAX_DECO:
		var crown := Color(0.25, 0.55, 0.3).lerp(SKY_COLOR, Tuning.scenery_haze_trees)
		var trunk := Color(0.45, 0.32, 0.2).lerp(SKY_COLOR, Tuning.scenery_haze_trees)
		var t := _make_tree(crown, trunk, false)
		_set_tree(t, 0.0, -9.0 - fmod(float(i) * 2.9, 7.0), 3.0 + fmod(float(i) * 3.7, 3.5), 1.4 + fmod(float(i) * 1.3, 1.0))
		_deco.append(t)
		_deco_base.append(float(i) * DECO_SPAN / float(MAX_DECO) + fmod(float(i) * 7.3, 6.0))
	for i in MAX_HILLS:
		var hh := 4.0 + fmod(float(i) * 5.3, 7.0)
		var hc := Color(0.45, 0.6, 0.55).lerp(Color(0.4, 0.58, 0.45), float(i % 3) / 3.0).lerp(SKY_COLOR, Tuning.scenery_haze_hills)
		var hm := _mi(_prism, hc, false, null, true)
		hm.position = Vector3(0.0, hh * 0.5 - 0.5, -28.0)
		hm.scale = Vector3(34.0 + fmod(float(i) * 11.0, 30.0), hh, 18.0)
		_far_hills.append(hm)
		_hill_base.append(float(i) * HILL_SPAN / float(MAX_HILLS))
	for i in MAX_CLOUDS:
		var c := Node3D.new()
		add_child(c)
		for k in 3:
			var b := _mi(_box, Color(1, 1, 1).lerp(SKY_COLOR, 0.2), false, c, true)
			b.position = Vector3((k - 1) * 4.0, (k % 2) * 1.2, 0.0)
			b.scale = Vector3(7.0 - k * 1.5, 2.2 + k * 0.4, 3.0)
		c.position.y = 46.0 + fmod(float(i) * 13.0, 30.0)
		c.position.z = -40.0
		_clouds.append(c)
		_cloud_base.append(float(i) * CLOUD_SPAN / float(MAX_CLOUDS))
		_cloud_speed.append(0.8 + 0.25 * i)
	_build_papi()
	for i in 2:
		_beacons.append(_make_beacon())
	_build_scenario_pools()
	_streak_pos.resize(MAX_STREAKS)
	var smat := StandardMaterial3D.new()
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.albedo_color = Color(1, 1, 1, 0.5)
	for i in MAX_STREAKS:
		var st := MeshInstance3D.new()
		st.mesh = _box
		st.material_override = smat
		st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(st)
		_streaks.append(st)
		_streak_pos[i] = Vector3((i * 7919 % 100) / 100.0, 3.0 + float(i * 4373 % 100) * 0.35, 3.0 + float(i % 4))
	_build_sock()
	generate(1, RandomNumberGenerator.new())
	build()

## Everything the scenarios and the weather add, built once: mountain ramp, carrier hull / island / wires, truck, road,
## water waves, runway + approach lights (night) and rain streaks.
func _build_scenario_pools() -> void:
	_ramp_root = Node3D.new()
	add_child(_ramp_root)
	_ramp = _mi(_box, ROCK_COLOR, true, _ramp_root)
	_plateau = _mi(_box, ROCK_COLOR, true)
	_extras_root = Node3D.new()
	add_child(_extras_root)
	_hull = _mi(_box, Color(0.42, 0.45, 0.5), true, _extras_root)
	_island = _mi(_box, Color(0.62, 0.64, 0.68), true, _extras_root)
	_cab = _mi(_box, Color(0.85, 0.25, 0.2), true, _extras_root)
	_chassis = _mi(_box, Color(0.22, 0.22, 0.27), true, _extras_root)
	for i in 3:
		var w := _mi(_cyl, Color(0.12, 0.12, 0.14), true, _extras_root)
		w.rotation_degrees = Vector3(90, 0, 0)
		_wheels.append(w)
	for i in 4:
		_wires.append(_mi(_box, Color(0.12, 0.12, 0.12), false, _rwy_root))
	_road = _mi(_box, ROAD_COLOR, true)
	for i in MAX_WAVES:
		var wv := _mi(_box, Color(0.9, 0.97, 1.0), false, null, true)
		_waves.append(wv)
		_wave_x.append(-150.0 + float(i) * 23.7 + fmod(float(i) * 5.3, 7.0))
	for i in MAX_LIGHTS:
		var lm := _mi(_box, Color(1, 1, 1), false, _rwy_root, true)
		lm.scale = Vector3(0.7, 0.7, 0.7)
		_lights.append(lm)
		_light_mats.append(lm.material_override as StandardMaterial3D)
	var rmat := StandardMaterial3D.new()
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rmat.albedo_color = Color(0.75, 0.85, 1.0, 0.55)
	_rain_pos.resize(MAX_RAIN)
	for i in MAX_RAIN:
		var rs := MeshInstance3D.new()
		rs.mesh = _box
		rs.material_override = rmat
		rs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rs.rotation_degrees = Vector3(0, 0, 12)
		add_child(rs)
		_rain.append(rs)
		_rain_pos[i] = Vector3(float(i * 7919 % 100) / 100.0, float(i * 4373 % 100) / 100.0, 4.0 + float(i % 3))

func _build_sock() -> void:
	_sock_root = Node3D.new()
	add_child(_sock_root)
	var pole := _mi(_box, Color(0.85, 0.85, 0.85), true, _sock_root)
	pole.scale = Vector3(0.3, 8.0, 0.3)
	pole.position = Vector3(0, 4.0, 0)
	_sock_pivot = Node3D.new()
	_sock_pivot.position = Vector3(0, 8.0, 0)
	_sock_root.add_child(_sock_pivot)
	for i in 4:
		var seg := _mi(_cyl, Color(1.0, 0.45, 0.1) if i % 2 == 0 else Color(0.97, 0.97, 0.97), true, _sock_pivot)
		seg.rotation_degrees = Vector3(0, 0, 90)
		seg.scale = Vector3(1.0 - i * 0.17, 1.15, 1.0 - i * 0.17)
		seg.position = Vector3(0.7 + 1.15 * i, 0, 0)

func _make_tree(crown: Color, trunk: Color, outlined: bool) -> Node3D:
	var t := Node3D.new()
	add_child(t)
	_mi(_box, trunk, outlined, t, not outlined)      # child 0: trunk
	_mi(_cone, crown, outlined, t, not outlined)     # child 1: crown
	return t

func _make_post(color: Color, size: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var m := _mi(_box, color, true, root)
	m.scale = size
	m.position = Vector3(0, size.y * 0.5, 0)
	return root

func _make_beacon() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var m := _mi(_box, Color(1.0, 0.45, 0.1), true, root, true)
	m.scale = Vector3(0.9, 0.9, 0.9)
	_beacon_mats.append(m.material_override as StandardMaterial3D)
	return root

func _build_papi() -> void:
	_papi_root = Node3D.new()
	add_child(_papi_root)
	for i in 4:
		var h := _mi(_box, Color(0.36, 0.38, 0.42), false, _papi_root)
		h.scale = Vector3(1.9, 1.9, 1.9)
		h.position = Vector3((float(i) - 1.5) * 2.7, 0.95, 0.0)
		var lens := _mi(_box, Color(1, 1, 1), false, _papi_root, true)
		lens.scale = Vector3(1.25, 1.25, 0.25)
		lens.position = Vector3((float(i) - 1.5) * 2.7, 0.95, 1.0)
		_papi_mats.append(lens.material_override as StandardMaterial3D)

func _mi(mesh: Mesh, color: Color, outlined: bool, parent: Node3D = null, unshaded: bool = false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	if outlined:
		m.material_overlay = _outline
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else self).add_child(m)
	return m

func _set_color(m: MeshInstance3D, c: Color) -> void:
	(m.material_override as StandardMaterial3D).albedo_color = c

func _place(m: Node3D, pos: Vector3, size: Vector3) -> void:
	m.position = pos
	m.scale = size
	m.visible = true

## The aircraft the next round is generated for.
func set_plane(id: int) -> void:
	var pr: Dictionary = Planes.profile(id)
	plane_speed = pr["speed"]
	plane_sink = pr["sink"]
	plane_min_len = pr["min_len"]
	plane_power = pr["power"]

## Choose the round: scenario, surface, length, terrain, wind, weather, where the approach starts and how it misses
## the markers.
func generate(round_no: int, rng: RandomNumberGenerator, scn: int = 0, wx: int = 0) -> void:
	scenario = scn
	weather = wx
	var r := Tuning.ramp(round_no)
	slope_m = 0.0
	deck_h = 0.0
	deck_speed = 0.0
	deck_off = 0.0
	has_wires = false
	night = scn == Scenarios.NIGHT
	power = 0.0 if (scn == Scenarios.ENGINE_OUT or plane_power == 0.0) else 1.0
	sink_mult = Tuning.engine_out_sink_mult if scn == Scenarios.ENGINE_OUT else 1.0
	wet = wx == Scenarios.RAIN
	vis_end = 0.0
	turb = 0.0
	shear_back = 0.0
	# surface and length
	if round_no <= 2 and scn == Scenarios.STANDARD:
		surface = ASPHALT
	else:
		var u := rng.randf()
		surface = ASPHALT if u < 0.5 else (GRASS if u < 0.75 else DIRT)
	var lo := Tuning.runway_length_asphalt_min
	var hi := Tuning.runway_length_asphalt_max
	if surface == GRASS:
		lo = Tuning.runway_length_grass_min
		hi = Tuning.runway_length_grass_max
	elif surface == DIRT:
		lo = Tuning.runway_length_dirt_min
		hi = Tuning.runway_length_dirt_max
	rwy_len = rng.randf_range(lo, hi) * (1.0 - Tuning.runway_shrink * r)
	match scn:
		Scenarios.SHORT_FIELD:
			surface = ASPHALT if rng.randf() < 0.6 else GRASS
			rwy_len = rng.randf_range(68.0, 100.0) * (1.0 - 0.12 * r)
		Scenarios.MOUNTAIN:
			surface = DIRT if rng.randf() < 0.65 else GRASS
			rwy_len = rng.randf_range(110.0, 170.0) * (1.0 - 0.1 * r)
			slope_m = tan(deg_to_rad(rng.randf_range(Tuning.mountain_slope_min, Tuning.mountain_slope_max)))
		Scenarios.WATER:
			surface = WATER
			rwy_len = rng.randf_range(130.0, 210.0)
		Scenarios.CARRIER:
			surface = DECK
			rwy_len = rng.randf_range(105.0, 135.0) * (1.0 - 0.08 * r)
			deck_h = Tuning.carrier_deck_height
			deck_speed = rng.randf_range(Tuning.carrier_speed_min, Tuning.carrier_speed_max)
			has_wires = true
		Scenarios.TRUCK:
			surface = TRUCK
			rwy_len = rng.randf_range(Tuning.truck_len_min, Tuning.truck_len_max)
			deck_h = Tuning.truck_height
			deck_speed = rng.randf_range(Tuning.truck_speed_min, Tuning.truck_speed_max)
	# a fast aircraft needs a long paved runway
	if plane_min_len > 0.0 and (scn == Scenarios.STANDARD or scn == Scenarios.ENGINE_OUT or scn == Scenarios.NIGHT):
		surface = ASPHALT
		rwy_len = maxf(rwy_len, plane_min_len)
	# terrain: nothing in the first rounds; only the standard and short-field approaches have obstacles
	terrain = FLAT
	if scn == Scenarios.SHORT_FIELD:
		terrain = TREES
	elif scn == Scenarios.STANDARD and round_no > 2:
		var short := 1.0 - clampf((rwy_len - 80.0) / 160.0, 0.0, 1.0)
		var u2 := rng.randf()
		if u2 < 0.25 + 0.3 * short:
			terrain = TREES
		elif u2 < 0.45 + 0.4 * short:
			terrain = HILL
	# wind: mild at first, up to the full range later
	var wscale := 0.3 + 0.7 * r
	wind_base = rng.randf_range(-Tuning.wind_tail_max * wscale, Tuning.wind_head_max * wscale)
	if not Tuning.wind_enabled:
		wind_base = 0.0
	# weather
	match wx:
		Scenarios.FOG:
			vis_end = rng.randf_range(Tuning.fog_end_min, Tuning.fog_end_max) * (1.15 - 0.35 * r)
		Scenarios.RAIN:
			vis_end = Tuning.rain_vis_end * (1.1 - 0.3 * r)
		Scenarios.TURBULENCE:
			turb = Tuning.turb_strength * (0.7 + 0.6 * r)
		Scenarios.SHEAR:
			shear_back = rng.randf_range(35.0, 60.0)
	# the plain approach path: sink / ground speed
	path_slope = Tuning.trim_sink * sink_mult * plane_sink / maxf(Tuning.approach_speed * plane_speed - wind_base, 6.0)
	start_altitude = rng.randf_range(Tuning.start_altitude_min, Tuning.start_altitude_max) + deck_h
	aim_off = clampf(rwy_len * Tuning.aim_fraction, Tuning.aim_min, Tuning.aim_max)
	if scn == Scenarios.TRUCK:
		aim_off = rwy_len * 0.45
	elif scn == Scenarios.CARRIER:
		aim_off = rwy_len * 0.4
	var emax := Tuning.path_error_max * (0.4 + 0.6 * r)
	if deck_h > 0.0:
		emax *= 0.6
	# Obstacles are laid out relative to the threshold. The aim markers then move far enough down the runway
	# that a comfortable descent (a bit steeper than the plain approach path) from over the obstacles reaches
	# them - so "trees before a short field" means the markers are further down and the runway left is shorter.
	var comfy := path_slope * 1.2
	tree_count = 0
	hill_on = false
	var cap_off := rwy_len * 0.5
	if terrain == TREES:
		tree_count = rng.randi_range(3, 6)
		var gap := rng.randf_range(4.0, 9.0)
		var spacing := rng.randf_range(4.5, 6.5)
		for i in tree_count:
			var rel := -gap - float(i) * spacing + rng.randf_range(-0.8, 0.8)
			tree_x[i] = rel
			tree_hw[i] = rng.randf_range(1.8, 2.6)
			tree_h[i] = rng.randf_range(5.0, 10.0)
			aim_off = maxf(aim_off, rel + (tree_h[i] + 2.5) / comfy)
		if aim_off > cap_off:
			aim_off = cap_off
			for i in tree_count:   # too tall for this short field: cut the trees down to what the markers allow
				tree_h[i] = clampf(minf(tree_h[i], (aim_off - tree_x[i]) * comfy - 2.5), 3.0, 10.0)
	elif terrain == HILL:
		hill_on = true
		hill_hw = rng.randf_range(14.0, 22.0)
		hill_x = -rng.randf_range(8.0, 14.0) - hill_hw
		hill_h = rng.randf_range(5.0, 9.0)
		aim_off = maxf(aim_off, hill_x + (hill_h + 2.5) / comfy)
		if aim_off > cap_off:
			aim_off = cap_off
			hill_h = clampf(minf(hill_h, (aim_off - hill_x) * comfy - 2.5), 3.0, 9.0)
	# where the plain approach path would touch down relative to the markers: random, but never under the obstacles;
	# an engine-out glide comes in short (you have to stretch it)
	if power == 0.0:
		path_error = rng.randf_range(-emax * 0.9, emax * 0.15)
	else:
		path_error = rng.randf_range(-emax, emax)
	if terrain != FLAT:
		var need := -INF
		for i in tree_count:
			need = maxf(need, (tree_h[i] + 1.2) / path_slope - (aim_off - tree_x[i]))
		if hill_on:
			need = maxf(need, (hill_h + 1.2) / path_slope - (aim_off - hill_x))
		path_error = maxf(path_error, need)
	# Where the threshold has to be at the moment of touchdown so the plain path meets the ground (or the deck, or the
	# slope) path_error from the markers; a moving deck is started further back by how far it travels meanwhile.
	var lead := 25.0 if slope_m > 0.0 else 0.0
	var gs_nom := maxf(Tuning.approach_speed * plane_speed - wind_base, 6.0)
	var thr0 := 0.0
	for attempt in 8:
		var s := path_slope
		var thr_t := (start_altitude - deck_h - (s + slope_m) * (aim_off + path_error) - slope_m * lead) / s
		var x_t := thr_t + aim_off + path_error
		thr0 = thr_t - deck_speed * x_t / gs_nom
		if thr0 >= 60.0:
			break
		start_altitude += (60.0 - thr0) * s * 1.2 + 0.5     # too close: start a little higher instead
	_thr0 = thr0
	thr = thr0
	rwy_end = thr + rwy_len
	aim_x = thr + aim_off
	papi_x = aim_x
	ramp_x = thr - lead
	papi_slope = comfy if terrain != FLAT else path_slope    # the glide that reaches the markers (and clears the obstacles)
	for i in tree_count:
		tree_x[i] += thr          # to world x
	if hill_on:
		hill_x += thr

## Lay the pooled nodes out for the round (also hides what this round doesn't use).
func build() -> void:
	_half_z = RWY_HALF_DEPTH
	if scenario == Scenarios.TRUCK:
		_half_z = 3.5
	elif scenario == Scenarios.CARRIER:
		_half_z = 8.0
	var water_like := surface == WATER or surface == DECK
	_set_color(_ground, SEA_COLOR if water_like else GROUND_COLOR)
	_rwy_mat.albedo_color = SURFACE_COLORS[surface]
	var span_l := -160.0
	var span_r := rwy_end + 260.0
	_place(_ground, Vector3((span_l + span_r) * 0.5, -350.0, 0.0), Vector3(span_r - span_l, 700.0, 60.0))   # (deep: nothing shows below it when zoomed far out)
	# the runway sits on a carrier: slope for a mountain strip, deck height for a carrier / truck, moving with the deck
	_pivot0 = ramp_x if slope_m > 0.0 else _thr0
	_slope_root.position = Vector3(_pivot0, 0.0 if slope_m > 0.0 else deck_h, 0.0)
	_slope_root.rotation = Vector3(0.0, 0.0, atan(slope_m))
	_rwy_root.position = Vector3(-_pivot0, 0.0, 0.0)
	_extras_root.position = Vector3.ZERO
	_place(_rwy, Vector3((thr + rwy_end) * 0.5, -0.02, 0.0), Vector3(rwy_len, 0.12, _half_z * 2.0))
	var line_col := Color(0.97, 0.97, 0.95) if surface == ASPHALT or surface == DECK else Color(0.95, 0.9, 0.7)
	var paint := surface != WATER and surface != TRUCK
	var dash_n := mini(int(rwy_len / 9.0), MAX_DASHES) if paint else 0
	for i in MAX_DASHES:
		var d := _dashes[i]
		d.visible = i < dash_n
		if d.visible:
			_set_color(d, line_col)
			_place(d, Vector3(thr + 10.0 + float(i) * 9.0 + 2.0, 0.05, 0.0), Vector3(4.0, 0.03, 0.5))
			d.visible = d.position.x < rwy_end - 6.0
	for i in MAX_BARS:
		var b := _bars[i]
		b.visible = paint
		_set_color(b, line_col)
		_place(b, Vector3(thr + 1.6, 0.05, -_half_z + 1.5 + float(i) * (2.0 * _half_z - 3.0) / float(MAX_BARS - 1)), Vector3(3.0, 0.03, 0.8))
		b.visible = paint
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		_place(_aim_slabs[k], Vector3(aim_x, 0.06, side * _half_z * 0.5), Vector3(7.0, 0.03, 1.1))
	_place(_end_bar, Vector3(rwy_end - 0.6, 0.06, 0.0), Vector3(1.2, 0.03, _half_z * 2.0))
	_end_bar.visible = surface != WATER
	# carrier wires
	for i in 4:
		_wires[i].visible = has_wires
		if has_wires:
			_place(_wires[i], Vector3(aim_x + (float(i) - 1.5) * Tuning.carrier_wire_half * 0.66, 0.07, 0.0), Vector3(0.35, 0.05, _half_z * 1.7))
	for i in MAX_TREES:
		var t := _trees[i]
		t.visible = i < tree_count
		if t.visible:
			_set_tree(t, tree_x[i], 0.0, tree_h[i], tree_hw[i])
	_hill.visible = hill_on
	if hill_on:
		_place(_hill, Vector3(hill_x, hill_h * 0.5, 0.0), Vector3(hill_hw * 2.0, hill_h, 16.0))
	# blinking obstruction lights on the tallest tree and the hill peak
	_beacons[0].visible = tree_count > 0
	if tree_count > 0:
		var best := 0
		for i in tree_count:
			if tree_h[i] > tree_h[best]:
				best = i
		_beacons[0].position = Vector3(tree_x[best], tree_h[best] + 0.9, 0.0)
	_beacons[1].visible = hill_on
	if hill_on:
		_beacons[1].position = Vector3(hill_x, hill_h + 0.9, 0.0)
	_build_mountain()
	_build_extras()
	_build_lights()
	_layout_markers()
	papi_white = 2
	_paint_papi()

## Mountain strip: a ramp that starts a little before the threshold and a plateau after the runway.
func _build_mountain() -> void:
	_ramp_root.visible = slope_m > 0.0
	_plateau.visible = slope_m > 0.0
	if slope_m <= 0.0:
		return
	var ang := atan(slope_m)
	var plateau_x := rwy_end + 20.0
	var ramp_len := (plateau_x - ramp_x) / cos(ang)
	var tuck := 80.0      # the ramp's low end runs on under the ground, so its cut edge is never seen
	_ramp_root.position = Vector3(ramp_x, 0.0, 0.0)
	_ramp_root.rotation = Vector3(0.0, 0.0, ang)
	_place(_ramp, Vector3((ramp_len - tuck) * 0.5, -350.0, 0.0), Vector3(ramp_len + tuck, 700.0, 60.0))
	_place(_plateau, Vector3(plateau_x + 150.0, ground_y(plateau_x) - 350.0, 0.0), Vector3(300.0, 700.0, 60.0))

## Carrier hull + island, truck chassis + cab + wheels + road, water waves.
func _build_extras() -> void:
	var carrier := scenario == Scenarios.CARRIER
	var truck := scenario == Scenarios.TRUCK
	_hull.visible = carrier
	_island.visible = carrier
	_cab.visible = truck
	_chassis.visible = truck
	_road.visible = truck
	for w in _wheels:
		w.visible = truck
	if carrier:
		_place(_hull, Vector3((thr + rwy_end) * 0.5 - 4.0, deck_h * 0.5 - 0.1, 0.0), Vector3(rwy_len + 24.0, deck_h, _half_z * 2.0 + 4.0))
		_place(_island, Vector3(thr + rwy_len * 0.62, deck_h + 4.0, -_half_z - 0.2), Vector3(14.0, 8.0, 4.0))
	if truck:
		_place(_chassis, Vector3((thr + rwy_end) * 0.5, deck_h - 0.9, 0.0), Vector3(rwy_len + 2.0, 1.2, 4.4))
		_place(_cab, Vector3(rwy_end + 3.6, 2.3, 0.0), Vector3(6.0, 4.6, _half_z * 2.0))
		for i in 3:
			_place(_wheels[i], Vector3(thr + 3.0 + float(i) * (rwy_len - 6.0) * 0.5, 1.0, 0.0), Vector3(2.0, _half_z * 2.0 + 1.2, 2.0))
		_place(_road, Vector3((thr + rwy_end) * 0.5, -0.05, 0.0), Vector3(rwy_end + 500.0, 0.1, 20.0))
	var water := surface == WATER
	for i in MAX_WAVES:
		_waves[i].visible = water
		if water:
			_waves[i].position = Vector3(_wave_x[i], 0.1, -13.0 + fmod(float(i) * 3.7, 26.0))
			_waves[i].scale = Vector3(3.0 + fmod(float(i) * 1.3, 2.0), 0.18, 0.45)

## Night: runway edge lights, threshold (green) and end (red) lights, and a chain of approach lights before the threshold.
func _build_lights() -> void:
	_light_used = 0
	_approach_first = 0
	_approach_count = 0
	if not night:
		return
	var step := maxf(rwy_len / 22.0, 6.0)
	var n := int(rwy_len / step)
	for i in n + 1:
		for side in [-1.0, 1.0]:
			_set_light(Vector3(thr + float(i) * step, 0.35, side * (_half_z - 0.3)), Color(1.0, 0.95, 0.7))
	for i in 6:
		_set_light(Vector3(thr + 0.4, 0.35, -_half_z + 0.6 + float(i) * (2.0 * _half_z - 1.2) / 5.0), Color(0.2, 1.0, 0.35))
		_set_light(Vector3(rwy_end - 0.4, 0.35, -_half_z + 0.6 + float(i) * (2.0 * _half_z - 1.2) / 5.0), Color(1.0, 0.2, 0.15))
	_approach_first = _light_used
	for k in 16:
		_set_light(Vector3(thr - 6.0 * float(k + 1), 0.35, 0.0), Color(1, 1, 1))
	_approach_count = 16

func _set_light(pos: Vector3, color: Color) -> void:
	if _light_used >= MAX_LIGHTS:
		return
	_lights[_light_used].position = pos
	_light_mats[_light_used].albedo_color = color
	_light_used += 1

## Posts and the PAPI sit just outside the runway edge, which moves out when the runway is stretched in z; they ride on
## the slope / deck and move with a carrier / truck.
func _layout_markers() -> void:
	var edge := _half_z * _zs + 1.5
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		_aim_posts[k].position = Vector3(aim_x, ground_y(aim_x), side * edge)
		_aim_posts[k].scale = Vector3.ONE * _mark
		_end_posts[k].position = Vector3(rwy_end + 1.0, ground_y(rwy_end - 1.0), side * edge)
		_end_posts[k].scale = Vector3.ONE * _mark
		_end_posts[k].visible = surface != WATER
	_papi_root.position = Vector3(papi_x, ground_y(papi_x), edge + 1.5)   # (the small runway PAPI is scenery: it never scales with the zoom)
	_sock_root.position = Vector3(thr + 6.0, ground_y(thr + 6.0), -(edge + 1.0))
	_sock_root.scale = Vector3.ONE * _mark
	for b in _beacons:
		b.scale = Vector3.ONE * _mark

func _set_tree(t: Node3D, cx: float, cz: float, h: float, hw: float) -> void:
	t.position = Vector3(cx, 0.0, cz)
	t.visible = true
	var trunk := t.get_child(0) as Node3D
	var crown := t.get_child(1) as Node3D
	trunk.position = Vector3(0, 0.125 * h, 0)
	trunk.scale = Vector3(hw * 0.35, 0.25 * h, hw * 0.35)
	crown.position = Vector3(0, 0.625 * h, 0)
	crown.scale = Vector3(hw * 2.0, 0.75 * h, hw * 2.0)

## Height of the highest obstacle under x (0 = open ground): trees, the hill, and the stern of a carrier / truck.
func height_at(px: float) -> float:
	var h := 0.0
	for i in tree_count:
		var d := absf(px - tree_x[i])
		if d < tree_hw[i]:
			h = maxf(h, tree_h[i] * (0.25 + 0.75 * (1.0 - d / tree_hw[i])))
	if hill_on:
		var dh := absf(px - hill_x)
		if dh < hill_hw:
			h = maxf(h, hill_h * (1.0 - dh / hill_hw))
	if deck_h > 0.0 and px > thr - 3.0 and px < thr:
		h = maxf(h, deck_h)
	return h

## Height of the ground the plane can touch down on at x: 0 on the flat, up the slope of a mountain strip, the deck height
## over a carrier deck / truck bed.
func ground_y(px: float) -> float:
	if deck_h > 0.0:
		return deck_h if (px >= thr and px <= rwy_end) else 0.0
	if slope_m > 0.0:
		return clampf(px - ramp_x, 0.0, rwy_end + 20.0 - ramp_x) * slope_m
	return 0.0

## The ground's slope at x (rise per unit run): the mountain ramp, else 0.
func slope_at(px: float) -> float:
	if slope_m > 0.0 and px > ramp_x and px < rwy_end + 20.0:
		return slope_m
	return 0.0

## Can the plane land at x? (A seaplane can land anywhere on the water; the calm lane is the runway.)
func on_runway(px: float) -> bool:
	if surface == WATER:
		return true
	return px >= thr - 0.5 and px <= rwy_end

## On the calm water lane (only matters for the seaplane: outside it the water is rough).
func in_lane(px: float) -> bool:
	return px >= thr and px <= rwy_end

func surface_decel() -> float:
	var d := Tuning.decel_asphalt
	match surface:
		GRASS:
			d = Tuning.decel_grass
		DIRT:
			d = Tuning.decel_dirt
		WATER:
			d = Tuning.water_decel
		DECK:
			d = Tuning.deck_decel
		TRUCK:
			d = Tuning.truck_decel
	if wet:
		d *= Tuning.rain_wet_decel
	return d

func smoke_color() -> Color:
	return SMOKE_COLORS[surface]

## A carrier / truck keeps moving: shift the threshold, markers and everything riding on it.
func step_deck(dt: float) -> void:
	if deck_speed <= 0.0:
		return
	deck_off += deck_speed * dt
	thr = _thr0 + deck_off
	rwy_end = thr + rwy_len
	aim_x = thr + aim_off
	papi_x = aim_x
	_slope_root.position.x = _pivot0 + deck_off
	_extras_root.position.x = deck_off

## The windsock snaps round (wind-shear warning) for a moment.
func snap_sock() -> void:
	_sock_snap = 1.6

## Per frame: zoom-dependent scaling, scenery parallax, drifting wind streaks, windsock, beacons, night lights, rain, waves.
## `head` = total headwind, `cam_x` / `cam_y` / `view_w` = what is on screen.
func update(dt: float, cam_x: float, view_w: float, head: float, cam_y: float = 20.0) -> void:
	_t += dt
	if _sock_snap > 0.0:
		_sock_snap = maxf(_sock_snap - dt, 0.0)
	# When zoomed out the play-layer details would shrink to nothing: stretch the runway band, scale the markers
	# and thicken the black outlines with the zoom (all of it eases back to the normal size in the close framing).
	_zs = clampf(view_w / 60.0, 1.0, 3.2)
	_mark = clampf(view_w / 70.0, 1.0, 6.0)
	_rwy_root.scale = Vector3(1.0, 1.0, _zs)
	_outline.set_shader_parameter("thickness", Tuning.outline_thickness * clampf(view_w / 54.0, 1.0, 8.0))
	_layout_markers()
	# beacons blink between orange and red
	var blink := 0.5 + 0.5 * sin(_t * 5.0)
	for m in _beacon_mats:
		m.albedo_color = Color(1.0, 0.25 + 0.3 * blink, 0.05)
	# scenery: parallax (slower than the play layer), wrapped around the camera; at night it is dark and gone
	var scenery_on := not night or _prewarm_all
	var trees_on := scenery_on and surface != WATER and surface != DECK    # (no background trees standing on the sea)
	for i in MAX_DECO:
		var off := fposmod(_deco_base[i] - Tuning.parallax_trees * cam_x + DECO_SPAN * 0.5, DECO_SPAN) - DECO_SPAN * 0.5
		_deco[i].position.x = cam_x + off
		_deco[i].visible = trees_on or _prewarm_all
	for i in MAX_HILLS:
		var off2 := fposmod(_hill_base[i] - Tuning.parallax_hills * cam_x + HILL_SPAN * 0.5, HILL_SPAN) - HILL_SPAN * 0.5
		_far_hills[i].position.x = cam_x + off2
		_far_hills[i].visible = scenery_on
	var show_clouds := not DebugFlags.off("clouds") and scenery_on
	for i in MAX_CLOUDS:
		var c := _clouds[i]
		c.visible = show_clouds
		_cloud_base[i] += _cloud_speed[i] * dt
		var off3 := fposmod(_cloud_base[i] - Tuning.parallax_clouds * cam_x + CLOUD_SPAN * 0.5, CLOUD_SPAN) - CLOUD_SPAN * 0.5
		c.position.x = cam_x + off3
	# night lights: the approach lights chase toward the runway
	var light_scale := 0.7 * clampf(view_w / 60.0, 1.0, 6.0)    # (they stay visible when the view is zoomed out)
	for i in MAX_LIGHTS:
		_lights[i].visible = (i < _light_used and night) or _prewarm_all
		_lights[i].scale = Vector3.ONE * light_scale
	if night and _approach_count > 0:
		for k in _approach_count:
			var phase := fposmod(_t * 1.6 - float(_approach_count - 1 - k) * 0.06, 1.0)
			var glow := 1.0 if phase < 0.12 else 0.3
			_light_mats[_approach_first + k].albedo_color = Color(glow, glow, glow)
	# water: the waves bob (the lane is calm, the rest is rough)
	if surface == WATER or _prewarm_all:
		for i in MAX_WAVES:
			var rough := not in_lane(_wave_x[i])
			_waves[i].visible = true
			_waves[i].position.y = 0.1 + (0.22 if rough else 0.05) * sin(_t * 1.8 + float(i))
	# rain streaks fall through the view
	var raining := weather == Scenarios.RAIN or _prewarm_all
	var vs := get_viewport().get_visible_rect().size
	var view_h := view_w * vs.y / maxf(vs.x, 1.0)
	var rk := clampf(view_w / 54.0, 1.0, 8.0)
	for i in MAX_RAIN:
		var rs := _rain[i]
		rs.visible = raining
		if not raining:
			continue
		var p := _rain_pos[i]
		var fall := fposmod(p.y * view_h + _t * (30.0 + 0.5 * view_w) * (0.8 + 0.1 * p.z), view_h)
		rs.position = Vector3(cam_x + (p.x - 0.5) * (view_w + 8.0) - fall * 0.2, cam_y + view_h * 0.5 - fall, p.z)
		rs.scale = Vector3(0.05 * rk, 1.5 * rk, 0.05)
	# wind streaks
	var half := view_w * 0.5 + 6.0
	var show_wind := not DebugFlags.off("wind")
	for i in MAX_STREAKS:
		var st := _streaks[i]
		st.visible = show_wind
		if not show_wind:
			continue
		var sp := _streak_pos[i]
		# sp.x is the streak's x offset from the camera in half-widths (-1..1), sp.y its height, sp.z its depth
		var wx := cam_x + sp.x * half * 2.0 - half
		st.position = Vector3(wx, sp.y, sp.z)
		st.scale = Vector3(1.0 + absf(head) * 0.25, 0.07, 0.07)
	# windsock: droops when calm, sticks out straight in a strong wind, points downwind. A wind-shear warning snaps it round.
	var sock_head := head
	if _sock_snap > 0.0:
		sock_head = -signf(head if absf(head) > 0.5 else 1.0) * maxf(absf(head), Tuning.sock_full_wind)
	var strength := clampf(absf(sock_head) / maxf(Tuning.sock_full_wind, 0.1), 0.0, 1.0)
	var droop := (1.0 - strength) * 80.0 + sin(_t * (9.0 if _sock_snap <= 0.0 else 26.0)) * 6.0 * strength
	_sock_pivot.rotation = Vector3(0, 0 if sock_head < 0.0 else PI, -deg_to_rad(droop))

## PAPI from where the plane is: the slope of the line from the plane to the PAPI against the slope of the path to the
## markers (heights are above the PAPI's own ground level). Four lights, each turns white as the plane climbs above its
## step: all red = too low, two white + two red = on the path, all white = too high. A light needs to pass its step by
## papi_hysteresis (a fraction of papi_band) to flip back, so turbulence around a step doesn't make it flicker. Holds its
## last state close in (the angle swings wildly right at the end). `snap` ignores the hysteresis and the hold (used when a
## round starts).
func update_papi(plane_x: float, plane_y: float, snap: bool = false) -> void:
	var dx := papi_x - plane_x
	var rel_y := plane_y - ground_y(papi_x)
	if not snap and (dx < Tuning.papi_hold_distance or plane_y <= ground_y(plane_x)):
		return
	if dx <= 0.5:
		return
	var ratio := (rel_y / dx) / maxf(papi_slope, 0.01)
	var h := Tuning.papi_hysteresis * Tuning.papi_band
	var n := 0
	for k in 4:
		var step := 1.0 + (float(k) - 1.5) * Tuning.papi_band
		var was_white := k < papi_white
		var white: bool
		if snap:
			white = ratio > step
		elif was_white:
			white = ratio > step - h
		else:
			white = ratio > step + h
		if white:
			n += 1
	if n != papi_white:
		papi_white = n
		_paint_papi()

## Pre-warm: show every pooled node for real (nothing hidden / off-screen), so each one is drawn once.
func prewarm_show() -> void:
	_prewarm_all = true
	for t in _trees:
		_set_tree(t, thr - 20.0, 0.0, 8.0, 2.0)
	_hill.visible = true
	for d in _dashes:
		d.visible = true
	for st in _streaks:
		st.visible = true
	for b in _beacons:
		b.visible = true
	_ramp_root.visible = true
	_plateau.visible = true
	_hull.visible = true
	_island.visible = true
	_cab.visible = true
	_chassis.visible = true
	_road.visible = true
	for w in _wheels:
		w.visible = true
	for w in _wires:
		w.visible = true

func drift_streaks(dt: float, cam_dx: float, head: float, view_w: float) -> void:
	var half2 := view_w + 12.0
	var dx := (-head * dt - cam_dx) / half2
	for i in MAX_STREAKS:
		var p := _streak_pos[i]
		p.x = fposmod(p.x + dx * (0.7 + 0.15 * float(i % 3)), 1.0)
		_streak_pos[i] = p

func _paint_papi() -> void:
	for i in 4:
		_papi_mats[i].albedo_color = Color(1, 1, 1) if i < papi_white else Color(1.0, 0.08, 0.08)

func prewarm_hide() -> void:
	_prewarm_all = false
	build()
