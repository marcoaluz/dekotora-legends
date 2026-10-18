extends Node3D
## Tela inicial: logo, caminhao do jogador em destaque (fundo 3D MenuBackdrop: posto a noite ou rodovia,
## `--menu-bg=a|b|hall`) e menu com acoes reais: Continuar (proximo frete liberado), Nova carreira (com
## confirmacao), Garagem, Mercado de fretes, Multiplayer, Corrida rapida, Configuracoes e Sair.
## Saldo e fama no topo direito; progresso e codigo do jogador no rodape. Layout por containers (T-138).
## Depuracao: --screen=options|market|newcareer, --shot=ARQUIVO.png [--shot-delay=S].

var stage: MenuBackdrop
var _ui: Control
var _panel: Control


func _ready() -> void:
	AudioBus.play_music("menu_citypop")
	get_node("/root/GameState").pending_contract = {}   # corrida abandonada nao leva o contrato adiante
	stage = MenuBackdrop.create()
	add_child(stage)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.theme = UiTheme.make()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	var screen: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="):
			screen = a.substr(9)
	match screen:
		"options":
			_show_options()
		"market", "campaign":
			_show_market()
		"newcareer":
			_show_main()
			_confirm_new_career()
		_:
			_show_main()
	DebugShot.arm(self)


func _clear_panel() -> void:
	if _panel != null:
		_panel.queue_free()
	_panel = Control.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_panel)


## Proximo frete: o primeiro liberado e ainda nao vencido; null se todos ja foram vencidos.
func _next_route() -> RouteDef:
	var gs: Node = get_node("/root/GameState")
	for r in FreightMarket.all_routes():
		if gs.route_unlocked(r) and not gs.route_won(String(r.id)):
			return r
	return null


func _show_main() -> void:
	_clear_panel()
	stage.focus_hero()
	var gs: Node = get_node("/root/GameState")
	# faixa escura a esquerda (leitura do menu) com degrade para a direita; presa a esquerda, altura toda
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(0.02, 0.03, 0.07, 0.9), Color(0.02, 0.03, 0.07, 0.6), Color(0.02, 0.03, 0.07, 0.0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_to = Vector2(1, 0)
	var scrim := TextureRect.new()
	scrim.texture = gt
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.anchor_bottom = 1.0
	scrim.offset_right = 600.0
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(scrim)
	var margin: MarginContainer = UiKit.screen_margin(32, 16)
	_panel.add_child(margin)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(row)
	# coluna esquerda: logo, menu, rodape (progresso)
	var left := VBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_theme_constant_override("separation", 6)
	row.add_child(left)
	left.add_child(UiKit.logo(0.9))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	left.add_child(box)
	var items: Array = [
		[Tr.t("menu.continue"), "play", _continue],
		[Tr.t("menu.new_career"), "rotate-ccw", _confirm_new_career],
		[Tr.t("menu.garage"), "warehouse", func() -> void: SceneFader.go(get_tree(), "res://scenes/garage/garage.tscn")],
		[Tr.t("menu.market"), "package", _show_market],
		[Tr.t("menu.multiplayer"), "users", func() -> void: SceneFader.go(get_tree(), "res://scenes/lobby/lobby.tscn")],
		[Tr.t("menu.race_quick"), "flag", _quick_race],
		[Tr.t("menu.settings"), "settings", _show_options],
		[Tr.t("menu.quit"), "log-out", func() -> void: get_tree().quit()],
	]
	var first: Button = null
	for it in items:
		var b: Button = UiKit.nav_button(String(it[0]), String(it[1]), Vector2(330, 38))
		b.pressed.connect(it[2])
		box.add_child(b)
		if first == null:
			first = b
	first.grab_focus.call_deferred()
	left.add_child(UiKit.spacer(true))
	var next: RouteDef = _next_route()
	var done: int = (gs.profile["routes_done"] as Dictionary).size()
	var total: int = FreightMarket.all_routes().size()
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 0)
	foot.add_child(UiTheme.label(Tr.t("menu.progress", [done, total]), 14, UiTheme.TEXT_DIM))
	var nxt: String = Tr.t("menu.next", [Tr.t("route." + String(next.id))]) if next != null else Tr.t("menu.all_done")
	foot.add_child(UiTheme.label(nxt, 14, UiTheme.CYAN))
	left.add_child(foot)
	row.add_child(UiKit.spacer())
	# coluna direita: saldo e fama no topo, codigo do jogador embaixo
	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.alignment = BoxContainer.ALIGNMENT_END
	chips.add_child(UiKit.chip("coins", Tr.yen(gs.money()), UiTheme.GOLD))
	chips.add_child(UiKit.chip("star", "%s %d" % [Tr.t("hud.fame"), gs.fame()]))
	right.add_child(chips)
	right.add_child(UiKit.spacer(true))
	var code: Label = UiTheme.label(Tr.t("menu.player_code", [String(gs.profile["player_code"])]), 13, UiTheme.TEXT_DIM)
	code.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(code)


