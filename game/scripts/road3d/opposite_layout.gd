class_name OppositeLayout
extends RefCounted
## T-217: the OTHER carriageway of the expressway (traffic coming the other way), on the RIGHT of the player's road
## (Japan drives on the left). Pure data, no nodes; only visual (nothing in scripts/sim/ nor in the network).
## Cross-section (metres from the centre line of the player's road, + = right):
##   13.0-13.6  our concrete barrier (RoadMesh)          13.6-16.4  median: soil strip with a hedge (sakaki/tsutsuji)
##   16.3       guard-rail of the other carriageway       16.6-27.0  other carriageway: shoulder, 2 lanes of 3.5 m,
##   27.0-27.6  outer barrier (coast: guard-rail)                     outer shoulder
## It runs along the whole drawn road (start to the end of the arrival avenue), on the same deck as ours in the city
## (twin viaduct), on a twin deck over the bridges and through its own bore in every tunnel (Tunnel3D twin bore).
## Other builders ask `OppositeLayout.of(path)` (null = no other carriageway: tests, --no-opposite) and keep their
## things out of [MEDIAN_IN, CLEAR] on the right.

const MEDIAN_IN: float = RoadMesh.BARRIER_IN + RoadMesh.BARRIER_W   # 13.6: outer face of our barrier
const HEDGE_LAT: float = 15.0
const HEDGE_W: float = 1.3
const HEDGE_H: float = 1.05
const RAIL_LAT: float = 16.3          # posts of the median guard-rail (blade on the far side, facing the other road)
const ROAD_IN: float = 16.6           # inner edge of the other asphalt
const LANE_W: float = 3.5
const LANES: int = 2
const SHOULDER_IN: float = 0.75
const LANE0: float = ROAD_IN + SHOULDER_IN                  # 17.35: first lane line (median side)
const LANE_END: float = LANE0 + LANE_W * LANES              # 24.35
const ROAD_OUT: float = 27.0          # outer edge of the asphalt (inner face of the outer barrier)
const BARRIER_W: float = 0.6
const CLEAR: float = 29.0             # beyond this the right side is free again (trees, poles, billboards, houses)
const CENTER: float = (ROAD_IN + ROAD_OUT) * 0.5            # 21.8: centre of the other carriageway (twin bore)
const SHIFT: float = CLEAR - MEDIAN_IN                      # how much right-side scenery moves out (15.4 m)

var path: TrackPath
var route_id: String = ""
var kind: StringName = &"city"
var tunnels: Array[Vector2] = []
var bridges: Array[Vector2] = []
var deck: float = 0.0

static var _by_path: Dictionary = {}  # path instance id -> OppositeLayout (registered by the race scene)


## `--no-opposite` turns the other carriageway off (before/after prints and cost measures).
static func enabled() -> bool:
	return not "--no-opposite" in OS.get_cmdline_user_args()


## The layout registered for this path (null = none).
static func of(path_: TrackPath) -> OppositeLayout:
	if path_ == null:
		return null
	return _by_path.get(path_.get_instance_id(), null)


static func register(layout: OppositeLayout) -> void:
	_by_path[layout.path.get_instance_id()] = layout


static func clear_all() -> void:
	_by_path.clear()


func _init(path_: TrackPath, route_id_: String, kind_: StringName, tunnels_: Array[Vector2] = [],
		bridges_: Array[Vector2] = []) -> void:
	path = path_
	route_id = route_id_
	kind = kind_
	tunnels = tunnels_
	bridges = bridges_
	deck = RoadMesh.deck_height(kind)


## The other carriageway exists at z (the whole drawn road).
func has(z: float) -> bool:
	return z >= 0.0 and z <= path.end_m()


## In one of the twin bores (the player's tunnel z range).
func in_tube(z: float, margin: float = 0.0) -> bool:
	return RoadMesh.in_tunnel(z, tunnels, margin)


## On a twin bridge deck (no ground under it).
func on_bridge(z: float, margin: float = 0.0) -> bool:
	return RoadMesh.in_tunnel(z, bridges, margin)


## Lateral (signed, m) inside the band taken by the median and the other carriageway at z?
func occupies(z: float, lat: float, margin: float = 0.0) -> bool:
	return has(z) and lat > MEDIAN_IN - margin and lat < CLEAR + margin


## Lane centres of the other carriageway (they drive towards -z: their left is our right, slow lane = outer one).
static func lane_center(lane: int) -> float:
	return LANE0 + LANE_W * (float(lane) + 0.5)


## Static helper for builders that only have the path: is (z, lat) free of the other carriageway?
static func free_at(path_: TrackPath, z: float, lat: float, margin: float = 0.0) -> bool:
	var o: OppositeLayout = of(path_)
	return o == null or not o.occupies(z, lat, margin)


## Right-side lateral that clears the other carriageway (unchanged when there is none).
static func push_right(path_: TrackPath, lat: float) -> float:
	if of(path_) == null or lat <= MEDIAN_IN - 0.5:
		return lat
	return lat + SHIFT
