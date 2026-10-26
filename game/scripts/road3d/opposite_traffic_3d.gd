class_name OppositeTraffic3D
extends Node3D
## T-217: traffic of the other carriageway (cars, buses, box trucks, dump trucks, semi-trailers and, rarely, an army
## truck) driving TOWARDS the player on the right of the median. Only visual: no sim, no network, never an obstacle
## (it is on the other side of the barrier and the hedge). Deterministic: the position of every vehicle is a function
## of the race clock (frozen in the explorer camera; every player sees about the same thing online).
## Cost: one MultiMesh per model (only the vehicles within WINDOW of the camera are drawn) + one MultiMesh of light
## dots at night. Each lane has ONE speed (nobody overtakes, nobody overlaps).

const DIR := "res://assets/vehicles/traffic/"
## [model, weight, lane preference (0 inner / 1 outer / -1 any), minimum quality]. The cars made by code have 6-7
## surfaces (draw calls) each: only from the high quality up; the medium one (phones) uses the 2-4 surface models.
const MIX: Array = [["car_hatch", 8, -1, 2], ["car_sedan", 9, -1, 2], ["car_van", 6, -1, 2], ["car_kei_truck", 6, 1, 2],
	["car_van01", 7, -1, 0], ["car_suv", 8, -1, 0], ["car_jeep", 3, -1, 1], ["car_lp_coupe", 10, 0, 0],
	["car_lp_hatch", 10, -1, 0], ["car_bus", 6, 1, 0], ["truck_box", 9, 1, 0], ["truck_dump", 5, 1, 0],
	["truck_semi", 6, 1, 0], ["truck_army", 1, 1, 2]]
const LANE_SPEED: Array[float] = [27.0, 21.5]      # m/s: inner (passing) lane, outer lane
const GAP: Vector2 = Vector2(34.0, 120.0)          # free space between two vehicles of a lane
const WINDOW: Vector2 = Vector2(-180.0, 720.0)     # drawn from 180 m behind the camera to 720 m ahead of it
const NEAR: Vector2 = Vector2(-40.0, 130.0)         # full .glb inside this window, a box proxy outside (1 call per class)
const PROXY_CLASSES: Array[String] = ["car", "bus", "truck", "semi"]
const PAINTS: Array[Color] = [Color("#f2f2ef"), Color("#f2f2ef"), Color("#c9ccd1"), Color("#c9ccd1"), Color("#1c1d22"),
	Color("#2a5cc0"), Color("#c8202f"), Color("#7d8288"), Color("#2c9a5a"), Color("#d29a2e"), Color("#efe7d2")]
## Paints of some models (army = olive drab; dump trucks and buses in their usual colours).
const PAINTS_BY_MODEL: Dictionary = {
	"truck_army": [Color("#4b5232")],
	"truck_dump": [Color("#e0a020"), Color("#d8d8d2"), Color("#2f6e3e"), Color("#c0392b")],
	"car_bus": [Color("#f2f2ef"), Color("#2a5cc0"), Color("#2c9a5a"), Color("#e8b21a")],
	"truck_semi": [Color("#f2f2ef"), Color("#1c3f8f"), Color("#b02a2a"), Color("#3a3d42")],
}

var path: TrackPath
var layout: OppositeLayout
var vehicles: Array = []           # [model index, lane, start z (rear), length, paint]
var models: Array[String] = []
var lengths: Array[float] = []
var _mm: Array[MultiMesh] = []
var _proxy: Array[MultiMesh] = []  # per PROXY_CLASSES
var _class_of: Array[int] = []     # per model: index in PROXY_CLASSES
var _lights: MultiMesh
var _night: bool = false
var _span: float = 1.0
var clock: Callable                # () -> float: race clock that stops in the explorer camera (race_scene_3d)
var drawn: int = 0                 # vehicles drawn in the last update (tests / measures)
var _near: Vector2 = NEAR
var _nodes: Array[MultiMeshInstance3D] = []   # all the MultiMesh nodes (custom AABB = small box at the camera)
var _mm_nodes: Array[MultiMeshInstance3D] = []
var _proxy_nodes: Array[MultiMeshInstance3D] = []


