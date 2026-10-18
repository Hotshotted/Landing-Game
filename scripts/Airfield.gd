class_name Airfield
extends Node3D
## The play layer and the scenery layer.
##   * PLAY LAYER = everything the plane can hit or must read: the ground, the runway and its markings, the trees /
##     hill before it, the PAPI lights, the aim / end posts, the windsock. Full colour and black outlines.
##   * SCENERY = background trees, far hills, clouds. Faded toward the sky colour, unshaded, NO outlines, and
##     scrolling slower than the play layer (parallax), so it can never be mistaken for a hazard.
## Every node is created ONCE in build_pools() and only moved / scaled / shown / hidden for each new round
## (generate() picks the round, build() lays it out), so nothing is allocated in play.

enum { ASPHALT, GRASS, DIRT }
enum { FLAT, TREES, HILL }

const SURFACE_NAMES: Array[String] = ["asphalt", "grass", "dirt"]
const TERRAIN_NAMES: Array[String] = ["flat", "trees", "hill"]
const SURFACE_COLORS: Array[Color] = [Color(0.27, 0.28, 0.32), Color(0.5, 0.78, 0.36), Color(0.64, 0.48, 0.32)]
const SMOKE_COLORS: Array[Color] = [Color(0.95, 0.95, 0.95), Color(0.7, 0.8, 0.55), Color(0.78, 0.65, 0.48)]
const GROUND_COLOR := Color(0.34, 0.6, 0.3)
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
const DECO_SPAN := 700.0       # scenery wraps around the camera over this many units
const HILL_SPAN := 840.0
const CLOUD_SPAN := 900.0
const MAX_STREAKS := 40
const RWY_HALF_DEPTH := 6.0

# ---- the round (set by generate()) ----
var surface := ASPHALT
var terrain := FLAT
var thr := 0.0          # runway threshold (x)
var rwy_len := 150.0
var rwy_end := 150.0
var aim_x := 0.0        # centre of the aim markers
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

var _box := BoxMesh.new()
var _cone := CylinderMesh.new()
var _cyl := CylinderMesh.new()
var _prism := PrismMesh.new()
var _outline: ShaderMaterial
var _ground: MeshInstance3D
var _rwy: MeshInstance3D
var _rwy_mat: StandardMaterial3D
var _rwy_root: Node3D        # the runway and its paint: scaled in z when zoomed out so the band stays visible
var _end_bar: MeshInstance3D
var _end_posts: Array[Node3D] = []
var _dashes: Array[MeshInstance3D] = []
var _bars: Array[MeshInstance3D] = []
var _aim_slabs: Array[MeshInstance3D] = []
var _aim_posts: Array[Node3D] = []
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
	_rwy_root = Node3D.new()
	add_child(_rwy_root)
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

## A post (marker) standing on the ground: a root at its foot (scaled with the zoom) and a box child.
func _make_post(color: Color, size: Vector3) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var m := _mi(_box, color, true, root)
	m.scale = size
	m.position = Vector3(0, size.y * 0.5, 0)
	return root

## A blinking obstruction light (a small unshaded cube), scaled with the zoom.
func _make_beacon() -> Node3D:
	var root := Node3D.new()
	add_child(root)
	var m := _mi(_box, Color(1.0, 0.45, 0.1), true, root, true)
	m.scale = Vector3(0.9, 0.9, 0.9)
	_beacon_mats.append(m.material_override as StandardMaterial3D)
	return root

## PAPI: four housings in a row beside the aim markers, each with a lens facing the camera.
func _build_papi() -> void:
	_papi_root = Node3D.new()
	add_child(_papi_root)
	for i in 4:
		var h := _mi(_box, Color(0.3, 0.3, 0.34), true, _papi_root)
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

