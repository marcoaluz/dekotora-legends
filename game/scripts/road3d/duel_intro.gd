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

signal finished

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


## `tod` and `place` are kept for the callers (the studio looks the same at any hour).
func setup(kind_: String, _tod: TimeOfDay, trucks_: Array[TruckNode], pair_: Array[int], cards_: Array[Dictionary], _place: String) -> void:
	kind = kind_
	trucks = trucks_
	pair = pair_
	cards = cards_
	done = kind != DuelPlan.FULL
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
	if done or skipped:
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


## Ends now (online: the server already started the race).
func finish_now() -> void:
	_finish()


func _finish() -> void:
	if done:
		return
	done = true
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
	for n in 2:
		var k: int = pair[n]
		if k < 0 or k >= trucks.size():
			continue
		var pose: Dictionary = DuelShots.truck_pose(n, t)
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


## Engines braking in, air brakes at the stop, distant rumble when the guardians rise, the taiko with the title,
## the thunder with the bolt, both engines flat out at the launch.
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
