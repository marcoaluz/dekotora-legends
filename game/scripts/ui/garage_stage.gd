class_name GarageStage
extends Node3D
## Palco 3D do menu e da garagem: plataforma com neon, caminhao com os acessorios instalados,
## camera que gira sozinha (ou pelo arraste do dedo/mouse). O destino da camera muda por foco (slot).

const HALL_PATH := "res://assets/scenery/garage_hall.glb"
const FOCUS: Dictionary = {   # alvo no mundo Godot (x, y, -z do Blender), distancia e azimute
	"default": {"target": Vector3(-3.5, 1.6, -6.0), "dist": 22.0, "az": 35.0, "el": 14.0},
	"front": {"target": Vector3(0, 1.4, -10.5), "dist": 9.0, "az": 25.0, "el": 10.0},
	"roof": {"target": Vector3(0, 3.0, -8.5), "dist": 13.0, "az": 35.0, "el": 18.0},
	"side": {"target": Vector3(1.2, 1.2, -6.0), "dist": 15.0, "az": 100.0, "el": 8.0},
	"rear": {"target": Vector3(0, 1.8, -0.5), "dist": 10.0, "az": 160.0, "el": 12.0},
	"wheel": {"target": Vector3(1.0, 0.7, -10.0), "dist": 8.0, "az": 100.0, "el": 6.0},
}
const SLOT_FOCUS: Dictionary = {
	"front_bumper": "front", "front_lip": "front", "grille": "front", "front_trim": "front", "front_ornament": "front",
	"aux_lights": "front", "visor": "front", "roof_lights": "roof", "roof_ornament": "roof", "roof_frame": "roof",
	"body_ornament": "roof", "andon": "roof", "side_skirts": "side", "fenders": "side", "steps": "side", "side_trim": "side",
	"side_box": "side", "side_ornament": "side", "mural": "side", "hubcaps": "wheel", "rear_bumper": "rear",
	"rear_lamps": "rear", "plate": "rear", "mudflaps": "rear", "rear_ornament": "rear",
}

var truck: TruckNode
var day: bool = false                # previa de dia (luz clara) ou noite (luzes do caminhao em destaque)
var _env: Environment
var _key: SpotLight3D
var _rim: OmniLight3D
var _fill: OmniLight3D
var cam: Camera3D
var auto_rotate: bool = true
var _az: float = 35.0
var _el: float = 14.0
var _dist: float = 22.0
var _target: Vector3 = Vector3(0, 1.6, -6.0)
var _goal: Dictionary = FOCUS["default"]
var _dragging: bool = false
var _shift: float = 0.0            # desloca o caminhao para a direita (fracao da distancia) ao liberar a tela
var _shift_goal: float = 0.0
var _zoom: float = 1.0
var _zoom_goal: float = 1.0


func _ready() -> void:
	WorldEnv.create(self, true)
	var hall: PackedScene = load(HALL_PATH) as PackedScene if ResourceLoader.exists(HALL_PATH) else null
	if hall != null:                                  # galpao industrial (blender/scripts/build_garage_env.py)
		add_child(hall.instantiate())
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


## Luz de estudio: principal fria de cima/frente (com sombra quando a qualidade permite), recorte rosa atras
## e preenchimento ciano do outro lado. Poucas luzes para caber no celular.
func _studio_lights() -> void:
	var q: int = int(get_node("/root/Settings").quality)
	var key := SpotLight3D.new()
	key.position = Vector3(9, 12, 4)
	key.look_at_from_position(key.position, Vector3(0, 1, -6), Vector3.UP)
	key.spot_range = 40.0
	key.spot_angle = 42.0
	key.light_energy = 5.0
	key.light_color = Color(1.0, 0.97, 0.92)
	key.shadow_enabled = q >= 1
	add_child(key)
	_key = key
	var rim := OmniLight3D.new()
	rim.position = Vector3(-6, 5, -16)
	rim.omni_range = 16.0
	rim.light_energy = 2.2
	rim.light_color = UiTheme.PINK
	add_child(rim)
	_rim = rim
	var fill := OmniLight3D.new()
	fill.position = Vector3(-9, 4, 3)
	fill.omni_range = 18.0
	fill.light_energy = 1.0
	fill.light_color = Color("#9fd8ff")
	add_child(fill)
	_fill = fill


func _spawn_truck() -> void:
	truck = TruckNode.new()
	var prof: Dictionary = get_node("/root/GameState").profile
	truck.body_kind = String(prof.get("body", "base"))
	truck.cab_kind = String(prof.get("cab", "padrao"))
	truck.chrome_mode = "day" if day else "night"
	add_child(truck)
	truck.set_lights_on(true, day)
	truck.set_light_pattern(String(prof.get("light_pattern", "steady")))


