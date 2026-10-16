extends Node3D
## Lobby do multiplayer: conectar ao servidor, criar sala (codigo de 6 letras) ou entrar com codigo,
## ver os jogadores, marcar "pronto", e (anfitriao) escolher as regras e iniciar a corrida.
## Fluxo: docs/MULTIPLAYER.md. O caminhao 3D de fundo e o proprio (da garagem).

var stage: GarageStage
var _ui: Control
var _panel: Control
var _status: Label
var _code_edit: LineEdit
var _members_box: VBoxContainer
var _rules_box: VBoxContainer
var _ready_btn: Button
var _start_btn: Button
var _last_members: int = 0
var _was_all_ready: bool = false
var _building_rules: bool = false


func _ready() -> void:
	AudioBus.play_music("lobby_wait")
	stage = GarageStage.new()
	add_child(stage)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UiTheme.make()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	_status = UiTheme.label("", 18, UiTheme.CYAN)
	_status.position = Vector2(40, 492)
	_ui.add_child(_status)
	Net.connected_to_server.connect(func() -> void: _set_status("Conectado. Aguardando o servidor..."))
	Net.connection_failed.connect(func() -> void:
		_set_status("Nao foi possivel conectar.", true)
		_show_connect())
	Net.disconnected_from_server.connect(func() -> void:
		_set_status("Desconectado do servidor.", true)
		_show_connect())
	Net.welcome.connect(func(_p: Dictionary) -> void:
		_set_status("Conectado! Seu codigo de jogador: %s" % get_node("/root/GameState").profile["player_code"])
		_show_menu())
	Net.error_received.connect(func(m: String) -> void:
		_set_status(m, true)
		AudioBus.play_ui("ui_error"))
	Net.room_joined.connect(func(_c: String) -> void: _show_room())
	Net.lobby_updated.connect(_on_lobby)
	Net.race_setup_received.connect(func(_s: Dictionary, _t: int) -> void:
		SceneFader.go(get_tree(), "res://scenes/race/race3d.tscn"))
	_apply_auto_args()
	if Net.online:
		if Net.room_code != "":
			_show_room()
			_on_lobby(Net.lobby)
		else:
			_show_menu()
	else:
		_show_connect()


func _set_status(text: String, bad: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiTheme.BAD if bad else UiTheme.CYAN)


func _new_panel(title: String, width: float = 520.0) -> VBoxContainer:
	if _panel != null:
		_panel.queue_free()
	var pc := PanelContainer.new()
	pc.position = Vector2(40, 30)
	pc.custom_minimum_size = Vector2(width, 0)
	_ui.add_child(pc)
	_panel = pc
	var v := VBoxContainer.new()
	pc.add_child(v)
	v.add_child(UiTheme.label(title, 30, UiTheme.PINK))
	return v


# ---------------------------------------------------------------- 1) conectar

func _show_connect() -> void:
	var v: VBoxContainer = _new_panel("MULTIPLAYER")
	var s: Node = get_node("/root/Settings")
	v.add_child(UiTheme.label("Nome do jogador", 16, UiTheme.TEXT_DIM))
	var name_edit := LineEdit.new()
	name_edit.text = s.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(400, 44)
	v.add_child(name_edit)
	v.add_child(UiTheme.label("Servidor (IP ou nome)", 16, UiTheme.TEXT_DIM))
	var ip_edit := LineEdit.new()
	ip_edit.text = s.server_address
	ip_edit.custom_minimum_size = Vector2(400, 44)
	v.add_child(ip_edit)
	var go: Button = UiTheme.button("CONECTAR")
	go.pressed.connect(func() -> void:
		s.player_name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else "Jogador"
		s.server_address = ip_edit.text.strip_edges()
		s.save_settings()
		Net.player_name = s.player_name
		_set_status("Conectando em %s ..." % s.server_address)
		var addr: String = s.server_address
		var port: int = Protocol.DEFAULT_PORT
		if addr.contains(":"):
			port = int(addr.get_slice(":", 1))
			addr = addr.get_slice(":", 0)
		var err: int = Net.connect_to(addr, port)
		if err != OK:
			_set_status("Erro ao iniciar a conexao (%d)" % err, true))
	v.add_child(go)
	var back: Button = UiTheme.button(Tr.t("menu.back"))
	back.pressed.connect(func() -> void: SceneFader.go(get_tree(), "res://scenes/menu/main_menu.tscn"))
	v.add_child(back)


