class_name TrackEvents3D
extends Node3D
## Track events in 3D (T-139): accident, road works, lane narrowing. Visual only, built once from the event list of
## the track (the same on server and clients: TrackEvents). What goes where is in EventProps; here are the batches.
## Per event, 3 draw calls (and only near it: visibility range):
##   solid (ONE mesh with vertex colours: cones, posts, barricade legs, works truck, sign backs, road paint
##   (zebra, lane-end line, arrows, steel plates))  ·  faces (AtlasQuads with EventAtlas: signs, LED boards,
##   barricade stripes)  ·  lights (MultiMesh, additive, blinking in the shader: hazards, flares, beacons, LED arrows)
##   + accident: 2 stopped cars (traffic .glb with 4 surfaces each).
## No per-pixel light (unshaded + day level, like the road signs): cheap on the Compatibility renderer.

const RANGE_M: float = 700.0           # visibility range of an event group (signs start WARN_M before it)
const CAR_RANGE_M: float = 330.0
const SOLID_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform float level = 1.0;
varying vec3 tint;
void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tint = COLOR.rgb * (0.6 + 0.4 * clamp(dot(n, normalize(vec3(0.4, 0.8, 0.3))), 0.0, 1.0));
}
void fragment() { ALBEDO = tint * level; }
"""
## Blinking lights: atlas rect in INSTANCE_CUSTOM, tint in COLOR.rgb, phase in COLOR.a (0..1), additive.
const BLINK_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float rate = 1.4;
varying vec4 tint;
void vertex() {
	vec4 r = INSTANCE_CUSTOM;
	UV = r.xy + UV * r.zw;
	tint = COLOR;
}
void fragment() {
	float ph = fract(TIME * rate + tint.a);
	float on = smoothstep(0.0, 0.08, ph) * (1.0 - smoothstep(0.5, 0.58, ph));
	vec4 c = texture(atlas, UV);
	ALBEDO = c.rgb * tint.rgb * (0.25 + 2.2 * on);
	ALPHA = c.a;
}
"""
## Unit cube (centred), 6 faces x 2 triangles, clockwise seen from outside: [normal, 4 corners].
const CUBE: Array = [
	[Vector3(0, 0, 1), [Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1), Vector3(1, -1, 1)]],
	[Vector3(0, 0, -1), [Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1), Vector3(-1, -1, -1)]],
	[Vector3(1, 0, 0), [Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1), Vector3(1, -1, -1)]],
	[Vector3(-1, 0, 0), [Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1), Vector3(-1, -1, 1)]],
	[Vector3(0, 1, 0), [Vector3(-1, 1, 1), Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1)]],
	[Vector3(0, -1, 0), [Vector3(-1, -1, -1), Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1)]],
]

var path: TrackPath
var events: TrackEvents
var level: float = 1.0
var counts: Dictionary = {}           # kind -> how many (tests / debug)
var groups: Array[Node3D] = []        # one per event
var _atlas: Texture2D
var _cone: Array = []                 # [Vector3 vertex, Vector3 normal, Color] of one cone at the origin
var _mats: Dictionary = {}
# accumulators of the event being built
var faces: AtlasQuads
var lights: Array = []                # [Transform3D, Rect2, Color (a = phase)]
var solid := SurfaceTool.new()
var _solid_used: bool = false
var _root: Node3D


func build(path_: TrackPath, tod: TimeOfDay) -> void:
	path = path_
	events = path.track.events
	level = AtlasQuads.level_for(tod)
	if events == null or events.is_empty():
		return
	_atlas = load(EventAtlas.ATLAS) as Texture2D
	_cone = _make_cone()
	for sh in [["solid", SOLID_SHADER], ["blink", BLINK_SHADER]]:
		var s := Shader.new()
		s.code = sh[1]
		var m := ShaderMaterial.new()
		m.shader = s
		m.set_shader_parameter("level", level)
		if sh[0] == "blink":
			m.set_shader_parameter("atlas", _atlas)
		_mats[sh[0]] = m
	for k in events.list.size():
		_begin(k)
		EventProps.build(self, events.list[k], k)
		_commit()
	if "--fps-log" in OS.get_cmdline_user_args():
		print("EVENTOS 3D: ", counts, "  grupos=", groups.size())
	visible = not "--hide-events-3d" in OS.get_cmdline_user_args()   # depuracao: mede o custo so do visual


