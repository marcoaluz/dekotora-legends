class_name GarageStage
extends Node3D
## Palco 3D do menu e da garagem: plataforma com neon, caminhao com os acessorios instalados,
## camera que gira sozinha (ou pelo arraste do dedo/mouse). O destino da camera muda por foco (slot).
## T-138: camera mais perto (caminhao ~60% da largura da tela), cromo neutro de estudio (sem o azul da noite)
## e rodas paradas ate o jogador pedir "Ver em movimento" (botao, toque na roda ou roda nova instalada).

const HALL_PATH := "res://assets/scenery/garage_hall.glb"
const FOCUS: Dictionary = {   # alvo no mundo Godot (x, y, -z do Blender), distancia e azimute
	"default": {"target": Vector3(0.0, 1.8, -6.2), "dist": 18.0, "az": 38.0, "el": 10.0},   # antes 22 x zoom 1,5 (= 33)
	"front": {"target": Vector3(0, 1.6, -10.5), "dist": 9.5, "az": 28.0, "el": 9.0},
	"roof": {"target": Vector3(0, 3.0, -8.5), "dist": 12.0, "az": 35.0, "el": 18.0},
	"side": {"target": Vector3(0.6, 1.5, -6.0), "dist": 15.5, "az": 95.0, "el": 7.0},
	"rear": {"target": Vector3(0, 1.8, -0.8), "dist": 10.0, "az": 158.0, "el": 11.0},
	"wheel": {"target": Vector3(1.0, 0.8, -9.6), "dist": 7.0, "az": 100.0, "el": 5.0},
}
const SLOT_FOCUS: Dictionary = {
	"front_bumper": "front", "front_lip": "front", "grille": "front", "front_trim": "front", "front_ornament": "front",
	"aux_lights": "front", "visor": "front", "roof_lights": "roof", "roof_ornament": "roof", "roof_frame": "roof", "roof_wing": "roof",
	"exhaust_stacks": "side", "underglow": "side",
	"body_ornament": "roof", "andon": "roof", "side_skirts": "side", "fenders": "side", "steps": "side", "side_trim": "side",
	"side_box": "side", "side_ornament": "side", "mural": "side", "hubcaps": "wheel", "rear_bumper": "rear",
	"rear_lamps": "rear", "plate": "rear", "mudflaps": "rear", "rear_ornament": "rear",
}
## Velocidade de mentira das rodas em "Ver em movimento" (m/s; ~1 volta a cada 3 s).
const WHEEL_VIEW_SPEED: float = 1.0
## Proporcao de referencia (16:9). Tela mais comprida (celular 20:9) aproxima um pouco para o caminhao
## continuar ocupando a mesma fracao da largura.
const REF_ASPECT: float = 16.0 / 9.0
## Malha do galpao onde o caminhao fica (plataforma giratoria, 10 cm acima do piso; T-171).
const PLATFORM_MESH: String = "turntable"
## Topo da plataforma se o galpao nao tiver a malha (m).
const PLATFORM_TOP_FALLBACK: float = 0.1

signal wheel_spin_changed(on: bool)

var truck: TruckNode
var day: bool = false                # previa de dia (luz clara) ou noite (luzes do caminhao em destaque)
## Cromo do palco: "studio" (garagem, neutro). A previa de dia usa o cromo "day" (como na corrida de dia).
const INERTIA_TIME: float = 0.3     # s: constante de tempo da inercia depois de soltar
const MAX_SPIN: float = 400.0       # graus/s maximos de inercia
const EL_MIN: float = -2.0
const EL_MAX: float = 70.0
const ZOOM_MIN: float = 0.5
const ZOOM_MAX: float = 2.0
var chrome: String = "studio"
var _env: Environment
var _key: SpotLight3D
var _rim: OmniLight3D
var _fill: OmniLight3D
var cam: Camera3D
var _az: float = 38.0
var _el: float = 11.0
var _dist: float = 17.0
var _target: Vector3 = Vector3(0, 1.7, -6.2)
var _goal: Dictionary = FOCUS["default"]
var _dragging: bool = false
var _seek: bool = false            # true so enquanto vai ao angulo de uma vista recem-escolhida
var _az_vel: float = 0.0           # inercia do arrasto (graus/s); morre em ~0,3 s
var _el_vel: float = 0.0
var _touches: Dictionary = {}      # indice do dedo -> posicao (pinca)
var _pinch_dist: float = 0.0
var _press_pos: Vector2 = Vector2.ZERO
var _moved: float = 0.0
var _shift: float = 0.0            # desloca o caminhao para a direita (fracao da distancia) ao liberar a tela
var _shift_goal: float = 0.0
var _zoom: float = 1.0
var _zoom_goal: float = 1.0
## Vista atual ("default", "front", "side", "rear", "roof", "wheel", "hero").
var view: String = "default"
## Rodas girando ("Ver em movimento"). Desliga ao trocar de vista.
var wheel_spin: bool = false
## Previa da garagem (T-171): peca/cor temporaria mostrada no caminhao sem mexer no perfil. null = sem previa.
var preview: GaragePreview
## Altura (m) do que o caminhao pisa: topo da plataforma giratoria do galpao (0 sem galpao). T-171: antes o
## caminhao nascia em y = 0 (piso) e os pneus afundavam 10 cm dentro da plataforma.
var floor_y: float = 0.0
static var _wheel_bottom_cache: Dictionary = {}     # caminho do .glb -> ponto mais baixo dos pneus (m)


