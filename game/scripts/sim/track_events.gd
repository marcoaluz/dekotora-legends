class_name TrackEvents
extends RefCounted
## Track events (C4 / T-139): accident, road works and lane narrowing (3 -> 2 lanes). Pure data and queries,
## no nodes: the same list runs on the server, on the clients and in the presentation.
##
## Each event closes a CONTIGUOUS block of road lanes (never the 3). Along z:
##   z .. z + TAPER_M[kind]          taper: the closed area grows from an anchor (asphalt edge, or the lane centre
##                                   for a middle lane) to the full width (cones / the lane end gets narrower)
##   z + TAPER_M .. z + length       full closure (accident vehicles, works truck + barricades, or the lane is gone)
##   narrow only: + REOPEN_M         the road widens back smoothly
## The closed area at a given z is an x interval (Lanes units); an outer closure also closes the shoulder.
## Warning signs and the HUD alert start WARN_M before z.
## Fixed events come from RouteDef.events; random ones are rolled from the race seed (server rolls online and sends
## the list in the race setup, see to_array/from_array).
## T-153: Kind.SECTION = a road section with 2 lanes (LaneSections): part of the road, added to every list from
## Track.lane_sections (never sent in `events`, never random). Its taper/reopen lengths come from the data.

enum Kind { ACCIDENT, WORKS, NARROW, SECTION }
const KIND_IDS: Array[String] = ["accident", "works", "narrow", "section"]
const TAPER_M: Array[float] = [45.0, 60.0, 120.0, LaneSections.DEFAULT_TAPER_M]
const REOPEN_M: Array[float] = [0.0, 0.0, 80.0, LaneSections.DEFAULT_TAPER_M]
const MIN_FULL_M: Array[float] = [50.0, 60.0, 120.0, LaneSections.MIN_LENGTH_M]   # minimum full-closure length after the taper
const WARN_M: float = 400.0
const OUTER: float = 2.0                  # beyond the physical limit (|x| <= 1,6): outer closures take the shoulder too
const EDGE: float = Lanes.ASPHALT_EDGE    # anchor of an outer taper (asphalt edge)
const SCAN_M: float = 1.0                 # resolution of the per-lane block/clear z tables
const BODY_HALF: float = TruckSim.WIDTH_X * 0.5   # a lane counts as closed once a truck in it would touch the closure
# random events (RouteDef.random_events / random_chance)
const RANDOM_MIN_Z: float = 650.0         # after the toll gate and the start
const RANDOM_END_GAP: float = 350.0       # keep the last metres before the finish free
const RANDOM_GAP_M: float = 200.0         # free road between one event (end) and the next warning
const RANDOM_SHARP: float = 1.25          # no random event in the tightest curves (the mountain still gets some)
const SECTION_GAP_M: float = 120.0        # T-153: free road between a random event and a 2-lane section zone (its signs skip the section)
# road works: steel plates on the open lanes along the full closure (EventContact.truck)
const WORKS_LIMIT_KMH: float = 60.0       # posted limit beside the works
const LIMIT_TOL_KMH: float = 5.0          # above limit + tolerance the plates shake the cargo
# deadline allowance (s) per event, measured with tools_dev/measure_event_times.gd (mean loss of the HARD bots)
const ALLOWANCE_S: Array[float] = [3.0, 7.0, 3.0, 0.0]   # accident (1 lane), works (60 km/h limit), narrow, section (part of the route)
const ALLOWANCE_TWO_LANES_S: float = 8.0           # accident or works closing 2 lanes


class Event:
	extends RefCounted
	var kind: int = Kind.WORKS
	var z: float = 0.0                    # taper start
	var length: float = 200.0             # taper + full closure
	var lo: int = Lanes.LAST              # closed road lanes lo..hi (Lanes indices)
	var hi: int = Lanes.LAST
	var fixed: bool = true                # from the route (false = rolled by the seed)
	var taper: float = 0.0                # m of taper (TAPER_M[kind]; sections: from the data)
	var reopen: float = 0.0               # m of reopening after end_z (REOPEN_M[kind]; sections: = taper)
	var look: String = ""                 # sections: visual structure (LaneSections)
	var block_z: PackedFloat32Array = PackedFloat32Array()   # per lane 0..4: first z where a truck in that lane would touch the closure (INF = never)
	var clear_z: PackedFloat32Array = PackedFloat32Array()   # per lane: z where it is open again

	func full_z() -> float:
		return z + taper

	func end_z() -> float:
		return z + length

	func reopen_end() -> float:
		return end_z() + reopen

	## Side of the closure: +1 right (touches lane 3), -1 left (touches lane 1), 0 middle lane only.
	func side() -> int:
		if hi == Lanes.LAST and lo > Lanes.FIRST:
			return 1
		if lo == Lanes.FIRST and hi < Lanes.LAST:
			return -1
		return 0

	## Extra deadline (s) this event gives (TrackEvents.time_allowance).
	func allowance() -> float:
		return ALLOWANCE_TWO_LANES_S if hi > lo else ALLOWANCE_S[kind]

	func closes(lane: int) -> bool:
		return lane >= lo and lane <= hi

	func to_dict() -> Dictionary:
		var lanes: Array[int] = []
		for l in range(lo, hi + 1):
			lanes.append(l)
		return {"kind": KIND_IDS[kind], "z": z, "length": length, "lanes": lanes, "fixed": fixed}


