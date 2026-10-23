class_name PeopleKit
extends RefCounted
## T-186: people standing around (only visual, nothing in the sim or the network). One model from the Marco's packs
## (the standing man of "ROAD SIGNS", build_t186_props.py): person.glb (~800 tri) near, person_lod1.glb (~200) far.
## The vertex colour tells the REGION (R: 0 skin, .25 hair, .5 shirt, .75 trousers, 1 shoes); the shader paints the
## shirt with the colour of each copy (MultiMesh custom data: rgb = shirt, a = variant 0..1 for skin, trousers and the
## phase of the idle sway). The model has no skeleton: the "idle" is a slow weight shift and breathing in the shader.
## Places: toll plaza of every route (staff), the road overpass (spectators), the duel stage (drivers, shoppers).

const DIR := "res://assets/scenery/people/"
const NEAR_M: float = 70.0
const FAR_M: float = 320.0
const STAFF := Color("#1d3f8a")            # toll staff: navy uniform
const VEST := Color("#ff7a1a")             # road worker: orange vest
const SHIRTS: Array[Color] = [Color("#e8e8e8"), Color("#2b2b33"), Color("#3a6ea5"), Color("#c8202f"),
	Color("#6b8e5a"), Color("#d8b25a"), Color("#8a5a9e"), Color("#f0f0f0")]
const SHADER := """
shader_type spatial;
render_mode cull_back;
uniform float day = 0.0;
varying float region;
varying vec4 look;
void vertex() {
	region = COLOR.r;
	look = INSTANCE_CUSTOM;
	float ph = look.a * 6.2831;
	float h = clamp(VERTEX.y / 1.7, 0.0, 1.0);
	VERTEX.x += sin(TIME * 0.7 + ph) * 0.018 * h * h;             // weight shift (idle)
	VERTEX.z += sin(TIME * 0.45 + ph * 1.3) * 0.010 * h * h;
	VERTEX.y *= 1.0 + sin(TIME * 1.7 + ph) * 0.004 * h;            // breathing
}
void fragment() {
	float v = look.a;
	vec3 skin = mix(vec3(0.62, 0.45, 0.34), vec3(0.86, 0.68, 0.55), fract(v * 7.31));
	vec3 hair = mix(vec3(0.03, 0.03, 0.03), vec3(0.22, 0.2, 0.2), step(0.85, fract(v * 5.7)));
	vec3 pants = fract(v * 3.13) < 0.5 ? vec3(0.07, 0.08, 0.12) : (fract(v * 3.13) < 0.8 ? vec3(0.22, 0.22, 0.24) : vec3(0.42, 0.37, 0.28));
	vec3 c = region < 0.125 ? skin : (region < 0.375 ? hair : (region < 0.625 ? look.rgb : (region < 0.875 ? pants : vec3(0.05))));
	ALBEDO = c * mix(0.85, 1.0, day);
	ROUGHNESS = region < 0.375 ? 0.6 : 0.9;
	SPECULAR = 0.25;
}
"""

static var _mat: Dictionary = {}


static func available() -> bool:
	return ResourceLoader.exists(DIR + "person.glb") and not "--no-people" in OS.get_cmdline_user_args()


static func material(tod: TimeOfDay) -> ShaderMaterial:
	var day: float = tod.day_amount if tod != null else 1.0
	var k: String = "%.2f" % day
	if not _mat.has(k):
		var m := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = SHADER
		m.shader = sh
		m.set_shader_parameter("day", day)
		_mat[k] = m
	return _mat[k]


## One group of people (one node, 2 MultiMesh: near/far). `looks[i]` = Color(shirt rgb, variant 0..1).
static func group(xforms: Array, looks: Array, tod: TimeOfDay, name: String = "people") -> Node3D:
	var root := Node3D.new()
	root.name = name
	if xforms.is_empty() or not available():
		return root
	for lod in 2:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true          # T-186 trap: custom data WITHOUT colours reaches the shader as COLOR (Compatibility)
		mm.use_custom_data = true
		mm.mesh = GlbMesh.merged(DIR + ("person.glb" if lod == 0 else "person_lod1.glb"))
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_color(i, Color.WHITE)
			mm.set_instance_custom_data(i, looks[i])
		var mi := MultiMeshInstance3D.new()
		mi.name = "lod%d" % lod
		mi.multimesh = mm
		mi.material_override = material(tod)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_begin = 0.0 if lod == 0 else NEAR_M
		mi.visibility_range_end = NEAR_M if lod == 0 else FAR_M
		root.add_child(mi)
	return root


