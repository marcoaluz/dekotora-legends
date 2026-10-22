class_name ArrivalLayout
extends RefCounted
## T-195: the road does not end at the finish line any more: it goes on (only drawn, the simulation does not change)
## into the DESTINATION CITY: avenue with buildings on both sides (the sea stays on the right of the coast),
## lamps, a finish gantry at the line and, at the end of the drawn road, a gateway building the avenue runs under, with
## the skyline of the city behind it. Pure data (no nodes): race_scene_3d builds TrackPath with `runout(route)` and
## ArrivalCity draws the city.
## `--no-arrival` turns it all off (the old end: the road stops at the finish line) to compare and measure.

## Runout per route: [length m, curve] (curve > 0 = to the right, eased by TrackPath.RUNOUT_EASE_M).
## Coast turns LEFT (inland, the city is on the land side); the others turn so that the end of the road is hidden.
const RUNOUT: Dictionary = {
	"kanto_1_coast": [[260.0, 0.0], [440.0, -1.3], [320.0, 0.0]],
	"kanto_2_viaduct": [[260.0, 0.0], [440.0, 1.2], [320.0, 0.0]],
	"kanto_3_mountain": [[260.0, 0.0], [440.0, 1.1], [320.0, 0.0]],
}
const DEFAULT_RUNOUT: Array = [[260.0, 0.0], [440.0, 1.0], [320.0, 0.0]]
const CITY_FROM_M: float = 70.0       # first city block after the finish line
const GATE_BEFORE_END_M: float = 150.0  # gateway building: this far before the end of the drawn road
const LAMP_EVERY_M: float = 36.0


static func enabled() -> bool:
	return not "--no-arrival" in OS.get_cmdline_user_args()


static func runout(route_id: String) -> Array:
	if not enabled():
		return []
	return RUNOUT.get(route_id, DEFAULT_RUNOUT)


static func length_of(route_id: String) -> float:
	var total: float = 0.0
	for s in RUNOUT.get(route_id, DEFAULT_RUNOUT):
		total += float(s[0])
	return total


## Sides that get city blocks (-1 left, +1 right). The coast keeps the sea on the right.
static func city_sides(kind: StringName) -> Array[float]:
	if kind == &"coast":
		return [-1.0]
	return [-1.0, 1.0]
