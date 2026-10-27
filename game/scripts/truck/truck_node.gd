class_name TruckNode
extends Node3D
## Caminhao 3D: instancia o .glb (PBR), gira as rodas conforme a velocidade, liga farois e
## lanternas. A origem do no e a TRASEIRA do bau no chao; a frente aponta para -Z (convencao Godot).
## Pecas (acessorios) entram nos nos MOUNT_* do modelo.

## Caminhao padrao (bau medio + cabine padrao CabCatalog.DEFAULT): visualizador de acessorios e testes.
const MODEL_PATH := "res://assets/vehicles/dekotora/truck/dekotora_truck_base_chata.glb"
const MODEL_PATHS: Dictionary = {
	"base": MODEL_PATH,
	"leve": "res://assets/vehicles/dekotora/truck/dekotora_truck_leve_chata.glb",
	"longo": "res://assets/vehicles/dekotora/truck/dekotora_truck_longo_chata.glb",
	"carreta": "res://assets/vehicles/dekotora/truck/dekotora_truck_carreta.glb",
	"canter": "res://assets/vehicles/dekotora/truck/dekotora_truck_canter.glb",   # T-125: so com a cabine do JAC
	"graneleira": "res://assets/vehicles/dekotora/truck/dekotora_truck_graneleira_chata.glb",   # T-145: aberta com lona
	# T-218: caminhoes de homenagem (feitos do zero, marca ficticia), cada um com a cabine dele
	"alubox": "res://assets/vehicles/dekotora/truck/dekotora_truck_alubox.glb",
	"tarp": "res://assets/vehicles/dekotora/truck/dekotora_truck_tarp.glb",
	"pinkbox": "res://assets/vehicles/dekotora/truck/dekotora_truck_pinkbox.glb",
	"tanker": "res://assets/vehicles/dekotora/truck/dekotora_truck_tanker.glb",
	"dump": "res://assets/vehicles/dekotora/truck/dekotora_truck_dump.glb",
}
const MODEL_DIR := "res://assets/vehicles/dekotora/truck/"
## Cabines que existem em .glb (T-129: so de modelos de arquivo; ids antigos caem em CabCatalog.normalize).
const CABS: Array[String] = CabCatalog.IDS
## Quanto a frente de cada cabine passa da frente padrao (CAB_Y1 = 11,5 m): JAC grande e bico longo americano.
const CAB_FRONT_DELTA: Dictionary = {"jac": 0.17, "americana": 0.09}
## Modelos com cabine fixa (nao combinam com as outras cabines).
const FIXED_CAB: Dictionary = {"canter": "canter", "alubox": "flat_wide", "tarp": "flat_quad", "pinkbox": "flat_wide",
		"tanker": "flat_wide", "dump": "flat_quad"}
## LODs (T-218): <modelo>_lod1.glb e _lod2.glb nesta pasta (so os caminhoes de homenagem tem). O LOD0 (o .glb de sempre,
## com pecas, rodas que giram e pontos de montagem) aparece ate LOD_RANGES[0] m da camera; o LOD1 ate LOD_RANGES[1]; o
## LOD2 dali em diante. As pecas compradas ficam sempre (sao filhas dos pontos de montagem do LOD0).
const LOD_DIR := "res://assets/vehicles/dekotora/truck/lod/"
const LOD_RANGES: Array[float] = [45.0, 120.0]
## Quanto cada modelo e mais comprido que o padrao (m); desloca o farol dianteiro.
const LENGTH_DELTA: Dictionary = {"base": 0.0, "leve": -2.8, "longo": 1.6, "carreta": 5.5, "canter": -4.6, "graneleira": 0.0,
		"alubox": 0.0, "tarp": 0.0, "pinkbox": 0.0, "tanker": 0.0, "dump": 0.0}
