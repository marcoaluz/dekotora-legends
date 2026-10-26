class_name ExposureAdapt
extends RefCounted
## T-217: eye adaptation at the tunnel mouths (PC, Forward+). The "eye" (adapted brightness A) follows the scene
## brightness L with a lag: entering a tunnel by day the image first goes dark and then opens up (~1.3 s); leaving it
## the outside burns white and then settles (~0.5 s). Night: the orange tunnel is BRIGHTER than the road outside, so
## the effect is the other way round and weaker. Drives Environment.tonemap_exposure (multiplies the base value).
## Phones keep the old flash (RaceCinema.tunnel_flash). "Reduzir clarões" limits the overshoot.

const DARK_IN: float = 0.18             # day: brightness inside the tunnel relative to outside
const NIGHT_IN: float = 1.45            # night: the sodium tunnel is brighter than the night road
const TAU_DARK: float = 1.3             # s to get used to the dark (slow)
const TAU_BRIGHT: float = 0.5           # s to get used to the light (fast)
const POWER: float = 0.5                # how much of the brightness ratio reaches the screen
const RANGE: Vector2 = Vector2(0.45, 2.4)
const RANGE_REDUCED: Vector2 = Vector2(0.7, 1.3)

var env: Environment
var base: float = 1.0
var adapted: float = 1.0
var day: float = 1.0
var reduce: bool = false


static func enabled() -> bool:
	return UltraLook.available() and not "--no-exposure" in OS.get_cmdline_user_args()


func _init(env_: Environment, day_amount: float, reduce_flash: bool) -> void:
	env = env_
	base = env.tonemap_exposure if env != null else 1.0
	day = day_amount
	reduce = reduce_flash


## Scene brightness for this much "inside a tunnel" (0..1).
func scene_level(tunnel_amount: float) -> float:
	var t: float = clampf(tunnel_amount, 0.0, 1.0)
	return lerpf(lerpf(1.0, NIGHT_IN, t), lerpf(1.0, DARK_IN, t), day)


## Exposure multiplier for the current scene level and the adapted one (pure, tested).
func ratio(level: float) -> float:
	var r: float = pow(level / maxf(adapted, 0.01), POWER)
	var lim: Vector2 = RANGE_REDUCED if reduce else RANGE
	return clampf(r, lim.x, lim.y)


func step(dt: float, tunnel_amount: float) -> float:
	var level: float = scene_level(tunnel_amount)
	var tau: float = TAU_DARK if level < adapted else TAU_BRIGHT
	adapted += (level - adapted) * (1.0 - exp(-dt / tau))
	var r: float = ratio(level)
	if env != null:
		env.tonemap_exposure = base * r
	return r
