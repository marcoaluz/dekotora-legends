class_name DanchiLayout
extends RefCounted
## T-217: concrete apartment blocks (団地 danchi) and small buildings right beside the urban expressway, between our
## viaduct and the elevated railway on the left (rail at 40 m, city blocks from 62 m). Pure data, deterministic.
## Footprints: [z0, z1, side, lat0, lat1, floors, kind (0 = danchi slab, 1 = small building), number] in metres.
## Runs leave room for the unique car (~0,6 km), the tunnel box (0,98-1,28 km), the rail crossing (1,5 km) and the
## overpass (2,05 km).

const RUNS: Dictionary = {
	"kanto_2_viaduct": [[440.0, 555.0], [700.0, 965.0], [1290.0, 1455.0], [1565.0, 2005.0], [2110.0, 2700.0]],
}
const SLAB_LAT: Vector2 = Vector2(19.5, 29.5)
const SMALL_LAT: Vector2 = Vector2(17.5, 27.5)
const FLOOR_H: float = 2.8

var path: TrackPath
var blocks: Array = []

static var _by_path: Dictionary = {}


static func enabled() -> bool:
	return not "--no-danchi" in OS.get_cmdline_user_args()


static func of(path_: TrackPath) -> DanchiLayout:
	if path_ == null:
		return null
	return _by_path.get(path_.get_instance_id(), null)


static func register(d: DanchiLayout) -> void:
	_by_path[d.path.get_instance_id()] = d


static func clear_all() -> void:
	_by_path.clear()


func _init(path_: TrackPath, route_id: String) -> void:
	path = path_
	blocks = footprints(route_id)


static func footprints(route_id: String) -> Array:
	var out: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2170 + absi(route_id.hash()) % 997
	var number: int = 1
	for r in RUNS.get(route_id, []):
		var z: float = float(r[0])
		while z < float(r[1]) - 10.0:
			if rng.randf() < 0.3:                                    # small building: shops below, 2-4 floors
				var w: float = rng.randf_range(10.0, 15.0)
				if z + w > float(r[1]):
					break
				out.append([z, z + w, -1.0, SMALL_LAT.x + rng.randf_range(0.0, 2.0), SMALL_LAT.y, rng.randi_range(2, 4), 1, 0])
				z += w + rng.randf_range(4.0, 9.0)
			else:
				var l: float = rng.randf_range(42.0, 64.0)
				if z + l > float(r[1]):
					l = float(r[1]) - z
					if l < 30.0:
						break
				out.append([z, z + l, -1.0, SLAB_LAT.x, SLAB_LAT.y, 5, 0, number])
				number += 1
				z += l + rng.randf_range(14.0, 24.0)
	return out


## Drops the blocks within `margin` of z (the unique car's lot).
func clear_around(z: float, margin: float) -> void:
	var keep: Array = []
	for b in blocks:
		if float(b[1]) < z - margin or float(b[0]) > z + margin:
			keep.append(b)
	blocks = keep


## (z, signed lateral) inside a footprint (+ margin): no tree, pole or sign there.
func blocks_at(z: float, lat: float, margin: float = 2.0) -> bool:
	for b in blocks:
		if signf(lat) == float(b[2]) and z > float(b[0]) - margin and z < float(b[1]) + margin \
				and absf(lat) > float(b[3]) - margin and absf(lat) < float(b[4]) + margin:
			return true
	return false


func spans() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for b in blocks:
		out.append(Vector2(float(b[0]), float(b[1])))
	return out