const WHEEL_RADIUS: float = 0.52
## Fumaca do motor (T-246): quanto abaixo da borda de baixo do para-brisa e quanto para dentro da frente da cabine (m).
const SMOKE_BELOW_GLASS: float = 0.45
const SMOKE_INSET: float = 0.15
const WHEEL_RADII: Dictionary = {"canter": 0.44}
## Mural das laterais do bau: troque este PNG (proporcao ~4:1) pela arte que quiser; um
## user://mural_side.png (pasta de dados do jogo) tem prioridade, para testar sem reimportar.
const MURAL_PATH := "res://assets/vehicles/dekotora/murals/mural_side.png"
const MURAL_USER := "user://mural_side.png"
## Modelo: "base" (bau medio), "leve" (bau curto), "longo", "canter", "graneleira" (aberta com lona, chassi do bau medio;
## T-145) ou "carreta" (guardada). Definir antes de add_child.
var body_kind: String = "base"
## Cabine: um id de CabCatalog.IDS ("chata", "jac", "curta", "americana"); ids antigos viram o mais parecido.
## Definir antes de add_child.
var cab_kind: String = CabCatalog.DEFAULT
## Cromo por matcap: "night" ou "day" (ChromeMatcap); "" = cromo PBR original. Definir antes de add_child.
var chrome_mode: String = "night"

## Placas de veiculo (T-130): camada da cena (corrida, uma chamada de desenho para todos); null = cria a sua.
var plates: LicensePlates
## Celula do atlas de placas (PlateCatalog); -1 = a camada escolhe. Gancho para a placa do jogador. Antes de add_child.
var plate_cell: int = -1
var _plate_ids: Array[int] = []
var _plates_queued: bool = false

var model: Node3D
## Rodas (giro por raio de cada roda, esterçamento, pecas de roda presas no pneu; T-133).
var wheels: TruckWheels = TruckWheels.new()
var _headlight: SpotLight3D
var _tail_glow: OmniLight3D
var tint: Color = Color.WHITE
var _acc_nodes: Dictionary = {}        # id da peca -> Array[Node3D] (pode ter lado L e R)
var _acc_state: Dictionary = {}        # id da peca -> "ok" | "dent" | "broken"
var _mural_mat: StandardMaterial3D
var _mural_glow: float = 0.0           # T-155: forca da luz falsa no mural (MuralGlow)
var _decal_nodes: Array[Node3D] = []
const LIGHTS_OFF_LEVEL: float = 0.12
var _lamp_mats: Dictionary = {}              # nome do material de luz -> ShaderMaterial animado (um por caminhao)
var _lights_level: float = 1.0
var _pattern: String = "steady"
var signals: TruckSignals = TruckSignals.new()   # T-239: setas em cima das lampadas (0 FE, 1 FD, 2 TE, 3 TD)
var _blink := SignalBlink.new()             # T-170: ritmo do pisca (1,5 Hz)
var _blink_shown: int = 0
var _sockets: Dictionary = {}               # encaixes/medidas do .glb (TruckSockets)
var _stock_rear: Node3D                     # T-239: lanterna de fabrica do jogo (so baus sem lanterna ambar atras)
var _brake: float = 0.0                     # T-239: 0..1 luz de freio (todas as luzes vermelhas)
var _red_mats: Array[StandardMaterial3D] = []   # lanternas vermelhas de fabrica deste caminhao (brilham mais no freio)
var _red_base: Array[float] = []
const BRAKE_ON_S: float = 0.08              # s para acender todas as luzes de vermelho (rapido, sem piscar feio)
const BRAKE_OFF_S: float = 0.15
const BRAKE_RED_GAIN: float = 1.0           # lanterna vermelha de fabrica: + 100% de brilho freando
## Brilho no chao (neon de chao, estribo) e acrilico do andon das pecas deluxe (T-172), pela mesma forca das luzinhas.
var glow: AccessoryGlow = AccessoryGlow.new()


