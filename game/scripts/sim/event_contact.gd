class_name EventContact
extends RefCounted
## Physical side of the track events (T-139): keeps trucks and traffic out of the closed areas. Pure math.
## Positions and speeds change here (so the client prediction does the same); damage and cargo are applied by
## RaceSim from the contact returned for each truck (server / offline only).
##  - cones (taper of an accident or works): soft. Every CONE_EVERY_M driven through them = one cone hit:
##    a little speed and a cargo touch (cargo loss rule of T-102).
##  - vehicles / barricades (full closure): hard. The nose reaching the block is a crash against a STOPPED
##    vehicle (DamageModel with OBSTACLE_MASS, like hitting traffic): the truck cannot pass, drops to
##    BLOCKED_SPEED, its target lane becomes the nearest open one and it slides out sideways.
##    Pushed into the block from the side: pushed back out with a side hit. A truck whose lane is OPEN and that only
##    overlaps the edge (curve slide, a push) grazes: pushed back into its lane, cargo touch, no crash.
##  - lane end (narrowing): a wall that moves in with the taper; the truck scrapes along it (speed + cargo touch)
##    and, once the centre of its lane is gone, its target lane becomes the open neighbour: it MUST merge
##    (whoever is beside it disputes the gap through the normal truck collision).
##  - steel plates (road works, beside the full closure): above TrackEvents.WORKS_LIMIT_KMH + tolerance, every
##    PLATE_EVERY s the cargo shakes (cargo_hit by the excess speed). No damage to the truck.

const CONE_EVERY_M: float = 5.0
const CONE_SLOW: float = 0.7            # m/s lost per cone
const OBSTACLE_MASS: float = 1500.0     # kg: a stopped car / small works truck
const BLOCKED_SPEED: float = 6.0        # m/s: max speed while the nose is against the block
const HIT_COOLDOWN: float = 1.5         # s: one hard hit per crash (then it only scrapes out)
const WALL_DECEL: float = 3.0           # m/s^2 while scraping the lane end
const SCRAPE_EVERY: float = 0.8         # s between cargo touches while scraping
const SIDE_MIN_DV: float = 1.5          # m/s: lateral speed that counts as a side hit
const WALL_PUSH: float = 2.0            # x/s: how fast the lane end pushes a vehicle in (no teleport at the taper start)
const GRAZE_X: float = 0.12            # x (0,86 m): a truck in an OPEN lane overlapping less than this only grazes the block
const PLATE_EVERY: float = 0.5          # s between cargo shakes on the works steel plates above the limit
const PLATE_CARGO: float = 0.25         # cargo_hit(dv) factor per shake (dv = m/s above limit + tolerance)


