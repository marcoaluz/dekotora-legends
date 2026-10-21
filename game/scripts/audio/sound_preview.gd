class_name SoundPreview
extends Node
## Short sound preview in the garage (T-173): an engine rev (idle -> high -> lift off, with the turbo whine and
## the "pssh" of the profile) or a horn. One at a time; the node lives under the AudioBus autoload, so it survives
## the garage rebuilding its cards.

const DURATION: float = 3.0
const HORN_DB: float = -3.0

static var _current: SoundPreview = null

var _engine: EngineAudio
var _t: float = 0.0
var _blown: bool = false


## Plays a rev of the given EngineSounds spec.
static func engine(host: Node, s: Dictionary) -> void:
	stop()
	var p := SoundPreview.new()
	host.add_child(p)
	p._engine = EngineAudio.new()
	p.add_child(p._engine)
	p._engine.setup_spec(s, false)
	_current = p


static func horn(host: Node, id: String) -> void:
	stop()
	host.get_node("/root/AudioBus").play_sfx(id, HORN_DB)


static func stop() -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
	_current = null


static func playing() -> bool:
	return _current != null and is_instance_valid(_current)


## rpm (0..1) and throttle of the rev at time t (pure, testable).
static func rev_curve(t: float) -> Vector2:
	if t < 0.4:
		return Vector2(0.05, 0.0)
	if t < 1.6:
		return Vector2(lerpf(0.05, 0.92, (t - 0.4) / 1.2), 1.0)
	if t < 1.9:
		return Vector2(0.92, 1.0)
	return Vector2(lerpf(0.92, 0.05, clampf((t - 1.9) / 1.0, 0.0, 1.0)), 0.0)


## Turbo boost (0..1) of the rev at time t (pure, testable). T-178: before the throttle (t < 0.4) the old formula
## gave boost 5.5, so every preview started with a loud squeal at ~4.6x pitch sliding down (the "DJ" effect).
static func boost_at(t: float) -> float:
	if rev_curve(t).y > 0.5:
		return clampf((t - 0.8) / 0.8, 0.0, 1.0)
	if t < 1.9:
		return 0.0
	return clampf(1.0 - (t - 1.9) / 0.4, 0.0, 1.0)


func _process(dt: float) -> void:
	_t += dt
	var c: Vector2 = rev_curve(_t)
	var boost: float = boost_at(_t)
	if c.y < 0.5 and _t >= 1.9 and not _blown:
		_blown = true
		if _engine.turbo_set != "":
			_engine.blowoff()
	_engine.update(dt, c.x, c.y, boost, 1.0, 0.0)
	var fade: float = clampf((DURATION - _t) / 0.4, 0.0, 1.0)      # some suave no fim (sem estalo)
	if fade < 1.0:
		for p in _engine.get_children():
			p.set("volume_db", float(p.get("volume_db")) + linear_to_db(maxf(fade, 0.0001)))
	if _t >= DURATION:
		if _current == self:
			_current = null
		queue_free()
