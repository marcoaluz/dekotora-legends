class_name RouteLandmarks
extends Node3D
## T-217: what gives each route its identity (only visual, deterministic):
##   coast    : white lighthouse on a rocky islet in the bay (rotating beam at night), a small harbour quay with
##              containers, a warehouse and parked trucks (docs/Modelos: Caminhão novo, Carreta) + port workers
##              (Homem machucado), swimmers on the beach by day (Homem)
##   mountain : waterfall falling down a cliff beside the road into a pool and over the stone wall, red suspension
##              footbridge over a far valley (docs/Modelos: Outra ponte), a gravel works yard with dump trucks
##              (Caminhão vasculante) and workers, mist sheets in the valleys
##   city     : the apartment blocks are Danchi3D; the neon was already there (T-188/T-193)
## Spots are in CutLayout.FEATURES (trees and rocks stay out of them).

const DIR := "res://assets/scenery/t217/"
const TRUCKS := "res://assets/vehicles/traffic/"
const LH_SCALE: float = 1.5                # the lighthouse is 30 m tall (seen from 150 m across the water)

var counts: Dictionary = {}
var path: TrackPath
var field: TerrainField
var tod: TimeOfDay
var _night: float = 0.0
var _deck: float = 0.0
var _beam: Node3D
var _scenes: Dictionary = {}


static func enabled() -> bool:
	return not "--no-landmarks" in OS.get_cmdline_user_args() and ScenicZone.enabled()


func build(path_: TrackPath, route_id: String, kind: StringName, tod_: TimeOfDay, q: int, field_: TerrainField) -> void:
	path = path_
	field = field_
	tod = tod_
	_night = 1.0 - tod.day_amount
	_deck = RoadMesh.deck_height(kind)
	var feats: Dictionary = CutLayout.FEATURES.get(route_id, {})
	match kind:
		&"coast":
			if feats.has("lighthouse"):
				_lighthouse(feats["lighthouse"])
			if feats.has("harbour"):
				_harbour(feats["harbour"])
			if feats.has("beach") and tod.day_amount > 0.5:
				_swimmers(feats["beach"])
		&"mountain":
			if feats.has("waterfall"):
				_waterfall(feats["waterfall"])
			if feats.has("works"):
				_works(feats["works"])
			_footbridge()
			if q >= 1:
				var mist := ValleyMist.new()
				add_child(mist)
				mist.build(path, field, tod, 217)
				counts["mist"] = mist.count


func summary() -> String:
	return str(counts)


func _process(delta: float) -> void:
	if _beam != null:
		_beam.rotate_y(delta * 0.9)


# ---------------------------------------------------------------- helpers
func _ground(z: float, lat: float) -> Vector3:
	var p: Vector3 = path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, -_deck)
	if field != null:
		var h: float = field.height_at(Vector2(p.x, p.z))
		if not is_nan(h):
			p.y = h
	return p


func _place(res: String, xf: Transform3D, paint: Color = Color(0, 0, 0, 0)) -> Node3D:
	if not ResourceLoader.exists(res):
		return null
	if not _scenes.has(res):
		_scenes[res] = load(res)
	var n: Node3D = (_scenes[res] as PackedScene).instantiate() as Node3D
	n.transform = xf
	add_child(n)
	if paint.a > 0.0:
		var m := StandardMaterial3D.new()
		m.albedo_color = paint
		m.metallic = 0.4
		m.roughness = 0.35
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var inst: MeshInstance3D = mi as MeshInstance3D
			for s in inst.mesh.get_surface_count():
				var cur: Material = inst.get_active_material(s)
				if cur != null and cur.resource_name == "paint_white":
					inst.set_surface_override_material(s, m)
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(mi as GeometryInstance3D).visibility_range_end = 1400.0
	var key: String = res.get_file().get_basename()
	counts[key] = int(counts.get(key, 0)) + 1
	return n


## Basis facing the road (local -Z towards the road centre line, i.e. the "front" of a .glb looks at the road).
func _facing_road(z: float, lat: float, extra: float = 0.0) -> Basis:
	var to_road: Vector3 = path.right_at(z) * -signf(lat)
	return Basis.looking_at(to_road, Vector3.UP).rotated(Vector3.UP, extra)


func _box(st: SurfaceTool, xf: Transform3D, size: Vector3, col: Color) -> void:
	Ribbon.box(st, xf.basis, xf.origin, size, col)


