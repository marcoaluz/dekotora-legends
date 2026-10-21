class_name MountainRidges
extends Node3D
## T-188: the MIDDLE layer of the mountains (between the hills of TerrainPatch, up to ~345 m, and the snowy massifs
## of the horizon, 1-6 km). Pieces of mountain range 0,5-0,9 km long, made by code: rounded envelope x ridged noise,
## jagged crest, forest low, rock high and snow on the tallest tops (mountain route). Placed 0,6-1,3 km from the
## road along the pilot stretch (+-250 m), never closer to ANY part of the route than their own half-depth + 320 m.
## All pieces of the stretch in one mesh (1 draw call). The engine fog gives the aerial perspective.

const GX: int = 24
const GY: int = 12

var piece_count: int = 0
var centres: Array[Vector3] = []          # tests
var _pts: PackedVector3Array = PackedVector3Array()
var _vertex_total: int = 0


func build(path: TrackPath, kind: StringName, tod: TimeOfDay, zone: Vector2, seed_: int) -> void:
	var L: float = path.track.length_m
	var z: float = 0.0
	while z <= L:
		_pts.append(path.center_at(z))
		z += 25.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_ + 7
	var noise := FastNoiseLite.new()
	noise.seed = seed_ + 8
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 4
	noise.frequency = 0.0035
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides: Array[float] = [-1.0]
	if kind == &"mountain":
		sides.append(1.0)
	var tall: Vector2 = Vector2(260.0, 440.0) if kind == &"mountain" else Vector2(170.0, 300.0)
	for side in sides:
		z = zone.x - 250.0
		while z < zone.y + 250.0:
			var zz: float = clampf(z, 0.0, L - 1.0)
			var length: float = rng.randf_range(520.0, 900.0)
			var depth: float = rng.randf_range(380.0, 620.0)
			var hgt: float = rng.randf_range(tall.x, tall.y)
			var lat: float = depth * 0.5 + rng.randf_range(420.0, 650.0)
			var turn: float = rng.randf_range(-0.25, 0.25)
			var c: Vector3 = path.world_point(zz, side * lat / Track.ROAD_HALF_WIDTH_M)
			var ok: bool = false
			for _k in 6:                                   # curves: push out until no part of the route is near
				if _min_dist(c) >= depth * 0.5 + 320.0:
					ok = true
					break
				lat += 140.0
				c = path.world_point(zz, side * lat / Track.ROAD_HALF_WIDTH_M)
			if ok:
				c.y = path.center_at(zz).y - 8.0
				_piece(st, noise, c, path.yaw_at(zz) + turn, length, depth, hgt, kind == &"mountain")
				centres.append(c)
				piece_count += 1
			z += length * rng.randf_range(0.45, 0.7)
	if piece_count == 0:
		return
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = ScenicShaders.ridge(tod, kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _min_dist(p: Vector3) -> float:
	var best: float = INF
	for q in _pts:
		best = minf(best, Vector2(p.x - q.x, p.z - q.z).length())
	return best


## One piece: grid along (forward) x across (right); height = envelope x ridged noise, edges at the base.
func _piece(st: SurfaceTool, noise: FastNoiseLite, c: Vector3, yaw: float, length: float, depth: float, hgt: float,
		snowy: bool) -> void:
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var first: int = _vertex_total
	for r in GX + 1:
		var u: float = float(r) / float(GX) - 0.5
		for k in GY + 1:
			var v: float = float(k) / float(GY) - 0.5
			var p: Vector3 = c + fwd * u * length + right * v * depth
			var env: float = pow(maxf(1.0 - pow(2.0 * v, 2.0), 0.0), 1.15) * maxf(1.0 - pow(2.0 * absf(u), 5.0), 0.0)
			var n: float = noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5
			var h: float = hgt * env * (0.45 + 0.55 * n)
			var rel: float = h / hgt
			st.set_color(Color(smoothstep(0.62, 0.85, rel) if snowy else 0.0, 1.0 - smoothstep(0.3, 0.55, rel),
				smoothstep(0.45, 0.75, rel), 1.0))
			st.add_vertex(p + Vector3.UP * h)
	for r in GX:
		for k in GY:
			var a: int = first + r * (GY + 1) + k
			var d: int = a + GY + 1
			for i in [a, d, a + 1, a + 1, d, d + 1]:
				st.add_index(i)
	_vertex_total += (GX + 1) * (GY + 1)