func count(kind: String, n: int = 1) -> void:
	counts[kind] = int(counts.get(kind, 0)) + n


# ---------------------------------------------------------------- geometry helpers (lateral in metres)
func pt(z: float, lat_m: float, h: float = 0.0) -> Vector3:
	return path.world_point(z, lat_m / Track.ROAD_HALF_WIDTH_M, h)


## +Z local points to whoever comes along the road (quads face it); `turn` rad to the left.
func basis(z: float, turn: float = 0.0) -> Basis:
	return Basis(Vector3.UP, path.yaw_at(z) + turn)


func face(xf_basis: Basis, c: Vector3, size: Vector2, id: String) -> void:
	faces.add_quad(Transform3D(xf_basis * Basis.from_scale(Vector3(size.x, size.y, 1.0)), c), EventAtlas.uv(id))


## Box of `size` centred at `c` (into the solid mesh).
func box(xf_basis: Basis, c: Vector3, size: Vector3, col: Color) -> void:
	var half: Vector3 = size * 0.5
	for f in CUBE:
		var n: Vector3 = (xf_basis * (f[0] as Vector3)).normalized()
		var q: Array = f[1]
		var p: Array[Vector3] = []
		for v in q:
			p.append(c + xf_basis * ((v as Vector3) * half))
		for i in [0, 1, 2, 0, 2, 3]:
			_vert(p[i], n, col)


func cone(z: float, lat_m: float) -> void:
	var xf := Transform3D(basis(z), pt(z, lat_m, 0.0))
	for v in _cone:
		_vert(xf * (v[0] as Vector3), xf.basis * (v[1] as Vector3), v[2])


## Blinking light (glow or LED arrow) facing the driver.
func light(xf_basis: Basis, c: Vector3, size: float, tint: Color, phase: float, id: String = "glow", aspect: float = 1.0) -> void:
	lights.append([Transform3D(xf_basis * Basis.from_scale(Vector3(size * aspect, size, 1.0)), c), EventAtlas.uv(id),
		Color(tint.r, tint.g, tint.b, fposmod(phase, 1.0))])


## Painted quad on the road between two cross-sections (z0: l0a..l0b, z1: l1a..l1b), lateral in metres.
func paint_quad(z0: float, l0a: float, l0b: float, z1: float, l1a: float, l1b: float, col: Color, h: float = 0.03) -> void:
	var a: Vector3 = pt(z0, l0a, h)
	var b: Vector3 = pt(z0, l0b, h)
	var c: Vector3 = pt(z1, l1b, h)
	var d: Vector3 = pt(z1, l1a, h)
	for v in [a, c, b, a, d, c]:                 # clockwise seen from above (as RoadMesh)
		_vert(v, Vector3.UP, col)


## Painted triangle (any winding: drawn from above).
func paint_tri(p0: Vector3, p1: Vector3, p2: Vector3, col: Color) -> void:
	var up: bool = (p1 - p0).cross(p2 - p0).y < 0.0       # clockwise from above = front face
	for v in ([p0, p1, p2] if up else [p0, p2, p1]):
		_vert(v, Vector3.UP, col)


func _vert(v: Vector3, n: Vector3, col: Color) -> void:
	solid.set_color(col)
	solid.set_normal(n)
	solid.add_vertex(v)
	_solid_used = true


