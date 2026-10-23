class_name ServerHost
extends Node
## Servidor dedicado autoritativo (modo --server): salas, lobby, corrida, perfis. As funcoes RPC
## ficam no autoload Net (mesmo caminho nos dois lados); aqui fica a logica.
## Roda headless: godot --headless --path game -- --server [--port=24600]

const NET_PATH := "/root/Net"

var rooms: Dictionary = {}                 # codigo -> Room
var peer_room: Dictionary = {}             # peer_id -> codigo
var peer_player: Dictionary = {}           # peer_id -> {code, name}
var store: ProfileStore
var _rng := RandomNumberGenerator.new()
var _snap_acc: float = 0.0
var _log_acc: float = 0.0


func _ready() -> void:
	_rng.randomize()
	store = ProfileStore.new()
	Engine.max_fps = 60
	print("[servidor] pronto; salas: 0")


func net() -> Node:
	return get_node(NET_PATH)


func log_msg(text: String) -> void:
	print("[servidor] ", text)


# ---------------------------------------------------------------- conexao

func on_hello(peer: int, version: int, player_code: String, name: String, profile_json: String) -> void:
	if version != Protocol.VERSION:
		net().rpc_id(peer, "s_error", "versão incompatível (servidor %d, cliente %d)" % [Protocol.VERSION, version])
		return
	var code: String = store.clean_code(player_code)
	if code == "":
		net().rpc_id(peer, "s_error", "código de jogador inválido")
		return
	var client_profile: Dictionary = {}
	var parsed: Variant = JSON.parse_string(profile_json) if profile_json != "" else null
	if parsed is Dictionary:
		client_profile = parsed
	var gs: Node = store.sync_from_client(code, client_profile) if not client_profile.is_empty() else store.get_profile(code)
	peer_player[peer] = {"code": code, "name": name.substr(0, 16)}
	log_msg("jogador %s (%s) conectou, peer %d" % [name, code, peer])
	net().rpc_id(peer, "s_welcome", Protocol.VERSION, peer, JSON.stringify(gs.profile))


func on_disconnect(peer: int) -> void:
	var rcode: String = String(peer_room.get(peer, ""))
	if rcode != "" and rooms.has(rcode):
		var room: Room = rooms[rcode]
		room.remove_member(peer)
		_broadcast_lobby(room)
		if room.is_empty():
			rooms.erase(rcode)
			log_msg("sala %s fechada (vazia)" % rcode)
	peer_room.erase(peer)
	if peer_player.has(peer):
		log_msg("jogador %s saiu" % peer_player[peer]["name"])
	peer_player.erase(peer)


# ---------------------------------------------------------------- salas

func _new_code() -> String:
	for i in 50:
		var c: String = Protocol.make_room_code(_rng)
		if not rooms.has(c):
			return c
	return Protocol.make_room_code(_rng)


func on_create_room(peer: int, rules: Dictionary, loadout: Dictionary) -> void:
	if not peer_player.has(peer):
		return
	_leave_current(peer)
	var room := Room.new(_new_code())
	if rules.has("route"):
		room.rules = Protocol.default_rules()
		for k in rules:
			if room.rules.has(k):
				room.rules[k] = rules[k]
	var pl: Dictionary = peer_player[peer]
	var err: String = room.add_member(peer, String(pl["name"]), String(pl["code"]), _sanitize_loadout(String(pl["code"]), loadout))
	if err != "":
		net().rpc_id(peer, "s_error", err)
		return
	rooms[room.code] = room
	peer_room[peer] = room.code
	log_msg("sala %s criada por %s" % [room.code, pl["name"]])
	net().rpc_id(peer, "s_room_joined", room.code)
	_broadcast_lobby(room)