## Applies the closures to truck `t` (call at the end of TruckSim.step). Returns {} or
## {kind: cone|scrape|obstacle, zone, dv, event} for RaceSim to turn into damage and an event.
static func truck(evs: TrackEvents, t: TruckSim, dt: float) -> Dictionary:
	var out: Dictionary = {}
	var half: float = TruckSim.WIDTH_X * 0.5
	var nose: float = t.z + t.length
	t.scrape_t = maxf(t.scrape_t - dt, 0.0)
	t.hit_t = maxf(t.hit_t - dt, 0.0)
	var touching_cones: bool = false
	for k in evs.list.size():
		var ev: TrackEvents.Event = evs.list[k]
		if nose < ev.z or t.z > ev.reopen_end():
			continue
		if ev.kind == TrackEvents.Kind.NARROW:
			var s: int = ev.side()
			var lim: float = _wall_limit(evs, ev, t.z, t.length, s)
			if is_finite(lim):
				var over: float = (t.x + half - lim) if s > 0 else (lim - (t.x - half))
				if over > 0.0:
					t.x -= minf(over, WALL_PUSH * dt) * float(s)
					if t.lateral_vel * float(s) > 0.0:
						t.lateral_vel = 0.0
					t.speed = maxf(t.speed - WALL_DECEL * dt, 0.0)
					if t.scrape_t <= 0.0 and t.speed > 3.0:
						t.scrape_t = SCRAPE_EVERY
						out = {"kind": "scrape", "zone": "right" if s > 0 else "left", "dv": 0.0, "event": k}
			var iv: Vector2 = evs.interval(ev, nose)
			if iv.x <= iv.y and Lanes.X[t.lane] >= iv.x and Lanes.X[t.lane] <= iv.y:
				var nl: int = t.lane
				while nl >= Lanes.SHOULDER_L and nl <= Lanes.SHOULDER_R and Lanes.X[nl] >= iv.x and Lanes.X[nl] <= iv.y:
					nl -= s
				t.lane = clampi(nl, Lanes.FIRST, Lanes.LAST)     # the lane is gone: merge into the open one
				t.signal_dir = 0
			continue
		var full: float = ev.full_z()
		if ev.kind == TrackEvents.Kind.WORKS and nose > full and t.z < ev.end_z():   # steel plates beside the works
			var over: float = t.speed - (TrackEvents.WORKS_LIMIT_KMH + TrackEvents.LIMIT_TOL_KMH) / 3.6
			if over > 0.0:
				t.plate_t -= dt
				if t.plate_t <= 0.0:
					t.plate_t = PLATE_EVERY
					out = {"kind": "plates", "zone": "rear", "dv": over, "event": k}
			else:
				t.plate_t = 0.0
		if nose > ev.z and t.z < full:                       # taper: cones under the nose
			var ivc: Vector2 = evs.interval(ev, minf(nose, full))
			if t.x + half > ivc.x and t.x - half < ivc.y:
				touching_cones = true
				t.cone_m += t.speed * dt
				if t.cone_m >= CONE_EVERY_M:
					t.cone_m -= CONE_EVERY_M
					t.speed = maxf(t.speed - CONE_SLOW, 0.0)
					out = {"kind": "cone", "zone": "front", "dv": CONE_SLOW, "event": k}
		if nose > full and t.z < ev.end_z():
			var ivb: Vector2 = evs.interval(ev, full + 0.5)
			if t.x + half > ivb.x and t.x - half < ivb.y:
				var lane_open: bool = Lanes.X[t.lane] < ivb.x or Lanes.X[t.lane] > ivb.y
				var graze: bool = lane_open and minf(t.x + half, ivb.y) - maxf(t.x - half, ivb.x) < GRAZE_X
				var c: Dictionary = _graze(ivb, t, half) if graze else _block(evs, ev, ivb, t, nose - full, half)
				if not c.is_empty():
					c["event"] = k
					out = c
	if not touching_cones:
		t.cone_m = CONE_EVERY_M                             # the first cone touched counts at once
	return out


## Truck overlapping the full block: frontal (nose just arrived) or pushed in from the side.
static func _block(evs: TrackEvents, ev: TrackEvents.Event, iv: Vector2, t: TruckSim, depth: float, half: float) -> Dictionary:
	var exit_left: bool = iv.y >= TrackEvents.OUTER or (iv.x > -TrackEvents.OUTER and t.x < (iv.x + iv.y) * 0.5)
	if depth < t.length * 0.5:
		var out: Dictionary = {}
		if t.hit_t <= 0.0:
			t.hit_t = HIT_COOLDOWN
			out = {"kind": "obstacle", "zone": "front", "dv": t.speed}
		t.z = ev.full_z() - t.length                        # it does not pass through the stopped vehicle
		t.speed = minf(t.speed, BLOCKED_SPEED)
		var nl: int = evs.nearest_open_lane(t.lane, ev.z, ev.end_z())
		if nl >= 0 and nl != t.lane:
			t.lane = nl
			t.signal_dir = 0
		return out
	var dv: float = absf(t.lateral_vel) * Collision.M_X
	t.x = (iv.x - half) if exit_left else (iv.y + half)
	t.lateral_vel = 0.0
	if t.scrape_t > 0.0:
		return {}
	t.scrape_t = SCRAPE_EVERY
	var zone: String = "right" if exit_left else "left"     # the block is on that side of the truck
	if dv > SIDE_MIN_DV:
		return {"kind": "obstacle", "zone": zone, "dv": dv}
	return {"kind": "scrape", "zone": zone, "dv": 0.0}


