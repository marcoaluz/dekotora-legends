class_name MenuBackdrop
extends Node3D
## Fundo 3D da tela inicial (T-138): o caminhao do jogador numa cena leve. Opcoes (escolha do Marco pendente):
##   a  = posto de estrada a noite com neon (MenuBgRestStop) — padrao provisorio
##   b  = rodovia a noite, caminhao passando em camera lenta (MenuBgHighway)
##   hall = galpao da garagem (o fundo antigo, MenuBgHall)
## Escolha por argumento: `-- --menu-bg=a|b|hall`. A base cuida do caminhao e da camera orbital suave.

const DEFAULT_KIND: String = "a"

var truck: TruckNode
var cam: Camera3D
## Enquadramento atual: alvo, distancia, azimute/elevacao (graus) e deslocamento lateral (fracao da distancia;
## positivo = caminhao vai para a direita da tela, deixando a esquerda livre para o menu).
var _goal: Dictionary = {"target": Vector3(0, 1.6, -6.0), "dist": 15.0, "az": 36.0, "el": 6.0, "shift": 0.22}
var _cur: Dictionary = {}
var _t: float = 0.0


## Cria o fundo pedido por `--menu-bg=` (ou o padrao).
static func create() -> MenuBackdrop:
	var kind: String = DEFAULT_KIND
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--menu-bg="):
			kind = a.substr(10)
	match kind:
		"b":
			return MenuBgHighway.new()
		"hall":
			return MenuBgHall.new()
	return MenuBgRestStop.new()


func _ready() -> void:
	_build_scene()
	spawn_truck()
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	focus_hero()
	_cur = _goal.duplicate()
	_place_camera(0.0)


## Monta o cenario (subclasses).
func _build_scene() -> void:
	pass


## Cromo do caminhao nesta cena ("night" nas cenas de rua a noite).
func chrome_mode() -> String:
	return "night"


func spawn_truck() -> void:
	if truck != null:
		truck.queue_free()
	var prof: Dictionary = get_node("/root/GameState").profile
	truck = TruckNode.new()
	truck.body_kind = String(prof.get("body", "base"))
	truck.cab_kind = CabCatalog.normalize(prof.get("cab", ""))
	truck.chrome_mode = chrome_mode()
	add_child(truck)
	truck.set_lights_on(true)
	truck.set_headlights(true)
	truck.set_light_pattern(String(prof.get("light_pattern", "steady")))
	refresh_truck()


## Reaplica pecas, pintura, adesivos e estado das pecas do perfil.
func refresh_truck() -> void:
	var gs: Node = get_node("/root/GameState")
	truck.apply_loadout(gs.installed_part_defs())
	truck.set_paint_color(Color(String(gs.profile.get("paint", "#e9eef5"))))
	truck.apply_decals(gs.profile.get("decals", []) as Array)
	for d in gs.installed_part_defs():
		var own: Dictionary = gs.profile["owned"][String(d.id)]
		var st: String = "broken" if bool(own["broken"]) else ("dent" if d.durability > 0.0 and float(own["dur"]) < d.durability * 0.6 else "ok")
		truck.set_part_state(String(d.id), st)


func set_body(kind: String) -> void:
	get_node("/root/GameState").profile["body"] = kind
	spawn_truck()


## Vitrine da tela inicial: caminhao a direita (menu a esquerda).
func focus_hero() -> void:
	_goal = hero_frame()


## Painel grande aberto (mercado, opcoes): o caminhao fica centralizado e mais longe, atras do vidro.
func focus_default() -> void:
	var g: Dictionary = hero_frame()
	g["dist"] = float(g["dist"]) * 1.25
	g["shift"] = 0.0
	_goal = g


## Enquadramento de vitrine de cada cena (subclasses podem trocar).
func hero_frame() -> Dictionary:
	return {"target": Vector3(-0.6, 1.7, -6.4), "dist": 15.5, "az": 34.0, "el": 6.0, "shift": 0.2}


func _process(delta: float) -> void:
	_t += delta
	_place_camera(1.0 - exp(-3.0 * delta))
	_animate(delta)


## Animacao propria da cena (subclasses).
func _animate(_delta: float) -> void:
	pass


## Camera orbital: segue o enquadramento com suavidade e "respira" bem devagar (deriva de poucos graus).
func _place_camera(k: float) -> void:
	for key in _goal:
		if _cur.has(key) and _goal[key] is float:
			_cur[key] = lerpf(float(_cur[key]), float(_goal[key]), k)
		elif _cur.has(key) and _goal[key] is Vector3:
			_cur[key] = (_cur[key] as Vector3).lerp(_goal[key], k)
		else:
			_cur[key] = _goal[key]
	var len_d: float = float(TruckNode.LENGTH_DELTA.get(truck.body_kind, 0.0)) if truck != null else 0.0
	var tg: Vector3 = _cur["target"]
	tg.z -= len_d * 0.5
	var az: float = deg_to_rad(float(_cur["az"]) + sin(_t * 0.12) * 3.0)
	var el: float = deg_to_rad(float(_cur["el"]) + sin(_t * 0.09) * 0.8)
	var dir := Vector3(sin(az) * cos(el), sin(el), -cos(az) * cos(el))
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var aspect_k: float = clampf((16.0 / 9.0) / maxf(vs.x / maxf(vs.y, 1.0), 0.1), 0.8, 1.15)
	var reach: float = float(_cur["dist"]) * aspect_k * (1.0 + len_d * 0.04)
	cam.global_position = tg + dir * reach
	cam.look_at(tg, Vector3.UP)
	cam.global_position -= cam.global_transform.basis.x * (float(_cur["shift"]) * reach)


# ---------------------------------------------------------------- pecas simples (cenas leves)

## Caixa com material (sem colisao). `emit` > 0 = brilha (letreiros, lampadas).
static func box(parent: Node3D, size: Vector3, pos: Vector3, col: Color, emit: float = 0.0, rough: float = 0.6) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(col, emit, rough)
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func mat(col: Color, emit: float = 0.0, rough: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = emit
	return m


## Letreiro de neon (texto 3D que brilha). Fonte com japones (Noto Sans JP).
static func neon(parent: Node3D, text: String, pos: Vector3, col: Color, px: float = 0.02, size: int = 96, rot_y: float = 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = load("res://assets/fonts/NotoSansJP.ttf") as Font
	l.font_size = size
	l.pixel_size = px
	l.modulate = col * 2.4
	l.outline_size = 10
	l.outline_modulate = Color(col.r, col.g, col.b, 0.35)
	l.shaded = false
	l.double_sided = true
	l.position = pos
	l.rotation_degrees.y = rot_y
	parent.add_child(l)
	return l


static func omni(parent: Node3D, pos: Vector3, col: Color, energy: float, rng: float) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = col
	o.light_energy = energy
	o.omni_range = rng
	parent.add_child(o)
	return o
