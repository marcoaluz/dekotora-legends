class_name TerrainField
extends RefCounted
## T-188: height of the ground beside the road on the pilot stretch (ScenicZone), relative to the road at the
## nearest point. Pure maths (no nodes), deterministic (seeded noise): TerrainPatch builds the mesh with it and
## Roadside3D / CityBlocks put trees, rocks and houses on it.
## Profile across the road (lateral = metres from the centre line, + = right):
## - 0..FLAT_M  : flat (barrier, trees at 15-34 m, power poles at 17 m, parallel railway at 36-40 m);
## - beyond     : hills that grow with the distance (mountain up to ~100 m at 340 m, coast land side ~45 m);
## - coast, sea side: grass, sand from 21 m sloping into the sea (same profile as RoadMesh), far shore at 360 m;
## - city: flat ground under the viaduct (streets and blocks are drawn on it).
## Another part of the route (or a rail/overpass corridor) close to a point flattens it: hills never cover a road.

const FLAT_M: float = 46.0
const RAMP_M: float = 120.0
const CELL: float = 80.0
const SAMPLE_M: float = 6.0
const BEACH: Vector4 = Vector4(21.0, 24.0, 39.5, 70.0)   # grass end, sand start, waterline (-1.6), seabed (-4.5)
const FAR_SHORE: Vector2 = Vector2(355.0, 380.0)          # coast: bay bottom -> far shore top (+0.4)

var path: TrackPath
var kind: StringName
var zone: Vector2
var deck: float
var keep_out: Array = []          # [a: Vector2, b: Vector2, half_width] (rail crossings, overpass)
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _side := FastNoiseLite.new()
var _cells: Dictionary = {}       # Vector2i -> PackedInt32Array (indices of road samples)
var _pts: PackedVector2Array = PackedVector2Array()
var _zs: PackedFloat32Array = PackedFloat32Array()


func _init(path_: TrackPath, kind_: StringName, zone_: Vector2, keep_out_: Array = [], seed_: int = 188) -> void:
	path = path_
	kind = kind_
	zone = zone_
	deck = RoadMesh.deck_height(kind)
	keep_out = keep_out_
	_hills.seed = seed_
	_hills.frequency = 0.0042
	_hills.fractal_octaves = 4
	_hills.fractal_type = FastNoiseLite.FRACTAL_RIDGED if kind == &"mountain" else FastNoiseLite.FRACTAL_FBM
	_detail.seed = seed_ + 1
	_detail.frequency = 0.03
	_side.seed = seed_ + 2
	_side.frequency = 0.0025
	var z: float = 0.0
	while z <= path.end_m():                               # T-195: + continuacao depois da chegada
		var c: Vector3 = path.center_at(z)
		var key := Vector2i(floori(c.x / CELL), floori(c.z / CELL))
		if not _cells.has(key):
			_cells[key] = PackedInt32Array()
		var arr: PackedInt32Array = _cells[key]
		arr.append(_pts.size())
		_cells[key] = arr
		_pts.append(Vector2(c.x, c.z))
		_zs.append(z)
		z += SAMPLE_M


## Nearest road sample to the point (x, z of the world): Vector3(distance m, road z, side -1/+1).
## Distance = INF when no road is within ~2 cells (160 m).
func nearest(p: Vector2) -> Vector3:
	var ck := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	var best: float = INF
	var bi: int = -1
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var key := Vector2i(ck.x + dx, ck.y + dz)
			if not _cells.has(key):
				continue
			for i in _cells[key]:
				var d2: float = _pts[i].distance_squared_to(p)
				if d2 < best:
					best = d2
					bi = i
	if bi < 0:
		return Vector3(INF, 0.0, 1.0)
	var z: float = _zs[bi]
	var c: Vector3 = path.center_at(z)
	var r: Vector3 = path.right_at(z)
	var lat: float = (p.x - c.x) * r.x + (p.y - c.z) * r.z
	var along: float = (p.x - c.x) * r.z - (p.y - c.z) * r.x        # forward = (r.z, -r.x) in the x/z plane
	z = clampf(z + along, 0.0, path.end_m())
	return Vector3(absf(lat), z, signf(lat) if lat != 0.0 else 1.0)


