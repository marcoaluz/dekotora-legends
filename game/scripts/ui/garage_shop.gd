class_name GarageShop
extends RefCounted
## Cartoes da garagem (pecas, mecanica, reparo): comprar, instalar, vender e reparar. Toda acao passa pelo
## GameState (que salva o perfil e avisa `profile_changed`, e a tela se redesenha). Mostra o efeito no peso
## e no 0-100 ANTES de comprar.

var gs: Node
var preview: Callable          # func(changes: Dictionary) -> Dictionary (com cache na tela)
var flash: Callable            # func(text: String) -> void
var live_decals: Callable      # func(decals: Array) -> void: mostra os adesivos no caminhao sem reconstruir a tela (sliders)
var focus_view: Callable       # func(view: String) -> void: enquadra o caminhao no lugar do adesivo


func _init(gs_: Node, preview_: Callable, flash_: Callable) -> void:
	gs = gs_
	preview = preview_
	flash = flash_


static func wl(text: String, size: int = 18, color: Color = UiTheme.TEXT, width: float = 250.0) -> Label:
	var l: Label = UiTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func card(highlight: Color = Color(1, 1, 1, 0.1)) -> Array:
	var c := PanelContainer.new()
	c.add_theme_stylebox_override("panel", UiTheme.box(Color(1, 1, 1, 0.04), highlight, 1, 10, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	c.add_child(v)
	return [c, v]


func delta_text(after: Dictionary, before: Dictionary) -> String:
	var dm: int = roundi(float(after["mass"]) - float(before["mass"]))
	var dz: float = float(after["zero100"]) - float(before["zero100"])
	var dd: int = int(after["rating"]) - int(before["rating"])
	return "%+d kg   %s %+.1f s   %s %+d" % [dm, Tr.t("garage.effect"), dz, Tr.t("garage.destaque"), dd]


static func small_button(text: String, w: float = 0.0) -> Button:
	var b: Button = UiTheme.button(text, Vector2(w, 38))
	b.add_theme_font_size_override("font_size", 16)
	return b


# ---------------------------------------------------------------- pecas

func part_card(d: PartDef, installed: bool, base: Dictionary) -> Control:
	var cv: Array = card(UiTheme.PINK if installed else Color(1, 1, 1, 0.1))
	var v: VBoxContainer = cv[1]
	var title: String = Tr.t("part." + String(d.id)) + ("  ✔" if installed else "")
	v.add_child(wl(title, 18, UiTheme.GOLD if installed else UiTheme.TEXT))
	var dur: String = "—" if d.durability <= 0.0 else str(int(d.durability))
	v.add_child(wl("%s %d kg · %s %s · %s +%d" % [Tr.t("garage.weight"), int(d.weight_kg), Tr.t("garage.durability"), dur, Tr.t("garage.destaque"), d.fame], 14, UiTheme.TEXT_DIM))
	v.add_child(wl("%s: %s" % [Tr.t("garage.protects"), _zones_text(d)], 13, UiTheme.TEXT_DIM))
	if not installed:
		v.add_child(wl(delta_text(preview.call({"install": String(d.id)}), base), 14, UiTheme.CYAN))
	var row := HBoxContainer.new()
	v.add_child(row)
	if not gs.owns(String(d.id)):
		var reason: String = gs.can_buy(d)
		var b: Button = UiKit.primary_button("%s  %s" % [Tr.t("garage.buy"), Tr.yen(d.price)], "", Vector2(0, 38))
		b.add_theme_font_size_override("font_size", 16)
		b.disabled = reason != ""
		if reason != "":
			v.add_child(wl(reason, 13, UiTheme.BAD))
		b.pressed.connect(func() -> void:
			if gs.buy(d):
				AudioBus.play_ui("ui_buy")
				flash.call("Comprou " + Tr.t("part." + String(d.id)))
			else:
				AudioBus.play_ui("ui_error"))
		row.add_child(b)
	else:
		if not installed:
			var bi: Button = small_button(Tr.t("garage.install"), 120)
			bi.pressed.connect(func() -> void: gs.install(String(d.id)))
			row.add_child(bi)
		var bs: Button = small_button(Tr.t("garage.sell"), 120)
		bs.pressed.connect(func() -> void: gs.sell(String(d.id)))
		row.add_child(bs)
	return cv[0]


## Zonas que a peca protege (ela absorve o impacto antes do motor/direcao/carga).
func _zones_text(d: PartDef) -> String:
	if d.durability <= 0.0 or d.zones.is_empty():
		return Tr.t("garage.no_protection")
	var names: PackedStringArray = []
	for z in d.zones:
		names.append(Tr.t("zone." + String(z)))
	return ", ".join(names)


func build_slot_detail(box: VBoxContainer, slot: String) -> void:
	box.add_child(UiKit.heading(Tr.t("slot." + slot).to_upper(), 22, UiTheme.PINK))
	var inst: String = gs.installed_id(slot)
	var base: Dictionary = preview.call({})
	for d in gs.parts_for_slot(slot):
		box.add_child(part_card(d, d.id == StringName(inst), base))
	if inst != "":
		var rm: Button = small_button(Tr.t("garage.remove"))
		rm.pressed.connect(func() -> void: gs.uninstall(slot))
		box.add_child(rm)


# ---------------------------------------------------------------- decoracao (cabecalho e pintura)

## Topo da aba DECORACAO: destaque total, peso e protecao por zona, e a escolha de pintura (cada cor soma destaque).
func build_deco_header(box: VBoxContainer) -> void:
	var pv: Dictionary = preview.call({})
	var cv: Array = card(UiTheme.PINK)
	var v: VBoxContainer = cv[1]
	v.add_child(UiKit.heading("%s %d" % [Tr.t("garage.destaque").to_upper(), gs.destaque()], 24, UiTheme.GOLD))
	v.add_child(wl("%s %d kg" % [Tr.t("garage.mass"), roundi(float(pv["mass"]))], 14, UiTheme.TEXT_DIM))
	var prot: Dictionary = gs.zone_protection()
	var parts: PackedStringArray = []
	for z in ["front", "rear", "left", "right"]:
		parts.append("%s %d" % [Tr.t("zone." + z), roundi(float(prot[z][0]))])
	v.add_child(wl("%s: %s" % [Tr.t("garage.protection"), " · ".join(parts)], 13, UiTheme.CYAN))
	box.add_child(cv[0])
	box.add_child(UiKit.heading(Tr.t("garage.paint").to_upper(), 18, UiTheme.PINK))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	var cur_hex: String = String(gs.profile.get("paint", "#e9eef5")).to_lower()
	for p in StyleCatalog.PAINTS:
		var hex: String = String(p["hex"])
		var locked: bool = gs.fame() < int(p["fame_required"])
		var sel: bool = hex.to_lower() == cur_hex
		var b := Button.new()
		b.custom_minimum_size = Vector2(62, 52)
		b.text = "+%d" % int(p["points"]) if not locked else "F%d" % int(p["fame_required"])
		b.tooltip_text = "%s · %s +%d" % [Tr.t("paint." + String(p["id"])), Tr.t("garage.destaque"), int(p["points"])]
		b.add_theme_font_size_override("font_size", 15)
		var col: Color = Color(hex)
		if locked:
			col = col.darkened(0.7)
		b.add_theme_stylebox_override("normal", UiTheme.box(col, UiTheme.GOLD if sel else Color(1, 1, 1, 0.25), 3 if sel else 1, 8, 4))
		b.add_theme_stylebox_override("hover", UiTheme.box(col.lightened(0.15), UiTheme.PINK, 2, 8, 4))
		b.add_theme_color_override("font_color", Color.BLACK if col.get_luminance() > 0.5 else Color.WHITE)
		b.disabled = locked
		b.pressed.connect(func() -> void:
			gs.profile["paint"] = hex
			gs.save_profile()
			AudioBus.play_ui("ui_select")
			gs.profile_changed.emit())
		grid.add_child(b)
	box.add_child(wl(Tr.t("garage.paint_hint"), 12, UiTheme.TEXT_DIM))
	box.add_child(UiKit.heading(Tr.t("garage.lights").to_upper(), 18, UiTheme.PINK))
	var cur_pat: String = String(gs.profile.get("light_pattern", "steady"))
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 6)
	row.add_theme_constant_override("v_separation", 6)
	box.add_child(row)
	for id in LightPatterns.IDS:
		var on: bool = id == cur_pat
		var pb: Button = UiTheme.button(Tr.t(LightPatterns.label_key(id)) + ("  ✔" if on else ""), Vector2(0, 38))
		pb.add_theme_font_size_override("font_size", 15)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.2) if on else Color(1, 1, 1, 0.04), UiTheme.PINK if on else Color(1, 1, 1, 0.12), 1, 8, 8))
		pb.pressed.connect(func() -> void:
			gs.profile["light_pattern"] = id
			gs.save_profile()
			AudioBus.play_ui("ui_select")
			gs.profile_changed.emit())
		row.add_child(pb)


