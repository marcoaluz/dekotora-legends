class_name SkirtFit
extends RefCounted
## Saia lateral GRANDE (T-265, capturas 085-094; pedido do Marco: "quase no chao, contornando as rodas e tambem atras da
## roda traseira"). Encaixe `side_skirts_r/l` com fit "skirt" (blender/scripts/lib/{truck_measure,socket_rules}.py):
## `runs` (trechos livres da frente do bau ate a traseira: tanque, bateria e degraus de fabrica ficam de fora), `arcs`
## (rodas daquele lado: [zc, yc, raio do arco]), `floor_y` (fundo da saia) e o topo no ponto do encaixe.
## A peca do catalogo traz o desenho (`skirt`: fileiras de neon/LED, enfeites, trilhos, neon do arco) e o .glb traz os
## enfeites modelados no Blender (MOTIF_<forma>_<material>) e uma amostra de cada material (MAT_<material>).
## Monta: painel com o recorte em arco das rodas (frente e costas), friso cromado no topo, nas pontas e em volta do
## recorte, as fileiras cortadas onde o arco chega, e uma malha simples para longe (LOD, LOD_M).

const XF: float = -0.014             # face de fora do painel (os enfeites saem ate ~1,2 cm dela, dentro do encaixe)
const BACK_GAP: float = 0.004         # costas do painel a isto do lado de dentro do encaixe
const TOP_CAP: float = 0.022          # friso cromado do topo
const LIP: float = 0.026              # friso cromado em volta do recorte e no fundo
const END_W: float = 0.03             # friso das pontas do trecho
const ROW_GAP: float = 0.035          # folga das fileiras ate o arco
const ROW_END: float = 0.05           # folga das fileiras ate as pontas do trecho
const LOD_M: float = 35.0             # m: troca para a malha simples (REFERENCIA_PECAS 16.1, igual ao BumperWrap)
const LOD_MARGIN: float = 2.0


static func handles(entry: Dictionary) -> bool:
	return String(entry.get("fit", "")) == "skirt"


## Monta a saia no no `node` (filho do SOCKET_side_skirts_*). `sx` = -1 no lado esquerdo (espelhado).
static func apply(node: Node3D, s: Dictionary, entry: Dictionary, sx: float) -> void:
	var pid: String = String(entry.get("id", "skirt"))
	var mats: Dictionary = {}
	var motifs: Dictionary = {}                     # chave -> [malha, material]
	for mi in StripFit._meshes(node):
		var nm: String = String(mi.name)
		for k in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(k)
			if m != null and not mats.has(m.resource_name):
				mats[m.resource_name] = m
		var at: int = nm.find("MOTIF_")
		if at >= 0 and mi.mesh.get_surface_count() > 0:
			var mm: Material = mi.mesh.surface_get_material(0)
			motifs[nm.substr(at + 6)] = [mi.mesh, mm.resource_name if mm != null else "chrome"]
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	for c in node.get_children():                    # (raiz vazia do .glb)
		node.remove_child(c)
		c.queue_free()
	node.scale = Vector3(sx, 1, 1)
	var spec: Dictionary = entry.get("skirt", {})
	var full := SkirtMesh.new()
	var lod := SkirtMesh.new()
	var a: Vector3 = _anchor(s)
	for r in s.get("runs", []):
		_run(full, lod, s, spec, float(r[0]), float(r[1]), a.y, motifs)
	for m in full.order + lod.order:
		if not mats.has(m):
			var nm2 := StandardMaterial3D.new()
			nm2.resource_name = m
			mats[m] = nm2
	for mi in full.commit(node, mats, pid):
		mi.visibility_range_end = LOD_M
		mi.visibility_range_end_margin = LOD_MARGIN
	for mi in lod.commit(node, mats, pid + "_lod1"):
		mi.visibility_range_begin = LOD_M
		mi.visibility_range_begin_margin = LOD_MARGIN
		mi.set_meta("part_lod", 1)
	node.set_meta("skirt_tris", full.tris)
	node.set_meta("skirt_tris_lod", lod.tris)


