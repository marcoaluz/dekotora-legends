class_name Lot5Grille
extends RefCounted
## Grade da oficina (T-234/T-256) assentada na frente REAL de cada cabine:
##  - inclina junto com a frente (`lean` do encaixe = dz/dy medido por raios; JAC e curta tem a frente inclinada);
##  - colar (T-256, "encaixe mais natural"): onde a lataria fica atras das costas da grade (frente curva), uma moldura
##    fina na cor do painel fecha a folga em cada borda, ate a lataria (nada de grade "boiando" vista de lado);
##  - arte na lata (T-256, opcao do jogador `art` = celula do atlas da T-211: 12 ondas, 13 sakura, 14 raios, 15 nuvens):
##    a grade desce para a parte de baixo da caixa e a arte e pintada NA LATARIA logo acima dela (malha que segue a
##    grade de raios `grid` do encaixe, 4 mm na frente da chapa), repetindo a celula para nao esticar.
## Os nos extras (colar, arte) sao filhos da peca com a transformacao desfeita (a peca e escalada e cisalhada).

const MARGIN: float = 0.03            # m de folga para dentro da caixa (cada lado)
const RING: float = 0.03              # m: contorno de LED por fora da moldura (Blender: grille_horn_t234.RING)
const COLLAR_W: float = 0.025         # m: espessura do colar
const COLLAR_MAX: float = 0.35        # m: o colar nunca passa disto (vao fundo = fresta de fabrica, nao precisa fechar)
const ART_GRILLE_K: float = 0.58      # com arte na lata, a grade ocupa esta fracao de baixo da caixa
const ART_LIFT: float = 0.004         # m: arte na frente da chapa
const ART_CELLS: Array[int] = [12, 13, 14, 15]

static var _art_mats: Dictionary = {}


## Assenta a grade (chamado pelo Lot5Fit). `art` = celula da arte na lata (-1 = sem arte).
static func apply(node: Node3D, s: Dictionary, entry: Dictionary, anchor: Vector3, art: int = -1, trim: Material = null) -> void:
	for n in node.get_children():
		if n.has_meta("lot5_extra"):
			node.remove_child(n)
			n.free()
	var box: AABB = TruckSockets.aabb_of(s["box"])
	var nom: Array = entry.get("nominal", [1.0, 1.0, 1.0])
	var lean: float = float(s.get("lean", 0.0))
	var yc_box: float = box.get_center().y
	var y0: float = box.position.y + MARGIN
	var y1: float = box.end.y - MARGIN
	var y_art: float = y1
	if art in ART_CELLS:
		y1 = y0 + (y1 - y0) * ART_GRILLE_K
	var sx: float = maxf(box.size.x - 2.0 * MARGIN, 0.2) / (float(nom[0]) + 2.0 * RING)   # com o contorno de LED
	var sy: float = maxf(y1 - y0, 0.2) / (float(nom[1]) + 2.0 * RING)
	var yc: float = (y0 + y1) * 0.5
	var face: float = float(s.get("face_z", anchor.z)) + lean * (yc - yc_box)
	var pos := Vector3(box.get_center().x - anchor.x, yc - anchor.y, face - anchor.z)
	node.transform = Transform3D(Basis(Vector3(sx, 0.0, 0.0), Vector3(0.0, sy, lean * sy), Vector3(0.0, 0.0, 1.0)), pos)
	var k: float = minf(sx, sy)
	for mi in node.find_children("*_CEN_*", "MeshInstance3D", true, false):
		(mi as Node3D).scale = Vector3(k / sx, k / sy, 1.0)
	Lot5Fit._honey_override(node, sx, sy)
	var half := Vector2((float(nom[0]) * 0.5 + RING) * sx, (y1 - y0) * 0.5)   # com o contorno de LED
	_collar(node, s, anchor, Vector3(box.get_center().x, yc, face), half, lean, trim)
	if art in ART_CELLS:
		_art(node, s, anchor, Vector2(box.position.x + MARGIN, box.end.x - MARGIN), Vector2(y1 + 0.01, y_art), art)


## z da lataria em (x, y) pela grade do encaixe (bilinear; vao = null vira `fallback`).
static func surface_z(s: Dictionary, x: float, y: float, fallback: float) -> float:
	var g: Array = s.get("grid", [])
	if g.is_empty():
		return fallback
	var gx: Array = s["grid_x"]
	var gy: Array = s["grid_y"]
	var ny: int = g.size()
	var nx: int = (g[0] as Array).size()
	var fx: float = clampf((x - float(gx[0])) / maxf(float(gx[1]) - float(gx[0]), 1e-4) * (nx - 1), 0.0, nx - 1.0)
	var fy: float = clampf((y - float(gy[0])) / maxf(float(gy[1]) - float(gy[0]), 1e-4) * (ny - 1), 0.0, ny - 1.0)
	var i: int = mini(int(fx), nx - 2)
	var j: int = mini(int(fy), ny - 2)
	var tx: float = fx - i
	var ty: float = fy - j
	var v: Array[float] = []
	for q in [[j, i], [j, i + 1], [j + 1, i], [j + 1, i + 1]]:
		var z: Variant = (g[q[0]] as Array)[q[1]]
		v.append(float(z) if z != null else fallback)
	return lerpf(lerpf(v[0], v[1], tx), lerpf(v[2], v[3], tx), ty)


