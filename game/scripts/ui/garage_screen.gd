extends Node3D
## Garagem (P42 + P43): caminhao 3D no centro; esquerda = abas e slots; direita = pecas do slot
## (comprar, instalar, vender) ou itens mecanicos ou o reparo. Mostra o efeito no peso e no 0-100
## ANTES de comprar. Funciona no toque e no mouse (botoes grandes).

var stage: GarageStage
var gs: Node
var _tab: String = "parts"          # parts | mech | repair
var _slot: String = ""
var _left: VBoxContainer
var _right: VBoxContainer
var _bar: Label
var _msg: Label
var _preview_cache: Dictionary = {}


func _ready() -> void:
	gs = get_node("/root/GameState")
	stage = GarageStage.new()
	add_child(stage)
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.make()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)
	# coluna esquerda
	var lp := PanelContainer.new()
	lp.position = Vector2(10, 10)
	lp.custom_minimum_size = Vector2(300, 470)
	root.add_child(lp)
	var lv := VBoxContainer.new()
	lp.add_child(lv)
	var tabs := HBoxContainer.new()
	lv.add_child(tabs)
	for t in [["parts", Tr.t("garage.parts")], ["mech", Tr.t("garage.mechanics")], ["repair", Tr.t("garage.repair")]]:
		var b: Button = UiTheme.button(String(t[1]), Vector2(90, 40))
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func() -> void: _set_tab(String(t[0])))
		tabs.add_child(b)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(280, 410)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lv.add_child(sc)
	_left = VBoxContainer.new()
	_left.custom_minimum_size = Vector2(270, 0)
	sc.add_child(_left)
	# coluna direita
	var rp := PanelContainer.new()
	rp.position = Vector2(650, 10)
	rp.custom_minimum_size = Vector2(300, 470)
	root.add_child(rp)
	var rsc := ScrollContainer.new()
	rsc.custom_minimum_size = Vector2(280, 450)
	rsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rp.add_child(rsc)
	_right = VBoxContainer.new()
	_right.custom_minimum_size = Vector2(270, 0)
	rsc.add_child(_right)
	# barra inferior
	var bp := PanelContainer.new()
	bp.position = Vector2(10, 486)
	bp.custom_minimum_size = Vector2(940, 44)
	root.add_child(bp)
	var bh := HBoxContainer.new()
	bp.add_child(bh)
	_bar = UiTheme.label("", 16, UiTheme.GOLD)
	_bar.custom_minimum_size = Vector2(700, 0)
	bh.add_child(_bar)
	var back: Button = UiTheme.button(Tr.t("menu.back"), Vector2(150, 30))
	back.add_theme_font_size_override("font_size", 16)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	bh.add_child(back)
	_msg = UiTheme.label("", 16, UiTheme.CYAN)
	_msg.position = Vector2(330, 440)
	root.add_child(_msg)
	gs.profile_changed.connect(_refresh)
	_apply_debug_args()
	_refresh()


## Argumentos de depuracao: --demo (monta um caminhao cheio de pecas), --tab=mech|repair, --slot=<slot>, --damage
func _apply_debug_args() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if "--demo" in args:
		gs.new_profile()
		gs.profile["money"] = 900000
		gs.profile["fame"] = 500
		for id in ["fb_gold_wing", "visor_gold_lights", "roof_lights_crown", "skirt_light_bar", "andon_kanji", "rb_chrome", "mural_lightning", "hub_chrome",
				"grille_frame_chrome", "aux_round_lamps_pair", "front_crest_ornament", "roof_torii_ornament", "fender_extension", "side_ornament_wave", "rear_lamp_cluster", "mudflap_designed"]:
			var d: PartDef = gs.part(id)
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
		if a.begins_with("--tab="):
			_tab = a.substr(6)
		elif a.begins_with("--slot="):
			_slot = a.substr(7)
			stage.focus_slot(_slot)


func _wl(text: String, size: int = 18, color: Color = UiTheme.TEXT) -> Label:
	var l: Label = UiTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(250, 0)
	return l


