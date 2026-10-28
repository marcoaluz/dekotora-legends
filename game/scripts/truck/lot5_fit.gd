class_name Lot5Fit
extends RefCounted
## Oficina lote 5 (T-234): encaixe das grades, escapamentos, buzinas e calotas novas (as "lacunas" da secao 19 de
## docs/REFERENCIA_PECAS.md). Os interiores usam o PaintFit (arte no retangulo medido no para-brisa).
##  - fit "grille": a peca encosta no ponto mais a frente da cabine entre os farois (`face_z` do encaixe, medido por
##    raios) e estica na largura e na altura da caixa de cada cabine; os nos com "_CEN_" no nome (o sol do meio) ficam
##    com a menor das duas escalas (nao deformam); a colmeia (`deco_honey`) repete a textura pelo tamanho real;
##  - fit "stack": escapamento no meio do vao entre a cabine e a carga; a secao encolhe onde o vao e estreito;
##  - fit "horn": buzina no topo da carga (encaixe "horn"; carga sem topo plano, como a cacamba, nao tem);
##  - fit "wheel": calota em cada roda de fora (TruckWheels.attach_part), escalada pelo raio de cada roda.

const FITS: Array[String] = ["grille", "stack", "horn"]
const GRILLE_MARGIN: float = 0.03            # m de folga da grade para dentro da caixa (cada lado)
const HONEY_PATH := "res://assets/vehicles/dekotora/textures/deco_honey.png"
const HONEY_TINT := Color(0.95, 0.74, 0.30)

static var _honey: Dictionary = {}           # "sx:sy" -> StandardMaterial3D


static func handles(entry: Dictionary) -> bool:
	return String(entry.get("fit", "")) in FITS


static func is_wheel(entry: Dictionary) -> bool:
	return String(entry.get("fit", "")) == "wheel"


static func socket_name(entry: Dictionary, side: String) -> String:
	if side == "L" and entry.has("socket_left"):
		return String(entry["socket_left"])
	return String(entry.get("socket", ""))


## Ajusta a peca recem-montada no no SOCKET_* (filha dele). `side` "L" = espelhada em X.
static func apply(node: Node3D, data: Dictionary, entry: Dictionary, side: String) -> void:
	var s: Dictionary = TruckSockets.socket(data, socket_name(entry, side))
	if not s.has("box"):
		return
	var box: AABB = TruckSockets.aabb_of(s["box"])
	var a: Array = s.get("anchor", [0.0, 0.0, 0.0])
	var anchor := Vector3(float(a[0]), float(a[1]), float(a[2]))
	var nom: Array = entry.get("nominal", [1.0, 1.0, 1.0])
	var sgn: float = -1.0 if side == "L" and bool(entry.get("mirror_for_left", false)) else 1.0
	match String(entry.get("fit", "")):
		"grille":
			var sx: float = maxf(box.size.x - 2.0 * GRILLE_MARGIN, 0.2) / float(nom[0])
			var sy: float = maxf(box.size.y - 2.0 * GRILLE_MARGIN, 0.2) / float(nom[1])
			var c: Vector3 = box.get_center()
			node.position = Vector3(c.x - anchor.x, c.y - anchor.y, float(s.get("face_z", anchor.z)) - anchor.z)
			node.scale = Vector3(sx, sy, 1.0)
			var k: float = minf(sx, sy)
			for mi in node.find_children("*_CEN_*", "MeshInstance3D", true, false):
				(mi as Node3D).scale = Vector3(k / sx, k / sy, 1.0)
			_honey_override(node, sx, sy)
		"stack":
			var kxz: float = minf(1.0, minf(box.size.z / float(nom[2]), box.size.x / float(nom[0])))
			var ky: float = minf(1.0, (box.end.y - anchor.y) / float(nom[1]))
			node.position = Vector3(0.0, 0.0, box.get_center().z - anchor.z)
			node.scale = Vector3(sgn * kxz, ky, kxz)
		"horn":
			var lift: float = float(s.get("lift", 0.0))
			node.position = Vector3(0.0, lift, 0.0)
			if lift > 0.0:
				_pedestal(node, lift)


