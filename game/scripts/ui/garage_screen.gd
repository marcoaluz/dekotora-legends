extends Node3D
## Garagem: galpao 3D com o caminhao na plataforma (camera orbital: arrastar gira, roda do mouse aproxima).
## Topo = titulo + saldo/fama. Esquerda = abas MODELO / DECORACAO / MECANICA / REPARO e a lista da aba.
## Direita = ficha tecnica real (GarageInfoPanel) ou as pecas do encaixe escolhido.
## Embaixo = VOLTAR, botoes de vista, "Ver em movimento" (rodas) e previa dia/noite.
## Layout por containers (T-138): cabe em 960x540 e em celular comprido (20:9) sem cortar nada.

const TABS: Array = [["model", "garage.tab_model", "truck"], ["parts", "garage.deco", "paintbrush"],
		["mech", "garage.mechanics", "cog"], ["repair", "garage.repair", "hammer"]]
const VIEWS: Array = [["front", "view.front"], ["side", "view.side"], ["rear", "view.rear"],
		["roof", "view.roof"], ["wheel", "view.wheel"], ["default", "view.rotate"]]
const BODIES: Array = ["canter", "leve", "base", "longo"]
const CABS: Array = TruckNode.CABS
const PANEL_W: float = 284.0

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
var _spin_btn: Button
var _ui_layer: CanvasLayer
var _preview_cache: Dictionary = {}
var _last_wheel_part: String = "?"          # roda/calota instalada no ultimo redesenho (instalar uma nova liga o giro)


func _ready() -> void:
	AudioBus.play_music("garage_chill")
	gs = get_node("/root/GameState")
	shop = GarageShop.new(gs, _preview, _flash)
	stage = GarageStage.new()
	add_child(stage)
	shop.live_decals = func(list: Array) -> void: stage.truck.apply_decals(list)
	shop.focus_view = func(view: String) -> void: stage.focus_view(view)
	_ui_layer = CanvasLayer.new()
	add_child(_ui_layer)
	var root := Control.new()
	root.theme = UiTheme.make()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE      # o centro livre deixa o arraste/toque chegar ao palco 3D
	_ui_layer.add_child(root)
	var margin: MarginContainer = UiKit.screen_margin(16, 10)
	root.add_child(margin)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(UiKit.screen_title(Tr.t("garage.title"), "house"))
	top.add_child(UiKit.spacer())
	_chips = HBoxContainer.new()
	_chips.alignment = BoxContainer.ALIGNMENT_END
	top.add_child(_chips)
	vb.add_child(top)
	var mid := HBoxContainer.new()
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(mid)
	_left = _column(mid, true)
	var center := VBoxContainer.new()                 # meio livre (caminhao) com o aviso embaixo
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_END
	mid.add_child(center)
	_msg = UiKit.heading("", 18, UiTheme.CYAN, false)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_msg)
	_right = _column(mid, false)
	_build_bottom(vb)
	stage.wheel_spin_changed.connect(func(_on: bool) -> void: _update_spin_button())
	var dbg: Dictionary = GarageDebug.apply(self, gs, stage, _ui_layer)
	_tab = String(dbg.get("tab", _tab))
	_slot = String(dbg.get("slot", _slot))
	gs.profile_changed.connect(_refresh)               # depois da depuracao: montar o caminhao demo nao conta como "roda nova"
	_refresh()


## Painel lateral de vidro com rolagem; o da esquerda leva as abas no topo.
func _column(parent: Control, with_tabs: bool) -> VBoxContainer:
	var p: PanelContainer = UiKit.glass_panel(0.82)
	p.custom_minimum_size = Vector2(PANEL_W, 0)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	if with_tabs:
		var tabs := HBoxContainer.new()
		tabs.add_theme_constant_override("separation", 4)
		for t in TABS:
			var b: Button = UiTheme.button(Tr.t(String(t[1])), Vector2(0, 58))
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.icon = UiKit.icon(String(t[2]))
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			b.add_theme_font_size_override("font_size", 12)
			b.add_theme_constant_override("icon_max_width", 22)
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(0.1, 0.1, 0.2, 0.82), Color(1, 1, 1, 0.14), 1, 10, 2))
			b.add_theme_stylebox_override("hover", UiTheme.box(Color(0.14, 0.15, 0.3, 0.92), UiTheme.CYAN, 1, 10, 2))
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


