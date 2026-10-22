class_name CityBlocks
extends Node3D
## T-188: buildings of the pilot stretch, ON THE GROUND and AWAY from the road (instead of CityBuilder's boxes that
## floated on the grass/sea, all with the same windows, some glued to the road):
## - city: rows of BLOCKS on both sides of the viaduct (sidewalk slab = base), STREETS between them (asphalt of the
##   terrain + dashed centre lines), 1-4 buildings per block with a setback from the slab edge, parks, heights that
##   grow toward the back, 8 facade styles (shop fronts on the ground floor near the road), varied roofs (parapet,
##   tiers, water tanks, AC units, machine rooms, rooftop billboards) and kanji NEON signs (NeonSigns) lit at night;
## - coast: a small town on the hills of the land side (houses on a concrete plinth that follows the slope, pitched
##   roofs, a few small apartment blocks).
## First row of blocks: 44 m from the centre line on the right, 62 m on the left (elevated railway at 40 m), so no
## facade is closer than ~46 m to the road (~33 m from the barrier). Keep-out corridors (rail crossing, overpass) stay empty.

const STREET_M: float = 12.0
const ROWS_TO: float = 300.0
const START_R: float = 44.0
const START_L: float = 62.0
const FLOOR_M: float = 3.5
const SLAB_H: float = 0.3
const SETBACK_M: float = 2.5
const WALLS: Array[Color] = [Color("#9a958c"), Color("#b8b2a6"), Color("#7d8288"), Color("#a08f7c"), Color("#c9c6bf"),
	Color("#8b8f96"), Color("#a7a294")]
const ROOFS: Array[Color] = [Color("#39404f"), Color("#6b3a2a"), Color("#2f3033"), Color("#355047"), Color("#4a4d57")]

var building_count: int = 0
var nearest_facade_m: float = INF        # tests: closest building face to the road centre line
var path: TrackPath
var field: TerrainField
var keep_out: Array = []
var _rng := RandomNumberGenerator.new()
var _b: Array = []
var _slabs: Array = []
var _props: Array = []
var _roofs: Array = []
var _lines: Array = []
var _neon: NeonSigns
var models: CityModels                   # T-193: textured buildings (docs/Modelos/Cidade) on some lots
var sides: Array[float] = [-1.0, 1.0]       # T-195: ArrivalCity (coast: only the land side)
var force_city: bool = false              # T-195: ArrivalCity builds city blocks on any route
var details: CityDetails                  # T-199: cornices, masts, AC units, balconies, fire escapes, awnings, signs


func build(field_: TerrainField, tod: TimeOfDay, keep_out_: Array, seed_: int) -> void:
	field = field_
	path = field.path
	keep_out = keep_out_
	_rng.seed = seed_ + 55
	_neon = NeonSigns.new()
	add_child(_neon)
	details = CityDetails.new(seed_)
	if (field.kind == &"city" or force_city) and CityModels.enabled():
		models = CityModels.new(tod, seed_, int(Settings.quality))
	if field.kind == &"city" or force_city:
		_city()
	elif field.kind == &"coast":
		_coast_town()
	_commit(tod)
	_neon.commit(tod)


func _city() -> void:
	var z0: float = field.zone.x
	var z1: float = field.zone.y
	for side in sides:
		var lat: float = START_L if side < 0.0 else START_R
		_street_line(z0, z1, side * (lat - STREET_M * 0.6))
		var row: int = 0
		while lat < ROWS_TO:
			var depth: float = _rng.randf_range(42.0, 62.0)
			var z: float = z0 + _rng.randf_range(0.0, 20.0)
			while z < z1 - 30.0:
				var zb: float = minf(z + _rng.randf_range(54.0, 90.0), z1)
				_block(z, zb, side, lat, lat + depth, row)
				z = zb + STREET_M
			lat += depth + STREET_M
			_street_line(z0, z1, side * (lat - STREET_M * 0.5))
			row += 1


