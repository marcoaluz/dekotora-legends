class_name DecalCatalog
extends RefCounted
## Adesivos em PNG: lista os arquivos de res://assets/decals/ (6 provisorios + os que o Marco colocar)
## e de user://decals/ (sem reimportar). O nome do arquivo e o id do adesivo.

const DIRS: Array[String] = ["res://assets/decals/", "user://decals/"]
## Lugares do caminhao: lateral esquerda, lateral direita, traseira e cabine (as duas portas).
const SLOTS: Array[String] = ["side_l", "side_r", "rear", "cab"]
## Cores de adesivo oferecidas na garagem.
const COLORS: Array[String] = ["#ffffff", "#111111", "#f5cc5a", "#ff2e88", "#21e6ff", "#c8202f", "#3fb26f", "#ff8a1f"]

static var _tex: Dictionary = {}


static func ids() -> Array[String]:
	var out: Array[String] = []
	DirAccess.make_dir_recursive_absolute(DIRS[1])        # a pasta do jogador sempre existe (o Marco so precisa colocar os PNGs)
	for dir in DIRS:
		for f in DirAccess.get_files_at(dir):
			var name: String = f.trim_suffix(".import").trim_suffix(".remap")
			if name.to_lower().ends_with(".png"):
				var id: String = name.get_basename()
				if not out.has(id):
					out.append(id)
	out.sort()
	return out


## Textura do adesivo `id` (res:// tem prioridade); null se nao existe.
static func texture(id: String) -> Texture2D:
	if _tex.has(id):
		return _tex[id]
	var tex: Texture2D = null
	var res_path: String = "%s%s.png" % [DIRS[0], id]
	if ResourceLoader.exists(res_path):
		tex = load(res_path) as Texture2D
	else:
		var user_path: String = "%s%s.png" % [DIRS[1], id]
		if FileAccess.file_exists(user_path):
			var img := Image.load_from_file(ProjectSettings.globalize_path(user_path))
			if img != null and not img.is_empty():
				img.generate_mipmaps()
				tex = ImageTexture.create_from_image(img)
	_tex[id] = tex
	return tex


static func forget_cache() -> void:
	_tex.clear()


## Adesivo padrao ao escolher um adesivo novo num lugar.
static func make(id: String, slot: String) -> Dictionary:
	var x: float = 0.0
	var y: float = 0.0
	match slot:
		"side_l", "side_r":
			x = 0.0
			y = 0.0
		"cab":
			y = 0.1
	return {"id": id, "slot": slot, "x": x, "y": y, "size": 0.55, "color": COLORS[0]}


static func find(decals: Array, slot: String) -> int:
	for i in decals.size():
		if String((decals[i] as Dictionary).get("slot", "")) == slot:
			return i
	return -1