func _build_bottom(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	var back: Button = UiKit.back_button(Vector2(140, 44))
	back.pressed.connect(func() -> void: SceneFader.go(get_tree(), "res://scenes/menu/main_menu.tscn"))
	row.add_child(back)
	row.add_child(UiKit.spacer())
	var strip: PanelContainer = UiKit.glass_panel(0.75)
	row.add_child(strip)
	row.add_child(UiKit.spacer())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	strip.add_child(h)
	h.add_child(UiKit._icon_rect("camera", 18, UiTheme.TEXT_DIM))
	for vw in VIEWS:
		var b: Button = _strip_button(Tr.t(String(vw[1])))
		var id: String = String(vw[0])
		b.pressed.connect(func() -> void: stage.focus_view(id))
		h.add_child(b)
	_spin_btn = _strip_button("")
	_spin_btn.add_theme_constant_override("icon_max_width", 16)
	_spin_btn.pressed.connect(func() -> void: stage.toggle_wheel_spin())
	h.add_child(_spin_btn)
	_update_spin_button()
	var dn: Button = _strip_button(Tr.t("garage.preview_night"))
	dn.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.2), UiTheme.PINK, 1, 6, 8))
	_day_btn = dn
	dn.pressed.connect(func() -> void:
		stage.set_daytime(not stage.day)
		_refresh())
	h.add_child(dn)


func _strip_button(text: String) -> Button:
	var b: Button = UiTheme.button(text, Vector2(0, 30))
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_stylebox_override("normal", UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 7))
	return b


## Texto e icone do botao das rodas: "Ver em movimento" (play) ou "Parar rodas" (pausa, destacado).
func _update_spin_button() -> void:
	if _spin_btn == null:
		return
	var on: bool = stage.wheel_spin
	_spin_btn.text = Tr.t("garage.spin_stop") if on else Tr.t("garage.spin_start")
	_spin_btn.icon = UiKit.icon("pause" if on else "circle-play")
	_spin_btn.add_theme_color_override("font_color", UiTheme.CYAN if on else UiTheme.TEXT)
	_spin_btn.add_theme_color_override("icon_normal_color", UiTheme.CYAN if on else Color(1, 1, 1, 0.85))
	_spin_btn.add_theme_stylebox_override("normal", UiTheme.box(Color(0.13, 0.9, 1, 0.14), UiTheme.CYAN, 1, 6, 7) if on
			else UiTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 7))


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
	_check_new_wheels()
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


## Roda/calota nova instalada: mostra a roda e liga o giro para o jogador ver a peca em movimento.
func _check_new_wheels() -> void:
	var cur: String = gs.installed_id("hubcaps")
	if _last_wheel_part != "?" and cur != _last_wheel_part and cur != "":
		stage.focus_view("wheel")
		stage.set_wheel_spin(true)
	_last_wheel_part = cur


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
		_left.add_child(GarageShop.wl(Tr.t("garage.cab_fixed"), 15, UiTheme.TEXT_DIM))
		return
	for k in CABS:
		_choice_card("cab", String(k), CabCatalog.DEFAULT, func() -> void: stage.set_cab(String(k)))


## Cartao selecionavel (estilo da lista de veiculos da referencia): nome + descricao; o atual fica com borda rosa.
func _choice_card(field: String, kind: String, default_kind: String, apply: Callable) -> void:
	var cur: bool = String(gs.profile.get(field, default_kind)) == kind
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 52)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
