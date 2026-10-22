class_name DieselMix
extends RefCounted
## T-197: mixing rules of the synthesized diesel loops (tools/synth_truck_audio.py). Pure functions (tests, preview
## renders). The loops are rendered at fixed RPM points, ON load (accelerating) and OFF load (lifted: fuel cut; at
## 700 rpm the OFF loop is the idle), plus jake brake and open-pipe rasp at a few points. The game crossfades the two
## nearest points and pitches each one by rpm / point (at most ~+-20%), so the firing rhythm follows the real RPM.

const IDLE_RPM: float = 700.0
const RPM_POINTS: Array[float] = [700.0, 1000.0, 1400.0, 1900.0, 2500.0]
const JAKE_POINTS: Array[float] = [1300.0, 1800.0, 2400.0]
const OPEN_POINTS: Array[float] = [1000.0, 1600.0, 2300.0]
const JAKE_MIN_RPM: float = 1300.0
## rpm falling faster than this with the foot down = the gearbox cut of an upshift (derived here; the sim is untouched)
const SHIFT_DROP_RPM_S: float = 1500.0
const SHIFT_CUT_S: float = 0.25
const SOUND_SPEED: float = 343.0
const DOPPLER_MAX: float = 0.06


## Loop file of a voice: syn_<voice>_<kind>_<rpm> (kind = on | off | jake | open).
static func layer(voice: String, kind: String, rpm: float) -> String:
	return "syn_%s_%s_%d" % [voice, kind, int(rpm)]


## Weight of each RPM point: the two neighbours, equal power (no loudness dip in the middle).
static func point_weights(rpm: float, points: Array[float]) -> Array[float]:
	var out: Array[float] = []
	out.resize(points.size())
	out.fill(0.0)
	if rpm <= points[0]:
		out[0] = 1.0
		return out
	if rpm >= points[points.size() - 1]:
		out[points.size() - 1] = 1.0
		return out
	for i in points.size() - 1:
		if rpm < points[i + 1]:
			var f: float = (rpm - points[i]) / (points[i + 1] - points[i])
			out[i] = cos(f * PI * 0.5)
			out[i + 1] = sin(f * PI * 0.5)
			break
	return out


## Loop pitch for a point: the firing frequency follows the engine.
static func point_pitch(rpm: float, point: float) -> float:
	return clampf(rpm / point, 0.5, 2.0)


## ON / OFF load weights (x = on, y = off), equal power.
static func load_weights(load: float) -> Vector2:
	var l: float = clampf(load, 0.0, 1.0)
	return Vector2(sin(l * PI * 0.5), cos(l * PI * 0.5))


## Upshift seen from the audio side: rpm drops fast while the throttle is held.
static func is_shift_drop(rpm_rate: float, throttle: float) -> bool:
	return throttle > 0.5 and rpm_rate < -SHIFT_DROP_RPM_S


## Jake brake engaged (only with the part installed): foot off, rpm high enough, rolling.
static func jake_active(has_jake: bool, throttle: float, rpm: float, speed: float) -> bool:
	return has_jake and throttle < 0.05 and rpm > JAKE_MIN_RPM and speed > 3.0


## Doppler pitch for a radial speed (m/s, + = going away from the listener), limited to +-6%.
static func doppler(radial_speed: float) -> float:
	var v: float = clampf(radial_speed, -0.5 * SOUND_SPEED, 0.5 * SOUND_SPEED)
	return clampf(SOUND_SPEED / (SOUND_SPEED + v), 1.0 - DOPPLER_MAX, 1.0 + DOPPLER_MAX)