func _continue() -> void:
	var r: RouteDef = _next_route()
	if r == null:                                 # tudo vencido: abre o mercado para escolher
		_show_market()
		return
	var gs: Node = get_node("/root/GameState")
	if not bool(gs.rival_refusal(String(r.id)).get("ok", true)):   # o rival recusa: o mercado mostra a fala e o que falta
		_show_market()
		return
	gs.pending_route = r
	for c in gs.contract_board():                 # usa o melhor contrato do trecho que cabe no bau
		if String(c["route"]) == String(r.id) and gs.contract_block_reason(c) == "":
			if gs.pending_contract.is_empty() or int(c["reward"]) > int(gs.pending_contract["reward"]):
				gs.pending_contract = (c as Dictionary).duplicate()
	SceneFader.go(get_tree(), "res://scenes/race/race3d.tscn")


func _quick_race() -> void:
	var gs: Node = get_node("/root/GameState")
	gs.pending_route = null
	gs.pending_contract = {}
	SceneFader.go(get_tree(), "res://scenes/race/race3d.tscn")


func _show_market() -> void:
	_clear_panel()
	stage.focus_default()
	var fm := FreightMarket.new()
	fm.back_pressed.connect(_show_main)
	fm.contract_chosen.connect(func(c: Dictionary) -> void:
		get_node("/root/GameState").accept_contract(c)
		SceneFader.go(get_tree(), "res://scenes/race/race3d.tscn"))
	_panel.add_child(fm)


func _confirm_new_career() -> void:
	var shade := ColorRect.new()                  # modal: escurece o fundo e bloqueia cliques
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.add_child(center)
	var p: PanelContainer = UiKit.glass_panel(0.96)
	p.custom_minimum_size = Vector2(460, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	v.add_child(UiKit.screen_title(Tr.t("menu.new_career_q"), "rotate-ccw"))
	var warn: Label = UiTheme.label(Tr.t("menu.new_career_warn"), 17, UiTheme.TEXT_DIM)
	warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	warn.custom_minimum_size = Vector2(430, 0)
	v.add_child(warn)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	var cancel: Button = UiTheme.button(Tr.t("menu.cancel"), Vector2(150, 46))
	cancel.pressed.connect(shade.queue_free)
	row.add_child(cancel)
	var ok: Button = UiKit.primary_button(Tr.t("menu.confirm"), "", Vector2(200, 46))
	ok.pressed.connect(func() -> void:
		var gs: Node = get_node("/root/GameState")
		gs.new_profile()
		stage.set_body(String(gs.profile.get("body", "base")))
		_show_main())
	row.add_child(ok)
	v.add_child(row)
	cancel.grab_focus.call_deferred()             # o foco comeca no botao seguro


func _show_options() -> void:
	_clear_panel()
	stage.focus_default()
	var op := OptionsPanel.new()
	op.back_pressed.connect(_show_main)
	op.profile_changed.connect(func() -> void:
		stage.refresh_truck()
		_show_main())
	_panel.add_child(op)