## Previa dia/noite: luz do galpao, cromo (matcap dia/noite) e luzes do caminhao. De dia as luzinhas ficam
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
		_key.light_color = Color(1.0, 0.98, 0.9) if on else Color(1.0, 0.97, 0.92)
	if _rim != null:
		_rim.light_energy = 0.8 if on else 2.2
	if _fill != null:
		_fill.light_energy = 1.8 if on else 1.0
	_respawn()


## Troca a carroceria do caminhao mostrado (recria o no e reaplica pecas e tinta).
func set_body(kind: String) -> void:
	get_node("/root/GameState").profile["body"] = kind
	_respawn()


## Troca a cabine do caminhao mostrado.
func set_cab(kind: String) -> void:
	get_node("/root/GameState").profile["cab"] = kind
	_respawn()


func _respawn() -> void:
	if truck != null:
		truck.queue_free()
	_spawn_truck()
	refresh_truck()


func refresh_truck() -> void:
	var gs: Node = get_node("/root/GameState")
	truck.apply_loadout(gs.installed_part_defs())
	var col: Color = Color(String(gs.profile.get("paint", "#e9eef5")))
	truck.set_paint_color(col)
	truck.apply_decals(gs.profile.get("decals", []) as Array)
	# pecas quebradas/amassadas do perfil
	for d in gs.installed_part_defs():
		var own: Dictionary = gs.profile["owned"][String(d.id)]
		var st: String = "broken" if bool(own["broken"]) else ("dent" if d.durability > 0.0 and float(own["dur"]) < d.durability * 0.6 else "ok")
		truck.set_part_state(String(d.id), st)


func focus_slot(slot: String) -> void:
	var key: String = String(SLOT_FOCUS.get(slot, "default"))
	_goal = FOCUS[key]
	auto_rotate = false


## Vista pedida pelos botoes da garagem: "default", "front", "side", "rear", "roof" ou "wheel".
func focus_view(view: String) -> void:
	_goal = FOCUS.get(view, FOCUS["default"])
	auto_rotate = view == "default"


## Layout da garagem: com os dois paineis abertos sobra so o terco central; com um so, desloca o caminhao.
func set_layout(right_panel_open: bool) -> void:
	_shift_goal = 0.0 if right_panel_open else 0.2
	_zoom_goal = 1.5 if right_panel_open else 1.15


## Aproximacao fixa da camera (1.0 = normal; menor = mais perto). Usada nas capturas de depuracao.
func set_zoom(z: float) -> void:
	_zoom_goal = clampf(z, 0.2, 3.0)


## Enquadramento de vitrine da tela inicial: 3/4 frontal baixo, caminhao deslocado para a direita
## (o menu fica a esquerda), girando bem devagar.
func focus_hero() -> void:
	_goal = {"target": Vector3(-1.0, 1.6, -6.8), "dist": 15.5, "az": 36.0, "el": 5.0}
	_shift_goal = 0.22
	_zoom_goal = 1.0
	auto_rotate = false


func focus_default() -> void:
	_goal = FOCUS["default"]
	auto_rotate = true


func _apply_goal(snap: bool = false) -> void:
	if snap:
		_target = _goal["target"]
		_dist = float(_goal["dist"])
		_az = float(_goal["az"])
		_el = float(_goal["el"])


func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-4.0 * delta)
	_target = _target.lerp(_goal["target"], k)
	_dist = lerpf(_dist, float(_goal["dist"]), k)
	if auto_rotate and not _dragging:
		_az += delta * 12.0
	elif not _dragging:
		_az = lerpf(_az, float(_goal["az"]), k * 0.6)
	if not _dragging:
		_el = lerpf(_el, float(_goal["el"]), k * 0.6)
	var a: float = deg_to_rad(_az)
	var e: float = deg_to_rad(_el)
	var dir := Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
	_shift = lerpf(_shift, _shift_goal, k)
	_zoom = lerpf(_zoom, _zoom_goal, k)
	# modelos mais longos/curtos: recua a camera e acompanha o centro (partes da frente andam junto com o comprimento)
	var len_d: float = float(TruckNode.LENGTH_DELTA.get(truck.body_kind, 0.0))
	var tg: Vector3 = _target
	tg.z -= len_d * clampf(-_target.z / 11.5, 0.0, 1.0)
	var reach: float = _dist * _zoom * (1.0 + len_d * 0.04)
	cam.global_position = tg + dir * reach
	cam.look_at(tg, Vector3.UP)
	cam.global_position -= cam.global_transform.basis.x * (_shift * reach)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventScreenTouch:
		_dragging = event.pressed
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_goal = clampf(_zoom_goal * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 0.6, 2.0)
	elif event is InputEventMouseMotion and _dragging:
		_az -= event.relative.x * 0.4
		_el = clampf(_el + event.relative.y * 0.3, -2.0, 70.0)
	elif event is InputEventScreenDrag and _dragging:
		_az -= event.relative.x * 0.4
		_el = clampf(_el + event.relative.y * 0.3, -2.0, 70.0)