static func _anchor(s: Dictionary) -> Vector3:
	var a: Array = s.get("anchor", [0.0, 0.0, 0.0])
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Um trecho [z0, z1] (z do modelo). y local = y do modelo - topo (`top`).
static func _run(full: SkirtMesh, lod: SkirtMesh, s: Dictionary, spec: Dictionary, z0: float, z1: float, top: float,
		motifs: Dictionary) -> void:
	var arcs: Array = []
	for q in s.get("arcs", []):                      # arcos no espaco local (y - topo)
		arcs.append([float(q[0]), float(q[1]) - top, float(q[2])])
	var fl: float = float(s.get("floor_y", top - float(s.get("height", 0.8)))) - top
	var depth: float = float(s.get("depth", 0.06))
	var xb: float = -(depth - BACK_GAP)
	var trim: String = String(spec.get("trim", "chrome"))
	var panel: bool = bool(spec.get("panel", true))
	var cols: Array = SkirtShape.columns(z0, z1, fl, 0.0, arcs)
	var cols_l: Array = SkirtShape.columns(z0, z1, fl, 0.0, arcs, SkirtShape.ARC_SEG_LOD)
	var body: String = String(spec.get("body", "deco_body"))
	if panel:
		_panel(full, body, cols, xb, false)
		_panel(lod, body, cols_l, xb, true)
	# frisos: topo, pontas e em volta do recorte (no fundo)
	full.bar(trim, z0, z1, -TOP_CAP, 0.0, XF, XF + 0.008)
	lod.ribbon(trim, PackedVector2Array([Vector2(z0, -TOP_CAP * 0.5), Vector2(z1, -TOP_CAP * 0.5)]), TOP_CAP, XF, XF + 0.008, 0, false, true)
	for e in [[z0, 1.0], [z1, -1.0]]:
		var ze: float = float(e[0])
		var lo: float = maxf(SkirtShape.col_lo(ze + float(e[1]) * 0.002, fl, arcs),
				SkirtShape.col_lo(ze + float(e[1]) * END_W, fl, arcs))     # (ponta dentro do arco: friso acima dele)
		if lo < -TOP_CAP - 0.01:
			full.bar(trim, minf(ze, ze + float(e[1]) * END_W), maxf(ze, ze + float(e[1]) * END_W), lo, -TOP_CAP, XF, XF + 0.007)
	if panel:
		# (clip_z: trecho que comeca dentro do arco, ex. poste da lona sobre a roda, nao deixa o friso sair do trecho)
		full.ribbon(trim, SkirtShape.bottom(cols), LIP, XF, XF + 0.006, -1, true, false, true)
		lod.ribbon(trim, SkirtShape.bottom(cols_l), LIP, XF, XF + 0.006, -1, false, true, true)
	var h: float = -fl
	for row in spec.get("rows", []):
		_row(full, lod, row, z0, z1, fl, h, arcs, motifs)
	var arch: Dictionary = spec.get("arch", {})
	if not arch.is_empty():
		var w: float = float(arch.get("w", 0.03))
		var off: float = float(arch.get("off", 0.06))
		var y_max: float = -TOP_CAP - w
		for line in SkirtShape.arch_lines(z0, z1, fl + LIP + w * 0.5 + 0.01, y_max, arcs, off, ROW_END):
			full.ribbon(String(arch.get("m", "deco_neon")), line, w, XF, XF + float(arch.get("d", 0.010)))
		for line in SkirtShape.arch_lines(z0, z1, fl + LIP + w * 0.5 + 0.01, y_max, arcs, off, ROW_END, SkirtShape.ARC_SEG_LOD):
			lod.ribbon(String(arch.get("m", "deco_neon")), line, w, XF, XF + 0.006, 0, false, true)
	var posts: Dictionary = spec.get("posts", {})
	if not posts.is_empty():
		_posts(full, posts, z0, z1, fl, arcs, motifs)


