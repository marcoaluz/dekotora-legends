class_name Room
extends RefCounted
## Uma sala multiplayer: jogadores, regras, lobby e a corrida autoritativa. Nao conhece a rede:
## o servidor (server_main.gd) entrega comandos e le snapshots/eventos. Isso permite testar tudo
## sem abrir portas (tests/test_net_room.gd).

const GRID_X: Array[float] = [0.0, -0.5, 0.5, 0.0]   # faixas do grid (centro, esq., dir., centro); posicoes: StartGrid
const GRID_GAP: float = 14.0                         # (antes da T-156: um atras do outro; agora lado a lado, StartGrid)
const END_AFTER_FIRST_FINISH: float = 30.0     # s para os outros chegarem depois do primeiro humano


class Member:
	extends RefCounted
	var peer_id: int = 0
	var name: String = ""
	var player_code: String = ""
	var ready: bool = false
	var loadout: Dictionary = {}                # descritor (TruckConfig)
	var truck_idx: int = -1
	var connected: bool = true
	var last_cmd: Commands = Commands.new()
	var ack_tick: int = 0                       # ultimo comando do cliente aplicado
	var loaded: bool = false                    # T-208: ja montou a corrida e preparou a abertura (c_race_loaded)


var code: String = ""
var host_peer: int = 0
var rules: Dictionary = Protocol.default_rules()
var state: int = Protocol.RoomState.LOBBY
var members: Dictionary = {}                    # peer_id -> Member
var order: Array[int] = []                      # peers na ordem dos slots
var sim: RaceSim
var drivers: Dictionary = {}                    # truck_idx -> BotDriver
var events: Array[Dictionary] = []              # eventos do tick (colisao, ultrapassagem, chegada...)
var damage_updates: Array[int] = []             # indices de caminhoes cujo dano mudou neste tick
var seed_value: int = 0
var countdown: float = 0.0
var end_timer: float = -1.0
var results: Dictionary = {}                    # peer_id -> resultado final
var bot_names: Dictionary = {}                  # truck_idx -> nome do bot
var bot_loadouts: Dictionary = {}               # truck_idx -> descritor do bot (T-218: com o modelo sorteado)
var intro: String = DuelPlan.SHORT              # T-156: abertura "frente a frente" (full) ou curta; o countdown inclui ela
var countdown_total: float = Protocol.COUNTDOWN_SECONDS
var race_rules: Dictionary = {}                 # regras usadas nesta corrida (comboio: transito mais leve)
## O servidor liga depois de mandar o setup: o quadro que montou a corrida (lento) nao entra na contagem (T-156).
var hold_first_frame: bool = false
## T-208: depois do setup a sala espera todos os jogadores montarem a corrida (ou Protocol.LOAD_WAIT_MAX) e so entao
## comeca a contagem; o servidor avisa a todos com s_state(COUNTDOWN) no mesmo instante (ninguem perde a abertura).
var loading: bool = false
var load_wait: float = 0.0
var _last_race_sig: String = ""                 # mesma rota e mesmas pessoas da corrida anterior = revanche (versao curta)
var _acc: float = 0.0
var _prev_damage: Dictionary = {}               # truck_idx -> assinatura do dano


func _init(code_: String = "") -> void:
	code = code_


# ---------------------------------------------------------------- lobby

func add_member(peer: int, name: String, player_code: String, loadout: Dictionary) -> String:
	if state != Protocol.RoomState.LOBBY:
		return "corrida em andamento"
	if members.size() >= Protocol.MAX_PLAYERS:
		return "sala cheia"
	var m := Member.new()
	m.peer_id = peer
	m.name = name.substr(0, 16) if name != "" else "Jogador"
	m.player_code = player_code
	m.loadout = loadout
	members[peer] = m
	order.append(peer)
	if host_peer == 0:
		host_peer = peer
	return ""


