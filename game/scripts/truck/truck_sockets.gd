class_name TruckSockets
extends RefCounted
## Encaixes por caminhao (T-211): caixa-limite de cada encaixe, ponto de montagem e zonas protegidas (para-brisa, farois,
## lanternas, setas, placas, portas, rodas). Gerado pelo Blender a partir dos .glb (`blender/scripts/build_sockets.py`)
## em assets/vehicles/dekotora/truck/sockets/<modelo>.json, em coordenadas do proprio .glb (Godot: frente = -z).
## Pecas da oficina com "socket" no catalogo montam no no SOCKET_<encaixe>, com escala uniforme pela largura.

const DIR := "res://assets/vehicles/dekotora/truck/sockets/"

static var _cache: Dictionary = {}


## Dados do modelo pelo caminho do .glb (vazio se o JSON nao existe).
static func for_model(glb_path: String) -> Dictionary:
	var stem: String = glb_path.get_file().get_basename()
	if _cache.has(stem):
		return _cache[stem]
	var path: String = DIR + stem + ".json"
	var data: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			data = parsed
	_cache[stem] = data
	return data


static func socket(data: Dictionary, name: String) -> Dictionary:
	return (data.get("sockets", {}) as Dictionary).get(name, {})


## Caixa (AABB) de um encaixe ou zona: [[x0,y0,z0],[x1,y1,z1]].
static func aabb_of(box: Array) -> AABB:
	var a: Vector3 = Vector3(float(box[0][0]), float(box[0][1]), float(box[0][2]))
	var b: Vector3 = Vector3(float(box[1][0]), float(box[1][1]), float(box[1][2]))
	return AABB(a, b - a)


## Escala uniforme da peca no encaixe: largura do encaixe / largura nominal da peca, limitada (0,85-1,15).
static func fit_scale(data: Dictionary, entry: Dictionary) -> float:
	var s: Dictionary = socket(data, String(entry.get("socket", "")))
	var w: float = float(s.get("width", 0.0))
	var nom: float = float(entry.get("nominal_w", 0.0))
	if w <= 0.0 or nom <= 0.0:
		return 1.0
	var lim: Array = data.get("scale_limits", [0.85, 1.15])
	return clampf(w / nom, float(lim[0]), float(lim[1]))


## Cria os nos SOCKET_<encaixe> (no anchor de cada encaixe com ponto) dentro do modelo. Idempotente.
static func add_nodes(model: Node3D, glb_path: String) -> void:
	var data: Dictionary = for_model(glb_path)
	if data.is_empty():
		return
	var host: Node = model.get_child(0) if model.get_child_count() == 1 else model
	for name in data.get("sockets", {}):
		var s: Dictionary = data["sockets"][name]
		if not s.has("anchor") or model.find_child("SOCKET_" + String(name), true, false) != null:
			continue
		var a: Array = s["anchor"]
		var e := Node3D.new()
		e.name = "SOCKET_" + String(name)
		e.position = Vector3(float(a[0]), float(a[1]), float(a[2]))
		e.set_meta("sockets", data)
		host.add_child(e)
