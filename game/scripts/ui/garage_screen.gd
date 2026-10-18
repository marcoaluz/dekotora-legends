extends Node3D
## Garagem: galpao 3D com o caminhao na plataforma (camera orbital: arrastar gira, roda do mouse aproxima).
## Topo = titulo + saldo/fama. Esquerda = abas MODELO / PECAS / MECANICA / REPARO e a lista da aba.
## Direita = ficha tecnica real (GarageInfoPanel) ou as pecas do encaixe escolhido.
## Embaixo = VOLTAR e botoes de vista (frente, lado, traseira, teto, rodas, girar).

const TABS: Array = [["model", "garage.tab_model", "truck"], ["parts", "garage.deco", "paintbrush"],
		["mech", "garage.mechanics", "cog"], ["repair", "garage.repair", "hammer"]]
const VIEWS: Array = [["front", "view.front"], ["side", "view.side"], ["rear", "view.rear"],
		["roof", "view.roof"], ["wheel", "view.wheel"], ["default", "view.rotate"]]
const BODIES: Array = ["canter", "leve", "base", "longo"]
const CABS: Array = TruckNode.CABS

var stage: GarageStage
var gs: Node
var shop: GarageShop
var _tab: String = "model"
var _slot: String = ""
var _left: VBoxContainer
var _right: VBoxContainer
var _chips: HBoxContainer
var _tab_buttons: Dictionary = {}
var _msg: Label
var _day_btn: Button
var _ui_layer: CanvasLayer
var _preview_cache: Dictionary = {}


func _ready() -> void:
	AudioBus.play_music("garage_chill")
	gs = get_node("/root/GameState")
	shop = GarageShop.new(gs, _preview, _flash)
	stage = GarageStage.new()
	add_child(stage)
	shop.live_decals = func(list: Array) -> void: stage.truck.apply_decals(list)
	shop.focus_view = func(view: String) -> void: stage.focus_view(view)
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui_layer = layer
	var root := Control.new()
	root.theme = UiTheme.make()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	var title: HBoxContainer = UiKit.screen_title(Tr.t("garage.title"), "house")
	title.position = Vector2(22, 12)
	root.add_child(title)
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_END
	_chips.position = Vector2(400, 12)
	_chips.size = Vector2(544, 40)
	root.add_child(_chips)
	_left = _column(root, Vector2(16, 62), true)
	_right = _column(root, Vector2(644, 62), false)
	_build_bottom(root)
	gs.profile_changed.connect(_refresh)
	_apply_debug_args()
	_refresh()


## Painel lateral de vidro com rolagem; o da esquerda leva as abas no topo.
func _column(root: Control, pos: Vector2, with_tabs: bool) -> VBoxContainer:
	var p: PanelContainer = UiKit.glass_panel(0.84)
	p.position = pos
	p.size = Vector2(300, 408)
	p.custom_minimum_size = Vector2(300, 408)
	root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	if with_tabs:
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 4)
		for t in TABS:
			var b: Button = UiTheme.button(Tr.t(String(t[1])), Vector2(64, 58))
			b.icon = UiKit.icon(String(t[2]))
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_theme_font_size_override("font_size", 13)
			b.add_theme_constant_override("icon_max_width", 22)
			var id: String = String(t[0])
			b.pressed.connect(func() -> void: _set_tab(id))
			tabs.add_child(b)
			_tab_buttons[id] = b
		v.add_child(tabs)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	sc.add_child(box)
	return box


func _build_bottom(root: Control) -> void:
	var back: Button = UiKit.back_button(Vector2(150, 44))
	back.position = Vector2(16, 482)
	back.pressed.connect(func() -> void: SceneFader.go(get_tree(), "res://scenes/menu/main_menu.tscn"))
	root.add_child(back)
	var strip: PanelContainer = UiKit.glass_panel(0.75)
	strip.position = Vector2(326, 480)
	root.add_child(strip)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	strip.add_child(h)
	h.add_child(UiKit._icon_rect("camera", 18, UiTheme.TEXT_DIM))
	for vw in VIEWS:
		var b: Button = UiTheme.button(Tr.t(String(vw[1])), Vector2(0, 30))
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 8))
		var id: String = String(vw[0])
		b.pressed.connect(func() -> void: stage.focus_view(id))
		h.add_child(b)
	var dn: Button = UiTheme.button(Tr.t("garage.preview_night"), Vector2(0, 30))
	dn.add_theme_font_size_override("font_size", 14)
	dn.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.2), UiTheme.PINK, 1, 6, 8))
	_day_btn = dn
	dn.pressed.connect(func() -> void:
		stage.set_daytime(not stage.day)
		_refresh())
	h.add_child(dn)
	_msg = UiKit.heading("", 18, UiTheme.CYAN, false)
	_msg.position = Vector2(330, 446)
	root.add_child(_msg)


