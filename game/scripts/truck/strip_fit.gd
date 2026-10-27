class_name StripFit
extends RefCounted
## Pecas da oficina que seguem o tamanho do bau (T-231), montadas a partir de modulos do .glb:
##  - fit "stretch" (foguete): grupos HEAD_ (ponta de tras), MID_ (modulo do meio) e TAIL_ (ponta da frente); o modulo
##    do meio e repetido ate o comprimento medido do encaixe (`length`), sem deformar as pontas; a secao encolhe na
##    largura da faixa livre do teto (`band`, minimo `min_scale`) e cresce ate `max_scale` (T-240: 1,35; T-252: 1,65 e `wide_k` 1,1 mais largo)
##    onde a faixa e larga;
##  - fit "strips" (contorno de LED): o modulo MID_ e repetido ao longo de cada trecho medido (`strips` do encaixe:
##    a, b, normal n, eixo da largura w), em coordenadas do modelo.
## Tudo vira UMA malha por material (poucas chamadas de desenho), feita uma vez na montagem.
## Encaixes medidos pelo Blender: blender/scripts/lib/truck_measure.py (box_edges) e lib/socket_rules.py.

const FITS: Array[String] = ["stretch", "strips"]


static func handles(entry: Dictionary) -> bool:
	return String(entry.get("fit", "")) in FITS


## Nome do encaixe deste lado da peca ("R" usa `socket`, "L" usa `socket_left`).
static func socket_name(entry: Dictionary, side: String) -> String:
	if side == "L" and entry.has("socket_left"):
		return String(entry["socket_left"])
	return String(entry.get("socket", ""))


## Monta a peca (ja filha do ponto SOCKET_*) no tamanho do encaixe. Devolve false se o encaixe nao serve.
static func apply(node: Node3D, data: Dictionary, entry: Dictionary, side: String) -> bool:
	var s: Dictionary = TruckSockets.socket(data, socket_name(entry, side))
	if s.is_empty():
		return false
	var st: Dictionary = entry.get("stretch", {})
	var mid_len: float = float(st.get("mid", 1.0))
	var jobs: Array = []                      # [MeshInstance3D, Array[Transform3D]]
	if String(entry.get("fit", "")) == "stretch":
		var head: float = float(st.get("head", 0.0))
		var tail: float = float(st.get("tail", 0.0))
		var length: float = float(s.get("length", 0.0))
		var body: float = maxf(length - head - tail, mid_len * 0.5)
		var n: int = maxi(1, roundi(body / mid_len))
		var sz: float = body / (n * mid_len)
		var sc: float = clampf(float(s.get("band", entry.get("nominal_w", 1.0))) / float(entry.get("nominal_w", 1.0)),
				float(entry.get("min_scale", 0.7)), float(entry.get("max_scale", 1.0)))
		# T-252: um pouco mais largo que alto (`wide_k`), sem passar da faixa medida
		var band: float = float(s.get("band", entry.get("nominal_w", 1.0)))
		var sx: float = minf(sc * float(entry.get("wide_k", 1.0)), maxf(sc, band / float(entry.get("nominal_w", 1.0)) * 0.9))
		node.scale = Vector3(-sx if side == "L" else sx, sc, 1.0)
		var mids: Array[Transform3D] = []
		for k in n:
			# modulo de z em [-(head+mid), -head] -> [-(head+(k+1)*mid*sz), -(head+k*mid*sz)]
			mids.append(Transform3D(Basis.from_scale(Vector3(1, 1, sz)), Vector3(0, 0, head * sz - head - k * mid_len * sz)))
		var tail_x: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0, 0, -(n * mid_len * sz - mid_len)))
		for mi in _meshes(node):
			var nm: String = String(mi.name)
			if nm.contains("_MID_"):
				jobs.append([mi, mids])
			elif nm.contains("_TAIL_"):
				jobs.append([mi, [tail_x]])
			else:
				jobs.append([mi, [Transform3D.IDENTITY]])
	else:
		node.scale = Vector3.ONE
		var xs: Array[Transform3D] = []
		for g in s.get("strips", []):
			var a: Vector3 = _v(g["a"])
			var b: Vector3 = _v(g["b"])
			var nrm: Vector3 = _v(g["n"]).normalized()
			var len: float = a.distance_to(b)
			if len < 0.01:
				continue
			var d: Vector3 = (b - a) / len
			var cnt: int = maxi(1, roundi(len / mid_len))
			var sz2: float = len / (cnt * mid_len)
			var basis := Basis(d.cross(nrm).normalized(), nrm, -d * sz2)
			for k in cnt:
				xs.append(Transform3D(basis, a + d * (k * mid_len * sz2)))
		for mi in _meshes(node):
			jobs.append([mi, xs])
	_merge(node, jobs, String(entry.get("id", "part")))
	var fade: float = float(entry.get("fade_end", 0.0))
	if fade > 0.0:
		for mi in _meshes(node):
			mi.visibility_range_end = fade
			mi.visibility_range_end_margin = 10.0
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return true


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