func _set_tab(t: String) -> void:
	_tab = t
	_slot = ""
	stage.focus_default()
	_refresh()


func _clear(c: Control) -> void:
	for n in c.get_children():
		n.queue_free()


func _refresh() -> void:
	_preview_cache.clear()
	stage.refresh_truck()
	_clear(_left)
	_clear(_right)
	match _tab:
		"parts":
			_build_slots()
			if _slot != "":
				_build_slot_detail(_slot)
		"mech":
			_build_mech()
		"repair":
			_build_repair()
	var pv: Dictionary = _preview({})
	_bar.text = "%s    Fama %d    %s: %d kg    %s: %.1f s    %s: %d" % [
		Tr.yen(gs.money()), gs.fame(), Tr.t("garage.mass"), roundi(float(pv["mass"])),
		Tr.t("garage.zero100"), float(pv["zero100"]), Tr.t("garage.rating"), int(pv["rating"])]


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


# ---------------------------------------------------------------- pecas

func _build_slots() -> void:
	for slot in gs.slots():
		var inst: String = gs.installed_id(String(slot))
		var txt: String = Tr.t("slot." + String(slot))
		var sub: String = Tr.t("part." + inst) if inst != "" else "— " + Tr.t("garage.empty")
		var b: Button = UiTheme.button("%s\n%s" % [txt, sub], Vector2(0, 54))
		b.add_theme_font_size_override("font_size", 15)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if String(slot) == _slot:
			b.add_theme_color_override("font_color", UiTheme.GOLD)
		b.pressed.connect(func() -> void:
			_slot = String(slot)
			stage.focus_slot(_slot)
			_refresh())
		_left.add_child(b)


func _build_slot_detail(slot: String) -> void:
	_right.add_child(_wl(Tr.t("slot." + slot), 22, UiTheme.PINK))
	var inst: String = gs.installed_id(slot)
	var base: Dictionary = _preview({})
	for d in gs.parts_for_slot(slot):
		_right.add_child(_part_card(d, d.id == StringName(inst), base))
	if inst != "":
		var rm: Button = UiTheme.button(Tr.t("garage.remove"), Vector2(0, 44))
		rm.pressed.connect(func() -> void: gs.uninstall(slot))
		_right.add_child(rm)


func _delta_text(after: Dictionary, before: Dictionary) -> String:
	var dm: int = roundi(float(after["mass"]) - float(before["mass"]))
	var dz: float = float(after["zero100"]) - float(before["zero100"])
	return "%+d kg   %s %+.1f s" % [dm, Tr.t("garage.effect"), dz]


func _part_card(d: PartDef, installed: bool, base: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.1, 0.09, 0.2, 0.95), UiTheme.PINK if installed else UiTheme.PANEL_EDGE, 2, 6, 8))
	var v := VBoxContainer.new()
	card.add_child(v)
	var title: String = Tr.t("part." + String(d.id))
	if installed:
		title += "  ✔"
	v.add_child(_wl(title, 18, UiTheme.GOLD if installed else UiTheme.TEXT))
	var dur: String = "—" if d.durability <= 0.0 else str(int(d.durability))
	v.add_child(_wl("%s %d kg · %s %s · Fama %d" % [Tr.t("garage.weight"), int(d.weight_kg), Tr.t("garage.durability"), dur, d.fame], 14, UiTheme.TEXT_DIM))
	if not installed:
		v.add_child(_wl(_delta_text(_preview({"install": String(d.id)}), base), 14, UiTheme.CYAN))
	var owned: bool = gs.owns(String(d.id))
	var row := HBoxContainer.new()
	v.add_child(row)
	if not owned:
		var reason: String = gs.can_buy(d)
		var b: Button = UiTheme.button("%s  %s" % [Tr.t("garage.buy"), Tr.yen(d.price)], Vector2(0, 40))
		b.add_theme_font_size_override("font_size", 15)
		b.disabled = reason != ""
		if reason != "":
			b.tooltip_text = reason
			v.add_child(_wl(reason, 13, UiTheme.BAD))
		b.pressed.connect(func() -> void:
			if gs.buy(d):
				_flash("Comprou " + Tr.t("part." + String(d.id))))
		row.add_child(b)
	else:
		if not installed:
			var bi: Button = UiTheme.button(Tr.t("garage.install"), Vector2(120, 40))
			bi.add_theme_font_size_override("font_size", 15)
			bi.pressed.connect(func() -> void: gs.install(String(d.id)))
			row.add_child(bi)
		var bs: Button = UiTheme.button(Tr.t("garage.sell"), Vector2(120, 40))
		bs.add_theme_font_size_override("font_size", 14)
		bs.pressed.connect(func() -> void: gs.sell(String(d.id)))
		row.add_child(bs)
	return card


