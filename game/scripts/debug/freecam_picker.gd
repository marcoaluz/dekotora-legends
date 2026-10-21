class_name FreecamPicker
extends RefCounted
## What is under the crosshair of the explorer camera (T-181). The scenery has no collision shapes, so the ray is
## tested against the visible triangles: AABB first (MeshInstance3D and every MultiMesh instance), then the
## TriangleMesh of the closest candidates (C++ BVH), nearest first. Debug only: nothing is built until the first pick
## and clear() drops the caches when the camera is switched off.

const MAX_DIST: float = 9000.0
const LIST_REFRESH_S: float = 2.0

var root: Node                     # race scene (all world geometry lives under it)
var exclude: Node                  # freecam node (never pick our own things)
var _tms: Dictionary = {}          # Mesh instance id -> [TriangleMesh, PackedInt32Array triangle end per surface]
var _nodes: Array = []             # cached GeometryInstance3D list
var _nodes_age: float = INF


func _init(root_: Node = null, exclude_: Node = null) -> void:
	root = root_
	exclude = exclude_


func clear() -> void:
	_tms.clear()
	_nodes.clear()
	_nodes_age = INF


## Called every frame by the camera; refreshes the node list every LIST_REFRESH_S (trucks/parts come and go).
func tick(dt: float) -> void:
	_nodes_age += dt


## Nearest hit of the ray (world space). Empty Dictionary when nothing is hit. Keys: position, distance, node,
## instance (-1 or MultiMesh index), label, name, system, file, material.
func pick(from: Vector3, dir: Vector3) -> Dictionary:
	if root == null:
		return {}
	dir = dir.normalized()
	if _nodes_age >= LIST_REFRESH_S:
		_nodes = root.find_children("*", "GeometryInstance3D", true, false)
		_nodes_age = 0.0
	var cands: Array = []
	for n in _nodes:
		if not is_instance_valid(n) or not (n as Node3D).is_visible_in_tree():
			continue
		if exclude != null and exclude.is_ancestor_of(n):
			continue
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n
			if mi.mesh != null:
				_candidate(cands, mi, mi.global_transform, mi.mesh.get_aabb(), -1, from, dir)
		elif n is MultiMeshInstance3D:
			_multi_candidates(cands, n as MultiMeshInstance3D, from, dir)
	cands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var best: Dictionary = {}
	var best_d: float = MAX_DIST
	for c in cands:
		if float(c[0]) > best_d:
			break
		var node: GeometryInstance3D = c[1]
		var mesh: Mesh = (node as MeshInstance3D).mesh if node is MeshInstance3D else (node as MultiMeshInstance3D).multimesh.mesh
		var entry: Array = _tri(mesh)
		if entry[0] == null:
			continue
		var xf: Transform3D = c[2]
		var inv: Transform3D = xf.affine_inverse()
		var r: Dictionary = (entry[0] as TriangleMesh).intersect_ray(inv * from, (inv.basis * dir).normalized())
		if r.is_empty():
			continue
		var local_hit: Vector3 = r["position"]
		var wp: Vector3 = xf * local_hit
		var d: float = wp.distance_to(from)
		if d < best_d and (wp - from).dot(dir) >= 0.0:
			best_d = d
			best = {"position": wp, "distance": d, "node": node, "instance": int(c[3]), "local": local_hit,
				"surface": _surface_of(int(r.get("face_index", -1)), entry[1] as PackedInt32Array), "mesh": mesh}
	if best.is_empty():
		return best
	best.merge(describe(best["node"], root, best["mesh"], int(best["surface"]), best["local"], int(best["instance"])), true)
	return best


func _candidate(cands: Array, node: GeometryInstance3D, xf: Transform3D, aabb: AABB, idx: int, from: Vector3, dir: Vector3) -> void:
	var inv: Transform3D = xf.affine_inverse()
	var lf: Vector3 = inv * from
	var hit: Variant = aabb.grow(0.01).intersects_ray(lf, inv.basis * dir)
	if hit == null:
		return
	var entry: float = (xf * (hit as Vector3)).distance_to(from)
	if entry > MAX_DIST:
		return
	if node.visibility_range_end > 0.0 and entry > node.visibility_range_end + aabb.get_longest_axis_size():
		return                                      # culled by distance: not on screen
	cands.append([entry, node, xf, idx])