func _solid(st: SurfaceTool, name: String) -> void:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	var mesh: ArrayMesh = st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return
	mesh.surface_set_material(0, m)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 1400.0
	add_child(mi)


# ---------------------------------------------------------------- coast
func _lighthouse(spot: Array) -> void:
	var z: float = float(spot[0])
	var lat: float = float(spot[1])
	var sea_y: float = path.center_at(z).y + SectionStructures3D.WATER_Y
	var c: Vector3 = path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, 0.0)
	c.y = sea_y
	var rock := MeshInstance3D.new()                             # rocky islet
	rock.mesh = RockKit.mesh()
	rock.material_override = RockKit.material(tod)
	rock.transform = Transform3D(Basis.from_scale(Vector3(34.0, 9.0, 28.0)), c + Vector3.DOWN * 1.2)
	rock.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rock)
	for k in 5:                                                  # boulders around it
		var a: float = float(k) * 1.37
		var r := MeshInstance3D.new()
		r.mesh = RockKit.mesh()
		r.material_override = RockKit.material(tod)
		r.transform = Transform3D(Basis(Vector3.UP, a) * Basis.from_scale(Vector3.ONE * (5.0 + k)), c + Vector3(cos(a) * 17.0, -1.5, sin(a) * 14.0))
		add_child(r)
	var top: Vector3 = c + Vector3.UP * 3.6
	_place(DIR + "lighthouse.glb", Transform3D(_facing_road(z, lat) * Basis.from_scale(Vector3.ONE * LH_SCALE), top))
	if tod.lamps_on or _night > 0.4:
		_beam = Node3D.new()
		_beam.position = top + Vector3.UP * 17.4 * LH_SCALE
		add_child(_beam)
		for k in 2:
			var q := QuadMesh.new()
			q.size = Vector2(160.0, 7.0)
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.material_override = LandmarkFx.beam_mat(0.35 + 0.35 * _night)
			mi.transform = Transform3D(Basis(Vector3.UP, PI * float(k)) * Basis(Vector3.RIGHT, -PI * 0.5), Vector3(80.0, 0, 0).rotated(Vector3.UP, PI * float(k)))
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_beam.add_child(mi)


func _harbour(spot: Array) -> void:
	var z0: float = float(spot[0])
	var z1: float = float(spot[1])
	var lat0: float = float(spot[2])
	var lat1: float = float(spot[3])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zm: float = (z0 + z1) * 0.5
	var b := Basis(Vector3.UP, path.yaw_at(zm))
	var road_y: float = path.center_at(zm).y
	var top_y: float = road_y - 0.4
	var mid: Vector3 = path.world_point(zm, (lat0 + lat1) * 0.5 / Track.ROAD_HALF_WIDTH_M, 0.0)
	mid.y = top_y - 3.0
	_box(st, Transform3D(b, mid), Vector3(lat1 - lat0, 6.0, z1 - z0), Color(0.62, 0.61, 0.58))      # the quay
	var rng := RandomNumberGenerator.new()
	rng.seed = 2171
	var cols: Array[Color] = [Color(0.72, 0.18, 0.12), Color(0.12, 0.35, 0.62), Color(0.15, 0.48, 0.32), Color(0.85, 0.6, 0.15),
		Color(0.55, 0.55, 0.58)]
	for k in 10:                                                 # container stacks
		var zz: float = z0 + 14.0 + float(k % 5) * 6.5
		var ll: float = lat1 - 9.0 - float(k / 5) * 3.0
		var h: int = rng.randi_range(1, 3)
		for lvl in h:
			var p: Vector3 = path.world_point(zz, ll / Track.ROAD_HALF_WIDTH_M, 0.0)
			p.y = top_y + 1.3 + float(lvl) * 2.6
			_box(st, Transform3D(b, p), Vector3(2.44, 2.59, 6.06), cols[rng.randi_range(0, cols.size() - 1)])
	var wh: Vector3 = path.world_point(z1 - 22.0, (lat1 - 12.0) / Track.ROAD_HALF_WIDTH_M, 0.0)     # warehouse
	wh.y = top_y + 4.0
	_box(st, Transform3D(b, wh), Vector3(16.0, 8.0, 30.0), Color(0.78, 0.78, 0.74))
	wh.y = top_y + 8.2
	_box(st, Transform3D(b, wh), Vector3(16.6, 0.5, 30.6), Color(0.16, 0.32, 0.55))
	for k in 2:                                                  # flood-light towers
		var lp: Vector3 = path.world_point(z0 + 20.0 + 60.0 * float(k), (lat0 + 4.0) / Track.ROAD_HALF_WIDTH_M, 0.0)
		lp.y = top_y + 9.0
		_box(st, Transform3D(b, lp), Vector3(0.4, 18.0, 0.4), Color(0.6, 0.6, 0.6))
		lp.y = top_y + 18.2
		_box(st, Transform3D(b, lp), Vector3(2.4, 0.8, 0.5), Color(1.0, 0.95, 0.8) * (1.0 + 2.0 * _night))
	_solid(st, "Harbour")
	var on_quay := func(zz: float, ll: float) -> Vector3:
		var p: Vector3 = path.world_point(zz, ll / Track.ROAD_HALF_WIDTH_M, 0.0)
		p.y = top_y
		return p
	var yaw := Basis(Vector3.UP, path.yaw_at(zm) + PI * 0.5)
	_place(TRUCKS + "truck_semi.glb", Transform3D(yaw, on_quay.call(z0 + 55.0, lat0 + 10.0)), Color("#1c3f8f"))
	_place(TRUCKS + "truck_semi.glb", Transform3D(yaw, on_quay.call(z0 + 60.0, lat0 + 10.0)), Color("#f2f2ef"))
	_place(TRUCKS + "truck_box.glb", Transform3D(b.rotated(Vector3.UP, PI), on_quay.call(z0 + 30.0, lat0 + 6.0)), Color("#c8202f"))
	for k in 3:
		var wp: Vector3 = on_quay.call(z0 + 40.0 + float(k) * 9.0, lat0 + 16.0 + float(k) * 2.0)
		_place(DIR + "worker.glb", Transform3D(Basis(Vector3.UP, float(k) * 2.1), wp))


