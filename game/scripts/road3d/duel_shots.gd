class_name DuelShots
extends RefCounted
## Camera work and truck moves of the duel opening (T-156, redone in T-204) and the alignment shot on the track at
## the start of the countdown. Pure math over the intro time (no state): every client plays the same moves from the
## same clock online, and the tests check them without a screen.
## Studio space (DuelStage, local to DuelStage.ORIGIN): camera on +Z looking at -Z; trucks end side by side facing
## the camera, noses on z = 0; player (pair[0]) on the screen LEFT (x < 0), rival on the right.

const SIDE_X: float = 4.0               # lateral position of each truck (m from the centre line)
const START := Vector2(30.0, -26.0)     # where each nose comes from (x outward, z far): enters from the screen side
const BEND := Vector2(4.0, -11.0)       # control point: comes in at an angle and straightens up facing the camera
const STOP_AT: float = 0.8              # fraction of the enter phase when the trucks are stopped (T-208: a beat parked)
const CRUISE: float = 0.35              # first part of the entrance at constant speed, then a steady braking
const LAUNCH_ACCEL: float = 16.0        # m/s2 when they charge at the camera (T-208: 1 s of launch, nose short of the lens)


## Height factor of the small Canter (its cab is ~2.1 m tall instead of ~3 m).
static func height_k(truck: TruckNode) -> float:
	return 0.74 if truck.body_kind == "canter" else 1.0


## Metres from the rear of the truck (node origin) to its nose.
static func front_len(truck: TruckNode) -> float:
	return 11.4 + truck.front_delta()


