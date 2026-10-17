class_name Room
extends RefCounted
## Uma sala multiplayer: jogadores, regras, lobby e a corrida autoritativa. Nao conhece a rede:
## o servidor (server_main.gd) entrega comandos e le snapshots/eventos. Isso permite testar tudo
## sem abrir portas (tests/test_net_room.gd).

const GRID_X: Array[float] = [0.0, -0.6, 0.6, 0.0]   # faixas do grid (centro, esq., dir., centro)
const GRID_GAP: float = 14.0
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
		drivers[m.truck_idx] = BotDriver.new(BotDriver.Difficulty.NORMAL, 900 + peer, GRID_X[m.truck_idx % 4])
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
		return "so o anfitriao inicia"
	if state != Protocol.RoomState.LOBBY:
		return "ja iniciada"
	if not all_ready():
		return "nem todos estao prontos"
	_build_race(seed_)
	state = Protocol.RoomState.COUNTDOWN
	countdown = Protocol.COUNTDOWN_SECONDS
	return ""


func _build_race(seed_: int) -> void:
	seed_value = seed_
	var route: RouteDef = load("res://data/routes/%s.tres" % rules["route"]) as RouteDef
	var track: Track = route.build_track() if route != null else Track.make_test_track()
	sim = RaceSim.new(track, int(rules["traffic"]), seed_)
	sim.freight = route.freight if route != null else 25000
	drivers.clear()
	var slot: int = 0
	for p in order:
		var m: Member = members[p]
		var idx: int = sim.add_truck(-float(slot) * GRID_GAP, GRID_X[slot % 4])
		m.truck_idx = idx
		TruckConfig.apply(sim.trucks[idx], m.loadout)
		slot += 1
	var bots: int = mini(int(rules["bots"]), Protocol.MAX_PLAYERS - order.size())
	var names: Array[String] = ["Trovao Rosa", "Dragao de Aco", "Lua Cromada"]
	for b in bots:
		var idx2: int = sim.add_truck(-float(slot) * GRID_GAP, GRID_X[slot % 4])
		var t: TruckSim = sim.trucks[idx2]
		t.is_bot = true
		TruckConfig.apply(t, TruckConfig.basic_descriptor())
		drivers[idx2] = BotDriver.new(clampi(b, 0, 2), seed_ + 10 + b, GRID_X[slot % 4])
		bot_names[idx2] = names[b % names.size()]
		slot += 1


func apply_command(peer: int, tick: int, steer: float, throttle: float, brake: float, passing: bool) -> void:
	if not members.has(peer):
		return
	var m: Member = members[peer]
	if tick < m.ack_tick:
		return                                  # comando antigo/duplicado
	m.last_cmd = Commands.make(steer, throttle, brake, passing)
	m.ack_tick = tick


## Avanca a sala em tempo real (chamado todo frame pelo servidor).
func advance(delta: float) -> void:
	if state == Protocol.RoomState.COUNTDOWN:
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
			"traffic":
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
	return {"idx": idx, "parts": parts, "systems": t.systems.duplicate(), "mass": t.mass}


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
		var entry: Dictionary = {"idx": i, "bot": sim.trucks[i].is_bot, "name": String(bot_names.get(i, "")), "peer": 0, "paint": "#e9eef5", "loadout": TruckConfig.basic_descriptor()}
		grid.append(entry)
	for p in order:
		var m: Member = members[p]
		var e: Dictionary = grid[m.truck_idx]
		e["peer"] = p
		e["name"] = m.name
		e["paint"] = m.loadout.get("paint", "#e9eef5")
		e["loadout"] = m.loadout
	return {"seed": seed_value, "rules": rules, "grid": grid, "countdown": countdown, "tick": sim.tick}
