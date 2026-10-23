class_name RaceCamRig
extends RefCounted
## T-198: race camera modes (presentation only; never touches the sim).
## Poses are built in track coordinates (z along the road, lateral metres, height above the road), clamped to the known
## track geometry (barriers, 2-lane sections, tunnels, the player's own truck) and only then converted to world space.
## STANDARD keeps the original chase camera numbers (race_scene_3d) exactly.

enum Mode { NEAR, STANDARD, FAR, CINEMA, ORBIT }
const IDS: Array[String] = ["near", "standard", "far", "cinema", "orbit"]
const BLEND_S: float = 0.8                 # mode change: smooth move from the old pose to the new one
const WALL_GAP_M: float = 0.8              # never closer than this to the barrier face
const TUNNEL_WALL_GAP_M: float = 1.8
const TUNNEL_H_MAX: float = 5.6            # camera height limit inside tunnels (the arch is 6.6-8.2 m)
const TUNNEL_RAMP: float = 0.35            # extra height allowed per metre away from a portal (smooth glide)
const MIN_H: float = 0.6
const TOLL_H_MAX: float = 5.6              # T-207: under the toll canopy / gantry (signs from 6,05 m), every mode
const BODY_CLEAR_M: float = 2.4            # lateral distance kept from the player's box side
const BODY_TOP_H: float = 5.0              # ... or the camera goes over the roof
## Orbit: one lap with ease in/out, then a pause behind the truck (automatic return), repeat.
const ORBIT_LAP_S: float = 14.0
const ORBIT_HOLD_S: float = 4.0
const ORBIT_FOV: float = 52.0

var mode: int = Mode.STANDARD
var path: TrackPath
var events: TrackEvents
var tunnels: Array[Vector2] = []
var director := RaceCamDirector.new()

var _blend_t: float = 0.0
var _from_pos: Vector3 = Vector3.ZERO      # relative to the anchor (player truck) when the blend started
var _from_look: Vector3 = Vector3.ZERO
var _from_fov: float = 56.0
var _orbit_t: float = 0.0


func _init(path_: TrackPath = null, events_: TrackEvents = null, tunnels_: Array[Vector2] = []) -> void:
	path = path_
	events = events_
	tunnels = tunnels_


static func mode_from_id(id: String) -> int:
	var i: int = IDS.find(id)
	return i if i >= 0 else Mode.STANDARD


static func next_mode(m: int) -> int:
	return (m + 1) % IDS.size()


func id() -> String:
	return IDS[mode]


## Chase modes follow the truck with the race_scene smoothing, speed effects and shake. Free modes place the camera.
func is_chase() -> bool:
	return mode == Mode.NEAR or mode == Mode.STANDARD or mode == Mode.FAR


## Change mode; `cam_pos`/`cam_look` = current world pose, `anchor` = player truck position (blend follows the truck).
func set_mode(m: int, cam_pos: Vector3, cam_look: Vector3, fov: float, anchor: Vector3) -> void:
	if m == mode:
		return
	mode = m
	_blend_t = BLEND_S
	_from_pos = cam_pos - anchor
	_from_look = cam_look - anchor
	_from_fov = fov
	_orbit_t = 0.0
	director.reset()


func blending() -> bool:
	return _blend_t > 0.0


## Mixes the blend start pose into a target pose. Returns [pos, look, fov].
func blend(pos: Vector3, look: Vector3, fov: float, anchor: Vector3, dt: float) -> Array:
	if _blend_t <= 0.0:
		return [pos, look, fov]
	_blend_t = maxf(_blend_t - dt, 0.0)
	var w: float = smoothstep(0.0, 1.0, 1.0 - _blend_t / BLEND_S)
	return [(anchor + _from_pos).lerp(pos, w), (anchor + _from_look).lerp(look, w), lerpf(_from_fov, fov, w)]


## Chase pose in track coords [pos(z, lat_m, h), look(z, lat_m, h)]. z = player rear, x in road units.
## `k` = truck length / Collision.LEN (Canter 7 m: a bit closer and lower).
func chase_local(z: float, x: float, k: float) -> Array[Vector3]:
	var w: float = Track.ROAD_HALF_WIDTH_M
	match mode:
		Mode.NEAR:
			return [Vector3(z - (5.0 + 2.0 * k), x * 0.92 * w, 4.3 + 0.5 * k), Vector3(z + 22.0, x * 0.6 * w, 1.2)]
		Mode.FAR:
			return [Vector3(z - (24.0 + 6.0 * k), x * 0.6 * w, 10.5 + 1.0 * k), Vector3(z + 34.0, x * 0.35 * w, 0.5)]
	return [Vector3(z - (10.0 + 4.5 * k), x * 0.85 * w, 4.6 + 1.0 * k), Vector3(z + 14.0, x * 0.45 * w, 1.8)]


