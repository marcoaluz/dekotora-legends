class_name RaceDemo
extends RefCounted
## Ferramenta de depuracao das capturas (nao entra no jogo normal). Argumentos depois de `--`:
##   --demo=lanes   o jogador toca a seta/troca sozinho (direita, direita, esquerda, esquerda...)
##   --demo=close   o rival comeca ao lado do jogador na faixa da direita; o jogador tenta ir para la
##   --shots=PASTA  salva PNGs (troca de faixa e batida lateral) na PASTA
##   --cam=DZ,LAT,H,LDZ,LLAT,LH camera fixa relativa ao jogador (m): posicao (z a frente, lateral, altura) e alvo
##   --cam=top|high|side camera presa ao caminhao do jogador: de cima (30 m), bem alta (75 m) ou alta de lado (T-132)
##   --nohud        esconde o HUD e os botoes (capturas limpas; lido pela RaceScene3D)
##   --snap-every=S com --shots: tambem uma captura a cada S segundos (t01, t02...; placas e sinalizacao, T-130)
##   --burst=S      com --shots: aos S segundos, 2 capturas em quadros SEGUIDOS (roda_1, roda_2; rodas girando, T-133)
## Exemplo: godot --path game res://scenes/race/race3d.tscn -- --demo=close --shots=C:/tmp/capt

var mode: String = ""
var shot_dir: String = ""
var _taps: Array = []                  # [tempo da corrida (s), direcao]
var _queue: Array = []                 # [tempo real (s) para tirar, nome]
var _clock: float = 0.0
var _last_lane_changes: int = 0
var _last_close: float = -99.0
var _count: Dictionary = {}
var _cam: PackedFloat32Array = []
var cam_mode: String = ""              # top | high | side (T-132)
var _snap_every: float = 0.0
var _next_snap: float = 0.0
var _burst_at: float = -1.0
var _burst_left: int = 2


func _init(args: PackedStringArray) -> void:
	for a in args:
		if a.begins_with("--demo="):
			mode = a.substr(7)
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a.begins_with("--cam="):
			if a.substr(6) in ["top", "high", "side"]:
				cam_mode = a.substr(6)
			else:
				for v in a.substr(6).split(","):
					_cam.append(float(v))
		elif a.begins_with("--snap-every="):
			_snap_every = float(a.substr(13))
			_next_snap = _snap_every
		elif a.begins_with("--burst="):
			_burst_at = float(a.substr(8))
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


## `--decorated`: perfil de demonstracao (caminhao cheio de pecas, pintura, adesivos e luzes) gravado em
## user://demo_profile.json, nunca no perfil real. Chamar antes de montar a corrida.
## `--decorated --noparts`: o mesmo perfil de teste, mas so o caminhao de fabrica (aceita --body= e --cab=).
static func decorate_profile(gs: Node, args: PackedStringArray) -> void:
	if not ("--decorated" in args):
		return
	gs.save_path = "user://demo_profile.json"
	gs.new_profile()
	gs.profile["money"] = 900000
	gs.profile["fame"] = 500
	if "--noparts" in args:                          # caminhao de fabrica, branco e sem adesivos (comparar o bau, T-136)
		for a in args:
			if a.begins_with("--body="):
				gs.profile["body"] = a.substr(7)
			elif a.begins_with("--cab="):
				gs.profile["cab"] = CabCatalog.normalize(a.substr(6))
		return
	for id in ["fb_gold_wing", "visor_gold_lights", "roof_lights_crown", "skirt_light_bar", "andon_kanji", "rb_chrome", "mural_lightning",
			"hub_gold", "grille_frame_chrome", "aux_round_lamps_pair", "front_crest_ornament", "roof_torii_ornament", "rear_lamp_cluster"]:
		var d: PartDef = gs.part(id)
		if d != null and gs.buy(d):
			gs.install(id)
	gs.profile["paint"] = "#ff2e88"
	gs.profile["light_pattern"] = "sequential"
	for a in args:                                   # --cab=chata / --body=leve / --parts=...: so no perfil demo
		if a.begins_with("--cab="):
			gs.profile["cab"] = CabCatalog.normalize(a.substr(6))
		elif a.begins_with("--body="):
			gs.profile["body"] = a.substr(7)
		elif a.begins_with("--parts="):                  # --parts=kw_bumper,fumi_wing: pecas a mais (medir custo, T-126)
			for pid in a.substr(8).split(","):
				var pd: PartDef = gs.part(pid)
				if pd != null and gs.buy(pd):
					gs.install(pid)
	gs.profile["decals"] = [
		{"id": "kanji_bakusou", "slot": "side_l", "x": -0.55, "y": 0.0, "size": 0.45, "color": "#f5cc5a"},
		{"id": "estrela", "slot": "side_r", "x": -0.55, "y": 0.0, "size": 0.4, "color": "#21e6ff"},
		{"id": "raio", "slot": "rear", "x": 0.0, "y": 0.0, "size": 0.7, "color": "#21e6ff"},
		{"id": "sol", "slot": "cab", "x": 0.0, "y": 0.1, "size": 0.5, "color": "#ffffff"}]


## Camera de depuracao (--cam=...): devolve true se assumiu a camera neste quadro.
func camera(cam: Camera3D, path: TrackPath, z: float, x: float = 0.0, length: float = Collision.LEN) -> bool:
	if cam_mode != "":
		_place_camera(cam, path, z, x, length)
		return true
	if _cam.size() < 6:
		return false
	var w: float = Track.ROAD_HALF_WIDTH_M
	cam.global_position = path.world_point(z + _cam[0], _cam[1] / w, _cam[2])
	cam.look_at(path.world_point(z + _cam[3], _cam[4] / w, _cam[5]), Vector3.UP)
	return true


## --cam=top|high|side: camera presa ao caminhao em (z, x), olhando o meio dele (alinhamento na faixa, T-132).
func _place_camera(cam: Camera3D, path: TrackPath, z: float, x: float, length: float) -> void:
	var mid: float = z + length * 0.5
	if cam_mode == "side":
		cam.global_position = path.world_point(mid - 4.0, x - 2.6, 11.0)
		cam.look_at(path.world_point(mid, x, 1.0), Vector3.UP)
		return
	var ahead: float = 0.0 if cam_mode == "top" else 30.0
	cam.global_position = path.world_point(mid + ahead, x, 30.0 if cam_mode == "top" else 75.0)
	cam.look_at(path.world_point(mid + ahead, x, 1.0), path.forward_at(mid + ahead))   # frente da pista para cima


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
	if shot_dir != "" and String(e["type"]) == "finish" and int(e["truck"]) == player:
		_queue.append([_clock + 0.9, "chegada"])
		return
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
	if _snap_every > 0.0 and _clock >= _next_snap:
		_save(viewport, "t%02d" % roundi(_next_snap / _snap_every))
		_next_snap += _snap_every
	if _burst_at >= 0.0 and _clock >= _burst_at and _burst_left > 0:
		_burst_left -= 1                              # um por quadro: roda_1 e roda_2 sao quadros seguidos
		_save(viewport, "roda")
		print("RODA: velocidade %.1f m/s, dt %.4f s" % [player_truck.speed, dt])
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


## Agenda uma captura daqui a `delay` s (tempo real).
func queue_shot(name: String, delay: float) -> void:
	if shot_dir != "":
		_queue.append([_clock + delay, name])


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
