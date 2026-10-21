class_name DuelIntro
extends Node
## Face-to-face opening before the start (T-156; idea from Art Truck Battle, nothing copied). Presentation only:
## the race simulation waits at the start line and begins at the end of the countdown, as before.
## FULL: the two REAL race trucks (their parts, paint, decals and light pattern) are moved to the DuelStage, nose to
## nose, lights on blinking; the camera visits bumper, visor/andon and mural of each one with the band of the driver;
## VS banner with a taiko hit; then the countdown on the track opens with the alignment shot (DuelShots).
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
var t: float = 0.0
var skipped: bool = false
var done: bool = false
var _layer: CanvasLayer
var _phase: String = ""
var _detail: String = ""
var _waiting_left: float = 0.0


## `place` = caption of the location (rest area / toll plaza + city of the route).
func setup(kind_: String, tod: TimeOfDay, trucks_: Array[TruckNode], pair_: Array[int], cards_: Array[Dictionary], place: String) -> void:
	kind = kind_
	trucks = trucks_
	pair = pair_
	cards = cards_
	done = kind != DuelPlan.FULL
	_layer = CanvasLayer.new()
	_layer.layer = 6
	_layer.scale = Vector2(2, 2)
	add_child(_layer)
	band = DuelBand.new()
	band.cards = cards
	band.place = place
	_layer.add_child(band)
	if kind == DuelPlan.FULL:
		stage = DuelStage.new()
		add_child(stage)
		stage.build(tod)
		var paints: Array[Color] = []                       # T-186: drivers by their trucks, shirt in the paint
		for c in cards:
			paints.append(c.get("color", Color.WHITE))
		stage.add_drivers(paints)
		band.place = Tr.t("intro.place_rest" if stage.rest_area else "intro.place_toll", [place])
		for k in pair:
			trucks[k].set_lights_on(true)
			trucks[k].set_headlights(true)


func running() -> bool:
	return not done


## Skip (tap/key/button): offline goes straight to the countdown; online waits for the server's countdown.
func skip() -> void:
	if done or skipped:
		return
	skipped = true
	band.phase = ""
	band.skip_hint = false
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
	t = t_now
	var ph: Array = DuelPlan.phase_at(t)
	if String(ph[0]) == "count":
		_finish()
		return
	if skipped:                                    # online: wait at the start line for the common countdown
		_waiting_left = DuelPlan.intro_seconds(kind) - t
		band.waiting = Tr.t("intro.waiting", [int(ceil(_waiting_left + Protocol.COUNTDOWN_SECONDS))])
		band.letterbox = maxf(band.letterbox - dt * 3.0, 0.0)
		return
	var phase: String = String(ph[0])
	var p: float = float(ph[1])
	band.phase = phase
	band.progress = p
	band.letterbox = minf(band.letterbox + dt * 4.0, 1.0)
	_place_trucks()
	DuelShots.stage_camera(cam, stage, trucks, pair, phase, p)
	_lights(phase, p)
	_sound(phase, p, dt)
	_shots(phase, p)


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
	if stage != null:
		stage.queue_free()
		stage = null
	for k in pair:
		if k >= 0 and k < trucks.size():
			trucks[k].set_headlights(true)
	finished.emit()


func _place_trucks() -> void:
	for n in 2:
		var k: int = pair[n]
		if k < 0 or k >= trucks.size():
			continue
		trucks[k].global_transform = stage.truck_xform(-1.0 if n == 0 else 1.0, DuelShots.front_len(trucks[k]))
		trucks[k].animate(0.0, 0.0)


## Headlights flashing: the rival "provokes" in the face-off, both flash at the VS.
func _lights(phase: String, p: float) -> void:
	var blink: bool = int(t * 9.0) % 2 == 0
	var rival_flash: bool = (phase == "face" and p > 0.45 and p < 0.8) or (phase == "rival" and p < 0.25)
	var both_flash: bool = phase == "vs" and p > 0.12 and p < 0.6
	if pair[1] >= 0:
		trucks[pair[1]].set_headlights(not ((rival_flash or both_flash) and blink))
	trucks[pair[0]].set_headlights(not ((both_flash or (phase == "player" and p < 0.2)) and blink))


## Engines revving while parked (blips), the rival's taunting horn, the taiko on the VS.
func _sound(phase: String, p: float, dt: float) -> void:
	if phase != _phase:
		match phase:
			"rival":
				get_node("/root/AudioBus").play_sfx(rival_horn, -3.0)
			"vs":
				var drum: String = "vs_taiko_hit" if RaceAudio.has_sound("vs_taiko_hit") else "truck_body_slam"
				get_node("/root/AudioBus").play_sfx(drum, 0.0)
	var me: float = 0.0
	var other: float = 0.0
	match phase:
		"face":
			other = _blip(p, [0.55, 0.72])
		"player":
			me = _blip(p, [0.15, 0.4, 0.7])
		"rival":
			other = _blip(p, [0.35, 0.6, 0.82])
		"vs":
			me = _blip(p, [0.2]) * 0.9
			other = _blip(p, [0.28]) * 0.9
	if audio != null:
		audio.intro_engine(dt, 0.05 + 0.85 * me, me)
	if rival_engine != null:
		rival_engine.update(dt, 0.05 + 0.85 * other, other, 0.0, 1.0, 0.0)


static func _blip(p: float, at: Array) -> float:
	var v: float = 0.0
	for b in at:
		var d: float = (p - float(b)) / 0.09
		v = maxf(v, exp(-d * d))
	return v


## Captures (--shots=): one per moment of the scene.
func _shots(phase: String, p: float) -> void:
	if demo == null:
		_phase = phase
		return
	if phase != _phase:
		match phase:
			"face":
				demo.queue_shot("duelo_1_frente", 0.95)
			"vs":
				demo.queue_shot("duelo_4_vs", 0.55)
	if phase in ["player", "rival"]:
		var d: Array = DuelPlan.detail_at(phase, p)
		var key: String = phase + String(d[0])
		if key != _detail:
			_detail = key
			demo.queue_shot("duelo_%s_%s" % ["2_jogador" if phase == "player" else "3_rival", String(d[0])], 0.4)
	_phase = phase