func remove_member(peer: int) -> void:
	if not members.has(peer):
		return
	var m: Member = members[peer]
	m.connected = false
	if state == Protocol.RoomState.LOBBY:
		members.erase(peer)
		order.erase(peer)
		if host_peer == peer:
			host_peer = order[0] if not order.is_empty() else 0
	elif sim != null and m.truck_idx >= 0:
		# jogador saiu no meio da corrida: um bot assume o caminhao ate o fim
		sim.trucks[m.truck_idx].is_bot = true
		drivers[m.truck_idx] = BotDriver.new(BotDriver.Difficulty.NORMAL, 900 + peer, StartGrid.lane_x(m.truck_idx), false, true)
		sim.set_command(m.truck_idx, Commands.new())


func set_ready(peer: int, ready: bool) -> void:
	if members.has(peer) and state == Protocol.RoomState.LOBBY:
		(members[peer] as Member).ready = ready


func set_loadout(peer: int, loadout: Dictionary) -> void:
	if members.has(peer) and state == Protocol.RoomState.LOBBY:
		(members[peer] as Member).loadout = loadout
		(members[peer] as Member).ready = false


func set_rules(peer: int, new_rules: Dictionary) -> bool:
	if peer != host_peer or state != Protocol.RoomState.LOBBY:
		return false
	for k in Protocol.default_rules():
		if new_rules.has(k):
			rules[k] = new_rules[k]
	rules["bots"] = clampi(int(rules["bots"]), 0, 3)
	rules["traffic"] = clampi(int(rules["traffic"]), 0, 2)
	for m in members.values():
		(m as Member).ready = false
	return true


func all_ready() -> bool:
	if members.is_empty():
		return false
	for m in members.values():
		if not (m as Member).ready:
			return false
	return true


## Estado enviado aos clientes (lobby).
func lobby_state() -> Dictionary:
	var list: Array = []
	for p in order:
		var m: Member = members[p]
		list.append({"peer": p, "name": m.name, "ready": m.ready, "host": p == host_peer,
			"paint": m.loadout.get("paint", "#e9eef5"), "player_code": m.player_code})
	return {"code": code, "state": state, "rules": rules, "members": list}


func is_empty() -> bool:
	for m in members.values():
		if (m as Member).connected:
			return false
	return true


# ---------------------------------------------------------------- corrida

## Host pede o inicio (ou todos prontos). Cria a simulacao e comeca a contagem.
func try_start(peer: int, seed_: int) -> String:
	if peer != host_peer:
		return "só o anfitrião inicia"
	if state != Protocol.RoomState.LOBBY:
		return "já iniciada"
	if not all_ready():
		return "nem todos estão prontos"
	_build_race(seed_)
	state = Protocol.RoomState.COUNTDOWN
	# T-156: 2 jogadores = abertura frente a frente; 3-4 ou revanche = curta. O servidor espera a abertura inteira
	# antes de largar, e todos os clientes tocam a cena pelo mesmo relogio (setup + ping): ninguem larga atrasado.
	var sig: String = "%s|%s" % [rules["route"], ",".join(PackedStringArray(order.map(func(p: int) -> String: return (members[p] as Member).player_code)))]
	intro = DuelPlan.pick_online(order.size(), sim.trucks.size(), sig == _last_race_sig)
	_last_race_sig = sig
	countdown_total = DuelPlan.total_seconds(intro)
	countdown = countdown_total
	loading = true
	load_wait = 0.0
	for p in order:
		(members[p] as Member).loaded = false
	return ""


