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
const BODIES: Array = ["canter", "leve", "base", "longo", "graneleira"]
const CABS: Array = TruckNode.CABS
const PANEL_W: float = 284.0

var stage: GarageStage
var gs: Node
var shop: GarageShop
var _tab: String = "model"
var _slot: String = ""
var _deco: String = "parts"                 # secao da aba DECORACAO (GarageDecoNav.SECTIONS), T-177
var _deco_bar: HBoxContainer                # barra PECAS / PINTURA / LUZES / ADESIVOS, fora da rolagem
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
## Previa (T-171): peca/cor mostrada no caminhao antes de comprar; nunca entra no perfil.
var preview := GaragePreview.new()
var _banner: VBoxContainer                  # faixa "PREVIA" no topo do painel direito (GaragePreviewUi.build_banner)
var _tag: Label                             # etiqueta "PREVIA" no alto do meio da tela
var _banner_main: Button


func _ready() -> void:
	AudioBus.play_music("garage_chill")
	gs = get_node("/root/GameState")
	shop = GarageShop.new(gs, _preview, _flash)
	stage = GarageStage.new()
	stage.preview = preview
	add_child(stage)
	shop.live_decals = func(list: Array) -> void: stage.truck.apply_decals(list)
	shop.focus_view = func(view: String) -> void: stage.focus_view(view)
	shop.on_preview = preview_part
	shop.on_preview_accept = func() -> void:
		if _banner_main != null and is_instance_valid(_banner_main):
			_banner_main.grab_focus()
	shop.on_preview_paint = preview_paint
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
	_tag = UiKit.heading("", 18, GaragePreviewUi.PREVIEW_COLOR)   # "◉ PREVIA · peca" no alto, sem cobrir o caminhao
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_tag.custom_minimum_size = Vector2(60, 0)
	_tag.size_flags_horizontal = Control.SIZE_FILL         # largura do meio; nome comprido vira "..."
	_tag.add_theme_stylebox_override("normal", UiTheme.box(Color(0.02, 0.04, 0.08, 0.78), GaragePreviewUi.PREVIEW_COLOR, 1, 14, 10))
	_tag.visible = false
	center.add_child(_tag)
	center.add_child(UiKit.spacer(true))
	_msg = UiKit.heading("", 18, UiTheme.CYAN, false)
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_msg)
	_right = _column(mid, false)
	_banner = VBoxContainer.new()                     # faixa PREVIA no topo do painel direito, fora da rolagem
	_banner.visible = false
	var right_col: Node = _right.get_parent().get_parent()
	right_col.add_child(_banner)
	right_col.move_child(_banner, 0)
	_build_bottom(vb)
	stage.wheel_spin_changed.connect(func(_on: bool) -> void: _update_spin_button())
	var dbg: Dictionary = GarageDebug.apply(self, gs, stage, _ui_layer)
	_tab = String(dbg.get("tab", _tab))
	_slot = String(dbg.get("slot", _slot))
	_deco = String(dbg.get("deco", _deco))
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
		_deco_bar = HBoxContainer.new()               # secoes da DECORACAO: sempre a mao, nao rolam junto (T-177)
		_deco_bar.add_theme_constant_override("separation", 4)
		_deco_bar.visible = false
		v.add_child(_deco_bar)
	var sc := TouchScroll.new()               # rola arrastando sobre os cartoes (T-165)
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
	back.pressed.connect(func() -> void:
		preview.clear()                        # a previa nunca entrou no perfil: sair nao leva nada junto
		SceneFader.go(get_tree(), "res://scenes/menu/main_menu.tscn"))
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
	_deco = "parts"
	preview.clear()
	stage.focus_default()
	_refresh()
	_scroll_top(_left)


## Troca a secao da DECORACAO: fecha o encaixe aberto e volta a lista ao topo.
func _set_deco(id: String) -> void:
	if id == _deco:
		return
	_deco = id
	_slot = ""
	preview.clear()
	stage.focus_default()
	_refresh()
	_scroll_top(_left)


func _scroll_top(box: Control) -> void:
	var sc: ScrollContainer = box.get_parent() as ScrollContainer
	if sc != null:
		sc.scroll_vertical = 0


func _clear(c: Control) -> void:
	for n in c.get_children():
		c.remove_child(n)
		n.queue_free()


