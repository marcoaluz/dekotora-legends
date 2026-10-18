class_name EventProps
extends RefCounted
## What each track event looks like (T-139), placed from the SAME closed interval the simulation uses
## (TrackEvents.interval): cones and lights sit on the edge the trucks collide with.
##  - accident: warning signs (LED board "この先 事故 / 車線規制" 400 m and 200 m before), cones and red flares along the
##    taper, warning triangle, LED arrow board, 1 or 2 stopped cars with hazard lights.
##  - works: LED board + works diamond + 60 km/h limit, cones, striped barricades with yellow lamps, 工事中 board,
##    small works truck with an LED arrow board and beacons, steel plates on the open lane beside the works.
##  - narrow: lane reduction diamond + 車線減少 plate, painted merge arrows, the lane-end line, zebra hatching on the
##    lane that ends, delineator posts and an LED arrow board.
## Signs stand on the right (median) barrier, so they never sit on the regular signs of RoadSigns (left side).

const M: float = Track.ROAD_HALF_WIDTH_M
const SIGN_LAT: float = RoadMesh.BARRIER_IN + 0.3
const SIGN_TURN: float = -0.1                      # right side: turned a little to the road
const BARRIER_TOP: float = 0.85
const ACCIDENT_MODELS: Array[String] = ["car_ascona", "car_suv", "car_falcon"]   # 4 surfaces each (the code-made cars have 7)
const ACCIDENT_COLORS: Array[Color] = [Color("#d8dce2"), Color("#2a5cc0"), Color("#c8202f")]
const CAR_LEN: float = 4.5
const AMBER := Color(1.0, 0.6, 0.12)
const RED_L := Color(1.0, 0.18, 0.08)
const YELLOW_L := Color(1.0, 0.82, 0.25)
const POST := Color("#8e939a")
const WHITE_P := Color(0.93, 0.93, 0.9)
const STEEL := Color(0.3, 0.31, 0.34)


static func build(b: TrackEvents3D, ev: TrackEvents.Event, k: int) -> void:
	_signs(b, ev)
	match ev.kind:
		TrackEvents.Kind.ACCIDENT:
			_cones(b, ev)
			_accident(b, ev, k)
		TrackEvents.Kind.WORKS:
			_cones(b, ev)
			_works(b, ev, k)
		TrackEvents.Kind.NARROW:
			_narrow(b, ev, k)
	b.count(TrackEvents.KIND_IDS[ev.kind])


# ---------------------------------------------------------------- shared
## Edges (m) of the closed area that are inside the road at zz, with the direction into the closure.
static func _edges(b: TrackEvents3D, ev: TrackEvents.Event, zz: float) -> Array:
	var iv: Vector2 = b.events.interval(ev, zz)
	var out: Array = []
	if iv.x > iv.y:
		return out
	if iv.x > -TrackEvents.OUTER + 0.001:
		out.append([iv.x * M, 1.0])
	if iv.y < TrackEvents.OUTER - 0.001:
		out.append([iv.y * M, -1.0])
	return out


## Closed span (m) inside the asphalt at zz: Vector2(left, right).
static func _span(b: TrackEvents3D, ev: TrackEvents.Event, zz: float) -> Vector2:
	var iv: Vector2 = b.events.interval(ev, zz)
	return Vector2(maxf(iv.x, -TrackEvents.EDGE) * M, minf(iv.y, TrackEvents.EDGE) * M)


## Closed lane next to the open road (where boards and the first car stand).
static func _front_lane(ev: TrackEvents.Event) -> int:
	return ev.hi if ev.side() < 0 else ev.lo


## Arrow pointing to the open side.
static func _arrow_id(ev: TrackEvents.Event) -> String:
	return "arrow_r" if ev.side() < 0 else "arrow_l"


static func _cones(b: TrackEvents3D, ev: TrackEvents.Event) -> void:
	var full: float = ev.full_z()
	var zz: float = ev.z + 1.5
	var n: int = 0
	while zz <= ev.end_z():
		for e in _edges(b, ev, zz):
			b.cone(zz, float(e[0]) + float(e[1]) * 0.18)
			if zz < full and n % 2 == 0 and ev.kind == TrackEvents.Kind.ACCIDENT:   # red flares along the taper
				b.light(b.basis(zz), b.pt(zz, float(e[0]) + float(e[1]) * 0.5, 0.18), 0.55, RED_L, n * 0.37)
			n += 1
		zz += 3.0 if zz < full else 6.0
	var sp: Vector2 = _span(b, ev, ev.end_z() - 0.3)     # last row across the closure
	var l: float = sp.x + 0.4
	while l < sp.y - 0.3:
		b.cone(ev.end_z() - 0.3, l)
		l += 1.2


