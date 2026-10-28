class_name PaintFit
extends RefCounted
## Pinturas do bau (T-232): mural de cada lateral, pintura da traseira (portas) e do teto. Cada uma e UM quadrado com
## a arte, no retangulo medido por raios no plano real da face (`rect` do encaixe; blender/scripts/lib/paint_measure.py),
## 5 mm para fora: o que sai da lataria (trilhos, ferragens, luzinhas, contorno de LED, foguete) fica na frente.
## O retangulo traz os eixos da imagem: u = direita, v = cima, com u x v = normal (vista de fora a arte nunca sai
## espelhada; kanji legivel nos dois lados, na traseira e no teto, onde o "cima" aponta para a frente do caminhao).
## A arte tem proporcao fixa (`aspect` de cada variante, largura/altura): o quadrado mostra a janela central da arte
## com a proporcao do retangulo, e so estica ate STRETCH (fora disso corta as bordas, que a arte deixa livres).
## A noite a pintura acende como o mural de fabrica (MuralGlow, com a emissao pronta de cada arte).

const FIT := "paint"
## Esticar/encolher a arte no maximo isso antes de cortar as bordas.
const STRETCH: Vector2 = Vector2(0.8, 1.25)
## Quanto a malha fica para fora do plano ja vem no centro do retangulo (Blender, OFFSET = 5 mm).
const ROUGHNESS: float = 0.42

static var _mats: Dictionary = {}           # caminho da arte -> StandardMaterial3D (compartilhado entre caminhoes)


static func handles(entry: Dictionary) -> bool:
	return String(entry.get("fit", "")) == FIT


static func socket_name(entry: Dictionary, side: String) -> String:
	if side == "L" and entry.has("socket_left"):
		return String(entry["socket_left"])
	return String(entry.get("socket", ""))


## Retangulo do encaixe neste caminhao ({} se nao tem: carroceria aberta).
static func rect_of(data: Dictionary, entry: Dictionary, side: String) -> Dictionary:
	return TruckSockets.socket(data, socket_name(entry, side)).get("rect", {})


## Variante da arte deste lado com a proporcao mais perto da do retangulo (lista `paint[side]` do catalogo).
static func art_for(entry: Dictionary, side: String, rect_aspect: float) -> Dictionary:
	var p: Dictionary = entry.get("paint", {})
	var arts: Array = p.get(side, p.get("R", []))
	var best: Dictionary = {}
	var best_d: float = INF
	for a in arts:
		var d: float = absf(log(maxf(float(a.get("aspect", 1.0)), 0.01) / maxf(rect_aspect, 0.01)))
		if d < best_d:
			best_d = d
			best = a
	return best


## Janela da arte (UV) que cabe no retangulo: Rect2(uv0, tamanho).
static func uv_window(art_aspect: float, rect_aspect: float) -> Rect2:
	var c: float = clampf(rect_aspect, art_aspect * STRETCH.x, art_aspect * STRETCH.y)
	if c >= art_aspect:
		var hf: float = art_aspect / c
		return Rect2(0.0, (1.0 - hf) * 0.5, 1.0, hf)
	var wf: float = c / art_aspect
	return Rect2((1.0 - wf) * 0.5, 0.0, wf, 1.0)


## Monta o no da pintura (filho do ponto SOCKET_*, que fica na origem do modelo). Null se o caminhao nao tem a face.
static func build(data: Dictionary, entry: Dictionary, side: String) -> Node3D:
	var r: Dictionary = rect_of(data, entry, side)
	if r.is_empty():
		return null
	var w: float = float(r["w"])
	var h: float = float(r["h"])
	var art: Dictionary = art_for(entry, side, w / maxf(h, 0.001))
	if art.is_empty() or not ResourceLoader.exists(String(art.get("tex", ""))):
		return null
	var c: Vector3 = _v(r["c"])
	var u: Vector3 = _v(r["u"]) * (w * 0.5)
	var v: Vector3 = _v(r["v"]) * (h * 0.5)
	var n: Vector3 = _v(r["n"])
	var win: Rect2 = uv_window(float(art.get("aspect", 1.0)), w / maxf(h, 0.001))
	var arr: Array = _surface(c, u, v, n, win, r.get("grid", []))
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.name = "paint"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat: StandardMaterial3D = material(String(art["tex"]), String(art.get("emit", "")), bool(entry.get("alpha", false)))
	mi.material_override = mat
	var node := Node3D.new()
	node.add_child(mi)
	node.set_meta("paint", true)
	node.set_meta("paint_mat", mat)
	node.set_meta("paint_window", win)
	return node