## Pedestal da buzina (2 colunas na cor da peca) quando ha andon de fabrica na frente da carga: as cornetas passam por
## cima dele. O material se chama deco_body: o DecoStyle pinta na cor escolhida, como o resto da peca.
static func _pedestal(node: Node3D, lift: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.resource_name = "deco_body"
	for x in [-0.15, 0.15]:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, lift, 0.10)
		bm.surface_set_material(0, mat)
		var mi := MeshInstance3D.new()
		mi.name = "pedestal"
		mi.mesh = bm
		mi.position = Vector3(x, -lift * 0.5, -0.12)
		node.add_child(mi)


## Colmeia da grade: a textura se repete pelo tamanho real (o favo nao estica com a grade).
static func _honey_override(node: Node3D, sx: float, sy: float) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src: Material = m.mesh.surface_get_material(i)
			if src != null and src.resource_name == "deco_honey":
				m.set_surface_override_material(i, honey_material(sx, sy))


static func honey_material(sx: float, sy: float) -> StandardMaterial3D:
	var key: String = "%.2f:%.2f" % [sx, sy]
	if _honey.has(key):
		return _honey[key]
	var mat := StandardMaterial3D.new()
	mat.resource_name = "deco_honey"
	mat.albedo_texture = load(HONEY_PATH) as Texture2D if ResourceLoader.exists(HONEY_PATH) else null
	mat.albedo_color = HONEY_TINT
	mat.metallic = 1.0
	mat.roughness = 0.28
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_scale = Vector3(sx, sy, 1.0)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_honey[key] = mat
	return mat


## Problemas de encaixe de uma peca montada (teste e relatorio): dentro da caixa do encaixe e fora das zonas protegidas.
static func problems(model: Node3D, data: Dictionary, entry: Dictionary, node: Node3D, side: String) -> Array[String]:
	var out: Array[String] = []
	var slot: String = socket_name(entry, side)
	var s: Dictionary = TruckSockets.socket(data, slot)
	if not s.has("box"):
		return ["encaixe %s nao existe neste caminhao" % slot]
	var box: AABB = PartFit.aabb_in(node, model)
	var sb: AABB = TruckSockets.aabb_of(s["box"])
	if not PartFit.inside(box, sb):
		out.append("%s: sai da caixa do encaixe (peca %s, caixa %s)" % [slot, PartFit._fmt(box), PartFit._fmt(sb)])
	for z in data.get("protected", {}):
		var zv: Dictionary = data["protected"][z]
		if not PartFit._exempt(slot, zv) and PartFit.overlap(box, TruckSockets.aabb_of(zv["box"]), 0.002):
			out.append("%s: cobre a zona protegida %s" % [slot, z])
	return out


## Calota (fit "wheel"): uma em cada roda de fora, dentro da roda (raio) e no maximo 0,25 m para fora do pneu (zona
## da roda, de que a calota e isenta). Monta e desmonta no proprio modelo.
static func wheel_problems(model: Node3D, data: Dictionary, catalog: AccessoryCatalog, id: String) -> Array[String]:
	var out: Array[String] = []
	var tw := TruckWheels.new()
	tw.setup(model, 0.52)
	var made: Array[Node3D] = tw.attach_part(catalog, id)
	if made.is_empty():
		return ["%s: nenhuma roda de fora" % id]
	var wheels: Dictionary = data.get("measure", {}).get("wheels", {})
	for n in made:
		var w: Node3D = n.get_parent() as Node3D
		var box: AABB = PartFit.aabb_in(n, model)
		if wheels.has(String(w.name)):
			var wa: AABB = TruckSockets.aabb_of(wheels[String(w.name)])
			var outward: float = 0.25
			var lim := AABB(Vector3(wa.position.x - (outward if wa.position.x < 0.0 else 0.0), wa.position.y, wa.position.z),
					Vector3(wa.size.x + outward, wa.size.y, wa.size.z))
			if not PartFit.inside(box, lim, 0.01):
				out.append("%s em %s: sai da roda (peca %s, roda %s)" % [id, w.name, PartFit._fmt(box), PartFit._fmt(wa)])
			var rim: float = minf(wa.size.y, wa.size.z) * 0.5
			if maxf(box.size.y, box.size.z) * 0.5 > rim * 0.85:
				out.append("%s em %s: maior que o aro (%.2f > %.2f)" % [id, w.name, maxf(box.size.y, box.size.z) * 0.5, rim * 0.85])
	for n in made:
		n.get_parent().remove_child(n)
		n.free()
	return out