## LED arrow board on a stand (or on a vehicle when `h` is higher). Faces the driver.
static func _arrow_board(b: TrackEvents3D, z: float, lat: float, h: float, id: String, phase: float, legs: bool = true) -> void:
	var bs: Basis = b.basis(z)
	b.face(bs, b.pt(z, lat, h), Vector2(1.9, 1.3), "solid_black")
	b.box(bs, b.pt(z, lat, h) - bs.z * 0.06, Vector3(2.0, 1.4, 0.1), Color("#2a2c31"))
	b.light(bs, b.pt(z, lat, h) + bs.z * 0.03, 1.2, Color.WHITE, phase, id)
	if legs:
		for sx in [-0.75, 0.75]:
			b.box(bs, b.pt(z, lat + sx, (h - 0.65) * 0.5) - bs.z * 0.1, Vector3(0.08, h - 0.65, 0.08), POST)


# ---------------------------------------------------------------- signs (right barrier)
static func _signs(b: TrackEvents3D, ev: TrackEvents.Event) -> void:
	var dists: Array = [[400.0, "d400"], [200.0, "d200"]]
	for d in dists:
		var z: float = ev.z - float(d[0])
		if z < 30.0:
			continue
		match ev.kind:
			TrackEvents.Kind.ACCIDENT:
				_board(b, z, "vms_accident", String(d[1]))
			TrackEvents.Kind.WORKS:
				if float(d[0]) > 300.0:
					_board(b, z, "vms_works", String(d[1]))
				else:
					_diamond(b, z, "warn_works", "", String(d[1]))
			TrackEvents.Kind.NARROW:
				_diamond(b, z, "warn_narrow_r" if ev.side() > 0 else "warn_narrow_l", "aux_narrow", String(d[1]))
		b.count("sign")
	if ev.kind == TrackEvents.Kind.WORKS:
		for z2 in [ev.z - 90.0, ev.full_z() + 12.0]:
			_diamond(b, z2, "spd_60", "", "")
			b.count("limit")


static func _board(b: TrackEvents3D, z: float, id: String, plate: String) -> void:
	var bs: Basis = b.basis(z, SIGN_TURN)
	var c: Vector3 = b.pt(z, SIGN_LAT, 4.0)
	b.face(bs, c, Vector2(3.4, 1.7), id)
	b.box(bs, c - bs.z * 0.06, Vector3(3.5, 1.8, 0.1), Color("#2a2c31"))
	b.face(bs, b.pt(z, SIGN_LAT, 2.75), Vector2(1.4, 0.7), plate)
	for sx in [-1.2, 1.2]:
		var base: Vector3 = b.pt(z, SIGN_LAT, BARRIER_TOP) + bs.x * sx - bs.z * 0.15
		b.box(Basis(), base + Vector3.UP * 1.6, Vector3(0.12, 3.2, 0.12), POST)


static func _diamond(b: TrackEvents3D, z: float, id: String, aux: String, plate: String) -> void:
	var bs: Basis = b.basis(z, SIGN_TURN)
	b.face(bs, b.pt(z, SIGN_LAT, 3.7), Vector2(1.6, 1.6), id)
	b.box(bs, b.pt(z, SIGN_LAT, 3.7) - bs.z * 0.04, Vector3(1.1, 1.1, 0.05), POST)
	var y: float = 2.6
	if aux != "":
		b.face(bs, b.pt(z, SIGN_LAT, y), Vector2(1.7, 0.43), aux)
		y -= 0.6
	if plate != "":
		b.face(bs, b.pt(z, SIGN_LAT, y), Vector2(1.2, 0.6), plate)
	var base: Vector3 = b.pt(z, SIGN_LAT, BARRIER_TOP) - bs.z * 0.08
	b.box(Basis(), base + Vector3.UP * 1.45, Vector3(0.11, 2.9, 0.11), POST)