## Moldura que fecha a folga entre as costas da grade e a lataria em cada borda (so onde a folga passa de 1 cm).
static func _collar(node: Node3D, s: Dictionary, anchor: Vector3, c: Vector3, half: Vector2, lean: float,
		trim: Material = null) -> void:
	var mat: Material = trim
	if mat == null:
		var sm := StandardMaterial3D.new()
		sm.resource_name = "deco_trim"              # o DecoStyle pinta na cor do painel da peca (montagem normal)
		sm.albedo_color = Color(0.045, 0.05, 0.07)
		mat = sm
	var edges: Array = [[Vector3(c.x - half.x, c.y + half.y, 0), Vector3(c.x + half.x, c.y + half.y, 0), true],
		[Vector3(c.x - half.x, c.y - half.y, 0), Vector3(c.x + half.x, c.y - half.y, 0), true],
		[Vector3(c.x - half.x, c.y - half.y, 0), Vector3(c.x - half.x, c.y + half.y, 0), false],
		[Vector3(c.x + half.x, c.y - half.y, 0), Vector3(c.x + half.x, c.y + half.y, 0), false]]
	var inv: Transform3D = node.transform.affine_inverse()
	for e in edges:
		var a: Vector3 = e[0]
		var b: Vector3 = e[1]
		var gap: float = 0.0
		for t in 9:
			var p: Vector3 = a.lerp(b, t / 8.0)
			var back: float = c.z + lean * (p.y - c.y)
			gap = maxf(gap, surface_z(s, p.x, p.y, back) - back)
		gap = minf(gap, COLLAR_MAX)
		if gap < 0.01:
			continue
		var mid: Vector3 = (a + b) * 0.5
		var bm := BoxMesh.new()
		var horizontal: bool = e[2]
		var length: float = (b - a).length() + (COLLAR_W if horizontal else 0.0)
		bm.size = Vector3(length if horizontal else COLLAR_W, COLLAR_W if horizontal else length, gap)
		bm.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = "collar"
		mi.mesh = bm
		mi.set_meta("lot5_extra", true)
		var back_mid: float = c.z + lean * (mid.y - c.y)
		var xf := Transform3D(Basis.IDENTITY, Vector3(mid.x, mid.y, back_mid + gap * 0.5) - anchor)
		mi.transform = inv * xf
		node.add_child(mi)


## Arte pintada na lataria acima da grade, seguindo a chapa; a celula se repete na horizontal (sem esticar).
static func _art(node: Node3D, s: Dictionary, anchor: Vector3, xr: Vector2, yr: Vector2, cell: int) -> void:
	if yr.y - yr.x < 0.05:
		return
	var nseg: int = maxi(1, roundi((xr.y - xr.x) / (yr.y - yr.x) / 2.0))
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var c0: Vector2 = DecoStyle.cell_uv(cell)
	var cw: Vector2 = Vector2(1.0 / DecoStyle.ATLAS_COLS, 1.0 / DecoStyle.ATLAS_ROWS)
	var nu: int = 4
	var nv: int = 3
	var back: float = float(s.get("face_z", anchor.z))
	for g in nseg:
		var base: int = verts.size()
		for j in nv + 1:
			var ty: float = float(j) / nv
			var y: float = lerpf(yr.x, yr.y, ty)
			for i in nu + 1:
				var tx: float = float(i) / nu
				# visto de frente a direita da imagem e o -x do caminhao: o segmento 0 comeca no +x
				var x: float = lerpf(xr.y, xr.x, (g + tx) / nseg)
				verts.append(Vector3(x, y, surface_z(s, x, y, back) - ART_LIFT) - anchor)
				uvs.append(Vector2(c0.x + cw.x * (0.02 + 0.96 * tx), c0.y + cw.y * (0.04 + 0.92 * (1.0 - ty))))
		for j in nv:
			for i in nu:
				var d: int = base + j * (nu + 1) + i
				var a: int = d + nu + 1
				idx.append_array([a, a + 1, d + 1, a, d + 1, d])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	var nrm := PackedVector3Array()
	nrm.resize(verts.size())
	nrm.fill(Vector3(0, 0, -1))
	arr[Mesh.ARRAY_NORMAL] = nrm
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "cab_art"
	mi.mesh = mesh
	mi.material_override = art_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("lot5_extra", true)
	mi.transform = node.transform.affine_inverse()
	node.add_child(mi)
	node.set_meta("cab_art", mi.material_override)


## Tinta da arte na lata (atlas da T-211, compartilhado): fosca, com um pouco de luz a noite (MuralGlow).
static func art_material() -> StandardMaterial3D:
	if _art_mats.has("art"):
		return _art_mats["art"]
	var m := StandardMaterial3D.new()
	m.resource_name = "cab_art"
	var tex: Texture2D = load(DecoStyle.ATLAS_PATH) as Texture2D if ResourceLoader.exists(DecoStyle.ATLAS_PATH) else null
	m.albedo_texture = tex
	m.roughness = 0.45
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if tex != null:
		MuralGlow.setup(m, tex)
	_art_mats["art"] = m
	return m