func _refresh() -> void:
	_preview_cache.clear()
	preview.settle(gs)                        # peca da previa instalada / cor aplicada: a previa acaba
	shop.previewing = preview.part_id if preview.part_id != "" else preview.paint_hex
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
	_deco_bar.visible = _tab == "parts"
	if _tab == "parts":
		if not GarageDecoNav.is_section(_deco):
			_deco = "parts"
		GarageDecoNav.build_bar(_deco_bar, _deco, _set_deco)
	match _tab:
		"model":
			_build_model()
		"parts":
			match _deco:
				"paint":
					shop.build_paint(_left)
				"lights":
					shop.build_lights(_left)
				"decals":
					shop.build_decals(_left)
				_:                                     # PECAS: encaixes primeiro (T-177), resumo no fim
					GarageDecoNav.build_slots(_left, gs, _slot, _pick_slot)
					shop.build_deco_summary(_left)
		"mech":
			shop.build_mech(_left)
		"repair":
			shop.build_repair(_left)
	if _tab == "parts" and _deco == "parts" and _slot != "":
		shop.build_slot_detail(_right, _slot)
	else:
		GarageInfoPanel.build(_right, gs, _preview({}), func() -> void: _set_tab("parts"))
	_build_banner()


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


# ---------------------------------------------------------------- previa (T-171)

## Mostra a peca `id` no caminhao (sem comprar), leva a camera para a vista dela e liga o giro nas rodas/calotas.
func preview_part(id: String) -> void:
	if preview.part_id == id:
		return
	preview.set_part(id)
	_show_preview()
	var slot: String = preview.slot(gs)
	stage.focus_slot(slot)
	if slot == "hubcaps":
		stage.set_wheel_spin(true)


## Cor travada por Fama: so ver no caminhao (a liberada continua aplicando direto, e gratis).
func preview_paint(hex: String) -> void:
	if preview.paint_hex == hex.to_lower():
		return
	preview.set_paint(hex)
	_show_preview()
	stage.focus_view("side")


## Sai da previa: o caminhao volta ao que esta equipado (o perfil nunca mudou).
func end_preview() -> void:
	if not preview.active():
		return
	preview.clear()
	_show_preview()


## Atualiza caminhao, marcas dos cartoes e a faixa sem redesenhar as listas (o foco do teclado fica onde esta).
func _show_preview() -> void:
	shop.previewing = preview.part_id if preview.part_id != "" else preview.paint_hex
	stage.refresh_truck()
	for id in shop.preview_cards:
		var c: PanelContainer = shop.preview_cards[id]
		if is_instance_valid(c):
			GaragePreviewUi.mark_card(c, String(id) == preview.part_id, false)
	_build_banner()


func _build_banner() -> void:
	var delta: String = ""
	if preview.part_id != "":
		delta = shop.delta_text(_preview({"install": preview.part_id}), _preview({}))
	_banner_main = GaragePreviewUi.build_banner(_banner, gs, preview, {
		"buy_install": _preview_buy_install,
		"install": func() -> void:
			AudioBus.play_ui("ui_select")
			gs.install(preview.part_id),
		"back": func() -> void:
			AudioBus.play_ui("ui_select")
			end_preview(),
	}, delta)
	GaragePreviewUi.update_tag(_tag, gs, preview)


## COMPRAR E EQUIPAR: compra (paga) e instala a peca da previa; a previa vira o caminhao de verdade.
func _preview_buy_install() -> void:
	var d: PartDef = gs.part(preview.part_id)
	if d != null and gs.buy(d):
		gs.install(String(d.id))
		AudioBus.play_ui("ui_buy")
		_flash(Tr.t("garage.bought", [Tr.t("part." + String(d.id))]))
	else:
		AudioBus.play_ui("ui_error")


## Esc / B do controle durante a previa: volta ao equipado.
func _unhandled_input(event: InputEvent) -> void:
	if preview.active() and event.is_action_pressed("ui_cancel"):
		end_preview()
		get_viewport().set_input_as_handled()


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


# ---------------------------------------------------------------- aba DECORACAO > PECAS (botoes: GarageDecoNav)

## Toque num encaixe: abre as pecas dele no painel direito; tocar de novo fecha e volta a ficha.
func _pick_slot(slot: String) -> void:
	AudioBus.play_ui("ui_select")
	preview.clear()                                          # trocou de encaixe: volta ao equipado
	_slot = "" if _slot == slot else slot
	if _slot != "":
		stage.focus_slot(_slot)
	else:
		stage.focus_default()
	_refresh()
	_scroll_top(_right)                                      # a lista de pecas comeca do topo
