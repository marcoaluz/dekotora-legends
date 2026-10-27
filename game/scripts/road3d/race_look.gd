class_name RaceLook
extends RefCounted
## T-241: "look back / left / right" while a button is held (presentation only, local; never touches the sim or the
## network). Works on top of any race camera (near, standard, far, cinema, orbit): the race camera keeps running
## underneath and this only overrides the final pose. Hold = look, release = back to the camera, with a short eased
## move that arcs over the truck when it crosses from behind to the front (never through the cab).
##  BACK : in front of the cab, chase-camera height, looking back over the truck (the decorated front + who chases).
##  LEFT/RIGHT: a crane shot from high on the OTHER side, looking across the truck's own roof (it stays at the bottom
##         of the picture, so the player knows where he is) to that side and a bit back (where an overtaker comes from).
## Inputs (see docs/DECISOES.md T-241): Q / E / X, right stick (left, right, down) + R3/RB on a controller, and the
## touch "eye" button (hold = back, slide left/right = sides).

enum Dir { NONE, BACK, LEFT, RIGHT }
const IDS: Array[String] = ["", "back", "left", "right"]

const IN_S: float = 0.24                   # eased move into a look
const OUT_S: float = 0.28                  # ... and back to the race camera
const CROSS_S: float = 0.34                # moves between behind and in front of the truck (~35 m): a bit longer
const ARC_CROSS_M: float = 3.2             # extra height in the middle of a move that crosses over the truck
const ARC_M: float = 0.6                   # ... and of any other move (a soft swing, not a straight slide)
const PRESS_MIN: float = 0.5               # analog strength that counts as "held" (sticks)
const TOUCH_SIDE: float = 0.9              # touch: slide more than radius x this to pick a side ...
const TOUCH_BACK: float = 0.55             # ... and come back under radius x this to return to BACK (hysteresis)
## Poses, track coords relative to the truck (metres): along the road from the front (BACK, sides), lateral, height.
const BACK_AHEAD_M: float = 11.0
const BACK_H: float = 6.0
const BACK_LOOK_BEHIND_M: float = 40.0     # look point behind the truck's rear
const SIDE_FROM_FRONT_M: float = 3.0       # camera this much behind the front (over the front of the box)
const SIDE_OUT_M: float = -3.5             # lateral offset from the truck's centre line (< 0 = the side NOT looked at)
const SIDE_H: float = 8.0                  # well over the box (~4 m) and any truck in the next lane
const SIDE_LOOK_BACK_M: float = 7.0        # look point: this much behind the camera ...
const SIDE_LOOK_OUT_M: float = 14.0        # ... and this much to the side of the truck (≈110° from straight ahead)
const BACK_FOV: float = 58.0
const SIDE_FOV: float = 60.0

var current: int = Dir.NONE                # direction shown (or being moved to)
var forced: int = Dir.NONE                 # --look= (screenshots): always this direction while racing
var weight: float = 0.0                    # 0 = race camera .. 1 = fully looking (tests, HUD badge, mirror)
var _t: float = 1.0                        # progress of the current move (1 = done)
var _dur: float = IN_S
var _from_pos: Vector3 = Vector3.ZERO      # relative to the anchor when the move started
var _from_look: Vector3 = Vector3.ZERO
var _from_fov: float = 56.0
var _from_w: float = 0.0
var _arc: float = 0.0
var _arc_pending: bool = false
var _lag_pos: Vector3 = Vector3.ZERO       # look camera position with the race camera's follow lag (RaceFeel)
var _lag_ok: bool = false
var _last: Array = []                      # [pos, look, fov] written last frame (empty = not overriding)


static func dir_from_id(id: String) -> int:
	var i: int = IDS.find(id)
	return i if i > 0 else Dir.NONE


## Keyboard/controller strengths -> direction. Back wins; left + right together also mean back (Q+E).
static func resolve(back: float, left: float, right: float) -> int:
	var l: bool = left >= PRESS_MIN
	var r: bool = right >= PRESS_MIN
	if back >= PRESS_MIN and back >= maxf(left, right):
		return Dir.BACK
	if l and r:
		return Dir.BACK
	if l or r:
		return Dir.LEFT if left >= right else Dir.RIGHT
	return Dir.BACK if back >= PRESS_MIN else Dir.NONE


## Touch: finger held on the eye button, `dx` = horizontal slide from where it was pressed (HUD units),
## `radius` = button radius, `prev` = direction of the last frame (hysteresis: no flicker on the border).
static func touch_dir(dx: float, radius: float, prev: int) -> int:
	var side: float = radius * (TOUCH_BACK if prev == Dir.LEFT or prev == Dir.RIGHT else TOUCH_SIDE)
	if dx <= -side:
		return Dir.LEFT
	if dx >= side:
		return Dir.RIGHT
	return Dir.BACK


