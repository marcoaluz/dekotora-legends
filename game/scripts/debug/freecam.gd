class_name Freecam
extends Node3D
## Explorer / free camera of the race (T-181). Presentation only: it never touches the simulation. While it is
## active the race scene skips its whole _process (race_scene_3d.gd), so the RaceSim, the bots and the visuals
## stay frozen in the same tick; switching it off gives the race camera back exactly where it was.
## Never created online (the server and the other players cannot be paused) nor without permission
## (FreecamMath.allowed: debug build, Settings.explorer_mode or --freecam).
## PC: F1 on/off, WASD move, Q/E down/up, right mouse button = look, Shift 4x, wheel = speed, T = go to km,
## P = screenshot in user://shots/, H = hide/show this overlay, Esc = leave. Touch: FreecamTouch.

signal toggled(on: bool)

const PICK_EVERY_S: float = 0.12

var active: bool = false
var speed: float = FreecamMath.SPEED_DEFAULT
var hud_visible: bool = true
var race: Node3D
var path: TrackPath
var race_cam: Camera3D
var route_id: String = ""
var route_name: String = ""
var time_id: String = ""
var cam: Camera3D
var picked: Dictionary = {}           # last FreecamPicker hit (empty = nothing under the crosshair)
var _yaw: float = 0.0
var _pitch: float = 0.0
var _looking: bool = false
var _layer: CanvasLayer
var _overlay: FreecamOverlay
var _picker: FreecamPicker
var _pick_t: float = 0.0
var _pick_xf: Transform3D
var _hidden_layers: Array[CanvasLayer] = []
var _master_muted: bool = false


## Creates the camera under `race_` when allowed (null otherwise). --freecam starts the race already in it.
static func attach(race_: Node3D, path_: TrackPath, race_cam_: Camera3D, route: RouteDef, tod: TimeOfDay, online: bool) -> Freecam:
	var flag: bool = "--freecam" in OS.get_cmdline_user_args()
	if online:
		if flag:
			print("FREECAM: desligada na corrida online (o servidor e os outros jogadores nao pausam)")
		return null
	var st: Node = race_.get_node_or_null("/root/Settings") if race_.is_inside_tree() else null
	var setting: bool = st != null and bool(st.get("explorer_mode"))
	if not FreecamMath.allowed(online, OS.is_debug_build(), setting, flag):
		return null
	var fc := Freecam.new()
	fc.name = "Freecam"
	fc.path = path_
	fc.race_cam = race_cam_
	fc.route_id = String(route.id) if route != null else "quick"
	fc.route_name = Tr.t(route.display_key) if route != null and route.display_key != "" else fc.route_id
	fc.time_id = String(tod.id) if tod != null else ""
	fc.race = race_
	race_.add_child(fc)
	if flag:
		fc.activate.call_deferred()
	return fc


func activate() -> void:
	if active or race_cam == null:
		return
	active = true
	if cam == null:
		_build()
	cam.near = race_cam.near
	cam.far = race_cam.far
	cam.fov = race_cam.fov
	cam.global_transform = race_cam.global_transform
	var e: Vector3 = race_cam.global_basis.get_euler(EULER_ORDER_YXZ)
	_yaw = e.y
	_pitch = clampf(e.x, -FreecamMath.PITCH_LIMIT, FreecamMath.PITCH_LIMIT)
	_apply_rotation()
	cam.make_current()
	_hide_world_layers()
	_master_muted = AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, true)                  # the race is frozen: no engine drone while exploring
	_layer.visible = true
	_overlay.set_hud(hud_visible)
	_pick_t = PICK_EVERY_S
	print("FREECAM: ligada em %s (%s)" % [FreecamMath.format_km(cam_track().x), route_id])
	toggled.emit(true)


func deactivate() -> void:
	if not active:
		return
	active = false
	_set_looking(false)
	_overlay.close_km()
	_layer.visible = false
	race_cam.make_current()
	for l in _hidden_layers:
		if is_instance_valid(l):
			l.visible = true
	_hidden_layers.clear()
	AudioServer.set_bus_mute(0, _master_muted)
	_picker.clear()                                    # frees the TriangleMesh caches
	picked = {}
	print("FREECAM: desligada")
	toggled.emit(false)


func toggle() -> void:
	if active:
		deactivate()
	else:
		activate()


## Camera to track distance `km` of the route, 6 m above the road, facing the driving direction.
func teleport_km(km: float) -> void:
	if cam == null or is_nan(km):
		return
	var pose: Array = FreecamMath.teleport_pose(path, FreecamMath.teleport_z(path, km))
	cam.global_position = pose[0]
	_yaw = float(pose[1])
	_pitch = float(pose[2])
	_apply_rotation()
	_pick_t = PICK_EVERY_S
	if _overlay != null:
		_overlay.toast(Tr.t("freecam.teleported", [FreecamMath.format_km(cam_track().x)]))


## (z along the track, lateral m, height above the road m) of the camera.
func cam_track() -> Vector3:
	return FreecamMath.nearest(path, cam.global_position) if cam != null else Vector3.ZERO


