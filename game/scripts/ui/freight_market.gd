class_name FreightMarket
extends Control
## Mercado de fretes: contratos com dados REAIS do jogo (Contracts): origem -> destino (cidades do trecho),
## tipo e peso da carga, distancia da corrida (soma das secoes da pista), valor e estado (disponivel, bau
## pequeno ou trecho bloqueado por Fama). ACEITAR grava o contrato no GameState e inicia a corrida.
## ATUALIZAR sorteia um quadro novo; o quadro tambem muda sozinho ao concluir um frete.

signal back_pressed
signal contract_chosen(contract: Dictionary)

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
	head.add_child(UiKit.chip("truck", "%s · %s %d t" % [Tr.t("body." + String(_gs.profile.get("body", "base"))), Tr.t("market.capacity"), roundi(_gs.capacity_t())]))
	head.add_child(UiKit.chip("coins", Tr.yen(_gs.money()), UiTheme.GOLD))
	head.add_child(UiKit.chip("star", "%s %d" % [Tr.t("hud.fame"), _gs.fame()]))
	root.add_child(head)
	var scroll := TouchScroll.new()           # rola arrastando sobre os cartoes (T-165)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	var first_btn: Button = null
	for c in _gs.contract_board():
		var b: Button = _contract_row(list, c)
		if first_btn == null and not b.disabled:
			first_btn = b
	for r in all_routes():                            # trechos ainda bloqueados aparecem no fim
		if not _gs.route_unlocked(r):
			_row(list, r)
	var foot := HBoxContainer.new()
	var back: Button = UiKit.back_button()
	back.pressed.connect(func() -> void: back_pressed.emit())
	foot.add_child(back)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp2)
	var done: Array = _gs.contracts_state()["done"]
	if not done.is_empty():
		var last: Dictionary = done[0]
		foot.add_child(UiTheme.label(Tr.t("market.last", [String(last["origin"]), String(last["destination"]), Tr.yen(int(last["paid"]))]), 14, UiTheme.GOOD))
	var refresh: Button = UiTheme.button(Tr.t("market.refresh"), Vector2(170, 44))
	refresh.icon = UiKit.icon("rotate-ccw")
	refresh.pressed.connect(func() -> void:
		_gs.refresh_contracts()
		_rebuild())
	foot.add_child(refresh)
	root.add_child(foot)
	if first_btn != null:
		first_btn.grab_focus.call_deferred()


## Redesenha a tela inteira (depois de ATUALIZAR).
func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_ready()


func _contract_row(list: VBoxContainer, c: Dictionary) -> Button:
	var r: RouteDef = load("res://data/routes/%s.tres" % c["route"]) as RouteDef
	var cargo: CargoDef = load("res://data/cargo/%s.tres" % c["cargo"]) as CargoDef
	var reason: String = _gs.contract_block_reason(c)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.035 if reason == "" else 0.015), Color(1, 1, 1, 0.08), 1, 10, 12))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	var ic := TextureRect.new()
	ic.texture = UiKit.icon(cargo.icon if cargo else "package")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(36, 36)
	ic.modulate = UiTheme.CYAN if reason == "" else UiTheme.TEXT_DIM
	h.add_child(ic)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 0)
	var title := HBoxContainer.new()
	title.add_child(UiKit.heading("%s · %s t" % [Tr.t("cargo." + String(c["cargo"])), _num(float(c["weight_t"]))], 21, UiTheme.TEXT if reason == "" else UiTheme.TEXT_DIM))
	var trait_kind: String = String(c.get("trait", "normal"))
	if trait_kind in ["fragile", "heavy", "perishable"]:
		title.add_child(UiKit.heading("  " + Tr.t("market." + trait_kind), 15, UiTheme.WARN))
	elif float(c.get("fragility", 1.0)) >= 1.5:
		title.add_child(UiKit.heading("  " + Tr.t("market.fragile"), 15, UiTheme.WARN))
	var need: StringName = Contracts.needs_of(c)                 # T-145: so bau / so graneleira
	if need != &"any":
		title.add_child(UiKit.heading("  " + Tr.t("market.needs." + String(need)), 15, UiTheme.CYAN))
	info.add_child(title)
	info.add_child(UiTheme.label("%s  →  %s" % [String(c["origin"]), String(c["destination"])], 16, UiTheme.TEXT))
	info.add_child(UiTheme.label("%s  ·  %s" % [Tr.t("route." + String(c["route"])), Tr.t("scenery." + String(r.scenery))], 13, UiTheme.TEXT_DIM))
	var refusal: Dictionary = _gs.rival_refusal(String(c["route"]))
	if not bool(refusal.get("ok", true)):
		var rl: Label = UiTheme.label("%s: “%s”" % [String(refusal["name"]), String(refusal["line"])], 14, UiTheme.WARN)
		rl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rl.custom_minimum_size = Vector2(420, 0)
		info.add_child(rl)
		info.add_child(UiTheme.label(Tr.t("market.rival_needs", [int(refusal["min_fame"]), int(refusal["min_destaque"]), _gs.fame(), _gs.destaque()]), 12, UiTheme.TEXT_DIM))
	h.add_child(info)
	var money := VBoxContainer.new()
	money.add_theme_constant_override("separation", -2)
	var val: Label = UiKit.heading(Tr.yen(int(c["reward"])), 24, UiTheme.GOLD)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.add_child(val)
	var dl: int = int(float(c.get("deadline_s", r.deadline())))
	var km: Label = UiTheme.label("%s km  ·  %d:%02d" % [_km(r), dl / 60, dl % 60], 15, UiTheme.TEXT_DIM)
	km.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.add_child(km)
	h.add_child(money)
	var b: Button
	if reason == "":
		b = UiKit.primary_button(Tr.t("market.accept"), "", Vector2(150, 46))
		b.pressed.connect(func() -> void: contract_chosen.emit(c))
	else:
		b = UiTheme.button(reason, Vector2(150, 46))
		b.add_theme_font_size_override("font_size", 15)
		b.disabled = true
	h.add_child(b)
	list.add_child(card)
	return b


## 9.5 -> "9,5"; 12.0 -> "12".
static func _num(v: float) -> String:
	return (str(int(v)) if is_equal_approx(v, round(v)) else "%.1f" % v).replace(".", ",")


## Distancia em km com virgula (pt-BR): 3.04 -> "3,0".
static func _km(r: RouteDef) -> String:
	return ("%.1f" % route_km(r)).replace(".", ",")


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
	var km: Label = UiTheme.label("%s km" % _km(r), 15, UiTheme.TEXT_DIM)
	km.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	money.add_child(km)
	h.add_child(money)
	var b: Button
	if unlocked:                                     # (trechos liberados aparecem como contratos)
		b = UiKit.primary_button(Tr.t("market.accept"), "", Vector2(150, 46))
	else:
		b = UiTheme.button(Tr.t("market.locked", [r.fame_required]), Vector2(150, 46))
		b.icon = UiKit.icon("lock")
		b.add_theme_font_size_override("font_size", 16)
		b.disabled = true
	h.add_child(b)
	list.add_child(card)
	return b
