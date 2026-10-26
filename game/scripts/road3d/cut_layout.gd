class_name CutLayout
extends RefCounted
## T-217: where the road runs in a CUT through a hill, held by a stone retaining wall (石積み, 谷積み masonry) with grass
## on top, as in the original game: runs [z0, z1, side (-1 left / +1 right), height m] per route. Pure data, no
## nodes, only visual. Left walls stand right behind our barrier; right walls stand beyond the other carriageway.
## Behind the wall the ground is a terrace at the wall top rising gently into the hills (TerrainField asks `terrace`).
## Rules (tests/test_scenery_t217.gd): never on the side of a parallel railway, never in a tunnel, a bridge or the
## coast sea side; walls taper to nothing over TAPER_M at both ends (the cut grows out of the slope).

const BATTER: float = 0.35          # horizontal metres per metre of height (the wall leans back)
const TAPER_M: float = 28.0
const GUTTER_W: float = 0.6         # concrete U channel at the foot
const TERRACE_SLOPE: float = 0.25   # the ground behind the coping rises this much per metre
## [z0, z1, side, height, taper at z0, taper at z1]: no taper where the wall meets a tunnel portal.
const RUNS: Dictionary = {
	"kanto_1_coast": [[2175.0, 2390.0, -1.0, 6.5, true, true]],
	"kanto_3_mountain": [[370.0, 804.0, -1.0, 8.0, true, false], [1042.0, 1215.0, -1.0, 6.5, false, true],
		[1290.0, 1760.0, 1.0, 9.5, true, true], [2385.0, 2560.0, 1.0, 7.0, false, true]],
}

## T-217: one-off landmark spots of each route (RouteLandmarks) and the rectangle they keep free of trees/rocks/signs:
##   lighthouse [z, lateral], harbour [z0, z1, lat0, lat1], beach [z0, z1, swimmers, lat0, lat1] (no keep-out),
##   waterfall [z, side], works [z0, z1, lat0, lat1] (right side, beyond the other carriageway).
const FEATURES: Dictionary = {
	"kanto_1_coast": {"lighthouse": [1880.0, 125.0], "harbour": [620.0, 760.0, 58.0, 108.0],
		"beach": [1185.0, 1265.0, 8, 43.0, 57.0]},
	"kanto_3_mountain": {"waterfall": [1140.0, -1.0], "works": [480.0, 570.0, 34.0, 46.0]},
}

var path: TrackPath
var runs: Array = []
var keep: Array = []              # [z0, z1, lat0 (signed), lat1 (signed)] rectangles of the landmarks
var fall: Array = []              # [z, side]: the waterfall bluff (a steep rocky rise of the ground behind the wall)
const BLUFF_H: float = 34.0
const BLUFF_LAT: Vector2 = Vector2(22.0, 30.0)   # the rock face goes up between these laterals
const BLUFF_HALF: float = 46.0                    # half length of the bluff along the road

static var _by_path: Dictionary = {}


static func enabled() -> bool:
	return not "--no-walls" in OS.get_cmdline_user_args()


static func of(path_: TrackPath) -> CutLayout:
	if path_ == null:
		return null
	return _by_path.get(path_.get_instance_id(), null)


static func register(c: CutLayout) -> void:
	_by_path[c.path.get_instance_id()] = c


static func clear_all() -> void:
	_by_path.clear()


func _init(path_: TrackPath, route_id: String) -> void:
	path = path_
	runs = RUNS.get(route_id, [])
	var f: Dictionary = FEATURES.get(route_id, {})
	if f.has("harbour"):
		keep.append([float(f["harbour"][0]) - 12.0, float(f["harbour"][1]) + 12.0, float(f["harbour"][2]) - 4.0, 400.0])
	if f.has("works"):
		keep.append([float(f["works"][0]) - 8.0, float(f["works"][1]) + 8.0, float(f["works"][2]) - 2.0, float(f["works"][3]) + 4.0])
	if f.has("waterfall"):
		fall = f["waterfall"]
		var sd: float = float(f["waterfall"][1])
		var a: float = sd * 14.0
		var b: float = sd * 60.0
		keep.append([float(f["waterfall"][0]) - BLUFF_HALF, float(f["waterfall"][0]) + BLUFF_HALF, minf(a, b), maxf(a, b)])


## Lateral (positive, m) of the foot of the wall on this side: behind our barrier on the left; beyond the other
## carriageway on the right.
func foot(side: float) -> float:
	if side > 0.0 and OppositeLayout.of(path) != null:
		return OppositeLayout.ROAD_OUT + OppositeLayout.BARRIER_W + GUTTER_W
	return OppositeLayout.MEDIAN_IN + GUTTER_W


## Height of the wall at z on this side (0 = no wall).
func height(z: float, side: float) -> float:
	for r in runs:
		if float(r[2]) != side or z < float(r[0]) or z > float(r[1]):
			continue
		var t0: float = (z - float(r[0])) / TAPER_M if bool(r[4]) else 1.0
		var t1: float = (float(r[1]) - z) / TAPER_M if bool(r[5]) else 1.0
		var t: float = minf(t0, t1)
		var e: float = smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
		var wobble: float = 1.0 + 0.08 * sin(z * 0.031) + 0.05 * sin(z * 0.11 + 1.3)
		return float(r[3]) * e * wobble
	return 0.0


## Lateral (positive) of the top of the wall at z.
func top(z: float, side: float) -> float:
	return foot(side) + height(z, side) * BATTER


## Ground height (above the road) behind the wall at signed lateral `lat`; 0 where there is no wall or in front
## of / under it (the wall face hides that part of the ground).
func terrace(z: float, lat: float) -> float:
	return maxf(_terrace(z, lat), bluff(z, lat))


## T-217: the waterfall bluff: the ground rises steeply (the terrain shader turns it to rock) behind the wall.
func bluff(z: float, lat: float) -> float:
	if fall.is_empty() or signf(lat) != float(fall[1]):
		return 0.0
	var dz: float = absf(z - float(fall[0]))
	if dz > BLUFF_HALF:
		return 0.0
	var along: float = 1.0 - smoothstep(BLUFF_HALF * 0.55, BLUFF_HALF, dz)
	var across: float = smoothstep(BLUFF_LAT.x, BLUFF_LAT.y, absf(lat))
	var notch: float = 1.0 - 0.18 * (1.0 - smoothstep(0.0, 9.0, dz))       # the river's notch at the lip
	return BLUFF_H * along * across * notch


func _terrace(z: float, lat: float) -> float:
	var side: float = signf(lat)
	var h: float = height(z, side)
	if h <= 0.05:
		return 0.0
	var t: float = top(z, side) + 0.6
	var d: float = absf(lat)
	if d < t:
		return 0.0
	return h + (d - t) * TERRACE_SLOPE


## (z, signed lateral) falls on the wall, its gutter or right behind its top, or on a landmark spot (no tree, sign,
## pole, rock there).
func blocks(z: float, lat: float, behind: float = 3.0) -> bool:
	for k in keep:
		if z > float(k[0]) and z < float(k[1]) and lat > float(k[2]) and lat < float(k[3]):
			return true
	var side: float = signf(lat)
	var h: float = height(z, side)
	if h <= 0.05:
		return false
	var d: float = absf(lat)
	return d > foot(side) - GUTTER_W - 0.3 and d < top(z, side) + behind


## [z0, z1] of every run (both sides): for the unique car and other one-off spots.
func spans() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for r in runs:
		out.append(Vector2(float(r[0]), float(r[1])))
	return out