# ---------------------------------------------------------------- 2) criar / entrar

func _show_menu() -> void:
	var v: VBoxContainer = _new_panel("SALAS")
	var create: Button = UiTheme.button("CRIAR SALA")
	create.pressed.connect(func() -> void:
		var rules: Dictionary = Protocol.default_rules()
		Net.create_room(rules, get_node("/root/GameState").truck_descriptor()))
	v.add_child(create)
	v.add_child(UiTheme.label("ou entre com o código de 6 letras:", 16, UiTheme.TEXT_DIM))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "KX4T9Q"
	_code_edit.max_length = 6
	_code_edit.custom_minimum_size = Vector2(300, 52)
	_code_edit.add_theme_font_size_override("font_size", 28)
	v.add_child(_code_edit)
	var join: Button = UiTheme.button("ENTRAR")
	join.pressed.connect(func() -> void:
		Net.join_room(_code_edit.text.strip_edges().to_upper(), get_node("/root/GameState").truck_descriptor()))
	v.add_child(join)
	var leave: Button = UiTheme.button("DESCONECTAR")
	leave.pressed.connect(func() -> void:
		Net.disconnect_from()
		_show_connect())
	v.add_child(leave)


# ---------------------------------------------------------------- 3) sala

func _show_room() -> void:
	var v: VBoxContainer = _new_panel("SALA  %s" % Net.room_code, 600.0)
	v.add_child(UiTheme.label("Passe este código aos amigos.", 15, UiTheme.TEXT_DIM))
	_members_box = VBoxContainer.new()
	v.add_child(_members_box)
	_rules_box = VBoxContainer.new()
	v.add_child(_rules_box)
	var row := HBoxContainer.new()
	v.add_child(row)
	_ready_btn = UiTheme.button("PRONTO", Vector2(180, 52))
	_ready_btn.pressed.connect(func() -> void: Net.set_ready(not _my_ready()))
	row.add_child(_ready_btn)
	_start_btn = UiTheme.button("INICIAR CORRIDA", Vector2(260, 52))
	_start_btn.pressed.connect(func() -> void: Net.start_race())
	row.add_child(_start_btn)
	var leave: Button = UiTheme.button("SAIR DA SALA")
	leave.pressed.connect(func() -> void:
		Net.leave_room()
		_show_menu())
	v.add_child(leave)


func _my_ready() -> bool:
	for m in Net.lobby.get("members", []):
		if int(m["peer"]) == Net.my_peer_id:
			return bool(m["ready"])
	return false


func _is_host() -> bool:
	for m in Net.lobby.get("members", []):
		if int(m["peer"]) == Net.my_peer_id:
			return bool(m["host"])
	return false


func _on_lobby(state: Dictionary) -> void:
	if state.is_empty() or _members_box == null or not is_instance_valid(_members_box):
		return
	for c in _members_box.get_children():
		c.queue_free()
	var members: Array = state["members"]
	var all_ready: bool = not members.is_empty()
	for m in members:
		var line := HBoxContainer.new()
		var txt: String = "%s%s" % ["👑 " if bool(m["host"]) else "", String(m["name"])]
		var l: Label = UiTheme.label(txt, 22, UiTheme.GOLD if bool(m["host"]) else UiTheme.TEXT)
		l.custom_minimum_size = Vector2(300, 0)
		line.add_child(l)
		var ready: bool = bool(m["ready"])
		if not ready:
			all_ready = false
		line.add_child(UiTheme.label("PRONTO ✔" if ready else "esperando...", 18, UiTheme.GOOD if ready else UiTheme.TEXT_DIM))
		_members_box.add_child(line)
	if members.size() > _last_members:
		AudioBus.play_ui("player_join")
	elif members.size() < _last_members:
		AudioBus.play_ui("player_leave")
	_last_members = members.size()
	if all_ready and not _was_all_ready and members.size() > 1:
		AudioBus.play_ui("all_ready")
	_was_all_ready = all_ready
	_ready_btn.text = "CANCELAR" if _my_ready() else "PRONTO"
	_start_btn.visible = _is_host()
	_start_btn.disabled = not all_ready
	_build_rules(state["rules"], _is_host())


