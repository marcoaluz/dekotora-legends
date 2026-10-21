extends Node3D
## Lobby do multiplayer: conectar ao servidor, criar sala (codigo de 6 letras) ou entrar com codigo,
## ver os jogadores, marcar "pronto", e (anfitriao) escolher as regras e iniciar a corrida.
## Fluxo: docs/MULTIPLAYER.md. O caminhao 3D de fundo e o proprio (da garagem).
## Layout por containers (T-138): painel a esquerda com rolagem, status embaixo; textos via Tr.t.

var stage: GarageStage
var _ui: Control
var _holder: VBoxContainer
var _panel: Control
var _foot: HBoxContainer              # rodape do painel, fora da rolagem (botoes principais sempre visiveis)
var _status: Label
var _code_edit: LineEdit
var _members_box: VBoxContainer
var _rules_box: VBoxContainer
var _ready_btn: Button
var _start_btn: Button
var _last_members: int = 0
var _was_all_ready: bool = false


func _ready() -> void:
	AudioBus.play_music("lobby_wait")
	stage = GarageStage.new()
	add_child(stage)
	stage.focus_hero(0.3, 18.0)                 # caminhao a direita: o painel do lobby fica a esquerda (T-138)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UiTheme.make()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	var margin: MarginContainer = UiKit.screen_margin(32, 20)
	_ui.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	_holder = VBoxContainer.new()
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_theme_constant_override("separation", 10)
	row.add_child(_holder)
	row.add_child(UiKit.spacer())
	_status = UiTheme.label("", 18, UiTheme.CYAN)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Net.connected_to_server.connect(func() -> void: _set_status(Tr.t("lobby.connected")))
	Net.connection_failed.connect(func() -> void:
		_set_status(Tr.t("lobby.failed"), true)
		_show_connect())
	Net.disconnected_from_server.connect(func() -> void:
		_set_status(Tr.t("lobby.disconnected"), true)
		_show_connect())
	Net.welcome.connect(func(_p: Dictionary) -> void:
		_set_status(Tr.t("lobby.welcome", [String(get_node("/root/GameState").profile["player_code"])]))
		_show_menu())
	Net.error_received.connect(func(m: String) -> void:
		_set_status(m, true)
		AudioBus.play_ui("ui_error"))
	Net.room_joined.connect(func(_c: String) -> void: _show_room())
	Net.lobby_updated.connect(_on_lobby)
	Net.race_setup_received.connect(func(_s: Dictionary, _t: int) -> void:
		SceneFader.go(get_tree(), "res://scenes/race/race3d.tscn"))
	_apply_auto_args()
	if "--lobby-demo" in OS.get_cmdline_user_args():    # depuracao/capturas: sala de mentira sem servidor
		_show_room_demo()
	elif Net.online:
		if Net.room_code != "":
			_show_room()
			_on_lobby(Net.lobby)
		else:
			_show_menu()
	else:
		_show_connect()
	DebugShot.arm(self)


func _set_status(text: String, bad: bool = false) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UiTheme.BAD if bad else UiTheme.CYAN)


## Painel novo (titulo + conteudo rolavel); o status fica logo abaixo dele.
func _new_panel(title: String, icon_name: String, width: float = 520.0) -> VBoxContainer:
	if _panel != null:
		_panel.queue_free()
	if _status.get_parent() != null:
		_status.get_parent().remove_child(_status)
	var pc: PanelContainer = UiKit.glass_panel(0.9)
	pc.custom_minimum_size = Vector2(width, 0)
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_holder.add_child(pc)
	_holder.add_child(_status)
	_panel = pc
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	pc.add_child(outer)
	outer.add_child(UiKit.screen_title(title, icon_name))
	var sc := TouchScroll.new()               # rola arrastando sobre os cartoes (T-165)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 0)
	outer.add_child(sc)
	_foot = HBoxContainer.new()
	_foot.add_theme_constant_override("separation", 8)
	outer.add_child(_foot)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	var fit := func() -> void:                    # cresce com o conteudo ate caber na tela (menos o rodape); depois rola
		var room: float = get_viewport().get_visible_rect().size.y - 150.0 - (_foot.size.y + 10.0 if _foot.get_child_count() > 0 else 0.0)
		sc.custom_minimum_size.y = minf(v.size.y, maxf(room, 120.0))
	v.resized.connect(fit)
	_foot.resized.connect(fit)
	return v