func _ready() -> void:
	cab_kind = CabCatalog.normalize(cab_kind)
	var path: String = model_path(body_kind, cab_kind)
	var scene: PackedScene = load(path) as PackedScene
	if scene == null:
		push_warning("TruckNode: modelo nao encontrado: " + path)
		return
	model = scene.instantiate() as Node3D
	add_child(model)
	add_extra_mounts(model, body_kind, cab_kind)
	TruckSockets.add_nodes(model, path)              # T-211: encaixes das pecas da oficina (deque, viseira...)
	_sockets = TruckSockets.for_model(path)
	_attach_lods(path)                               # T-218: antes do cromo/mural/texturas (valem para os LODs tambem)
	RearDoorLamps.strip(model, _sockets)             # T-239: porta de tras do bau sem luzes (so as do para-choque; LODs tambem)
	if StockRearLamps.needed(model, _sockets):
		_stock_rear = StockRearLamps.build(model, _sockets)
	if chrome_mode != "":
		ChromeMatcap.apply(model, chrome_mode)
	_apply_mural()
	TruckTextures.apply(model)               # texturas grandes compartilhadas (o .glb so traz miniaturas)
	_apply_light_materials(model)
	_place_blinkers()
	wheels.setup(model, float(WHEEL_RADII.get(body_kind, WHEEL_RADIUS)))
	_headlight = SpotLight3D.new()
	_headlight.position = Vector3(0, 1.2, -11.6 - front_delta())
	_headlight.rotation_degrees = Vector3(-4, 0, 0)
	_headlight.spot_range = 70.0
	_headlight.spot_angle = 32.0
	_headlight.light_energy = 1.6                 # T-199: was 3.0 (white blown-out pool on the wet asphalt at night)
	_headlight.light_specular = 0.3              # T-199: softer glare of the wet asphalt / sign panels
	_headlight.spot_angle_attenuation = 1.8      # T-199: soft edge instead of a hard bright disc
	_headlight.light_color = Color(1.0, 0.93, 0.78)
	_headlight.shadow_enabled = false
	_headlight.visible = int(Engine.get_main_loop().root.get_node("Settings").quality) >= 1
	add_child(_headlight)
	_queue_plates()


func _queue_plates() -> void:
	if not _plates_queued:
		_plates_queued = true
		_place_plates.call_deferred()            # uma vez por quadro (depois do queue_free das pecas antigas)


## Placa da frente e de tras (PlateCatalog, estilo comercial verde); refeita quando as pecas mudam.
func _place_plates() -> void:
	_plates_queued = false
	if model == null or not is_inside_tree():
		return
	if plates == null:
		plates = LicensePlates.new()
		add_child(plates)
	var s: Array = TruckPlateSpots.spots(self, model, shown_cab())
	if _plate_ids.is_empty():
		var cell: int = plate_cell if plate_cell >= 0 else plates.pick(PlateCatalog.Style.GREEN, 0)
		plate_cell = cell
		_plate_ids = [plates.add_plate(self, s[0], cell), plates.add_plate(self, s[1], cell)]
	plates.set_plate(_plate_ids[0], s[0], true)
	plates.set_plate(_plate_ids[1], s[1], bool(s[2]))


## Luzinhas de marcacao (fileiras do bau, cabine, andon e das pecas): `on` = acesas (noite/tunel); apagadas
## ficam so como vidro fosco. `day_preview` = garagem de dia (acesas, mas fracas).
func set_lights_on(on: bool, day_preview: bool = false) -> void:
	_lights_level = (0.4 if day_preview else 1.0) if on else LIGHTS_OFF_LEVEL
	for m in _lamp_mats.values():
		(m as ShaderMaterial).set_shader_parameter("level", _lights_level)
	glow.set_level(_lights_level)


## Luz falsa no mural das laterais (bau e tampas da graneleira; T-155): 0 = sem luz (dia), ~0,5 = noite.
## Corrida: TimeOfDay.mural_glow (e MuralGlow.TUNNEL dentro de tunel). Pode ser chamado antes ou depois de add_child.
func set_mural_glow(energy: float) -> void:
	_mural_glow = maxf(energy, 0.0)
	if _mural_mat != null:
		MuralGlow.set_level(_mural_mat, _mural_glow, _mural_mat.albedo_color)
	for id in _acc_nodes:                            # T-232: pinturas compradas (mural, traseira, teto) acendem junto
		for n in _acc_nodes[id]:
			if is_instance_valid(n) and (n as Node3D).has_meta("paint_mat"):
				MuralGlow.set_level((n as Node3D).get_meta("paint_mat") as StandardMaterial3D, _mural_glow)


func mural_glow() -> float:
	return _mural_glow


