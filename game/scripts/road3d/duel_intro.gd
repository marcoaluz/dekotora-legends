class_name DuelIntro
extends Node
## Duel opening before the start (T-156, redone in T-204 with the rhythm of the PS1 original, nothing copied).
## Presentation only: the race simulation waits at the start line and begins at the end of the countdown, as before.
## FULL (8 s with the countdown, timeline in DuelPlan): black studio with purple ground fog (DuelStage); the two REAL
## race trucks (parts, paint, decals, light pattern, headlights and neon on) drive in from each side and stop side by
## side facing the camera; Raijin and Fujin (our art) rise behind them in their auras; 対決 slams in with a taiko and
## the driver bands slide in; a lightning bolt strikes between them (one 0.15 s flash, or a soft glow with "reduce
## flashes") with thunder; cut: they charge at the camera; then the countdown on the track (alignment shot).
## SHORT (rematch, 3-4 trucks): only the countdown with the alignment shot. Any tap/key/button skips to the countdown.
## Online the clock comes from the server's countdown (setup + ping): every client sees the same moment.
## T-208: the clock starts at the first SMOOTH frame. Before it, a few frames of preparation behind a black screen with
## the purple fog (DuelBand.prep): the track once under the sun (the race world's shaders), the studio once with
## everything lit and visible (trucks under the studio lights, guardians, auras, the strike, title, bands, bolt), then
## it waits for PREP_SMOOTH_FRAMES quick frames (or PREP_MAX_S). Online it then tells the server (`prepared`) and
## waits for the common clock (`clock_started`).

signal finished
signal prepared                          # T-208: local preparation done (online: Net.race_loaded)

const PREP_MIN_FRAMES: int = 4           # track view, studio warm-up, then at least 2 more frames
const PREP_SMOOTH_MS: float = 70.0       # a frame quicker than this counts as smooth
const PREP_SMOOTH_FRAMES: int = 2
const PREP_MAX_S: float = 6.0            # never prepares longer than this (very slow phone)

var kind: String = DuelPlan.NONE
var online: bool = false
var pair: Array[int] = [0, 1]           # [player, rival] truck indices
var cards: Array[Dictionary] = []
var trucks: Array[TruckNode] = []
var stage: DuelStage
var band: DuelBand
var audio: RaceAudio
var rival_engine: EngineAudio
var rival_horn: String = "horn_musical_1"
var demo: RaceDemo
var sun: DirectionalLight3D             # the race's sun/moon: off while the studio is on screen
var reduced: bool = false               # Settings.fx_reduce_flash (or --reduce-flash)
var t: float = 0.0
var skipped: bool = false
var done: bool = false
var _layer: CanvasLayer
var _cam: Camera3D
var _in_studio: bool = false
var _prev_env: Environment
var _prev_far: float = 0.0
var _prev_attr: CameraAttributes
var _prev_sun: bool = true
var preparing: bool = false              # T-208: black screen + fog, the clock waits at 0
var ready_local: bool = false            # T-208: preparation done here (online: waiting for the others)
var clock_started: bool = true           # T-208: online = Net.race_clock_started (the race sets it every frame)
var prep_frames: int = 0
var prep_ms: float = 0.0                 # real time spent preparing (log)
var _prep_smooth: int = 0
var _prep_usec0: int = 0
var _prep_usec_last: int = 0


## `tod` and `place` are kept for the callers (the studio looks the same at any hour).
func setup(kind_: String, _tod: TimeOfDay, trucks_: Array[TruckNode], pair_: Array[int], cards_: Array[Dictionary], _place: String) -> void:
	kind = kind_
	trucks = trucks_
	pair = pair_
	cards = cards_
	done = kind != DuelPlan.FULL
	preparing = kind == DuelPlan.FULL
	var st: Node = Engine.get_main_loop().root.get_node_or_null("Settings")
	reduced = (st != null and bool(st.get("fx_reduce_flash"))) or "--reduce-flash" in OS.get_cmdline_user_args()
	_layer = CanvasLayer.new()
	_layer.layer = 6
	_layer.scale = Vector2(2, 2)
	add_child(_layer)
	band = DuelBand.new()
	band.cards = cards
	band.reduced = reduced
	_layer.add_child(band)
	if kind == DuelPlan.FULL:
		stage = DuelStage.new()
		add_child(stage)
		stage.build(int(st.get("quality")) if st != null else 1)
		for k in pair:
			if k >= 0 and k < trucks.size():
				trucks[k].set_lights_on(true)
				trucks[k].set_headlights(true)