# ---------------------------------------------------------------- accident
static func _accident(b: TrackEvents3D, ev: TrackEvents.Event, k: int) -> void:
	var full: float = ev.full_z()
	var s: int = ev.side()
	var dir: float = float(s) if s != 0 else 1.0
	var zt: float = ev.z + TrackEvents.TAPER_M[ev.kind] * 0.65    # warning triangle inside the taper
	var sp: Vector2 = _span(b, ev, zt)
	b.face(b.basis(zt), b.pt(zt, (sp.x + sp.y) * 0.5, 0.34), Vector2(0.72, 0.68), "triangle")
	var lane: int = _front_lane(ev)
	_arrow_board(b, full - 2.5, Lanes.X[lane] * M, 1.6, _arrow_id(ev), 0.1 * k)
	var other: int = ev.lo if lane == ev.hi else ev.hi
	var cars: Array = [[lane, full + 1.5, 0.38 * dir], [other, full + (8.5 if other != lane else 9.5), -0.5 * dir]]
	for i in cars.size():
		var c: Array = cars[i]
		var lat: float = Lanes.X[int(c[0])] * M + (0.35 * dir if i == 0 else -0.25 * dir)
		var model: String = ACCIDENT_MODELS[(k + i) % ACCIDENT_MODELS.size()]
		var n: Node3D = b.stopped_car(model, float(c[1]), lat, float(c[2]), ACCIDENT_COLORS[(k * 2 + i) % ACCIDENT_COLORS.size()])
		if n == null:
			continue
		b.count("car")
		var bs: Basis = b.basis(float(c[1]))
		for p in [Vector3(-0.72, 0.78, 0.05), Vector3(0.72, 0.78, 0.05), Vector3(-0.72, 0.72, -CAR_LEN + 0.1), Vector3(0.72, 0.72, -CAR_LEN + 0.1)]:
			b.light(bs, n.transform * p, 0.5, AMBER, 0.5 * i)


# ---------------------------------------------------------------- road works
static func _works(b: TrackEvents3D, ev: TrackEvents.Event, k: int) -> void:
	var full: float = ev.full_z()
	var s: int = ev.side()
	var zb: float = full - 0.4
	var sp: Vector2 = _span(b, ev, full + 0.5)
	var l0: float = sp.x + 0.25
	var l1: float = sp.y - 0.25
	var n: int = maxi(1, roundi((l1 - l0) / 1.6))
	var bs: Basis = b.basis(zb)
	for i in n:                                            # striped barricades with a yellow lamp
		var w: float = (l1 - l0) / n - 0.12
		var c: float = lerpf(l0, l1, (i + 0.5) / n)
		for h in [0.95, 0.55]:
			b.face(bs, b.pt(zb, c, h), Vector2(w, 0.26), "barricade")
		for sx in [-w * 0.5 + 0.05, w * 0.5 - 0.05]:
			b.box(bs, b.pt(zb, c + sx, 0.55) - bs.z * 0.05, Vector3(0.06, 1.1, 0.4), WHITE_P)
		b.light(bs, b.pt(zb, c, 1.28) + bs.z * 0.05, 0.42, YELLOW_L, 0.23 * i)
	b.face(bs, b.pt(zb, (l0 + l1) * 0.5, 1.62), Vector2(1.6, 0.4), "kouji")
	# small works truck behind the barricade, LED arrow board on the back, beacons on the cab
	var lat: float = Lanes.X[_front_lane(ev)] * M
	var rear: float = full + 4.0
	var tb: Basis = b.basis(rear + 3.0)
	b.box(tb, b.pt(rear + 2.9, lat, 0.62), Vector3(1.8, 0.35, 5.8), Color("#26272b"))
	b.box(tb, b.pt(rear + 2.1, lat, 1.25), Vector3(2.1, 0.9, 4.2), Color("#e2e2dc"))
	b.box(tb, b.pt(rear + 5.0, lat, 1.45), Vector3(2.1, 1.8, 1.6), Color("#f0f0ea"))
	b.box(tb, b.pt(rear + 5.81, lat, 1.75), Vector3(1.9, 0.75, 0.04), Color("#1d2430"))
	for wz in [rear + 1.1, rear + 4.9]:
		for sx in [-0.95, 0.95]:
			b.box(tb, b.pt(wz, lat + sx, 0.38), Vector3(0.3, 0.76, 0.76), Color("#151517"))
	_arrow_board(b, rear - 0.05, lat, 2.45, _arrow_id(ev), 0.17 * k, false)
	for sx in [-0.6, 0.6]:
		b.light(b.basis(rear + 5.0), b.pt(rear + 5.0, lat + sx, 2.5), 0.55, YELLOW_L, 0.5 * (sx + 1.0))
	b.count("works_truck")
	# steel plates on the open lane(s) beside the works: the 60 km/h limit
	var lanes: Array[int] = []
	if s >= 0 and ev.lo - 1 >= Lanes.FIRST:
		lanes.append(ev.lo - 1)
	if s <= 0 and ev.hi + 1 <= Lanes.LAST:
		lanes.append(ev.hi + 1)
	for ol in lanes:
		var zz: float = full + 1.0
		var j: int = 0
		while zz + 3.0 < ev.end_z():
			var c2: float = Lanes.X[ol] * M
			var tint: float = 0.9 + 0.2 * float(j % 3) * 0.5
			b.paint_quad(zz, c2 - 1.55, c2 + 1.55, zz + 3.0, c2 - 1.55, c2 + 1.55, STEEL * tint, 0.025)
			zz += 3.15
			j += 1


