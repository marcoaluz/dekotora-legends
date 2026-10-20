extends Node
## Net (autoload): conexao ENet, todas as funcoes RPC (mesmo caminho /root/Net em cliente e servidor)
## e a API que a interface usa. Em modo --server cria o ServerHost (logica das salas).
## Veja docs/MULTIPLAYER.md. Os RPCs sao as "mensagens" do protocolo:
##   c_* = cliente -> servidor      s_* = servidor -> cliente

signal connected_to_server
signal connection_failed
signal disconnected_from_server
signal welcome(profile: Dictionary)
signal error_received(message: String)
signal room_joined(code: String)
signal lobby_updated(state: Dictionary)
signal race_setup_received(setup: Dictionary, my_truck: int)
signal race_state_changed(state: int)
signal snapshot_received(data: PackedByteArray)
signal events_received(events: Array)
signal damage_received(damage: Dictionary)
signal race_ended(result: Dictionary)
signal profile_synced(profile: Dictionary)
signal ping_updated(ms: int)

var is_server: bool = false
var host: ServerHost
var peer: ENetMultiplayerPeer
var my_peer_id: int = 0
var online: bool = false                   # conectado e com "welcome" recebido
var room_code: String = ""
var lobby: Dictionary = {}
var ping_ms: int = 0
var player_name: String = "Jogador"
var pending_setup: Dictionary = {}          # corrida online a montar (preenchido em s_race_setup)
var pending_truck: int = -1
var pending_setup_msec: int = 0             # T-156: when the setup arrived (clock of the face-to-face opening)
var room_state: int = Protocol.RoomState.LOBBY   # last state sent by the server (s_state)

# --- depuracao de rede (P62): simula latencia e perda de pacotes
var debug_latency_ms: int = 0
var debug_loss: float = 0.0
var _delayed: Array[Dictionary] = []       # {due, kind, args}
var _ping_timer: float = 0.0
var _gs_connected: bool = false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: connection_failed.emit())
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# ---------------------------------------------------------------- servidor

func start_server(port: int = Protocol.DEFAULT_PORT) -> int:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(port, 32)
	if err != OK:
		push_error("Net: nao consegui abrir a porta UDP %d (erro %d)" % [port, err])
		return err
	multiplayer.multiplayer_peer = peer
	is_server = true
	host = ServerHost.new()
	host.name = "ServerHost"
	add_child(host)
	print("[servidor] escutando na porta UDP %d" % port)
	return OK


func _on_peer_connected(id: int) -> void:
	if is_server:
		print("[servidor] peer %d conectou (aguardando hello)" % id)


func _on_peer_disconnected(id: int) -> void:
	if is_server and host != null:
		host.on_disconnect(id)


# ---------------------------------------------------------------- cliente: conexao

