class_name UniqueCar
extends Node3D
## T-193: the "only one car" of docs/Modelos/Unico, apenas um carro (a blue R34-style coupe, car_skyline.glb, made by
## build_traffic_cars.py): it appears ONCE per race, parked on a small paved lookout beside the road, outside the
## barrier. Only scenery: not in the simulation, not an obstacle, not on the network (every player sees it in the same
## place because the spot only depends on the route). Discreet highlight: a soft warm pool of light on the ground
## (stronger at night), glossy paint and its lamps lit.
## Spot: the first stretch after FRACTION of the route that is straight, outside tunnels/bridges and the overpass
## corridors; side and distance per route (SPOTS).

const MODEL := "res://assets/vehicles/traffic/car_skyline.glb"
const PAINT := Color("#1f4fa8")                 # "Bayside" style blue
## route: [fraction of the route, side (+1 right / -1 left), lateral distance (m) of the car centre]
const SPOTS := {
	"kanto_1_coast": [0.45, 1.0, 17.5],          # sea side, on the grass before the sand: lookout over the bay
	"kanto_2_viaduct": [0.55, 1.0, 26.0],        # city: on the ground under the viaduct, before the first street
	"kanto_3_mountain": [0.6, -1.0, 17.0],       # mountain: lay-by on the hill side
}
const DEFAULT_SPOT: Array = [0.5, 1.0, 17.0]
const PAD := Vector2(9.0, 6.5)                   # paved lookout (along x across), metres

var z: float = -1.0
var lateral: float = 0.0
var placed: bool = false


static func enabled() -> bool:
	return not "--no-unique-car" in OS.get_cmdline_user_args() and ResourceLoader.exists(MODEL)


## z of the spot: first z after the fraction with low curvature and nothing in the way (pure: also used by tests).
static func spot_z(track: Track, route_id: String, blocked: Array[Vector2]) -> float:
	var spot: Array = SPOTS.get(route_id, DEFAULT_SPOT)
	var zz: float = track.length_m * float(spot[0])
	while zz < track.length_m - 300.0:
		var ok: bool = absf(track.curve_at(zz)) < 0.35 and absf(track.curve_at(zz + 40.0)) < 0.35 \
			and absf(track.curve_at(zz - 40.0)) < 0.35
		for b in blocked:
			if zz > b.x - 120.0 and zz < b.y + 120.0:
				ok = false
		if ok:
			return zz
		zz += 10.0
	return track.length_m * float(spot[0])


## Keep-out corridor [a, b, radius] (same format as OverpassLayout.keep_out) so trees/buildings leave the spot free.
static func keep_out(path: TrackPath, zz: float, lat: float) -> Array:
	var c: Vector3 = path.world_point(zz, lat / Track.ROAD_HALF_WIDTH_M)
	var f: Vector3 = path.forward_at(zz)
	return [[Vector2(c.x, c.z) - Vector2(f.x, f.z) * 8.0, Vector2(c.x, c.z) + Vector2(f.x, f.z) * 8.0, 9.0]]


func build(path: TrackPath, route_id: String, tod: TimeOfDay, zz: float, field: TerrainField) -> void:
	var spot: Array = SPOTS.get(route_id, DEFAULT_SPOT)
	z = zz
	lateral = float(spot[1]) * float(spot[2])
	var c: Vector3 = path.world_point(z, lateral / Track.ROAD_HALF_WIDTH_M)
	var ground: float = path.center_at(z).y - RoadMesh.deck_height(field.kind if field != null else &"")
	if field != null:
		var h: float = field.height_at(Vector2(c.x, c.z))
		if not is_nan(h):
			ground = h
	c.y = ground
	var yaw: float = path.yaw_at(z)
	var by := Basis(Vector3.UP, yaw)
	# paved pad (a thin slab, a bit below to cover bumps of the terrain)
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(PAD.y, 0.5, PAD.x)
	slab.mesh = bm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color("#55575a")
	sm.roughness = 0.95
	slab.material_override = sm
	slab.transform = Transform3D(by, Vector3(c.x, ground - 0.23, c.z))
	add_child(slab)
	# the car, parked at an angle facing the road (nose toward the traffic)
	var car: Node3D = (load(MODEL) as PackedScene).instantiate() as Node3D
	var cb: Basis = by * Basis(Vector3.UP, -signf(lateral) * deg_to_rad(35.0))
	car.transform = Transform3D(cb, c + Vector3.UP * 0.03 + cb.z * 2.3)      # origin = rear: centre it on the pad
	var paint := StandardMaterial3D.new()
	paint.albedo_color = PAINT
	paint.metallic = 0.6
	paint.roughness = 0.22
	paint.clearcoat_enabled = true
	paint.clearcoat = 1.0
	for mi in car.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		for s in inst.mesh.get_surface_count():
			var cur: Material = inst.get_active_material(s)
			if cur != null and cur.resource_name == "paint_white":
				inst.set_surface_override_material(s, paint)
	add_child(car)
	# discreet highlight: warm pool of light under the car (stronger at night)
	var night: float = 1.0 - (tod.day_amount if tod != null else 1.0)
	add_child(_glow_pool(c + Vector3.UP * 0.06, 0.25 + 0.75 * night))
	placed = true
	print("UNIQUE_T193 %s z=%.0f lateral=%.1f" % [route_id, z, lateral])


func _glow_pool(at: Vector3, strength: float) -> MeshInstance3D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.82, 0.5, 0.55 * strength))
	g.set_color(1, Color(1.0, 0.7, 0.4, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var q := PlaneMesh.new()
	q.size = Vector2(9.0, 9.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = at
	return mi
