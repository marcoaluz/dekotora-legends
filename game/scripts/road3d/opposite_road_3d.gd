class_name OppositeRoad3D
extends Node3D
## T-217: draws the other carriageway of OppositeLayout (only visual). Per 100 m chunk one MeshInstance3D with up to
## 8 surfaces: asphalt (same texture and wheel tracks as ours), lines, median soil, hedge, guard-rail, concrete
## (barriers, decks), sound wall, tunnel asphalt. Ground routes: median strip with a clipped hedge and a W guard-rail
## facing the other road, outer concrete barrier (coast: guard-rail). City viaduct and bridges: twin deck beside ours
## (1 m gap you can look down through), median concrete barrier, T piers, sound walls in the same blocks as ours.
## In the tunnels only the asphalt and the curbs (the twin bore is Tunnel3D). The ground under the band dips 0.25 m
## (TerrainField) so nothing fights with the terrain.

const CHUNK_SEGS: int = 50
const VIEW_M: float = 600.0
const DETAIL_M: float = 200.0            # full detail up to here (centre of the chunk); beyond: one flat-colour surface
const STEP: int = 2                      # segments per ring (4 m; the curves are >= 400 m radius)
const BAND_SEGS: int = 4
const DECK_GAP_IN: float = 14.6          # viaduct/bridge: inner edge of the twin deck (our deck ends at 13.6)
const PIER_EVERY: float = 32.0
const LANE_BANDS: Array = [[0.0, 1.0], [0.45, 0.76], [1.1, 0.97], [2.4, 0.76], [3.05, 1.0]]
## New-Jersey barrier profile [lateral from the face, height]; mirrored by `face`.
const NJ: Array = [[0.0, 0.0], [0.05, 0.25], [0.2, 0.85], [0.4, 0.85], [0.55, 0.25], [0.6, 0.0]]

var layout: OppositeLayout
var path: TrackPath
var tod: TimeOfDay
var tris: int = 0
var chunks: int = 0
var _r: Ribbon
var _mats: Dictionary = {}
var _q: int = 1


func build(layout_: OppositeLayout, tod_: TimeOfDay, q: int, soft_spec: bool) -> void:
	layout = layout_
	path = layout.path
	tod = tod_
	_q = q
	_r = Ribbon.new(path)
	_materials(soft_spec)
	var total: int = path.seg_total()
	var s: int = 0
	while s < total:
		_chunk(s, mini(s + CHUNK_SEGS, total))
		s += CHUNK_SEGS
	if layout.deck > 0.0 or not layout.bridges.is_empty():
		_piers()


func _materials(soft_spec: bool) -> void:
	var rm := RoadMesh.new()                 # same asphalt, lines and glass as our road (materials only, no mesh)
	rm.tod = tod
	rm.soft_spec = soft_spec
	rm._make_materials()
	for k in ["road", "troad", "line", "glass"]:
		_mats[k] = rm._mats[k]
	rm.free()
	_mats["rail"] = Ribbon.two_sided(PontesKit.guardrail(tod))
	_mats["concrete"] = Ribbon.two_sided(PontesKit.concrete(tod, 0.3))
	var hedge := StandardMaterial3D.new()
	hedge.albedo_texture = TexSlots.albedo("hedge")
	hedge.vertex_color_use_as_albedo = true
	hedge.roughness = 0.95
	hedge.cull_mode = BaseMaterial3D.CULL_DISABLED
	hedge.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats["hedge"] = hedge
	var soil := StandardMaterial3D.new()
	soil.cull_mode = BaseMaterial3D.CULL_DISABLED
	soil.albedo_texture = load("res://assets/textures/grass.png") as Texture2D
	soil.albedo_color = Color(0.42, 0.42, 0.36)
	soil.vertex_color_use_as_albedo = true
	soil.roughness = 0.95
	soil.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_mats["soil"] = soil
	var lite := StandardMaterial3D.new()
	lite.vertex_color_use_as_albedo = true
	lite.roughness = 0.9
	lite.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats["lite"] = lite


func _deck_at(z: float) -> bool:
	return layout.deck > 0.0 or layout.on_bridge(z, 2.0)


