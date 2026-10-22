class_name AudioDriveDemo
extends RefCounted
## T-197: scripted drive for the engine sound test (and the .wav renders in docs/audio_t197/): idle, full throttle
## through the gears, lift off (overrun / jake brake), hard brake to a stop (air brake), idle again.
## Uses the real EngineModel of the simulation read-only (gears, rpm, turbo, shift cut); the speed integration here
## is a simple stand-in (mass, drag, brake) for the demo only. Pure: no nodes.

const DURATION: float = 26.0
const T_GO: float = 2.5
const T_LIFT: float = 15.5
const T_BRAKE: float = 19.5
const MASS: float = 12000.0
const BRAKE_DECEL: float = 6.0

var engine: EngineModel = EngineModel.new()
var t: float = 0.0
var speed: float = 0.0
var throttle: float = 0.0
var braking: bool = false
var stopped_event: bool = false      # true for one step: the truck just stopped (air brake "tssss")
var brake_released: bool = false     # true for one step: the brake pedal was released while rolling
var gear_changed: int = 0            # +1 upshift / -1 downshift this step


func configure(engine_id: String, turbo_id: String, exhaust_id: String, jake: bool) -> void:
	engine.configure(_def(engine_id), _def(turbo_id), _def(exhaust_id), jake)


func _def(id: String) -> Resource:
	var p: String = "res://data/engines/%s.tres" % id
	return load(p) if ResourceLoader.exists(p) else null


## Throttle / brake of the script at time `at` (pure).
static func controls(at: float) -> Vector2:
	if at < T_GO:
		return Vector2(0.0, 0.0)
	if at < T_LIFT:
		return Vector2(1.0, 0.0)
	if at < T_BRAKE:
		return Vector2(0.0, 0.0)
	return Vector2(0.0, 1.0)


func rpm01() -> float:
	return clampf((engine.rpm - EngineModel.IDLE_RPM) / (engine.redline_rpm - EngineModel.IDLE_RPM), 0.0, 1.0)


func step(dt: float) -> void:
	var c: Vector2 = controls(t)
	var was_moving: bool = speed > 0.3
	var was_braking: bool = braking
	throttle = c.x
	braking = c.y > 0.5 and speed > 0.0
	var g0: int = engine.gear
	var force: float = engine.step(dt, throttle, speed)
	var resist: float = 1.5 * speed * speed + 0.01 * MASS * 9.8
	var acc: float = (force - resist) / MASS - (BRAKE_DECEL if braking else 0.0)
	speed = maxf(speed + acc * dt, 0.0)
	gear_changed = signi(engine.gear - g0)
	stopped_event = was_moving and speed <= 0.3
	brake_released = was_braking and not braking and speed > 0.3
	t += dt