## One block from za to zb (along the road) and lateral la..lb on `side`.
func _block(za: float, zb: float, side: float, la: float, lb: float, row: int) -> void:
	var zc: float = (za + zb) * 0.5
	var latc: float = side * (la + lb) * 0.5
	var c: Vector3 = path.world_point(zc, latc / Track.ROAD_HALF_WIDTH_M)
	c.y = path.center_at(zc).y - field.deck
	var along: float = path.world_point(za, latc / Track.ROAD_HALF_WIDTH_M).distance_to(path.world_point(zb, latc / Track.ROAD_HALF_WIDTH_M))
	var across: float = lb - la
	if _blocked(c, maxf(along, across) * 0.5, (la + lb) * 0.5):
		return
	var yaw: float = path.yaw_at(zc)
	var by := Basis(Vector3.UP, yaw)
	var park: bool = _rng.randf() < 0.12
	var slab_col: Color = Color("#2c3d22") if park else Color("#8a8780")
	_slabs.append([Transform3D(by * Basis.from_scale(Vector3(across, SLAB_H, along)), c + Vector3.UP * SLAB_H * 0.5), slab_col])
	if park:
		return
	var right: Vector3 = path.right_at(zc)
	var fwd: Vector3 = path.forward_at(zc)
	var n_al: int = clampi(int(along / 30.0), 1, 3)
	var n_ac: int = 2 if across > 52.0 and _rng.randf() < 0.6 else 1
	for i in n_ac:
		for j in n_al:
			var lw: float = across / float(n_ac)
			var ld: float = along / float(n_al)
			var off: Vector3 = right * side * (-across * 0.5 + lw * (float(i) + 0.5)) + fwd * (-along * 0.5 + ld * (float(j) + 0.5))
			var front: bool = row == 0 and i == 0
			_building(c + off + Vector3.UP * SLAB_H, by, right * -side, fwd, lw, ld, row, front, zc)


## A building on a lot of lw (across) x ld (along) metres; `to_road` = horizontal direction of the road.
func _building(base: Vector3, by: Basis, to_road: Vector3, fwd: Vector3, lw: float, ld: float, row: int, front: bool,
		z: float = 0.0) -> void:
	var w: float = maxf(snappedf(lw - SETBACK_M * 2.0, 3.0), 9.0)
	var d: float = maxf(snappedf(ld - SETBACK_M * 2.0, 3.0), 9.0)
	var lo: int = [3, 5, 8][mini(row, 2)]
	var hi: int = [9, 15, 26][mini(row, 2)]
	var floors: int = _rng.randi_range(lo, hi) + (10 if _rng.randf() < 0.08 else 0)
	var h: float = float(floors) * FLOOR_M + 1.0
	var style: int = [2, 3, 4, 5, 6, 1][_rng.randi() % 6] if row == 0 else _rng.randi() % 8
	var shop: bool = front or _rng.randf() < 0.25
	var wall: Color = WALLS[_rng.randi() % WALLS.size()]
	wall.a = (float(style) + 0.5) / 16.0 + (0.5 if shop else 0.0)
	var model := Vector3.ZERO                                        # T-193: a textured building on this lot?
	if models != null:
		model = models.try_place(base, by, w, d, row, float(hi + 12) * FLOOR_M, z)
	if model != Vector3.ZERO:
		w = model.x
		d = model.z
		h = model.y
		floors = int(h / FLOOR_M)
	else:
		_b.append([Transform3D(by * Basis.from_scale(Vector3(w, h, d)), base + Vector3.UP * h * 0.5), wall])
	building_count += 1
	var face_lat: float = _lat_of(base - to_road * w * 0.5)
	nearest_facade_m = minf(nearest_facade_m, face_lat)
	var top: float = h
	if model != Vector3.ZERO:
		pass                                                         # the model has its own roof
	elif floors > 10 and _rng.randf() < 0.35:                        # tier on top
		var f2: int = _rng.randi_range(2, 6)
		var h2: float = float(f2) * FLOOR_M + 1.0
		_b.append([Transform3D(by * Basis.from_scale(Vector3(snappedf(w * 0.6, 3.0), h2, snappedf(d * 0.6, 3.0))),
			base + Vector3.UP * (h + h2 * 0.5)), Color(wall.r, wall.g, wall.b, (float(style) + 0.5) / 16.0)])   # no shops up there
		top += h2
	if model == Vector3.ZERO:
		_roof_props(base + Vector3.UP * top, by, w * (0.6 if top > h else 1.0), d * (0.6 if top > h else 1.0))
	if front and _rng.randf() < 0.6:                                 # vertical neon on the face toward the road
		var sh: float = clampf(float(floors) * 1.1, 4.5, 9.0)
		var at: Vector3 = base + to_road * (w * 0.5 + 0.6) + fwd * (d * 0.5 - 1.6) * (1.0 if _rng.randf() < 0.5 else -1.0)
		_neon.add(at + Vector3.UP * (FLOOR_M + 0.5 + sh * 0.5), to_road, Vector2(sh * 0.25, sh), _rng.randi() % 16, true)
	if row <= 1 and floors >= 4 and _rng.randf() < 0.3:              # rooftop billboard facing the road
		var bw: float = minf(d * 0.8, 12.0)
		var roof_at: Vector3 = base + Vector3.UP * (top + 1.2 + bw * 0.25) + to_road * (w * 0.5 - 1.0)
		_neon.add(roof_at, to_road, Vector2(bw, bw * 0.5), _rng.randi() % 8, false)
		_props.append([Transform3D(by * Basis.from_scale(Vector3(0.3, 1.2, bw * 0.9)), roof_at - Vector3.UP * (bw * 0.25 + 0.6) - to_road * 0.3), Color("#3a3c40")])
	if model == Vector3.ZERO:
		details.building(base, by, to_road, fwd, w, d, h, top, wall, row, shop, front, z)


