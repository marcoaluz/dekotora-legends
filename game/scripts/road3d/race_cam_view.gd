class_name RaceCamView
extends Node
## T-198: glue between the race scene and the camera modes / rear mirror (presentation only, local).
## Keys: C = next camera, R = mirror on/off (input actions camera_next / rear_mirror). Touch/mouse: camera icon on the
## HUD, tap on the mirror. Remembers the choice (Settings.race_cam, per route in Settings.race_cam_routes).
## T-241: look back / left / right while held (RaceLook) on top of any camera; the mirror hides while looking.

const LETTERBOX_FRAC: float = 0.085        # each black bar of the cinema camera (fraction of the screen height)

var rig: RaceCamRig
var mirror: RearMirror
var button: RaceCamButton
var route_id: String = ""
var anchor_node: Node3D                    # player truck (the blend follows it)
var _bars: Array[ColorRect] = []
var _bars_on: bool = true
var _bars_k: float = 0.0
var _save: bool = true                     # --race-cam= / --mirror= (captures) do not touch the saved settings
var look := RaceLook.new()                 # T-241
var look_badge: RaceLookBadge
var _base_xf: Transform3D                  # race camera pose before the look override (restored next frame)
var _base_fov: float = 56.0
var _restore: bool = false


## Mirror "automatic": on in the PC (medium and up), on in the phone only at high quality.
static func mirror_auto_on(q: int, mobile: bool) -> bool:
	return q >= 2 or (q == 1 and not mobile)


static func mirror_on(mode: int, q: int, mobile: bool) -> bool:
	if mode == 1:
		return true
	if mode == 2:
		return false
	return mirror_auto_on(q, mobile)


## Camera the race starts with: the one used last time on this route, else the last one chosen.
static func initial_mode(route: String, per_route: Dictionary, last: String) -> int:
	if route != "" and per_route.has(route):
		return RaceCamRig.mode_from_id(String(per_route[route]))
	return RaceCamRig.mode_from_id(last)


## hud_layer = the race CanvasLayer (480x270 scaled 2x). mirror_top = HUD y of the mirror.
func setup(path: TrackPath, events: TrackEvents, tunnels: Array[Vector2], route: String, hud_layer: CanvasLayer,
		effects_parent: Node, mirror_top: float, q: int, touch: bool, env: Environment) -> void:
	route_id = route
	rig = RaceCamRig.new(path, events, tunnels)
	rig.mode = initial_mode(route, Settings.race_cam_routes, Settings.race_cam)
	var mirror_wanted: bool = mirror_on(Settings.mirror_mode, q, OS.has_feature("mobile"))
	_bars_on = Settings.cam_letterbox
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--race-cam="):
			rig.mode = RaceCamRig.mode_from_id(a.substr(11))
			_save = false
		elif a.begins_with("--mirror="):
			mirror_wanted = a.substr(9) == "on"
			_save = false
		elif a.begins_with("--cine-shot="):
			rig.director.forced = a.substr(12)
		elif a == "--letterbox=off":
			_bars_on = false
		elif a.begins_with("--look="):                 # T-241 screenshots: always looking this way while racing
			look.forced = RaceLook.dir_from_id(a.substr(7))
	# letterbox (between the world and the HUD, like the tunnel flash)
	var bl := CanvasLayer.new()
	bl.layer = 4
	effects_parent.add_child(bl)
	for i in 2:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.visible = false
		bl.add_child(b)
		_bars.append(b)
	mirror = RearMirror.new()
	mirror.show_tab = touch
	hud_layer.add_child(mirror)
	hud_layer.move_child(mirror, 0)                   # under the HUD texts (banners draw over it)
	mirror.setup(mirror_top, q)
	mirror.use_environment(env)
	mirror.enabled = mirror_wanted
	mirror.toggled.connect(_on_mirror_toggled)
	button = RaceCamButton.new()
	hud_layer.add_child(button)
	button.position = Vector2(6, 52)                  # under the position panel (top left)
	button.pressed.connect(cycle)
	look_badge = RaceLookBadge.new()
	hud_layer.add_child(look_badge)
	look_badge.visible = false
	look_badge.position.y = mirror_top