func build(layout_: OppositeLayout, tod: TimeOfDay, q: int, seed_: int) -> void:
	layout = layout_
	path = layout.path
	_span = path.end_m()
	_night = tod.headlights
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--opp-near="):             # measures: --opp-near=-50,150 (0,0 = proxies only)
			var v: PackedFloat64Array = a.substr(11).split_floats(",")
			_near = Vector2(v[0], v[1])
	var weights: Array = []
	for e in MIX:
		var p: String = "%s%s.glb" % [DIR, String(e[0])]
		if not ResourceLoader.exists(p) or q < int(e[3]):
			continue
		var mesh: ArrayMesh = _paintable(p)
		if mesh == null:
			continue
		models.append(String(e[0]))
		lengths.append(maxf(mesh.get_aabb().size.z, 3.5))
		weights.append([models.size() - 1, int(e[1]), int(e[2])])
		_mm.append(_multi(mesh, 10))
		_mm_nodes.append(_nodes[_nodes.size() - 1])
		var m: String = String(e[0])
		_class_of.append(1 if m == "car_bus" else (3 if m == "truck_semi" else (2 if m.begins_with("truck") else 0)))
	if models.is_empty():
		return
	for c in PROXY_CLASSES.size():
		_proxy.append(_multi(_proxy_mesh(c), 64))
		_proxy_nodes.append(_nodes[_nodes.size() - 1])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var gap_k: float = 1.0 if q >= 1 else 1.6
	for lane in OppositeLayout.LANES:
		var z: float = rng.randf_range(0.0, GAP.y)
		while z < _span - 20.0:
			var m: int = _pick(rng, weights, lane)
			var pal: Array = PAINTS_BY_MODEL.get(models[m], PAINTS)
			vehicles.append([m, lane, z, lengths[m], pal[rng.randi_range(0, pal.size() - 1)]])
			z += lengths[m] + rng.randf_range(GAP.x, GAP.y) * gap_k
	if _night:
		_lights = _light_multi()
	update(0.0, path.center_at(0.0))


