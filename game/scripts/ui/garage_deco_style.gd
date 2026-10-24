class_name GarageDecoStyle
extends RefCounted
## Garagem (T-211): o que as pecas da oficina tem a mais no cartao da loja: raridade (so etiqueta), "Classica" para as
## pecas antigas, troca de cor L/R com preco (DecoColorDef) e letreiro de nomes prontos; e o botao De dia/De noite
## no topo do encaixe (como nas capturas: ver as luzes acesas).

const DAY_NIGHT_SLOTS: Array[String] = ["andon", "visor"]
const RARITY_COLOR: Dictionary = {"comum": Color("#c9d2e3"), "incomum": Color("#3dff7a"), "rara": Color("#21e6ff"),
		"lendaria": Color("#f0b83a")}


## Linha "Raridade: Rara · Fama sugerida 60" (nova) ou "Classica" (peca de antes da T-211).
static func rarity_line(d: PartDef) -> Label:
	if String(d.rarity) == "":
		return GarageShop.wl(Tr.t("garage.classic"), 13, UiTheme.TEXT_DIM)
	var txt: String = "%s: %s" % [Tr.t("garage.rarity"), Tr.t("rarity." + String(d.rarity))]
	if d.fame_min > 0:
		txt += " · " + Tr.t("garage.fame_hint", [d.fame_min])
	return GarageShop.wl(txt, 13, RARITY_COLOR.get(String(d.rarity), UiTheme.TEXT))


## Botao "De dia / De noite" no topo dos encaixes com luz (deque e viseira).
static func day_night_button(box: VBoxContainer, is_day: bool, toggle: Callable) -> void:
	var b: Button = GarageShop.small_button(Tr.t("garage.see_night") if is_day else Tr.t("garage.see_day"))
	b.name = "DayNight"
	b.pressed.connect(func() -> void:
		AudioBus.play_ui("ui_select")
		toggle.call())
	box.add_child(b)


## Cores L/R (grade com preco) e letreiro (lista pronta) de uma peca da oficina que o jogador tem.
static func build(v: VBoxContainer, gs: Node, d: PartDef, flash: Callable) -> void:
	var id: String = String(d.id)
	var entry: Dictionary = AccessoryCatalog.get_instance().entry(d.accessory_id)
	if not DecoStyle.is_deco(entry) or not gs.owns(id):
		return
	var cur: String = gs.part_color(id)
	v.add_child(GarageShop.wl("%s: %s" % [Tr.t("garage.color_lr"), Tr.t("deco_color." + cur)], 14, UiTheme.GOLD))
	var grid := GridContainer.new()
	grid.name = "Colors_" + id
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	v.add_child(grid)
	for cd in DecoColorDef.all():
		var cid: String = String(cd.id)
		var price: int = gs.color_price(id, cid)
		var b := Button.new()
		b.name = "Color_" + cid
		b.custom_minimum_size = Vector2(54, 40)
		b.text = "✔" if cid == cur else ("0" if price == 0 else "%dk" % int(price / 1000))
		b.tooltip_text = "%s · %s" % [Tr.t("deco_color." + cid), Tr.yen(price)]
		b.add_theme_font_size_override("font_size", 13)
		var sel: bool = cid == cur
		b.add_theme_stylebox_override("normal", _swatch(cd, UiTheme.GOLD if sel else Color(1, 1, 1, 0.25), 3 if sel else 1))
		b.add_theme_stylebox_override("hover", _swatch(cd, UiTheme.PINK, 2))
		b.add_theme_color_override("font_color", Color.WHITE)
		b.disabled = sel or gs.money() < price
		b.pressed.connect(func() -> void:
			if gs.set_part_color(id, cid):
				AudioBus.play_ui("ui_buy" if price > 0 else "ui_select")
				flash.call(Tr.t("garage.color_paid", [Tr.t("deco_color." + cid), Tr.yen(price)]))
			else:
				AudioBus.play_ui("ui_error"))
		grid.add_child(b)
	if not bool(entry.get("has_sign", false)):
		return
	var cell: int = int(gs.part_style(id).get("sign", DecoStyle.default_sign(entry)))
	v.add_child(GarageShop.wl(Tr.t("garage.sign_pick"), 14, UiTheme.GOLD))
	var sg := GridContainer.new()
	sg.name = "Signs_" + id
	sg.columns = 4
	sg.add_theme_constant_override("h_separation", 4)
	sg.add_theme_constant_override("v_separation", 4)
	v.add_child(sg)
	for k in DecoStyle.SIGN_NAMES.size():
		var sb: Button = GarageShop.small_button(DecoStyle.SIGN_NAMES[k] + (" ✔" if k == cell else ""), 70)
		sb.disabled = k == cell
		sb.pressed.connect(func() -> void:
			if gs.set_part_sign(id, k):
				AudioBus.play_ui("ui_select"))
		sg.add_child(sb)


static func _swatch(cd: DecoColorDef, border: Color, bw: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = UiTheme.box(cd.swatch_a, border, bw, 6, 4)
	sb.border_color = border
	sb.shadow_color = cd.swatch_b                     # a cor da luz aparece como brilho em volta da amostra
	sb.shadow_size = 3
	return sb