func on_join_room(peer: int, code: String, loadout: Dictionary) -> void:
	if not peer_player.has(peer):
		return
	code = code.to_upper().strip_edges()
	if not rooms.has(code):
		net().rpc_id(peer, "s_error", "sala %s não existe" % code)
		return
	_leave_current(peer)
	var room: Room = rooms[code]
	var pl: Dictionary = peer_player[peer]
	var err: String = room.add_member(peer, String(pl["name"]), String(pl["code"]), _sanitize_loadout(String(pl["code"]), loadout))
	if err != "":
		net().rpc_id(peer, "s_error", err)
		return
	peer_room[peer] = code
	log_msg("%s entrou na sala %s" % [pl["name"], code])
	net().rpc_id(peer, "s_room_joined", code)
	_broadcast_lobby(room)


func _leave_current(peer: int) -> void:
	var rcode: String = String(peer_room.get(peer, ""))
	if rcode != "" and rooms.has(rcode):
		var room: Room = rooms[rcode]
		room.remove_member(peer)
		_broadcast_lobby(room)
		if room.is_empty():
			rooms.erase(rcode)
	peer_room.erase(peer)


func on_leave_room(peer: int) -> void:
	_leave_current(peer)


## O servidor ignora o descritor do cliente e usa o PERFIL guardado (anti-trapaca): so a tinta e aceita.
func _sanitize_loadout(player_code: String, requested: Dictionary) -> Dictionary:
	var gs: Node = store.get_profile(player_code)
	var desc: Dictionary = gs.truck_descriptor()
	if requested.has("paint") and String(requested["paint"]).begins_with("#") and String(requested["paint"]).length() == 7:
		desc["paint"] = String(requested["paint"])
	if requested.has("cab"):                       # cabine e so visual: aceita a do cliente (id antigo vira o novo)
		desc["cab"] = CabCatalog.normalize(requested["cab"])
	if requested.has("horn") and HornCatalog.is_valid(String(requested["horn"])):   # buzina e so som (T-173)
		desc["horn"] = String(requested["horn"])
	return desc


func _room_of(peer: int) -> Room:
	var c: String = String(peer_room.get(peer, ""))
	return rooms.get(c)


func on_set_ready(peer: int, ready: bool) -> void:
	var room: Room = _room_of(peer)
	if room == null:
		return
	room.set_ready(peer, ready)
	_broadcast_lobby(room)


func on_set_loadout(peer: int, loadout: Dictionary) -> void:
	var room: Room = _room_of(peer)
	if room == null or not peer_player.has(peer):
		return
	room.set_loadout(peer, _sanitize_loadout(String(peer_player[peer]["code"]), loadout))
	_broadcast_lobby(room)


func on_set_rules(peer: int, rules: Dictionary) -> void:
	var room: Room = _room_of(peer)
	if room != null and room.set_rules(peer, rules):
		_broadcast_lobby(room)


func on_start_race(peer: int) -> void:
	var room: Room = _room_of(peer)
	if room == null:
		return
	var err: String = room.try_start(peer, _rng.randi())
	if err != "":
		net().rpc_id(peer, "s_error", err)
		return
	log_msg("sala %s: corrida iniciada (%d caminhoes, rota %s)" % [room.code, room.sim.trucks.size(), room.rules["route"]])
	var setup: Dictionary = room.race_setup()
	for p in room.order:
		if (room.members[p] as Room.Member).connected:
			net().rpc_id(p, "s_race_setup", setup, (room.members[p] as Room.Member).truck_idx)
	room.hold_first_frame = true          # T-156: o tempo gasto montando a corrida nao conta (mesmo relogio dos clientes)
	_broadcast_lobby(room)


## T-208: o cliente montou a corrida (e preparou a abertura).
func on_race_loaded(peer: int) -> void:
	var room: Room = _room_of(peer)
	if room != null and room.state == Protocol.RoomState.COUNTDOWN:
		room.mark_loaded(peer)


func on_commands(peer: int, tick: int, steer: float, throttle: float, brake: float, passing: bool, horn: bool = false) -> void:
	var room: Room = _room_of(peer)
	if room != null and room.state == Protocol.RoomState.RACING:
		room.apply_command(peer, tick, steer, throttle, brake, passing, horn)