## Argumentos de depuracao: --demo (monta um caminhao cheio de pecas; --noparts = sem pecas; --cab=<estilo>; --body=<modelo>), --tab=model|parts|mech|repair, --slot=<slot>, --damage
func _apply_debug_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--demo" in args:
		gs.save_path = "user://demo_profile.json"        # a depuracao NUNCA grava por cima do perfil real do jogador
		gs.new_profile()
		gs.profile["money"] = 900000
		gs.profile["fame"] = 500
		for id in ["fb_gold_wing", "visor_gold_lights", "roof_lights_crown", "skirt_light_bar", "andon_kanji", "rb_chrome", "mural_lightning", "hub_chrome",
				"grille_frame_chrome", "aux_round_lamps_pair", "front_crest_ornament", "roof_torii_ornament", "fender_extension", "side_ornament_wave", "rear_lamp_cluster", "mudflap_designed"]:
			var d: PartDef = gs.part(id)
			if "--noparts" in args:                    # so o caminhao de fabrica (capturas da cabine)
				break
			if d != null and gs.buy(d):
				gs.install(id)
	if "--damage" in args:
		for id in gs.profile["owned"]:
			var d2: PartDef = gs.part(String(id))
			if d2.durability > 0.0:
				gs.profile["owned"][id]["dur"] = d2.durability * 0.4
		gs.profile["owned"]["rb_chrome"]["broken"] = true
		gs.profile["systems"]["engine"] = 55.0
	for a in args:
		if a == "--decals":
			gs.profile["decals"] = [
				{"id": "kanji_bakusou", "slot": "side_l", "x": -0.5, "y": 0.0, "size": 0.5, "color": "#f5cc5a"},
				{"id": "estrela", "slot": "side_r", "x": 0.3, "y": 0.0, "size": 0.45, "color": "#ff2e88"},
				{"id": "raio", "slot": "rear", "x": 0.0, "y": 0.0, "size": 0.7, "color": "#21e6ff"},
				{"id": "sol", "slot": "cab", "x": 0.0, "y": 0.1, "size": 0.5, "color": "#ffffff"}]
			stage.refresh_truck()
		elif a.begins_with("--lights="):
			gs.profile["light_pattern"] = a.substr(9)
			stage.refresh_truck()
			stage.truck.set_light_pattern(a.substr(9))
		elif a == "--hideui":
			_ui_layer.visible = false
		elif a == "--day":
			stage.set_daytime(true)
		elif a.begins_with("--view="):
			stage.focus_view(a.substr(7))
		elif a.begins_with("--cab=") and "--demo" in args:    # so com --demo (perfil de teste, nunca o real)
			stage.set_cab(a.substr(6))
		elif a.begins_with("--body=") and "--demo" in args:   # --body=canter (T-125)
			stage.set_body(a.substr(7))
		elif a.begins_with("--parts=") and "--demo" in args:  # --parts=kw_bumper,fumi_wing (T-126): compra e instala
			for pid in a.substr(8).split(","):
				var pd: PartDef = gs.part(pid)
				if pd != null and (gs.owns(pid) or gs.buy(pd)):
					gs.install(pid)
			stage.refresh_truck()
		elif a.begins_with("--zoom="):                      # aproxima a camera (capturas de detalhe)
			var z: float = float(a.substr(7))
			get_tree().create_timer(1.0).timeout.connect(func() -> void: stage.set_zoom(z))   # depois do layout
		elif a.begins_with("--shot="):          # captura de tela depois de 6 s (camera assentada) e fecha (depuracao)
			var path: String = a.substr(7)
			get_tree().create_timer(6.0).timeout.connect(func() -> void: _take_shot(path))
		elif a.begins_with("--tab="):
			_tab = a.substr(6)
		elif a.begins_with("--slot="):
			_tab = "parts"
			_slot = a.substr(7)
			stage.focus_slot(_slot)


func _take_shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURA: ", path)
	get_tree().quit()


func _set_tab(t: String) -> void:
	_tab = t
	_slot = ""
	stage.focus_default()
	_refresh()


func _clear(c: Control) -> void:
	for n in c.get_children():
		c.remove_child(n)
		n.queue_free()