var list: Array[Event] = []
## T-207: toll plaza of the route (part of the road, like the sections; attached by the Track.events setter). Never in
## `list` (indices of the events stay the same) and never sent in `events`: the route alone defines it.
var toll: TollPlaza = null


func is_empty() -> bool:
	return list.is_empty() and toll == null


## Adds an event from a dictionary {kind, z, length, lanes:[Lanes indices]}. Invalid ones (3 lanes, not contiguous,
## too short) are ignored and return null.
func add(d: Dictionary) -> Event:
	var kind: int = KIND_IDS.find(String(d.get("kind", "works")))
	if kind < 0:
		return null
	var lanes: Array = d.get("lanes", [Lanes.LAST])
	if lanes.is_empty():
		return null
	var lo: int = Lanes.LAST
	var hi: int = Lanes.FIRST
	for l in lanes:
		lo = mini(lo, int(l))
		hi = maxi(hi, int(l))
	if lo < Lanes.FIRST or hi > Lanes.LAST or hi - lo + 1 != lanes.size() or hi - lo >= 2:
		return null                                   # never all 3 lanes: there is always a way out
	if kind == Kind.NARROW and lo != hi or kind == Kind.NARROW and lo == Lanes.CENTER:
		return null                                   # narrowing: one OUTER lane ends
	if kind == Kind.SECTION and (lo != Lanes.LAST or hi != Lanes.LAST):
		return null                                   # 2-lane section: the right lane ends (LaneSections)
	var ev := Event.new()
	ev.kind = kind
	ev.z = float(d.get("z", 0.0))
	ev.taper = TAPER_M[kind]
	ev.reopen = REOPEN_M[kind]
	if kind == Kind.SECTION:
		ev.taper = clampf(float(d.get("taper", ev.taper)), LaneSections.MIN_TAPER_M, LaneSections.MAX_TAPER_M)
		ev.reopen = ev.taper
		ev.look = String(d.get("look", ""))
	ev.length = maxf(float(d.get("length", 0.0)), ev.taper + MIN_FULL_M[kind])
	ev.lo = lo
	ev.hi = hi
	ev.fixed = bool(d.get("fixed", true))
	_scan(ev)
	list.append(ev)
	list.sort_custom(func(a: Event, b: Event) -> bool: return a.z < b.z)
	return ev


## 0..1: how closed the event is at `zz` (taper and reopening are smooth: no step in the road).
func closure(ev: Event, zz: float) -> float:
	if zz < ev.z or zz > ev.reopen_end():
		return 0.0
	if zz < ev.full_z():
		return smoothstep(0.0, 1.0, (zz - ev.z) / ev.taper)
	if zz <= ev.end_z():
		return 1.0
	return 1.0 - smoothstep(0.0, 1.0, (zz - ev.end_z()) / maxf(ev.reopen, 0.001))


## Closed x interval at `zz` (Lanes units). x > y means nothing is closed there.
func interval(ev: Event, zz: float) -> Vector2:
	var f: float = closure(ev, zz)
	if f <= 0.0:
		return Vector2(1.0, -1.0)
	if ev.kind == Kind.SECTION:                       # the right barrier moves in (LaneSections)
		return Vector2(LaneSections.right_x(f), OUTER)
	var xa: float = -OUTER if ev.lo == Lanes.FIRST else Lanes.X[ev.lo] - Lanes.SPACING * 0.5
	var xb: float = OUTER if ev.hi == Lanes.LAST else Lanes.X[ev.hi] + Lanes.SPACING * 0.5
	var s: int = ev.side()
	var anchor: float = EDGE * float(s) if s != 0 else (xa + xb) * 0.5
	if xa > -OUTER:
		xa = lerpf(anchor, xa, f)
	if xb < OUTER:
		xb = lerpf(anchor, xb, f)
	return Vector2(xa, xb)


