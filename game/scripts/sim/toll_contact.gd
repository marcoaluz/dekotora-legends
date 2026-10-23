class_name TollContact
extends RefCounted
## Physical side of the toll plaza (T-207, TollPlaza). Pure math, called from EventContact (same timers, same contact
## dictionary, so RaceSim, the network, the sounds and the impact effects treat it like the track events of T-139):
##  - outer barriers (funnel + outer islands): a wall that moves in; the truck scrapes along it (speed + cargo
##    touch) and a truck on a shoulder lane that ends MUST merge into the passage (like the lane end of T-139).
##  - centre island (booth): HARD. The nose reaching the island nose is a crash against a stopped obstacle
##    (DamageModel with EventContact.OBSTACLE_MASS, like the accident vehicles): the truck cannot pass, drops to
##    EventContact.BLOCKED_SPEED, its target lane becomes the passage on its side and it slides out sideways.
##    Pushed in from the side: pushed back out with a side hit (or a scrape when slow). A truck in a passage that only
##    overlaps the island edge (curve slide, a push) grazes: back into its passage, cargo touch, no damage.
## The contact carries "event": -1 and "toll": true (RaceSim names it "toll").

const NO_EVENT: int = -1


## Applies the plaza to truck `t` (EventContact.truck calls it after the events). Returns {} or the contact.
static func truck(p: TollPlaza, t: TruckSim, dt: float) -> Dictionary:
	var out: Dictionary = {}
	var nose: float = t.z + t.length
	if nose < p.zone_start() or t.z > p.zone_end():
		return out
	var half: float = TruckSim.WIDTH_X * 0.5
	var lim: float = p.outer_limit_x(t.z, t.length)
	for s in [-1.0, 1.0]:                                         # outer barriers (both sides, same face)
		var over: float = s * t.x + half - lim
		if over > 0.0:
			t.x -= minf(over, EventContact.WALL_PUSH * dt) * s
			if t.lateral_vel * s > 0.0:
				t.lateral_vel = 0.0
			t.speed = maxf(t.speed - EventContact.WALL_DECEL * dt, 0.0)
			if t.scrape_t <= 0.0 and t.speed > 3.0:
				t.scrape_t = EventContact.SCRAPE_EVERY
				out = _contact("scrape", "right" if s > 0.0 else "left", 0.0)
	if (t.lane == Lanes.SHOULDER_L or t.lane == Lanes.SHOULDER_R) and p.lane_blocked_between(t.lane, t.z, nose + 10.0):
		t.lane = Lanes.FIRST if t.lane == Lanes.SHOULDER_L else Lanes.LAST     # the shoulder ends: into the passage
		t.signal_dir = 0
	if nose <= p.nose_z() or t.z >= p.tail_z():
		return out
	var ih: float = p.island_half_x()
	if t.x + half <= -ih or t.x - half >= ih:
		return out
	var lane_open: bool = t.lane != Lanes.CENTER and Lanes.is_road_lane(t.lane)
	var graze: bool = lane_open and minf(t.x + half, ih) - maxf(t.x - half, -ih) < EventContact.GRAZE_X
	var c: Dictionary = _graze(t, ih, half) if graze else _block(p, t, nose - p.nose_z(), ih, half)
	return c if not c.is_empty() else out


