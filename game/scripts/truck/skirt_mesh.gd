class_name SkirtMesh
extends RefCounted
## Malhas da saia grande (T-265) feitas no jogo, uma por material: painel com o recorte dos arcos, frisos e faixas
## (fitas com espessura) e copias dos enfeites modelados no Blender (MOTIF_* do .glb da peca). Espaco local da peca:
## x = 0 no lado de FORA do encaixe (a peca cresce para dentro, -x), y = 0 no topo (embaixo do bau), z do modelo.

var groups: Dictionary = {}           # nome do material -> {v, n, uv, i}
var order: Array[String] = []
var tris: int = 0


func _g(mat: String) -> Dictionary:
	if not groups.has(mat):
		groups[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "i": PackedInt32Array()}
		order.append(mat)
	return groups[mat]


## Quadrilatero a-b-c-d (anti-horario visto do lado da normal `n`).
func quad(mat: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	if (b - a).cross(d - a).length() < 1e-8 and (c - b).cross(d - b).length() < 1e-8:
		return                                       # (coluna dupla do degrau do arco: quadrado sem area)
	var g: Dictionary = _g(mat)
	var v: PackedVector3Array = g["v"]
	var nn: PackedVector3Array = g["n"]
	var uv: PackedVector2Array = g["uv"]
	var ii: PackedInt32Array = g["i"]
	var base: int = v.size()
	for p in [a, b, c, d]:
		v.append(p)
		nn.append(n)
		# (UV em metros: a textura de detalhe do painel; lado de fora usa z, y; as faces de borda usam o maior eixo)
		uv.append(Vector2(p.z if absf(n.x) > 0.5 else p.x + p.z, p.y) * 2.0)
	# (Godot: frente = sentido horario visto de fora; os vertices vem anti-horario)
	ii.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	g["v"] = v
	g["n"] = nn
	g["uv"] = uv
	g["i"] = ii
	tris += 2


## Fita em pe na face (x0 = encostada, x1 = de fora) seguindo a polilinha `pts` (z, y) com largura `w` (centrada) ou,
## com `side` = 1/-1, so de um lado da linha (friso que acompanha uma borda). Frente, as duas bordas e as tampas.
## `clip_z`: a fita nao passa do z da 1a e da ultima ponta (friso do recorte num trecho que comeca DENTRO do arco: la a
## borda e quase vertical e a largura empurraria a fita para fora do trecho, no vao do poste da lona/tanque).
func ribbon(mat: String, pts: PackedVector2Array, w: float, x0: float, x1: float, side: int = 0, caps: bool = true,
		front_only: bool = false, clip_z: bool = false) -> void:
	if pts.size() < 2:
		return
	var nrm: PackedVector2Array = _normals(pts)
	var a := PackedVector2Array()
	var b := PackedVector2Array()
	var z_lo: float = minf(pts[0].x, pts[pts.size() - 1].x)
	var z_hi: float = maxf(pts[0].x, pts[pts.size() - 1].x)
	for k in pts.size():
		var o: Vector2 = nrm[k]
		var pa: Vector2 = pts[k] + o * (0.0 if side > 0 else (w if side < 0 else w * 0.5))
		var pb: Vector2 = pts[k] - o * (0.0 if side < 0 else (w if side > 0 else w * 0.5))
		if clip_z:
			pa.x = clampf(pa.x, z_lo, z_hi)
			pb.x = clampf(pb.x, z_lo, z_hi)
		a.append(pa)
		b.append(pb)
	for k in pts.size() - 1:
		# frente (x1)
		quad(mat, _p(x1, a[k]), _p(x1, a[k + 1]), _p(x1, b[k + 1]), _p(x1, b[k]), Vector3.RIGHT)
		if front_only:
			continue
		var ea: Vector2 = Vector2(nrm[k].x + nrm[k + 1].x, nrm[k].y + nrm[k + 1].y).normalized()
		quad(mat, _p(x0, a[k]), _p(x0, a[k + 1]), _p(x1, a[k + 1]), _p(x1, a[k]), Vector3(0, ea.y, ea.x))
		quad(mat, _p(x1, b[k]), _p(x1, b[k + 1]), _p(x0, b[k + 1]), _p(x0, b[k]), Vector3(0, -ea.y, -ea.x))
	if caps and not front_only:
		var t0: Vector2 = (pts[0] - pts[1]).normalized()
		var t1: Vector2 = (pts[pts.size() - 1] - pts[pts.size() - 2]).normalized()
		quad(mat, _p(x0, b[0]), _p(x0, a[0]), _p(x1, a[0]), _p(x1, b[0]), Vector3(0, t0.y, t0.x))
		var e: int = pts.size() - 1
		quad(mat, _p(x0, a[e]), _p(x0, b[e]), _p(x1, b[e]), _p(x1, a[e]), Vector3(0, t1.y, t1.x))


## Normal (no plano z, y) de cada ponto da polilinha: a esquerda do sentido de percurso (+y numa linha que vai para +z).
static func _normals(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in pts.size():
		var t: Vector2 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)])
		if t.length() < 1e-6:
			t = Vector2(1, 0)
		t = t.normalized()
		var n := Vector2(-t.y, t.x)
		if k > 0 and k < pts.size() - 1:
			# (canto: a fita mantem a largura nas duas pernas)
			var t0: Vector2 = (pts[k] - pts[k - 1]).normalized()
			var n0 := Vector2(-t0.y, t0.x)
			var c: float = n.dot(n0)
			if c > 0.3:
				n = n / c
		out.append(n)
	return out