# ---------------------------------------------------------------- narrowing (one outer lane ends)
static func _narrow(b: TrackEvents3D, ev: TrackEvents.Event, k: int) -> void:
	var s: int = ev.side()
	var lane_c: float = Lanes.X[ev.lo] * M
	var outer: float = TrackEvents.EDGE * M * float(s) - 0.3 * float(s)
	# painted merge arrows on the lane that ends (diagonal, pointing to the open side)
	for dz in [-110.0, -55.0, -8.0]:
		var z0: float = ev.z + dz
		var tail: Vector3 = b.pt(z0, lane_c + 0.4 * s, 0.03)
		var tip_z: float = z0 + 5.5
		var tip_lat: float = lane_c - 0.9 * s
		var neck: Vector3 = b.pt(tip_z - 1.4, tip_lat + 0.45 * s, 0.03)
		var side_v: Vector3 = b.path.right_at(z0) * 0.16
		b.paint_tri(tail - side_v, neck - side_v, neck + side_v, WHITE_P)
		b.paint_tri(tail - side_v, neck + side_v, tail + side_v, WHITE_P)
		var wing: Vector3 = b.path.right_at(z0) * 0.6
		b.paint_tri(neck - wing, b.pt(tip_z, tip_lat, 0.03), neck + wing, WHITE_P)
	# lane-end line and zebra hatching, from the same interval the trucks collide with
	var zz: float = ev.z
	while zz < ev.reopen_end():
		var e0: Array = _edges(b, ev, zz)
		var e1: Array = _edges(b, ev, zz + 2.0)
		if not e0.is_empty() and not e1.is_empty():
			var a: float = float(e0[0][0])
			var c: float = float(e1[0][0])
			b.paint_quad(zz, a - 0.1, a + 0.1, zz + 2.0, c - 0.1, c + 0.1, WHITE_P)
		zz += 2.0
	zz = ev.z + 8.0
	while zz < ev.reopen_end() - 4.0:
		var ea: Array = _edges(b, ev, zz)
		if not ea.is_empty():
			var inner: float = float(ea[0][0]) + float(ea[0][1]) * 0.45
			if (outer - inner) * float(s) > 0.8:
				var p0: Vector3 = b.pt(zz, inner, 0.028)
				var p1: Vector3 = b.pt(zz + 0.6, inner, 0.028)
				var p2: Vector3 = b.pt(zz + 2.6, outer, 0.028)
				var p3: Vector3 = b.pt(zz + 2.0, outer, 0.028)
				b.paint_tri(p0, p1, p2, WHITE_P)
				b.paint_tri(p0, p2, p3, WHITE_P)
		zz += 3.5
	# delineator posts along the taper and an LED arrow board where the lane is gone
	zz = ev.z + 4.0
	while zz < ev.full_z():
		var ep: Array = _edges(b, ev, zz)
		if not ep.is_empty():
			var lat: float = float(ep[0][0]) + float(ep[0][1]) * 0.25
			var bs: Basis = b.basis(zz)
			b.box(bs, b.pt(zz, lat, 0.4), Vector3(0.12, 0.8, 0.12), Color("#ff6a13"))
			b.box(bs, b.pt(zz, lat, 0.62), Vector3(0.13, 0.1, 0.13), WHITE_P)
		zz += 6.0
	var spf: Vector2 = _span(b, ev, ev.full_z() + 6.0)
	_arrow_board(b, ev.full_z() + 6.0, (spf.x + spf.y) * 0.5, 1.6, _arrow_id(ev), 0.13 * k)