func _chunk(s0: int, s1: int) -> void:
	var sts: Dictionary = {}
	for k in ["road", "troad", "line", "soil", "hedge", "rail", "concrete", "glass"]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		sts[k] = st
	var used: Dictionary = {}
	var lite := SurfaceTool.new()
	lite.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lite_used: bool = false
	for i in range(s0, s1, STEP):
		var j: int = mini(i + STEP, s1)
		var z: float = float(i) * Track.SEG_LEN
		if not layout.has(z):
			continue
		lite_used = true
		_lite(lite, i, j, z)
		var tube: bool = layout.in_tube(z)
		var deck: bool = _deck_at(z)
		var inner: float = OppositeLayout.ROAD_IN
		if deck and not tube:
			inner = DECK_GAP_IN + RoadMesh.BARRIER_W
		_asphalt(sts["troad" if tube else "road"], i, j, inner, tube)
		used["troad" if tube else "road"] = true
		_lines(sts["line"], i, j)
		used["line"] = true
		if tube:
			_r.sweep(sts["concrete"], i, j, [[0.0, 0.0], [0.0, 0.25], [-0.5, 0.25], [-0.5, 0.0]], 1.0,
				Color(0.55, 0.5, 0.42), 4.0, OppositeLayout.ROAD_IN + 0.5)
			_r.sweep(sts["concrete"], i, j, [[0.0, 0.0], [0.0, 0.25], [0.5, 0.25], [0.5, 0.0]], 1.0,
				Color(0.55, 0.5, 0.42), 4.0, OppositeLayout.ROAD_OUT - 0.5)
			used["concrete"] = true
			continue
		if deck:
			_deck(sts, i, j, z)
			used["concrete"] = true
			if _q >= 1 and RoadMesh.sound_wall_at(z) and layout.deck > 0.0:
				_glass(sts["glass"], i, j, OppositeLayout.ROAD_OUT + 0.45, 0.85, 4.0)
				used["glass"] = true
			continue
		_median(sts, i, j)
		used["soil"] = true
		used["hedge"] = true
		used["rail"] = true
		_outer(sts, i, j)
		used["concrete"] = true
	var mesh := ArrayMesh.new()
	for k in sts:
		if not used.has(k):
			continue
		var st: SurfaceTool = sts[k]
		st.generate_normals()
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[k])
		tris += mesh.surface_get_array_len(mesh.get_surface_count() - 1) / 3
	if mesh.get_surface_count() == 0:
		return
	var far_m: float = VIEW_M if _q >= 2 else (520.0 if _q == 1 else 400.0)
	var mi := MeshInstance3D.new()
	mi.name = "OppositeChunk%d" % s0
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = DETAIL_M
	mi.visibility_range_end_margin = 10.0
	add_child(mi)
	chunks += 1
	if lite_used:
		lite.generate_normals()
		var lm: ArrayMesh = lite.commit()
		lm.surface_set_material(0, _mats["lite"])
		tris += lm.surface_get_array_len(0) / 3
		var li := MeshInstance3D.new()
		li.name = "OppositeLite%d" % s0
		li.mesh = lm
		li.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		li.visibility_range_begin = DETAIL_M - 10.0
		li.visibility_range_begin_margin = 10.0
		li.visibility_range_end = far_m
		add_child(li)