func _multi_candidates(cands: Array, mmi: MultiMeshInstance3D, from: Vector3, dir: Vector3) -> void:
	var mm: MultiMesh = mmi.multimesh
	if mm == null or mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D:
		return
	var gxf: Transform3D = mmi.global_transform
	var inv: Transform3D = gxf.affine_inverse()
	var whole: AABB = mmi.get_aabb()                    # empty without a real renderer (headless): test every copy
	if whole.has_volume() and whole.grow(0.5).intersects_ray(inv * from, inv.basis * dir) == null:
		return
	var maabb: AABB = mm.mesh.get_aabb()
	var count: int = mm.instance_count if mm.visible_instance_count < 0 else mini(mm.visible_instance_count, mm.instance_count)
	for i in count:
		_candidate(cands, mmi, gxf * mm.get_instance_transform(i), maabb, i, from, dir)


## [TriangleMesh, triangle end per surface] of a mesh (cached). The mesh is duplicated first: Mesh caches the
## TriangleMesh it generates forever (see PlateSpot); the copy lets clear() really free the memory.
func _tri(mesh: Mesh) -> Array:
	var id: int = mesh.get_instance_id()
	if _tms.has(id):
		return _tms[id]
	var tm: TriangleMesh = (mesh.duplicate() as Mesh).generate_triangle_mesh()
	var ends := PackedInt32Array()
	if mesh is ArrayMesh:
		var am: ArrayMesh = mesh
		var acc: int = 0
		for s in am.get_surface_count():
			if am.surface_get_primitive_type(s) == Mesh.PRIMITIVE_TRIANGLES:
				var il: int = am.surface_get_array_index_len(s)
				acc += (il if il > 0 else am.surface_get_array_len(s)) / 3
			ends.append(acc)
	_tms[id] = [tm, ends]
	return _tms[id]


static func _surface_of(face: int, ends: PackedInt32Array) -> int:
	if face < 0:
		return -1
	for s in ends.size():
		if face < ends[s]:
			return s
	return 0 if ends.is_empty() else -1


## Human-readable description of a hit: system (top node under the race), name, source .glb and material.
static func describe(node: Node, root: Node, mesh: Mesh, surface: int, local_hit: Vector3, instance: int = -1) -> Dictionary:
	var system: String = ""
	var scene: Node = null
	var c: Node = node
	while c != null and c != root:
		if scene == null and c.scene_file_path != "":
			scene = c
		if c.get_parent() == root:
			var sc: Script = c.get_script() as Script
			system = String(sc.get_global_name()) if sc != null and sc.get_global_name() != &"" else String(c.name)
		c = c.get_parent()
	var mat: Material = null
	if surface >= 0 and mesh != null and surface < mesh.get_surface_count():
		mat = (node as MeshInstance3D).get_active_material(surface) if node is MeshInstance3D else mesh.surface_get_material(surface)
	var mat_name: String = ""
	if mat != null:
		mat_name = mat.resource_name
		if mat_name == "" and mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
			mat_name = (mat as ShaderMaterial).shader.resource_path.get_file().get_basename()
	var file: String = ""
	var name: String = ""
	if scene != null:
		file = scene.scene_file_path
		name = String(scene.name) + ("" if scene == node else "/" + String(node.name))
	else:
		var piece: Mesh = _piece_at(node, local_hit)
		var src: Mesh = piece if piece != null else mesh
		file = GlbMesh.source_of(src)
		if file != "":
			name = file.get_file().get_basename()
		elif not _generic(node):
			name = String(node.name)
		elif src != null and src.resource_name != "":
			name = src.resource_name
		elif mat_name != "":
			name = mat_name
		else:                                           # unnamed child: its position among the siblings tells them apart
			name = "%s_%d" % [node.get_class(), node.get_index()]
	if instance >= 0:
		name += " #%d" % instance
	return {"system": system, "name": name, "file": file, "material": mat_name,
		"label": ("%s > %s" % [system, name]) if system != "" and system != name else name}


## Name given by add_child() without a name ("MeshInstance3D", "MeshInstance3D2", "@MeshInstance3D@123").
static func _generic(node: Node) -> bool:
	var n: String = String(node.name)
	return n.begins_with("@") or n.begins_with(node.get_class())


## MeshBatch blocks keep their pieces (meta "pieces" = [[Mesh, Transform3D], ...]): the smallest piece whose box
## contains the hit point (local to the block) is the one under the crosshair.
static func _piece_at(node: Node, local_hit: Vector3) -> Mesh:
	if not node.has_meta("pieces"):
		return null
	var best: Mesh = null
	var best_v: float = INF
	for p in node.get_meta("pieces") as Array:
		var m: Mesh = p[0]
		var box: AABB = ((p[1] as Transform3D) * m.get_aabb()).grow(0.05)
		if box.has_point(local_hit) and box.get_volume() < best_v:
			best_v = box.get_volume()
			best = m
	return best