## Target pose of a direction in track coords [pos(z, lat_m, h), look(z, lat_m, h)].
## `me` = Vector3(rear z, lateral metres, length) of the player truck.
static func local_pose(dir: int, me: Vector3) -> Array[Vector3]:
	var front: float = me.x + me.z
	match dir:
		Dir.BACK:
			return [Vector3(front + BACK_AHEAD_M, me.y, BACK_H), Vector3(me.x - BACK_LOOK_BEHIND_M, me.y, 1.2)]
		Dir.LEFT, Dir.RIGHT:
			var s: float = -1.0 if dir == Dir.LEFT else 1.0
			var cz: float = front - SIDE_FROM_FRONT_M
			return [Vector3(cz, me.y + s * SIDE_OUT_M, SIDE_H),
					Vector3(cz - SIDE_LOOK_BACK_M, me.y + s * SIDE_LOOK_OUT_M, 0.5)]
	return [Vector3(me.x - 14.0, me.y, 5.6), Vector3(front + 14.0, me.y, 1.8)]


## World target [pos, look] of a direction: the camera point goes through the T-198 limits (barriers, tunnel arch,
## toll canopy); the "keep out of the player's box" push is skipped when the point is already above the box.
static func world_target(rig: RaceCamRig, dir: int, me: Vector3) -> Array:
	var lp: Array[Vector3] = local_pose(dir, me)
	var body: Vector3 = me if lp[0].z < RaceCamRig.BODY_TOP_H else Vector3(me.x, me.y, 0.0)
	var p: Vector3 = rig.clamp_point(lp[0], body)
	return [rig.to_world(p), rig.to_world(lp[1])]


static func fov_of(dir: int) -> float:
	return BACK_FOV if dir == Dir.BACK else SIDE_FOV


func looking() -> bool:
	return current != Dir.NONE and weight > 0.0


## Drop everything at once (cuts, intro, result, pause camera): the next look starts from the race camera.
func reset() -> void:
	current = Dir.NONE
	weight = 0.0
	_t = 1.0
	_last = []
	_lag_ok = false


## One frame. `want` = wanted direction; `base` = [pos, look, fov] of the race camera this frame (world);
## `target` = [pos, look] of the `want` pose in world space (ignored for NONE); `anchor` = truck middle (world);
## `fwd` = road forward at the truck; `follow_rate` = RaceFeel camera lag (1/s).
## Returns [pos, look, fov] to put on the camera, or [] when the race camera is left alone.
func update(dt: float, want: int, allowed: bool, base: Array, target: Array, anchor: Vector3, fwd: Vector3,
		follow_rate: float) -> Array:
	if forced != Dir.NONE:
		want = forced
	if not allowed:
		reset()
		return []
	if want != current:
		var start: Array = _last if not _last.is_empty() else base
		_from_pos = (start[0] as Vector3) - anchor
		_from_look = (start[1] as Vector3) - anchor
		_from_fov = float(start[2])
		_from_w = weight
		current = want
		_t = 0.0
		_dur = IN_S if want != Dir.NONE else OUT_S
		_arc_pending = true
		_lag_ok = false
	if current == Dir.NONE and _t >= 1.0:
		_last = []
		weight = 0.0
		return []
	var to_pos: Vector3
	var to_look: Vector3
	var to_fov: float
	if current == Dir.NONE:
		to_pos = base[0]
		to_look = base[1]
		to_fov = float(base[2])
	else:
		var tp: Vector3 = target[0]
		if not _lag_ok:
			_lag_pos = tp
			_lag_ok = true
		else:
			_lag_pos = _lag_pos.lerp(tp, 1.0 - exp(-follow_rate * dt))
		to_pos = _lag_pos
		to_look = target[1]
		to_fov = fov_of(current)
	if _arc_pending:
		var a: float = _from_pos.dot(fwd)
		var b: float = (to_pos - anchor).dot(fwd)
		var crossing: bool = signf(a) != signf(b)
		_arc = ARC_CROSS_M if crossing else ARC_M
		if crossing:
			_dur = CROSS_S
		_arc_pending = false
	_t = minf(_t + dt / _dur, 1.0)
	var e: float = smoothstep(0.0, 1.0, _t)
	var pos: Vector3 = (anchor + _from_pos).lerp(to_pos, e) + Vector3.UP * _arc * sin(PI * e)
	var look: Vector3 = (anchor + _from_look).lerp(to_look, e)
	var fov: float = lerpf(_from_fov, to_fov, e)
	weight = lerpf(_from_w, 1.0 if current != Dir.NONE else 0.0, e)
	if current == Dir.NONE and _t >= 1.0:
		_last = []
		weight = 0.0
		return [to_pos, to_look, to_fov]
	_last = [pos, look, fov]
	return _last