func running() -> bool:
	return not done


## Skip (tap/key/button): offline goes straight to the countdown; online waits at the start line for the server.
func skip() -> void:
	if done or skipped or (preparing and online):    # online: the server waits for this client's preparation
		return
	skipped = true
	band.phase = ""
	band.skip_hint = false
	_leave_studio()
	if not online:
		_finish()


func _input(event: InputEvent) -> void:
	if done or skipped or get_tree().paused:
		return
	var press: bool = (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventJoypadButton and event.pressed) or (event is InputEventKey and event.pressed and not event.echo)
	if press and not event.is_action_pressed("pause"):
		skip()
		get_viewport().set_input_as_handled()


## Advance to intro time `t_now` (offline: t + dt; online: the server clock) and place trucks/camera.
func update_to(t_now: float, dt: float, cam: Camera3D) -> void:
	if done:
		return
	if preparing:
		_prepare(cam)
		return
	var prev: float = t
	t = t_now
	var ph: Array = DuelPlan.phase_at(t)
	if String(ph[0]) == "count":
		_finish()
		return
	if skipped:                                    # online: wait at the start line for the common countdown
		var left: float = DuelPlan.intro_seconds(kind) - t
		band.waiting = Tr.t("intro.waiting", [int(ceil(left + Protocol.COUNTDOWN_SECONDS))])
		band.letterbox = maxf(band.letterbox - dt * 3.0, 0.0)
		return
	_enter_studio(cam)
	band.phase = String(ph[0])
	band.t_intro = t
	band.letterbox = minf(band.letterbox + dt * 4.0, 1.0)
	_place_trucks(dt)
	DuelShots.studio_camera(cam, t, reduced)
	stage.update(t, reduced)
	_aim_bolt(cam)
	_sound(prev, dt)
	_shots(prev)


## T-208: one frame of preparation (see the header). Measures the real frame time (dt is capped by the race).
func _prepare(cam: Camera3D) -> void:
	var now: int = Time.get_ticks_usec()
	if prep_frames == 0:
		_prep_usec0 = now
	elif float(now - _prep_usec_last) / 1000.0 < PREP_SMOOTH_MS:
		_prep_smooth += 1
	else:
		_prep_smooth = 0
	_prep_usec_last = now
	prep_frames += 1
	prep_ms = float(now - _prep_usec0) / 1000.0
	band.prep = true
	band.phase = ""
	band.letterbox = 0.0
	if prep_frames == 1:                     # the track under the sun (the race camera is already there)
		return
	if prep_frames == 3 and demo != null:
		demo.queue_shot("abertura_preparo", 0.0)
	_enter_studio(cam)
	var warm: bool = prep_frames == 2
	stage.warm_up(warm)
	band.warm = warm
	if warm:                                  # everything of the scene on screen once, behind the black
		_place_trucks_at(DuelPlan.phase_start("guard"), 0.0)
		DuelShots.studio_camera(cam, DuelPlan.BOLT_AT, reduced)
		_aim_bolt(cam)
		band.t_intro = DuelPlan.BOLT_AT
	else:
		stage.update(0.0, reduced)
		_place_trucks_at(0.0, 0.0)
		DuelShots.studio_camera(cam, 0.0, reduced)
		band.t_intro = 0.0
	if not ready_local and prep_frames >= PREP_MIN_FRAMES and (_prep_smooth >= PREP_SMOOTH_FRAMES or prep_ms > PREP_MAX_S * 1000.0):
		ready_local = true
		prepared.emit()
	band.waiting = Tr.t("intro.wait_players") if ready_local and not clock_started else ""
	if ready_local and clock_started:
		preparing = false
		band.prep = false
		band.warm = false
		band.waiting = ""
		t = 0.0
		print("ABERTURA: preparada em %d quadros, %.0f ms (o relogio comeca agora)" % [prep_frames, prep_ms])
		LoadClock.mark("abertura_comeca")


## Ends now (online: the server already started the race).
func finish_now() -> void:
	_finish()


func _finish() -> void:
	if done:
		return
	done = true
	preparing = false
	band.prep = false
	band.warm = false
	band.phase = ""
	band.waiting = ""
	band.letterbox = 0.0
	band.skip_hint = false
	_leave_studio()
	for k in pair:
		if k >= 0 and k < trucks.size():
			trucks[k].set_headlights(true)
	finished.emit()


