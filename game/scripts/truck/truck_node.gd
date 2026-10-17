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
## Mural das laterais do bau: troque este PNG (proporcao ~4:1) pela arte que quiser; um
## user://mural_side.png (pasta de dados do jogo) tem prioridade, para testar sem reimportar.
const MURAL_PATH := "res://assets/vehicles/dekotora/murals/mural_side.png"
const MURAL_USER := "user://mural_side.png"
## Modelo: "base" (bau padrao), "leve" (bau curto), "longo" ou "carreta". Definir antes de add_child.
var body_kind: String = "base"
## Cabine: "padrao", "classica", "aero" ou "alta". Definir antes de add_child.
var cab_kind: String = "padrao"
## Cromo por matcap: "night" ou "day" (ChromeMatcap); "" = cromo PBR original. Definir antes de add_child.
var chrome_mode: String = "night"

var model: Node3D
var _wheels: Array[Node3D] = []
var _wheel_rest: Array[Basis] = []
var _headlight: SpotLight3D
var _tail_glow: OmniLight3D
var _spin: float = 0.0
var tint: Color = Color.WHITE
var _acc_nodes: Dictionary = {}        # id da peca -> Array[Node3D] (pode ter lado L e R)
var _acc_state: Dictionary = {}        # id da peca -> "ok" | "dent" | "broken"
var _mural_mat: StandardMaterial3D
var _decal_nodes: Array[Node3D] = []
const LIGHTS_OFF_LEVEL: float = 0.12
var _lamp_mats: Dictionary = {}              # nome do material de luz -> ShaderMaterial animado (um por caminhao)
var _lights_level: float = 1.0
var _pattern: String = "steady"
var _blinkers: Array[MeshInstance3D] = []   # 0 frente-esq., 1 frente-dir., 2 traseira-esq., 3 traseira-dir.


func _ready() -> void:
	var path: String = model_path(body_kind, cab_kind)
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning("TruckNode: modelo nao encontrado: " + path)
		return
	model = scene.instantiate() as Node3D
	add_child(model)
	if chrome_mode != "":
		ChromeMatcap.apply(model, chrome_mode)
	_apply_mural()
	_apply_light_materials(model)
	_build_blinkers()
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


## Luzinhas de marcacao (fileiras do bau, cabine, andon e das pecas): `on` = acesas (noite/tunel); apagadas
## ficam so como vidro fosco. `day_preview` = garagem de dia (acesas, mas fracas).
func set_lights_on(on: bool, day_preview: bool = false) -> void:
	_lights_level = (0.4 if day_preview else 1.0) if on else LIGHTS_OFF_LEVEL
	for m in _lamp_mats.values():
		(m as ShaderMaterial).set_shader_parameter("level", _lights_level)


## Padrao de pisca: "steady" (fixas), "sequential" (onda correndo), "alternate" (grupos alternando) ou "breathing".
func set_light_pattern(pattern: String) -> void:
	_pattern = pattern if pattern in LightPatterns.IDS else "steady"
	for m in _lamp_mats.values():
		(m as ShaderMaterial).set_shader_parameter("pattern", LightPatterns.IDS.find(_pattern))


## Troca os materiais das luzinhas (lamp_amber/yellow/pink/cyan) de `root` pelo material animado do padrao.
## Vermelho (lanterna) e branco (farol) ficam fixos. Chame de novo depois de montar pecas novas.
func _apply_light_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var cur: Material = m.get_active_material(s)
			if cur == null or not cur.resource_name.begins_with("lamp_") or not LightPatterns.ANIMATED.has(cur.resource_name):
				continue
			var key: String = cur.resource_name
			if not _lamp_mats.has(key):
				var sm: ShaderMaterial = LightPatterns.make_material(cur)
				sm.set_shader_parameter("level", _lights_level)
				sm.set_shader_parameter("pattern", LightPatterns.IDS.find(_pattern))
				_lamp_mats[key] = sm
			m.set_surface_override_material(s, _lamp_mats[key])


## Adesivos (DecalPlacer): lista de {id, slot, x, y, size, color}. Troca tudo de uma vez.
func apply_decals(decals: Array) -> void:
	for n in _decal_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_decal_nodes.clear()
	if model == null:
		return
	_decal_nodes = DecalPlacer.build(self, model, decals, -11.5 - float(LENGTH_DELTA.get(body_kind, 0.0)))


## Setas de faixa: 4 lamparinas ambar (frente e traseira, esquerda e direita), sem luz real (barato no celular).
func _build_blinkers() -> void:
	var front_z: float = -11.5 - float(LENGTH_DELTA.get(body_kind, 0.0))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.62, 0.05)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.0)
	mat.emission_energy_multiplier = 5.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var box := BoxMesh.new()
	box.size = Vector3(0.34, 0.2, 0.14)
	box.material = mat
	for i in 4:
		var m := MeshInstance3D.new()
		m.mesh = box
		var side: float = -1.0 if i % 2 == 0 else 1.0
		m.position = Vector3(side * 1.22, 0.95 if i < 2 else 1.05, front_z if i < 2 else 0.12)
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_blinkers.append(m)


## Pisca a seta do lado `dir` (-1 esquerda, +1 direita, 0 apagada), ~3 vezes por segundo.
func set_signal(dir: int) -> void:
	var on: bool = dir != 0 and int(Time.get_ticks_msec() / 160) % 2 == 0
	for i in _blinkers.size():
		var side: int = -1 if i % 2 == 0 else 1
		_blinkers[i].visible = on and side == dir


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
	if _mural_mat != null:
		_mural_mat.albedo_color = c.lerp(Color.WHITE, 0.45)          # rivais: mural levemente tingido
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if String(m.name).contains("paint_white"):
			var mat: StandardMaterial3D = (m.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = c
			m.material_override = mat


## Troca a textura do material "mural" (laterais do bau) pelo PNG trocavel.
func _apply_mural() -> void:
	var tex: Texture2D = null
	if FileAccess.file_exists(MURAL_USER):
		var img := Image.load_from_file(ProjectSettings.globalize_path(MURAL_USER))
		if img != null and not img.is_empty():
			img.generate_mipmaps()
			tex = ImageTexture.create_from_image(img)
	elif ResourceLoader.exists(MURAL_PATH):
		tex = load(MURAL_PATH) as Texture2D
	if tex == null:
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var cur: Material = m.get_active_material(s)
			if cur != null and cur.resource_name == "mural":
				if _mural_mat == null:
					_mural_mat = (cur as StandardMaterial3D).duplicate() as StandardMaterial3D if cur is StandardMaterial3D else StandardMaterial3D.new()
					_mural_mat.albedo_texture = tex
					_mural_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				m.set_surface_override_material(s, _mural_mat)


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
				if chrome_mode != "":
					ChromeMatcap.apply(n, chrome_mode)
				_apply_light_materials(n)
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
