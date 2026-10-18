class_name TruckTextures
extends RefCounted
## Texturas compartilhadas do caminhao (T-118). Cada .glb do caminhao traz so miniaturas 4x4 (cor media) no lugar
## das texturas grandes; as texturas de verdade ficam UMA vez em assets/vehicles/dekotora/textures/ (geradas pelo
## build_truck_3d.py). Aqui trocamos as miniaturas pelas compartilhadas, com um material em cache por nome:
## todos os caminhoes da corrida usam a mesma copia na memoria.
##
## Como acha a textura: o Godot extrai as miniaturas do .glb como "<glb>_tex_<nome>.png"; o "tex_<nome>" do fim
## do caminho e o nome do arquivo compartilhado. Se o arquivo nao existir, a miniatura fica (o caminhao continua
## abrindo, so mais liso).

const DIR := "res://assets/vehicles/dekotora/textures/"
const SLOTS: Array[String] = ["albedo_texture", "metallic_texture", "roughness_texture", "normal_texture", "ao_texture", "emission_texture"]

static var _mats: Dictionary = {}       # nome do material -> StandardMaterial3D compartilhado (ou null = nao troca)


## Troca os materiais com miniaturas de todas as malhas abaixo de `root` pelos compartilhados.
## Chamar DEPOIS do ChromeMatcap e do mural (eles ja colocaram os materiais deles; aqui so mexe em StandardMaterial3D).
static func apply(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var cur: StandardMaterial3D = m.get_active_material(s) as StandardMaterial3D
			if cur == null:
				continue
			var shared: StandardMaterial3D = material_for(cur)
			if shared != null and shared != cur:
				m.set_surface_override_material(s, shared)


## Material compartilhado para `cur` (mesmo nome = mesmo material em todos os .glb do caminhao).
static func material_for(cur: StandardMaterial3D) -> StandardMaterial3D:
	var key: String = cur.resource_name
	if key == "":
		return null
	if _mats.has(key):
		return _mats[key]
	var dup: StandardMaterial3D = cur.duplicate() as StandardMaterial3D
	var swapped: bool = false
	for prop in SLOTS:
		var t: Texture2D = dup.get(prop) as Texture2D
		var full: Texture2D = texture_for(t)
		if full != null:
			dup.set(prop, full)
			swapped = true
	_mats[key] = dup if swapped else null
	return _mats[key]


## Textura compartilhada que corresponde a miniatura `t` (ou null).
static func texture_for(t: Texture2D) -> Texture2D:
	if t == null:
		return null
	var p: String = t.resource_path
	var i: int = p.rfind("_tex_")
	if i < 0:
		return null
	var path: String = DIR + p.substr(i + 1).get_file().get_basename() + ".png"
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
