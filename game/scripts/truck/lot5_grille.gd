class_name Lot5Grille
extends RefCounted
## Grade da oficina (T-234/T-256) assentada na frente REAL de cada cabine:
##  - inclina junto com a frente (`lean` do encaixe = dz/dy medido por raios; JAC e curta tem a frente inclinada);
##  - colar (T-256, "encaixe mais natural"): onde a lataria fica atras das costas da grade (frente curva), uma moldura
##    fina na cor do painel fecha a folga em cada borda, ate a lataria (nada de grade "boiando" vista de lado);
##  - adesivo na lataria (T-259, refeito: opcao `art` = celula do atlas da T-211): faixa de lado a lado logo abaixo do
##    para-brisa, recortada em volta das luzes (Lot5Band); a grade desce para baixo dela. Nada de arte dentro da grade.
## Os nos extras (colar, arte) sao filhos da peca com a transformacao desfeita (a peca e escalada e cisalhada).

const MARGIN: float = 0.03            # m de folga para dentro da caixa (cada lado)
const RING: float = 0.03              # m: contorno de LED por fora da moldura (Blender: grille_horn_t234.RING)
const COLLAR_W: float = 0.025         # m: espessura do colar
const COLLAR_MAX: float = 0.35        # m: o colar nunca passa disto (vao fundo = fresta de fabrica, nao precisa fechar)
const ART_CELLS: Array[int] = [12, 13, 14, 15]



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
	var band: Dictionary = s.get("band", {})
	if art in ART_CELLS and not band.is_empty():           # T-259: a grade desce para baixo do adesivo da lataria
		y1 = minf(y1, float(band["y"][0]) - 0.02)
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
	if art in ART_CELLS and not band.is_empty():
		Lot5Band.build(node, band, anchor, art, led_material(node))


## Material de LED da propria grade (o mesmo da cor de luz escolhida e do padrao de pisca), para os LEDs da faixa.
static func led_material(node: Node3D) -> Material:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or m.has_meta("lot5_extra"):
			continue
		for i in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(i)
			if src != null and src.resource_name == "deco_led":
				return m.get_active_material(i)
	return null


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
