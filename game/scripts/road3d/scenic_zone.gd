class_name ScenicZone
extends RefCounted
## T-188 (etapa 1): the new scenery (terrain with relief, layered mountains, city blocks, signs with text, rocks,
## slope forest) is built only on ONE pilot stretch per route until Marco approves the prints.
## Sky, night light and aerial perspective are global (they cannot be cut per km).
##   --t188=off      old look everywhere (before/after prints, cost comparison)
##   --t188=segment  default: only the pilot stretch below
##   --t188=all      whole route (not approved yet; for tests only)
## Pure data (no nodes): used by RoadMesh, CityBuilder, Roadside3D, RoadFurniture and the new builders.

const ZONES: Dictionary = {
	"kanto_1_coast": Vector2(600.0, 1600.0),
	"kanto_2_viaduct": Vector2(1300.0, 2050.0),
	"kanto_3_mountain": Vector2(1100.0, 2050.0),
}
const TAPER_M: float = 140.0          # relief fades to flat over this length at both ends of the stretch
const NONE: Vector2 = Vector2(-1.0, -1.0)


static func mode() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--t188="):
			return a.substr(7)
	return "segment"


static func enabled() -> bool:
	return mode() != "off"


## Stretch (start m, end m) of the route with the new scenery; NONE when off or unknown route.
static func zone(route_id: String, length_m: float = 1.0e9) -> Vector2:
	match mode():
		"off":
			return NONE
		"all":
			return Vector2(0.0, length_m)
	return ZONES.get(route_id, NONE)


static func contains(z_range: Vector2, z: float, margin: float = 0.0) -> bool:
	return z_range.y > z_range.x and z >= z_range.x - margin and z <= z_range.y + margin


## 0 outside, 1 in the middle, smooth ramp of TAPER_M at the ends.
static func weight(z_range: Vector2, z: float) -> float:
	if not contains(z_range, z):
		return 0.0
	var t: float = minf(z - z_range.x, z_range.y - z) / TAPER_M
	return smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