func _swimmers(spot: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2172
	for k in int(spot[2]):
		var z: float = rng.randf_range(float(spot[0]), float(spot[1]))
		var lat: float = rng.randf_range(float(spot[3]), float(spot[4]))
		var p: Vector3 = _ground(z, lat)
		if is_nan(p.y):
			continue
		_place(DIR + "swimmer.glb", Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.95, 1.05)), p))


# ---------------------------------------------------------------- mountain
func _waterfall(spot: Array) -> void:
	var z: float = float(spot[0])
	var side: float = float(spot[1])
	var cuts: CutLayout = CutLayout.of(path)
	var wall_h: float = cuts.height(z, side) if cuts != null else 0.0
	var wall_top: float = cuts.top(z, side) if cuts != null else 14.0
	var terr: float = wall_h + 0.5
	var face: Vector3 = path.right_at(z) * -side                  # towards the road
	var level: float = lerpf(0.35, 1.0, tod.day_amount)
	var lip_h: float = cuts.terrace(z, side * (CutLayout.BLUFF_LAT.y + 1.0)) if cuts != null else 30.0
	var lip: Vector3 = path.world_point(z, side * (CutLayout.BLUFF_LAT.y + 0.5) / Track.ROAD_HALF_WIDTH_M, lip_h - 0.6)
	_water(LandmarkFx.fall_ribbon(lip, path.center_at(z).y + terr + 0.2, 4.6, face, CutLayout.BLUFF_LAT.y - wall_top - 3.0),
		LandmarkFx.fall_mat(level), "Waterfall")
	var pool_h: float = (cuts.terrace(z, side * (wall_top + 3.2)) if cuts != null else terr) + 0.12
	var pool_c: Vector3 = path.world_point(z, side * (wall_top + 3.2) / Track.ROAD_HALF_WIDTH_M, pool_h)
	var pool := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9.0, 9.0)
	pool.mesh = pm
	pool.material_override = LandmarkFx.pool_mat(level)
	pool.position = pool_c
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	var spill: Vector3 = path.world_point(z + 1.0, side * (wall_top - 0.1) / Track.ROAD_HALF_WIDTH_M, wall_h + 0.3)   # over the wall
	_water(LandmarkFx.fall_ribbon(spill, path.center_at(z).y - 0.2, 1.6, face, 0.7), LandmarkFx.fall_mat(level), "Spill")
	for k in 3:                                                  # spray at the foot of the fall
		var q := QuadMesh.new()
		q.size = Vector2(12.0, 7.0)
		var m := MeshInstance3D.new()
		m.mesh = q
		m.material_override = LandmarkFx.mist_mat(Color(0.9, 0.93, 0.96, 0.32 * level))
		m.transform = Transform3D(Basis(Vector3.UP, float(k) * PI / 3.0), pool_c + Vector3.UP * 3.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
	counts["waterfall"] = 1


func _water(mesh: ArrayMesh, mat: Material, name: String) -> void:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 900.0
	add_child(mi)


func _works(spot: Array) -> void:
	var z0: float = float(spot[0])
	var z1: float = float(spot[1])
	var lat0: float = float(spot[2])
	var lat1: float = float(spot[3])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var zm: float = (z0 + z1) * 0.5
	var b := Basis(Vector3.UP, path.yaw_at(zm))
	var pad: Vector3 = _ground(zm, (lat0 + lat1) * 0.5)
	_box(st, Transform3D(path.basis_at(zm), pad + Vector3.DOWN * 0.2), Vector3(lat1 - lat0, 0.5, z1 - z0), Color(0.45, 0.4, 0.33))   # gravel pad (follows the slope)
	for k in 2:                                                  # gravel heaps (cones)
		var hp: Vector3 = _ground(z0 + 18.0 + 32.0 * float(k), lat1 - 7.0)
		var cone := CylinderMesh.new()
		cone.top_radius = 0.6
		cone.bottom_radius = 6.5 - float(k)
		cone.height = 4.4 - float(k) * 0.6
		cone.radial_segments = 14
		cone.rings = 1
		var cm := MeshInstance3D.new()
		cm.mesh = cone
		cm.material_override = RockKit.material(tod)
		cm.position = hp + Vector3.UP * (cone.height * 0.5 - 0.2)
		cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cm)
	var office: Vector3 = _ground(z1 - 12.0, lat0 + 4.0)          # site office (prefab), with a blue roof
	_box(st, Transform3D(b, office + Vector3.UP * 1.3), Vector3(2.6, 2.6, 6.0), Color(0.9, 0.9, 0.86))
	_box(st, Transform3D(b, office + Vector3.UP * 2.7), Vector3(2.9, 0.2, 6.3), Color(0.2, 0.36, 0.62))
	_solid(st, "Works")
	_place(TRUCKS + "truck_dump.glb", Transform3D(b.rotated(Vector3.UP, 0.4), _ground(z0 + 28.0, lat0 + 4.0)), Color("#e0a020"))
	_place(TRUCKS + "truck_dump.glb", Transform3D(b.rotated(Vector3.UP, -2.6), _ground(z0 + 50.0, lat0 + 6.0)), Color("#d8d8d2"))
	for k in 2:
		_place(DIR + "worker.glb", Transform3D(Basis(Vector3.UP, 1.2 + float(k)), _ground(z0 + 38.0 + 5.0 * float(k), lat0 + 3.0 + float(k))))


