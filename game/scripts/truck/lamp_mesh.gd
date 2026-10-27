class_name LampMesh
extends RefCounted
## T-239: lampadas como pecas soltas de uma malha. Os .glb juntam todas as lampadas de um material numa malha so
## (truck_lamp_amber...), entao para achar UMA lampada (a da seta) ou tirar as da porta do bau o jogo separa os
## triangulos em pecas ligadas (vertice em comum ou na mesma posicao). Sem regerar os .glb.

## Uma peca: caixa no espaco de `root` + inicio (no vetor de indices) de cada triangulo dela.
class Piece:
	var box: AABB
	var tris: PackedInt32Array = PackedInt32Array()
	var mesh: MeshInstance3D
	var surface: int = 0


static var _cache: Dictionary = {}          # chave da malha/superficie/transform/filtro -> Array[Piece] (sem o no)


## Pecas da superficie `s` de `m` (caixas no espaco de `root`). `only` (opcional, tamanho > 0): so triangulos com os 3
## vertices dentro dela. Guardado em cache (varios caminhoes iguais na corrida).
static func pieces(m: MeshInstance3D, s: int, root: Node3D, only: AABB = AABB()) -> Array[Piece]:
	var t: Transform3D = PartFit.rel_xform(m, root)
	var key: String = "%d|%d|%s|%s" % [m.mesh.get_rid().get_id(), s, str(t), str(only)]
	if not _cache.has(key):
		_cache[key] = _split(m.mesh, s, t, only)
	var out: Array[Piece] = []
	for p in _cache[key]:
		var q := Piece.new()
		q.box = (p as Piece).box
		q.tris = (p as Piece).tris
		q.mesh = m
		q.surface = s
		out.append(q)
	return out


static func _split(mesh: Mesh, s: int, t: Transform3D, only: AABB) -> Array[Piece]:
	var arr: Array = mesh.surface_get_arrays(s)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		for k in v.size():
			idx.append(k)
	var w := PackedVector3Array()
	w.resize(v.size())
	for i in v.size():
		w[i] = t * v[i]
	var use: bool = only.size != Vector3.ZERO
	var parent := PackedInt32Array()
	parent.resize(v.size())
	for i in v.size():
		parent[i] = i
	var by_pos: Dictionary = {}
	var tris := PackedInt32Array()
	for k in range(0, idx.size(), 3):
		var a: int = idx[k]
		var b: int = idx[k + 1]
		var c: int = idx[k + 2]
		if use and not (only.has_point(w[a]) and only.has_point(w[b]) and only.has_point(w[c])):
			continue
		tris.append(k)
		for i in [a, b, c]:
			var pk: Vector3i = Vector3i((v[i] * 2000.0).round())
			if by_pos.has(pk):
				_union(parent, i, int(by_pos[pk]))
			else:
				by_pos[pk] = i
		_union(parent, a, b)
		_union(parent, a, c)
	var groups: Dictionary = {}
	for k in tris:
		var r: int = _find(parent, idx[k])
		var p: Piece = groups.get(r)
		if p == null:
			p = Piece.new()
			p.box = AABB(w[idx[k]], Vector3.ZERO)
			groups[r] = p
		p.tris.append(k)
		for j in 3:
			p.box = p.box.expand(w[idx[k + j]])
	var out: Array[Piece] = []
	for p in groups.values():
		out.append(p)
	return out


static func _find(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i


static func _union(p: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = _find(p, a)
	var rb: int = _find(p, b)
	if ra != rb:
		p[ra] = rb


## Malha so com os triangulos das pecas (todas da mesma MeshInstance/superficie), no espaco LOCAL dessa malha,
## empurrada `push` (espaco local) para ficar na frente da lampada original. Para a seta piscar no formato da lampada.
static func piece_mesh(list: Array[Piece], push: Vector3, mat: Material) -> ArrayMesh:
	var src: Mesh = list[0].mesh.mesh
	var arr: Array = src.surface_get_arrays(list[0].surface)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nrm: Variant = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if idx.is_empty():
		for k in v.size():
			idx.append(k)
	var ov := PackedVector3Array()
	var on := PackedVector3Array()
	for p in list:
		for k in p.tris:
			for j in 3:
				ov.append(v[idx[k + j]] + push)
				if nrm != null:
					on.append((nrm as PackedVector3Array)[idx[k + j]])
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = ov
	if nrm != null:
		out[Mesh.ARRAY_NORMAL] = on
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	am.surface_set_material(0, mat)
	return am


## Todas as pecas de lampada (materiais `prefix`*) das malhas abaixo de `node`, caixas no espaco de `root`.
## `skip_parts` = ignora as pecas montadas (SOCKET_/MOUNT_/acc_) quando `node` e o modelo do caminhao.
static func lamp_pieces(node: Node, root: Node3D, names: Array[String], skip_parts: bool) -> Array[Piece]:
	var out: Array[Piece] = []
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or not m.is_visible_in_tree() and m.is_inside_tree() or m.has_meta("lod"):
			continue
		if skip_parts and FrameFit._in_part(m, root):
			continue
		for s in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(s)
			if mat != null and LightPatterns.base_name(mat.resource_name) in names:
				out.append_array(pieces(m, s, root))
	return out