## Malha da arte: um quadrado ou (T-234, interior no para-brisa) uma grade que segue a curvatura do vidro (`grid` =
## linhas de baixo para cima, colunas de s = -1 a +1, deslocamento ao longo da normal em m).
static func _surface(c: Vector3, u: Vector3, v: Vector3, n: Vector3, win: Rect2, grid: Array) -> Array:
	var nv: int = maxi(grid.size() - 1, 1)
	var nu: int = maxi((grid[0] as Array).size() - 1, 1) if not grid.is_empty() else 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	for j in nv + 1:
		var t: float = -1.0 + 2.0 * j / nv
		for i in nu + 1:
			var s: float = -1.0 + 2.0 * i / nu
			var k: float = float((grid[j] as Array)[i]) if not grid.is_empty() else 0.0
			verts.append(c + u * s + v * t + n * k)
			uvs.append(Vector2(win.position.x + win.size.x * (s + 1.0) * 0.5, win.position.y + win.size.y * (1.0 - (t + 1.0) * 0.5)))
			norms.append(n)
	var idx := PackedInt32Array()
	var front: bool = u.cross(v).dot(n) > 0.0
	for j in nv:
		for i in nu:
			var d: int = j * (nu + 1) + i            # (s0, t0)
			var cc: int = d + 1                      # (s1, t0)
			var a: int = d + nu + 1                  # (s0, t1)
			var b: int = a + 1                       # (s1, t1)
			# frente = lado da normal: (a,b,cc) (a,cc,d) gira no sentido horario visto de fora (Godot: frente = horario)
			idx.append_array([a, b, cc, a, cc, d] if front else [a, cc, b, a, d, cc])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = idx
	return arr


## Material de uma arte (um so por arte, compartilhado): cor + emissao pronta para a noite (MuralGlow).
static func material(tex_path: String, emit_path: String, alpha: bool = false) -> StandardMaterial3D:
	if _mats.has(tex_path):
		return _mats[tex_path]
	var tex: Texture2D = load(tex_path) as Texture2D
	var emit: Texture2D = load(emit_path) as Texture2D if emit_path != "" and ResourceLoader.exists(emit_path) else null
	var m := StandardMaterial3D.new()
	m.resource_name = "paint_art"
	m.albedo_texture = tex
	m.roughness = ROUGHNESS
	m.metallic = 0.0
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if alpha:                                       # T-234: interior pelo vidro (bordas somem aos poucos) e brilho de vidro
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.12
		m.metallic = 0.35
	MuralGlow.setup(m, tex, emit)
	_mats[tex_path] = m
	return m


## Problemas de encaixe de uma pintura montada (teste e relatorio): retangulo medido, dentro do bau, fora das zonas
## protegidas (a traseira e isenta das portas: e tinta na porta), area minima e arte nunca espelhada.
static func problems(model: Node3D, data: Dictionary, entry: Dictionary, node: Node3D, side: String) -> Array[String]:
	var out: Array[String] = []
	var slot: String = socket_name(entry, side)
	var r: Dictionary = rect_of(data, entry, side)
	if r.is_empty() or node == null:
		return ["pintura sem retangulo em %s" % slot]
	var u: Vector3 = _v(r["u"])
	var v: Vector3 = _v(r["v"])
	var n: Vector3 = _v(r["n"])
	if u.cross(v).dot(n) < 0.99:
		out.append("%s: arte espelhada (u x v != normal)" % slot)
	var box: AABB = PartFit.aabb_in(node, model)
	box = box.grow(0.001)
	var bx: Dictionary = data.get("measure", {}).get("box", {})
	if slot == "interior":                         # T-234: o interior fica no para-brisa (na frente do vidro, ate 3 cm)
		var ws: AABB = TruckSockets.aabb_of(data.get("measure", {}).get("cab", {}).get("windshield", [[0, 0, 0], [0, 0, 0]]))
		if not PartFit.inside(box, ws.grow(0.03), 0.0):
			out.append("%s: sai do para-brisa" % slot)
		bx = {}
	if not bx.is_empty():
		var lim := AABB(Vector3(-float(bx["half_w"]) - 0.05, float(bx["bottom_y"]) - 0.05, float(bx["front_z"]) - 0.05),
				Vector3(2.0 * float(bx["half_w"]) + 0.1, float(bx["top_y"]) - float(bx["bottom_y"]) + 0.1,
				float(bx["rear_z"]) - float(bx["front_z"]) + 0.1))
		if not PartFit.inside(box, lim, 0.0):
			out.append("%s: sai do bau" % slot)
	for z in data.get("protected", {}):
		var zv: Dictionary = data["protected"][z]
		if slot in (zv.get("exempt", []) as Array):
			continue
		if PartFit.overlap(box, TruckSockets.aabb_of(zv["box"]), 0.002):
			out.append("%s: cobre a zona protegida %s" % [slot, z])
	var area: float = float(r["w"]) * float(r["h"])
	var need: float = float(MIN_AREA.get(slot.trim_suffix("_r").trim_suffix("_l"), 1.0))
	if area < need:
		out.append("%s: area %.1f m2 < %.1f" % [slot, area, need])
	return out


## Area minima de cada face (m2): o menor bau (Canter) tem lateral 4,4 x 1,7 e traseira 2,1 x 1,8.
const MIN_AREA: Dictionary = {"mural": 6.0, "rear_paint": 3.0, "roof_paint": 8.0, "interior": 0.6}


static func _v(a: Array) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
