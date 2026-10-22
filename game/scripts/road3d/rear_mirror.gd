class_name RearMirror
extends Control
## T-198: rear-view mirror on the race HUD (presentation only, local; nothing goes to the sim or the network).
## A SubViewport shares the race World3D and a Camera3D on the back of the player's box looks backwards. The image is
## small (VIEW_SIZE), mirrored, updated at FPS times per second (not every frame) and drawn with a light copy of the
## environment (no SSAO/SSIL/SSR/SDFGI/volumetric fog, no shadows of street lamps, no MSAA): the scene is drawn a
## second time, so everything here is about keeping that second pass cheap.

signal toggled(on: bool)

const VIEW_SIZE := Vector2i(288, 84)       # pixels of the mirror image
const RECT_SIZE := Vector2(144, 42)        # HUD units (480x270 layer scaled 2x: 1 image pixel per screen pixel at 960x540)
const FRAME_W: float = 3.0
const FOV: float = 24.0                    # vertical; the wide image gives ~70 degrees across
const FAR_M: float = 260.0                 # the mirror does not need the 8 km mountains
const CAM_H: float = 3.0
const CAM_BACK_M: float = 0.4              # behind the rear doors (z = rear of the truck)
const LOOK_BACK_M: float = 35.0
const ALERT_M: float = 45.0                # border lights up when a truck is this close behind
const CLOSE_M: float = 14.0
const ENV_SYNC_S: float = 0.25
const GOLD := Color("#f5cc5a")
const PINK := Color("#ff2e88")
const TAB_SIZE := Vector2(30, 10)
## Environment values copied from the race environment (tunnels and time of day change them).
const ENV_SYNC: Array[String] = ["background_energy_multiplier", "background_color", "ambient_light_color",
		"ambient_light_energy", "ambient_light_sky_contribution", "fog_enabled", "fog_density", "fog_light_color",
		"fog_light_energy", "fog_sky_affect", "tonemap_exposure", "tonemap_white"]

var enabled: bool = false                  # player's choice (R key, tap, Options)
var allowed: bool = false                  # the race decides: hidden in the intro, countdown cuts, cinema, result
var show_tab: bool = false                 # touch: small tab to turn it back on
var fps: float = 25.0
var frames_rendered: int = 0               # tests / measurements
var _vp: SubViewport
var _cam: Camera3D
var _tex: TextureRect
var _acc: float = 0.0
var _env_acc: float = 0.0
var _src_env: Environment
var _env: Environment
var _alert: float = 0.0                    # 0..1 border glow
var _alert_rival: bool = false
var _font: Font


## Builds the mirror. `top` = HUD y of the mirror; `q` = Settings.quality (Ultra refreshes faster).
func setup(top: float, q: int) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = RECT_SIZE
	position = Vector2(0, top)
	fps = 30.0 if q >= UltraLook.ULTRA else 25.0
	_vp = SubViewport.new()
	_vp.size = VIEW_SIZE
	_vp.msaa_3d = Viewport.MSAA_DISABLED
	_vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	_vp.use_taa = false
	_vp.positional_shadow_atlas_size = 0         # no street-lamp shadows in the mirror
	_vp.mesh_lod_threshold = 6.0                 # coarser LODs (the image is tiny)
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.audio_listener_enable_3d = false
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = FOV
	_cam.near = 0.4
	_cam.far = FAR_M
	_vp.add_child(_cam)
	_cam.current = true
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.flip_h = true                           # a mirror: what is behind on the left shows on the left
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tex.position = Vector2(FRAME_W, FRAME_W)
	_tex.size = RECT_SIZE - Vector2(FRAME_W, FRAME_W) * 2.0
	add_child(_tex)
	_font = UiTheme.heading_font(true)
	_refresh_visibility()


## Light copy of the race environment (same sky and fog, none of the expensive screen effects).
func use_environment(src: Environment) -> void:
	_src_env = src
	if src == null:
		return
	_env = src.duplicate() as Environment
	_env.ssao_enabled = false
	_env.ssil_enabled = false
	_env.ssr_enabled = false
	_env.sdfgi_enabled = false
	_env.volumetric_fog_enabled = false
	_cam.environment = _env