## Standing person at `pos` looking along `dir` (horizontal); scale 0.92-1.06 (height 1.56-1.80 m).
static func stand(pos: Vector3, dir: Vector3, sc: float) -> Transform3D:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length() < 0.001:
		d = Vector3.FORWARD
	return Transform3D(Basis.looking_at(d.normalized(), Vector3.UP).scaled(Vector3.ONE * sc), pos)


static func look(rng: RandomNumberGenerator, shirt: Color = Color(0, 0, 0, 0)) -> Color:
	var c: Color = shirt if shirt.a > 0.0 else SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	return Color(c.r, c.g, c.b, rng.randf())


## Race route: toll staff at the plaza (z = 150) and spectators on the road overpass. Deterministic per route.
static func populate(parent: Node, path: TrackPath, route_id: String, tod: TimeOfDay) -> void:
	if not available():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 1860 + route_id.hash()
	var root := Node3D.new()
	root.name = "PeopleKit"
	parent.add_child(root)
	var xs: Array = []                         # one group per place: the LOD distance is from the group's centre
	var looks: Array = []
	var hw: float = Track.ROAD_HALF_WIDTH_M
	var plaza: bool = TollPlaza3D.enabled(path.track)                 # T-207: staff on the islands, beside the booths
	for side in [-1.0, 1.0]:                                          # toll staff beside the canopy pillars
		for k in 2:
			var z: float = 150.0 + rng.randf_range(-2.5, 2.5) + float(k) * 1.6
			var lat: float = side * rng.randf_range(9.8, 11.2)
			var h: float = 0.0
			if plaza:                                                     # same draws (the overpass people do not move)
				z = path.track.toll.z + (2.75 if k == 0 else -2.75) * side + (lat - side * 10.5) * 0.3
				lat = side * (1.15 if k == 0 else TollPlaza.OUTER_FACE_M + 0.75)
				h = TollParts.ISLAND_TOP
			var to_road: Vector3 = path.world_point(z, (side * 3.7 if plaza else 0.0) / hw) - path.world_point(z, lat / hw)
			xs.append(stand(path.world_point(z, lat / hw, h), to_road.rotated(Vector3.UP, rng.randf_range(-0.6, 0.6)), rng.randf_range(0.94, 1.04)))
			looks.append(look(rng, STAFF))
	var zw: float = 118.0                                              # road worker by the stop line (left shoulder)
	xs.append(stand(path.world_point(zw, -9.6 / hw), -path.forward_at(zw), 1.0))
	looks.append(look(rng, VEST))
	root.add_child(group(xs, looks, tod, "toll"))
	if Overpass3D.enabled():
		for o in OverpassLayout.for_route(route_id):                  # spectators on the overpass railings
			xs = []
			looks = []
			var ax: Dictionary = OverpassLayout.axis(path, o)
			var c: Vector3 = ax["c"]
			var d: Vector3 = ax["d"]
			var f: Vector3 = path.forward_at(float(o["z"]))
			var n := Vector3(-d.z, 0.0, d.x)
			var nb: Vector3 = n if n.dot(f) < 0.0 else -n              # railing on the side the trucks come from
			for k in 5:
				var nn: Vector3 = nb if k < 3 else -nb                  # 3 watch the trucks coming, 2 see them go
				var p: Vector3 = c + d * rng.randf_range(-9.0, 9.0) + nn * 5.0 + Vector3.UP * 0.15
				xs.append(stand(p, nn.rotated(Vector3.UP, rng.randf_range(-0.4, 0.4)), rng.randf_range(0.92, 1.06)))
				looks.append(look(rng))
			root.add_child(group(xs, looks, tod, "overpass_%d" % int(o["z"])))