# ---------------------------------------------------------------- 1) conectar

func _show_connect() -> void:
	var v: VBoxContainer = _new_panel(Tr.t("lobby.title"), "users")
	var s: Node = get_node("/root/Settings")
	v.add_child(UiTheme.label(Tr.t("lobby.player_name"), 16, UiTheme.TEXT_DIM))
	var name_edit := LineEdit.new()
	name_edit.text = s.player_name
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 44)
	v.add_child(name_edit)
	v.add_child(UiTheme.label(Tr.t("lobby.server"), 16, UiTheme.TEXT_DIM))
	var ip_edit := LineEdit.new()
	ip_edit.text = s.server_address
	ip_edit.custom_minimum_size = Vector2(0, 44)
	v.add_child(ip_edit)
	var go: Button = UiKit.primary_button(Tr.t("lobby.connect"), "", Vector2(0, 48))
	go.pressed.connect(func() -> void:
		s.player_name = name_edit.text.strip_edges() if name_edit.text.strip_edges() != "" else Tr.t("lobby.default_name")
		s.server_address = ip_edit.text.strip_edges()
		s.save_settings()
		Net.player_name = s.player_name
		_set_status(Tr.t("lobby.connecting", [s.server_address]))
		var addr: String = s.server_address
		var port: int = Protocol.DEFAULT_PORT
		if addr.contains(":"):
			port = int(addr.get_slice(":", 1))
			addr = addr.get_slice(":", 0)
		var err: int = Net.connect_to(addr, port)
		if err != OK:
			_set_status(Tr.t("lobby.connect_error", [err]), true))
	v.add_child(go)
	var back: Button = UiKit.back_button()
	back.pressed.connect(func() -> void: SceneFader.go(get_tree(), "res://scenes/menu/main_menu.tscn"))
	v.add_child(back)
	go.grab_focus.call_deferred()


# ---------------------------------------------------------------- 2) criar / entrar

func _show_menu() -> void:
	var v: VBoxContainer = _new_panel(Tr.t("lobby.rooms"), "users")
	var create: Button = UiKit.primary_button(Tr.t("lobby.create"), "plus", Vector2(0, 48))
	create.pressed.connect(func() -> void:
		var rules: Dictionary = Protocol.default_rules()
		Net.create_room(rules, get_node("/root/GameState").truck_descriptor()))
	v.add_child(create)
	v.add_child(UiTheme.label(Tr.t("lobby.join_hint"), 16, UiTheme.TEXT_DIM))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "KX4T9Q"
	_code_edit.max_length = 6
	_code_edit.custom_minimum_size = Vector2(300, 52)
	_code_edit.add_theme_font_size_override("font_size", 28)
	v.add_child(_code_edit)
	var join: Button = UiTheme.button(Tr.t("lobby.join"), Vector2(0, 48))
	join.pressed.connect(func() -> void:
		Net.join_room(_code_edit.text.strip_edges().to_upper(), get_node("/root/GameState").truck_descriptor()))
	v.add_child(join)
	var leave: Button = UiTheme.button(Tr.t("lobby.disconnect"), Vector2(0, 48))
	leave.pressed.connect(func() -> void:
		Net.disconnect_from()
		_show_connect())
	v.add_child(leave)
	create.grab_focus.call_deferred()


# ---------------------------------------------------------------- 3) sala

