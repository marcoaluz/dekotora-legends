class_name LifeStreets
extends Node3D
## T-189 (vida, city): cars driving both ways on the ground streets beside the viaduct (the streets of the T-188
## city blocks, CityBlocks) and people standing on the sidewalks. Only visual: no sim, no network, never an
## obstacle (the streets are 9 m below the expressway). Cars keep to the left (Japan). Fixed seed per route.
## The streets exist only in the city stretch of ScenicZone; outside it there is nothing to drive on.

const MODELS: Array[String] = ["car_hatch", "car_sedan", "car_van", "car_kei_truck", "car_suv", "car_van01"]
const CARS_PER_LANE: int = 3
const CAR_LEN: float = 4.3
const LANE_OFF: float = 3.0          # m from the street centre line
const SIDEWALK_OFF: float = 7.6      # m from the street centre line (people)

var path: TrackPath
var field: TerrainField
var zone: Vector2
var lanes: Array[Dictionary] = []    # {lat, dir}
var people_count: int = 0
var _cars: Array[Dictionary] = []    # {node, lane, z, speed}
var _deck: float = 0.0


static func streets_for(zone_: Vector2) -> Array[float]:
	if zone_.y <= zone_.x:
		return []
	return [-(CityBlocks.START_L - CityBlocks.STREET_M * 0.6), CityBlocks.START_R - CityBlocks.STREET_M * 0.6]


func setup(path_: TrackPath, field_: TerrainField, zone_: Vector2, route_id: String, tod: TimeOfDay, q: int) -> void:
	path = path_
	field = field_
	zone = zone_
	_deck = RoadMesh.deck_height(&"city")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1893 + route_id.hash()
	for c in streets_for(zone):
		lanes.append({"lat": c - LANE_OFF, "dir": 1.0})          # keep left: going +z = left side of the street
		lanes.append({"lat": c + LANE_OFF, "dir": -1.0})
	var per_lane: int = CARS_PER_LANE if q >= 2 else 2
	# T-192: the streets now run along the whole route: same density as the ~750 m pilot stretch (capped)
	per_lane = mini(int(ceil(float(per_lane) * maxf(1.0, (zone.y - zone.x) / 750.0))), 4 * per_lane)
	var scenes: Dictionary = {}
	for li in lanes.size():
		for k in per_lane:
			var model: String = MODELS[rng.randi_range(0, MODELS.size() - 1)]
			var p: String = "%s%s.glb" % [Traffic3D.DIR, model]
			if not ResourceLoader.exists(p):
				continue
			if not scenes.has(model):
				scenes[model] = load(p)
			var n: Node3D = (scenes[model] as PackedScene).instantiate() as Node3D
			if tod.headlights:
				_add_lights(n)
			add_child(n)
			var z: float = lerpf(zone.x, zone.y, (float(k) + rng.randf_range(0.1, 0.8)) / float(per_lane))
			_cars.append({"node": n, "lane": li, "z": z, "speed": rng.randf_range(10.0, 15.0)})
	_people(rng, tod)
	update(0.0)


## Ground height under (z, lat): the T-188 terrain, or the plain under the viaduct.
func ground(z: float, lat: float) -> Vector3:
	var p: Vector3 = path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M, -_deck)
	if field != null:
		var h: float = field.height_at(Vector2(p.x, p.z))
		if not is_nan(h):
			p.y = h
	return p


func update(dt: float) -> void:
	for c in _cars:
		var lane: Dictionary = lanes[int(c["lane"])]
		var dir: float = float(lane["dir"])
		var z: float = float(c["z"]) + dir * float(c["speed"]) * dt
		if z > zone.y:
			z = zone.x
		elif z < zone.x:
			z = zone.y
		c["z"] = z
		var mid: Vector3 = ground(z, float(lane["lat"]))
		var d: Vector3 = path.forward_at(z) * dir
		var b := Basis.looking_at(Vector3(d.x, 0.0, d.z).normalized(), Vector3.UP)
		(c["node"] as Node3D).transform = Transform3D(b, mid - b.z * -CAR_LEN * 0.5 + Vector3.UP * 0.02)


## Small lit headlights (front, local -Z) and tail lights (rear) for the night.
static func _add_lights(car: Node3D) -> void:
	for front in [true, false]:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.95, 0.8) if front else Color(1.0, 0.1, 0.05)
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = 4.0 if front else 2.0
		for sx in [-0.6, 0.6]:
			var s := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.11
			sm.height = 0.22
			sm.radial_segments = 6
			sm.rings = 3
			s.mesh = sm
			s.material_override = m
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			s.position = Vector3(sx, 0.65, -CAR_LEN + 0.1) if front else Vector3(sx, 0.75, 0.05)
			car.add_child(s)


## People standing on the sidewalks (one group per 150 m: the LOD distance is from the group's centre, T-186 trap).
func _people(rng: RandomNumberGenerator, tod: TimeOfDay) -> void:
	if not PeopleKit.available():
		return
	for c in streets_for(zone):
		var z: float = zone.x + 20.0
		while z < zone.y - 20.0:
			var xs: Array = []
			var looks: Array = []
			var z_end: float = minf(z + 150.0, zone.y - 20.0)
			for k in rng.randi_range(4, 8):
				var zz: float = rng.randf_range(z, z_end)
				var side: float = 1.0 if rng.randf() < 0.5 else -1.0
				var lat: float = c + side * (SIDEWALK_OFF + rng.randf_range(-0.6, 0.6))
				var pos: Vector3 = ground(zz, lat) + Vector3.UP * 0.15
				var face: Vector3 = (ground(zz, c) - pos).rotated(Vector3.UP, rng.randf_range(-1.4, 1.4))
				xs.append(PeopleKit.stand(pos, face, rng.randf_range(0.92, 1.06)))
				looks.append(PeopleKit.look(rng))
			people_count += xs.size()
			add_child(PeopleKit.group(xs, looks, tod, "street_%d" % int(z)))
			z = z_end + 1.0