## Chase pose in world space (STANDARD is not clamped: it is the camera the game always had).
func chase_target(z: float, x: float, k: float) -> Array[Vector3]:
	var c: Array[Vector3] = chase_local(z, x, k)
	var p: Vector3 = c[0] if mode == Mode.STANDARD else clamp_point(c[0])
	p.z = minf(p.z, toll_h_max(p.x))                         # T-207: never through the toll canopy (STANDARD too)
	return [to_world(p), to_world(c[1])]


## Base field of view of each chase mode (the speed effects add to it).
func chase_fov() -> float:
	match mode:
		Mode.NEAR:
			return 62.0
		Mode.FAR:
			return 52.0
	return 56.0


## Speed effects scale (near feels faster, far calmer).
func fx_scale() -> float:
	match mode:
		Mode.NEAR:
			return 1.35
		Mode.FAR:
			return 0.6
	return 1.0


## Free modes (CINEMA, ORBIT). `me` / `rival` = Vector3(z, lat_m, length); rival.x = NAN when there is none.
## Returns [pos, look, fov] in world space.
func free_pose(dt: float, me: Vector3, speed: float, rival: Vector3) -> Array:
	var p: Array
	if mode == Mode.ORBIT:
		_orbit_t += dt
		p = orbit_local(_orbit_t, me)
	else:
		p = director.update(dt, me, speed, rival, self)
	var pos: Vector3 = clamp_point(p[0], me)
	return [to_world(pos), to_world(p[1]), float(p[2])]


## Orbit angle (0 = behind the truck) at time t: one eased lap, then a hold behind.
static func orbit_angle(t: float) -> float:
	var cycle: float = ORBIT_LAP_S + ORBIT_HOLD_S
	var u: float = fposmod(t, cycle)
	if u >= ORBIT_LAP_S:
		return 0.0
	var s: float = u / ORBIT_LAP_S
	return TAU * s * s * s * (s * (s * 6.0 - 15.0) + 10.0)      # smootherstep: starts and stops gently


func orbit_local(t: float, me: Vector3) -> Array:
	var a: float = orbit_angle(t)
	var cz: float = me.x + me.z * 0.5
	var r_lon: float = me.z * 0.5 + 9.0
	var pos := Vector3(cz - cos(a) * r_lon, me.y + sin(a) * 9.0, 3.6 + 0.9 * sin(a * 0.5))
	return [pos, Vector3(cz, me.y, 1.9), ORBIT_FOV]


## Keeps a camera point (z, lat_m, h) inside the space the track is known to be free: between the barriers (2-lane
## sections included), under the tunnel arch (with a smooth glide near the portals) and out of the player's box.
## `me` = Vector3(z, lat_m, length) of the player truck (length 0 = do not check the truck).
func clamp_point(p: Vector3, me: Vector3 = Vector3.ZERO) -> Vector3:
	var prof: Vector3 = LaneSections.profile(events, p.x)
	var t_gap: float = tunnel_distance(p.x)
	var gap: float = lerpf(TUNNEL_WALL_GAP_M, WALL_GAP_M, clampf(t_gap / 20.0, 0.0, 1.0))
	var lat: float = clampf(p.y, -(prof.x - gap), prof.y - gap)
	var h: float = maxf(p.z, MIN_H)
	h = minf(h, TUNNEL_H_MAX + t_gap * TUNNEL_RAMP)
	h = minf(h, toll_h_max(p.x))
	if me.z > 0.0 and p.x > me.x - 1.5 and p.x < me.x + me.z + 1.5 and absf(lat - me.y) < BODY_CLEAR_M:
		var side: float = signf(lat - me.y) if lat != me.y else 1.0
		var pushed: float = me.y + side * BODY_CLEAR_M
		if pushed > -(prof.x - gap) and pushed < prof.y - gap:
			lat = pushed
		else:
			h = maxf(h, BODY_TOP_H)
	return Vector3(p.x, lat, h)


## T-207: highest camera at z near the toll plaza (gantry .. canopy end), gliding like at the tunnel portals. INF far
## from it (or without a plaza).
func toll_h_max(z: float) -> float:
	if path == null or path.track == null or path.track.toll == null:
		return INF
	var c: float = path.track.toll.z
	var d: float = maxf(maxf((c + TollParts.GANTRY_DZ - 1.0) - z, z - (c + TollParts.CANOPY_DZ + 1.0)), 0.0)
	return TOLL_H_MAX + d * TUNNEL_RAMP


## Metres from z to the nearest tunnel (0 inside; INF without tunnels).
func tunnel_distance(z: float) -> float:
	var best: float = INF
	for t in tunnels:
		if z >= t.x and z <= t.x + t.y:
			return 0.0
		best = minf(best, minf(absf(t.x - z), absf(z - (t.x + t.y))))
	return best


func to_world(p: Vector3) -> Vector3:
	return path.world_point(p.x, p.y / Track.ROAD_HALF_WIDTH_M, p.z)
