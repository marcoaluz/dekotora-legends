class_name ScenicZone
extends RefCounted
## T-188: the new scenery (terrain with relief, layered mountains, city blocks, signs with text, rocks, slope forest).
## Etapa 1 built it on ONE pilot stretch per route (ZONES); T-192 (etapa 2, approved by Marco) turns it on along the
## WHOLE route by default. Sky, night light and aerial perspective are global (they cannot be cut per km).
##   --t188=all      default (T-192): whole route
##   --t188=segment  only the old pilot stretch below (compare with the T-188 prints)
##   --t188=off      old look everywhere (before/after prints, cost comparison)
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
	return "all"


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


## The old pilot stretch of the route (T-188 etapa 1), whatever the mode (tests, --t188=segment).
static func pilot(route_id: String) -> Vector2:
	return ZONES.get(route_id, NONE)


static func contains(z_range: Vector2, z: float, margin: float = 0.0) -> bool:
	return z_range.y > z_range.x and z >= z_range.x - margin and z <= z_range.y + margin


## 0 outside, 1 in the middle, smooth ramp of TAPER_M at the ends.
static func weight(z_range: Vector2, z: float) -> float:
	if not contains(z_range, z):
		return 0.0
	var t: float = minf(z - z_range.x, z_range.y - z) / TAPER_M
	return smoothstep(0.0, 1.0, clampf(t, 0.0, 1.0))