## Red suspension footbridge over a far valley: the spot where the ground in the middle is lowest under the ends.
func _footbridge() -> void:
	if field == null or not ResourceLoader.exists(DIR + "footbridge.glb"):
		return
	var best: Array = []
	var best_gap: float = 6.0
	var z: float = 1300.0
	while z < path.track.length_m - 250.0:
		for lat in [170.0, 210.0, 250.0, 290.0]:
			var a: Vector3 = _ground(z - 72.0, lat)
			var bb: Vector3 = _ground(z + 72.0, lat)
			var m: Vector3 = _ground(z, lat)
			var gap: float = minf(a.y, bb.y) - m.y
			if gap > best_gap and absf(a.y - bb.y) < 8.0:
				best_gap = gap
				best = [z, lat, minf(a.y, bb.y)]
		z += 50.0
	if best.is_empty():
		return
	var zc: float = float(best[0])
	var p0: Vector3 = _ground(zc - 72.0, float(best[1]))
	var p1: Vector3 = _ground(zc + 72.0, float(best[1]))
	var dir: Vector3 = (p1 - p0)
	dir.y = 0.0
	var b := Basis.looking_at(dir.normalized(), Vector3.UP)
	var mid: Vector3 = (p0 + p1) * 0.5
	mid.y = float(best[2]) - 1.2
	_place(DIR + "footbridge.glb", Transform3D(b, mid))
	counts["footbridge_at"] = "%d,%d" % [int(zc), int(best[1])]