func _ready() -> void:
	WorldEnv.create(self, true)
	var hall: PackedScene = load(HALL_PATH) as PackedScene if ResourceLoader.exists(HALL_PATH) else null
	if hall != null:                                  # galpao industrial (blender/scripts/build_garage_env.py)
		var h: Node3D = hall.instantiate() as Node3D
		add_child(h)
		floor_y = platform_top(h)
	for n in get_children():
		if n is WorldEnvironment:
			_env = (n as WorldEnvironment).environment
	_studio_lights()
	_spawn_truck()
	cam = Camera3D.new()
	cam.fov = 42.0
	add_child(cam)
	cam.make_current()
	_apply_goal(true)
	refresh_truck()


## Luz de estudio: principal branca de cima/frente (com sombra quando a qualidade permite), recorte rosa atras
## (o neon do galpao) e preenchimento branco quente do outro lado. Poucas luzes para caber no celular.
func _studio_lights() -> void:
	var q: int = int(get_node("/root/Settings").quality)
	var key := SpotLight3D.new()
	key.position = Vector3(9, 12, 4)
	key.look_at_from_position(key.position, Vector3(0, 1, -6), Vector3.UP)
	key.spot_range = 40.0
	key.spot_angle = 42.0
	key.light_energy = 5.0
	key.light_color = Color(1.0, 0.98, 0.95)
	key.shadow_enabled = q >= 1
	add_child(key)
	_key = key
	var rim := OmniLight3D.new()
	rim.position = Vector3(-6, 5, -16)
	rim.omni_range = 16.0
	rim.light_energy = 1.5
	rim.light_color = UiTheme.PINK
	add_child(rim)
	_rim = rim
	var fill := OmniLight3D.new()
	fill.position = Vector3(-9, 4, 3)
	fill.omni_range = 18.0
	fill.light_energy = 1.1
	fill.light_color = Color("#fff1e2")              # antes ciano (#9fd8ff): deixava o cromo azulado
	add_child(fill)
	_fill = fill


func _spawn_truck() -> void:
	truck = TruckNode.new()
	var prof: Dictionary = get_node("/root/GameState").profile
	truck.body_kind = String(prof.get("body", "base"))
	truck.cab_kind = CabCatalog.normalize(prof.get("cab", ""))
	truck.chrome_mode = "day" if day else chrome
	add_child(truck)
	truck.position.y = floor_y - wheel_bottom(truck)   # pneus apoiados SOBRE a plataforma (T-171)
	truck.set_lights_on(true, day)
	truck.set_light_pattern(String(prof.get("light_pattern", "steady")))


## Previa dia/noite: luz do galpao, cromo (matcap dia/estudio) e luzes do caminhao. De dia as luzinhas ficam
## acesas mas fracas; a noite brilham com o padrao escolhido.
func set_daytime(on: bool) -> void:
	day = on
	if _env != null:
		_env.background_color = Color("#bcd5ee") if on else Color("#07080d")
		_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if on else Environment.AMBIENT_SOURCE_SKY
		_env.ambient_light_color = Color(0.85, 0.9, 1.0)
		_env.ambient_light_energy = 1.0 if on else 0.45
	if _key != null:
		_key.light_energy = 8.5 if on else 5.0
	if _rim != null:
		_rim.light_energy = 0.8 if on else 1.5
	if _fill != null:
		_fill.light_energy = 1.8 if on else 1.1
	_respawn()


## Troca a carroceria do caminhao mostrado (recria o no e reaplica pecas e tinta).
func set_body(kind: String) -> void:
	get_node("/root/GameState").profile["body"] = kind
	_respawn()


## Troca a cabine do caminhao mostrado.
func set_cab(kind: String) -> void:
	get_node("/root/GameState").profile["cab"] = CabCatalog.normalize(kind)
	_respawn()


func _respawn() -> void:
	if truck != null:
		truck.queue_free()
	_spawn_truck()
	refresh_truck()