## Far version of a ring: flat asphalt, edge lines, hedge block, guard-rail and barrier as plain quads (1 surface).
func _lite(st: SurfaceTool, i: int, j: int, z: float) -> void:
	var tube: bool = layout.in_tube(z)
	var deck: bool = _deck_at(z) and not tube
	var inner: float = DECK_GAP_IN + RoadMesh.BARRIER_W if deck else OppositeLayout.ROAD_IN
	var asph := Color(0.33, 0.33, 0.34) if not tube else Color(0.3, 0.22, 0.15)
	_r.strip(st, i, j, inner, OppositeLayout.ROAD_OUT, 0.0, 0.0, asph)
	for e in [OppositeLayout.LANE0 - 0.12, OppositeLayout.LANE_END + 0.12]:
		_r.strip(st, i, j, e - 0.12, e + 0.12, 0.03, 0.03, Color(0.85, 0.85, 0.82))
	if tube:
		return
	var grey := Color(0.7, 0.7, 0.68)
	if deck:
		_r.sweep(st, i, j, [[DECK_GAP_IN, 0.85], [DECK_GAP_IN, -1.6], [OppositeLayout.ROAD_OUT + 0.6, -1.6],
			[OppositeLayout.ROAD_OUT + 0.6, 0.85]], 1.0, grey)
		return
	var hc: float = OppositeLayout.HEDGE_LAT
	var hw: float = OppositeLayout.HEDGE_W * 0.5
	_r.sweep(st, i, j, [[hc - hw, 0.1], [hc - hw * 0.7, OppositeLayout.HEDGE_H], [hc + hw * 0.7, OppositeLayout.HEDGE_H],
		[hc + hw, 0.1]], 1.0, Color(0.16, 0.27, 0.1))
	_r.sweep(st, i, j, [[OppositeLayout.RAIL_LAT + 0.2, 0.45], [OppositeLayout.RAIL_LAT + 0.2, 0.78]], 1.0, grey)
	if layout.kind == &"coast":
		_r.sweep(st, i, j, [[OppositeLayout.ROAD_OUT + 0.15, 0.45], [OppositeLayout.ROAD_OUT + 0.15, 0.78]], 1.0, grey)
	else:
		_r.sweep(st, i, j, [[OppositeLayout.ROAD_OUT, 0.0], [OppositeLayout.ROAD_OUT + 0.2, 0.85],
			[OppositeLayout.ROAD_OUT + 0.6, 0.0]], 1.0, Color(0.82, 0.82, 0.8))


## Asphalt from `inner` to the outer edge: 2 lanes with darker wheel tracks, patches, shoulders.
func _asphalt(st: SurfaceTool, i: int, j: int, inner: float, tube: bool) -> void:
	var z: float = float(i) * Track.SEG_LEN
	var block: int = int(z / 41.0)
	var base: float = 0.94 + 0.12 * _hash(block * 5 + 11)
	var sodium := Color(1, 1, 1)
	if tube:
		var lamp: float = 0.5 + 0.5 * cos(fmod(z, 6.0) / 6.0 * TAU)
		sodium = Color(0.55, 0.4, 0.26).lerp(Color(1.0, 0.7, 0.42), lamp)
	var shoulder: Color = Color(0.84, 0.84, 0.86) * sodium
	_r.strip(st, i, j, inner, OppositeLayout.LANE0, 0.0, 0.0, shoulder)
	for lane in OppositeLayout.LANES:
		var x0: float = OppositeLayout.LANE0 + float(lane) * OppositeLayout.LANE_W
		var c: float = base
		if _hash(block * 29 + lane * 7) < 0.1:
			c *= 0.74 if _hash(block * 3 + lane) < 0.6 else 1.15
		for b in LANE_BANDS.size():
			var a0: float = float(LANE_BANDS[b][0])
			var a1: float = float(LANE_BANDS[b + 1][0]) if b + 1 < LANE_BANDS.size() else OppositeLayout.LANE_W
			var m: float = float(LANE_BANDS[b][1]) * c
			_r.strip(st, i, j, x0 + a0, x0 + a1, 0.0, 0.0, Color(m, m, m) * sodium)
	_r.strip(st, i, j, OppositeLayout.LANE_END, OppositeLayout.ROAD_OUT, 0.0, 0.0, shoulder)


func _lines(st: SurfaceTool, i: int, j: int) -> void:
	for e in [OppositeLayout.LANE0 - 0.12, OppositeLayout.LANE_END + 0.12]:
		_r.strip(st, i, j, e - 0.1, e + 0.1, 0.02, 0.02)
	if (i / BAND_SEGS) % 2 == 0 or j - i > BAND_SEGS:
		var c: float = OppositeLayout.LANE0 + OppositeLayout.LANE_W
		_r.strip(st, i, j, c - 0.08, c + 0.08, 0.02, 0.02)