# ---------------------------------------------------------------- mecanica

func _build_mech() -> void:
	_left.add_child(_wl(Tr.t("garage.mechanics"), 22, UiTheme.PINK))
	_left.add_child(_wl("Motor, turbo, escape e freio-motor.\nAs mudanças mostram o efeito no 0–100.", 14, UiTheme.TEXT_DIM))
	var base: Dictionary = _preview({})
	for kind in ["engine", "turbo", "exhaust", "upgrade"]:
		for id in gs.MECH_KINDS[kind]["ids"]:
			var def: Resource = gs.mech_def(String(id))
			var owned: bool = gs.owns_mech(String(id))
			var inst: bool = gs.mech_installed(String(id))
			var card := PanelContainer.new()
			card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.1, 0.09, 0.2, 0.95), UiTheme.PINK if inst else UiTheme.PANEL_EDGE, 2, 6, 8))
			var v := VBoxContainer.new()
			card.add_child(v)
			var nm: String = Tr.t("%s.%s" % ["upgrade" if kind == "upgrade" else kind, id])
			v.add_child(_wl(nm + ("  ✔" if inst else ""), 17, UiTheme.GOLD if inst else UiTheme.TEXT))
			var detail: String = ""
			match kind:
				"engine":
					detail = "%d N·m · corte %d rpm · +%d kg" % [int(def.get("max_torque_nm")), int(def.get("redline_rpm")), int(def.get("weight_kg"))]
				"turbo":
					detail = "+%d%% torque · atraso %.1f s" % [roundi(float(def.get("torque_gain")) * 100.0), float(def.get("lag_s"))]
				"exhaust":
					detail = "+%d%% torque · +%d Fama" % [roundi(float(def.get("torque_bonus")) * 100.0), int(def.get("fame"))]
				"upgrade":
					detail = "efeito %+d%%" % roundi(float(def.get("value")) * 100.0)
			v.add_child(_wl(detail, 13, UiTheme.TEXT_DIM))
			if not inst:
				var ch: Dictionary = {}
				match kind:
					"engine", "turbo", "exhaust":
						ch = {kind: String(id)}
					"upgrade":
						if id == "jake_brake":
							ch = {"jake_brake": true}
				if not ch.is_empty():
					v.add_child(_wl(_delta_text(_preview(ch), base), 13, UiTheme.CYAN))
			var b: Button
			if not owned:
				var price: int = int(def.get("price"))
				b = UiTheme.button("%s  %s" % [Tr.t("garage.buy"), Tr.yen(price)], Vector2(0, 38))
				b.disabled = gs.can_buy_mech(String(id)) != ""
				b.pressed.connect(func() -> void: gs.buy_mech(String(id)))
			else:
				b = UiTheme.button(Tr.t("garage.install") if not inst else ("DESLIGAR" if kind == "upgrade" else Tr.t("garage.installed")), Vector2(0, 38))
				b.disabled = inst and kind != "upgrade"
				b.pressed.connect(func() -> void: gs.install_mech(String(id)))
			b.add_theme_font_size_override("font_size", 15)
			v.add_child(b)
			_right.add_child(card)


# ---------------------------------------------------------------- reparo (P43)

