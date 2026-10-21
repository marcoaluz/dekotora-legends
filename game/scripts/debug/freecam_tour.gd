class_name FreecamTour
extends Node
## T-186: automatic tour of the explorer camera (captures for review, no keyboard needed). With
## `--freecam-tour=FOLDER --tour=NAME@KM,LAT,H,YAW,PITCH;...` the race opens in the free camera, goes to each pose
## (KM along the route, LAT metres to the right, H metres above the road, YAW/PITCH degrees relative to the driving
## direction), waits for the frame to settle, saves FOLDER/<route>_<NAME>.png WITH the overlay (FPS, draw calls)
## and prints a TOUR line (average draw calls, triangles and FPS of the last frames). Quits after the last pose.

const SETTLE_FRAMES: int = 70
const MEASURE_FRAMES: int = 40

var fc: Freecam
var out_dir: String = ""
var poses: Array = []          # [name, km, lat, h, yaw_deg, pitch_deg]
var _i: int = -1
var _frame: int = 0
var _acc: Vector3 = Vector3.ZERO   # draw calls, triangles, fps


## Creates the tour under the free camera when --freecam-tour= is given.
static func maybe_attach(fc_: Freecam) -> void:
	var out: String = ""
	var spec: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--freecam-tour="):
			out = a.substr(15)
		elif a.begins_with("--tour="):
			spec = a.substr(7)
	if out == "" or spec == "":
		return
	var t := FreecamTour.new()
	t.fc = fc_
	t.out_dir = out
	t.poses = parse(spec)
	fc_.add_child(t)


## "name@km,lat,h,yaw,pitch;..." -> [[name, km, lat, h, yaw, pitch], ...] (missing numbers = 0).
static func parse(spec: String) -> Array:
	var out: Array = []
	for item in spec.split(";", false):
		var parts: PackedStringArray = item.split("@")
		if parts.size() != 2:
			continue
		var n: PackedFloat64Array = parts[1].split_floats(",")
		while n.size() < 5:
			n.append(0.0)
		out.append([parts[0], n[0], n[1], n[2], n[3], n[4]])
	return out


func _process(_dt: float) -> void:
	if fc == null or not fc.active or fc.cam == null:
		return
	if _i < 0 or _frame >= SETTLE_FRAMES + MEASURE_FRAMES:
		if _i >= 0:
			_finish_pose()
		_i += 1
		if _i >= poses.size():
			get_tree().quit()
			return
		_go(poses[_i])
		_frame = 0
		_acc = Vector3.ZERO
		return
	_frame += 1
	if _frame > SETTLE_FRAMES:
		_acc += Vector3(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Engine.get_frames_per_second())


func _go(p: Array) -> void:
	var path: TrackPath = fc.path
	var z: float = FreecamMath.teleport_z(path, float(p[1]))
	fc.cam.global_position = path.world_point(z, float(p[2]) / Track.ROAD_HALF_WIDTH_M, float(p[3]))
	fc.cam.global_basis = FreecamMath.basis_from(path.yaw_at(z) + deg_to_rad(float(p[4])), deg_to_rad(float(p[5])))
	fc.update_pick()


func _finish_pose() -> void:
	var p: Array = poses[_i]
	var m: Vector3 = _acc / float(MEASURE_FRAMES)
	print("TOUR %s %s km=%.2f draw=%d tri=%d fps=%d" % [fc.route_id, p[0], float(p[1]), roundi(m.x), roundi(m.y), roundi(m.z)])
	if DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(out_dir)
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(out_dir.path_join("%s_%s.png" % [fc.route_id, p[0]]))