## Median of the ground routes: soil strip with curbs, clipped hedge (uneven top), guard-rail facing the other road.
func _median(sts: Dictionary, i: int, j: int) -> void:
	var z: float = float(i) * Track.SEG_LEN
	var m0: float = OppositeLayout.MEDIAN_IN
	var m1: float = OppositeLayout.ROAD_IN
	var soil := Color(0.55, 0.5, 0.42)
	_r.sweep(sts["soil"], i, j, [[0.0, 0.0], [0.0, 0.14], [m1 - m0, 0.14], [m1 - m0, 0.0]], 1.0, soil, 4.0, m0)
	var hc: float = OppositeLayout.HEDGE_LAT
	var hw: float = OppositeLayout.HEDGE_W * 0.5
	var bump_i: float = _bump(z)
	var bump_j: float = _bump(float(j) * Track.SEG_LEN)
	var hi: float = OppositeLayout.HEDGE_H * (0.9 + 0.2 * bump_i)
	var hj: float = OppositeLayout.HEDGE_H * (0.9 + 0.2 * bump_j)
	var pi: Array = [[-hw, 0.1, 0.0], [-hw - 0.08, hi * 0.55, 0.5], [-hw * 0.6, hi, 0.9], [hw * 0.6, hi, 1.35], [hw + 0.08, hi * 0.55, 1.75], [hw, 0.1, 2.2]]
	var pj: Array = [[-hw, 0.1, 0.0], [-hw - 0.08, hj * 0.55, 0.5], [-hw * 0.6, hj, 0.9], [hw * 0.6, hj, 1.35], [hw + 0.08, hj * 0.55, 1.75], [hw, 0.1, 2.2]]
	var tone := Color(0.92 + 0.12 * bump_i, 0.95 + 0.08 * bump_i, 0.9)
	if _hash(int(z / 26.0) * 17 + 5) < 0.18:                 # tsutsuji (azalea) in bloom here and there
		tone = Color(1.35, 0.75, 0.95)
	var ui: float = float(i) * Track.SEG_LEN / 2.0
	var uj: float = float(j) * Track.SEG_LEN / 2.0
	for k in pi.size() - 1:
		var a: Vector3 = _r.edge(i, hc + float(pi[k][0]), float(pi[k][1]))
		var b: Vector3 = _r.edge(i, hc + float(pi[k + 1][0]), float(pi[k + 1][1]))
		var c: Vector3 = _r.edge(j, hc + float(pj[k + 1][0]), float(pj[k + 1][1]))
		var d: Vector3 = _r.edge(j, hc + float(pj[k][0]), float(pj[k][1]))
		var uvs: Array = [Vector2(ui, pi[k][2]), Vector2(ui, pi[k + 1][2]), Vector2(uj, pj[k + 1][2]), Vector2(uj, pj[k][2])]
		var vs: Array = [a, b, c, d]
		var shade: float = 0.72 if k == 0 or k == pi.size() - 2 else 1.0
		for n in [0, 1, 2, 0, 2, 3]:
			(sts["hedge"] as SurfaceTool).set_color(tone * shade)
			(sts["hedge"] as SurfaceTool).set_uv(uvs[n] / 1.0)
			(sts["hedge"] as SurfaceTool).add_vertex(vs[n])
	_rail(sts["rail"], i, j, OppositeLayout.RAIL_LAT, 1.0)


## Outer edge: concrete New-Jersey barrier (coast: guard-rail on the sea side) and a short verge.
func _outer(sts: Dictionary, i: int, j: int) -> void:
	var o: float = OppositeLayout.ROAD_OUT
	if layout.kind == &"coast":
		_rail(sts["rail"], i, j, o + 0.35, -1.0)
	else:
		_r.sweep(sts["concrete"], i, j, NJ, 1.0, Color(0.86, 0.86, 0.84), 4.0, o)
	_r.sweep(sts["soil"], i, j, [[0.0, 0.0], [0.0, 0.05], [1.6, 0.05]], 1.0, Color(0.6, 0.6, 0.5), 4.0, o + 0.6)


## W guard-rail swept with the kit profile; `face` = +1 blade facing +x (the other road seen from the median).
## One ring every 2 segments (4 m, like GuardrailW): even segments draw to i + 2, odd ones nothing.
func _rail(st: SurfaceTool, i: int, j: int, post_lat: float, face: float) -> void:
	var prof: Array = PontesKit.profile()
	var out: Array = []
	for p in prof:
		out.append([face * float(p[0]), float(p[1]), float(p[2])])
	_r.sweep(st, i, j, out, 1.0, Color.WHITE, PontesKit.GR_LEN, post_lat)
	var z: float = float(i) * Track.SEG_LEN
	if fmod(z, PontesKit.GR_POST_EVERY) < Track.SEG_LEN * float(STEP) * 0.5:
		var b := Basis(Vector3.UP, path.yaw[i])
		Ribbon.box(st, b, _r.edge(i, post_lat - face * 0.05, PontesKit.GR_POST_TOP * 0.5),
			Vector3(0.1, PontesKit.GR_POST_TOP, 0.15), Color(0.8, 0.8, 0.8), true)


