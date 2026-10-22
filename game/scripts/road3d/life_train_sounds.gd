class_name LifeTrainSounds
extends Node3D
## T-189 (vida): the trains of T-154 (RailTraffic, only visual) now sound: a distant horn when a train comes into
## range (400-900 m) and the rumble when it passes near. Positional (AudioStreamPlayer3D at the head of the train),
## so it fades with the distance. Missing file = silent (AudioBus.stream returns null).

const HORN_M: float = 900.0
const PASS_M: float = 140.0

var rail: Railway3D
var _horned: Dictionary = {}
var _passed: Dictionary = {}
var _horn: AudioStreamPlayer3D
var _pass: AudioStreamPlayer3D


func setup(rail_: Railway3D) -> void:
	rail = rail_
	_horn = _player("train_horn", 6.0, 90.0)
	_pass = _player("train_pass", 2.0, 30.0)


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


func update(cam_pos: Vector3) -> void:
	if rail == null or rail.traffic == null:
		return
	for t in rail.traffic.trains:
		var id: int = t.get_instance_id()
		var h: Vector3 = head_of(t)
		var d: float = h.distance_to(cam_pos)
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
