class_name GarageDecoNav
extends RefCounted
## Navegacao da aba DECORACAO da garagem (T-177). Antes era uma lista unica de ~2.700 unidades: pintura, luzes e
## 4 cartoes de adesivo vinham antes das PECAS, e os 28 encaixes ficavam a 3 telas de rolagem no celular.
## Agora:
##  - uma barra fixa (fora da rolagem, logo abaixo das abas) com PECAS / PINTURA / LUZES / ADESIVOS;
##  - em PECAS os encaixes vem primeiro, agrupados por lugar do caminhao (frente, teto, laterais, traseira),
##    em 2 colunas de botoes; o resumo (destaque, massa, protecao) fica no fim.

## [id, chave do texto]. A primeira e a padrao.
const SECTIONS: Array = [["parts", "garage.parts"], ["paint", "garage.paint"], ["lights", "garage.lights"], ["decals", "garage.decals"]]
## Lugar do caminhao -> encaixes (mesma ordem do GameState.SLOT_ORDER). Encaixe fora daqui cai em "other".
const AREAS: Array = [
	["front", ["front_bumper", "front_lip", "grille", "front_trim", "front_ornament", "aux_lights", "mirror_stay", "interior"]],   # T-234: interior
	["roof", ["visor", "andon", "rocket", "box_light_top", "roof_paint", "horn"]],   # T-234: buzina no topo da carga   # T-232: pintura do teto          # T-231: foguete e contorno do teto do bau                       # T-215: roof_lights/frame/ornament/wing sairam (RetiredParts)
	["side", ["body_ornament", "exhaust_stacks", "ladder", "side_skirts", "underglow", "fenders", "steps", "side_trim",
			"side_box", "side_ornament", "mural", "box_light_r", "box_light_l", "hubcaps"]],
	["rear", ["rear_bumper", "rear_lamps", "plate", "mudflaps", "rear_ornament", "rear_paint"]],   # T-232
]
const SLOT_H: float = 46.0


static func is_section(id: String) -> bool:
	for s in SECTIONS:
		if String(s[0]) == id:
			return true
	return false


## Lugar do caminhao do encaixe (front | roof | side | rear | other).
static func area_of(slot: String) -> String:
	for a in AREAS:
		if slot in (a[1] as Array):
			return String(a[0])
	return "other"


## Barra das secoes (refeita a cada redesenho para marcar a atual). `on_pick.call(id)` ao tocar.
static func build_bar(bar: HBoxContainer, current: String, on_pick: Callable) -> void:
	for n in bar.get_children():
		bar.remove_child(n)
		n.queue_free()
	for s in SECTIONS:
		var id: String = String(s[0])
		var on: bool = id == current
		var b: Button = UiTheme.button(Tr.t(String(s[1])).to_upper(), Vector2(0, 36))
		b.name = "Deco_" + id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true                                  # texto comprido nao alarga o painel
		b.add_theme_font_size_override("font_size", 12)
		b.add_theme_color_override("font_color", UiTheme.PINK if on else UiTheme.TEXT)
		b.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.2) if on else Color(1, 1, 1, 0.04),
				UiTheme.PINK if on else Color(1, 1, 1, 0.12), 1, 8, 4))
		b.pressed.connect(func() -> void: on_pick.call(id))
		bar.add_child(b)


## Encaixes agrupados por lugar, 2 por linha. `sel` = encaixe aberto; `on_pick.call(slot)` ao tocar.
static func build_slots(box: VBoxContainer, gs: Node, sel: String, on_pick: Callable) -> void:
	var groups: Dictionary = {}
	var order: Array[String] = []
	for slot in gs.slots():
		var area: String = area_of(String(slot))
		if not groups.has(area):
			groups[area] = []
			order.append(area)
		(groups[area] as Array).append(String(slot))
	for area in order:
		box.add_child(UiKit.heading(Tr.t("garage.area." + area), 15, UiTheme.PINK))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		box.add_child(grid)
		for slot in groups[area]:
			grid.add_child(_slot_button(gs, String(slot), String(slot) == sel, on_pick))


static func _slot_button(gs: Node, slot: String, sel: bool, on_pick: Callable) -> Button:
	var inst: String = gs.installed_id(slot)
	var b := Button.new()
	b.name = "Slot_" + slot
	b.text = ("✔ " if inst != "" else "") + Tr.t("slot." + slot)
	b.tooltip_text = Tr.t("part." + inst) if inst != "" else Tr.t("garage.empty")
	b.custom_minimum_size = Vector2(0, SLOT_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.18) if sel else Color(1, 1, 1, 0.04),
			UiTheme.PINK if sel else Color(1, 1, 1, 0.08), 2 if sel else 1, 8, 8))
	b.add_theme_color_override("font_color", UiTheme.GOLD if inst != "" else UiTheme.TEXT)
	b.pressed.connect(func() -> void: on_pick.call(slot))
	return b
