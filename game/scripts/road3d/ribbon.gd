class_name Ribbon
extends RefCounted
## T-217: geometry helpers for things swept along the road (the other carriageway, stone walls, the median hedge):
## points at (segment i, lateral m, height m) like RoadMesh._edge, strips seen from above, vertical faces with
## (metres along, height) UVs, swept profiles and boxes. Callers pick materials; faces here go with materials that
## draw both sides (CULL_DISABLED) unless noted, so the winding never hides a face.

var path: TrackPath


func _init(path_: TrackPath) -> void:
	path = path_


func edge(i: int, lat: float, up: float = 0.0) -> Vector3:
	var a: float = path.yaw[i]
	return path.pos[i] + Vector3(cos(a), 0.0, -sin(a)) * lat + Vector3.UP * up


## Horizontal strip from lateral l0 to l1 between segments i and j (UV = world x/z / tile, like RoadMesh).
func strip(st: SurfaceTool, i: int, j: int, l0: float, l1: float, h0: float = 0.0, h1: float = 0.0,
		col: Color = Color.WHITE, tile: float = 4.0) -> void:
	var a: Vector3 = edge(i, minf(l0, l1), h0 if l0 < l1 else h1)
	var b: Vector3 = edge(i, maxf(l0, l1), h1 if l0 < l1 else h0)
	var c: Vector3 = edge(j, maxf(l0, l1), h1 if l0 < l1 else h0)
	var d: Vector3 = edge(j, minf(l0, l1), h0 if l0 < l1 else h1)
	for v in [a, c, b, a, d, c]:
		st.set_color(col)
		st.set_uv(Vector2(v.x, v.z) / tile)
		st.add_vertex(v)


## Swept profile [[lateral, height, v], ...] between segments i and j; u = metres along / u_tile.
## `side` mirrors the laterals (-1 = left of the road).
func sweep(st: SurfaceTool, i: int, j: int, prof: Array, side: float = 1.0, col: Color = Color.WHITE,
		u_tile: float = 4.0, base_lat: float = 0.0, base_lat_j: float = NAN) -> void:
	var bj: float = base_lat if is_nan(base_lat_j) else base_lat_j
	var ui: float = float(i) * Track.SEG_LEN / u_tile
	var uj: float = float(j) * Track.SEG_LEN / u_tile
	for k in prof.size() - 1:
		var p0: Array = prof[k]
		var p1: Array = prof[k + 1]
		var a: Vector3 = edge(i, side * (base_lat + float(p0[0])), float(p0[1]))
		var b: Vector3 = edge(i, side * (base_lat + float(p1[0])), float(p1[1]))
		var c: Vector3 = edge(j, side * (bj + float(p1[0])), float(p1[1]))
		var d: Vector3 = edge(j, side * (bj + float(p0[0])), float(p0[1]))
		var v0: float = float(p0[2]) if p0.size() > 2 else float(p0[1])
		var v1: float = float(p1[2]) if p1.size() > 2 else float(p1[1])
		var uvs: Array = [Vector2(ui, v0), Vector2(ui, v1), Vector2(uj, v1), Vector2(uj, v0)]
		var vs: Array = [a, b, c, d]
		for n in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_uv(uvs[n])
			st.add_vertex(vs[n])


## Box (centre c, basis b, full size), clockwise from outside (TrackEvents3D.CUBE). `uv` = false: colour + normal per
## face (same vertex format as PierT, no generate_normals); true: colour + UV (for surfaces made with strip/sweep).
static func box(st: SurfaceTool, b: Basis, c: Vector3, size: Vector3, col: Color, uv: bool = false) -> void:
	var half: Vector3 = size * 0.5
	for f in TrackEvents3D.CUBE:
		var n: Vector3 = (b * (f[0] as Vector3)).normalized()
		var q: Array = f[1]
		var p: Array[Vector3] = []
		for v in q:
			p.append(c + b * ((v as Vector3) * half))
		for k in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			if uv:
				st.set_uv(Vector2((p[k] as Vector3).x + (p[k] as Vector3).y, (p[k] as Vector3).z + (p[k] as Vector3).y) * 0.25)
			else:
				st.set_normal(n)
			st.add_vertex(p[k])


## Commits a SurfaceTool as one MeshInstance3D child of `parent` (no shadows); returns the triangle count.
static func add_mesh(parent: Node3D, st: SurfaceTool, mat: Material, view_m: float = 0.0, normals: bool = true,
		tangents: bool = false) -> int:
	if normals:
		st.generate_normals()
	if tangents:
		st.generate_tangents()
	var mesh: ArrayMesh = st.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return 0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if view_m > 0.0:
		mi.visibility_range_end = view_m
		mi.visibility_range_end_margin = 20.0
	parent.add_child(mi)
	return mesh.surface_get_array_len(0) / 3


## Material that draws both faces (copy of `m`).
static func two_sided(m: BaseMaterial3D) -> BaseMaterial3D:
	var d: BaseMaterial3D = m.duplicate() as BaseMaterial3D
	d.cull_mode = BaseMaterial3D.CULL_DISABLED
	return d