## Open-lane truck touching the edge of the block: back into its lane, a scrape (cargo touch), no damage.
static func _graze(iv: Vector2, t: TruckSim, half: float) -> Dictionary:
	var exit_left: bool = iv.y >= TrackEvents.OUTER or (iv.x > -TrackEvents.OUTER and t.x < (iv.x + iv.y) * 0.5)
	t.x = (iv.x - half) if exit_left else (iv.y + half)
	if t.lateral_vel * (1.0 if exit_left else -1.0) > 0.0:
		t.lateral_vel = 0.0
	if t.scrape_t > 0.0:
		return {}
	t.scrape_t = SCRAPE_EVERY
	return {"kind": "scrape", "zone": "right" if exit_left else "left", "dv": 0.0}


## Tightest inner bound of the narrowing over the truck body (rear, middle, nose). INF/-INF if open.
static func _wall_limit(evs: TrackEvents, ev: TrackEvents.Event, z: float, length: float, s: int) -> float:
	var lim: float = INF if s > 0 else -INF
	for zz in [z, z + length * 0.5, z + length]:
		var iv: Vector2 = evs.interval(ev, zz)
		if iv.x <= iv.y:
			lim = minf(lim, iv.x) if s > 0 else maxf(lim, iv.y)
	return lim


## Lane-end wall only, for after the vehicle collisions (a push from the side cannot put anyone past the end of the
## lane). Small overlaps are removed at once, big ones (shoulder at the taper start) at WALL_PUSH. Returns the new x.
static func wall_x(evs: TrackEvents, x: float, z: float, length: float, half: float, dt: float) -> float:
	for ev in evs.list:
		if ev.kind != TrackEvents.Kind.NARROW or z + length < ev.z or z > ev.reopen_end():
			continue
		var s: int = ev.side()
		var lim: float = _wall_limit(evs, ev, z, length, s)
		if not is_finite(lim):
			continue
		var over: float = (x + half - lim) if s > 0 else (lim - (x - half))
		if over > 0.0:
			x -= (over if over < 0.15 else minf(over, WALL_PUSH * dt)) * float(s)
	return x


## Traffic car: never inside a closure (stops in front of the block, slides along the lane end).
static func car(evs: TrackEvents, c: TrafficSim.Car, dt: float) -> void:
	var half: float = c.width_x * 0.5
	var nose: float = c.z + c.length
	for ev in evs.list:
		if nose < ev.z or c.z > ev.reopen_end():
			continue
		if ev.kind == TrackEvents.Kind.NARROW:
			var s: int = ev.side()
			var lim: float = _wall_limit(evs, ev, c.z, c.length, s)
			if is_finite(lim):
				var over: float = (c.x + half - lim) if s > 0 else (lim - (c.x - half))
				if over > 0.0:
					c.x -= minf(over, WALL_PUSH * dt) * float(s)
			continue
		var full: float = ev.full_z()
		if nose <= full or c.z >= ev.end_z():
			continue
		var iv: Vector2 = evs.interval(ev, full + 0.5)
		if c.x + half <= iv.x or c.x - half >= iv.y:
			continue
		if nose - full < c.length * 0.5 + 1.0:
			c.z = full - c.length
			c.speed = 0.0
		else:
			var exit_left: bool = iv.y >= TrackEvents.OUTER or (iv.x > -TrackEvents.OUTER and c.x < (iv.x + iv.y) * 0.5)
			c.x = (iv.x - half) if exit_left else (iv.y + half)