## Painel: frente e costas por coluna, a borda de baixo (que acompanha o recorte) e, na malha de longe, so a frente.
static func _panel(mesh: SkirtMesh, mat: String, cols: Array, xb: float, front_only: bool) -> void:
	for k in cols.size() - 1:
		var za: float = float(cols[k][0])
		var zb: float = float(cols[k + 1][0])
		var ya: float = float(cols[k][1])
		var yb: float = float(cols[k + 1][1])
		mesh.quad(mat, Vector3(XF, 0.0, za), Vector3(XF, 0.0, zb), Vector3(XF, yb, zb), Vector3(XF, ya, za), Vector3.RIGHT)
		if front_only:
			continue
		mesh.quad(mat, Vector3(xb, 0.0, zb), Vector3(xb, 0.0, za), Vector3(xb, ya, za), Vector3(xb, yb, zb), Vector3.LEFT)
		var t := Vector2(zb - za, yb - ya)
		if t.length() > 1e-6:
			t = t.normalized()
			var n := Vector3(0.0, -t.x, t.y)            # (para baixo / para o lado da roda)
			mesh.quad(mat, Vector3(XF, ya, za), Vector3(XF, yb, zb), Vector3(xb, yb, zb), Vector3(xb, ya, za), n)
	# pontas do trecho
	for e in [0, cols.size() - 1]:
		var z: float = float(cols[e][0])
		var y: float = float(cols[e][1])
		var nz: float = -1.0 if e == 0 else 1.0
		if front_only:
			continue
		if nz < 0.0:
			mesh.quad(mat, Vector3(xb, 0.0, z), Vector3(XF, 0.0, z), Vector3(XF, y, z), Vector3(xb, y, z), Vector3(0, 0, -1))
		else:
			mesh.quad(mat, Vector3(XF, 0.0, z), Vector3(xb, 0.0, z), Vector3(xb, y, z), Vector3(XF, y, z), Vector3(0, 0, 1))


