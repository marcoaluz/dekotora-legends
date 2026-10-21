class_name FreecamMath
extends RefCounted
## Pure helpers of the explorer/free camera (T-181): no nodes, no Input, no rendering.
## Covered by tests/test_freecam.gd. The camera itself is Freecam (freecam.gd).

const TELEPORT_HEIGHT: float = 6.0      # m above the road centre after a teleport
const TELEPORT_PITCH: float = -0.12     # rad, looking slightly down the road
const SPEED_DEFAULT: float = 20.0       # m/s
const SPEED_MIN: float = 1.0
const SPEED_MAX: float = 400.0
const WHEEL_STEP: float = 1.25          # speed multiplier per mouse wheel notch
const FAST_MULT: float = 4.0            # Shift (PC) / 4x button (touch)
const PITCH_LIMIT: float = 1.55         # rad (just under 90 degrees)
const MOUSE_SENS: float = 0.003         # rad per pixel of mouse motion
const STICK_LOOK_RATE: Vector2 = Vector2(2.2, 1.6)   # rad/s at full deflection (yaw, pitch)


## The explorer camera is offered only off-line, and only in a debug build, with the "Explorer mode" option on,
## or when the race was started with --freecam.
static func allowed(online: bool, debug_build: bool, explorer_setting: bool, flag: bool) -> bool:
	return not online and (debug_build or explorer_setting or flag)


## "1,2" / "1.2" / "1.2 km" -> 1.2 km; "800m" / "800 m" -> 0.8 km. NAN when the text is not a valid distance.
static func parse_km(text: String) -> float:
	var s: String = text.strip_edges().to_lower().replace(" ", "").replace(",", ".")
	var meters: bool = false
	if s.ends_with("km"):
		s = s.left(-2)
	elif s.ends_with("m"):
		meters = true
		s = s.left(-1)
	if s == "" or not s.is_valid_float():
		return NAN
	var v: float = s.to_float()
	if v < 0.0 or is_nan(v) or is_inf(v):
		return NAN
	return v / 1000.0 if meters else v


## Track distance (m) for a km typed by the player, kept inside the route.
static func teleport_z(path: TrackPath, km: float) -> float:
	return clampf(km * 1000.0, 0.0, maxf(path.track.length_m - 0.01, 0.0))


## Camera pose for a teleport to track distance `z`: [position, yaw, pitch]. Centre of the road, 6 m up,
## facing the driving direction.
static func teleport_pose(path: TrackPath, z: float) -> Array:
	return [path.world_point(z, 0.0, TELEPORT_HEIGHT), path.yaw_at(z), TELEPORT_PITCH]


## Camera basis from yaw (around Y) and pitch (around local X). Forward = -Z, like Camera3D.
static func basis_from(yaw: float, pitch: float) -> Basis:
	return Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)


## World velocity for an input vector (x = right, y = up, z = forward), each -1..+1, at `speed` m/s.
## Forward follows where the camera looks (pitch included); up/down is always world Y.
static func velocity(b: Basis, input: Vector3, speed: float) -> Vector3:
	var v: Vector3 = b.x * input.x + (-b.z) * input.z
	if v.length() > 1.0:
		v = v.normalized()
	return (v + Vector3.UP * clampf(input.y, -1.0, 1.0)) * speed


## Speed after `notches` mouse wheel steps (+ = faster).
static func next_speed(speed: float, notches: int) -> float:
	return clampf(speed * pow(WHEEL_STEP, float(notches)), SPEED_MIN, SPEED_MAX)


## Nearest point of the route to `p`: Vector3(z along the track in m, lateral offset in m (+ = right),
## height above the road centre in m). Brute force over the segment starts (2 m apart; ~1-2 thousand points).
static func nearest(path: TrackPath, p: Vector3) -> Vector3:
	var n: int = path.pos.size() - 1
	if n <= 0:
		return Vector3.ZERO
	var best_i: int = 0
	var best_d: float = INF
	for i in n:
		var d: float = path.pos[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best_i = i
	var z: float = float(best_i) * Track.SEG_LEN
	for i in [best_i - 1, best_i]:                      # refine on the two segments around the nearest start
		if i < 0 or i >= n:
			continue
		var a: Vector3 = path.pos[i]
		var ab: Vector3 = path.pos[i + 1] - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d2: float = (a + ab * t).distance_squared_to(p)
		if d2 <= best_d:
			best_d = d2
			z = (float(i) + t) * Track.SEG_LEN
	z = clampf(z, 0.0, path.track.length_m)
	var c: Vector3 = path.center_at(z)
	return Vector3(z, (p - c).dot(path.right_at(z)), p.y - c.y)


## "km 1,234" (Brazilian decimal comma, like the road signs).
static func format_km(z: float) -> String:
	return ("km %.3f" % (z / 1000.0)).replace(".", ",")


## File name of a screenshot: <route>_km<1.234>_<object>_<YYYYMMDD-HHMMSS>.png (safe on Windows and Android).
static func shot_file_name(route_id: String, z: float, object_name: String, stamp: String) -> String:
	var r: String = sanitize(route_id, 32)
	var o: String = sanitize(object_name, 48)
	return "%skm%.3f_%s_%s.png" % [(r + "_") if r != "" else "", z / 1000.0, o if o != "" else "nada", stamp]


## Keeps letters, digits, '-' and '_' (accents are dropped, everything else becomes '_'); at most `max_len` chars.
static func sanitize(text: String, max_len: int = 48) -> String:
	var out: String = ""
	for ch in text:
		var c: int = ch.unicode_at(0)
		var ok: bool = (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or ch == "-" or ch == "_"
		if ok:
			out += ch
		elif not out.ends_with("_"):
			out += "_"
	out = out.strip_edges().trim_prefix("_").trim_suffix("_")
	return out.left(max_len).trim_suffix("_")


## "20261021-153012" from Time.get_datetime_dict_from_system().
static func stamp(dt: Dictionary) -> String:
	return "%04d%02d%02d-%02d%02d%02d" % [int(dt.get("year", 0)), int(dt.get("month", 0)), int(dt.get("day", 0)),
		int(dt.get("hour", 0)), int(dt.get("minute", 0)), int(dt.get("second", 0))]
