class_name BumperWrap
extends RefCounted
## Para-choque grande da frente (T-264, capturas 054-062): alem das 3 faixas do FrameFit ("bumper"), a peca dobra a
## quina e corre pela lateral da cabine ate a roda da frente (as "abas"). O encaixe `front_bumper` traz, por lado, o x do
## lado de dentro da aba (lataria medida por raios + 4 mm), o comprimento livre ate a roda/porta e o perfil da quina
## arredondada da cabine (`wrap.r/l`, blender/scripts/lib/{truck_measure,socket_rules}.py). Depois de juntar as malhas:
##  - x: |x| ate XA fica igual (placa, grade); de XA ate o lado de dentro da aba (vfit.wrap.xb) estica de leve; dali
##    para fora so desloca (a aba nao muda de espessura) -> o lado de dentro da aba encosta na lataria;
##  - z (atras das costas, +z): a aba estica do comprimento nominal (vfit.wrap.wl) ate o medido; a ponta (vfit.wrap.end)
##    so desloca (faixa vertical da ponta nao deforma);
##  - tampa no topo (`corner_cap`) fecha o vao entre a quina arredondada da cabine e a aba (visto de cima);
##  - LOD: grupos `L*` (LTOP/LMID/LBOT/LCEN) = malha simples que aparece de LOD_M em diante; a completa some ali.
## Os pontos SIGNAL_L/R (seta da frente) acompanham o x.

const XA: float = 0.55                 # nominal: |x| ate aqui nao deforma
const CAP_T: float = 0.018             # m: espessura da tampa da quina (= socket_rules.CAP_T)
const LOD_M: float = 35.0              # m: distancia da troca para a malha simples (REFERENCIA_PECAS 16.1)
const LOD_MARGIN: float = 2.0
const NO_WRAP_LEN: float = 0.14        # m: sem aba medida naquele lado, a aba fica so com a ponta (nao acontece hoje)


static func handles(entry: Dictionary) -> bool:
	return (entry.get("vfit", {}) as Dictionary).has("wrap")


## Grupo de LOD de uma malha do .glb (antes de juntar): "L" no comeco do grupo (pid_LMID_material).
static func is_lod1(mesh_name: String) -> bool:
	for g in ["_LTOP_", "_LMID_", "_LBOT_", "_LCEN_"]:
		if mesh_name.contains(g):
			return true
	return false


## Depois do StripFit._merge: deforma as malhas juntadas (x e z), move os pontos SIGNAL e cria as tampas da quina.
static func apply(node: Node3D, s: Dictionary, entry: Dictionary, sc: float, pid: String) -> void:
	var w: Dictionary = (entry.get("vfit", {}) as Dictionary).get("wrap", {})
	var sw: Dictionary = s.get("wrap", {})
	var xb: float = float(w.get("xb", 1.18))
	var wl: float = float(w.get("wl", 0.6))
	var e: float = float(w.get("end", 0.1))
	var p: Dictionary = {}
	for side in ["r", "l"]:
		var d: Dictionary = sw.get(side, {})
		var xin: float = float(d.get("x", xb * sc)) / sc
		var ln: float = float(d.get("len", NO_WRAP_LEN)) / sc
		p[side] = {"xb2": xin, "fx": (xin - XA) / (xb - XA), "ln": maxf(ln, e + 0.02)}
	for mi in StripFit._meshes(node):
		if mi.has_meta("bumper_cap"):
			continue
		mi.mesh = _deform(mi.mesh, p, xb, wl, e)
	for sig in node.find_children("SIGNAL_*", "Node3D", true, false):
		var n3: Node3D = sig as Node3D
		var par: Transform3D = PartFit.rel_xform(n3.get_parent() as Node3D, node) if n3.get_parent() != node else Transform3D.IDENTITY
		var o: Vector3 = (par * n3.transform).origin
		var q: Dictionary = p["r" if o.x > 0.0 else "l"]
		var m: Vector2 = _map_x(absf(o.x), xb, q)
		o.x = signf(o.x) * m.x
		n3.transform.origin = par.affine_inverse() * o
	for side in ["r", "l"]:
		var d2: Dictionary = sw.get(side, {})
		if (d2.get("prof", []) as Array).size() >= 2:
			corner_cap(node, d2, 1.0 if side == "r" else -1.0, sc, pid)
	_lod(node, pid)