## Centres the mirror on the HUD width (the HUD is wider on long phones).
func layout(hud_width: float) -> void:
	if mirror != null:
		mirror.position.x = roundf(hud_width * 0.5 - RearMirror.RECT_SIZE.x * 0.5)
	if look_badge != null:
		look_badge.position.x = roundf(hud_width * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_next"):
		cycle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rear_mirror"):
		mirror.set_enabled(not mirror.enabled)
		get_viewport().set_input_as_handled()


## Next camera (C / icon). The blend starts from the current camera pose.
func cycle() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var anchor: Vector3 = _anchor()
	var xf: Transform3D = _base_xf if _restore else (cam.global_transform if cam != null else Transform3D())
	var pos: Vector3 = xf.origin if cam != null else anchor        # T-241: the race camera, not the look pose
	var look_pt: Vector3 = pos - xf.basis.z * 20.0 if cam != null else anchor
	var fov: float = (_base_fov if _restore else cam.fov) if cam != null else 56.0
	rig.set_mode(RaceCamRig.next_mode(rig.mode), pos, look_pt, fov, anchor)
	button.show_name(Tr.t("cam." + rig.id()))
	if _save:
		Settings.race_cam = rig.id()
		if route_id != "":
			Settings.race_cam_routes[route_id] = rig.id()
		Settings.save_settings()



func _anchor() -> Vector3:
	return anchor_node.global_position if anchor_node != null and anchor_node.is_inside_tree() else Vector3.ZERO


func _on_mirror_toggled(on: bool) -> void:
	if _save:
		Settings.mirror_mode = 1 if on else 2
		Settings.save_settings()


## Free modes (cinema/orbit): places the camera. Returns false for the chase modes (race_scene does those).
func apply_free(dt: float, cam: Camera3D, me: Vector3, speed: float, rival: Vector3) -> bool:
	if rig.is_chase():
		return false
	var p: Array = rig.free_pose(dt, me, speed, rival)
	var b: Array = rig.blend(p[0], p[1], p[2], _anchor(), dt)
	cam.global_position = b[0]
	cam.look_at(b[1], Vector3.UP)
	cam.fov = lerpf(cam.fov, float(b[2]), 1.0 if rig.director.shot_t < 0.05 and not rig.blending() else minf(4.0 * dt, 1.0))
	return true


## Letterbox in and out (cinema only) and the mirror state. `racing` = race running (not intro, countdown, result).
func update(dt: float, racing: bool, cut: bool, path: TrackPath, z: float, x: float, behind_gap: float,
		is_rival: bool) -> void:
	var want: float = 1.0 if racing and rig.mode == RaceCamRig.Mode.CINEMA and _bars_on else 0.0
	_bars_k = move_toward(_bars_k, want, dt * 2.5)
	var vs: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(960, 540)
	var hgt: float = roundf(vs.y * LETTERBOX_FRAC * smoothstep(0.0, 1.0, _bars_k))
	for i in _bars.size():
		_bars[i].visible = hgt > 0.0
		_bars[i].size = Vector2(vs.x, hgt)
		_bars[i].position = Vector2(0, 0.0 if i == 0 else vs.y - hgt)
	mirror.set_allowed(racing and not cut and rig.mode != RaceCamRig.Mode.CINEMA and not look.looking())
	if look_badge != null and mirror != null:
		look_badge.position.y = mirror.position.y
	mirror.update(dt, path, z, x, behind_gap, is_rival)


## T-241: puts back the race camera pose that the look override replaced last frame (the chase camera follows from
## its own position: without this it would start from the look pose). Call before the race camera runs.
func restore_base(cam: Camera3D) -> void:
	if _restore:
		cam.global_transform = _base_xf
		cam.fov = _base_fov
		_restore = false


## T-241: look back / left / right over the race camera already placed on `cam` this frame. `want` = RaceLook.Dir,
## `allowed` = race running and no cut; `me` = Vector3(rear z, lateral m, length) of the player; `shake_m` = the
## impact shake of the chase camera (RaceFeel, already scaled by "Reduzir tremor"); `follow_rate` = its lag (1/s).
func apply_look(dt: float, cam: Camera3D, want: int, allowed: bool, me: Vector3, shake_m: float,
		follow_rate: float) -> void:
	var mid: float = me.x + me.z * 0.5
	var anchor: Vector3 = rig.to_world(Vector3(mid, me.y, 0.0))
	var base: Array = [cam.global_position, cam.global_position - cam.global_basis.z * 20.0, cam.fov]
	var target: Array = []
	var w: int = look.forced if look.forced != RaceLook.Dir.NONE else want
	if allowed and w != RaceLook.Dir.NONE:
		var lp: Array[Vector3] = RaceLook.local_pose(w, me)
		target = [rig.to_world(rig.clamp_point(lp[0], me)), rig.to_world(lp[1])]
	var out: Array = look.update(dt, want, allowed, base, target, anchor, rig.path.forward_at(mid), follow_rate)
	if look_badge != null:
		look_badge.show_dir(look.current, look.weight)
	if out.is_empty():
		return
	_base_xf = cam.global_transform
	_base_fov = cam.fov
	_restore = true
	var pos: Vector3 = out[0]
	var s: float = shake_m * look.weight
	if s > 0.0:
		pos += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	cam.global_position = pos
	var d: Vector3 = (out[1] as Vector3) - pos
	if d.length_squared() > 0.01 and absf(d.normalized().dot(Vector3.UP)) < 0.995:
		cam.look_at(out[1], Vector3.UP)
	cam.fov = float(out[2])
