class_name WreckProps
extends RefCounted
## T-183: meshes and materials of the crashed car visuals (WreckFx), made by code (no new .glb):
##  - hazard lamps: 4 small amber boxes at the corners of the car body, one ArrayMesh per car model (1 draw call);
##  - lamp glow: a soft additive "cross" (one quad facing along the car, one sideways) on each lamp, 1 draw call;
##  - warning triangle: red reflective frame on a small dark stand (shared mesh).
## Car model frame (Traffic3D): origin on the ground at the rear, front = -Z, +X = right.

const AMBER := Color(1.0, 0.56, 0.08)
const AMBER_OFF := Color(0.32, 0.17, 0.04)
const LAMP_SIZE := Vector3(0.22, 0.12, 0.07)       # m
const GLOW_SIZE: float = 1.5                       # m (glow quad side)
const TRI_SIDE: float = 0.5                        # m (warning triangle side)
const TRI_BAR: float = 0.07                        # m (width of the frame)


## Body box of the car model in its own frame (merge of the mesh AABBs). Works outside the scene tree.
static func body_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first: bool = true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		if inst.mesh == null or String(inst.name).begins_with("wreck_"):
			continue
		var t := Transform3D.IDENTITY
		var p: Node = inst
		while p != null and p != n:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var box: AABB = t * inst.get_aabb()
		out = box if first else out.merge(box)
		first = false
	if first:                                          # no mesh: a typical small car
		out = AABB(Vector3(-0.85, 0.0, -4.5), Vector3(1.7, 1.45, 4.5))
	return out


## Lamp centers [rear left, rear right, front left, front right] for a body box: on the corners, at 55% height,
## sticking a little out of the body so they are seen from behind, from the front and from the side.
static func lamp_points(b: AABB) -> PackedVector3Array:
	var y: float = b.position.y + b.size.y * 0.55
	var x: float = b.size.x * 0.5 - LAMP_SIZE.x * 0.6
	var cx: float = b.position.x + b.size.x * 0.5
	var rear: float = b.end.z + LAMP_SIZE.z * 0.3
	var front: float = b.position.z - LAMP_SIZE.z * 0.3
	return PackedVector3Array([Vector3(cx - x, y, rear), Vector3(cx + x, y, rear), Vector3(cx - x, y, front), Vector3(cx + x, y, front)])


static func lamps_mesh(points: PackedVector3Array) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = LAMP_SIZE
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in points:
		st.append_from(box, 0, Transform3D(Basis.IDENTITY, p))
	return st.commit()


static func glow_mesh(points: PackedVector3Array) -> ArrayMesh:
	var q := QuadMesh.new()
	q.size = Vector2(GLOW_SIZE, GLOW_SIZE)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in points:
		st.append_from(q, 0, Transform3D(Basis.IDENTITY, p))                      # faces along the car
		st.append_from(q, 0, Transform3D(Basis(Vector3.UP, PI * 0.5), p))         # faces sideways
	return st.commit()


static func lamp_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = AMBER
	return m


static func glow_material() -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.25, Color(1, 1, 1, 0.55))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = tex
	m.albedo_color = AMBER
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Warning triangle standing on the ground, facing +Z (the node is turned to face the traffic coming from behind).
static func triangle_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h: float = TRI_SIDE * sqrt(3.0) * 0.5
	var lift: float = 0.06
	var outer: Array[Vector3] = [Vector3(-TRI_SIDE * 0.5, lift, 0.0), Vector3(TRI_SIDE * 0.5, lift, 0.0), Vector3(0.0, lift + h, 0.0)]
	var c := Vector3(0.0, lift + h / 3.0, 0.0)
	var k: float = 1.0 - TRI_BAR * 3.0 / h                       # inner triangle scale (frame width TRI_BAR)
	var red := Color(0.95, 0.06, 0.04)
	st.set_color(red)
	for i in 3:
		var a: Vector3 = outer[i]
		var b: Vector3 = outer[(i + 1) % 3]
		var ai: Vector3 = c + (a - c) * k
		var bi: Vector3 = c + (b - c) * k
		for tri in [[a, b, bi], [a, bi, ai]]:
			for v in tri:
				st.add_vertex(v)
	# small dark stand (base plate and a short post) so it does not float
	st.set_color(Color(0.08, 0.08, 0.08))
	var w: float = TRI_SIDE * 0.45
	for q in [[Vector3(-w, 0.03, 0.06), Vector3(w, 0.03, 0.06), Vector3(w, 0.03, -0.18), Vector3(-w, 0.03, -0.18)],
			[Vector3(-0.02, 0.0, -0.01), Vector3(0.02, 0.0, -0.01), Vector3(0.02, lift, -0.01), Vector3(-0.02, lift, -0.01)]]:
		for i in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[i])
	return st.commit()


## Unshaded: the red reads like a reflector at night too (and the dark stand stays dark).
static func triangle_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