static func _ease(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


static func _aim(cam: Camera3D, pos: Vector3, look: Vector3, fov: float) -> void:
	if cam.is_inside_tree():
		cam.global_position = pos
		cam.look_at(look, Vector3.UP)
	else:
		cam.position = pos
	cam.fov = fov


# ---------------------------------------------------------------- trucks

## Nose of truck `n` (0 = player, left; 1 = rival, right) at intro time `t`, in studio space:
## {nose: Vector3, dir: Vector3 (unit, where the nose points), speed: m/s}.
static func truck_pose(n: int, t: float) -> Dictionary:
	var side: float = -1.0 if n == 0 else 1.0
	var enter_len: float = DuelPlan.phase_len("enter")
	var launch_t: float = t - DuelPlan.phase_start("launch")
	var stop_t: float = enter_len * STOP_AT
	if t < stop_t:
		var p0 := Vector2(side * START.x, START.y)
		var p1 := Vector2(side * BEND.x, BEND.y)
		var p2 := Vector2(side * SIDE_X, 0.0)
		var lut: PackedFloat32Array = _arc_lut(p0, p1, p2)
		var total: float = lut[lut.size() - 1]
		var v0: float = 2.0 * total / (stop_t * (1.0 + CRUISE))       # cruise speed that ends exactly at the mark
		var u: float = clampf(t / stop_t, 0.0, 1.0)
		var dist: float = v0 * stop_t * u
		var speed: float = v0
		if u > CRUISE:
			var b: float = (u - CRUISE) / (1.0 - CRUISE)                 # steady braking down to 0
			dist = v0 * stop_t * (CRUISE + (1.0 - CRUISE) * (b - 0.5 * b * b))
			speed = v0 * (1.0 - b)
		var s: float = _s_at(lut, dist)
		var pt: Vector2 = _bez(p0, p1, p2, s)
		var d: Vector2 = (p1 - p0) * 2.0 * (1.0 - s) + (p2 - p1) * 2.0 * s
		var dn: Vector2 = d.normalized() if d.length() > 0.001 else Vector2(0, 1)
		return {"nose": Vector3(pt.x, 0.0, pt.y), "dir": Vector3(dn.x, 0.0, dn.y), "speed": speed}
	if launch_t > 0.0:
		var z: float = 0.5 * LAUNCH_ACCEL * launch_t * launch_t
		return {"nose": Vector3(side * SIDE_X, 0.0, z), "dir": Vector3(0, 0, 1), "speed": LAUNCH_ACCEL * launch_t}
	return {"nose": Vector3(side * SIDE_X, 0.0, 0.0), "dir": Vector3(0, 0, 1), "speed": 0.0}


static func _bez(p0: Vector2, p1: Vector2, p2: Vector2, s: float) -> Vector2:
	return p0 * (1.0 - s) * (1.0 - s) + p1 * 2.0 * (1.0 - s) * s + p2 * s * s


## Cumulative length of the curve at 64 even steps of its parameter (to move at a real speed along it).
static func _arc_lut(p0: Vector2, p1: Vector2, p2: Vector2) -> PackedFloat32Array:
	var lut := PackedFloat32Array([0.0])
	var prev: Vector2 = p0
	for i in range(1, 65):
		var p: Vector2 = _bez(p0, p1, p2, float(i) / 64.0)
		lut.append(lut[i - 1] + p.distance_to(prev))
		prev = p
	return lut


static func _s_at(lut: PackedFloat32Array, dist: float) -> float:
	for i in range(1, lut.size()):
		if lut[i] >= dist:
			var f: float = (dist - lut[i - 1]) / maxf(lut[i] - lut[i - 1], 0.0001)
			return (float(i - 1) + f) / float(lut.size() - 1)
	return 1.0


## Transform (studio local) of a TruckNode (origin = rear of the box, front = -Z) whose nose is at `pose`.
static func truck_xform(pose: Dictionary, front: float) -> Transform3D:
	var d: Vector3 = pose["dir"]
	var yaw: float = atan2(d.x, d.z) + PI                             # local -Z -> d
	return Transform3D(Basis(Vector3.UP, yaw), Vector3(pose["nose"]) - d * front)


# ---------------------------------------------------------------- camera

## Camera in the studio at intro time `t`: one slow push-in from the entrance to the bolt (tilting up to show the
## guardians), a small shake at the strike (none with "reduce flashes"), then the cut to a low lens between the
## trucks for the launch. Returns [position, look target, fov] in studio space.
static func studio_view(t: float, reduced: bool) -> Array:
	var launch0: float = DuelPlan.phase_start("launch")
	if t >= launch0:
		var p: float = clampf((t - launch0) / DuelPlan.phase_len("launch"), 0.0, 1.0)
		return [Vector3(0.0, lerpf(1.05, 0.9, p), lerpf(9.6, 10.6, p)), Vector3(0.0, lerpf(2.3, 2.6, p), -8.0), lerpf(64.0, 70.0, p)]
	var e: float = _ease(t / launch0)
	var up: float = _ease((t - DuelPlan.phase_start("guard") + 0.5) / 1.6)   # tilt up when the guardians appear
	var pos := Vector3(0.0, lerpf(1.7, 2.3, e), lerpf(19.0, 15.6, e))
	var look := Vector3(0.0, lerpf(2.5, 3.5, up), -4.0)
	var d: float = t - DuelPlan.BOLT_AT
	if not reduced and d >= 0.0 and d < 0.3:
		var amp: float = 0.09 * (1.0 - d / 0.3)
		pos += Vector3(sin(d * 97.0) * amp, cos(d * 83.0) * amp * 0.7, 0.0)
	return [pos, look, lerpf(48.0, 46.0, e)]


static func studio_camera(cam: Camera3D, t: float, reduced: bool) -> void:
	var v: Array = studio_view(t, reduced)
	_aim(cam, DuelStage.ORIGIN + Vector3(v[0]), DuelStage.ORIGIN + Vector3(v[1]), float(v[2]))


# ---------------------------------------------------------------- alignment on the track (countdown)

## 0..1 progress of the alignment shot (countdown from 3.0 to 3.0 - ALIGN_S); < 0 = not in the shot.
static func align_progress(countdown: float) -> float:
	var start: float = Protocol.COUNTDOWN_SECONDS
	if countdown > start or countdown < start - DuelPlan.ALIGN_S:
		return -1.0
	return (start - countdown) / DuelPlan.ALIGN_S


## Lateral offset (x units) and yaw (rad) of truck `i` while it pulls into its lane: trucks in the side lanes come
## from further out (the rival from the shoulder), the one in the centre lane straightens up. Short version only:
## after the full opening the trucks are already side by side on the grid (T-204).
static func align_offset(lane_x: float, progress: float) -> Vector2:
	if progress < 0.0:
		return Vector2.ZERO
	var rest: float = 1.0 - _ease(progress)
	var out: float = signf(lane_x) * 0.36 if absf(lane_x) > 0.1 else 0.1
	return Vector2(out * rest, out * rest * 0.35)


## Camera of the alignment shot: high behind the grid, centred on the trucks, coming down to the race camera.
static func align_camera(cam: Camera3D, path: TrackPath, z_front: float, x_mid: float, progress: float, end_pos: Vector3, end_look: Vector3) -> void:
	var e: float = _ease(progress)
	var p0: Vector3 = path.world_point(z_front - 22.0, x_mid, 10.5)
	var l0: Vector3 = path.world_point(z_front + 26.0, x_mid, 0.8)
	_aim(cam, p0.lerp(end_pos, e * e), l0.lerp(end_look, e * e), lerpf(58.0, 56.0, e))