## AC units, water tank and machine room on a flat roof (top centre `at`).
func _roof_props(at: Vector3, by: Basis, w: float, d: float) -> void:
	for _k in _rng.randi_range(1, 5):
		var p := Vector3(_rng.randf_range(-0.35, 0.35) * w, 0.5, _rng.randf_range(-0.35, 0.35) * d)
		_props.append([Transform3D(by * Basis.from_scale(Vector3(1.4, 1.0, 1.8)), at + by * p), Color("#b9bab4")])
	if _rng.randf() < 0.45:
		var tp := Vector3(_rng.randf_range(-0.25, 0.25) * w, 1.6, _rng.randf_range(-0.25, 0.25) * d)
		_props.append([Transform3D(by * Basis.from_scale(Vector3(2.6, 3.2, 2.6)), at + by * tp), Color("#7f8c94")])
	if _rng.randf() < 0.5:
		var mp := Vector3(_rng.randf_range(-0.2, 0.2) * w, 1.5, _rng.randf_range(-0.2, 0.2) * d)
		_props.append([Transform3D(by * Basis.from_scale(Vector3(4.0, 3.0, 5.0)), at + by * mp), Color("#9c9890")])


## Coast: houses on the hills of the land side, on a plinth that follows the slope.
func _coast_town() -> void:
	var z: float = field.zone.x + 60.0
	while z < field.zone.y - 60.0:
		for _k in 2:
			var lat: float = -_rng.randf_range(64.0, 200.0)
			var take: float = _rng.randf()
			var w: float = snappedf(_rng.randf_range(9.0, 15.0), 3.0)
			var d: float = snappedf(_rng.randf_range(9.0, 15.0), 3.0)
			var flat: bool = _rng.randf() < 0.3
			var floors: int = _rng.randi_range(4, 6) if flat else _rng.randi_range(2, 3)
			var roof_c: Color = ROOFS[_rng.randi() % ROOFS.size()]
			var turn: float = _rng.randf_range(-0.3, 0.3)
			if take > 0.55:
				continue
			_house(z, lat, w, d, floors, flat, roof_c, turn)
		z += _rng.randf_range(22.0, 40.0)


