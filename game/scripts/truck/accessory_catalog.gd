class_name AccessoryCatalog
extends RefCounted
## Catalogo dos acessorios 3D (assets/vehicles/dekotora/catalog.json, gerado pelo Blender).
## Carrega os .glb, monta nos pontos MOUNT_* do caminhao e troca materiais por variantes.
## Nao tem logica de loja/economia: so a biblioteca de modelos (prompt do Marco, etapa 8).

const CATALOG_PATH := "res://assets/vehicles/dekotora/catalog.json"

var data: Dictionary = {}
var by_id: Dictionary = {}
static var _cache: AccessoryCatalog


static func get_instance() -> AccessoryCatalog:
	if _cache == null:
		_cache = AccessoryCatalog.new()
		_cache.reload()
	return _cache


func reload() -> void:
	data = {}
	by_id = {}
	if not FileAccess.file_exists(CATALOG_PATH):
		push_warning("AccessoryCatalog: catalogo nao encontrado: " + CATALOG_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if parsed is Dictionary:
		data = parsed
		for e in data.get("accessories", []):
			by_id[String(e["id"])] = e


func ids() -> Array:
	return by_id.keys()


func categories() -> Dictionary:
	return data.get("categories", {})


func in_category(category: String) -> Array:
	var out: Array = []
	for e in data.get("accessories", []):
		if String(e["category"]) == category:
			out.append(e)
	return out


func entry(id: String) -> Dictionary:
	return by_id.get(id, {})


func instantiate(id: String) -> Node3D:
	var e: Dictionary = entry(id)
	if e.is_empty() or String(e.get("model", "")) == "":     # T-232: pintura nao tem modelo (PaintFit)
		return null
	var ps: PackedScene = load(String(e["model"])) as PackedScene
	if ps == null:
		return null
	return ps.instantiate() as Node3D


## Monta o acessorio no ponto de encaixe do caminhao. `truck_model` = raiz do .glb do caminhao.
## `side` = "R" ou "L" (so para pecas espelhaveis; "L" usa MOUNT_*_L e escala X = -1).
func attach(truck_model: Node3D, id: String, side: String = "R") -> Node3D:
	var e: Dictionary = entry(id)
	if e.is_empty():
		return null
	var mirror: bool = bool(e.get("mirror_for_left", false))
	var mount_name: String = String(e["mount_point"])
	if mirror and side == "L":
		mount_name = String(e["mount_point_left"])
	var mount: Node = truck_model.find_child(mount_name, true, false)
	if mount == null and e.has("socket"):            # T-231: encaixe que este caminhao nao tem (ex.: foguete na graneleira)
		return null
	if mount == null:
		push_warning("AccessoryCatalog: ponto de montagem ausente: %s (peca %s)" % [mount_name, id])
		return null
	if PaintFit.handles(e):                           # T-232: pintura (mural/traseira/teto) = quadrado no retangulo medido
		var pn: Node3D = PaintFit.build(mount.get_meta("sockets", {}), e, side)
		if pn != null:
			pn.name = "acc_%s_%s" % [id, side]
			mount.add_child(pn)
		return pn
	var node: Node3D = instantiate(id)
	if node == null:
		return null
	node.name = "acc_%s_%s" % [id, side]
	mount.add_child(node)
	if mirror and side == "L":
		node.scale = Vector3(-1, 1, 1)
	if mount.has_meta("sockets") and StripFit.handles(e):   # T-231: foguete/contorno no tamanho do bau (modulos)
		StripFit.apply(node, mount.get_meta("sockets"), e, side)
	elif mount.has_meta("sockets"):                   # T-211: encaixe por caminhao, escala pela largura (TruckSockets)
		node.scale = Vector3.ONE * TruckSockets.fit_scale(mount.get_meta("sockets"), e)
		SocketSeat.seat(node, mount as Node3D, mount.get_meta("sockets"), e)   # T-214: assenta no teto/testa real
	return node


## Troca o material de todos os MeshInstance3D cujo material tem `from_name` por `to_name`
## (variantes de cor/acabamento sem duplicar geometria).
func swap_material(acc: Node3D, from_name: String, to_name: String) -> void:
	var mat: Material = AccessoryMaterials.make(to_name)
	for mi in acc.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var cur: Material = m.get_active_material(s)
			if cur != null and cur.resource_name == from_name:
				m.set_surface_override_material(s, mat)


## Aplica as variantes de material de um PartDef ({"main": "...", "accent": "..."}) a um acessorio montado.
func apply_variant(acc: Node3D, id: String, variant: Dictionary) -> void:
	var e: Dictionary = entry(id)
	if e.is_empty() or variant.is_empty():
		return
	var avail: Dictionary = e.get("materials_available", {})
	var used: Array = e.get("materials_used", [])
	for slot in variant:
		var opts: Array = avail.get(slot, [])
		for u in used:
			if String(u) in opts and String(u) != String(variant[slot]):
				swap_material(acc, String(u), String(variant[slot]))
				break