## Twin deck (city viaduct, bridges): slab with a fascia, median barrier facing the other road, outer barrier.
func _deck(sts: Dictionary, i: int, j: int, z: float) -> void:
	var st: SurfaceTool = sts["concrete"]
	var a: float = DECK_GAP_IN
	var b: float = OppositeLayout.ROAD_OUT + RoadMesh.BARRIER_W
	var under := Color(0.62, 0.62, 0.62)
	_r.sweep(st, i, j, [[a, -0.02], [a, -1.6], [b, -1.6], [b, -0.02]], 1.0, under, 4.0)   # sides + soffit
	_r.sweep(st, i, j, NJ, -1.0, Color(0.86, 0.86, 0.84), 4.0, -(a + RoadMesh.BARRIER_W))   # median barrier faces +x
	_r.sweep(st, i, j, NJ, 1.0, Color(0.86, 0.86, 0.84), 4.0, OppositeLayout.ROAD_OUT)
	_r.strip(sts["concrete"], i, j, a, a + RoadMesh.BARRIER_W, 0.0, 0.0, Color(0.7, 0.7, 0.7))


func _glass(st: SurfaceTool, i: int, j: int, lat: float, h0: float, h1: float) -> void:
	var u0: float = float(i) * Track.SEG_LEN / 12.0
	var u1: float = float(j) * Track.SEG_LEN / 12.0
	var a: Vector3 = _r.edge(i, lat, h1)
	var b: Vector3 = _r.edge(i, lat, h0)
	var c: Vector3 = _r.edge(j, lat, h0)
	var d: Vector3 = _r.edge(j, lat, h1)
	var uv: Dictionary = {a: Vector2(u0, 0.127), b: Vector2(u0, 0.255), c: Vector2(u1, 0.255), d: Vector2(u1, 0.127)}
	for tri in [[a, c, b, a, d, c], [b, c, a, c, d, a]]:
		for v in tri:
			st.set_color(Color.WHITE)
			st.set_uv(uv[v])
			st.add_vertex(v)


## T piers under the twin deck (same rhythm as ViaductPiers3D) and on the twin bridges (feet in the water).
func _piers() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var blocks: Dictionary = {}
	var L: float = path.end_m()
	var c: float = (DECK_GAP_IN + OppositeLayout.ROAD_OUT + RoadMesh.BARRIER_W) * 0.5
	var w: float = OppositeLayout.ROAD_OUT + RoadMesh.BARRIER_W - DECK_GAP_IN
	var z: float = 16.0
	while z < L:
		var city: bool = layout.deck > 0.0
		if (city or layout.on_bridge(z, -8.0)) and not layout.in_tube(z, 8.0):
			var bi: int = int(z / 300.0)
			if not blocks.has(bi):
				var s := SurfaceTool.new()
				s.begin(Mesh.PRIMITIVE_TRIANGLES)
				blocks[bi] = s
			var bs: SurfaceTool = blocks[bi]
			var b := Basis(Vector3.UP, path.yaw_at(z))
			var top: Vector3 = path.world_point(z, c / Track.ROAD_HALF_WIDTH_M, 0.0)
			Ribbon.box(bs, b, top + Vector3.UP * -2.3, Vector3(w - 1.0, 1.4, 2.4), Color(0.8, 0.81, 0.84))
			var foot_y: float = top.y - layout.deck if city else SectionStructures3D.FOOT_Y
			var foot := Vector3(top.x, foot_y, top.z)
			PierT.append(bs, foot, b, top.y - 3.0 - foot_y, minf(w * 0.42, 6.0), Color(0.8, 0.81, 0.84))
		z += PIER_EVERY if layout.deck > 0.0 else SectionStructures3D.PIER_EVERY
	var mat: StandardMaterial3D = PontesKit.concrete(tod, 0.3)
	for bi in blocks:
		tris += Ribbon.add_mesh(self, blocks[bi], mat, 600.0, false)


func _bump(z: float) -> float:
	return 0.5 + 0.35 * sin(z * 0.9) + 0.15 * sin(z * 2.3 + 1.7)


func _hash(n: int) -> float:
	return fmod(absf(sin(float(n) * 12.9898) * 43758.5453), 1.0)
