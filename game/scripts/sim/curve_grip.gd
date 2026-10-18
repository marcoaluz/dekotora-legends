class_name CurveGrip
extends RefCounted
## Curves with lane control (T-132): the truck FOLLOWS ITS LANE by itself. Pure math, no nodes.
##  - ratio = speed / safe speed of the curve under the truck (safe speed: curve 1,0 = 90 km/h).
##  - ratio <= 1: nothing happens.
##  - 1 < ratio <= ESCAPE_RATIO: tyres scrub. Costs speed (SCRUB_DECEL, strong near the limit), the tyres squeal (`skid` 0..1) and the
##    truck slides outward at most MAX_SLIDE_M; the lane controller keeps it there and brings it back.
##  - ratio > ESCAPE_RATIO (+30%): grip is gone. The lane controller loses authority and the curve throws the
##    truck outward (ESCAPE_PUSH + ESCAPE_GAIN x excess); sliding tyres brake less (SLIDE_DECEL), so it only
##    regains the lane after the speed falls back under the limit.
## The warning (`warning`) looks ~2 s ahead so the HUD/vibration can tell the player BEFORE the escape.

const GRIP_K: float = 7.9e-4            # safe speed = sqrt(LANE_HOLD x grip / (|curve| x GRIP_K))
const LANE_HOLD: float = 0.5            # lateral grip: curve 1,0 = 90 km/h for the 12 t reference truck
const ESCAPE_RATIO: float = 1.3         # +30% over the safe speed: really leaves the lane
const WARN_RATIO: float = 1.12          # warning starts here (before the escape)
const MAX_SLIDE_M: float = 0.5          # outward slide while scrubbing (m), reached at ESCAPE_RATIO
const SCRUB_DECEL: float = 8.0          # m/s^2 per unit of (ratio^2 - 1) while the tyres still grip
const SLIDE_DECEL: float = 1.5          # m/s^2 while escaping: sliding tyres brake less (that is why it escapes)
const ESCAPE_PUSH: float = 0.6          # x/s outward as soon as it escapes
const ESCAPE_GAIN: float = 4.0          # extra x/s per unit of ratio above ESCAPE_RATIO
const WARN_LOOK_S: float = 2.0          # warning look-ahead (seconds at the current speed)
const STRAIGHT: float = 0.05            # |curve| below this counts as straight


## Speed (m/s) above which the curve starts to scrub the tyres.
static func safe_speed(curve: float, grip: float) -> float:
	var c: float = absf(curve)
	if c < STRAIGHT:
		return EngineModel.MAX_SPEED * 2.0
	return sqrt(LANE_HOLD * grip / (c * GRIP_K))


static func ratio(speed: float, curve: float, grip: float) -> float:
	return speed / safe_speed(curve, grip)


## Tyre squeal 0..1: 0 at the safe speed, 1 at the escape limit.
static func skid(ratio_: float) -> float:
	return clampf((ratio_ - 1.0) / (ESCAPE_RATIO - 1.0), 0.0, 1.0)


## Outward offset (x units) the lane controller accepts while scrubbing. Curve > 0 turns right: slides to -x.
static func slide_x(curve: float, ratio_: float) -> float:
	return -signf(curve) * skid(ratio_) * MAX_SLIDE_M / Track.ROAD_HALF_WIDTH_M


## Speed lost to scrubbing (m/s^2). Above the escape limit the tyres slide and brake less.
static func scrub_decel(ratio_: float) -> float:
	if ratio_ > ESCAPE_RATIO:
		return SLIDE_DECEL
	return SCRUB_DECEL * maxf(ratio_ * ratio_ - 1.0, 0.0)


## Outward lateral speed (x/s) while escaping (0 below ESCAPE_RATIO).
static func escape_push(curve: float, ratio_: float) -> float:
	if ratio_ <= ESCAPE_RATIO:
		return 0.0
	return -signf(curve) * (ESCAPE_PUSH + ESCAPE_GAIN * (ratio_ - ESCAPE_RATIO))


## Warning 0..1 for the HUD: worst ratio from here to WARN_LOOK_S ahead (0 = fine, 1 = will escape).
static func warning(track: Track, z: float, speed: float, grip: float) -> float:
	var worst: float = ratio(speed, track.curve_at(z), grip)
	var d: float = 10.0
	var look: float = speed * WARN_LOOK_S
	while d <= look:
		worst = maxf(worst, ratio(speed, track.curve_at(z + d), grip))
		d += 10.0
	return clampf((worst - WARN_RATIO) / (ESCAPE_RATIO - WARN_RATIO), 0.0, 1.0)