func _house(z: float, lat: float, w: float, d: float, floors: int, flat: bool, roof_c: Color, turn: float) -> void:
	var c: Vector3 = path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M)
	var by := Basis(Vector3.UP, path.yaw_at(z) + turn)
	var hmin: float = INF
	var hmax: float = -INF
	for corner in [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5), Vector3.ZERO]:
		var p: Vector3 = c + by * (corner * Vector3(w + 1.0, 0.0, d + 1.0))
		var hh: float = field.height_at(Vector2(p.x, p.z))
		if is_nan(hh):
			return
		hmin = minf(hmin, hh)
		hmax = maxf(hmax, hh)
	if hmax - hmin > 4.5 or _blocked(c, maxf(w, d), absf(lat)) or field.paint(lat, hmax - path.center_at(z).y, Vector2(c.x, c.z)).g > 0.6:
		return
	var ph: float = hmax - hmin + 1.9
	_props.append([Transform3D(by * Basis.from_scale(Vector3(w + 1.2, ph, d + 1.2)), Vector3(c.x, hmin - 1.5 + ph * 0.5, c.z)), Color("#5d5a52")])
	var h: float = float(floors) * FLOOR_M + (1.0 if flat else 0.0)
	var base := Vector3(c.x, hmax + 0.4, c.z)
	var wall: Color = WALLS[_rng.randi() % WALLS.size()]
	var style: int = [2, 6, 3, 4][_rng.randi() % 4]
	wall.a = (float(style) + 0.5) / 16.0
	_b.append([Transform3D(by * Basis.from_scale(Vector3(w, h, d)), base + Vector3.UP * h * 0.5), wall])
	building_count += 1
	details.house(base, by, w, d, h, flat, z, 1.0 if lat < 0.0 else -1.0)
	if flat:
		_roof_props(base + Vector3.UP * h, by, w, d)
	else:
		_roofs.append([Transform3D(by * Basis.from_scale(Vector3(w + 0.8, _rng.randf_range(2.4, 3.4), d + 0.8)), base + Vector3.UP * h), roof_c])


## Dashed centre line of a street parallel to the road at signed lateral `lat` (m).
func _street_line(z0: float, z1: float, lat: float) -> void:
	var z: float = z0 + 4.0
	while z < z1 - 4.0:
		var p: Vector3 = path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M)
		p.y = path.center_at(z).y - field.deck + 0.03
		if not _blocked(p, 2.0, absf(lat)):
			_lines.append([Transform3D(Basis(Vector3.UP, path.yaw_at(z)) * Basis.from_scale(Vector3(0.18, 1.0, 3.0)), p), Color("#d8d6cc")])
		z += 8.0


func _lat_of(p: Vector3) -> float:
	return field.nearest(Vector2(p.x, p.z)).x


## Keep-out corridor (rail crossing, overpass) within reach of the circle, or another part of the route closer than
## the expected lateral distance `lat` (curves: the inner side of one bend can reach the road of another).
func _blocked(c: Vector3, r: float, lat: float) -> bool:
	var p := Vector2(c.x, c.z)
	for k in keep_out:
		if Geometry2D.get_closest_point_to_segment(p, k[0], k[1]).distance_to(p) < float(k[2]) + r:
			return true
	return field.nearest(p).x < lat - 8.0


func _commit(tod: TimeOfDay) -> void:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_multi(box, _b, CityLook.facade(tod))
	_multi(box, _slabs, CityLook.props())
	_multi(box, _props, CityLook.props())
	_multi(CityLook.prism(), _roofs, CityLook.roof())
	_multi(plane, _lines, CityLook.props())
	if models != null:
		models.commit(self, tod)
	details.commit(self)


func _multi(mesh: Mesh, items: Array, mat: Material) -> void:
	if items.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_color(i, items[i][1])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