func set_enabled(on: bool) -> void:
	if on == enabled:
		return
	enabled = on
	_refresh_visibility()
	toggled.emit(on)


func set_allowed(on: bool) -> void:
	if on == allowed:
		return
	allowed = on
	_refresh_visibility()


func active() -> bool:
	return enabled and allowed


func _refresh_visibility() -> void:
	visible = allowed and (enabled or show_tab)
	if _tex != null:
		_tex.visible = enabled
	if not active() and _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	queue_redraw()


## Places the camera (track coords of the player: rear z, x in road units) and renders a new image when it is time.
## `behind_gap` = metres to the closest truck behind (INF = none), `is_rival` = that truck is the route rival.
func update(dt: float, path: TrackPath, z: float, x: float, behind_gap: float, is_rival: bool) -> void:
	var target: float = 0.0
	if behind_gap < ALERT_M:
		target = clampf(1.0 - (behind_gap - CLOSE_M) / (ALERT_M - CLOSE_M), 0.25, 1.0)
	_alert = move_toward(_alert, target, dt * 3.0)
	_alert_rival = is_rival
	if _alert > 0.0 or target > 0.0:
		queue_redraw()
	if not active():
		return
	_acc += dt
	_env_acc += dt
	if _env_acc >= ENV_SYNC_S and _env != null and _src_env != null:
		_env_acc = 0.0
		for p in ENV_SYNC:
			_env.set(p, _src_env.get(p))
	if _acc < 1.0 / fps:
		return                                   # UPDATE_ONCE goes back to DISABLED by itself after one image
	_acc = fmod(_acc, 1.0 / fps)
	var pos: Vector3 = path.world_point(z - CAM_BACK_M, x, CAM_H)
	var look: Vector3 = path.world_point(z - LOOK_BACK_M, x * 0.8, 1.0)
	_cam.global_position = pos
	_cam.look_at(look, Vector3.UP)
	_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	frames_rendered += 1


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton      # touch arrives as an emulated mouse click
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		set_enabled(not enabled)
		accept_event()


func _has_point(p: Vector2) -> bool:
	if enabled:
		return Rect2(Vector2.ZERO, RECT_SIZE).grow(4.0).has_point(p)
	return _tab_rect().grow(6.0).has_point(p)


func _tab_rect() -> Rect2:
	return Rect2((RECT_SIZE.x - TAB_SIZE.x) * 0.5, 0.0, TAB_SIZE.x, TAB_SIZE.y)


func _draw() -> void:
	if not enabled:
		if show_tab:                                     # collapsed: small mirror tab (tap to open)
			var t: Rect2 = _tab_rect()
			draw_rect(t, Color(0.03, 0.04, 0.09, 0.55))
			draw_rect(t, Color(1, 1, 1, 0.45), false, 1.0)
			draw_rect(Rect2(t.position + Vector2(8, 3), Vector2(14, 4)), Color(0.55, 0.7, 0.85, 0.7))
		return
	var r := Rect2(Vector2.ZERO, RECT_SIZE)
	# housing (dark), chrome rim and the stem that holds it
	draw_rect(Rect2(r.size.x * 0.5 - 4.0, -4.0, 8.0, 5.0), Color(0.08, 0.08, 0.1, 0.9))
	draw_rect(r.grow(1.0), Color(0.05, 0.05, 0.07, 0.95))
	var rim := Color(0.78, 0.8, 0.86)
	if _alert > 0.0:
		var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.012)
		var hot: Color = PINK if _alert > 0.85 else (GOLD if _alert_rival else Color(1.0, 0.62, 0.25))
		rim = rim.lerp(hot, clampf(_alert * pulse, 0.0, 1.0))
	draw_rect(r.grow(-1.0), rim, false, FRAME_W - 1.0)
	draw_line(r.position + Vector2(2, 2), Vector2(r.end.x - 2, 2), Color(1, 1, 1, 0.5), 1.0)   # highlight on top
