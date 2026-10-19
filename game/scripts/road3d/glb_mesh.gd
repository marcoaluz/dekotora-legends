class_name GlbMesh
extends RefCounted
## Junta todas as malhas de um .glb em UM ArrayMesh (varias superficies, materiais preservados),
## aplicando as transformacoes dos nos. Serve para usar modelos do Blender em MultiMesh.

static var _cache: Dictionary = {}


static func merged(path: String) -> ArrayMesh:
	if _cache.has(path):
		return _cache[path]
	var out := ArrayMesh.new()
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		push_warning("GlbMesh: nao achei " + path)
		_cache[path] = out
		return out
	var root: Node = ps.instantiate()
	_collect(root, Transform3D.IDENTITY, out)
	root.free()
	_cache[path] = out
	return out


static func _collect(node: Node, parent_xf: Transform3D, out: ArrayMesh) -> void:
	var xf: Transform3D = parent_xf
	if node is Node3D:
		xf = parent_xf * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		var mesh: Mesh = mi.mesh
		if mesh != null:
			for s in mesh.get_surface_count():
				var arrays: Array = mesh.surface_get_arrays(s)
				var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
				for i in verts.size():
					verts[i] = xf * verts[i]
				for i in norms.size():
					norms[i] = (xf.basis * norms[i]).normalized()
				arrays[Mesh.ARRAY_VERTEX] = verts
				if norms.size() > 0:
					arrays[Mesh.ARRAY_NORMAL] = norms
				var tans: Variant = arrays[Mesh.ARRAY_TANGENT]
				if tans is PackedFloat32Array and (tans as PackedFloat32Array).size() == verts.size() * 4:
					var t4: PackedFloat32Array = tans
					for i in verts.size():                      # tangentes giradas junto (mapa de normais, T-146)
						var t: Vector3 = (xf.basis * Vector3(t4[i * 4], t4[i * 4 + 1], t4[i * 4 + 2])).normalized()
						t4[i * 4] = t.x
						t4[i * 4 + 1] = t.y
						t4[i * 4 + 2] = t.z
					arrays[Mesh.ARRAY_TANGENT] = t4
				else:
					arrays[Mesh.ARRAY_TANGENT] = null
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				var mat: Material = mi.get_active_material(s)
				out.surface_set_material(out.get_surface_count() - 1, mat)
	for c in node.get_children():
		_collect(c, xf, out)
