class_name TruckNode
extends Node3D
## Caminhao 3D: instancia o .glb (PBR), gira as rodas conforme a velocidade, liga farois e
## lanternas. A origem do no e a TRASEIRA do bau no chao; a frente aponta para -Z (convencao Godot).
## Pecas (acessorios) entram nos nos MOUNT_* do modelo.

const MODEL_PATH := "res://assets/vehicles/dekotora/truck/dekotora_truck_base.glb"
const MODEL_PATHS: Dictionary = {
	"base": MODEL_PATH,
	"leve": "res://assets/vehicles/dekotora/truck/dekotora_truck_leve.glb",
	"longo": "res://assets/vehicles/dekotora/truck/dekotora_truck_longo.glb",
	"carreta": "res://assets/vehicles/dekotora/truck/dekotora_truck_carreta.glb",
}
const MODEL_DIR := "res://assets/vehicles/dekotora/truck/"
## Quanto cada modelo e mais comprido que o padrao (m); desloca o farol dianteiro.
const LENGTH_DELTA: Dictionary = {"base": 0.0, "leve": -2.8, "longo": 1.6, "carreta": 5.5}
const WHEEL_RADIUS: float = 0.52
## Modelo: "base" (bau padrao), "leve" (bau curto), "longo" ou "carreta". Definir antes de add_child.
var body_kind: String = "base"
## Cabine: "padrao", "classica", "aero" ou "alta". Definir antes de add_child.
var cab_kind: String = "padrao"

var model: Node3D
var _wheels: Array[Node3D] = []
var _wheel_rest: Array[Basis] = []
var _headlight: SpotLight3D
var _tail_glow: OmniLight3D
var _spin: float = 0.0
var tint: Color = Color.WHITE
var _acc_nodes: Dictionary = {}        # id da peca -> Array[Node3D] (pode ter lado L e R)
var _acc_state: Dictionary = {}        # id da peca -> "ok" | "dent" | "broken"


func _ready() -> void:
	var path: String = model_path(body_kind, cab_kind)
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning("TruckNode: modelo nao encontrado: " + path)
		return
	model = scene.instantiate() as Node3D
	add_child(model)
	for n in model.find_children("wheel_*", "Node3D", true, false):
		_wheels.append(n as Node3D)
		_wheel_rest.append((n as Node3D).transform.basis)   # rotacao original do .glb (eixo do pneu em X)
	_headlight = SpotLight3D.new()
	_headlight.position = Vector3(0, 1.2, -11.6 - float(LENGTH_DELTA.get(body_kind, 0.0)))
	_headlight.rotation_degrees = Vector3(-4, 0, 0)
	_headlight.spot_range = 70.0
	_headlight.spot_angle = 32.0
	_headlight.light_energy = 3.0
	_headlight.light_color = Color(1.0, 0.93, 0.78)
	_headlight.shadow_enabled = false
	_headlight.visible = int(Engine.get_main_loop().root.get_node("Settings").quality) >= 1
	add_child(_headlight)


## Gira as rodas e aplica a escala de velocidade; `dt` em segundos reais.
func animate(speed: float, dt: float, steer: float = 0.0) -> void:
	_spin += speed / WHEEL_RADIUS * dt
	_spin = fmod(_spin, TAU)                 # evita perder precisao em corridas longas
	for i in _wheels.size():
		var w: Node3D = _wheels[i]
		var r: Basis = Basis(Vector3.RIGHT, -_spin)
		var base_yaw: float = 0.0
		if String(w.name).begins_with("wheel_f"):
			base_yaw = -steer * 0.35
		# ordem: rotacao original do modelo -> giro no eixo X -> esterçamento no eixo vertical
		w.transform.basis = Basis(Vector3.UP, base_yaw) * r * _wheel_rest[i]


func set_headlights(on: bool) -> void:
	if _headlight:
		_headlight.visible = on and int(Engine.get_main_loop().root.get_node("Settings").quality) >= 1


## Tinge a pintura branca (rivais de cores diferentes) sem duplicar o modelo.
func set_paint_color(c: Color) -> void:
	tint = c
	if model == null:
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if String(m.name).contains("paint_white"):
			var mat: StandardMaterial3D = (m.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = c
			m.material_override = mat


## Caminho do .glb para a combinacao carroceria + cabine (a cabine "padrao" nao tem sufixo).
static func model_path(body: String, cab: String) -> String:
	if cab == "padrao" or not ResourceLoader.exists(MODEL_DIR + "dekotora_truck_%s_%s.glb" % [body, cab]):
		return String(MODEL_PATHS.get(body, MODEL_PATH))
	return MODEL_DIR + "dekotora_truck_%s_%s.glb" % [body, cab]


## Monta os acessorios 3D das pecas instaladas (PartDef) nos pontos de encaixe do caminhao.
func apply_loadout(defs: Array[PartDef]) -> void:
	for id in _acc_nodes:
		for n in _acc_nodes[id]:
			if is_instance_valid(n):
				n.queue_free()
	_acc_nodes.clear()
	_acc_state.clear()
	if model == null:
		return
	var catalog: AccessoryCatalog = AccessoryCatalog.get_instance()
	for d in defs:
		var entry: Dictionary = catalog.entry(d.accessory_id)
		if entry.is_empty():
			continue
		var list: Array = []
		for side in (["R", "L"] if bool(entry.get("mirror_for_left", false)) else ["R"]):
			var n: Node3D = catalog.attach(model, d.accessory_id, side)
			if n != null:
				catalog.apply_variant(n, d.accessory_id, d.variant)
				list.append(n)
		_acc_nodes[String(d.id)] = list
		_acc_state[String(d.id)] = "ok"


## Estado visual de uma peca: "ok", "dent" (opaca/amassada) ou "broken" (some do caminhao).
func set_part_state(part_id: String, state: String) -> void:
	if not _acc_nodes.has(part_id) or _acc_state.get(part_id, "ok") == state:
		return
	_acc_state[part_id] = state
	var catalog: AccessoryCatalog = AccessoryCatalog.get_instance()
	for n in _acc_nodes[part_id]:
		var node: Node3D = n
		node.visible = state != "broken"
		if state == "dent":
			catalog.swap_material(node, "chrome", "steel")
			node.rotation.x = 0.06


## Sincroniza todos os acessorios com o dano da simulacao (lista de pecas de TruckSim.loadout).
func sync_damage(loadout: Array[Dictionary]) -> void:
	for p in loadout:
		set_part_state(String(p["id"]), DamageModel.part_state(p))