func _build_rules(rules: Dictionary, editable: bool) -> void:
	for c in _rules_box.get_children():
		c.queue_free()
	_rules_box.add_child(UiTheme.label("Regras da sala" + ("" if editable else " (definidas pelo anfitrião)"), 17, UiTheme.CYAN))
	var routes: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
	var opt := OptionButton.new()
	for r in routes:
		opt.add_item(Tr.t("route." + r))
	opt.selected = maxi(routes.find(String(rules["route"])), 0)
	opt.disabled = not editable
	opt.item_selected.connect(func(i: int) -> void: _send_rules({"route": routes[i]}))
	_rules_box.add_child(opt)
	var dmg := OptionButton.new()
	dmg.add_item("Dano: Real (grava no perfil)")
	dmg.add_item("Dano: Só na corrida")
	dmg.selected = int(rules["damage"])
	dmg.disabled = not editable
	dmg.item_selected.connect(func(i: int) -> void: _send_rules({"damage": i}))
	_rules_box.add_child(dmg)
	var traffic := OptionButton.new()
	for t in ["Trânsito leve", "Trânsito normal", "Trânsito pesado"]:
		traffic.add_item(t)
	traffic.selected = int(rules["traffic"])
	traffic.disabled = not editable
	traffic.item_selected.connect(func(i: int) -> void: _send_rules({"traffic": i}))
	_rules_box.add_child(traffic)
	var bots := OptionButton.new()
	for b in 4:
		bots.add_item("Bots: %d" % b)
	bots.selected = int(rules["bots"])
	bots.disabled = not editable
	bots.item_selected.connect(func(i: int) -> void: _send_rules({"bots": i}))
	_rules_box.add_child(bots)


func _send_rules(change: Dictionary) -> void:
	var rules: Dictionary = Net.lobby["rules"].duplicate()
	for k in change:
		rules[k] = change[k]
	Net.set_rules(rules)


## Argumentos de teste: --auto-connect --ip=127.0.0.1 --port=24600 --name=Ana --code=ANA22222 [--create | --auto-join=CODIGO] [--players=2]
## Conecta, entra/cria a sala, marca pronto e (se for o anfitriao) inicia quando todos estiverem prontos.
func _apply_auto_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--auto-connect" not in args:
		return
	var ip: String = "127.0.0.1"
	var port: int = Protocol.DEFAULT_PORT
	var join_code: String = ""
	var create: bool = "--create" in args
	var players: int = 2
	var gs: Node = get_node("/root/GameState")
	for a in args:
		if a.begins_with("--ip="):
			ip = a.substr(5)
		elif a.begins_with("--port="):
			port = int(a.substr(7))
		elif a.begins_with("--name="):
			Net.player_name = a.substr(7)
		elif a.begins_with("--code="):
			gs.save_path = "user://auto_%s.json" % a.substr(7)
			gs.new_profile()
			gs.profile["player_code"] = a.substr(7)
		elif a.begins_with("--auto-join="):
			join_code = a.substr(12)
		elif a.begins_with("--players="):
			players = int(a.substr(10))
	Net.welcome.connect(func(_p: Dictionary) -> void:
		if create:
			Net.create_room(Protocol.default_rules(), gs.truck_descriptor())
		elif join_code != "":
			Net.join_room(join_code, gs.truck_descriptor()))
	Net.lobby_updated.connect(func(st: Dictionary) -> void:
		var ms: Array = st["members"]
		var mine_ready: bool = false
		var all_ready: bool = true
		for m in ms:
			if int(m["peer"]) == Net.my_peer_id:
				mine_ready = bool(m["ready"])
			if not bool(m["ready"]):
				all_ready = false
		if not mine_ready:
			Net.set_ready(true)
		elif create and all_ready and ms.size() >= players and int(st["state"]) == Protocol.RoomState.LOBBY:
			Net.start_race())
	Net.connect_to(ip, port)