func _build_repair() -> void:
	_left.add_child(_wl(Tr.t("garage.repair"), 22, UiTheme.PINK))
	var total: int = gs.total_repair_cost()
	_left.add_child(_wl("Total: " + Tr.yen(total), 18, UiTheme.GOLD))
	var all: Button = UiTheme.button("%s  %s" % [Tr.t("garage.repair_all"), Tr.yen(total)], Vector2(0, 50))
	all.disabled = total <= 0 or gs.money() < 1
	all.pressed.connect(func() -> void:
		var spent: int = gs.repair_all()
		_flash("Reparos pagos: " + Tr.yen(spent)))
	_left.add_child(all)
	_left.add_child(_wl("Fórmula: preço da peça × % de dano × 0,5.\nMural riscado: repintar = 30% do preço.", 13, UiTheme.TEXT_DIM))
	var any: bool = false
	for id in gs.profile["owned"]:
		var cost: int = gs.part_repair_cost(String(id))
		if cost <= 0:
			continue
		any = true
		var d: PartDef = gs.part(String(id))
		var own: Dictionary = gs.profile["owned"][String(id)]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UiTheme.box(Color(0.1, 0.09, 0.2, 0.95), UiTheme.BAD if bool(own["broken"]) else UiTheme.WARN, 2, 6, 8))
		var v := VBoxContainer.new()
		card.add_child(v)
		v.add_child(_wl(Tr.t("part." + String(id)), 17))
		var state: String
		if d.durability <= 0.0:
			state = "riscado %d%%" % roundi(float(own["scratch"]) * 100.0)
		elif bool(own["broken"]):
			state = "QUEBRADA"
		else:
			state = "dano %d%%" % roundi((1.0 - float(own["dur"]) / d.durability) * 100.0)
		v.add_child(_wl(state, 14, UiTheme.BAD if bool(own["broken"]) else UiTheme.WARN))
		var row := HBoxContainer.new()
		v.add_child(row)
		var rb: Button = UiTheme.button("%s  %s" % [Tr.t("garage.repaint") if d.durability <= 0.0 else Tr.t("garage.repair_one"), Tr.yen(cost)], Vector2(0, 38))
		rb.add_theme_font_size_override("font_size", 14)
		rb.disabled = gs.money() < cost
		rb.pressed.connect(func() -> void: gs.repair_part(String(id)))
		row.add_child(rb)
		if bool(own["broken"]):
			var nb: Button = UiTheme.button("%s  %s" % [Tr.t("garage.buy_new"), Tr.yen(d.price)], Vector2(0, 38))
			nb.add_theme_font_size_override("font_size", 14)
			nb.disabled = gs.money() < d.price
			nb.pressed.connect(func() -> void: gs.buy_new_replacement(String(id)))
			row.add_child(nb)
		_right.add_child(card)
	for sys in gs.SYSTEM_REPAIR_PRICE:
		var c2: int = gs.system_repair_cost(String(sys))
		if c2 <= 0:
			continue
		any = true
		var card2 := PanelContainer.new()
		card2.add_theme_stylebox_override("panel", UiTheme.box(Color(0.1, 0.09, 0.2, 0.95), UiTheme.WARN, 2, 6, 8))
		var v2 := VBoxContainer.new()
		card2.add_child(v2)
		v2.add_child(_wl(Tr.t("repair." + String(sys)), 17))
		v2.add_child(_wl("saúde %d%%" % roundi(float(gs.profile["systems"][sys])), 14, UiTheme.WARN))
		var sb: Button = UiTheme.button("%s  %s" % [Tr.t("garage.repair_one"), Tr.yen(c2)], Vector2(0, 38))
		sb.add_theme_font_size_override("font_size", 14)
		sb.disabled = gs.money() < c2
		sb.pressed.connect(func() -> void: gs.repair_system(String(sys)))
		v2.add_child(sb)
		_right.add_child(card2)
	if not any:
		_right.add_child(_wl(Tr.t("garage.nothing_to_repair"), 18, UiTheme.GOOD))
