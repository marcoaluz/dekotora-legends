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
var _decals: GarageDecals


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
				flash.call(Tr.t("garage.bought", [Tr.t("part." + String(d.id))]))
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


## Secao ADESIVOS (GarageDecals, arquivo proprio). O objeto fica guardado: os botoes chamam metodos dele.
func build_decals(box: VBoxContainer) -> void:
	_decals = GarageDecals.new(gs, live_decals, focus_view)
	_decals.build(box)


# ---------------------------------------------------------------- mecanica

func build_mech(box: VBoxContainer) -> void:
	box.add_child(wl(Tr.t("garage.mech_hint"), 14, UiTheme.TEXT_DIM))
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
					detail = Tr.t("garage.mech_engine", [int(def.get("max_torque_nm")), int(def.get("redline_rpm")), int(def.get("weight_kg"))])
				"turbo":
					detail = Tr.t("garage.mech_turbo", [roundi(float(def.get("torque_gain")) * 100.0), float(def.get("lag_s"))])
				"exhaust":
					detail = Tr.t("garage.mech_exhaust", [roundi(float(def.get("torque_bonus")) * 100.0), int(def.get("fame"))])
				"upgrade":
					detail = Tr.t("garage.mech_upgrade", [roundi(float(def.get("value")) * 100.0)])
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
				b = small_button(Tr.t("garage.install") if not inst else (Tr.t("garage.turn_off") if kind == "upgrade" else Tr.t("garage.installed")))
				b.disabled = inst and kind != "upgrade"
				b.pressed.connect(func() -> void:
					if gs.install_mech(String(id)) and kind != "upgrade":
						GarageHorns.preview_engine(gs, {}))           # T-173: ouve o motor como ficou
			if kind == "upgrade":
				v.add_child(b)
			else:                                              # T-173: OUVIR = trecho do motor com este item
				v.add_child(GarageHorns.with_listen(b, func() -> void: GarageHorns.preview_engine(gs, {kind: String(id)})))
			box.add_child(cv[0])
	GarageHorns.build(box, gs)


# ---------------------------------------------------------------- reparo (P43)

func build_repair(box: VBoxContainer) -> void:
	var total: int = gs.total_repair_cost()
	box.add_child(UiKit.heading(Tr.t("garage.repair_total", [Tr.yen(total)]), 22, UiTheme.GOLD))
	var all: Button = UiKit.primary_button("%s  %s" % [Tr.t("garage.repair_all"), Tr.yen(total)], "wrench", Vector2(0, 44))
	all.add_theme_font_size_override("font_size", 17)
	all.disabled = total <= 0 or gs.money() < 1
	all.pressed.connect(func() -> void:
		var spent: int = gs.repair_all()
		AudioBus.play_ui("ui_repair" if spent > 0 else "ui_error")
		flash.call(Tr.t("garage.repairs_paid", [Tr.yen(spent)])))
	box.add_child(all)
	box.add_child(wl(Tr.t("garage.repair_formula"), 13, UiTheme.TEXT_DIM))
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
			state = Tr.t("garage.state_scratched", [roundi(float(own["scratch"]) * 100.0)])
		elif bool(own["broken"]):
			state = Tr.t("part_state.broken").to_upper()
		else:
			state = Tr.t("garage.state_damage", [roundi((1.0 - float(own["dur"]) / d.durability) * 100.0)])
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
		v2.add_child(wl(Tr.t("garage.state_health", [roundi(float(gs.profile["systems"][sys]))]), 14, UiTheme.WARN))
		var sb: Button = small_button("%s  %s" % [Tr.t("garage.repair_one"), Tr.yen(c2)])
		sb.disabled = gs.money() < c2
		sb.pressed.connect(func() -> void:
			if gs.repair_system(String(sys)):
				AudioBus.play_ui("ui_repair"))
		v2.add_child(sb)
		box.add_child(cv2[0])
	if not any:
		box.add_child(wl(Tr.t("garage.nothing_to_repair"), 18, UiTheme.GOOD))
