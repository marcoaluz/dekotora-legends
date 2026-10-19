class_name GarageInfoPanel
extends RefCounted
## Ficha tecnica da garagem: SO dados reais do jogo (GameState + EngineDef/TurboDef/ExhaustDef).
## Capacidade de carga vem de BodyDef (data/bodies/, via Contracts.capacity_t); torque x BodyDef.torque_mult. Potencia e tanque NAO existem nos dados e nao sao inventados (aviso no rodape).


static func build(box: VBoxContainer, gs: Node, pv: Dictionary, on_customize: Callable) -> void:
	var body: String = String(gs.profile.get("body", "base"))
	var cab: String = CabCatalog.normalize(gs.profile.get("cab", ""))
	box.add_child(UiTheme.label(Tr.t("garage.spec_title"), 14, UiTheme.TEXT_DIM))
	box.add_child(UiKit.heading(Tr.t("body." + body).to_upper(), 26))
	if TruckNode.FIXED_CAB.has(body):
		cab = "curta"
	box.add_child(UiTheme.label("%s %s" % [Tr.t("garage.cab"), Tr.t("cab." + cab)], 16, UiTheme.CYAN))
	box.add_child(UiKit.divider())
	var eng: EngineDef = gs.mech_def(String(gs.profile["engine"])) as EngineDef
	var turbo: TurboDef = gs.mech_def(String(gs.profile["turbo"])) as TurboDef
	var exh: ExhaustDef = gs.mech_def(String(gs.profile["exhaust"])) as ExhaustDef
	var gain: float = (turbo.torque_gain if turbo else 0.0) + (exh.torque_bonus if exh else 0.0)
	var bdef: BodyDef = BodyDef.find(body)
	var tq_mult: float = bdef.torque_mult if bdef != null else 1.0      # Canter: motor menor
	var torque: String = "%s N·m" % _thousands(roundi(eng.max_torque_nm * tq_mult)) if eng else "—"
	if gain > 0.0:
		torque += "  (+%d%%)" % roundi(gain * 100.0)
	box.add_child(UiKit.stat_row("zap", Tr.t("garage.torque"), torque))
	var engine_name: String = Tr.t("engine.canter_note") if TruckNode.FIXED_CAB.has(body) else Tr.t("engine." + String(gs.profile["engine"]))
	box.add_child(UiKit.stat_row("cog", Tr.t("garage.engine"), engine_name))
	box.add_child(UiKit.stat_row("gauge", Tr.t("garage.redline"), "%s rpm" % _thousands(roundi(eng.redline_rpm) if eng else 0)))
	box.add_child(UiKit.stat_row("package", Tr.t("garage.capacity"), "%d t" % roundi(Contracts.capacity_t(body))))
	box.add_child(UiKit.stat_row("truck", Tr.t("garage.carries"), Tr.t("garage.carries." + String(Contracts.body_kind(body)))))
	box.add_child(UiKit.stat_row("weight", Tr.t("garage.mass"), "%s kg" % _thousands(roundi(float(pv["mass"])))))
	box.add_child(UiKit.stat_row("gauge", Tr.t("garage.zero100"), "%.1f s" % float(pv["zero100"])))
	box.add_child(UiKit.stat_row("star", Tr.t("garage.rating"), "%d" % int(pv["rating"]), UiTheme.GOLD))
	var sys: Dictionary = gs.profile["systems"]
	var health: String = "%d%% / %d%%" % [roundi(float(sys["engine"])), roundi(float(sys["steering"]))]
	var hcol: Color = UiTheme.GOOD if minf(float(sys["engine"]), float(sys["steering"])) > 66.0 else UiTheme.WARN
	box.add_child(UiKit.stat_row("shield", Tr.t("garage.state"), health, hcol))
	var rep: int = gs.total_repair_cost()
	box.add_child(UiKit.stat_row("hammer", Tr.t("garage.repairs_pending"), Tr.yen(rep) if rep > 0 else "—", UiTheme.WARN if rep > 0 else UiTheme.TEXT))
	var note: Label = UiTheme.label(Tr.t("garage.not_impl"), 12, UiTheme.TEXT_DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(250, 0)
	box.add_child(note)
	var b: Button = UiKit.primary_button(Tr.t("garage.customize"), "paintbrush", Vector2(0, 44))
	b.pressed.connect(on_customize)
	box.add_child(b)


## 12220 -> "12.220" (separador de milhar brasileiro).
static func _thousands(n: int) -> String:
	var s: String = str(absi(n))
	var out: String = ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