func _process(_dt: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null and clock.is_valid():
		update(float(clock.call()), cam.global_position)


static func _pick(rng: RandomNumberGenerator, weights: Array, lane: int) -> int:
	var total: int = 0
	for w in weights:
		if int(w[2]) < 0 or int(w[2]) == lane:
			total += int(w[1])
	var r: int = rng.randi_range(0, maxi(total - 1, 0))
	for w in weights:
		if int(w[2]) < 0 or int(w[2]) == lane:
			r -= int(w[1])
			if r < 0:
				return int(w[0])
	return int(weights[0][0])


## Copy of the merged .glb where the "paint_white" surfaces take the colour of each copy (MultiMesh colour).
func _paintable(p: String) -> ArrayMesh:
	var src: ArrayMesh = GlbMesh.merged(p)
	if src == null or src.get_surface_count() == 0:
		return null
	var mesh: ArrayMesh = src.duplicate() as ArrayMesh
	mesh.resource_name = p
	for s in mesh.get_surface_count():
		var m: Material = mesh.surface_get_material(s)
		if m != null and m.resource_name == "paint_white":
			var paint := StandardMaterial3D.new()
			paint.vertex_color_use_as_albedo = true
			paint.metallic = 0.45
			paint.roughness = 0.32
			mesh.surface_set_material(s, paint)
	return mesh


func _multi(mesh: ArrayMesh, cap: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = cap
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nodes.append(mi)
	add_child(mi)
	return mm


func _light_multi() -> MultiMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = t
	m.no_depth_test = false
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = q
	mm.instance_count = 240
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nodes.append(mi)
	add_child(mi)
	return mm


## Rear of vehicle k at the race clock t (they drive towards -z; wraps around the drawn road).
func rear_z(k: int, t: float) -> float:
	var v: Array = vehicles[k]
	return fposmod(float(v[2]) - LANE_SPEED[int(v[1])] * t, _span)


## Places the vehicles for the race clock `t` (s) around the camera.
func update(t: float, cam: Vector3) -> void:
	if models.is_empty():
		return
	var cz: float = _camera_z(cam)
	var counts: Array[int] = []
	counts.resize(models.size())
	counts.fill(0)
	var pcounts: Array[int] = []
	pcounts.resize(PROXY_CLASSES.size())
	pcounts.fill(0)
	var lights: int = 0
	drawn = 0
	for k in vehicles.size():
		var v: Array = vehicles[k]
		var zr: float = rear_z(k, t)
		var len_: float = float(v[3])
		var rel: float = zr - cz                                  # > 0 = ahead of the camera (they come from there)
		if rel < WINDOW.x or rel > WINDOW.y:
			continue
		var m: int = int(v[0])
		var near: bool = rel >= _near.x and rel <= _near.y
		var pc: int = _class_of[m]
		if (near and counts[m] >= _mm[m].instance_count) or (not near and pcounts[pc] >= _proxy[pc].instance_count):
			continue
		var lat: float = OppositeLayout.lane_center(int(v[1]))
		var rear: Vector3 = path.world_point(zr, lat / Track.ROAD_HALF_WIDTH_M, 0.0)
		var front: Vector3 = path.world_point(maxf(zr - len_, 0.0), lat / Track.ROAD_HALF_WIDTH_M, 0.0)
		var fwd: Vector3 = front - rear
		if fwd.length_squared() < 0.01:
			fwd = -path.forward_at(zr)
		var b := Basis.looking_at(fwd.normalized(), Vector3.UP)
		var xf := Transform3D(b, rear)
		if near:
			_mm[m].set_instance_transform(counts[m], xf)
			_mm[m].set_instance_color(counts[m], v[4])
			counts[m] += 1
		else:
			_proxy[pc].set_instance_transform(pcounts[pc], Transform3D(b * Basis.from_scale(Vector3(1.0, 1.0, len_)), rear))
			_proxy[pc].set_instance_color(pcounts[pc], v[4])
			pcounts[pc] += 1
		drawn += 1
		if _lights != null and rel < 520.0:
			lights = _add_lights(lights, xf, len_, models[m])
	# visible_instance_count = 0 still draws ONE copy in the Compatibility renderer (measured: +84 k triangles with
	# the 14 models empty): hide the node instead.
	for m in _mm.size():
		_mm[m].visible_instance_count = counts[m]
		_mm_nodes[m].visible = counts[m] > 0
	for c in _proxy.size():
		_proxy[c].visible_instance_count = pcounts[c]
		_proxy_nodes[c].visible = pcounts[c] > 0
	# A small box at the camera: the nodes are always drawn (all their copies), without a big AABB that made the
	# sun's shadow cascades take the whole scene (+85 k triangles in the shadow pass, measured).
	var aabb := AABB(cam - Vector3(30.0, 30.0, 30.0), Vector3(60.0, 60.0, 60.0))
	for n in _nodes:
		n.custom_aabb = aabb
	if _lights != null:
		_lights.visible_instance_count = lights
		_nodes[_nodes.size() - 1].visible = lights > 0


## Box proxy of a vehicle class seen from far away: unit length along -Z (scaled by the vehicle length), real width
## and height; vertex colour multiplies the paint of the copy (windows and tyres darker).
func _proxy_mesh(c: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts: Array = []          # [centre, size, colour] with z in 0..-1
	match c:
		0:
			parts = [[Vector3(0, 0.68, -0.5), Vector3(1.7, 0.75, 1.0), Color.WHITE],
				[Vector3(0, 1.3, -0.47), Vector3(1.5, 0.5, 0.52), Color(0.32, 0.34, 0.38)]]
		1:
			parts = [[Vector3(0, 1.55, -0.5), Vector3(2.5, 2.4, 1.0), Color.WHITE],
				[Vector3(0, 2.15, -0.5), Vector3(2.52, 0.75, 0.96), Color(0.25, 0.27, 0.3)]]
		2:
			parts = [[Vector3(0, 1.55, -0.89), Vector3(2.3, 2.3, 0.22), Color.WHITE],
				[Vector3(0, 2.2, -0.995), Vector3(2.1, 0.8, 0.02), Color(0.22, 0.24, 0.28)],
				[Vector3(0, 1.95, -0.38), Vector3(2.45, 2.6, 0.76), Color(0.95, 0.95, 0.95)]]
		_:
			parts = [[Vector3(0, 1.55, -0.94), Vector3(2.4, 2.4, 0.12), Color.WHITE],
				[Vector3(0, 2.05, -0.43), Vector3(2.5, 2.8, 0.84), Color(0.85, 0.86, 0.88)]]
	for p in parts:
		Ribbon.box(st, Basis.IDENTITY, p[0], p[1], p[2])
	Ribbon.box(st, Basis.IDENTITY, Vector3(0, 0.3, -0.5), Vector3(1.9 if c == 0 else 2.4, 0.6, 0.9), Color(0.08, 0.08, 0.08))
	var mesh: ArrayMesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.45
	mesh.surface_set_material(0, m)
	return mesh


## Headlights (warm white, at the front, facing the player) and, on trucks, amber marker lamps on the cab roof.
func _add_lights(n: int, xf: Transform3D, len_: float, model: String) -> int:
	var truck: bool = model.begins_with("truck") or model == "car_bus"
	var hw: float = 0.95 if truck else 0.68
	var hy: float = 0.95 if truck else 0.68
	var spots: Array = [[Vector3(-hw, hy, -len_ - 0.15), Color(1.0, 0.92, 0.75) * 1.6, 0.9],
		[Vector3(hw, hy, -len_ - 0.15), Color(1.0, 0.92, 0.75) * 1.6, 0.9],
		[Vector3(-hw * 0.95, hy + 0.1, 0.1), Color(1.0, 0.12, 0.06) * 0.9, 0.5],
		[Vector3(hw * 0.95, hy + 0.1, 0.1), Color(1.0, 0.12, 0.06) * 0.9, 0.5]]
	if truck and model != "car_bus":
		for x in [-0.8, -0.4, 0.0, 0.4, 0.8]:
			spots.append([Vector3(x, 2.85, -len_ + 0.4), Color(1.0, 0.55, 0.1) * 1.2, 0.35])
	for s in spots:
		if n >= _lights.instance_count:
			return n
		var p: Vector3 = xf * (s[0] as Vector3)
		_lights.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * float(s[2])), p))
		_lights.set_instance_color(n, s[1])
		n += 1
	return n


## Track z of the camera (nearest centre-line point). Searches near the last one; a teleport (explorer camera,
## camera cuts) scans the whole road.
var _last_cz: float = -1.0
var _last_cam: Vector3 = Vector3(INF, 0.0, 0.0)
func _camera_z(cam: Vector3) -> float:
	var best: float = INF
	var bz: float = maxf(_last_cz, 0.0)
	var z: float = maxf(_last_cz - 120.0, 0.0)
	var z1: float = minf(_last_cz + 120.0, _span)
	if _last_cz < 0.0 or cam.distance_to(_last_cam) > 60.0:
		z = 0.0
		z1 = _span
	_last_cam = cam
	while z <= z1:
		var p: Vector3 = path.center_at(z)
		var d: float = Vector2(p.x - cam.x, p.z - cam.z).length_squared()
		if d < best:
			best = d
			bz = z
		z += 6.0
	_last_cz = bz
	return bz