## Uma fileira do desenho: "bar" (faixa continua), "dash" (tracos), "motif" (enfeite repetido) ou "rail" (trilho
## cromado). `t` = altura em fracao da saia reta (0 = fundo, 1 = topo).
static func _row(full: SkirtMesh, lod: SkirtMesh, row: Dictionary, z0: float, z1: float, fl: float, h: float, arcs: Array,
		motifs: Dictionary) -> void:
	var k: String = String(row.get("k", "bar"))
	var mat: String = String(row.get("m", "deco_neon"))
	var d: float = float(row.get("d", 0.010))
	var tt: Array = row["t"] if row.get("t") is Array else [float(row.get("t", 0.5)), float(row.get("t", 0.5))]
	var y0: float = fl + h * float(tt[0])
	var y1: float = fl + h * float(tt[1])
	if k == "motif" or k == "rail":
		var hh: float = float(row.get("h", 0.1)) * 0.5
		y0 = (y0 + y1) * 0.5 - hh
		y1 = y0 + hh * 2.0
	y1 = minf(y1, -TOP_CAP - 0.01)
	y0 = maxf(y0, fl + LIP + 0.01)
	if y1 - y0 < 0.01:
		return
	var gap: float = float(row.get("gap_arch", ROW_GAP))
	for sp in SkirtShape.spans(z0, z1, y0, y1, arcs, gap, float(row.get("end", ROW_END))):
		match k:
			"bar":
				full.bar(mat, sp.x, sp.y, y0, y1, XF, XF + d)
				lod.ribbon(mat, PackedVector2Array([Vector2(sp.x, (y0 + y1) * 0.5), Vector2(sp.y, (y0 + y1) * 0.5)]), y1 - y0, XF, XF + 0.004, 0, false, true)
			"dash":
				for q in SkirtShape.dashes(sp.x, sp.y, float(row.get("len", 0.3)), float(row.get("gap", 0.1)), float(row.get("shift", 0.0))):
					full.bar(mat, q.x, q.y, y0, y1, XF, XF + d)
				lod.ribbon(mat, PackedVector2Array([Vector2(sp.x, (y0 + y1) * 0.5), Vector2(sp.y, (y0 + y1) * 0.5)]), (y1 - y0) * 0.6, XF, XF + 0.004, 0, false, true)
			"motif":
				var o: Array = motifs.get(String(row.get("o", "")), [])
				var w: float = float(row.get("w", 0.2))
				var k_z: float = 1.0
				var zcs: Array[float] = SkirtShape.spread(sp.x, sp.y, w, float(row.get("pitch", 0.32)))
				if zcs.is_empty() and sp.y - sp.x - 0.01 >= w * float(row.get("shrink", 1.0)):
					k_z = (sp.y - sp.x - 0.01) / w        # (trecho curto: um enfeite encolhido no comprimento, ex. seta)
					zcs = [(sp.x + sp.y) * 0.5]
				for zc in zcs:
					if o.is_empty():
						full.bar(mat, zc - w * 0.5 * k_z, zc + w * 0.5 * k_z, y0, y1, XF, XF + d)
					else:
						full.copy(String(o[1]), o[0], Transform3D(Basis.from_scale(Vector3(1, 1, k_z)), Vector3(XF, (y0 + y1) * 0.5, zc)))
				lod.ribbon(mat, PackedVector2Array([Vector2(sp.x, (y0 + y1) * 0.5), Vector2(sp.y, (y0 + y1) * 0.5)]), (y1 - y0) * 0.35, XF, XF + 0.004, 0, false, true)
			"rail":
				var o2: Array = motifs.get(String(row.get("o", "")), [])
				var x: float = float(row.get("x", -0.03))
				if o2.is_empty():
					full.bar(mat, sp.x, sp.y, y0, y1, x - (y1 - y0) * 0.5, x + (y1 - y0) * 0.5)
				else:                                   # tubo de 1 m do Blender esticado no comprimento
					full.copy(String(o2[1]), o2[0], Transform3D(Basis.from_scale(Vector3(1, 1, sp.y - sp.x)), Vector3(x, (y0 + y1) * 0.5, (sp.x + sp.y) * 0.5)))
				lod.ribbon(mat, PackedVector2Array([Vector2(sp.x, (y0 + y1) * 0.5), Vector2(sp.y, (y0 + y1) * 0.5)]), y1 - y0, x, x + 0.004, 0, false, true)


## Postes verticais (trilhos cromados, capturas 086-087): nas pontas e a cada `pitch`, da altura do recorte ate o topo.
static func _posts(full: SkirtMesh, posts: Dictionary, z0: float, z1: float, fl: float, arcs: Array, motifs: Dictionary) -> void:
	var w: float = float(posts.get("w", 0.035))
	var o: Array = motifs.get(String(posts.get("o", "")), [])
	var mat: String = String(posts.get("m", "deco_trim"))
	var x: float = float(posts.get("x", -0.03))
	var y_min: float = fl + float(posts.get("bottom", 0.0))
	for sp in SkirtShape.spans(z0, z1, -TOP_CAP - 0.05, -TOP_CAP - 0.04, arcs, 0.01, 0.0):
		var zs: Array[float] = [sp.x + w * 0.5, sp.y - w * 0.5]
		zs.append_array(SkirtShape.spread(sp.x + w, sp.y - w, w, float(posts.get("pitch", 1.1))))
		for zc in zs:
			var lo: float = maxf(y_min, maxf(SkirtShape.col_lo(zc - w * 0.5, fl, arcs), SkirtShape.col_lo(zc + w * 0.5, fl, arcs)))
			if lo > -TOP_CAP - 0.06:
				continue
			if o.is_empty():
				full.bar(mat, zc - w * 0.5, zc + w * 0.5, lo, -TOP_CAP, x - w * 0.5, x + w * 0.5)
			else:                                       # poste de 1 m do Blender esticado na altura
				var hgt: float = -TOP_CAP - lo
				full.copy(String(o[1]), o[0], Transform3D(Basis.from_scale(Vector3(1, hgt, 1)), Vector3(x, lo + hgt * 0.5, zc)))