# ---------------------------------------------------------------- adesivos

const DECAL_VIEW: Dictionary = {"side_l": "side", "side_r": "side", "rear": "rear", "cab": "front"}


## Secao ADESIVOS da aba DECORACAO: um cartao por lugar (esq., dir., traseira, cabine) com adesivo, posicao, tamanho e cor.
func build_decals(box: VBoxContainer) -> void:
	box.add_child(UiKit.heading(Tr.t("garage.decals").to_upper(), 18, UiTheme.PINK))
	box.add_child(wl(Tr.t("garage.decals_hint") % [StyleCatalog.DECAL_POINTS], 12, UiTheme.TEXT_DIM))
	var options: Array[String] = [""]
	options.append_array(DecalCatalog.ids())
	for slot in DecalCatalog.SLOTS:
		_decal_card(box, slot, options)


func _commit_decals(decals: Array) -> void:
	gs.profile["decals"] = decals
	gs.save_profile()
	gs.profile_changed.emit()


func _decal_card(box: VBoxContainer, slot: String, options: Array[String]) -> void:
	var decals: Array = gs.profile.get("decals", []) as Array
	var idx: int = DecalCatalog.find(decals, slot)
	var cur: Dictionary = decals[idx] if idx >= 0 else {}
	var cur_id: String = String(cur.get("id", ""))
	var cv: Array = card(UiTheme.PINK if idx >= 0 else Color(1, 1, 1, 0.1))
	var v: VBoxContainer = cv[1]
	v.add_child(wl("%s: %s" % [Tr.t("decal.slot." + slot), cur_id if cur_id != "" else "— " + Tr.t("garage.empty")], 16, UiTheme.GOLD if idx >= 0 else UiTheme.TEXT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for dir in [-1, 1]:
		var b: Button = small_button("◀" if dir < 0 else "▶", 60)
		b.pressed.connect(func() -> void:
			var n: int = options.size()
			var pick: String = options[(options.find(cur_id) + dir + n) % n]
			var list: Array = (gs.profile.get("decals", []) as Array).duplicate(true)
			var i2: int = DecalCatalog.find(list, slot)
			if pick == "":
				if i2 >= 0:
					list.remove_at(i2)
			elif i2 >= 0:
				(list[i2] as Dictionary)["id"] = pick
			else:
				list.append(DecalCatalog.make(pick, slot))
			AudioBus.play_ui("ui_select")
			if focus_view.is_valid():
				focus_view.call(String(DECAL_VIEW[slot]))
			_commit_decals(list))
		row.add_child(b)
	if idx < 0:
		box.add_child(cv[0])
		return
	for spec in [["x", "garage.decal_x", -1.0, 1.0], ["y", "garage.decal_y", -1.0, 1.0], ["size", "garage.decal_size", 0.15, 1.1]]:
		var key: String = String(spec[0])
		v.add_child(wl(Tr.t(String(spec[1])), 12, UiTheme.TEXT_DIM))
		var sl := HSlider.new()
		sl.min_value = float(spec[2])
		sl.max_value = float(spec[3])
		sl.step = 0.02
		sl.value = float(cur.get(key, 0.0))
		sl.custom_minimum_size = Vector2(0, 22)
		sl.value_changed.connect(func(val: float) -> void:
			var list: Array = gs.profile.get("decals", []) as Array
			var i3: int = DecalCatalog.find(list, slot)
			if i3 >= 0:
				(list[i3] as Dictionary)[key] = val
				if live_decals.is_valid():
					live_decals.call(list))
		sl.drag_ended.connect(func(_changed: bool) -> void: _commit_decals(gs.profile.get("decals", []) as Array))
		v.add_child(sl)
	var colors := HFlowContainer.new()
	colors.add_theme_constant_override("h_separation", 5)
	colors.add_theme_constant_override("v_separation", 5)
	v.add_child(colors)
	for hex in DecalCatalog.COLORS:
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(28, 28)
		var on: bool = String(cur.get("color", "#ffffff")).to_lower() == String(hex)
		cb.add_theme_stylebox_override("normal", UiTheme.box(Color(String(hex)), UiTheme.GOLD if on else Color(1, 1, 1, 0.3), 3 if on else 1, 6, 0))
		cb.add_theme_stylebox_override("hover", UiTheme.box(Color(String(hex)).lightened(0.2), UiTheme.PINK, 2, 6, 0))
		cb.pressed.connect(func() -> void:
			var list: Array = (gs.profile.get("decals", []) as Array).duplicate(true)
			var i4: int = DecalCatalog.find(list, slot)
			if i4 >= 0:
				(list[i4] as Dictionary)["color"] = String(hex)
				_commit_decals(list))
		colors.add_child(cb)
	box.add_child(cv[0])


# ---------------------------------------------------------------- mecanica

func build_mech(box: VBoxContainer) -> void:
	box.add_child(wl("Motor, turbo, escape e freio-motor. As mudanças mostram o efeito no 0–100.", 14, UiTheme.TEXT_DIM))
	var base: Dictionary = preview.call({})
	for kind in ["engine", "turbo", "exhaust", "upgrade"]:
		for id in gs.MECH_KINDS[kind]["ids"]:
			var def: Resource = gs.mech_def(String(id))
			var owned: bool = gs.owns_mech(String(id))
			var inst: bool = gs.mech_installed(String(id))
			var cv: Array = card(UiTheme.PINK if inst else Color(1, 1, 1, 0.1))
			var v: VBoxContainer = cv[1]
			var nm: String = Tr.t("%s.%s" % ["upgrade" if kind == "upgrade" else kind, id])
			v.add_child(wl(nm + ("  ✔" if inst else ""), 17, UiTheme.GOLD if inst else UiTheme.TEXT))
			var detail: String = ""
			match kind:
				"engine":
					detail = "%d N·m · corte %d rpm · +%d kg" % [int(def.get("max_torque_nm")), int(def.get("redline_rpm")), int(def.get("weight_kg"))]
				"turbo":
					detail = "+%d%% torque · atraso %.1f s" % [roundi(float(def.get("torque_gain")) * 100.0), float(def.get("lag_s"))]
				"exhaust":
					detail = "+%d%% torque · destaque +%d" % [roundi(float(def.get("torque_bonus")) * 100.0), int(def.get("fame"))]
				"upgrade":
					detail = "efeito %+d%%" % roundi(float(def.get("value")) * 100.0)
			v.add_child(wl(detail, 13, UiTheme.TEXT_DIM))
			if not inst:
				var ch: Dictionary = {}
				match kind:
					"engine", "turbo", "exhaust":
						ch = {kind: String(id)}
					"upgrade":
						if id == "jake_brake":
							ch = {"jake_brake": true}
				if not ch.is_empty():
					v.add_child(wl(delta_text(preview.call(ch), base), 13, UiTheme.CYAN))
			var b: Button
			if not owned:
				b = UiKit.primary_button("%s  %s" % [Tr.t("garage.buy"), Tr.yen(int(def.get("price")))], "", Vector2(0, 38))
				b.add_theme_font_size_override("font_size", 16)
				b.disabled = gs.can_buy_mech(String(id)) != ""
				b.pressed.connect(func() -> void: gs.buy_mech(String(id)))
			else:
				b = small_button(Tr.t("garage.install") if not inst else ("DESLIGAR" if kind == "upgrade" else Tr.t("garage.installed")))
				b.disabled = inst and kind != "upgrade"
				b.pressed.connect(func() -> void: gs.install_mech(String(id)))
			v.add_child(b)
			box.add_child(cv[0])


# ---------------------------------------------------------------- reparo (P43)

func build_repair(box: VBoxContainer) -> void:
	var total: int = gs.total_repair_cost()
	box.add_child(UiKit.heading("Total: " + Tr.yen(total), 22, UiTheme.GOLD))
	var all: Button = UiKit.primary_button("%s  %s" % [Tr.t("garage.repair_all"), Tr.yen(total)], "wrench", Vector2(0, 44))
	all.add_theme_font_size_override("font_size", 17)
	all.disabled = total <= 0 or gs.money() < 1
	all.pressed.connect(func() -> void:
		var spent: int = gs.repair_all()
		AudioBus.play_ui("ui_repair" if spent > 0 else "ui_error")
		flash.call("Reparos pagos: " + Tr.yen(spent)))
	box.add_child(all)
	box.add_child(wl("Fórmula: preço da peça × % de dano × 0,5. Mural riscado: repintar = 30% do preço.", 13, UiTheme.TEXT_DIM))
	var any: bool = false
	for id in gs.profile["owned"]:
		var cost: int = gs.part_repair_cost(String(id))
		if cost <= 0:
			continue
		any = true
		var d: PartDef = gs.part(String(id))
		var own: Dictionary = gs.profile["owned"][String(id)]
		var cv: Array = card(UiTheme.BAD if bool(own["broken"]) else UiTheme.WARN)
		var v: VBoxContainer = cv[1]
		v.add_child(wl(Tr.t("part." + String(id)), 17))
		var state: String
		if d.durability <= 0.0:
			state = "riscado %d%%" % roundi(float(own["scratch"]) * 100.0)
		elif bool(own["broken"]):
			state = "QUEBRADA"
		else:
			state = "dano %d%%" % roundi((1.0 - float(own["dur"]) / d.durability) * 100.0)
		v.add_child(wl(state, 14, UiTheme.BAD if bool(own["broken"]) else UiTheme.WARN))
		var row := VBoxContainer.new()                 # empilhados: dois botoes lado a lado nao cabem em 300 px
		v.add_child(row)
		var rb: Button = small_button("%s  %s" % [Tr.t("garage.repaint") if d.durability <= 0.0 else Tr.t("garage.repair_one"), Tr.yen(cost)])
		rb.disabled = gs.money() < cost
		rb.pressed.connect(func() -> void:
			if gs.repair_part(String(id)):
				AudioBus.play_ui("ui_repair"))
		row.add_child(rb)
		if bool(own["broken"]):
			var nb: Button = small_button("%s  %s" % [Tr.t("garage.buy_new"), Tr.yen(d.price)])
			nb.disabled = gs.money() < d.price
			nb.pressed.connect(func() -> void: gs.buy_new_replacement(String(id)))
			row.add_child(nb)
		box.add_child(cv[0])
	for sys in gs.SYSTEM_REPAIR_PRICE:
		var c2: int = gs.system_repair_cost(String(sys))
		if c2 <= 0:
			continue
		any = true
		var cv2: Array = card(UiTheme.WARN)
		var v2: VBoxContainer = cv2[1]
		v2.add_child(wl(Tr.t("repair." + String(sys)), 17))
		v2.add_child(wl("saúde %d%%" % roundi(float(gs.profile["systems"][sys])), 14, UiTheme.WARN))
		var sb: Button = small_button("%s  %s" % [Tr.t("garage.repair_one"), Tr.yen(c2)])
		sb.disabled = gs.money() < c2
		sb.pressed.connect(func() -> void:
			if gs.repair_system(String(sys)):
				AudioBus.play_ui("ui_repair"))
		v2.add_child(sb)
		box.add_child(cv2[0])
	if not any:
		box.add_child(wl(Tr.t("garage.nothing_to_repair"), 18, UiTheme.GOOD))