## Topo da plataforma giratoria do galpao `hall` (m). Sem a malha, PLATFORM_TOP_FALLBACK.
static func platform_top(hall: Node) -> float:
	var top: float = TruckGround.top_of(hall, PLATFORM_MESH)
	return top if top > -INF else PLATFORM_TOP_FALLBACK


## Ponto mais baixo dos pneus do caminhao (m, no espaco dele; os .glb atuais dao 0). Medido uma vez por modelo.
static func wheel_bottom(t: TruckNode) -> float:
	if t == null or t.model == null:
		return 0.0
	var key: String = TruckNode.model_path(t.body_kind, t.cab_kind)
	if not _wheel_bottom_cache.has(key):
		_wheel_bottom_cache[key] = TruckGround.wheel_bottom(t.model)
	return float(_wheel_bottom_cache[key])


## Monta o caminhao como esta no perfil; com previa ativa, com a peca/cor da previa (o perfil nao muda).
func refresh_truck() -> void:
	var gs: Node = get_node("/root/GameState")
	var shown: Array[PartDef] = preview.loadout(gs) if preview != null else gs.installed_part_defs()
	truck.apply_loadout(shown)
	var col: Color = preview.paint(gs) if preview != null else Color(String(gs.profile.get("paint", "#e9eef5")))
	truck.set_paint_color(col)
	truck.apply_decals(gs.profile.get("decals", []) as Array)
	# pecas quebradas/amassadas do perfil (a peca da previa ainda nao comprada aparece nova)
	for d in shown:
		if not (gs.profile["owned"] as Dictionary).has(String(d.id)):
			continue
		var own: Dictionary = gs.profile["owned"][String(d.id)]
		var st: String = "broken" if bool(own["broken"]) else ("dent" if d.durability > 0.0 and float(own["dur"]) < d.durability * 0.6 else "ok")
		truck.set_part_state(String(d.id), st)


func focus_slot(slot: String) -> void:
	var key: String = String(SLOT_FOCUS.get(slot, "default"))
	_goal = FOCUS[key]
	_set_view(key)


## Vista pedida pelos botoes da garagem: "default", "front", "side", "rear", "roof" ou "wheel".
func focus_view(v: String) -> void:
	_goal = FOCUS.get(v, FOCUS["default"])
	_set_view(v if FOCUS.has(v) else "default")


## Layout da garagem: os paineis laterais sao de vidro; o caminhao fica no centro, grande (~60% da largura).
func set_layout(right_panel_open: bool) -> void:
	_shift_goal = 0.0 if right_panel_open else 0.12
	_zoom_goal = 1.0


## Aproximacao fixa da camera (1.0 = normal; menor = mais perto). Usada nas capturas de depuracao.
func set_zoom(z: float) -> void:
	_zoom_goal = clampf(z, 0.2, 3.0)


## Enquadramento de vitrine da tela inicial: 3/4 frontal baixo, caminhao deslocado para a direita
## (o menu fica a esquerda), girando bem devagar.
func focus_hero(shift: float = 0.22, dist: float = 15.5) -> void:
	_goal = {"target": Vector3(-1.0, 1.6, -6.8), "dist": dist, "az": 36.0, "el": 5.0}
	_shift_goal = shift
	_zoom_goal = 1.0
	_set_view("hero")


func focus_default() -> void:
	_goal = FOCUS["default"]
	_set_view("default")


## Troca de vista: desliga o giro das rodas (o jogador liga de novo se quiser).
func _set_view(v: String) -> void:
	_seek = true
	if v != view:
		set_wheel_spin(false)
	view = v


## Liga/desliga o giro das rodas ("Ver em movimento").
func set_wheel_spin(on: bool) -> void:
	if on == wheel_spin:
		return
	wheel_spin = on
	wheel_spin_changed.emit(on)


func toggle_wheel_spin() -> void:
	set_wheel_spin(not wheel_spin)


func _apply_goal(snap: bool = false) -> void:
	if snap:
		_target = _goal["target"]
		_dist = float(_goal["dist"])
		_az = float(_goal["az"])
		_el = float(_goal["el"])


## Rodas (e calotas/rodas da loja) girando devagar so com "Ver em movimento" ligado (sem custo parado).
func spin_wheels(delta: float) -> void:
	if wheel_spin and truck != null:
		truck.animate(WHEEL_VIEW_SPEED, delta)


## true se o ponto da tela (coordenadas da viewport) cai sobre uma roda do caminhao.
func wheel_at(screen_pos: Vector2) -> bool:
	if truck == null or cam == null or not cam.is_inside_tree():
		return false
	var w: TruckWheels = truck.wheels
	for i in w.wheels.size():
		var n: Node3D = w.wheels[i]
		if not is_instance_valid(n) or not n.is_inside_tree() or cam.is_position_behind(n.global_position):
			continue
		var c: Vector2 = cam.unproject_position(n.global_position)
		var edge: Vector2 = cam.unproject_position(n.global_position + cam.global_transform.basis.y * w.radii[i])
		if c.distance_to(screen_pos) <= maxf(c.distance_to(edge) * 1.25, 14.0):
			return true
	return false


