class_name GaragePreviewUi
extends RefCounted
## Pedacos de tela da previa da garagem (T-171): cartao que vira "toque para ver no caminhao" e a faixa
## "PREVIA" no meio da tela com COMPRAR E EQUIPAR / EQUIPAR / VOLTAR AO ATUAL.
##
## Toque e mouse: o toque do Android chega como clique de mouse emulado, entao so o clique conta. Soltar perto
## de onde apertou (< TAP_SLOP) = toque; mais longe = o dedo estava rolando a lista (TouchScroll) e nada acontece.
## Teclado/controle: o cartao recebe foco (setas/Tab); foco no cartao = previa; Enter/A leva o foco ao botao
## principal da faixa.

## Distancia maxima (unidades da tela base) entre apertar e soltar para contar como toque.
const TAP_SLOP: float = 12.0
const PREVIEW_COLOR: Color = Color("#21e6ff")


## Deixa `card` tocavel: `on_tap.call()` no toque/clique (sem arrastar), no foco por teclado e no Enter/A
## (que tambem chama `on_accept`). Toque que comeca num botao do cartao fica com o botao.
static func make_tappable(card: Control, on_tap: Callable, on_accept: Callable) -> void:
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_filter = Control.MOUSE_FILTER_STOP              # o TouchScroll troca para PASS (rolagem continua)
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.add_theme_stylebox_override("focus", UiTheme.box(Color(0, 0, 0, 0), PREVIEW_COLOR, 2, 10, 10))
	var st: Dictionary = {"down": false, "pos": Vector2.ZERO}
	card.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			var mb: InputEventMouseButton = ev
			if mb.pressed:
				st["down"] = not _on_button(card, mb.global_position)
				st["pos"] = mb.global_position
			elif bool(st["down"]):
				st["down"] = false
				if mb.global_position.distance_to(st["pos"]) <= TAP_SLOP:
					on_tap.call()
		elif ev.is_action_pressed("ui_accept"):
			card.accept_event()
			on_tap.call()
			on_accept.call())
	card.focus_entered.connect(func() -> void:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):  # clique/toque: decide ao soltar (pode ser rolagem)
			on_tap.call())


## true se `pos` (tela) cai num botao dentro de `card`.
static func _on_button(card: Control, pos: Vector2) -> bool:
	for b in card.find_children("*", "BaseButton", true, false):
		var bb: BaseButton = b as BaseButton
		if bb.is_visible_in_tree() and bb.get_global_rect().has_point(pos):
			return true
	return false


## Borda e etiqueta do cartao em previa (ciano) por cima do estilo normal.
static func mark_card(card: PanelContainer, on: bool, installed: bool) -> void:
	var edge: Color = PREVIEW_COLOR if on else (UiTheme.PINK if installed else Color(1, 1, 1, 0.1))
	var bg: Color = Color(0.13, 0.9, 1, 0.12) if on else Color(1, 1, 1, 0.04)
	card.add_theme_stylebox_override("panel", UiTheme.box(bg, edge, 2 if on else 1, 10, 10))
	var tag: Node = card.find_child("PreviewTag", true, false)
	if tag != null:
		(tag as CanvasItem).visible = on


## Etiqueta "PREVIA" (escondida ate o cartao entrar em previa).
static func preview_tag() -> Label:
	var l: Label = UiKit.heading("◉ " + Tr.t("garage.preview_tag"), 13, PREVIEW_COLOR)
	l.name = "PreviewTag"
	l.visible = false
	return l


## Faixa da previa no meio da tela. `act`: {"buy_install": Callable, "install": Callable, "back": Callable}.
## Devolve o botao principal (para o foco do teclado/controle) ou null.
static func build_banner(box: Control, gs: Node, pv: GaragePreview, act: Dictionary, delta: String) -> Button:
	for n in box.get_children():
		box.remove_child(n)
		n.queue_free()
	box.visible = pv.active()
	if not pv.active():
		return null
	var p: PanelContainer = UiKit.glass_panel(0.9)
	p.add_theme_stylebox_override("panel", UiTheme.box(Color(0.03, 0.05, 0.1, 0.9), PREVIEW_COLOR, 2, 12, 12))
	p.mouse_filter = Control.MOUSE_FILTER_STOP                 # o toque na faixa nao gira a camera
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(head)
	head.add_child(UiKit._icon_rect("eye", 20, PREVIEW_COLOR))
	head.add_child(UiKit.heading(Tr.t("garage.preview_tag"), 22, PREVIEW_COLOR))
	var main: Button = null
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	if pv.part_id != "":
		var d: PartDef = gs.part(pv.part_id)
		head.add_child(UiKit.heading(Tr.t("part." + pv.part_id), 20, UiTheme.TEXT, false))
		var hint: String = Tr.t("garage.preview_hint")
		if delta != "":
			hint += "   " + delta
		v.add_child(_center(GarageShop.wl(hint, 14, UiTheme.TEXT_DIM, 300.0)))
		if not gs.owns(pv.part_id):
			var reason: String = gs.can_buy(d)
			main = UiKit.primary_button("%s  %s" % [Tr.t("garage.preview_buy_install"), Tr.yen(d.price)], "coins", Vector2(0, 42))
			main.add_theme_font_size_override("font_size", 16)
			main.disabled = reason != ""
			main.pressed.connect(act["buy_install"])
			if reason != "":
				v.add_child(_center(GarageShop.wl(reason, 14, UiTheme.BAD, 300.0)))
		else:
			main = UiKit.primary_button(Tr.t("garage.preview_equip"), "check", Vector2(0, 42))
			main.add_theme_font_size_override("font_size", 16)
			main.pressed.connect(act["install"])
		row.add_child(main)
	else:
		var pid: String = ""
		var need: int = 0
		for pp in StyleCatalog.PAINTS:
			if String(pp["hex"]).to_lower() == pv.paint_hex:
				pid = String(pp["id"])
				need = int(pp["fame_required"])
		head.add_child(UiKit.heading(Tr.t("paint." + pid) if pid != "" else pv.paint_hex, 20, UiTheme.TEXT, false))
		v.add_child(_center(GarageShop.wl(Tr.t("garage.preview_paint_locked", [need]), 14, UiTheme.BAD, 300.0)))
	var back: Button = GarageShop.small_button(Tr.t("garage.preview_back"))
	back.icon = UiKit.icon("rotate-ccw")
	back.add_theme_constant_override("icon_max_width", 18)
	back.pressed.connect(act["back"])
	row.add_child(back)
	v.add_child(row)
	return main if main != null and not main.disabled else back


static func _center(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if c is Label:
		(c as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return c
