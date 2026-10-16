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
	_show_main()


func _clear_panel() -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_panel)


func _show_main() -> void:
	_clear_panel()
	var title := UiTheme.label(Tr.t("game.title"), 54, UiTheme.PINK)
	title.position = Vector2(48, 36)
	_panel.add_child(title)
	var sub := UiTheme.label(Tr.t("game.subtitle"), 26, UiTheme.CYAN)
	sub.position = Vector2(52, 100)
	_panel.add_child(sub)
	var box := VBoxContainer.new()
	box.position = Vector2(48, 170)
	box.custom_minimum_size = Vector2(300, 0)
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
		var b: Button = UiTheme.button(String(it[0]), Vector2(300, 54))
		b.pressed.connect(it[1])
		box.add_child(b)
	var gs: Node = get_node("/root/GameState")
	var info := UiTheme.label("%s    Fama %d" % [Tr.yen(gs.money()), gs.fame()], 20, UiTheme.GOLD)
	info.position = Vector2(48, 490)
	_panel.add_child(info)
	var code := UiTheme.label("Código do jogador: %s" % gs.profile["player_code"], 14, UiTheme.TEXT_DIM)
	code.position = Vector2(620, 505)
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
	var s: Node = get_node("/root/Settings")
	var panel := PanelContainer.new()
	panel.position = Vector2(40, 30)
	panel.custom_minimum_size = Vector2(520, 0)
	_panel.add_child(panel)
	var v := VBoxContainer.new()
	panel.add_child(v)
	v.add_child(UiTheme.label(Tr.t("options.title"), 30, UiTheme.PINK))
	v.add_child(UiTheme.label(Tr.t("options.touch_size"), 18))
	var hs := HSlider.new()
	hs.min_value = 0.7
	hs.max_value = 1.5
	hs.step = 0.05
	hs.value = s.touch_scale
	hs.custom_minimum_size = Vector2(300, 30)
	hs.value_changed.connect(func(val: float) -> void:
		s.touch_scale = val
		s.save_settings())
	v.add_child(hs)
	var tilt := CheckButton.new()
	tilt.text = Tr.t("options.tilt")
	tilt.button_pressed = s.use_tilt
	tilt.toggled.connect(func(on: bool) -> void:
		s.use_tilt = on
		s.save_settings())
	v.add_child(tilt)
	var inv := CheckButton.new()
	inv.text = Tr.t("options.tilt_invert")
	inv.button_pressed = s.tilt_invert
	inv.toggled.connect(func(on: bool) -> void:
		s.tilt_invert = on
		s.save_settings())
	v.add_child(inv)
	v.add_child(UiTheme.label("Qualidade gráfica (baixa = mais FPS no celular)", 18))
	var qual := OptionButton.new()
	for qn in ["Baixa", "Média", "Alta"]:
		qual.add_item(qn)
	qual.selected = s.quality
	qual.item_selected.connect(func(i: int) -> void:
		s.quality = i
		s.save_settings())
	v.add_child(qual)
	var fps := CheckButton.new()
	fps.text = "Mostrar FPS na corrida"
	fps.button_pressed = s.show_fps
	fps.toggled.connect(func(on: bool) -> void:
		s.show_fps = on
		s.save_settings())
	v.add_child(fps)
	v.add_child(UiTheme.label(Tr.t("options.music"), 18))
	var ms := HSlider.new()
	ms.min_value = 0.0
	ms.max_value = 1.0
	ms.step = 0.05
	ms.value = s.music_volume
	ms.value_changed.connect(func(val: float) -> void:
		s.music_volume = val
		s.save_settings()
		AudioBus.apply_settings())
	v.add_child(ms)
	v.add_child(UiTheme.label(Tr.t("options.sfx"), 18))
	var fs := HSlider.new()
	fs.min_value = 0.0
	fs.max_value = 1.0
	fs.step = 0.05
	fs.value = s.sfx_volume
	fs.value_changed.connect(func(val: float) -> void:
		s.sfx_volume = val
		s.save_settings()
		AudioBus.apply_settings())
	v.add_child(fs)
	v.add_child(UiTheme.label("Código do jogador (use o mesmo em outro aparelho para ter a mesma garagem)", 14, UiTheme.TEXT_DIM))
	var code_row := HBoxContainer.new()
	v.add_child(code_row)
	var code_edit := LineEdit.new()
	code_edit.text = String(get_node("/root/GameState").profile["player_code"])
	code_edit.max_length = 12
	code_edit.custom_minimum_size = Vector2(240, 44)
	code_row.add_child(code_edit)
	var code_btn: Button = UiTheme.button("USAR CÓDIGO", Vector2(180, 44))
	code_btn.pressed.connect(func() -> void:
		var new_code: String = code_edit.text.strip_edges().to_upper()
		if new_code.length() >= 6 and new_code != String(get_node("/root/GameState").profile["player_code"]):
			get_node("/root/GameState").adopt_player_code(new_code)
			stage.refresh_truck()
			_show_main())
	code_row.add_child(code_btn)
	var reset: Button = UiTheme.button(Tr.t("options.reset"))
	reset.pressed.connect(func() -> void:
		get_node("/root/GameState").new_profile()
		stage.refresh_truck()
		_show_main())
	v.add_child(reset)
	var back: Button = UiTheme.button(Tr.t("menu.back"))
	back.pressed.connect(_show_main)
	v.add_child(back)