## The camera gets the studio environment (black, glow, Ultra volumetric fog) and a short far plane (the race world
## 400 m above never shows); the race's sun goes off. Given back in _leave_studio.
func _enter_studio(cam: Camera3D) -> void:
	if _in_studio or stage == null or cam == null:
		return
	_in_studio = true
	_cam = cam
	_prev_env = cam.environment
	_prev_far = cam.far
	_prev_attr = cam.attributes
	cam.environment = stage.environment()
	cam.attributes = null                          # no depth of field: it would blur the guardians (Ultra)
	cam.far = 160.0
	if sun != null:
		_prev_sun = sun.visible
		sun.visible = false


func _leave_studio() -> void:
	if _in_studio and _cam != null:
		_cam.environment = _prev_env
		_cam.far = _prev_far
		_cam.attributes = _prev_attr
		if sun != null:
			sun.visible = _prev_sun
	_in_studio = false
	if stage != null:
		stage.queue_free()
		stage = null


func _place_trucks(dt: float) -> void:
	_place_trucks_at(t, dt)


func _place_trucks_at(at: float, dt: float) -> void:
	for n in 2:
		var k: int = pair[n]
		if k < 0 or k >= trucks.size():
			continue
		var pose: Dictionary = DuelShots.truck_pose(n, at)
		var xf: Transform3D = DuelShots.truck_xform(pose, DuelShots.front_len(trucks[k]))
		xf.origin += DuelStage.ORIGIN
		if trucks[k].is_inside_tree():
			trucks[k].global_transform = xf
		else:
			trucks[k].transform = xf
		trucks[k].animate(float(pose["speed"]), dt)


## Screen points of the bolt (band space = viewport / 2): from above the frame down to the floor between the trucks.
func _aim_bolt(cam: Camera3D) -> void:
	if not cam.is_inside_tree():
		return
	var ground: Vector2 = cam.unproject_position(DuelStage.ORIGIN + Vector3(0.0, 0.0, -2.0)) * 0.5
	band.bolt_to = ground
	band.bolt_from = Vector2(ground.x + 18.0, -12.0)


static func _crossed(prev: float, now: float, at: float) -> bool:
	return prev < at and now >= at and now - at < 0.3          # a late client does not replay stale sounds


## Engines braking in, air brakes at the stop, distant rumble when the guardians rise, the taiko with the title (and a
## softer one when the bands come in), the thunder with the bolt, both engines flat out at the launch.
func _sound(prev: float, dt: float) -> void:
	var bus: Node = Engine.get_main_loop().root.get_node_or_null("AudioBus")
	if bus != null:
		var stop_t: float = DuelPlan.phase_len("enter") * DuelShots.STOP_AT
		if _crossed(prev, t, stop_t):
			bus.play_sfx("air_brake_park", -5.0)
		if _crossed(prev, t, DuelPlan.phase_start("guard")):
			bus.play_sfx(_thunder(), -15.0, 0.72)
		if _crossed(prev, t, DuelPlan.phase_start("title")):
			bus.play_sfx("vs_taiko_hit" if RaceAudio.has_sound("vs_taiko_hit") else "truck_body_slam", 0.0)
		if _crossed(prev, t, DuelPlan.phase_start("bands")) and RaceAudio.has_sound("vs_taiko_hit"):
			bus.play_sfx("vs_taiko_hit", -9.0, 1.12)
		if _crossed(prev, t, DuelPlan.BOLT_AT):
			bus.play_sfx(_thunder(), 0.0)
	var rpm: float = 0.1
	var thr: float = 0.08
	var stop_at: float = DuelPlan.phase_len("enter") * DuelShots.STOP_AT
	if t < stop_at:
		var u: float = t / stop_at
		rpm = 0.12 + 0.55 * (1.0 - u)
		thr = 0.35 * (1.0 - u)
	elif t >= DuelPlan.phase_start("launch"):
		var p: float = (t - DuelPlan.phase_start("launch")) / DuelPlan.phase_len("launch")
		rpm = 0.35 + 0.65 * p
		thr = 1.0
	if audio != null:
		audio.intro_engine(dt, rpm, thr)
	if rival_engine != null:
		rival_engine.update(dt, rpm, thr, 0.0, 1.0, 0.0)


static func _thunder() -> String:
	return "duel_thunder" if RaceAudio.has_sound("duel_thunder") else "crash_heavy_1"


## Captures (--shots=): one at each moment of DuelPlan.SHOT_TIMES (abertura_00.50s_1.png ...).
func _shots(prev: float) -> void:
	if demo == null:
		return
	for st in DuelPlan.SHOT_TIMES:
		if prev < st and t >= st:
			demo.queue_shot("abertura_%05.2fs" % st, 0.0)