## Traffic car model standing still (accident). `yaw` rad to the left over the road direction.
func stopped_car(model: String, z: float, lat_m: float, yaw: float, paint_col: Color) -> Node3D:
	var ps: PackedScene = load("%s%s.glb" % [Traffic3D.DIR, model]) as PackedScene
	if ps == null:
		return null
	var n: Node3D = ps.instantiate() as Node3D
	var mat := StandardMaterial3D.new()
	mat.albedo_color = paint_col
	mat.metallic = 0.5
	mat.roughness = 0.35
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		inst.visibility_range_end = CAR_RANGE_M
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in inst.mesh.get_surface_count():
			var cur: Material = inst.get_active_material(s)
			if cur != null and cur.resource_name == "paint_white":
				inst.set_surface_override_material(s, mat)
	n.transform = Transform3D(basis(z, yaw), pt(z, lat_m, 0.0))
	_root.add_child(n)
	return n


# ---------------------------------------------------------------- batches
func _begin(k: int) -> void:
	_root = Node3D.new()
	_root.name = "Event%d" % k
	add_child(_root)
	groups.append(_root)
	lights.clear()
	faces = AtlasQuads.new()
	faces.setup(_atlas, level)
	solid = SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	_solid_used = false


func _commit() -> void:
	faces.commit()
	faces.visibility_range_end = RANGE_M
	_root.add_child(faces)
	if _solid_used:
		var mi := MeshInstance3D.new()
		mi.mesh = solid.commit()
		mi.material_override = _mats["solid"]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = RANGE_M
		_root.add_child(mi)
	if not lights.is_empty():
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = q
		mm.instance_count = lights.size()
		for i in lights.size():
			mm.set_instance_transform(i, lights[i][0])
			var r: Rect2 = lights[i][1]
			mm.set_instance_custom_data(i, Color(r.position.x, r.position.y, r.size.x, r.size.y))
			mm.set_instance_color(i, lights[i][2])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mats["blink"]
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = RANGE_M
		_root.add_child(mmi)


## Traffic cone (0,72 m): dark base, orange body with two white reflective bands. [vertex, normal, colour] list.
func _make_cone() -> Array:
	var out: Array = []
	var dark := Color("#202024")
	var b: float = 0.19
	var base: Array[Vector3] = [Vector3(-b, 0.04, -b), Vector3(b, 0.04, -b), Vector3(b, 0.04, b), Vector3(-b, 0.04, b)]
	for i in [0, 1, 2, 0, 2, 3]:
		out.append([base[i], Vector3.UP, dark])
	var orange := Color("#ff5a10")
	var white := Color("#f2f2ee")
	var rings: Array = [[0.04, 0.16, orange], [0.26, 0.125, orange], [0.34, 0.11, white], [0.44, 0.095, orange],
		[0.5, 0.085, white], [0.58, 0.07, orange], [0.72, 0.03, orange]]
	var sides: int = 8
	for r in rings.size() - 1:
		var lo: Array = rings[r]
		var hi: Array = rings[r + 1]
		for s in sides:
			var a0: float = TAU * s / sides
			var a1: float = TAU * (s + 1) / sides
			var n0 := Vector3(cos(a0), 0.35, sin(a0)).normalized()
			var n1 := Vector3(cos(a1), 0.35, sin(a1)).normalized()
			var p00 := Vector3(cos(a0) * lo[1], lo[0], sin(a0) * lo[1])
			var p01 := Vector3(cos(a1) * lo[1], lo[0], sin(a1) * lo[1])
			var p10 := Vector3(cos(a0) * hi[1], hi[0], sin(a0) * hi[1])
			var p11 := Vector3(cos(a1) * hi[1], hi[0], sin(a1) * hi[1])
			for v in [[p00, n0], [p01, n1], [p11, n1], [p00, n0], [p11, n1], [p10, n0]]:   # clockwise = front
				out.append([v[0], v[1], lo[2]])          # the band above each ring has the ring colour
	return out