## Height above the road at road coordinate (z, signed lateral m) for the world point `wp` (x, z).
func rel_height(z: float, lat: float, wp: Vector2) -> float:
	var w: float = ScenicZone.weight(zone, z)
	if kind == &"city":
		return 0.0
	if kind == &"coast" and lat > 0.0:
		return _sea_side(lat, wp)
	if w <= 0.0:
		return 0.0
	var d: float = absf(lat)
	var near: Vector3 = nearest(wp)                                 # another part of the road closer than this one?
	if near.x < d - 8.0:
		d = near.x
	var flat: float = _corridor_flat(wp)
	var ramp: float = smoothstep(0.0, RAMP_M, d - FLAT_M) * flat
	if ramp <= 0.0:
		return 0.0
	var n: float = _hills.get_noise_2d(wp.x, wp.y) * 0.5 + 0.5
	var fine: float = _detail.get_noise_2d(wp.x, wp.y) * 2.5
	var t: float = d - FLAT_M
	var side_amp: float = 0.5 + 0.5 * (_side.get_noise_1d(z + signf(lat) * 4000.0) * 0.5 + 0.5)
	var h: float
	if kind == &"mountain":
		h = (70.0 * side_amp * (0.3 + 0.7 * n) + 0.22 * t) + fine
	else:
		h = (42.0 * side_amp * (0.25 + 0.75 * n) + 0.09 * t) + fine
	return maxf(h, 0.0) * ramp * w


## World height of the ground at world point (x, z) (trees, rocks, houses). NAN far from the road.
func height_at(wp: Vector2) -> float:
	var n: Vector3 = nearest(wp)
	if n.x == INF:
		return NAN
	return path.center_at(n.y).y - deck + rel_height(n.y, n.x * n.z, wp)


## Coast, sea side: grass, sand down to the water, seabed, far shore (same in and out of the stretch near the road).
func _sea_side(lat: float, wp: Vector2) -> float:
	if lat <= BEACH.y:
		return 0.0
	if lat <= BEACH.z:
		return -1.6 * smoothstep(BEACH.y, BEACH.z, lat) + _detail.get_noise_2d(wp.x, wp.y) * 0.12
	if lat < FAR_SHORE.x:
		return lerpf(-1.6, -4.5, clampf((lat - BEACH.z) / (BEACH.w - BEACH.z), 0.0, 1.0))
	var t: float = smoothstep(FAR_SHORE.x, FAR_SHORE.y, lat)
	return lerpf(-4.5, 0.4 + absf(_detail.get_noise_2d(wp.x, wp.y)) * 1.5 * t, t)


## 0 inside a keep-out corridor (rail crossing, overpass), 1 far from them.
func _corridor_flat(wp: Vector2) -> float:
	var f: float = 1.0
	for k in keep_out:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(wp, k[0], k[1])
		f = minf(f, smoothstep(float(k[2]) + 6.0, float(k[2]) + 70.0, q.distance_to(wp)))
	return f


## Vertex paint for the terrain shader at this point: r = sand, g = forest, b = city ground.
func paint(lat: float, rel: float, wp: Vector2) -> Color:
	if kind == &"city":
		return Color(0.0, 0.0, 1.0, 1.0) if absf(lat) > RoadMesh.BARRIER_IN + 0.6 else Color(0, 0, 0, 1)
	var sand: float = 0.0
	if kind == &"coast" and lat > 0.0:
		sand = smoothstep(BEACH.x, BEACH.y, lat) * (1.0 - smoothstep(FAR_SHORE.y, FAR_SHORE.y + 25.0, lat))
	var patch: float = _detail.get_noise_2d(wp.x * 0.25 + 50.0, wp.y * 0.25) * 0.5 + 0.5
	var forest: float = smoothstep(3.0, 16.0, rel) * (0.75 + 0.25 * patch)
	if kind == &"coast":
		forest *= smoothstep(0.45, 0.6, patch)
	return Color(sand, forest, 0.0, 1.0)