func _build_race(seed_: int) -> void:
	seed_value = seed_
	var route: RouteDef = load("res://data/routes/%s.tres" % rules["route"]) as RouteDef
	var track: Track = route.build_track() if route != null else Track.make_test_track()
	if route != null and bool(rules.get("events", true)):
		track.events = route.build_events(track, seed_)       # T-139: o servidor sorteia e manda no setup
	race_rules = rules.duplicate()
	race_rules["traffic"] = DuelPlan.convoy_traffic(int(rules["traffic"]), order.size())   # T-156: comboio (3-4) = mais leve
	race_rules["convoy"] = order.size() >= 3
	sim = RaceSim.new(track, int(race_rules["traffic"]), seed_)
	sim.freight = route.freight if route != null else 25000
	sim.deadline = (route.deadline() + track.events.time_allowance()) if route != null else 0.0   # T-139: folga dos eventos
	drivers.clear()
	bot_loadouts.clear()
	var bots: int = mini(int(rules["bots"]), Protocol.MAX_PLAYERS - order.size())
	var n: int = order.size() + bots
	var slot: int = 0
	for p in order:
		var m: Member = members[p]
		var g: Vector2 = StartGrid.slot(slot, n)                # T-156: lado a lado (ate 3 por fileira)
		var idx: int = sim.add_truck(g.x, g.y)
		m.truck_idx = idx
		TruckConfig.apply(sim.trucks[idx], m.loadout)
		slot += 1
	var names: Array[String] = ["Trovão Rosa", "Dragão de Aço", "Lua Cromada"]
	for b in bots:
		var g2: Vector2 = StartGrid.slot(slot, n)
		var idx2: int = sim.add_truck(g2.x, g2.y)
		var t: TruckSim = sim.trucks[idx2]
		t.is_bot = true
		var desc: Dictionary = TruckConfig.basic_descriptor()
		desc["body"] = BodyDef.BOT_POOL[absi(seed_ + 7 * b) % BodyDef.BOT_POOL.size()]   # T-218: sorteio pela semente
		bot_loadouts[idx2] = desc
		TruckConfig.apply(t, desc)
		drivers[idx2] = BotDriver.new(clampi(b, 0, 2), seed_ + 10 + b, g2.y)
		bot_names[idx2] = names[b % names.size()]
		slot += 1


func apply_command(peer: int, tick: int, steer: float, throttle: float, brake: float, passing: bool, horn: bool = false) -> void:
	if not members.has(peer):
		return
	var m: Member = members[peer]
	if tick < m.ack_tick:
		return                                  # comando antigo/duplicado
	m.last_cmd = Commands.make(steer, throttle, brake, passing, horn)
	m.ack_tick = tick


## T-208: o jogador `peer` montou a corrida e esta pronto para ver a abertura.
func mark_loaded(peer: int) -> void:
	if members.has(peer):
		(members[peer] as Member).loaded = true


## Todos os jogadores conectados ja montaram a corrida?
func all_loaded() -> bool:
	for p in order:
		var m: Member = members[p]
		if m.connected and not m.loaded:
			return false
	return true


## Avanca a sala em tempo real (chamado todo frame pelo servidor).
func advance(delta: float) -> void:
	if state == Protocol.RoomState.COUNTDOWN:
		if loading:                     # T-208: espera todos montarem a corrida; o quadro que libera nao conta
			load_wait += delta
			if all_loaded() or load_wait >= Protocol.LOAD_WAIT_MAX:
				loading = false
				hold_first_frame = false        # este quadro (o do aviso a todos) ja e o "segurado"
			return
		if hold_first_frame:            # T-156: os clientes contam a partir do setup; o servidor, do quadro seguinte
			hold_first_frame = false
			return
		countdown -= delta
		if countdown <= 0.0:
			state = Protocol.RoomState.RACING
			_acc = 0.0
		return
	if state != Protocol.RoomState.RACING:
		return
	_acc += delta
	while _acc >= Protocol.SERVER_TICK and state == Protocol.RoomState.RACING:
		_acc -= Protocol.SERVER_TICK
		step_tick()