func _process(delta: float) -> void:
	spin_wheels(delta)
	var k: float = 1.0 - exp(-4.0 * delta)
	_target = _target.lerp(_goal["target"], k)
	_dist = lerpf(_dist, float(_goal["dist"]), k)
	if not _dragging:
		# inercia curta do arrasto; depois disso a camera so vai ao angulo da vista (nunca gira sozinha)
		var decay: float = exp(-delta / INERTIA_TIME)
		_az_vel *= decay
		_el_vel *= decay
		if absf(_az_vel) < 4.0:
			_az_vel = 0.0
		if absf(_el_vel) < 4.0:
			_el_vel = 0.0
		_az += _az_vel * delta
		_el = clampf(_el + _el_vel * delta, EL_MIN, EL_MAX)
		if _seek and _az_vel == 0.0 and _el_vel == 0.0:
			_az = lerpf(_az, float(_goal["az"]), k * 0.6)
			_el = lerpf(_el, float(_goal["el"]), k * 0.6)
			if absf(_az - float(_goal["az"])) < 0.05 and absf(_el - float(_goal["el"])) < 0.05:
				_seek = false
	var a: float = deg_to_rad(_az)
	var e: float = deg_to_rad(_el)
	var dir := Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
	_shift = lerpf(_shift, _shift_goal, k)
	_zoom = lerpf(_zoom, _zoom_goal, k)
	# modelos mais longos/curtos: recua a camera e acompanha o centro (partes da frente andam junto com o comprimento)
	var len_d: float = float(TruckNode.LENGTH_DELTA.get(truck.body_kind, 0.0))
	var tg: Vector3 = _target
	tg.z -= len_d * clampf(-_target.z / 11.5, 0.0, 1.0)
	var vs: Vector2 = get_viewport().get_visible_rect().size
	var aspect_k: float = clampf(REF_ASPECT / maxf(vs.x / maxf(vs.y, 1.0), 0.1), 0.8, 1.15)
	var reach: float = _dist * _zoom * aspect_k * (1.0 + len_d * 0.04)
	cam.global_position = tg + dir * reach
	cam.look_at(tg, Vector3.UP)
	cam.global_position -= cam.global_transform.basis.x * (_shift * reach)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_press(event.pressed, event.position)
	elif event is InputEventScreenTouch:
		_touch(event)
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_goal = clampf(_zoom_goal * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), ZOOM_MIN, ZOOM_MAX)
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2:
			_pinch_update()
		elif _dragging:
			_rotate(event.relative, event.velocity)
	elif event is InputEventMouseMotion and _dragging:
		_rotate(event.relative, event.velocity)


func _rotate(rel: Vector2, vel: Vector2) -> void:
	_moved += rel.length()
	_az -= rel.x * 0.4
	_el = clampf(_el + rel.y * 0.3, EL_MIN, EL_MAX)
	_az_vel = clampf(-vel.x * 0.4, -MAX_SPIN, MAX_SPIN)
	_el_vel = clampf(vel.y * 0.3, -MAX_SPIN, MAX_SPIN)


func _touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touches[event.index] = event.position
	else:
		_touches.erase(event.index)
	_pinch_dist = 0.0
	if _touches.size() >= 2:
		_dragging = false
		_az_vel = 0.0
		_el_vel = 0.0
		_pinch_dist = _pinch_span()
	elif not event.pressed and _touches.size() == 1:
		_dragging = false      # sobrou um dedo depois da pinca: so volta a girar num novo toque
	else:
		_press(event.pressed, event.position)


func _pinch_span() -> float:
	var pts: Array = _touches.values()
	return (pts[0] as Vector2).distance_to(pts[1] as Vector2)


func _pinch_update() -> void:
	var d: float = _pinch_span()
	if _pinch_dist > 1.0 and d > 1.0:
		_zoom_goal = clampf(_zoom_goal * _pinch_dist / d, ZOOM_MIN, ZOOM_MAX)
	_pinch_dist = d


## Arrastar gira a camera; um toque curto (sem arrastar) sobre uma roda liga/desliga o giro dela.
func _press(pressed: bool, pos: Vector2) -> void:
	_dragging = pressed
	if pressed:
		_seek = false
		_az_vel = 0.0
		_el_vel = 0.0
		_press_pos = pos
		_moved = 0.0
	elif _moved < 10.0 and wheel_at(pos):
		toggle_wheel_spin()