func connect_to(ip: String, port: int = Protocol.DEFAULT_PORT) -> int:
	disconnect_from()
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(ip, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func disconnect_from() -> void:
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = null
	peer = null
	online = false
	room_code = ""
	lobby = {}


func _on_connected() -> void:
	my_peer_id = multiplayer.get_unique_id()
	connected_to_server.emit()
	var gs: Node = get_node("/root/GameState")
	if not _gs_connected:
		_gs_connected = true
		gs.action_performed.connect(_on_local_action)
	rpc_id(1, "c_hello", Protocol.VERSION, String(gs.profile["player_code"]), player_name, JSON.stringify(gs.profile))


func _on_server_disconnected() -> void:
	online = false
	room_code = ""
	disconnected_from_server.emit()


func _on_local_action(action: String, arg: String) -> void:
	if online:
		rpc_id(1, "c_action", action, arg)


# ---------------------------------------------------------------- cliente: API usada pela interface

func create_room(rules: Dictionary, loadout: Dictionary) -> void:
	rpc_id(1, "c_create_room", rules, loadout)


func join_room(code: String, loadout: Dictionary) -> void:
	rpc_id(1, "c_join_room", code, loadout)


func leave_room() -> void:
	rpc_id(1, "c_leave_room")
	room_code = ""
	lobby = {}


func set_ready(ready: bool) -> void:
	rpc_id(1, "c_set_ready", ready)


func set_loadout(loadout: Dictionary) -> void:
	rpc_id(1, "c_set_loadout", loadout)


func set_rules(rules: Dictionary) -> void:
	rpc_id(1, "c_set_rules", rules)


func start_race() -> void:
	rpc_id(1, "c_start_race")


## Comandos do jogador (30/s). `tick` = numero do comando no cliente (usado como "ack" pelo servidor).
func send_commands(tick: int, cmd: Commands) -> void:
	if debug_loss > 0.0 and randf() < debug_loss:
		return
	if debug_latency_ms > 0:
		_delayed.append({"due": Time.get_ticks_msec() + debug_latency_ms / 2, "kind": "cmd", "args": [tick, cmd.steer, cmd.throttle, cmd.brake, cmd.passing, cmd.horn]})
		return
	rpc_id(1, "c_commands", tick, cmd.steer, cmd.throttle, cmd.brake, cmd.passing, cmd.horn)


func _process(delta: float) -> void:
	if not _delayed.is_empty():
		var now: int = Time.get_ticks_msec()
		var rest: Array[Dictionary] = []
		for d in _delayed:
			if now >= int(d["due"]):
				match String(d["kind"]):
					"cmd":
						var a: Array = d["args"]
						rpc_id(1, "c_commands", a[0], a[1], a[2], a[3], a[4], a[5])
					"snap":
						snapshot_received.emit(d["args"])
			else:
				rest.append(d)
		_delayed = rest
	if online and not is_server:
		_ping_timer += delta
		if _ping_timer >= 2.0:
			_ping_timer = 0.0
			rpc_id(1, "c_ping", Time.get_ticks_msec())


# ================================================================ RPCs: cliente -> servidor

@rpc("any_peer", "reliable")
func c_hello(version: int, player_code: String, name: String, profile_json: String) -> void:
	if is_server:
		host.on_hello(multiplayer.get_remote_sender_id(), version, player_code, name, profile_json)


@rpc("any_peer", "reliable")
func c_create_room(rules: Dictionary, loadout: Dictionary) -> void:
	if is_server:
		host.on_create_room(multiplayer.get_remote_sender_id(), rules, loadout)


@rpc("any_peer", "reliable")
func c_join_room(code: String, loadout: Dictionary) -> void:
	if is_server:
		host.on_join_room(multiplayer.get_remote_sender_id(), code, loadout)


@rpc("any_peer", "reliable")
func c_leave_room() -> void:
	if is_server:
		host.on_leave_room(multiplayer.get_remote_sender_id())


@rpc("any_peer", "reliable")
func c_set_ready(ready: bool) -> void:
	if is_server:
		host.on_set_ready(multiplayer.get_remote_sender_id(), ready)


@rpc("any_peer", "reliable")
func c_set_loadout(loadout: Dictionary) -> void:
	if is_server:
		host.on_set_loadout(multiplayer.get_remote_sender_id(), loadout)


@rpc("any_peer", "reliable")
func c_set_rules(rules: Dictionary) -> void:
	if is_server:
		host.on_set_rules(multiplayer.get_remote_sender_id(), rules)


@rpc("any_peer", "reliable")
func c_start_race() -> void:
	if is_server:
		host.on_start_race(multiplayer.get_remote_sender_id())


@rpc("any_peer", "unreliable")
func c_commands(tick: int, steer: float, throttle: float, brake: float, passing: bool, horn: bool) -> void:
	if is_server:
		host.on_commands(multiplayer.get_remote_sender_id(), tick, steer, throttle, brake, passing, horn)


@rpc("any_peer", "reliable")
func c_action(action: String, arg: String) -> void:
	if is_server:
		host.on_action(multiplayer.get_remote_sender_id(), action, arg)


@rpc("any_peer", "unreliable")
func c_ping(t: int) -> void:
	if is_server:
		rpc_id(multiplayer.get_remote_sender_id(), "s_pong", t)


# ================================================================ RPCs: servidor -> cliente

@rpc("authority", "reliable")
func s_welcome(version: int, peer_id: int, profile_json: String) -> void:
	my_peer_id = peer_id
	online = true
	var parsed: Variant = JSON.parse_string(profile_json)
	if parsed is Dictionary:
		_adopt_profile(parsed)
		welcome.emit(parsed)


@rpc("authority", "reliable")
func s_error(message: String) -> void:
	push_warning("Net: servidor diz: " + message)
	error_received.emit(message)


@rpc("authority", "reliable")
func s_room_joined(code: String) -> void:
	room_code = code
	room_joined.emit(code)


@rpc("authority", "reliable")
func s_lobby(state: Dictionary) -> void:
	lobby = state
	lobby_updated.emit(state)


@rpc("authority", "reliable")
func s_race_setup(setup: Dictionary, my_truck: int) -> void:
	pending_setup = setup
	pending_truck = my_truck
	pending_setup_msec = Time.get_ticks_msec()
	room_state = Protocol.RoomState.COUNTDOWN
	race_setup_received.emit(setup, my_truck)


@rpc("authority", "reliable")
func s_state(state: int) -> void:
	room_state = state
	race_state_changed.emit(state)


@rpc("authority", "unreliable_ordered")
func s_snapshot(data: PackedByteArray) -> void:
	if debug_loss > 0.0 and randf() < debug_loss:
		return
	if debug_latency_ms > 0:
		_delayed.append({"due": Time.get_ticks_msec() + debug_latency_ms / 2, "kind": "snap", "args": data})
		return
	snapshot_received.emit(data)


@rpc("authority", "reliable")
func s_events(events: Array) -> void:
	events_received.emit(events)


@rpc("authority", "reliable")
func s_damage(damage: Dictionary) -> void:
	damage_received.emit(damage)


@rpc("authority", "reliable")
func s_race_end(result: Dictionary, profile_json: String) -> void:
	var parsed: Variant = JSON.parse_string(profile_json)
	if parsed is Dictionary:
		_adopt_profile(parsed)
	race_ended.emit(result)


@rpc("authority", "reliable")
func s_profile(profile_json: String) -> void:
	var parsed: Variant = JSON.parse_string(profile_json)
	if parsed is Dictionary:
		_adopt_profile(parsed)
		profile_synced.emit(parsed)


@rpc("authority", "unreliable")
func s_pong(t: int) -> void:
	ping_ms = Time.get_ticks_msec() - t
	ping_updated.emit(ping_ms)


## O servidor e a fonte da verdade: o perfil local passa a ser um cache do que ele mandou.
func _adopt_profile(p: Dictionary) -> void:
	var gs: Node = get_node("/root/GameState")
	gs.profile = p
	gs.save_profile_cache_only()
	gs.profile_changed.emit()
