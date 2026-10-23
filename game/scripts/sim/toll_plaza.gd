class_name TollPlaza
extends RefCounted
## Toll plaza of the route (T-207): the road splits in TWO passages around a centre island with the booth and joins
## again after it. Part of the road (like the 2-lane sections of T-153), not a random event: RouteDef.build_track
## places it at DEFAULT_Z (the old decorative "toll_gate" of Track.decorate_roadside) on every route, so the server,
## the clients and the presentation build the SAME plaza from the route alone (nothing new in the race setup).
## Pure geometry, no nodes. The physics is in TollContact; avoidance (bots, traffic, lane-change refusal, shoves)
## comes for free through the TrackEvents queries (TrackEvents.toll).
##
## Along z (metres, c = booth centre):
##   c - NOSE_M - FUNNEL_M .. c - NOSE_M   the outer barriers sweep in from the normal barrier (13 m) to OUTER_FACE_M
##                                         (the shoulders end: whoever is on them must merge into the passage)
##   c - NOSE_M - GORE_M .. c - NOSE_M     painted zebra in the middle lane (visual only: no physics)
##   c - NOSE_M .. c + TAIL_M              centre island (|x| < ISLAND_HALF_M) = HARD, like a stopped vehicle;
##                                         outer islands from OUTER_FACE_M outwards
##   c + TAIL_M .. c + TAIL_M + FUNNEL_M   the outer barriers open again (painted zebra REJOIN_M after the tail)
## Lateral (metres from the centre line): passage = ISLAND_HALF_M .. OUTER_FACE_M on each side (3,8 m). Lanes 1 and 3
## (centres at -/+3,6 m, a 2,5 m truck) always fit; lane 2 is the island; the shoulder lanes 0/4 end at the funnel.

const DEFAULT_Z: float = 150.0             # booth centre (= the "toll_gate" object of Track.decorate_roadside)
const ISLAND_HALF_M: float = 1.8           # centre island faces (the whole middle lane)
const OUTER_FACE_M: float = 5.6            # inner face of the outer islands
const OPEN_FACE_M: float = LaneSections.OPEN_WALL_M    # 13 m: the normal barrier face (no wall inside the road)
const NOSE_M: float = 18.0                 # island nose this far before the booth centre
const TAIL_M: float = 14.0                 # island tail this far after it
const FUNNEL_M: float = 60.0               # outer barriers: length of the sweep in (before the nose) and out (after the tail)
const GORE_M: float = 55.0                 # zebra before the nose (the middle lane closes as paint first)
const REJOIN_M: float = 30.0               # zebra after the tail
const SCAN_M: float = 1.0                  # resolution of the per-lane block tables
const M: float = Track.ROAD_HALF_WIDTH_M

var z: float = DEFAULT_Z
var block_z: PackedFloat32Array = PackedFloat32Array()   # per lane 0..4: first z where a truck in that lane touches (INF = never)
var clear_z: PackedFloat32Array = PackedFloat32Array()   # per lane: last such z


func _init(z_: float = DEFAULT_Z) -> void:
	z = z_
	_scan()


func nose_z() -> float:
	return z - NOSE_M


func tail_z() -> float:
	return z + TAIL_M


## First z with anything of the plaza in the road (outer funnel start).
func zone_start() -> float:
	return nose_z() - FUNNEL_M


## Last z with anything of the plaza in the road (outer funnel end).
func zone_end() -> float:
	return tail_z() + FUNNEL_M


func island_half_x() -> float:
	return ISLAND_HALF_M / M


## Is zz on the centre island (nose .. tail)?
func island_at(zz: float) -> bool:
	return zz >= nose_z() and zz <= tail_z()


## 0..1: how far in the outer barriers are at zz (0 = normal barrier, 1 = outer island face). Smooth (no step).
func funnel(zz: float) -> float:
	var n: float = nose_z()
	var t: float = tail_z()
	if zz <= n - FUNNEL_M or zz >= t + FUNNEL_M:
		return 0.0
	if zz < n:
		return smoothstep(0.0, 1.0, (zz - (n - FUNNEL_M)) / FUNNEL_M)
	if zz <= t:
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (zz - t) / FUNNEL_M)


## Outer barrier face at zz, metres from the centre line (same on both sides).
func outer_face_m(zz: float) -> float:
	return lerpf(OPEN_FACE_M, OUTER_FACE_M, funnel(zz))


func outer_face_x(zz: float) -> float:
	return outer_face_m(zz) / M


## Tightest outer face (x units) over a body from `rear` to rear + `length` (rear, middle, nose).
func outer_limit_x(rear: float, length: float) -> float:
	var lim: float = INF
	for zz in [rear, rear + length * 0.5, rear + length]:
		lim = minf(lim, outer_face_x(zz))
	return lim


## 0..1 of the painted zebra in the middle lane at zz (visual): grows to the nose, shrinks after the tail.
func gore(zz: float) -> float:
	var n: float = nose_z()
	var t: float = tail_z()
	if zz <= n - GORE_M or zz >= t + REJOIN_M:
		return 0.0
	if zz < n:
		return (zz - (n - GORE_M)) / GORE_M
	if zz <= t:
		return 1.0
	return 1.0 - (zz - t) / REJOIN_M


## Is [x0, x1] (x units) touching the plaza (island or outer barriers) at zz?
func blocked_at(x0: float, x1: float, zz: float) -> bool:
	if zz < zone_start() or zz > zone_end():
		return false
	var face: float = outer_face_x(zz)
	if x1 > face or x0 < -face:
		return true
	var ih: float = island_half_x()
	return island_at(zz) and x1 > -ih and x0 < ih


## Lane (Lanes index, centre) closed somewhere in [z0, z1]: a truck in it would touch the island or the outer barrier.
func lane_blocked_between(lane: int, z0: float, z1: float) -> bool:
	return block_z[lane] <= z1 and clear_z[lane] >= z0


## First z >= from_z (within `within` m) where `lane` is closed; INF if none.
func next_block(lane: int, from_z: float, within: float) -> float:
	if clear_z[lane] >= from_z and block_z[lane] <= from_z + within:
		return maxf(block_z[lane], from_z)
	return INF


## Passage (Lanes.FIRST or Lanes.LAST) on the side of x: left of the centre = the left passage. Exactly 0 = left
## (keep left, Japanese rule). Deterministic.
static func passage_for(x: float) -> int:
	return Lanes.FIRST if x <= 0.0 else Lanes.LAST


func _scan() -> void:
	var half: float = TruckSim.WIDTH_X * 0.5
	block_z.resize(Lanes.X.size())
	clear_z.resize(Lanes.X.size())
	for lane in Lanes.X.size():
		var first: float = INF
		var last: float = -INF
		var zz: float = zone_start()
		while zz <= zone_end():
			if blocked_at(Lanes.X[lane] - half, Lanes.X[lane] + half, zz):
				first = minf(first, zz)
				last = zz
			zz += SCAN_M
		block_z[lane] = first
		clear_z[lane] = last if first < INF else -INF