func _show_room() -> void:
	var v: VBoxContainer = _new_panel(Tr.t("lobby.room", [Net.room_code]), "users", 600.0)
	v.add_child(UiTheme.label(Tr.t("lobby.share"), 15, UiTheme.TEXT_DIM))
	_members_box = VBoxContainer.new()
	v.add_child(_members_box)
	_rules_box = VBoxContainer.new()
	v.add_child(_rules_box)
	_ready_btn = UiTheme.button(Tr.t("lobby.ready"), Vector2(150, 48))
	_ready_btn.pressed.connect(func() -> void: Net.set_ready(not _my_ready()))
	_foot.add_child(_ready_btn)
	_start_btn = UiKit.primary_button(Tr.t("lobby.start"), "flag", Vector2(0, 48))
	_start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_start_btn.pressed.connect(func() -> void: Net.start_race())
	_foot.add_child(_start_btn)
	var leave: Button = UiTheme.button(Tr.t("lobby.leave"), Vector2(170, 48))
	leave.pressed.connect(func() -> void:
		Net.leave_room()
		_show_menu())
	_foot.add_child(leave)


## `--lobby-demo`: sala de mentira (2 jogadores, voce e o anfitriao) so para ver o layout; nada vai a rede.
func _show_room_demo() -> void:
	Net.room_code = "KX4T9Q"
	Net.my_peer_id = 1
	Net.lobby = {"members": [{"peer": 1, "name": "Marco", "host": true, "ready": true},
			{"peer": 2, "name": "Ana", "host": false, "ready": false}], "rules": Protocol.default_rules(), "state": 0}
	_show_room()
	_on_lobby(Net.lobby)


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
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		line.add_child(l)
		var ready: bool = bool(m["ready"])
		if not ready:
			all_ready = false
		line.add_child(UiTheme.label(Tr.t("lobby.is_ready") if ready else Tr.t("lobby.waiting"), 18, UiTheme.GOOD if ready else UiTheme.TEXT_DIM))
		_members_box.add_child(line)
	if members.size() > _last_members:
		AudioBus.play_ui("player_join")
	elif members.size() < _last_members:
		AudioBus.play_ui("player_leave")
	_last_members = members.size()
	if all_ready and not _was_all_ready and members.size() > 1:
		AudioBus.play_ui("all_ready")
	_was_all_ready = all_ready
	_ready_btn.text = Tr.t("lobby.cancel_ready") if _my_ready() else Tr.t("lobby.ready")
	_start_btn.visible = _is_host()
	_start_btn.disabled = not all_ready
	_build_rules(state["rules"], _is_host())
	if (state["members"] as Array).size() >= 3:              # T-156: 3-4 jogadores = comboio (transito mais leve)
		_rules_box.add_child(UiTheme.label(Tr.t("lobby.convoy"), 13, UiTheme.GOLD))


func _build_rules(rules: Dictionary, editable: bool) -> void:
	for c in _rules_box.get_children():
		c.queue_free()
	_rules_box.add_child(UiTheme.label(Tr.t("lobby.rules") + ("" if editable else Tr.t("lobby.rules_host")), 17, UiTheme.CYAN))
	var routes: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
	var names: Array = []
	for r in routes:
		names.append(Tr.t("route." + r))
	_option(names, maxi(routes.find(String(rules["route"])), 0), editable, func(i: int) -> void: _send_rules({"route": routes[i]}))
	_option([Tr.t("lobby.damage_real"), Tr.t("lobby.damage_race")], int(rules["damage"]), editable, func(i: int) -> void: _send_rules({"damage": i}))
	_option([Tr.t("lobby.traffic_light"), Tr.t("lobby.traffic_normal"), Tr.t("lobby.traffic_heavy")], int(rules["traffic"]), editable,
			func(i: int) -> void: _send_rules({"traffic": i}))
	var bots: Array = []
	for b in 4:
		bots.append(Tr.t("lobby.bots", [b]))
	_option(bots, int(rules["bots"]), editable, func(i: int) -> void: _send_rules({"bots": i}))


func _option(items: Array, selected: int, editable: bool, on_pick: Callable) -> void:
	var opt := OptionButton.new()
	for it in items:
		opt.add_item(String(it))
	opt.selected = selected
	opt.disabled = not editable
	opt.item_selected.connect(on_pick)
	_rules_box.add_child(opt)


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
