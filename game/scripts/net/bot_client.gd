class_name BotClient
extends Node
## Cliente automatico (headless) para testar o multiplayer de ponta a ponta sem celular:
## conecta, cria ou entra numa sala, fica pronto, (se for o anfitriao) inicia a corrida, dirige com
## BotDriver usando predicao/reconciliacao e imprime o resultado.
## Uso:  godot --headless --path game -- --bot-client --ip=127.0.0.1 --port=24600 --name=Ana --code=AAAAAAAA --create --players=2
##       godot --headless --path game -- --bot-client --join=KX4T9Q --name=Beto --code=BBBBBBBB
## Opcoes: --route=kanto_1_coast --bots=1 --latency=150 --loss=0.02 --nopredict --quit-after=240

var host_mode: bool = false
var join_code: String = ""
var expected_players: int = 2
var route: String = "kanto_1_coast"
var bots: int = 1
var sync: ClientSync
var driver: BotDriver
var racing: bool = false
var _acc: float = 0.0
var _started_sent: bool = false
var _elapsed: float = 0.0
var _max_runtime: float = 300.0
var _log_acc: float = 0.0
var _name: String = "Bot"


func _ready() -> void:
	var ip: String = "127.0.0.1"
	var port: int = Protocol.DEFAULT_PORT
	var code: String = "BOTCODE1"
	var gs: Node = get_node("/root/GameState")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ip="):
			ip = a.substr(5)
		elif a.begins_with("--port="):
			port = int(a.substr(7))
		elif a.begins_with("--name="):
			_name = a.substr(7)
		elif a.begins_with("--code="):
			code = a.substr(7)
		elif a == "--create":
			host_mode = true
		elif a.begins_with("--join="):
			join_code = a.substr(7)
		elif a.begins_with("--players="):
			expected_players = int(a.substr(10))
		elif a.begins_with("--route="):
			route = a.substr(8)
		elif a.begins_with("--bots="):
			bots = int(a.substr(7))
		elif a.begins_with("--latency="):
			Net.debug_latency_ms = int(a.substr(10))
		elif a.begins_with("--loss="):
			Net.debug_loss = float(a.substr(7))
		elif a.begins_with("--max-runtime="):
			_max_runtime = float(a.substr(14))
	# perfil proprio e isolado para este bot (nao mexe no perfil real do Marco)
	gs.save_path = "user://botclient_%s.json" % code
	gs.new_profile()
	gs.profile["player_code"] = code
	Net.player_name = _name
	Net.welcome.connect(_on_welcome)
	Net.error_received.connect(func(m: String) -> void: print("[botclient %s] erro do servidor: %s" % [_name, m]))
	Net.room_joined.connect(func(c: String) -> void: print("[botclient %s] entrou na sala %s" % [_name, c]))
	Net.lobby_updated.connect(_on_lobby)
	Net.race_setup_received.connect(_on_setup)
	Net.snapshot_received.connect(func(d: PackedByteArray) -> void:
		if sync != null:
			sync.on_snapshot(d, Time.get_ticks_msec()))
	Net.damage_received.connect(func(d: Dictionary) -> void:
		if sync != null:
			sync.apply_damage(d))
	Net.events_received.connect(_on_events)
	Net.race_state_changed.connect(func(s: int) -> void:
		print("[botclient %s] estado da sala: %d" % [_name, s])
		racing = s == Protocol.RoomState.RACING)
	Net.race_ended.connect(_on_end)
	Net.disconnected_from_server.connect(func() -> void:
		print("[botclient %s] desconectado" % _name)
		get_tree().quit(2))
	Net.connection_failed.connect(func() -> void:
		print("[botclient %s] falha de conexao" % _name)
		get_tree().quit(3))
	var err: int = Net.connect_to(ip, port)
	print("[botclient %s] conectando em %s:%d (%d)" % [_name, ip, port, err])


func _on_welcome(profile: Dictionary) -> void:
	print("[botclient %s] conectado; dinheiro %d, codigo %s" % [_name, int(profile["money"]), profile["player_code"]])
	var loadout: Dictionary = get_node("/root/GameState").truck_descriptor()
	if host_mode:
		var rules: Dictionary = Protocol.default_rules()
		rules["route"] = route
		rules["bots"] = bots
		Net.create_room(rules, loadout)
	elif join_code != "":
		Net.join_room(join_code, loadout)


func _on_lobby(state: Dictionary) -> void:
	var members: Array = state["members"]
	var me_ready: bool = false
	for m in members:
		if int(m["peer"]) == Net.my_peer_id:
			me_ready = bool(m["ready"])
	if not me_ready and int(state["state"]) == Protocol.RoomState.LOBBY:
		Net.set_ready(true)
	print("[botclient %s] lobby: sala %s, %d jogadores, estado %d" % [_name, state["code"], members.size(), int(state["state"])])
	if host_mode and not _started_sent and members.size() >= expected_players:
		var all_ready: bool = true
		for m in members:
			if not bool(m["ready"]):
				all_ready = false
		if all_ready:
			_started_sent = true
			print("[botclient %s] todos prontos: iniciando a corrida" % _name)
			Net.start_race()


func _on_setup(setup: Dictionary, my_truck: int) -> void:
	sync = ClientSync.new()
	sync.predict = not ("--nopredict" in OS.get_cmdline_user_args())
	sync.setup(setup, my_truck)
	driver = BotDriver.new(BotDriver.Difficulty.NORMAL, 7 + my_truck, Room.GRID_X[my_truck % 4], false, true)
	print("[botclient %s] corrida montada: %d caminhoes, meu indice %d, predicao %s" % [_name, sync.sim.trucks.size(), my_truck, sync.predict])


func _on_events(events: Array) -> void:
	for e in events:
		if String(e["type"]) in ["truck", "traffic", "finish"]:
			print("[botclient %s] evento: %s" % [_name, JSON.stringify(e)])


func _on_end(result: Dictionary) -> void:
	print("[botclient %s] RESULTADO posicao=%d pagamento=%d fama=%d carga=%.2f tempo=%.1f" % [
		_name, int(result["position"]), int(result["pay"]), int(result["fame"]), float(result["cargo"]), float(result["time"])])
	print("[botclient %s] BOTCLIENT_DONE" % _name)
	get_tree().create_timer(0.5).timeout.connect(func() -> void: get_tree().quit(0))


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > _max_runtime:
		print("[botclient %s] tempo maximo estourou" % _name)
		get_tree().quit(4)
		return
	if not racing or sync == null:
		return
	_acc += delta
	while _acc >= RaceSim.FIXED_DT:
		_acc -= RaceSim.FIXED_DT
		var cmd: Commands = driver.command_for(sync.sim, sync.me, RaceSim.FIXED_DT)
		var tk: int = sync.local_step(cmd)
		Net.send_commands(tk, cmd)
	sync.interpolate(Time.get_ticks_msec(), delta)
	_log_acc += delta
	if _log_acc >= 5.0:
		_log_acc = 0.0
		var t: TruckSim = sync.my_truck()
		print("[botclient %s] z=%.0f vel=%.1f km/h erro_pred=%.3f m snapshots=%d ping=%d ms" % [
			_name, t.z, t.speed * 3.6, sync.last_error.x, sync.snapshots_received, Net.ping_ms])