## Choose the round: surface, length, terrain, wind, where the approach starts and how it misses the markers.
func generate(round_no: int, rng: RandomNumberGenerator) -> void:
	var r := Tuning.ramp(round_no)
	# surface and length
	if round_no <= 2:
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
	# terrain: nothing in the first rounds; short fields get obstacles more often
	if round_no <= 2:
		terrain = FLAT
	else:
		var short := 1.0 - clampf((rwy_len - 80.0) / 160.0, 0.0, 1.0)
		var u2 := rng.randf()
		if u2 < 0.25 + 0.3 * short:
			terrain = TREES
		elif u2 < 0.45 + 0.4 * short:
			terrain = HILL
		else:
			terrain = FLAT
	# wind: mild at first, up to the full range later
	var wscale := 0.3 + 0.7 * r
	wind_base = rng.randf_range(-Tuning.wind_tail_max * wscale, Tuning.wind_head_max * wscale)
	if not Tuning.wind_enabled:
		wind_base = 0.0
	# the plain approach path: sink / ground speed
	path_slope = Tuning.trim_sink / maxf(Tuning.approach_speed - wind_base, 6.0)
	start_altitude = rng.randf_range(Tuning.start_altitude_min, Tuning.start_altitude_max)
	var aim_off := clampf(rwy_len * Tuning.aim_fraction, Tuning.aim_min, Tuning.aim_max)
	var emax := Tuning.path_error_max * (0.4 + 0.6 * r)
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
	# where the plain approach path would touch down relative to the markers: random, but never under the obstacles
	path_error = rng.randf_range(-emax, emax)
	if terrain != FLAT:
		var need := -INF
		for i in tree_count:
			need = maxf(need, (tree_h[i] + 1.2) / path_slope - (aim_off - tree_x[i]))
		if hill_on:
			need = maxf(need, (hill_h + 1.2) / path_slope - (aim_off - hill_x))
		path_error = maxf(path_error, need)
	var touch_nom := start_altitude / path_slope               # x where the plain path hits the ground (plane starts at x = 0)
	thr = touch_nom - path_error - aim_off
	if thr < 60.0:                                              # too close: start a little higher instead
		start_altitude += (60.0 - thr) * path_slope
		touch_nom = start_altitude / path_slope
		thr = touch_nom - path_error - aim_off
	aim_x = thr + aim_off
	rwy_end = thr + rwy_len
	papi_x = aim_x
	papi_slope = comfy if terrain != FLAT else path_slope    # the glide that reaches the markers (and clears the obstacles)
	for i in tree_count:
		tree_x[i] += thr          # to world x
	if hill_on:
		hill_x += thr

## Lay the pooled nodes out for the round (also hides what this round doesn't use).
func build() -> void:
	var c := SURFACE_COLORS[surface]
	_rwy_mat.albedo_color = c
	var span_l := -160.0
	var span_r := rwy_end + 200.0
	_place(_ground, Vector3((span_l + span_r) * 0.5, -350.0, 0.0), Vector3(span_r - span_l, 700.0, 60.0))   # (deep: nothing shows below it when zoomed far out)
	_place(_rwy, Vector3((thr + rwy_end) * 0.5, -0.02, 0.0), Vector3(rwy_len, 0.12, RWY_HALF_DEPTH * 2.0))
	var line_col := Color(0.97, 0.97, 0.95) if surface == ASPHALT else Color(0.95, 0.9, 0.7)
	var dash_n := mini(int(rwy_len / 9.0), MAX_DASHES)
	for i in MAX_DASHES:
		var d := _dashes[i]
		d.visible = i < dash_n
		if d.visible:
			_set_color(d, line_col)
			_place(d, Vector3(thr + 10.0 + float(i) * 9.0 + 2.0, 0.05, 0.0), Vector3(4.0, 0.03, 0.5))
			d.visible = d.position.x < rwy_end - 6.0
	for i in MAX_BARS:
		var b := _bars[i]
		_set_color(b, line_col)
		_place(b, Vector3(thr + 1.6, 0.05, -4.5 + float(i) * 1.8), Vector3(3.0, 0.03, 0.8))
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		_place(_aim_slabs[k], Vector3(aim_x, 0.06, side * 3.0), Vector3(7.0, 0.03, 1.1))
	_place(_end_bar, Vector3(rwy_end - 0.6, 0.06, 0.0), Vector3(1.2, 0.03, RWY_HALF_DEPTH * 2.0))
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
	_sock_root.position = Vector3(thr + 6.0, 0.0, -9.5)
	_layout_markers()
	papi_white = 2
	_paint_papi()

## Posts and the PAPI sit just outside the runway edge, which moves out when the runway is stretched in z.
func _layout_markers() -> void:
	var edge := RWY_HALF_DEPTH * _zs + 1.5
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		_aim_posts[k].position = Vector3(aim_x, 0.0, side * edge)
		_aim_posts[k].scale = Vector3.ONE * _mark
		_end_posts[k].position = Vector3(rwy_end + 1.0, 0.0, side * edge)
		_end_posts[k].scale = Vector3.ONE * _mark
	_papi_root.position = Vector3(papi_x, 0.0, edge + 1.5 * _mark)
	_papi_root.scale = Vector3.ONE * _mark
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

## Height of the highest obstacle under x (0 = open ground).
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
	return h

func on_runway(px: float) -> bool:
	return px >= thr - 0.5 and px <= rwy_end

