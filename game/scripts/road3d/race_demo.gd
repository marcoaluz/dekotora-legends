class_name RaceDemo
extends RefCounted
## Ferramenta de depuracao das capturas (nao entra no jogo normal). Argumentos depois de `--`:
##   --demo=lanes   o jogador toca a seta/troca sozinho (direita, direita, esquerda, esquerda...)
##   --demo=close   o rival comeca ao lado do jogador na faixa da direita; o jogador tenta ir para la
##   --shots=PASTA  salva PNGs (troca de faixa e batida lateral) na PASTA
## Exemplo: godot --path game res://scenes/race/race3d.tscn -- --demo=close --shots=C:/tmp/capt

var mode: String = ""
var shot_dir: String = ""
var _taps: Array = []                  # [tempo da corrida (s), direcao]
var _queue: Array = []                 # [tempo real (s) para tirar, nome]
var _clock: float = 0.0
var _last_lane_changes: int = 0
var _last_close: float = -99.0
var _count: Dictionary = {}


func _init(args: PackedStringArray) -> void:
	for a in args:
		if a.begins_with("--demo="):
			mode = a.substr(7)
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
	if mode == "lanes":
		_taps = [[1.0, 1], [1.5, 1], [5.0, -1], [5.5, -1], [9.0, 1], [9.5, 1]]
	elif mode == "close":
		_taps = [[1.0, 1], [1.5, 1], [4.0, 1], [4.5, 1], [7.0, 1], [7.5, 1]]
	if shot_dir != "":
		DirAccess.make_dir_recursive_absolute(shot_dir)


## `--contract=ceramica`: contrato de teste com esse tipo de carga (para ver o aviso, o prazo e a perda de carga sem passar pelo Mercado).
static func fake_contract(args: PackedStringArray, route: RouteDef) -> Dictionary:
	for a in args:
		if a.begins_with("--contract="):
			var path: String = "res://data/cargo/%s.tres" % a.substr(11)
			if not ResourceLoader.exists(path) or route == null:
				return {}
			var c: CargoDef = load(path) as CargoDef
			var perishable: bool = c.trait_kind == &"perishable"
			return {"id": "demo", "route": String(route.id), "origin": "Origem", "destination": "Destino", "cargo": String(c.id),
				"weight_t": (c.weight_min_t + c.weight_max_t) * 0.5, "reward": Contracts.reward(route, c, (c.weight_min_t + c.weight_max_t) * 0.5),
				"fragility": c.fragility, "trait": String(c.trait_kind),
				"deadline_s": roundf(route.deadline() * (Contracts.PERISHABLE_DEADLINE if perishable else 1.0))}
	return {}


func active() -> bool:
	return mode != ""


## Prepara o grid: no modo "close" o rival (indice 1) comeca ao lado do jogador, na faixa da direita.
func setup(sim: RaceSim) -> void:
	if mode == "close" and sim.trucks.size() > 1:
		var r: TruckSim = sim.trucks[1]
		r.z = sim.trucks[0].z - 2.0
		r.lane = Lanes.LAST
		r.x = Lanes.X[Lanes.LAST]


## Comando do jogador no modo demo: acelera e toca as setas nos instantes combinados.
func command(race_time: float) -> Commands:
	var steer: float = 0.0
	for tap in _taps:
		if race_time >= float(tap[0]) and race_time < float(tap[0]) + 0.12:
			steer = float(tap[1])
	return Commands.make(steer, 0.85, 0.0)


func on_event(e: Dictionary, player: int, race_time: float) -> void:
	if shot_dir == "" or String(e["type"]) != "truck":
		return
	if int(e["a"]) != player and int(e["b"]) != player:
		return
	if race_time - _last_close < 3.0:
		return
	_last_close = race_time
	_queue.append([_clock + 0.05, "fechamento_a"])
	_queue.append([_clock + 0.5, "fechamento_b"])


## Chame todo quadro (depois de avancar a simulacao).
func update(viewport: Viewport, player_truck: TruckSim, dt: float) -> void:
	_clock += dt
	if shot_dir == "":
		return
	if _clock > 1.5 and not _count.has("largada"):
		_save(viewport, "largada")                # contagem regressiva: mostra o aviso da carga
	if player_truck.lane_changes != _last_lane_changes:
		_last_lane_changes = player_truck.lane_changes
		_queue.append([_clock + 0.05, "troca_a"])
		_queue.append([_clock + 0.35, "troca_b"])
		_queue.append([_clock + 0.65, "troca_c"])
	if player_truck.signal_dir != 0 and not _count.has("seta_%d" % _last_lane_changes):
		_count["seta_%d" % _last_lane_changes] = true
		_queue.append([_clock + 0.1, "seta"])
	var keep: Array = []
	for q in _queue:
		if _clock >= float(q[0]):
			_save(viewport, String(q[1]))
		else:
			keep.append(q)
	_queue = keep


## Captura avulsa (ex.: tela de pausa).
func snap(viewport: Viewport, name: String) -> void:
	if shot_dir != "":
		_save(viewport, name)


func _save(viewport: Viewport, name: String) -> void:
	var n: int = int(_count.get(name, 0)) + 1
	_count[name] = n
	if n > 3:
		return
	await RenderingServer.frame_post_draw
	var img: Image = viewport.get_texture().get_image()
	var path: String = "%s/%s_%d.png" % [shot_dir, name, n]
	img.save_png(path)
	print("CAPTURA: ", path)
