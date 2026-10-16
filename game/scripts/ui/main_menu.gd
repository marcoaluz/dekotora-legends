extends Node3D
## Menu principal: Campanha / Garagem / Opcoes / Sair, sobre o palco 3D do caminhao.
## A campanha lista os 3 trechos de Kanto (bloqueados por Fama) e inicia a corrida.

var stage: GarageStage
var _ui: Control
var _panel: Control


func _ready() -> void:
	AudioBus.play_music("menu_citypop")
	stage = GarageStage.new()
	add_child(stage)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UiTheme.make()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_ui)
	match "".join(OS.get_cmdline_user_args()).replace("--screen=", ""):    # debug: --screen=options|campaign
		"options":
			_show_options()
		"campaign":
			_show_campaign()
		_:
			_show_main()


func _clear_panel() -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_panel)


func _show_main() -> void:
	_clear_panel()
	# faixa escura a esquerda (leitura do texto) com degrade para a direita
	var grad := Gradient.new()
	grad.set_color(0, Color(0.02, 0.02, 0.07, 0.88))
	grad.set_color(1, Color(0.02, 0.02, 0.07, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(1, 0)
	var scrim := TextureRect.new()
	scrim.texture = gt
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.size = Vector2(520, 540)
	_panel.add_child(scrim)
	var title := UiTheme.label(Tr.t("game.title"), 52, Color.WHITE)
	title.position = Vector2(48, 34)
	_panel.add_child(title)
	var bar := ColorRect.new()
	bar.color = UiTheme.PINK
	bar.position = Vector2(52, 104)
	bar.size = Vector2(72, 4)
	_panel.add_child(bar)
	var sub := UiTheme.label(Tr.t("game.subtitle").to_upper(), 22, UiTheme.CYAN)
	sub.position = Vector2(52, 114)
	_panel.add_child(sub)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 150)
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 2)
	_panel.add_child(box)
	var items: Array = [
		[Tr.t("menu.campaign"), _show_campaign],
		[Tr.t("menu.garage"), func() -> void: get_tree().change_scene_to_file("res://scenes/garage/garage.tscn")],
		["MULTIPLAYER", func() -> void: get_tree().change_scene_to_file("res://scenes/lobby/lobby.tscn")],
		[Tr.t("menu.race_quick"), _quick_race],
		[Tr.t("menu.options"), _show_options],
		[Tr.t("menu.quit"), func() -> void: get_tree().quit()],
	]
	for it in items:
		var b: Button = UiTheme.menu_button(String(it[0]), Vector2(320, 46))
		b.pressed.connect(it[1])
		box.add_child(b)
	var gs: Node = get_node("/root/GameState")
	var info := UiTheme.label("%s     FAMA %d" % [Tr.yen(gs.money()), gs.fame()], 20, UiTheme.GOLD)
	info.position = Vector2(52, 502)
	_panel.add_child(info)
	var code := UiTheme.label("Código do jogador: %s" % gs.profile["player_code"], 14, UiTheme.TEXT_DIM)
	code.position = Vector2(700, 510)
	_panel.add_child(code)
	stage.focus_default()


func _quick_race() -> void:
	var gs: Node = get_node("/root/GameState")
	gs.pending_route = null
	get_tree().change_scene_to_file("res://scenes/race/race3d.tscn")


func _show_campaign() -> void:
	_clear_panel()
	var gs: Node = get_node("/root/GameState")
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 30)
	panel.custom_minimum_size = Vector2(500, 480)
	_panel.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UiTheme.label(Tr.t("campaign.title"), 30, UiTheme.PINK))
	var routes: Array[RouteDef] = []
	for f in DirAccess.get_files_at("res://data/routes/"):
		if f.ends_with(".tres"):
			routes.append(load("res://data/routes/" + f) as RouteDef)
	routes.sort_custom(func(a: RouteDef, b: RouteDef) -> bool: return a.freight < b.freight)
	for r in routes:
		var rival: RivalDef = load("res://data/rivals/%s.tres" % r.rival_id) as RivalDef
		var row := VBoxContainer.new()
		var unlocked: bool = gs.route_unlocked(r)
		var head: String = Tr.t("route." + String(r.id))
		if gs.route_won(String(r.id)):
			head += "   ✔ " + Tr.t("campaign.won")
		row.add_child(UiTheme.label(head, 22, UiTheme.TEXT if unlocked else UiTheme.TEXT_DIM))
		var detail: String = "%s: %s    %s: %s" % [Tr.t("campaign.freight"), Tr.yen(r.freight), Tr.t("campaign.rival"), rival.display_name]
		row.add_child(UiTheme.label(detail, 16, UiTheme.GOLD))
		var rec: Dictionary = (gs.profile["routes_done"] as Dictionary).get(String(r.id), {})
		if not rec.is_empty():
			var t: float = float(rec["best_time"])
			row.add_child(UiTheme.label("%s: %d:%05.2f" % [Tr.t("campaign.best"), int(t) / 60, fmod(t, 60.0)], 14, UiTheme.TEXT_DIM))
		var go: Button = UiTheme.button(Tr.t("campaign.start") if unlocked else Tr.t("campaign.locked", [r.fame_required]), Vector2(0, 44))
		go.disabled = not unlocked
		go.pressed.connect(func() -> void:
			gs.pending_route = r
			get_tree().change_scene_to_file("res://scenes/race/race3d.tscn"))
		row.add_child(go)
		v.add_child(row)
	var back: Button = UiTheme.button(Tr.t("menu.back"))
	back.pressed.connect(_show_main)
	v.add_child(back)


func _show_options() -> void:
	_clear_panel()
	var op := OptionsPanel.new()
	op.back_pressed.connect(_show_main)
	op.profile_changed.connect(func() -> void:
		stage.refresh_truck()
		_show_main())
	_panel.add_child(op)