## Padrao de pisca: "steady" (fixas), "sequential" (onda correndo), "alternate" (grupos alternando) ou "breathing".
func set_light_pattern(pattern: String) -> void:
	_pattern = pattern if pattern in LightPatterns.IDS else "steady"
	for k in _lamp_mats:
		if not LightPatterns.is_steady_lit(String(k)):   # T-231: lanterna (lamp_tail) acende mas nao pisca
			(_lamp_mats[k] as ShaderMaterial).set_shader_parameter("pattern", LightPatterns.IDS.find(_pattern))


## Troca os materiais das luzinhas (lamp_amber/yellow/pink/cyan) de `root` pelo material animado do padrao.
## Branco (farol) fica fixo; vermelho (lanterna de fabrica) ganha uma copia por caminhao que brilha mais no freio (T-239).
## Chame de novo depois de montar pecas novas.
func _apply_light_materials(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var cur: Material = m.get_active_material(s)
			if cur is StandardMaterial3D and cur.resource_name == "lamp_red":
				m.set_surface_override_material(s, _red_copy(cur as StandardMaterial3D))
				continue
			if cur == null or not cur.resource_name.begins_with("lamp_") or not (LightPatterns.is_animated(cur.resource_name) 					or LightPatterns.is_steady_lit(cur.resource_name)):
				continue
			var key: String = cur.resource_name
			if not _lamp_mats.has(key):
				var sm: ShaderMaterial = LightPatterns.make_material(cur)
				sm.set_shader_parameter("level", _lights_level)
				sm.set_shader_parameter("pattern", 0 if LightPatterns.is_steady_lit(key) else LightPatterns.IDS.find(_pattern))
				sm.set_shader_parameter("brake", _brake)
				_lamp_mats[key] = sm
			m.set_surface_override_material(s, _lamp_mats[key])


## Copia por caminhao da lanterna vermelha de fabrica (o .glb divide o material entre todos os caminhoes).
func _red_copy(src: StandardMaterial3D) -> StandardMaterial3D:
	if src in _red_mats:
		return src
	var i: int = _red_base.size()
	for k in _red_mats.size():
		if _red_mats[k].get_meta("src", null) == src:
			return _red_mats[k]
	var dup: StandardMaterial3D = src.duplicate() as StandardMaterial3D
	dup.set_meta("src", src)
	_red_mats.append(dup)
	_red_base.append(dup.emission_energy_multiplier if dup.emission_enabled else 0.0)
	_apply_red(i)
	return dup


func _apply_red(i: int) -> void:
	if _red_mats[i].emission_enabled:
		_red_mats[i].emission_energy_multiplier = _red_base[i] * (1.0 + BRAKE_RED_GAIN * _brake)


## T-239: luz de freio. `on` = freio apertado (TruckSim.brake_lamp); `dt` em s (transicao de BRAKE_ON_S / BRAKE_OFF_S;
## dt grande = na hora). Todas as luzinhas, LEDs, neons e lanternas ficam vermelhos e fixos; o farol branco e a seta
## nao mudam. So mexe em uniformes quando o valor muda (nada de material novo).
func set_brake(on: bool, dt: float) -> void:
	var target: float = 1.0 if on else 0.0
	var b: float = move_toward(_brake, target, dt / (BRAKE_ON_S if on else BRAKE_OFF_S))
	if b == _brake:
		return
	_brake = b
	for m in _lamp_mats.values():
		(m as ShaderMaterial).set_shader_parameter("brake", _brake)
	for i in _red_mats.size():
		_apply_red(i)
	glow.set_brake(_brake)


## Luz de freio agora (0..1; testes).
func brake_level() -> float:
	return _brake


## Adesivos (DecalPlacer): lista de {id, slot, x, y, size, color}. Troca tudo de uma vez.
func apply_decals(decals: Array) -> void:
	for n in _decal_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_decal_nodes.clear()
	if model == null:
		return
	_decal_nodes = DecalPlacer.build(self, model, decals, -11.5 - front_delta(), shown_cab())


## Pisca a seta do lado `dir` (-1 esquerda, +1 direita, 0 apagada, 2 = pisca-alerta dos dois lados, T-202), ~1,5 vez por segundo (T-170: SignalBlink,
## comeca aceso no toque). So mexe na visibilidade quando muda (nenhum no ou material novo).
func set_signal(dir: int) -> void:
	if _blink.update(dir, SignalBlink.now()) == SignalBlink.Edge.NONE and dir == _blink_shown:
		return
	_blink_shown = dir
	for i in 4:
		signals.set_visible(i, _blink_lit(i))


func _blink_lit(i: int) -> bool:
	var side: int = -1 if i % 2 == 0 else 1
	return _blink.lit and (side == _blink_shown or _blink_shown == 2)     # T-202: 2 = hazard (both sides)


## A seta esta acesa agora (testes)?
func signal_lit() -> bool:
	return _blink.lit


## Gira as rodas (cada uma por velocidade / raio dela) e estérça as dianteiras; as calotas e rodas da loja
## sao filhas das rodas e acompanham. `speed` em m/s, `dt` em segundos reais, `steer` em -1..1.
func animate(speed: float, dt: float, steer: float = 0.0) -> void:
	wheels.animate(speed, dt, steer)


## T-219: balanco da carroceria (TruckMotion): inclina o modelo (cabine, bau e pecas) e as rodas ficam no chao.
## `length` = comprimento do caminhao na pista (pivo do cabeceio no meio dele).
func set_body_motion(roll: float, pitch: float, heave: float, length: float) -> void:
	if model == null:
		return
	var b: Transform3D = TruckMotion.body_transform(roll, pitch, heave, length)
	if _model_rest == null:
		_model_rest = model.transform
	model.transform = b * (_model_rest as Transform3D)
	wheels.body = b
	wheels.apply()


var _model_rest: Variant = null           # transform original do modelo (antes do primeiro balanco)


func set_headlights(on: bool) -> void:
	if _headlight:
		_headlight.visible = on and int(Engine.get_main_loop().root.get_node("Settings").quality) >= 1


## Tinge a pintura branca (rivais de cores diferentes) sem duplicar o modelo.
func set_paint_color(c: Color) -> void:
	tint = c
	if model == null:
		return
	if _mural_mat != null and _own_mural() == "":
		_mural_mat.albedo_color = c.lerp(Color.WHITE, 0.45)          # rivais: mural levemente tingido (o proprio do modelo nao)
		MuralGlow.set_level(_mural_mat, _mural_glow, _mural_mat.albedo_color)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if String(m.name).contains("paint_white"):
			var mat: StandardMaterial3D = (m.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
			mat.albedo_color = c
			m.material_override = mat


## Troca a textura do material "mural" (laterais do bau) pelo PNG trocavel.
func _apply_mural() -> void:
	var tex: Texture2D = null
	var emit: Texture2D = null
	if _own_mural() != "":                       # T-218: mural proprio do modelo (baú rosa) + emissao dos neons
		tex = load(_own_mural()) as Texture2D
		var bd: BodyDef = BodyDef.find(body_kind)
		if bd != null and bd.mural_emit != "" and ResourceLoader.exists(bd.mural_emit):
			emit = load(bd.mural_emit) as Texture2D
	elif FileAccess.file_exists(MURAL_USER):
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
					TruckTextures.swap_textures(_mural_mat)      # bau premium: normais/oclusao da chapa (T-136)
					_mural_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
					MuralGlow.setup(_mural_mat, tex, emit)       # T-155: luz falsa das luzinhas (forca 0 ate set_mural_glow)
					MuralGlow.set_level(_mural_mat, _mural_glow, _mural_mat.albedo_color)
				m.set_surface_override_material(s, _mural_mat)


## PNG do mural proprio do modelo (BodyDef.mural) ou "" (usa o mural trocavel de sempre).
func _own_mural() -> String:
	var bd: BodyDef = BodyDef.find(body_kind)
	return bd.mural if bd != null and bd.mural != "" and ResourceLoader.exists(bd.mural) else ""


## LODs do modelo (T-218): esconde as malhas do .glb a partir de LOD_RANGES[0] m e poe as versoes leves no lugar.
## Sem os arquivos _lod1/_lod2, nao faz nada (os caminhoes antigos continuam como antes).
func _attach_lods(path: String) -> void:
	var stem: String = path.get_file().get_basename()
	var paths: Array[String] = [LOD_DIR + stem + "_lod1.glb", LOD_DIR + stem + "_lod2.glb"]
	if not ResourceLoader.exists(paths[0]) or not ResourceLoader.exists(paths[1]):
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).visibility_range_end = LOD_RANGES[0]
	for k in 2:
		var lod: Node3D = (load(paths[k]) as PackedScene).instantiate() as Node3D
		lod.name = "LOD%d" % (k + 1)
		for mi in lod.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			m.visibility_range_begin = LOD_RANGES[k]
			m.visibility_range_end = LOD_RANGES[1] if k == 0 else 0.0
			m.set_meta("lod", k + 1)
			if k == 1:
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.add_child(lod)


## Quantos LODs este caminhao tem carregados (0 = so o modelo; testes).
func lod_count() -> int:
	return 0 if model == null else model.find_children("LOD*", "Node3D", false, false).size()


## Pontos de montagem que os .glb ainda nao tem (T-126: escapamentos altos atras da cabine). Posicao no Blender
## (x, y, z; y = da traseira do bau para a frente) e escala da peca. Criados em tempo de execucao para nao regerar
## os 20 modelos; um .glb futuro que ja traga o ponto tem prioridade.
static func extra_mounts(body: String, cab: String) -> Dictionary:
	var d: float = float(LENGTH_DELTA.get(body, 0.0))
	var stack: Vector3 = Vector3(1.3, 8.3 + d, 0.9)           # escapamentos de fabrica (chata, americana)
	var sc: float = 1.0
	if body == "canter":
		stack = Vector3(1.25, 5.09, 0.75)                    # entre a cabine curta e o bau do Canter
		sc = 0.88
	elif cab == "curta":
		stack = Vector3(1.4, 9.47 + d, 0.9)                  # canto de tras da cabine curta (o bau cresceu ate ali)
	elif cab == "jac":
		stack = Vector3(1.3, 9.15 + d, 0.9)                  # atras da cabine JAC grande (escapamentos de fabrica)
	return {"MOUNT_STACK_R": [stack, sc], "MOUNT_STACK_L": [Vector3(-stack.x, stack.y, stack.z), sc]}


static func add_extra_mounts(root: Node3D, body: String, cab: String) -> void:
	var host: Node = root.get_child(0) if root.get_child_count() == 1 else root    # o no raiz do .glb (DekotoraTruckBase)
	var em: Dictionary = extra_mounts(body, cab)
	for n in em:
		if root.find_child(String(n), true, false) != null:
			continue
		var p: Vector3 = em[n][0]
		var e := Node3D.new()
		e.name = String(n)
		e.position = Vector3(p.x, p.z, -p.y)
		e.scale = Vector3.ONE * float(em[n][1])
		host.add_child(e)


## Cabine que aparece de verdade (o Canter so tem a dele, qualquer que seja a escolha do perfil).
func shown_cab() -> String:
	return String(FIXED_CAB.get(body_kind, CabCatalog.normalize(cab_kind)))


## T-246: de onde sai a fumaca do motor ferido (metros do caminhao): na grade, ABAIXO do para-brisa, um pouco para
## dentro do bico (a fumaca brota da frente da cabine). Antes era fixo em (0; 2,4; -11), que no bau curto ficava
## solto no ar 2,3 m na frente do para-brisa e, olhando de frente, virava um quadrado cinza em cima do vidro.
func smoke_origin() -> Vector3:
	var front: float = -11.5 - front_delta()
	var top: float = 1.7
	var cab: Dictionary = (_sockets.get("measure", {}) as Dictionary).get("cab", {})
	if cab.has("front_z"):
		front = float(cab["front_z"])
	if cab.has("windshield"):
		top = TruckSockets.aabb_of(cab["windshield"]).position.y
	return Vector3(0.0, top - SMOKE_BELOW_GLASS, front + SMOKE_INSET)


## Quanto a frente deste caminhao passa da do caminhao padrao (m): comprimento do bau + bico da cabine.
func front_delta() -> float:
	var d: float = float(LENGTH_DELTA.get(body_kind, 0.0))
	if not FIXED_CAB.has(body_kind):
		d += float(CAB_FRONT_DELTA.get(CabCatalog.normalize(cab_kind), 0.0))
	return d


## Caminho do .glb para a combinacao carroceria + cabine (`dekotora_truck_<bau>_<cabine>.glb`; o Canter e a
## carreta tem cabine fixa). Cabine antiga ou desconhecida vira a nova mais parecida (CabCatalog.normalize).
static func model_path(body: String, cab: String) -> String:
	if FIXED_CAB.has(body) or body == "carreta":
		return String(MODEL_PATHS[body])
	var path: String = MODEL_DIR + "dekotora_truck_%s_%s.glb" % [body, CabCatalog.normalize(cab)]
	if not ResourceLoader.exists(path):
		return String(MODEL_PATHS.get(body, MODEL_PATH))
	return path


## Monta os acessorios 3D das pecas instaladas (PartDef) nos pontos de encaixe do caminhao. `styles` (T-211):
## {id da peca: {"color": id de DecoColorDef, "sign": celula do letreiro}} das pecas da oficina; vazio = de fabrica.
func apply_loadout(defs: Array[PartDef], styles: Dictionary = {}) -> void:
	for id in _acc_nodes:
		for n in _acc_nodes[id]:
			if is_instance_valid(n):
				if (n as Node).get_parent() != null and String((n as Node).get_parent().name).begins_with("SOCKET_"):
					(n as Node).get_parent().remove_child(n)      # T-233: a seta/placa nao pode achar a peca velha
				n.queue_free()
	_acc_nodes.clear()
	_acc_state.clear()
	if model == null:
		return
	var catalog: AccessoryCatalog = AccessoryCatalog.get_instance()
	var tops: Array[PartDef] = []
	var lower: Node3D = null
	var lower_entry: Dictionary = {}
	for d in defs:
		var entry: Dictionary = catalog.entry(d.accessory_id)
		if entry.is_empty():
			continue
		if bool((styles.get(String(d.id), {}) as Dictionary).get("top", false)):
			tops.append(d)                           # T-215: 2o nivel do deque, montado em cima da peca de baixo
			continue
		var list: Array = []
		var made: Array[Node3D] = []
		if TruckWheels.is_wheel_part(entry):            # calota/roda da loja: em TODAS as rodas externas, presa no pneu
			made = wheels.attach_part(catalog, d.accessory_id)
		else:
			for side in (["R", "L"] if bool(entry.get("mirror_for_left", false)) else ["R"]):
				made.append(catalog.attach(model, d.accessory_id, side))
		for n in made:
			if n != null:
				_finish_part(n, d, entry, styles)
				list.append(n)
				if String(entry.get("socket", "")) == DeckStack.LOWER_SLOT:
					lower = n
					lower_entry = entry
		_acc_nodes[String(d.id)] = list
		_acc_state[String(d.id)] = "ok"
	_after_frame_parts(catalog, defs)
	for d in tops:
		var top: Node3D = _mount_top(catalog, d, lower, lower_entry)
		if top != null:
			_finish_part(top, d, catalog.entry(d.accessory_id), styles)
			_acc_nodes[String(d.id)] = [top]
			_acc_state[String(d.id)] = "ok"
	_queue_plates()


## T-233: espelho de fabrica some onde ha haste de retrovisor da oficina; seta da frente vai para o para-choque novo.
func _after_frame_parts(catalog: AccessoryCatalog, defs: Array[PartDef]) -> void:
	var sides: Array = []
	for d in defs:
		if String(catalog.entry(d.accessory_id).get("fit", "")) == "stay":
			sides = ["r", "l"]
	var data: Dictionary = TruckSockets.for_model(model_path(body_kind, cab_kind))
	FrameFit.hide_stock(model, FrameFit.stock_boxes(data, sides))
	_place_blinkers()


## T-239: setas em cima das lampadas (TruckSignals). A lanterna de fabrica do jogo some quando ha para-choque traseiro
## da oficina (a peca traz as lanternas dela).
func _place_blinkers() -> void:
	if model == null:
		return
	if _stock_rear != null:
		_stock_rear.visible = not _has_rear_part()
	var lit: Array[bool] = []
	for i in 4:
		lit.append(_blink_lit(i))
	signals.rebuild(self, model, _sockets, -11.5 - front_delta(), lit)


func _has_rear_part() -> bool:
	var rb: Node = model.find_child("SOCKET_rear_bumper", true, false)
	if rb == null:
		return false
	for c in rb.get_children():
		if not c.is_queued_for_deletion() and c is Node3D and (c as Node3D).visible:
			return true
	return false


## Variante, cor/letreiro/luzes da oficina, brilho, cromo e luzinhas de uma peca recem-montada.
func _finish_part(n: Node3D, d: PartDef, entry: Dictionary, styles: Dictionary) -> void:
	var catalog: AccessoryCatalog = AccessoryCatalog.get_instance()
	if n.has_meta("paint_mat"):                  # T-232: pintura = so a arte (sem cor L/R, cromo nem luzinhas)
		MuralGlow.set_level(n.get_meta("paint_mat") as StandardMaterial3D, _mural_glow)
		return
	catalog.apply_variant(n, d.accessory_id, d.variant)
	if DecoStyle.is_deco(entry):             # T-211: cor L/R e letreiro (antes do brilho e do cromo); T-214: luzes
		var st: Dictionary = styles.get(String(d.id), {})
		DecoStyle.apply(n, entry, String(st.get("color", "")), int(st.get("sign", -1)), String(st.get("led", "")),
				String(st.get("neon", "")))
	glow.apply(n)                            # antes das luzinhas (que tiram o nome dos materiais lamp_*)
	if chrome_mode != "":
		ChromeMatcap.apply(n, chrome_mode)
	_apply_light_materials(n)
	if DecoStyle.is_deco(entry):
		n.set_meta("deco", true)
		n.set_meta("deco_id", d.accessory_id)       # T-231: a peca quebrada le a inclinacao dela no catalogo


## Peca do 2o nivel do deque (T-215): filha da peca de baixo, em cima dela. Confere de novo se cabe NESTE caminhao (o
## descritor de outro jogador pode vir de outra cabine); nao cabendo, nao monta.
func _mount_top(catalog: AccessoryCatalog, d: PartDef, lower: Node3D, lower_entry: Dictionary) -> Node3D:
	if lower == null:
		return null
	var mount: Node = lower.get_parent()
	var data: Dictionary = mount.get_meta("sockets", {}) if mount != null else {}
	if not DeckStack.fits(data, String(lower_entry.get("id", "")), d.accessory_id):
		return null
	var top: Node3D = catalog.instantiate(d.accessory_id)
	if top == null:
		return null
	top.name = "acc_%s_TOP" % d.accessory_id
	lower.add_child(top)
	SocketSeat.place_upper(top, lower, lower_entry, catalog.entry(d.accessory_id))
	return top


## Estado visual de uma peca: "ok", "dent" (opaca/amassada) ou "broken" (some do caminhao).
func set_part_state(part_id: String, state: String) -> void:
	if not _acc_nodes.has(part_id) or _acc_state.get(part_id, "ok") == state:
		return
	_acc_state[part_id] = state
	var catalog: AccessoryCatalog = AccessoryCatalog.get_instance()
	for n in _acc_nodes[part_id]:
		var node: Node3D = n
		if node.has_meta("paint"):                    # T-232: pintura nao amassa nem cai (risca: perfil, "scratch")
			continue
		if state == "broken" and node.has_meta("deco"):   # T-211: peca da oficina quebrada fica (torta e apagada)
			DecoStyle.set_broken(node, catalog)
			continue
		node.visible = state != "broken"
		if state == "dent":
			catalog.swap_material(node, "chrome", "steel")
			if not node.has_meta("wheel_part"):          # peca de roda gira com o pneu: sem inclinar o encaixe
				node.rotation.x = 0.06


## Sincroniza todos os acessorios com o dano da simulacao (lista de pecas de TruckSim.loadout).
func sync_damage(loadout: Array[Dictionary]) -> void:
	for p in loadout:
		set_part_state(String(p["id"]), DamageModel.part_state(p))