## Um tick da simulacao (30/s): comandos dos humanos, IA dos bots, fisica, colisao, chegada.
func step_tick() -> void:
	for p in order:
		var m: Member = members[p]
		if m.truck_idx >= 0 and not sim.trucks[m.truck_idx].is_bot:
			sim.set_command(m.truck_idx, m.last_cmd)
	for idx in drivers:
		sim.set_command(int(idx), (drivers[idx] as BotDriver).command_for(sim, int(idx), RaceSim.FIXED_DT))
	sim.step()
	var evs: Array[Dictionary] = sim.drain_events()
	events.append_array(evs)
	_track_damage_changes(evs)
	if end_timer < 0.0:
		for p in order:
			var m2: Member = members[p]
			if m2.truck_idx >= 0 and sim.trucks[m2.truck_idx].finish_position > 0 and not sim.trucks[m2.truck_idx].is_bot:
				end_timer = END_AFTER_FIRST_FINISH
				break
	elif end_timer > 0.0:
		end_timer -= RaceSim.FIXED_DT
	if sim.is_over() or (end_timer >= 0.0 and end_timer <= 0.0):
		_finish()


func _track_damage_changes(evs: Array[Dictionary]) -> void:
	for e in evs:
		match String(e["type"]):
			"truck":
				_mark_damage(int(e["a"]))
				_mark_damage(int(e["b"]))
			"traffic", "event_obstacle", "event_cone", "event_scrape", "event_plates":   # T-139: dano/carga dos eventos
				_mark_damage(int(e["truck"]))


func _mark_damage(idx: int) -> void:
	if idx not in damage_updates:
		damage_updates.append(idx)


## Dano completo de um caminhao (enviado so quando muda).
func damage_of(idx: int) -> Dictionary:
	var t: TruckSim = sim.trucks[idx]
	var parts: Array = []
	for p in t.loadout:
		parts.append([String(p["id"]), float(p["dur"]), bool(p["broken"])])
	return {"idx": idx, "parts": parts, "systems": t.systems.duplicate(), "mass": t.mass, "penalty": t.cargo_penalty}


func _finish() -> void:
	if state == Protocol.RoomState.FINISHED:
		return
	state = Protocol.RoomState.FINISHED
	for p in order:
		var m: Member = members[p]
		if m.truck_idx < 0:
			continue
		var res: Dictionary = sim.result_for(m.truck_idx)
		res["persist_damage"] = int(rules["damage"]) == Protocol.DamageMode.REAL
		res["truck_idx"] = m.truck_idx
		res["parts_final"] = damage_of(m.truck_idx)
		results[p] = res


func snapshot() -> PackedByteArray:
	var acks: Array = []
	for i in sim.trucks.size():
		acks.append(0)
	for p in order:
		var m: Member = members[p]
		if m.truck_idx >= 0:
			acks[m.truck_idx] = m.ack_tick
	return Snapshot.pack(sim, acks)


func drain_events() -> Array[Dictionary]:
	var out: Array[Dictionary] = events.duplicate()
	events.clear()
	return out


func drain_damage_updates() -> Array[int]:
	var out: Array[int] = damage_updates.duplicate()
	damage_updates.clear()
	return out


## Dados para o cliente montar a corrida (mesma pista/semente/grid).
func race_setup() -> Dictionary:
	var grid: Array = []
	for i in sim.trucks.size():
		var entry: Dictionary = {"idx": i, "bot": sim.trucks[i].is_bot, "name": String(bot_names.get(i, "")), "peer": 0, "paint": "#e9eef5", "loadout": bot_loadouts.get(i, TruckConfig.basic_descriptor())}
		grid.append(entry)
	for p in order:
		var m: Member = members[p]
		var e: Dictionary = grid[m.truck_idx]
		e["peer"] = p
		e["name"] = m.name
		e["paint"] = m.loadout.get("paint", "#e9eef5")
		e["loadout"] = m.loadout
	return {"seed": seed_value, "rules": race_rules if not race_rules.is_empty() else rules, "grid": grid, "countdown": countdown,
		"tick": sim.tick, "events": sim.track.events.to_array(), "lane_sections": sim.track.lane_sections,   # T-153: trechos de 2 faixas
		"intro": intro, "countdown_total": countdown_total}                      # T-156: abertura e relogio da largada
