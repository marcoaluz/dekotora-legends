class_name GarageShop
extends RefCounted
## Cartoes da garagem (pecas, mecanica, reparo): comprar, instalar, vender e reparar. Toda acao passa pelo
## GameState (que salva o perfil e avisa `profile_changed`, e a tela se redesenha). Mostra o efeito no peso
## e no 0-100 ANTES de comprar.

var gs: Node
var preview: Callable          # func(changes: Dictionary) -> Dictionary (com cache na tela)
var flash: Callable            # func(text: String) -> void


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
