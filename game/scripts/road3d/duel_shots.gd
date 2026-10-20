class_name DuelShots
extends RefCounted
## Camera work of the face-to-face opening (T-156): shots on the DuelStage and the alignment shot on the track at
## the start of the countdown. Pure math over nodes (no state), so the race scene and the tests share it.

## Height factor of the small Canter (its cab is ~2.1 m tall instead of ~3 m).
static func height_k(truck: TruckNode) -> float:
	return 0.74 if truck.body_kind == "canter" else 1.0


## Metres from the rear of the truck (node origin) to its nose.
static func front_len(truck: TruckNode) -> float:
	return 11.4 + truck.front_delta()


static func _aim(cam: Camera3D, pos: Vector3, look: Vector3, fov: float) -> void:
	if cam.is_inside_tree():
		cam.global_position = pos
		cam.look_at(look, Vector3.UP)
	else:
		cam.position = pos
	cam.fov = fov


static func _ease(x: float) -> float:
	var c: float = clampf(x, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


## Camera on the stage for `phase` (face / player / rival / vs) at progress `p`.
static func stage_camera(cam: Camera3D, stage: DuelStage, trucks: Array[TruckNode], pair: Array[int], phase: String, p: float) -> void:
	var o: Vector3 = DuelStage.ORIGIN
	match phase:
		"face":                                                    # wide side view, both noses, slow dolly
			var e: float = _ease(p)
			_aim(cam, o + Vector3(lerpf(-6.0, 5.0, e), lerpf(1.4, 2.4, e), lerpf(20.0, 18.0, e)), o + Vector3(0, 1.9, 0), 50.0)
		"player", "rival":
			var n: int = 0 if phase == "player" else 1
			var k: int = pair[n]
			if k < 0 or k >= trucks.size():
				return
			var d: Array = DuelPlan.detail_at(phase, p)
			detail_camera(cam, trucks[k], String(d[0]), float(d[1]), 1.0 if n == 0 else -1.0)
		"vs":                                                      # centred between the noses, pushing in
			var e2: float = _ease(p * 1.2)
			_aim(cam, o + Vector3(0.0, lerpf(2.2, 2.9, e2), lerpf(15.5, 11.0, e2)), o + Vector3(0, 2.0, 0), 50.0)


## Detail shot of one truck (in its own space: nose at z = -front, camera on the local `side` of X).
## bumper = low 3/4 between the noses; visor = high, visor and front andon; mural = sliding along the box side.
static func detail_camera(cam: Camera3D, truck: TruckNode, detail: String, q: float, side: float) -> void:
	var f: float = front_len(truck)
	var hk: float = height_k(truck)
	var xf: Transform3D = truck.global_transform if truck.is_inside_tree() else truck.transform
	var e: float = _ease(q)
	var pos: Vector3
	var look: Vector3
	var fov: float = 42.0
	match detail:
		"bumper":
			pos = Vector3(side * lerpf(3.3, 2.5, e), 0.95 * hk, -f - lerpf(1.1, 1.7, e))
			look = Vector3(0.0, 0.8 * hk, -f + 0.5)
		"visor":
			pos = Vector3(side * lerpf(2.6, 1.9, e), lerpf(4.3, 4.8, e) * hk, -f - 1.5)
			look = Vector3(0.0, 2.85 * hk, -f + 0.9)
			fov = 46.0
		_:                                                         # mural
			var zb: float = -(f - 3.4) * 0.5
			pos = Vector3(side * 7.0, 2.1 * hk, zb + lerpf(2.6, -2.6, e))
			look = Vector3(side * 1.2, 1.9 * hk, zb + lerpf(1.2, -1.2, e))
			fov = 48.0
	_aim(cam, xf * pos, xf * look, fov)


# ---------------------------------------------------------------- alignment on the track (countdown)

## 0..1 progress of the alignment shot (countdown from 3.0 to 3.0 - ALIGN_S); < 0 = not in the shot.
static func align_progress(countdown: float) -> float:
	var start: float = Protocol.COUNTDOWN_SECONDS
	if countdown > start or countdown < start - DuelPlan.ALIGN_S:
		return -1.0
	return (start - countdown) / DuelPlan.ALIGN_S


## Lateral offset (x units) and yaw (rad) of truck `i` while it pulls into its lane: trucks in the side lanes come
## from further out (the rival from the shoulder), the one in the centre lane straightens up.
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
