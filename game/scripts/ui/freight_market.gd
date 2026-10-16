class_name FreightMarket
extends Control
## Mercado de fretes: lista os trechos (RouteDef) com dados REAIS — nome, cenario, rival, distancia
## (soma das secoes da pista), valor do frete, fama exigida, estado (disponivel / bloqueado / concluido e
## melhor tempo). ACEITAR inicia a corrida pelo GameState.pending_route (mesmo fluxo da antiga campanha).
## Ainda NAO existem nos dados: origem/destino, tipo e peso da carga (ver docs/STATUS.md, etapa G).

signal back_pressed
signal route_chosen(route: RouteDef)

const SCENERY_ICON: Dictionary = {"coast": "waves", "city": "building-2", "mountain": "mountain"}

var _gs: Node


func _ready() -> void:
	_gs = get_node("/root/GameState")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = UiKit.glass_panel(0.9)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 36.0
	panel.offset_top = 24.0
	panel.offset_right = -36.0
	panel.offset_bottom = -24.0
	add_child(panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	panel.add_child(root)
	var head := HBoxContainer.new()
	head.add_child(UiKit.screen_title(Tr.t("market.title"), "package"))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(UiKit.chip("coins", Tr.yen(_gs.money()), UiTheme.GOLD))
	head.add_child(UiKit.chip("star", "%s %d" % [Tr.t("hud.fame"), _gs.fame()]))
	root.add_child(head)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var first_btn: Button = null
	for r in all_routes():
		var b: Button = _row(list, r)
		if first_btn == null and b != null and not b.disabled:
			first_btn = b
	var foot := HBoxContainer.new()
	var back: Button = UiKit.back_button()
	back.pressed.connect(func() -> void: back_pressed.emit())
	foot.add_child(back)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)
	foot.add_child(UiTheme.label(Tr.t("market.note"), 13, UiTheme.TEXT_DIM))
	root.add_child(foot)
	if first_btn != null:
		first_btn.grab_focus.call_deferred()


## Rotas ordenadas pelo valor do frete (a ordem da progressao).
static func all_routes() -> Array[RouteDef]:
	var routes: Array[RouteDef] = []
	for f in DirAccess.get_files_at("res://data/routes/"):
		var name: String = f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			routes.append(load("res://data/routes/" + name) as RouteDef)
	routes.sort_custom(func(a: RouteDef, b: RouteDef) -> bool: return a.freight < b.freight)
	return routes


## Distancia real do trecho em km (soma das secoes).
static func route_km(r: RouteDef) -> float:
	var m: float = 0.0
	for s in r.sections:
		m += float(s["length"])
	return m / 1000.0


func _row(list: VBoxContainer, r: RouteDef) -> Button:
	var unlocked: bool = _gs.route_unlocked(r)
	var won: bool = _gs.route_won(String(r.id))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.035 if unlocked else 0.015), Color(1, 1, 1, 0.08), 1, 10, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	card.add_child(h)
	var ic := TextureRect.new()                       # cenario
	ic.texture = UiKit.icon(String(SCENERY_ICON.get(String(r.scenery), "route")))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(40, 40)
	ic.modulate = UiTheme.CYAN if unlocked else UiTheme.TEXT_DIM
	h.add_child(ic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	info.add_child(UiKit.heading(Tr.t("route." + String(r.id)), 22, UiTheme.TEXT if unlocked else UiTheme.TEXT_DIM))
	var rival: RivalDef = load("res://data/rivals/%s.tres" % r.rival_id) as RivalDef
	var sub: String = "%s  ·  %s: %s" % [Tr.t("scenery." + String(r.scenery)), Tr.t("campaign.rival"), rival.display_name if rival else "—"]
	info.add_child(UiTheme.label(sub, 15, UiTheme.TEXT_DIM))
	var rec: Dictionary = (_gs.profile["routes_done"] as Dictionary).get(String(r.id), {})
	if not rec.is_empty():
		var t: float = float(rec["best_time"])
		info.add_child(UiTheme.label("%s: %d:%05.2f" % [Tr.t("campaign.best"), int(t) / 60, fmod(t, 60.0)], 14, UiTheme.GOOD))
	h.add_child(info)
	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", -2)
	var val: Label = UiKit.heading(Tr.yen(r.freight), 24, UiTheme.GOLD)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.add_child(val)
	var km: Label = UiTheme.label("%.1f km" % route_km(r), 15, UiTheme.TEXT_DIM)
	km.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.add_child(km)
	h.add_child(money)
	var b: Button
	if unlocked:
		b = UiKit.primary_button(Tr.t("market.again") if won else Tr.t("market.accept"), "", Vector2(170, 46))
		b.pressed.connect(func() -> void: route_chosen.emit(r))
	else:
		b = UiTheme.button(Tr.t("market.locked", [r.fame_required]), Vector2(170, 46))
		b.icon = UiKit.icon("lock")
		b.add_theme_font_size_override("font_size", 16)
		b.disabled = true
	h.add_child(b)
	list.add_child(card)
	return b
