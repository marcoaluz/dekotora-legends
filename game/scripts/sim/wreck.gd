class_name Wreck
extends RefCounted
## Crashed traffic car (T-183). A car thrown by a truck (ThrownCar) never drives again: it slides and spins until it
## stops, keeps the angle it stopped at and becomes an obstacle for everybody (trucks, bots and the other cars).
## Hitting it again pushes it with the same impact physics (Collision -> TrafficSim.throw_car), but it stays a wreck.
## It goes away when it is WRECK_DESPAWN_BEHIND m behind the last truck (TrafficSim respawns it ahead as a new car).
## Numbers only (runs the same on the server); the hazard lights, smoke and warning triangle are drawn by
## road3d/wreck_fx.gd from `wrecked` and `crash_t`, which travel in the snapshot.

const DESPAWN_BEHIND: float = 300.0    # m behind the last truck (normal cars: TrafficSim.DESPAWN_BEHIND, 150 m)
const CRASH_T_MAX: float = 600.0       # s; crash_t stops counting here (only the first seconds matter to the visuals)
const BUMP_SHARE: float = 0.5          # fraction of the bumping car's momentum that pushes the wreck
const SIDE_PEN_M: float = 2.5          # m: a z overlap deeper than this is resolved sideways (cars side by side)
const PIVOT: float = 0.2               # fraction of the length from the rear to the rear axle (= TrackPath.REAR_AXLE, tested)


## Turns the car into a wreck (first throw only). Returns true if it was not a wreck before.
static func mark(c: TrafficSim.Car) -> bool:
	if c.wrecked:
		return false
	c.wrecked = true
	c.crash_t = 0.0
	return true


static func clear(c: TrafficSim.Car) -> void:
	c.wrecked = false
	c.crash_t = 0.0


## Seconds since the crash (visual timing: smoke, warning triangle).
static func step(c: TrafficSim.Car, dt: float) -> void:
	c.crash_t = minf(c.crash_t + dt, CRASH_T_MAX)


## Footprint on the road as a Rect2: position = (rear z in m, left x in units), size = (length in m, width in x units).
## A car that is not turned (yaw 0) gives exactly its plain box. A turned car is rotated around its rear axle
## (the same pivot TrackPath.vehicle_transform uses to draw it), so a car standing across the lane blocks the lane.
static func footprint(c: TrafficSim.Car) -> Rect2:
	if c.yaw == 0.0:
		return Rect2(c.z, c.x - c.width_x * 0.5, c.length, c.width_x)
	var m_x: float = Track.ROAD_HALF_WIDTH_M
	var pivot: float = c.length * PIVOT
	var cy: float = cos(c.yaw)
	var sy: float = sin(c.yaw)
	var w_m: float = c.width_x * m_x
	# forward unit (dz, dx m) = (cos, -sin) (yaw + = left = -x); right unit = (sin, cos)
	var z_lo: float = INF
	var z_hi: float = -INF
	var x_lo: float = INF
	var x_hi: float = -INF
	for f in [-pivot, c.length - pivot]:
		for s in [-w_m * 0.5, w_m * 0.5]:
			var dz: float = float(f) * cy + float(s) * sy
			var dx: float = -float(f) * sy + float(s) * cy
			z_lo = minf(z_lo, dz)
			z_hi = maxf(z_hi, dz)
			x_lo = minf(x_lo, dx)
			x_hi = maxf(x_hi, dx)
	var pz: float = c.z + pivot
	return Rect2(pz + z_lo, c.x + x_lo / m_x, z_hi - z_lo, (x_hi - x_lo) / m_x)


## Lateral overlap (x units) between a corridor centered at `x` with half width `half` and the footprint `r`.
static func overlaps_x(r: Rect2, x: float, half: float) -> bool:
	return r.position.y < x + half and r.end.y > x - half


## Contacts between wrecks and the other traffic cars (traffic cars brake and change lane before, see TrafficSim;
## this is the fallback when they could not). The car behind stops right behind the one in front and part of its
## momentum pushes the wreck. Deterministic: fixed order of the list. Returns the number of contacts.
static func resolve_cars(cars: Array[TrafficSim.Car]) -> int:
	var bumps: int = 0
	for i in cars.size():
		var w: TrafficSim.Car = cars[i]
		if not w.wrecked or w.y > 0.5:
			continue
		for j in cars.size():
			var o: TrafficSim.Car = cars[j]
			if j == i or o.y > 0.5 or (o.wrecked and j < i):
				continue                       # wreck x wreck: once per pair
			var rw: Rect2 = footprint(w)
			var ro: Rect2 = footprint(o)
			if not rw.intersects(ro):
				continue
			bumps += 1
			var pen_z: float = minf(rw.end.x, ro.end.x) - maxf(rw.position.x, ro.position.x)
			var pen_x: float = minf(rw.end.y, ro.end.y) - maxf(rw.position.y, ro.position.y)
			if pen_z > SIDE_PEN_M and pen_x * Track.ROAD_HALF_WIDTH_M < pen_z:
				var side: float = 1.0 if ro.get_center().y >= rw.get_center().y else -1.0
				if o.wrecked:
					w.x -= side * pen_x * 0.5
					o.x += side * pen_x * 0.5
				else:
					o.x += side * pen_x       # the driving car is squeezed aside
				continue
			var back: TrafficSim.Car = o if ro.get_center().x < rw.get_center().x else w
			var front: TrafficSim.Car = w if back == o else o
			back.z -= pen_z
			if back.speed > front.speed:
				var push: float = (back.speed - front.speed) * back.mass / (back.mass + front.mass) * BUMP_SHARE
				front.speed += push if front.wrecked else 0.0
				back.speed = front.speed if not back.wrecked else maxf(back.speed - push, 0.0)
	return bumps