func surface_decel() -> float:
	match surface:
		GRASS:
			return Tuning.decel_grass
		DIRT:
			return Tuning.decel_dirt
	return Tuning.decel_asphalt

func smoke_color() -> Color:
	return SMOKE_COLORS[surface]

## Per frame: zoom-dependent scaling, scenery parallax, drifting wind streaks, windsock, beacons.
## `head` = total headwind, `cam_x` / `view_w` = what is on screen.
func update(dt: float, cam_x: float, view_w: float, head: float) -> void:
	_t += dt
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
	# scenery: parallax (slower than the play layer), wrapped around the camera
	for i in MAX_DECO:
		var off := fposmod(_deco_base[i] - Tuning.parallax_trees * cam_x + DECO_SPAN * 0.5, DECO_SPAN) - DECO_SPAN * 0.5
		_deco[i].position.x = cam_x + off
	for i in MAX_HILLS:
		var off2 := fposmod(_hill_base[i] - Tuning.parallax_hills * cam_x + HILL_SPAN * 0.5, HILL_SPAN) - HILL_SPAN * 0.5
		_far_hills[i].position.x = cam_x + off2
	var show_clouds := not DebugFlags.off("clouds")
	for i in MAX_CLOUDS:
		var c := _clouds[i]
		c.visible = show_clouds
		_cloud_base[i] += _cloud_speed[i] * dt
		var off3 := fposmod(_cloud_base[i] - Tuning.parallax_clouds * cam_x + CLOUD_SPAN * 0.5, CLOUD_SPAN) - CLOUD_SPAN * 0.5
		c.position.x = cam_x + off3
	# wind streaks
	var half := view_w * 0.5 + 6.0
	var show_wind := not DebugFlags.off("wind")
	for i in MAX_STREAKS:
		var st := _streaks[i]
		st.visible = show_wind
		if not show_wind:
			continue
		var p := _streak_pos[i]
		# p.x is the streak's x offset from the camera in half-widths (-1..1), p.y its height, p.z its depth
		var wx := cam_x + p.x * half * 2.0 - half
		st.position = Vector3(wx, p.y, p.z)
		st.scale = Vector3(1.0 + absf(head) * 0.25, 0.07, 0.07)
	# windsock: droops when calm, sticks out straight in a strong wind, points downwind
	var strength := clampf(absf(head) / maxf(Tuning.sock_full_wind, 0.1), 0.0, 1.0)
	var droop := (1.0 - strength) * 80.0 + sin(_t * 9.0) * 6.0 * strength
	_sock_pivot.rotation = Vector3(0, 0 if head < 0.0 else PI, -deg_to_rad(droop))

## PAPI from where the plane is: the slope of the line from the plane to the PAPI against the slope of the path to the
## markers. Four lights, each turns white as the plane climbs above its step: all red = too low, two white + two red =
## on the path, all white = too high. Holds its last state close in (the angle swings wildly right at the end).
func update_papi(plane_x: float, plane_y: float) -> void:
	var dx := papi_x - plane_x
	if dx < Tuning.papi_hold_distance or plane_y <= 0.0:
		return
	var ratio := (plane_y / dx) / maxf(papi_slope, 0.01)
	var n := 0
	for k in 4:
		if ratio > 1.0 + (float(k) - 1.5) * Tuning.papi_band:
			n += 1
	if n != papi_white:
		papi_white = n
		_paint_papi()

func _paint_papi() -> void:
	for i in 4:
		_papi_mats[i].albedo_color = Color(1, 1, 1) if i < papi_white else Color(1.0, 0.08, 0.08)

## Streak drift: move the streak offsets along the air flow relative to the camera (called with the camera's speed).
func drift_streaks(dt: float, cam_dx: float, head: float, view_w: float) -> void:
	var half2 := view_w + 12.0
	var dx := (-head * dt - cam_dx) / half2
	for i in MAX_STREAKS:
		var p := _streak_pos[i]
		p.x = fposmod(p.x + dx * (0.7 + 0.15 * float(i % 3)), 1.0)
		_streak_pos[i] = p

## Pre-warm: show every pooled node for real (nothing hidden / off-screen), so each one is drawn once.
func prewarm_show() -> void:
	for t in _trees:
		_set_tree(t, thr - 20.0, 0.0, 8.0, 2.0)
	_hill.visible = true
	for d in _dashes:
		d.visible = true
	for st in _streaks:
		st.visible = true
	for b in _beacons:
		b.visible = true

func prewarm_hide() -> void:
	build()