## |x| novo e fator da derivada (para a normal).
static func _map_x(ax: float, xb: float, q: Dictionary) -> Vector2:
	if ax <= XA:
		return Vector2(ax, 1.0)
	if ax >= xb:
		return Vector2(ax + float(q["xb2"]) - xb, 1.0)
	return Vector2(XA + (ax - XA) * float(q["fx"]), float(q["fx"]))


static func _map_z(z: float, wl: float, e: float, ln: float) -> Vector2:
	if z <= 0.0:
		return Vector2(z, 1.0)
	var zb: float = wl - e
	if z <= zb:
		var g: float = (ln - e) / zb
		return Vector2(z * g, g)
	return Vector2(z + ln - wl, 1.0)


static func _deform(src: Mesh, p: Dictionary, xb: float, wl: float, e: float) -> ArrayMesh:
	var am := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for k in v.size():
			var a: Vector3 = v[k]
			var q: Dictionary = p["r" if a.x > 0.0 else "l"]
			var mx: Vector2 = _map_x(absf(a.x), xb, q)
			var mz: Vector2 = _map_z(a.z, wl, e, float(q["ln"]))
			v[k] = Vector3(signf(a.x) * mx.x, a.y, mz.x)
			if k < n.size():
				n[k] = Vector3(n[k].x / mx.y, n[k].y, n[k].z / mz.y).normalized()
		arr[Mesh.ARRAY_VERTEX] = v
		if not n.is_empty():
			arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_TANGENT] = null                  # (a normal mudou um pouco; o Godot refaz o que precisar)
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(si, src.surface_get_material(si))
	return am


## Tampa no topo entre a quina arredondada da cabine (perfil medido) e o canto de dentro da aba (espaco da peca).
static func corner_cap(node: Node3D, d: Dictionary, sx: float, sc: float, pid: String) -> void:
	var mat: Material = _material(node, ["deco_checker", "deco_body", "chrome"])   # (o cromado envolvente nao tem deco_body)
	if mat == null:
		return
	var xin: float = float(d["x"]) / sc
	var pts: Array[Vector2] = [Vector2(xin, 0.0)]           # (x, z) no espaco da peca, z = atras das costas
	var prof: Array = d["prof"]
	pts.append(Vector2(minf(float(prof[0][1]) / sc, xin), 0.0))
	for q in prof:
		pts.append(Vector2(minf(float(q[1]) / sc, xin), float(q[0]) / sc))
	pts.append(Vector2(xin, float(prof[prof.size() - 1][0]) / sc))
	var t: float = CAP_T / sc
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, pts.size() - 1):
		var tri: Array[Vector2] = [pts[0], pts[i], pts[i + 1]]
		for y in [0.0, -t]:
			# (as duas ordens de vertice: a face aparece de cima no topo e de baixo embaixo, qualquer que seja o lado)
			for order in [[0, 1, 2], [0, 2, 1]]:
				for k in order:
					st.set_normal(Vector3.UP if y == 0.0 else Vector3.DOWN)
					st.set_uv(Vector2(tri[k].x * sx, tri[k].y) / 0.3)
					st.add_vertex(Vector3(tri[k].x * sx, y, tri[k].y))
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.name = "%s_cap_%s_%s" % [pid, "r" if sx > 0.0 else "l", mat.resource_name]
	mi.mesh = st.commit()
	mi.set_meta("bumper_cap", true)
	node.add_child(mi)


static func _material(node: Node3D, names: Array) -> Material:
	for want in names:
		for mi in StripFit._meshes(node):
			for k in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(k)
				if m != null and m.resource_name == want:
					return m
	return null


## LOD: malha juntada dos grupos L* ("<pid>_lod1_<material>") aparece de LOD_M em diante; as outras somem ali.
static func _lod(node: Node3D, pid: String) -> void:
	for mi in StripFit._meshes(node):
		if mi.has_meta("bumper_cap"):
			continue
		if String(mi.name).begins_with(pid + "_lod1_"):
			mi.visibility_range_begin = LOD_M
			mi.visibility_range_begin_margin = LOD_MARGIN
			mi.set_meta("part_lod", 1)
		else:
			mi.visibility_range_end = LOD_M
			mi.visibility_range_end_margin = LOD_MARGIN
