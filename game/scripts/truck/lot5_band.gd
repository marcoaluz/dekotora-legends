class_name Lot5Band
extends RefCounted
## Adesivo na lataria da frente da cabine (T-259; referencia do Marco = a "pintura geral" do original, telas em
## docs/Referencias/grade_t234/): uma faixa de arte de lado a lado LOGO ABAIXO DO PARA-BRISA, colada na chapa (a grade
## de raios `band` do encaixe da grade da o z da lataria em cada vertice), recortada em volta de farol, lanterna, seta e
## placa, com uma fileira de LEDs em cima e embaixo (a cor de LED da grade) e brilho fraco a noite (MuralGlow).
## A arte (atlas da T-211: 12 ondas, 13 sakura, 14 raios, 15 nuvens) e recortada do atlas numa textura propria que se
## repete na horizontal (nao estica). E opcao de graca da grade (estilo `art`); a grade desce para baixo da faixa.

const LIFT: float = 0.004             # m: a arte fica na frente da chapa
const LED_LIFT: float = 0.010         # m: os LEDs um pouco mais para fora
const LED_SIZE: float = 0.024
const LED_STEP: float = 0.075
const LED_INSET: float = 0.022        # m: LEDs para dentro da borda de cima/baixo da faixa

static var _tex: Dictionary = {}      # celula -> ImageTexture
static var _mats: Dictionary = {}


## z da chapa no vertice (i, j) da faixa (null = sem chapa).
static func _vz(b: Dictionary, i: int, j: int) -> Variant:
	return (b["z"] as Array)[j * (int(b["nx"]) + 1) + i]


static func _vpos(b: Dictionary, i: int, j: int) -> Vector3:
	var x: float = lerpf(float(b["x"][0]), float(b["x"][1]), float(i) / int(b["nx"]))
	var y: float = lerpf(float(b["y"][0]), float(b["y"][1]), float(j) / int(b["ny"]))
	var z: Variant = _vz(b, i, j)
	return Vector3(x, y, float(z) if z != null else 0.0)


static func blocked(b: Dictionary, i: int, j: int) -> bool:
	return int((b["blocked"] as Array)[j * int(b["nx"]) + i]) != 0


## Monta a faixa e os LEDs como filhos de `node` (a grade), desfazendo a transformacao dela. `led` = material dos LEDs.
static func build(node: Node3D, b: Dictionary, anchor: Vector3, cell: int, led: Material) -> void:
	var nx: int = int(b["nx"])
	var ny: int = int(b["ny"])
	var h: float = float(b["y"][1]) - float(b["y"][0])
	var seg: float = 2.0 * h                         # a celula do atlas e 2:1: uma repeticao a cada 2 alturas
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var x1: float = float(b["x"][1])
	for j in ny:
		for i in nx:
			if blocked(b, i, j):
				continue
			var base: int = verts.size()
			for q in [[i, j], [i + 1, j], [i, j + 1], [i + 1, j + 1]]:
				var p: Vector3 = _vpos(b, q[0], q[1])
				verts.append(Vector3(p.x, p.y, p.z - LIFT) - anchor)
				# visto de frente a direita da imagem e o -x do caminhao
				uvs.append(Vector2((x1 - p.x) / seg, (float(b["y"][1]) - p.y) / h))
			# frente para -z (horario visto de frente, onde o +x fica a ESQUERDA): (i,j+1) (i+1,j) (i+1,j+1) / (i,j+1) (i,j) (i+1,j)
			idx.append_array([base + 2, base + 1, base + 3, base + 2, base, base + 1])
	if verts.is_empty():
		return
	var inv: Transform3D = node.transform.affine_inverse()
	node.add_child(_mesh("cab_art", verts, uvs, idx, material(cell), inv))
	node.set_meta("cab_art", material(cell))
	if led != null:
		_leds(node, b, anchor, led, inv)


static func _mesh(name: String, verts: PackedVector3Array, uvs: PackedVector2Array, idx: PackedInt32Array, mat: Material,
		inv: Transform3D) -> MeshInstance3D:
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
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("lot5_extra", true)
	mi.transform = inv
	return mi


## Fileira de LEDs em cima e embaixo da faixa (quadradinhos com UV 0..1: o shader das luzes desenha a lente).
static func _leds(node: Node3D, b: Dictionary, anchor: Vector3, led: Material, inv: Transform3D) -> void:
	var nx: int = int(b["nx"])
	var ny: int = int(b["ny"])
	var x0: float = float(b["x"][0])
	var x1: float = float(b["x"][1])
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var hs: float = LED_SIZE * 0.5
	for row in [[float(b["y"][1]) - LED_INSET, ny - 1], [float(b["y"][0]) + LED_INSET, 0]]:
		var y: float = row[0]
		var n: int = int((x1 - x0) / LED_STEP)
		for k in n + 1:
			var x: float = lerpf(x0 + 0.02, x1 - 0.02, float(k) / maxi(n, 1))
			var i: int = clampi(int((x - x0) / (x1 - x0) * nx), 0, nx - 1)
			if blocked(b, i, int(row[1])):
				continue
			var z: float = _vpos(b, i, int(row[1])).z
			z = minf(z, _vpos(b, mini(i + 1, nx), int(row[1])).z) - LED_LIFT
			var base: int = verts.size()
			for q in [Vector2(hs, -hs), Vector2(-hs, -hs), Vector2(hs, hs), Vector2(-hs, hs)]:
				verts.append(Vector3(x + q.x, y + q.y, z) - anchor)
			uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0)])
			idx.append_array([base + 2, base + 3, base + 1, base + 2, base + 1, base])
	if not verts.is_empty():
		node.add_child(_mesh("cab_art_leds", verts, uvs, idx, led, inv))


## Arte da celula do atlas numa textura propria (repete na horizontal), fosca, com um pouco de luz a noite.
static func material(cell: int) -> StandardMaterial3D:
	if _mats.has(cell):
		return _mats[cell]
	var m := StandardMaterial3D.new()
	m.resource_name = "cab_art"
	var tex: Texture2D = cell_texture(cell)
	m.albedo_texture = tex
	m.roughness = 0.4
	m.metallic = 0.15
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.texture_repeat = true
	if tex != null:
		MuralGlow.setup(m, tex)
	_mats[cell] = m
	return m


static func cell_texture(cell: int) -> Texture2D:
	if _tex.has(cell):
		return _tex[cell]
	var atlas: Texture2D = load(DecoStyle.ATLAS_PATH) as Texture2D if ResourceLoader.exists(DecoStyle.ATLAS_PATH) else null
	if atlas == null:
		return null
	var img: Image = atlas.get_image()
	if img == null or img.is_empty():
		return atlas
	img = img.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.clear_mipmaps()
	var cw: int = img.get_width() / DecoStyle.ATLAS_COLS
	var ch: int = img.get_height() / DecoStyle.ATLAS_ROWS
	var o: Vector2 = DecoStyle.cell_uv(cell)
	var pad: int = 2
	var sub: Image = img.get_region(Rect2i(int(o.x * img.get_width()) + pad, int(o.y * img.get_height()) + pad, cw - 2 * pad, ch - 2 * pad))
	sub.generate_mipmaps()
	var t := ImageTexture.create_from_image(sub)
	_tex[cell] = t
	return t