func on_action(peer: int, action: String, arg: String) -> void:
	if not peer_player.has(peer):
		return
	var code: String = String(peer_player[peer]["code"])
	var gs: Node = store.get_profile(code)
	var ok: bool = gs.apply_action(action, arg)
	if not ok:
		net().rpc_id(peer, "s_error", "ação recusada: %s %s" % [action, arg])
	net().rpc_id(peer, "s_profile", JSON.stringify(gs.profile))


func _broadcast_lobby(room: Room) -> void:
	var st: Dictionary = room.lobby_state()
	for p in room.order:
		if (room.members[p] as Room.Member).connected:
			net().rpc_id(p, "s_lobby", st)


# ---------------------------------------------------------------- laco principal

func _process(delta: float) -> void:
	var dead: Array[String] = []
	for code in rooms:
		var room: Room = rooms[code]
		var before: int = room.state
		var was_loading: bool = room.loading
		room.advance(delta)
		if was_loading and not room.loading and room.state == Protocol.RoomState.COUNTDOWN:   # T-208: todos prontos
			log_msg("sala %s: todos montaram a corrida em %.1f s; abertura e contagem comecam agora" % [room.code, room.load_wait])
			_broadcast_state(room)                 # s_state(COUNTDOWN) = o relogio comum comeca neste instante
		if room.state == Protocol.RoomState.RACING or room.state == Protocol.RoomState.FINISHED:
			_send_race_updates(room, delta)
		if before != room.state:
			if room.state == Protocol.RoomState.RACING:
				_broadcast_state(room)
			elif room.state == Protocol.RoomState.FINISHED:
				_finish_room(room)
		if room.state == Protocol.RoomState.FINISHED and room.is_empty():
			dead.append(code)
	for c in dead:
		rooms.erase(c)


func _broadcast_state(room: Room) -> void:
	for p in room.order:
		if (room.members[p] as Room.Member).connected:
			net().rpc_id(p, "s_state", room.state)


func _send_race_updates(room: Room, delta: float) -> void:
	if room.state != Protocol.RoomState.RACING:
		return
	var evs: Array[Dictionary] = room.drain_events()
	var dmg: Array[int] = room.drain_damage_updates()
	_snap_acc += delta
	var send_snapshot: bool = _snap_acc >= 1.0 / Protocol.SNAPSHOT_RATE
	if send_snapshot:
		_snap_acc = 0.0
	var bytes: PackedByteArray = room.snapshot() if send_snapshot else PackedByteArray()
	for p in room.order:
		var m: Room.Member = room.members[p]
		if not m.connected:
			continue
		if not evs.is_empty():
			net().rpc_id(p, "s_events", evs)
		for idx in dmg:
			net().rpc_id(p, "s_damage", room.damage_of(idx))
		if send_snapshot:
			net().rpc_id(p, "s_snapshot", bytes)


## Fim da corrida: paga os jogadores e grava (se o modo for "Dano real"), avisa os clientes.
func _finish_room(room: Room) -> void:
	log_msg("sala %s: corrida terminou" % room.code)
	for p in room.order:
		var m: Room.Member = room.members[p]
		if not room.results.has(p) or not peer_player.has(p):
			continue
		var res: Dictionary = room.results[p]
		var gs: Node = store.get_profile(m.player_code)
		var truck: TruckSim = room.sim.trucks[m.truck_idx]
		if bool(res["persist_damage"]):
			gs.apply_race_result(res, String(room.rules["route"]), truck)
		else:
			_apply_money_only(gs, res)
		if m.connected:
			net().rpc_id(p, "s_race_end", res, JSON.stringify(gs.profile))


## "Dano: so na corrida": o dinheiro e a Fama contam, mas as pecas voltam como estavam.
func _apply_money_only(gs: Node, res: Dictionary) -> void:
	gs.profile["money"] = gs.money() + int(res["pay"])
	gs.profile["fame"] = gs.fame() + int(res["fame"])
	gs.save_profile()
