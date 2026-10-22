class_name LifeTrainSounds
extends Node3D
## T-189 (vida): the trains of T-154 (RailTraffic, only visual) now sound: a distant horn when a train comes into
## range (400-900 m) and the rumble when it passes near. Positional (AudioStreamPlayer3D at the head of the train),
## so it fades with the distance. Missing file = silent (AudioBus.stream returns null).
## T-197: the yellow light rail (RailTraffic.Type.LRT, "bonde") has its own sounds: the "chin-chin" bell when it
## comes near and a light running loop (electric hum, light wheels, joints, faint flange squeal) that follows the
## tram with Doppler. The freight train keeps the deep horn and the heavy rumble.

const HORN_M: float = 900.0
const PASS_M: float = 140.0
const BELL_M: float = 170.0
const RUN_M: float = 260.0            # the tram loop plays while the nearest tram is closer than this

var rail: Railway3D
var _horned: Dictionary = {}
var _passed: Dictionary = {}
var _belled: Dictionary = {}
var _horn: AudioStreamPlayer3D
var _pass: AudioStreamPlayer3D
var _bell: AudioStreamPlayer3D
var _run: AudioStreamPlayer3D
var _run_prev_d: float = -1.0
var _doppler: float = 1.0


func setup(rail_: Railway3D) -> void:
	rail = rail_
	_horn = _player("train_horn", 6.0, 90.0)
	_pass = _player("train_pass", 2.0, 30.0)
	_bell = _player("tram_bell", -2.0, 40.0)
	_run = _player("tram_run_loop", 0.0, 22.0)


func _player(sound: String, db: float, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	var bus: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("AudioBus")
	p.stream = bus.call("stream", sound) if bus != null and RaceAudio.has_sound(sound) else null
	p.bus = "SFX"
	p.volume_db = db
	p.unit_size = unit
	p.max_distance = 1400.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	add_child(p)
	return p


## Head of a train in the world (null-safe).
func head_of(t: RailTraffic.Train) -> Vector3:
	var l: RailLine = rail.lines[t.line]
	var c: float = t.center + t.dir * (t.length - t.lens[0]) * 0.5
	return l.car_transform(clampf(c, 0.0, l.length()), t.lens[0], t.dir, t.track).origin


## Which sounds a train type uses (pure; tests).
static func sounds_for(type: int) -> Array[String]:
	if type == RailTraffic.Type.LRT:
		return ["tram_bell", "tram_run_loop"]
	return ["train_horn", "train_pass"]


func update(cam_pos: Vector3, dt: float = -1.0) -> void:
	if rail == null or rail.traffic == null:
		return
	if dt < 0.0:
		dt = get_process_delta_time() if is_inside_tree() else 1.0 / 60.0
	var tram_pos: Vector3 = Vector3.ZERO
	var tram_d: float = INF
	for t in rail.traffic.trains:
		var id: int = t.get_instance_id()
		var h: Vector3 = head_of(t)
		var d: float = h.distance_to(cam_pos)
		if t.type == RailTraffic.Type.LRT:
			if d < tram_d:
				tram_d = d
				tram_pos = h
			if not _belled.has(id) and d < BELL_M and t.age > 0.5:
				_belled[id] = true
				if _bell.stream != null:
					_bell.global_position = h
					_bell.pitch_scale = 0.97 + float(id % 5) * 0.015
					_bell.play()
			continue
		if not _horned.has(id) and d < HORN_M and t.age > 0.5:
			_horned[id] = true
			if _horn.stream != null:
				_horn.global_position = h
				_horn.pitch_scale = 0.94 + float(id % 7) * 0.02
				_horn.play()
		if not _passed.has(id) and d < PASS_M:
			_passed[id] = true
			if _pass.stream != null:
				_pass.global_position = h
				_pass.play()
		if _pass.playing and _passed.has(id):
			_pass.global_position = _pass.global_position.lerp(h, 0.2)
	_update_tram_run(tram_pos, tram_d, dt)


func _update_tram_run(pos: Vector3, d: float, dt: float) -> void:
	if _run.stream == null:
		return
	if d > RUN_M:
		if _run.playing:
			_run.stop()
		_run_prev_d = -1.0
		return
	_run.global_position = pos
	var target: float = 1.0
	if _run_prev_d >= 0.0 and dt > 0.0 and absf(d - _run_prev_d) / dt < 90.0:
		target = DieselMix.doppler((d - _run_prev_d) / dt)
	_run_prev_d = d
	_doppler = lerpf(_doppler, target, minf(5.0 * dt, 1.0))
	_run.pitch_scale = _doppler
	_run.volume_db = linear_to_db(clampf((RUN_M - d) / 60.0, 0.001, 1.0))     # fade in/out at the edge
	if not _run.playing:
		_run.play()
