class_name GarageInfoPanel
extends RefCounted
## Ficha tecnica da garagem: SO dados reais do jogo (GameState + EngineDef/TurboDef/ExhaustDef).
## Capacidade de carga vem de BodyDef (data/bodies/, via Contracts.capacity_t); torque x BodyDef.torque_mult. Potencia e tanque NAO existem nos dados e nao sao inventados (aviso na dica do titulo).
## T-155: linhas compactas (rotulo e valor na mesma linha) para a ficha inteira caber na tela de 540 de altura
## (16:9 e 20:9); antes a ultima linha visivel aparecia cortada ao meio (a rolagem continua de reserva).


static func build(parent: VBoxContainer, gs: Node, pv: Dictionary, on_customize: Callable) -> void:
	var box := VBoxContainer.new()                     # espacamento proprio, menor que o da coluna (8)
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	var body: String = String(gs.profile.get("body", "base"))
	var cab: String = CabCatalog.normalize(gs.profile.get("cab", ""))
	var head := HBoxContainer.new()                    # nome do modelo e "FICHA TECNICA" na mesma linha
	var title: Label = UiKit.heading(Tr.t("body." + body).to_upper(), 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var tag: Label = UiTheme.label(Tr.t("garage.spec_title"), 12, UiTheme.TEXT_DIM)
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_PASS
	tag.tooltip_text = Tr.t("garage.not_impl")          # "potencia e tanque nao existem": dica, nao cabe na tela
	title.tooltip_text = tag.tooltip_text
	title.mouse_filter = Control.MOUSE_FILTER_PASS
	head.add_child(tag)
	box.add_child(head)
	if TruckNode.FIXED_CAB.has(body):
		cab = "curta"
	box.add_child(UiTheme.label("%s %s" % [Tr.t("garage.cab"), Tr.t("cab." + cab)], 15, UiTheme.CYAN))
	box.add_child(UiKit.divider())
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	box.add_child(rows)
	var eng: EngineDef = gs.mech_def(String(gs.profile["engine"])) as EngineDef
	var turbo: TurboDef = gs.mech_def(String(gs.profile["turbo"])) as TurboDef
	var exh: ExhaustDef = gs.mech_def(String(gs.profile["exhaust"])) as ExhaustDef
	var gain: float = (turbo.torque_gain if turbo else 0.0) + (exh.torque_bonus if exh else 0.0)
	var bdef: BodyDef = BodyDef.find(body)
	var tq_mult: float = bdef.torque_mult if bdef != null else 1.0      # Canter: motor menor
	var torque: String = "%s N·m" % _thousands(roundi(eng.max_torque_nm * tq_mult)) if eng else "—"
	if gain > 0.0:
		torque += "  (+%d%%)" % roundi(gain * 100.0)
	rows.add_child(UiKit.stat_line("zap", Tr.t("garage.torque"), torque))
	var engine_name: String = Tr.t("engine.canter_note") if TruckNode.FIXED_CAB.has(body) else Tr.t("engine." + String(gs.profile["engine"]))
	rows.add_child(UiKit.stat_line("cog", Tr.t("garage.engine"), engine_name))
	rows.add_child(UiKit.stat_line("gauge", Tr.t("garage.redline"), "%s rpm" % _thousands(roundi(eng.redline_rpm) if eng else 0)))
	rows.add_child(UiKit.stat_line("package", Tr.t("garage.capacity"), "%d t" % roundi(Contracts.capacity_t(body))))
	rows.add_child(UiKit.stat_line("truck", Tr.t("garage.carries"), Tr.t("garage.carries." + String(Contracts.body_kind(body)))))
	rows.add_child(UiKit.stat_line("weight", Tr.t("garage.mass"), "%s kg" % _thousands(roundi(float(pv["mass"])))))
	rows.add_child(UiKit.stat_line("gauge", Tr.t("garage.zero100"), "%.1f s" % float(pv["zero100"])))
	rows.add_child(UiKit.stat_line("star", Tr.t("garage.rating"), "%d" % int(pv["rating"]), UiTheme.GOLD))
	var sys: Dictionary = gs.profile["systems"]
	var health: String = "%d%% / %d%%" % [roundi(float(sys["engine"])), roundi(float(sys["steering"]))]
	var hcol: Color = UiTheme.GOOD if minf(float(sys["engine"]), float(sys["steering"])) > 66.0 else UiTheme.WARN
	rows.add_child(UiKit.stat_line("shield", Tr.t("garage.state"), health, hcol))
	var rep: int = gs.total_repair_cost()
	rows.add_child(UiKit.stat_line("hammer", Tr.t("garage.repairs_pending"), Tr.yen(rep) if rep > 0 else "—", UiTheme.WARN if rep > 0 else UiTheme.TEXT))
	var b: Button = UiKit.primary_button(Tr.t("garage.customize"), "paintbrush", Vector2(0, 38))
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