func _refresh() -> void:
	_preview_cache.clear()
	if _day_btn != null:
		_day_btn.text = Tr.t("garage.preview_day") if stage.day else Tr.t("garage.preview_night")
	stage.refresh_truck()
	stage.set_layout(true)
	_clear(_left)
	_clear(_right)
	_clear(_chips)
	_chips.add_child(UiKit.chip("coins", Tr.yen(gs.money()), UiTheme.GOLD))
	_chips.add_child(UiKit.chip("star", "%s %d" % [Tr.t("hud.fame"), gs.fame()]))
	_chips.add_child(UiKit.chip("trophy", "%s %d" % [Tr.t("garage.destaque"), gs.destaque()], UiTheme.PINK))
	for k in _tab_buttons:
		var on: bool = k == _tab
		var b: Button = _tab_buttons[k]
		b.add_theme_color_override("font_color", UiTheme.PINK if on else UiTheme.TEXT)
		b.add_theme_color_override("icon_normal_color", UiTheme.PINK if on else Color(1, 1, 1, 0.8))
	match _tab:
		"model":
			_build_model()
		"parts":
			shop.build_deco_header(_left)
			shop.build_decals(_left)
			_left.add_child(UiKit.heading(Tr.t("garage.parts").to_upper(), 18, UiTheme.PINK))
			_build_slots()
		"mech":
			shop.build_mech(_left)
		"repair":
			shop.build_repair(_left)
	if _tab == "parts" and _slot != "":
		shop.build_slot_detail(_right, _slot)
	else:
		GarageInfoPanel.build(_right, gs, _preview({}), func() -> void: _set_tab("parts"))


func _preview(changes: Dictionary) -> Dictionary:
	var key: String = JSON.stringify(changes)
	if not _preview_cache.has(key):
		_preview_cache[key] = gs.preview(changes)
	return _preview_cache[key]


func _flash(text: String) -> void:
	_msg.text = text
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_callback(func() -> void: _msg.text = "")


# ---------------------------------------------------------------- aba MODELO (carroceria + cabine)

func _build_model() -> void:
	_left.add_child(UiKit.heading(Tr.t("garage.body").to_upper(), 18, UiTheme.PINK))
	for k in BODIES:
		_choice_card("body", String(k), "base", func() -> void: stage.set_body(String(k)))
	_left.add_child(UiKit.heading(Tr.t("garage.cab").to_upper(), 18, UiTheme.PINK))
	var body: String = String(gs.profile.get("body", "base"))
	if TruckNode.FIXED_CAB.has(body):              # o Canter so tem a cabine dele (a escolha do perfil fica guardada)
		var note: Label = UiTheme.label(Tr.t("garage.cab_fixed"), 15, UiTheme.TEXT_DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(220, 0)
		_left.add_child(note)
		return
	for k in CABS:
		_choice_card("cab", String(k), "padrao", func() -> void: stage.set_cab(String(k)))


## Cartao selecionavel (estilo da lista de veiculos da referencia): nome + descricao; o atual fica com borda rosa.
func _choice_card(field: String, kind: String, default_kind: String, apply: Callable) -> void:
	var cur: bool = String(gs.profile.get(field, default_kind)) == kind
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "%s\n%s" % [Tr.t(field + "." + kind), Tr.t(field + ".desc." + kind)]
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.14) if cur else Color(1, 1, 1, 0.04), UiTheme.PINK if cur else Color(1, 1, 1, 0.1), 1, 8, 12))
	b.add_theme_color_override("font_color", Color.WHITE if cur else UiTheme.TEXT)
	b.pressed.connect(func() -> void:
		AudioBus.play_ui("ui_select")
		apply.call()
		gs.save_profile()
		_refresh())
	_left.add_child(b)


# ---------------------------------------------------------------- aba PECAS

func _build_slots() -> void:
	for slot in gs.slots():
		var inst: String = gs.installed_id(String(slot))
		var sub: String = Tr.t("part." + inst) if inst != "" else "— " + Tr.t("garage.empty")
		var sel: bool = String(slot) == _slot
		var b := Button.new()
		b.text = "%s\n%s" % [Tr.t("slot." + String(slot)), sub]
		b.custom_minimum_size = Vector2(0, 50)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.14) if sel else Color(1, 1, 1, 0.04), UiTheme.PINK if sel else Color(1, 1, 1, 0.08), 1, 8, 12))
		b.add_theme_color_override("font_color", UiTheme.GOLD if inst != "" else UiTheme.TEXT)
		b.pressed.connect(func() -> void:
			AudioBus.play_ui("ui_select")
			_slot = "" if _slot == String(slot) else String(slot)   # tocar de novo fecha e volta a ficha
			if _slot != "":
				stage.focus_slot(_slot)
			else:
				stage.focus_default()
			_refresh())
		_left.add_child(b)
