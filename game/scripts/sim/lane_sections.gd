class_name LaneSections
extends RefCounted
## Road sections with fewer lanes (T-153): the WHOLE road narrows to 2 lanes (old tunnel, bridge, old viaduct).
## Part of the road, not a random event: the data comes from RouteDef.lane_sections and every TrackEvents list of the
## race gets them as Kind.SECTION entries (Track.events setter), so trucks, bots, traffic and the lane-change refusal
## use the SAME closure queries as the T-139 events. Pure math, no nodes.
##
## Data (RouteDef.lane_sections): {start, end, lanes: 2, taper, look}
##   start .. end      the road has 2 lanes (metres along the track)
##   taper             metres of smooth transition BEFORE start (narrows) and AFTER end (widens back)
##   look              visual only: "tunnel" | "bridge" | "old_viaduct" (the presentation picks the structure)
## Which lane ends: always the RIGHT one (lane 3, the overtaking lane on a Japanese expressway; traffic keeps left).
## The right barrier sweeps in from OPEN_WALL_M to RIGHT_WALL_M and the left one from OPEN_WALL_M to LEFT_WALL_M
## (inner faces, metres from the centre line). The painted right edge line runs ahead of the barrier (LINE_LEAD).

const OPEN_WALL_M: float = 13.0           # inner face of the normal barrier (RoadMesh.BARRIER_IN)
const RIGHT_WALL_M: float = 3.0           # 2 lanes: lane 2 ends at 1,8 m + 1,2 m right shoulder
const LEFT_WALL_M: float = 7.8            # lane 1 ends at -5,4 m + 2,4 m left shoulder (lane 0 still fits)
const EDGE_LINE_M: float = 5.15           # normal right edge line (centre)
const NARROW_LINE_M: float = 1.95         # right edge line in the section (just right of the old 2/3 lane line)
const DEFAULT_TAPER_M: float = 150.0
const MIN_TAPER_M: float = 60.0
const MAX_TAPER_M: float = 400.0
const MIN_LENGTH_M: float = 60.0          # minimum 2-lane length (start .. end)
const LINE_LEAD: float = 0.8              # the painted line finishes its taper at 80% of it (before the barrier)
const M: float = Track.ROAD_HALF_WIDTH_M
const OPEN_X: float = OPEN_WALL_M / M
const RIGHT_X: float = RIGHT_WALL_M / M
const LEFT_X: float = LEFT_WALL_M / M


## RouteDef entry -> TrackEvents entry {kind: "section", z, length, lanes: [3], taper}. {} if invalid.
static func to_event(d: Dictionary) -> Dictionary:
	var start: float = float(d.get("start", 0.0))
	var end_: float = float(d.get("end", 0.0))
	var lanes: int = int(d.get("lanes", 2))
	if lanes != 2 or end_ - start < MIN_LENGTH_M:
		return {}                                  # only 3 -> 2 lanes (never closes a 2nd lane)
	var taper: float = clampf(float(d.get("taper", DEFAULT_TAPER_M)), MIN_TAPER_M, MAX_TAPER_M)
	return {"kind": "section", "z": start - taper, "length": end_ - start + taper, "lanes": [Lanes.LAST],
		"taper": taper, "fixed": true, "look": String(d.get("look", ""))}


## Right closure (Lanes units) at closure fraction f: the barrier face.
static func right_x(f: float) -> float:
	return lerpf(OPEN_X, RIGHT_X, f)


## Left barrier face (Lanes units, negative) at closure fraction f.
static func left_x(f: float) -> float:
	return -lerpf(OPEN_X, LEFT_X, f)


## 0..1 of the painted right edge line (0 = normal 5,15 m, 1 = narrow 1,95 m): ahead of the barrier when narrowing,
## behind it when widening back.
static func line_f(ev: TrackEvents.Event, zz: float) -> float:
	if zz <= ev.z or zz >= ev.reopen_end():
		return 0.0
	if zz < ev.full_z():
		return smoothstep(0.0, 1.0, clampf((zz - ev.z) / (ev.taper * LINE_LEAD), 0.0, 1.0))
	if zz <= ev.end_z():
		return 1.0
	var u: float = (zz - ev.end_z()) / ev.reopen
	return 1.0 - smoothstep(0.0, 1.0, clampf((u - (1.0 - LINE_LEAD)) / LINE_LEAD, 0.0, 1.0))


## Road profile at zz for the presentation: Vector3(left barrier face (m, > 0), right barrier face (m), right edge
## line centre (m)). Without sections: (13, 13, 5,15).
static func profile(evs: TrackEvents, zz: float) -> Vector3:
	var out := Vector3(OPEN_WALL_M, OPEN_WALL_M, EDGE_LINE_M)
	if evs == null:
		return out
	for ev in evs.list:
		if ev.kind != TrackEvents.Kind.SECTION or zz < ev.z or zz > ev.reopen_end():
			continue
		var f: float = evs.closure(ev, zz)
		out.x = minf(out.x, -left_x(f) * M)
		out.y = minf(out.y, right_x(f) * M)
		out.z = minf(out.z, lerpf(EDGE_LINE_M, NARROW_LINE_M, line_f(ev, zz)))
	return out


## Section (event) whose zone (taper .. reopen, with `margin`) contains zz, or null.
static func at(evs: TrackEvents, zz: float, margin: float = 0.0) -> TrackEvents.Event:
	if evs == null:
		return null
	for ev in evs.list:
		if ev.kind == TrackEvents.Kind.SECTION and zz >= ev.z - margin and zz <= ev.reopen_end() + margin:
			return ev
	return null


## Road lanes open at zz (3, or 2 where the right lane is gone: a truck in it would touch the barrier).
static func lanes_at(evs: TrackEvents, zz: float) -> int:
	if evs == null:
		return 3
	for ev in evs.list:
		if ev.kind == TrackEvents.Kind.SECTION and zz >= ev.block_z[Lanes.LAST] and zz <= ev.clear_z[Lanes.LAST]:
			return 2
	return 3


## Validated copy of RouteDef.lane_sections / the race setup (network): only the known keys, as floats.
static func sanitize(a: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d in a:
		if d is Dictionary and not to_event(d).is_empty():
			out.append({"start": float(d["start"]), "end": float(d["end"]), "lanes": 2,
				"taper": clampf(float(d.get("taper", DEFAULT_TAPER_M)), MIN_TAPER_M, MAX_TAPER_M),
				"look": String(d.get("look", ""))})
	return out
