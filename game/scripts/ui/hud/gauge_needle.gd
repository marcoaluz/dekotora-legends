class_name GaugeNeedle
extends RefCounted
## T-202: needle of the analog speedometer. Pure (no nodes): a spring-damper that chases the speed (light inertia,
## a small overshoot), plus a tremor that grows with the engine RPM and a kick on a crash jolt.
## Scale: 0 at 150 degrees (bottom left, screen angles: y down) sweeping 240 degrees clockwise to 140 km/h at the
## bottom right. The needle may pass the last number up to STOP_KMH (draft gives ~147 km/h; see DECISOES T-202).

const SCALE_MAX_KMH: float = 140.0         # last number of the dial = EngineModel.MAX_SPEED (38,9 m/s)
const STOP_KMH: float = 150.0              # stop pin
const START_DEG: float = 150.0
const SWEEP_DEG: float = 240.0
const OMEGA: float = 13.0                  # rad/s: spring stiffness (how fast it follows)
const DAMPING: float = 0.62                # < 1: a little overshoot (needle "weight")
const TREMOR_KMH: float = 0.35             # tremor at idle ...
const TREMOR_RPM_KMH: float = 0.55         # ... plus this much at the redline
const KICK_KMH: float = 9.0                # needle speed (km/h per s x OMEGA) added on a crash jolt

var value: float = 0.0                     # km/h shown (without tremor)
var vel: float = 0.0                       # km/h per s
var clock: float = 0.0


## Advances `dt` seconds towards `target_kmh`. `kick` true = crash jolt this frame (the needle drops and comes back).
func step(dt: float, target_kmh: float, kick: bool = false) -> void:
	clock += dt
	var n: int = maxi(int(ceil(dt / 0.008)), 1)          # small sub-steps: stable at 20 or 240 FPS
	var h: float = dt / float(n)
	if kick:
		vel -= KICK_KMH * OMEGA
	for _i in n:
		var acc: float = OMEGA * OMEGA * (target_kmh - value) - 2.0 * DAMPING * OMEGA * vel
		vel += acc * h
		value += vel * h
	value = clampf(value, 0.0, STOP_KMH)


## Value with the tremor (what is drawn). Deterministic (sums of sines of the needle clock).
func shown(rpm_frac: float = 0.0) -> float:
	var amp: float = TREMOR_KMH + TREMOR_RPM_KMH * clampf(rpm_frac, 0.0, 1.0)
	if value < 0.5:
		amp *= 0.3                                       # parked: almost still
	var n: float = sin(clock * 41.0) * 0.55 + sin(clock * 23.7 + 1.3) * 0.3 + sin(clock * 67.1 + 0.4) * 0.15
	return clampf(value + amp * n, 0.0, STOP_KMH)


## Screen angle (radians) of `kmh` on the dial.
static func angle_for(kmh: float) -> float:
	return deg_to_rad(START_DEG + SWEEP_DEG * clampf(kmh, 0.0, STOP_KMH) / SCALE_MAX_KMH)


## Gear / state letter on the centre cap: "N" stopped, gear number moving.
static func cap_letter(speed_ms: float, gear: int) -> String:
	if speed_ms < 0.5:
		return "N"
	return str(gear)
