class_name RaceCamDirector
extends RefCounted
## T-198: CINEMA camera. A small "director" that cuts between dramatic shots every few seconds: low side travelling,
## low front shot on the dekotora face, long lens from behind, crane, rival shots, and an automatic cut when somebody
## overtakes. Inside a shot the camera only moves slowly (no shake) so it does not make anyone sick.
## Shots are built in track coordinates (z, lateral m, height) and clamped by RaceCamRig.

const SHOTS: Array[String] = ["side_low", "front_low", "tele_rear", "crane", "rival"]
const SHOT_MIN_S: float = 4.5
const SHOT_MAX_S: float = 7.0
const OVERTAKE_S: float = 3.2
const RIVAL_NEAR_M: float = 90.0           # rival shot only when the rival is this close
const OVERTAKE_GAP_M: float = 25.0
const MIN_CUT_GAP_S: float = 1.5           # no overtake cut right after another cut

var shot: String = ""
var shot_t: float = 0.0
var shot_len: float = 1.0
var side: float = 1.0                      # +1 = camera on the right of the truck
var cuts: int = 0                          # number of cuts so far (tests, captures)
var forced: String = ""                    # --cine-shot=NAME (captures): always this shot
var _rng := RandomNumberGenerator.new()
var _last_gap: float = NAN


func _init() -> void:
	_rng.seed = 198


func reset() -> void:
	shot = ""
	shot_t = 0.0
	_last_gap = NAN


## me / rival = Vector3(z, lat_m, length); rival.x = NAN when there is no rival. Returns [pos, look, fov] (track coords).
func update(dt: float, me: Vector3, speed: float, rival: Vector3, rig: RaceCamRig) -> Array:
	var has_rival: bool = not is_nan(rival.x)
	var gap: float = (rival.x - me.x) if has_rival else NAN
	if shot == "":
		_cut(_pick(has_rival and absf(gap) < RIVAL_NEAR_M), me, rig, rival)
	else:
		shot_t += dt
		var overtook: bool = has_rival and not is_nan(_last_gap) and signf(gap) != signf(_last_gap) \
				and absf(gap) < OVERTAKE_GAP_M
		if overtook and shot != "overtake" and shot_t > MIN_CUT_GAP_S and forced == "":
			_cut("overtake", me, rig, rival)
		elif shot_t >= shot_len or (shot == "rival" and not (has_rival and absf(gap) < RIVAL_NEAR_M * 1.3)):
			_cut(_pick(has_rival and absf(gap) < RIVAL_NEAR_M), me, rig, rival)
	_last_gap = gap
	return pose(shot, clampf(shot_t / shot_len, 0.0, 1.0), me, rival, speed)


func _pick(rival_ok: bool) -> String:
	if forced != "":
		return forced
	var options: Array[String] = []
	for s in SHOTS:
		if s != shot and (s != "rival" or rival_ok):
			options.append(s)
	if rival_ok and shot != "rival" and _rng.randf() < 0.35:     # the duel is the point: show the rival often
		return "rival"
	return options[_rng.randi() % options.size()]


func _cut(next: String, me: Vector3, rig: RaceCamRig, rival: Vector3) -> void:
	shot = next
	shot_t = 0.0
	shot_len = OVERTAKE_S if next == "overtake" else _rng.randf_range(SHOT_MIN_S, SHOT_MAX_S)
	cuts += 1
	# side with more room between the truck and the barrier (narrow sections, shoulder lane)
	var prof: Vector3 = LaneSections.profile(rig.events, me.x + me.z * 0.5) if rig != null else Vector3(13, 13, 5)
	var room_r: float = prof.y - me.y
	var room_l: float = prof.x + me.y
	side = 1.0 if room_r >= room_l else -1.0
	if absf(room_r - room_l) < 3.0:
		side = 1.0 if _rng.randf() < 0.5 else -1.0
	if next == "overtake" and not is_nan(rival.x) and absf(rival.y - me.y) > 1.0:
		side = -signf(rival.y - me.y)                            # outside the pair, never on top of the rival


## Camera of a shot at progress u (0..1). Pure function of its inputs (tests).
func pose(name: String, u: float, me: Vector3, rival: Vector3, speed: float) -> Array:
	var mid: float = me.x + me.z * 0.5
	var e: float = smoothstep(0.0, 1.0, u)
	match name:
		"side_low":       # low travelling on the side: the truck slowly overtakes the camera
			return [Vector3(mid + lerpf(me.z * 0.7, -me.z * 0.6, e), me.y + side * 10.0, 1.1),
					Vector3(mid, me.y, 1.9), 46.0]
		"front_low":      # low in front, looking back at the face of the truck (andon, bumper, visor)
			return [Vector3(me.x + me.z + lerpf(16.0, 10.0, e), me.y + side * 1.8, 1.0),
					Vector3(mid + me.z * 0.15, me.y, 2.3), 44.0]
		"tele_rear":      # long lens from far behind: compresses the road and the traffic
			return [Vector3(me.x - lerpf(50.0, 42.0, e), me.y * 0.5 + side * 2.0, 3.2),
					Vector3(mid, me.y, 2.0), 19.0]
		"crane":          # rising crane on the side
			return [Vector3(mid - lerpf(12.0, -4.0, e), me.y + side * 6.0, lerpf(8.0, 13.0, e)),
					Vector3(mid + 6.0, me.y, 1.2), 50.0]
		"rival":          # over the shoulder of the player towards the rival (ahead or behind)
			if not is_nan(rival.x):
				var rmid: float = rival.x + rival.z * 0.5
				var ahead: bool = rival.x >= me.x
				var cz: float = me.x - 7.0 if ahead else me.x + me.z + 9.0
				var dist: float = absf(rmid - cz)
				var fov: float = clampf(rad_to_deg(2.0 * atan2(6.0, maxf(dist, 1.0))), 14.0, 40.0)
				return [Vector3(cz + lerpf(0.0, 2.0, e) * (1.0 if ahead else -1.0), me.y + side * 3.2, 2.6),
						Vector3(rmid, rival.y, 2.0), fov]
		"overtake":       # side shot between the two trucks
			if not is_nan(rival.x):
				var m2: float = (mid + rival.x + rival.z * 0.5) * 0.5
				var outer: float = me.y + side * 8.0
				return [Vector3(m2 - lerpf(-6.0, 6.0, e), outer, 1.6), Vector3(m2, (me.y + rival.y) * 0.5, 2.0), 50.0]
	return pose("side_low", u, me, rival, speed)