static func _meshes(node: Node3D) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = c as MeshInstance3D
		if m.mesh != null:
			out.append(m)
	return out


## Junta as copias (cada malha x lista de transformacoes, no espaco do no da peca) numa malha por material.
static func _merge(node: Node3D, jobs: Array, pid: String) -> void:
	var groups: Dictionary = {}                 # nome do material -> {mat, v, n, t, uv, i}
	var order: Array[String] = []
	for job in jobs:
		var mi: MeshInstance3D = job[0]
		var local: Transform3D = PartFit.rel_xform(mi, node)
		for s in mi.mesh.get_surface_count():
			var mat: Material = mi.mesh.surface_get_material(s)
			var key: String = mat.resource_name if mat != null else "none"
			if not groups.has(key):
				groups[key] = {"mat": mat, "v": PackedVector3Array(), "n": PackedVector3Array(), "t": PackedFloat32Array(),
					"uv": PackedVector2Array(), "i": PackedInt32Array()}
				order.append(key)
			var g: Dictionary = groups[key]
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var tans: PackedFloat32Array = arr[Mesh.ARRAY_TANGENT] if arr[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
			var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty():
				for k in verts.size():
					idx.append(k)
			# (PackedArray e copiado ao sair do dicionario: trabalha em variaveis e grava de volta)
			var gv: PackedVector3Array = g["v"]
			var gn: PackedVector3Array = g["n"]
			var gt: PackedFloat32Array = g["t"]
			var guv: PackedVector2Array = g["uv"]
			var gi: PackedInt32Array = g["i"]
			for x in job[1]:
				var t: Transform3D = (x as Transform3D) * local
				var nb: Basis = t.basis.inverse().transposed()
				var base: int = gv.size()
				for k in verts.size():
					gv.append(t * verts[k])
					gn.append((nb * norms[k]).normalized() if k < norms.size() else Vector3.UP)
					guv.append(uvs[k] if k < uvs.size() else Vector2.ZERO)
					if tans.size() >= (k + 1) * 4:
						var tv: Vector3 = (t.basis * Vector3(tans[k * 4], tans[k * 4 + 1], tans[k * 4 + 2])).normalized()
						gt.append_array(PackedFloat32Array([tv.x, tv.y, tv.z, tans[k * 4 + 3]]))
				for k in idx:
					gi.append(base + k)
			g["v"] = gv
			g["n"] = gn
			g["t"] = gt
			g["uv"] = guv
			g["i"] = gi
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for key in order:
		var g: Dictionary = groups[key]
		if (g["v"] as PackedVector3Array).is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = g["v"]
		arrays[Mesh.ARRAY_NORMAL] = g["n"]
		arrays[Mesh.ARRAY_TEX_UV] = g["uv"]
		if (g["t"] as PackedFloat32Array).size() == (g["v"] as PackedVector3Array).size() * 4:
			arrays[Mesh.ARRAY_TANGENT] = g["t"]
		arrays[Mesh.ARRAY_INDEX] = g["i"]
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		am.surface_set_material(0, g["mat"])
		var out := MeshInstance3D.new()
		out.name = "%s_%s" % [pid, key]
		out.mesh = am
		node.add_child(out)


## Regras de encaixe (T-231) das pecas por modulo: cada vertice dentro de alguma caixa do encaixe (folga PartFit.TOL)
## e fora de toda zona protegida sem isencao. `node` montado no modelo `model`.
static func problems(model: Node3D, data: Dictionary, entry: Dictionary, node: Node3D, side: String) -> Array[String]:
	var probs: Array[String] = []
	var slot: String = socket_name(entry, side)
	var s: Dictionary = TruckSockets.socket(data, slot)
	var boxes: Array[AABB] = []
	for b in (s.get("boxes", [s["box"]] if s.has("box") else []) as Array):
		boxes.append(TruckSockets.aabb_of(b).grow(PartFit.TOL))
	var zones: Array = []
	for z in data.get("protected", {}):
		var zv: Dictionary = data["protected"][z]
		if not PartFit._exempt(slot, zv):
			zones.append([String(z), TruckSockets.aabb_of(zv["box"])])
	var outside: int = 0
	var hit: Dictionary = {}
	var total: int = 0
	for mi in _meshes(node):
		var t: Transform3D = PartFit.rel_xform(mi, model)
		for v in mi.mesh.get_faces():
			var w: Vector3 = t * v
			total += 1
			var ok: bool = false
			for b in boxes:
				if b.has_point(w):
					ok = true
					break
			if not ok:
				outside += 1
			for z in zones:
				if (z[1] as AABB).grow(-0.002).has_point(w):
					hit[z[0]] = true
	if total == 0:
		probs.append("peca sem malha")
	if outside > 0:
		probs.append("%d de %d vertices fora das caixas do encaixe %s" % [outside, total, slot])
	for z in hit:
		probs.append("cobre a zona protegida %s" % z)
	return probs