## Is [x0, x1] (Lanes units) touching a closed area at `zz`? Returns the event or null.
func blocked_at(x0: float, x1: float, zz: float) -> Event:
	for ev in list:
		var iv: Vector2 = interval(ev, zz)
		if iv.x <= iv.y and x1 > iv.x and x0 < iv.y:
			return ev
	return null


## T-207: [x0, x1] touching the toll plaza (island or outer barriers) at zz?
func toll_blocked_at(x0: float, x1: float, zz: float) -> bool:
	return toll != null and toll.blocked_at(x0, x1, zz)


## Lane `lane` (centre) closed somewhere in [z0, z1]? (events, sections and the toll plaza of T-207)
func lane_blocked_between(lane: int, z0: float, z1: float) -> bool:
	for ev in list:
		if ev.block_z[lane] <= z1 and ev.clear_z[lane] >= z0:
			return true
	return toll != null and toll.lane_blocked_between(lane, z0, z1)


## First z >= from_z (within `within` m) where the centre of `lane` is closed; INF if none.
func next_block(lane: int, from_z: float, within: float) -> float:
	var best: float = INF
	for ev in list:
		if ev.clear_z[lane] >= from_z and ev.block_z[lane] <= from_z + within:
			best = minf(best, maxf(ev.block_z[lane], from_z))
	if toll != null:
		best = minf(best, toll.next_block(lane, from_z, within))
	return best


## Closest road lane to `lane` that is open in [z0, z1] (prefers the nearer one, then the left one). -1 if none.
func nearest_open_lane(lane: int, z0: float, z1: float) -> int:
	for d in [0, 1, 2]:
		for l in [lane - d, lane + d]:
			if Lanes.is_road_lane(l) and not lane_blocked_between(l, z0, z1):
				return l
	return -1


## Next event whose closure (or warning) is ahead of / under `z` within `ahead` m. null if none.
func next_event(z: float, ahead: float = WARN_M) -> Event:
	for ev in list:
		if ev.reopen_end() >= z and ev.z <= z + ahead:
			return ev
	return null


## Road narrowing for the road mesh: metres the asphalt edge moved inward on `side` (-1 left, +1 right) at `zz`.
func edge_cut_m(zz: float, side: int) -> float:
	var cut: float = 0.0
	for ev in list:
		if ev.kind != Kind.NARROW or (ev.lo == Lanes.FIRST) != (side < 0):
			continue
		var iv: Vector2 = interval(ev, zz)
		if iv.x > iv.y:
			continue
		var inner: float = iv.x if side > 0 else -iv.y
		cut = maxf(cut, (EDGE - inner) * Track.ROAD_HALF_WIDTH_M)
	return clampf(cut, 0.0, Lanes.SPACING * Track.ROAD_HALF_WIDTH_M)


## Works speed limit (m/s) for a vehicle from `rear_z` to `nose_z`: beside the full closure of road works. INF = none.
func limit_at(rear_z: float, nose_z: float) -> float:
	for ev in list:
		if ev.kind == Kind.WORKS and nose_z > ev.full_z() and rear_z < ev.end_z():
			return WORKS_LIMIT_KMH / 3.6
	return INF


## Highest speed (m/s) a vehicle with its nose at `nose_z` may have now to be at `limit` when it reaches the works,
## braking at `decel`. INF = no works ahead within `look` m.
func limit_ahead(rear_z: float, nose_z: float, look: float, decel: float, limit: float) -> float:
	var best: float = INF
	for ev in list:
		if ev.kind != Kind.WORKS or rear_z >= ev.end_z() or ev.full_z() - nose_z > look:
			continue
		var d: float = maxf(ev.full_z() - nose_z, 0.0)
		best = minf(best, sqrt(limit * limit + 2.0 * decel * d))
	return best


## Extra deadline (s) for these events (the prize deadline stretches: the client knows about the accident/works).
func time_allowance() -> float:
	var s: float = 0.0
	for ev in list:
		s += ev.allowance()
	return s


## Is z inside any event zone (warning included)? Used to keep paint/markings out of the closures.
func zone_at(zz: float, margin: float = 0.0) -> Event:
	for ev in list:
		if zz >= ev.z - margin and zz <= ev.reopen_end() + margin:
			return ev
	return null