## Truck overlapping the island: frontal (nose just arrived: crash) or pushed in from the side.
static func _block(p: TollPlaza, t: TruckSim, depth: float, ih: float, half: float) -> Dictionary:
	var side: int = TollPlaza.passage_for(t.x)
	if depth < t.length * 0.5:
		var out: Dictionary = {}
		if t.hit_t <= 0.0:
			t.hit_t = EventContact.HIT_COOLDOWN
			out = _contact("obstacle", "front", t.speed)
		t.z = p.nose_z() - t.length                        # it does not pass through the island
		t.speed = minf(t.speed, EventContact.BLOCKED_SPEED)
		if t.lane == Lanes.CENTER or not Lanes.is_road_lane(t.lane):
			t.lane = side                                   # out to the passage on its side
			t.signal_dir = 0
		return out
	var exit_left: bool = side == Lanes.FIRST
	var dv: float = absf(t.lateral_vel) * Collision.M_X
	t.x = (-ih - half) if exit_left else (ih + half)
	t.lateral_vel = 0.0
	if t.lane == Lanes.CENTER:
		t.lane = side
		t.signal_dir = 0
	if t.scrape_t > 0.0:
		return {}
	t.scrape_t = EventContact.SCRAPE_EVERY
	var zone: String = "right" if exit_left else "left"   # the island is on that side of the truck
	if dv > EventContact.SIDE_MIN_DV:
		return _contact("obstacle", zone, dv)
	return _contact("scrape", zone, 0.0)


## Truck in a passage touching the island edge: back into the passage, a scrape (cargo touch), no damage.
static func _graze(t: TruckSim, ih: float, half: float) -> Dictionary:
	var exit_left: bool = TollPlaza.passage_for(t.x) == Lanes.FIRST
	t.x = (-ih - half) if exit_left else (ih + half)
	if t.lateral_vel * (1.0 if exit_left else -1.0) > 0.0:
		t.lateral_vel = 0.0
	if t.scrape_t > 0.0:
		return {}
	t.scrape_t = EventContact.SCRAPE_EVERY
	return _contact("scrape", "right" if exit_left else "left", 0.0)


static func _contact(kind: String, zone: String, dv: float) -> Dictionary:
	return {"kind": kind, "zone": zone, "dv": dv, "event": NO_EVENT, "toll": true}


## After the vehicle collisions (a push cannot put anyone inside the plaza): outer faces and the island sides. Small
## overlaps go at once, big ones at EventContact.WALL_PUSH. A nose against the island (frontal) is left alone (its z
## is held by `truck`). Returns the new x.
static func wall_x(p: TollPlaza, x: float, z: float, length: float, half: float, dt: float) -> float:
	if z + length < p.zone_start() or z > p.zone_end():
		return x
	var lim: float = p.outer_limit_x(z, length)
	for s in [-1.0, 1.0]:
		var over: float = s * x + half - lim
		if over > 0.0:
			x -= (over if over < 0.15 else minf(over, EventContact.WALL_PUSH * dt)) * s
	var ih: float = p.island_half_x()
	if z + length - p.nose_z() >= length * 0.5 and z < p.tail_z() and x + half > -ih and x - half < ih:
		var exit_left: bool = TollPlaza.passage_for(x) == Lanes.FIRST
		var over_i: float = (x + half + ih) if exit_left else (ih - (x - half))
		var mv: float = over_i if over_i < 0.15 else minf(over_i, EventContact.WALL_PUSH * dt)
		x += -mv if exit_left else mv
	return x


## Traffic car: never inside the plaza (stops in front of the island nose, slides along the barriers and the island).
static func car(p: TollPlaza, c: TrafficSim.Car, dt: float) -> void:
	var nose: float = c.z + c.length
	if nose < p.zone_start() or c.z > p.zone_end():
		return
	var half: float = c.width_x * 0.5
	var lim: float = p.outer_limit_x(c.z, c.length)
	for s in [-1.0, 1.0]:
		var over: float = s * c.x + half - lim
		if over > 0.0:
			c.x -= minf(over, EventContact.WALL_PUSH * dt) * s
	if nose <= p.nose_z() or c.z >= p.tail_z():
		return
	var ih: float = p.island_half_x()
	if c.x + half <= -ih or c.x - half >= ih:
		return
	if nose - p.nose_z() < c.length * 0.5 + 1.0:
		c.z = p.nose_z() - c.length
		c.speed = 0.0
	else:
		c.x = (-ih - half) if TollPlaza.passage_for(c.x) == Lanes.FIRST else (ih + half)
