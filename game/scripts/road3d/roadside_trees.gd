class_name RoadsideTrees
extends RefCounted
## T-186: vegetation along the road in natural GROVES (never in a row): every species of the scenery library mixed
## per biome, scale 0.8-1.3, random yaw, groves of 1-7 trees on a disc with a minimum spacing, gaps between groves.
## Pure placement (no nodes): returns [model, Transform3D] pairs; Roadside3D draws them in MultiMesh with 2 LODs.
## Deterministic: same route seed -> same trees. Only visual (nothing in the sim or the network).
##   coast    : 3 palms (palm, palm_tall, palm_bent) + bushes; broadleaf (Gleditsia a/b/c) only on the land side
##   city     : street trees (Gleditsia a/b/c/e, round tree) + a few pines and bushes (on the ground under the viaduct)
##   mountain : pines + Japanese cedar + broadleaf (Gleditsia c/d/e/f) + bushes

const MIX: Dictionary = {
	&"coast": [["palm", 16], ["palm_tall", 14], ["palm_bent", 10], ["bush", 14], ["tree_leafy", 9], ["tree_leafy_b", 8],
		["tree_leafy_c", 6], ["tree_round", 4]],
	&"city": [["tree_leafy", 16], ["tree_leafy_b", 15], ["tree_leafy_c", 12], ["tree_leafy_e", 8], ["tree_round", 14],
		["tree_pine", 8], ["bush", 12]],
	&"mountain": [["tree_pine", 20], ["tree_cedar", 22], ["tree_leafy_d", 10], ["tree_leafy_e", 9], ["tree_leafy_f", 9],
		["tree_leafy_c", 7], ["bush", 8]],
}
const PALMS: Array[String] = ["palm", "palm_tall", "palm_bent", "bush"]   # what may grow on the sea side of the coast
const GAP: Vector2 = Vector2(14.0, 46.0)        # m between groves (along the road, each side)
const LAT: Vector2 = Vector2(15.0, 34.0)        # m from the road centre (barrier at 13 m)
const RAIL_CLEAR: float = 9.0                   # m from the axis of a parallel railway
const SPACING: float = 3.2                      # minimum distance between two trees of a grove
const COMPANION: float = 0.3                    # chance that a tree of a grove is another species


## Trees for the route: Array of [model: String, xf: Transform3D]. `blocked(z, lat_signed, pos) -> bool` filters the
## places Roadside3D already knows (tunnels, bridges, overpass, wires); `rails` = Array[RailLine] (parallel lines).
## T-217: `right_shift` moves the right-side groves out (beyond the other carriageway, OppositeLayout.SHIFT); the
## draws are the same, only the place changes.
static func place(path: TrackPath, kind: StringName, seed_: int, deck: float, blocked: Callable, rails: Array,
		right_shift: float = 0.0) -> Array:
	var out: Array = []
	var mix: Array = MIX.get(kind, MIX[&"city"])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var L: float = path.track.length_m
	for side in [-1.0, 1.0]:
		var z: float = rng.randf_range(0.0, GAP.x)
		while z < L - 5.0:
			var n: int = _grove_size(rng)
			var species: String = _pick(rng, mix, kind, side)
			var centre: float = rng.randf_range(LAT.x + 2.0, LAT.y - 2.0)
			var radius: float = 2.5 + float(n) * 1.5
			var placed: Array[Vector2] = []
			for k in n:
				var p: Vector2 = _spot(rng, Vector2(z, centre), radius, placed)
				if p.x < 0.0:
					continue
				if side > 0.0:
					p.y += right_shift
				var model: String = species if rng.randf() >= COMPANION else _pick(rng, mix, kind, side)
				var sc: float = rng.randf_range(0.8, 1.3)
				var yaw: float = rng.randf() * TAU
				if p.x > L - 2.0 or p.y < LAT.x or _near_rail(rails, p.x, side * p.y):
					continue
				var pos: Vector3 = path.world_point(p.x, side * p.y / Track.ROAD_HALF_WIDTH_M, -deck)
				if blocked.call(p.x, side * p.y, pos):
					continue
				placed.append(p if side < 0.0 else p - Vector2(0.0, right_shift))
				out.append([model, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3.ONE * sc), pos)])
			z += radius + rng.randf_range(GAP.x, GAP.y)
	return out


## Grove sizes: many pairs and trios, some singles, a few big clumps.
static func _grove_size(rng: RandomNumberGenerator) -> int:
	var r: float = rng.randf()
	if r < 0.18:
		return 1
	if r < 0.5:
		return 2 + int(r * 10.0) % 2
	if r < 0.85:
		return 4
	return 5 + rng.randi_range(0, 2)


static func _pick(rng: RandomNumberGenerator, mix: Array, kind: StringName, side: float) -> String:
	var total: int = 0
	for e in mix:
		total += int(e[1])
	var r: int = rng.randi_range(0, total - 1)
	var pick: String = String(mix[0][0])
	for e in mix:
		r -= int(e[1])
		if r < 0:
			pick = String(e[0])
			break
	if kind == &"coast" and side > 0.0 and not pick in PALMS:     # sea side: no broadleaf on the beach
		pick = PALMS[rng.randi_range(0, 2)]
	return pick


## A point of the grove disc (z, lateral) at least SPACING from the others; (-1, -1) if no room after 6 tries.
static func _spot(rng: RandomNumberGenerator, c: Vector2, r: float, placed: Array[Vector2]) -> Vector2:
	for t in 6:
		var a: float = rng.randf() * TAU
		var d: float = sqrt(rng.randf()) * r
		var p: Vector2 = c + Vector2(cos(a) * d, sin(a) * d * 0.7)   # groves a bit longer along the road
		var ok: bool = true
		for q in placed:
			if q.distance_to(p) < SPACING:
				ok = false
				break
		if ok:
			return p
	return Vector2(-1.0, -1.0)


static func _near_rail(rails: Array, z: float, lat: float) -> bool:
	for l in rails:
		var line: RailLine = l as RailLine
		if line.kind != RailLine.Kind.PARALLEL or z < line.z0 - 20.0 or z > line.z1 + 20.0:
			continue
		if signf(lat) == line.side and absf(absf(lat) - line.offset) < RAIL_CLEAR:
			return true
	return false