func _scan(ev: Event) -> void:
	ev.block_z.resize(Lanes.X.size())
	ev.clear_z.resize(Lanes.X.size())
	for lane in Lanes.X.size():
		var first: float = INF
		var last: float = -INF
		var zz: float = ev.z
		while zz <= ev.reopen_end():
			var iv: Vector2 = interval(ev, zz)
			if iv.x <= iv.y and Lanes.X[lane] + BODY_HALF > iv.x and Lanes.X[lane] - BODY_HALF < iv.y:
				first = minf(first, zz)
				last = zz
			zz += SCAN_M
		ev.block_z[lane] = first
		ev.clear_z[lane] = last if first < INF else -INF


# ---------------------------------------------------------------- network / setup
func to_array() -> Array:
	var out: Array = []
	for ev in list:
		if ev.kind != Kind.SECTION:                   # sections go in the setup as `lane_sections` (the road)
			out.append(ev.to_dict())
	return out


## Replaces the 2-lane sections of this list (T-153: Track.lane_sections, RouteDef format {start, end, lanes, taper}).
func set_sections(sections: Array) -> void:
	var keep: Array[Event] = []
	for ev in list:
		if ev.kind != Kind.SECTION:
			keep.append(ev)
	list = keep
	for d in sections:
		var e: Dictionary = LaneSections.to_event(d)
		if not e.is_empty():
			add(e)


## Only 2-lane sections (or nothing): no warning, cone or works event in the list.
func only_sections() -> bool:
	for ev in list:
		if ev.kind != Kind.SECTION:
			return false
	return true


static func from_array(a: Array) -> TrackEvents:
	var evs := TrackEvents.new()
	for d in a:
		if d is Dictionary:
			evs.add(d)
	return evs


# ---------------------------------------------------------------- roll (fixed + random by seed)
## Fixed events of the route plus `slots` random ones (each with `chance`), deterministic for `seed_`.
## `avoid` = z ranges (Vector2 start, length) where no random event may fall (tunnels).
static func roll(fixed: Array[Dictionary], track: Track, seed_: int, slots: int, chance: float,
		avoid: Array[Vector2] = []) -> TrackEvents:
	var evs := TrackEvents.new()
	evs.set_sections(track.lane_sections)              # T-153: random events never fall on a 2-lane section
	for d in fixed:
		evs.add(d)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for s in slots:
		var hit: bool = rng.randf() < chance
		var kind: int = rng.randi_range(0, 2)
		var lanes: Array = _random_lanes(rng, kind)
		var length: float = TAPER_M[kind] + MIN_FULL_M[kind] + rng.randf_range(0.0, 120.0 if kind == Kind.NARROW else 70.0)
		var z: float = -1.0
		for attempt in 12:                                 # same number of draws every time (determinism)
			var cand: float = rng.randf_range(RANDOM_MIN_Z, track.length_m - RANDOM_END_GAP - length - REOPEN_M[kind])
			if z < 0.0 and _free_spot(evs, track, cand, length + REOPEN_M[kind], avoid):
				z = roundf(cand)
		if hit and z > 0.0:
			evs.add({"kind": KIND_IDS[kind], "z": z, "length": roundf(length), "lanes": lanes, "fixed": false})
	return evs


static func _random_lanes(rng: RandomNumberGenerator, kind: int) -> Array:
	var r: float = rng.randf()
	if kind == Kind.NARROW:
		return [Lanes.FIRST] if r < 0.5 else [Lanes.LAST]
	if r < 0.25:                                           # two lanes (outer pair): one lane left open
		return [Lanes.FIRST, Lanes.CENTER] if rng.randf() < 0.5 else [Lanes.CENTER, Lanes.LAST]
	if kind == Kind.ACCIDENT and r < 0.5:
		return [Lanes.CENTER]
	return [Lanes.FIRST] if r < 0.75 else [Lanes.LAST]


static func _free_spot(evs: TrackEvents, track: Track, z: float, span: float, avoid: Array[Vector2]) -> bool:
	if z < RANDOM_MIN_Z or z + span > track.length_m - RANDOM_END_GAP:
		return false
	var from: float = z - WARN_M
	for t in avoid:
		if z + span > t.x - 60.0 and z - 120.0 < t.x + t.y + 60.0:
			return false
	for ev in evs.list:
		if ev.kind == Kind.SECTION:                    # T-153: the road itself; only the zones must not touch
			if z + span + SECTION_GAP_M > ev.z and z - SECTION_GAP_M < ev.reopen_end():
				return false
			continue
		if z + span + RANDOM_GAP_M > ev.z - WARN_M and from - RANDOM_GAP_M < ev.reopen_end():
			return false
	var zz: float = z - 150.0
	while zz < z + span:
		if absf(track.curve_at(zz)) >= RANDOM_SHARP:
			return false
		zz += 10.0
	return true