## user:// path the next screenshot gets (km of the camera + object under the crosshair).
func shot_path() -> String:
	var obj: String = String(picked.get("label", ""))       # "System > name" (e.g. Roadside3D > lamp_post #12)
	var base: String = String(picked.get("file", "")).get_file().get_basename()
	if base != "" and not obj.contains(base):
		obj = base + "_" + obj
	return "user://shots/" + FreecamMath.shot_file_name(route_id, cam_track().x, obj, FreecamMath.stamp(Time.get_datetime_dict_from_system()))


func save_shot() -> void:
	var file: String = shot_path()
	DirAccess.make_dir_recursive_absolute("user://shots")
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.save_png(file) != OK:
		_overlay.toast(Tr.t("freecam.shot_failed"))
		return
	print("FREECAM_SHOT: " + ProjectSettings.globalize_path(file))
	_overlay.toast(Tr.t("freecam.shot_saved", [file.get_file()]))


func toggle_hud() -> void:
	hud_visible = not hud_visible
	_overlay.set_hud(hud_visible)


func _build() -> void:
	cam = Camera3D.new()
	cam.name = "FreecamCamera"
	add_child(cam)
	_picker = FreecamPicker.new(race if race != null else get_parent(), self)
	_layer = CanvasLayer.new()
	_layer.layer = 40
	_layer.visible = false
	add_child(_layer)
	_overlay = FreecamOverlay.new()
	_overlay.cam = self
	_layer.add_child(_overlay)
	_overlay.exit_pressed.connect(deactivate)
	_overlay.km_pressed.connect(func() -> void: _overlay.open_km())
	_overlay.shot_pressed.connect(save_shot)
	_overlay.hud_pressed.connect(toggle_hud)
	_overlay.km_submitted.connect(teleport_km)


## Every CanvasLayer of the race (HUD, touch buttons, speed lines, cinema bars...) hides while exploring.
func _hide_world_layers() -> void:
	_hidden_layers.clear()
	var root: Node = race if race != null else get_parent()
	for n in root.find_children("*", "CanvasLayer", true, false):
		var l: CanvasLayer = n as CanvasLayer
		if l != _layer and l.visible and not is_ancestor_of(l):
			l.visible = false
			_hidden_layers.append(l)


func _apply_rotation() -> void:
	cam.global_basis = FreecamMath.basis_from(_yaw, _pitch)


func _set_looking(on: bool) -> void:
	_looking = on
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k: InputEventKey = event as InputEventKey
		if not k.pressed or k.echo:
			return
		if k.physical_keycode == KEY_F1:
			if active or not get_tree().paused:
				toggle()
			get_viewport().set_input_as_handled()
			return
		if not active:
			return
		if _overlay.km_open():                       # typing a km: only Esc is ours (Enter is the LineEdit's)
			if k.physical_keycode == KEY_ESCAPE:
				_overlay.close_km()
				get_viewport().set_input_as_handled()
			return
		match k.physical_keycode:
			KEY_ESCAPE:
				deactivate()
			KEY_T:
				_overlay.open_km()
			KEY_P:
				save_shot()
			KEY_H:
				toggle_hud()
			_:
				return
		get_viewport().set_input_as_handled()
	elif not active:
		return
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_set_looking(mb.pressed)
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			speed = FreecamMath.next_speed(speed, 1 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _looking:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		_yaw -= mm.relative.x * FreecamMath.MOUSE_SENS
		_pitch = clampf(_pitch - mm.relative.y * FreecamMath.MOUSE_SENS, -FreecamMath.PITCH_LIMIT, FreecamMath.PITCH_LIMIT)
		_apply_rotation()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not active:
		return
	var dt: float = minf(delta, 0.1)
	var touch: FreecamTouch = _overlay.touch
	var input := Vector3.ZERO
	var fast: bool = false
	if not _overlay.km_open():
		input.x = _key(KEY_D) - _key(KEY_A)
		input.z = _key(KEY_W) - _key(KEY_S)
		input.y = _key(KEY_E) - _key(KEY_Q)
		fast = Input.is_physical_key_pressed(KEY_SHIFT)
	if touch != null:
		input += Vector3(touch.move.x, touch.vertical, -touch.move.y)
		fast = fast or touch.fast
		if touch.look != Vector2.ZERO:
			_yaw -= touch.look.x * FreecamMath.STICK_LOOK_RATE.x * dt
			_pitch = clampf(_pitch - touch.look.y * FreecamMath.STICK_LOOK_RATE.y * dt, -FreecamMath.PITCH_LIMIT, FreecamMath.PITCH_LIMIT)
			_apply_rotation()
	var v: float = speed * (FreecamMath.FAST_MULT if fast else 1.0)
	cam.global_position += FreecamMath.velocity(cam.global_basis, input, v) * dt
	_picker.tick(dt)
	_pick_t += dt
	if _pick_t >= PICK_EVERY_S and (not cam.global_transform.is_equal_approx(_pick_xf) or _pick_t > 1.0):
		update_pick()
	_overlay.refresh(v)


## Ray from the centre of the screen (the crosshair) into the world.
func update_pick() -> void:
	_pick_t = 0.0
	_pick_xf = cam.global_transform
	picked = _picker.pick(cam.global_position, -cam.global_basis.z)


func _key(k: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(k) else 0.0