static func _p(x: float, q: Vector2) -> Vector3:
	return Vector3(x, q.y, q.x)


## Barra reta (caixa) de za a zb, de y0 a y1, de x0 a x1 (frente, topo, baixo e pontas).
func bar(mat: String, za: float, zb: float, y0: float, y1: float, x0: float, x1: float) -> void:
	ribbon(mat, PackedVector2Array([Vector2(za, (y0 + y1) * 0.5), Vector2(zb, (y0 + y1) * 0.5)]), y1 - y0, x0, x1)


## Copia de uma malha do .glb (um material) com a transformacao `t`.
func copy(mat: String, mesh: Mesh, t: Transform3D) -> void:
	var g: Dictionary = _g(mat)
	var nb: Basis = t.basis.inverse().transposed()
	for s in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for k in verts.size():
				idx.append(k)
		var v: PackedVector3Array = g["v"]
		var nn: PackedVector3Array = g["n"]
		var uv: PackedVector2Array = g["uv"]
		var ii: PackedInt32Array = g["i"]
		var base: int = v.size()
		for k in verts.size():
			v.append(t * verts[k])
			nn.append((nb * norms[k]).normalized() if k < norms.size() else Vector3.RIGHT)
			uv.append(uvs[k] if k < uvs.size() else Vector2.ZERO)
		for k in idx:
			ii.append(base + k)
		g["v"] = v
		g["n"] = nn
		g["uv"] = uv
		g["i"] = ii
		tris += idx.size() / 3


## Cria os MeshInstance3D (um por material) no `node`. `mats` = nome -> Material; `prefix` no nome do no.
func commit(node: Node3D, mats: Dictionary, prefix: String) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for key in order:
		var g: Dictionary = groups[key]
		if (g["v"] as PackedVector3Array).is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g["v"]
		arrays[Mesh.ARRAY_NORMAL] = g["n"]
		arrays[Mesh.ARRAY_TEX_UV] = g["uv"]
		arrays[Mesh.ARRAY_INDEX] = g["i"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(0, mats.get(key))
		var mi := MeshInstance3D.new()
		mi.name = "%s_%s" % [prefix, key]
		mi.mesh = am
		node.add_child(mi)
		out.append(mi)
	return out
