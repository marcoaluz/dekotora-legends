class_name ResultScreen
extends Control
## Tela de resultado da corrida (P33, T-138): titulo (vitoria / derrota / tempo esgotado), frases simples do que
## aconteceu (ResultText), numeros do frete a esquerda e os danos a direita. Layout por containers, centralizado:
## cabe em 960x540 e em celular comprido (20:9). Recebe o Dictionary de RaceRules.build_result.
## Use num CanvasLayer SEM escala. Emite `continue_pressed` no botao.

signal continue_pressed

var _res: Dictionary = {}
var continue_button: Button


func show_result(res: Dictionary) -> void:
	_res = res
	theme = UiTheme.make()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	for c in get_children():
		c.queue_free()
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.07, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin: MarginContainer = UiKit.screen_margin(24, 14)
	add_child(margin)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	var panel: PanelContainer = UiKit.glass_panel(0.94)
	panel.custom_minimum_size = Vector2(820, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var won: bool = String(res.get("outcome", "win")) == "win"
	var title: Label = UiKit.heading(ResultText.title(res), 40, UiTheme.GOLD if won else UiTheme.BAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var lines: Array[String] = ResultText.lines(res)
	var why: Label = _wrap(lines[0], 17, UiTheme.TEXT)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(why)
	v.add_child(UiKit.divider())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)
	v.add_child(cols)
	cols.add_child(_numbers(won))
	cols.add_child(_story(lines.slice(1)))
	continue_button = UiKit.primary_button(Tr.t("result.continue"), "play", Vector2(240, 46))
	continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	continue_button.pressed.connect(func() -> void: continue_pressed.emit())
	v.add_child(continue_button)
	continue_button.grab_focus.call_deferred()
	visible = true


## Coluna da esquerda: tempo, prazo, frete, perdas, bonus e o PAGAMENTO em destaque.
func _numbers(won: bool) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(330, 0)
	col.add_theme_constant_override("separation", 2)
	var rows: Array = [
		[Tr.t("result.time"), ResultText.race_clock(float(_res.get("time", 0.0))), UiTheme.TEXT],
		[Tr.t("result.deadline"), ResultText.clock(float(_res.get("deadline", 0.0))), UiTheme.TEXT],
		[Tr.t("result.freight"), Tr.yen(int(_res.get("freight", 0))), UiTheme.TEXT if won else UiTheme.TEXT_DIM],
	]
	if won:
		rows.append([Tr.t("result.cargo_row"), "-" + Tr.yen(int(_res.get("cargo_loss_yen", 0))), UiTheme.BAD if int(_res.get("cargo_loss_yen", 0)) > 0 else UiTheme.TEXT])
		rows.append([Tr.t("result.position_bonus"), "+" + Tr.yen(int(_res.get("position_bonus", 0))), UiTheme.GOOD])
	rows.append([Tr.t("result.overtakes_row"), str(int(_res.get("overtakes", 0))), UiTheme.TEXT])
	rows.append([Tr.t("result.destaque"), str(int(_res.get("destaque", 0))), UiTheme.TEXT])
	rows.append([Tr.t("result.fame"), "+%d" % int(_res.get("fame", 0)), UiTheme.CYAN])
	for r in rows:
		col.add_child(_row(String(r[0]), String(r[1]), 16, r[2]))
	col.add_child(UiKit.divider())
	col.add_child(_row(Tr.t("result.pay"), Tr.yen(int(_res.get("pay", 0))), 22, UiTheme.GOLD if won else UiTheme.TEXT_DIM, UiTheme.PINK))
	return col


## Coluna da direita: frases (carga, pecas, fama) e a lista das pecas danificadas + sistemas.
func _story(lines: Array) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	col.add_child(UiKit.heading(Tr.t("result.summary"), 16, UiTheme.PINK))
	for l in lines:
		col.add_child(_wrap("• " + String(l), 15, UiTheme.TEXT))
	col.add_child(UiKit.heading(Tr.t("result.damage"), 16, UiTheme.PINK))
	var damaged: Array = (_res.get("parts", []) as Array).filter(func(p: Dictionary) -> bool: return String(p.get("state", "ok")) != "ok")
	var shown: int = 0
	for p in damaged:
		if shown >= 3:                       # o resto fica na garagem (aba REPARO); a tela nao cresce sem fim
			col.add_child(UiTheme.label("+%d…" % (damaged.size() - shown), 14, UiTheme.TEXT_DIM))
			break
		var st: String = String(p["state"])
		col.add_child(_row(Tr.t("part." + String(p["id"])), ResultText.state_name(st), 14, ResultText.state_color(st)))
		shown += 1
	var sys: Dictionary = _res.get("systems", {}) as Dictionary
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	for k in ["engine", "steering", "cargo"]:
		var pct: int = roundi(float(sys.get(k, 100.0)))
		var c: Color = UiTheme.GOOD if pct >= 80 else (UiTheme.WARN if pct >= 50 else UiTheme.BAD)
		h.add_child(UiTheme.label("%s %d%%" % [Tr.t("result.sys_" + k), pct], 14, c))
	col.add_child(h)
	return col


func _row(left: String, right: String, size: int, right_color: Color, left_color: Color = UiTheme.TEXT_DIM) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l: Label = UiTheme.label(left, size, left_color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	var r: Label = UiTheme.label(right, size, right_color)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(r)
	return h


func _wrap(text: String, size: int, color: Color) -> Label:
	var l: Label = UiTheme.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(200, 0)
	return l


## Resultado de mentira para capturas/depuracao (`--demo=result|result_lose|result_timeout`). Nao toca no perfil.
static func demo_result(kind: String) -> Dictionary:
	var parts: Array = [{"id": "fb_gold_wing", "state": "dent", "dur": 30.0, "max": 60.0},
			{"id": "rb_chrome", "state": "broken", "dur": 0.0, "max": 50.0},
			{"id": "hub_chrome", "state": "ok", "dur": 40.0, "max": 40.0}]
	var res: Dictionary = {"position": 1, "time": 184.37, "outcome": "win", "deadline": 240.0, "time_left": 55.63,
		"cargo": 0.85, "cargo_loss": 0.06, "cargo_loss_yen": 2880, "cargo_trait": "fragile", "cargo_hits": 2,
		"cargo_touches": 3, "cargo_from_damage": 0.0, "destaque": 42, "freight": 48000, "position_bonus": 9600,
		"fame": 118, "pay": 66520, "overtakes": 5, "parts": parts, "systems": {"engine": 92.0, "steering": 71.0, "cargo": 85.0}}
	match kind:
		"result_lose":
			res.merge({"position": 2, "outcome": "lose_rival", "time_left": 40.0, "fame": 0, "pay": 0, "position_bonus": 0,
				"cargo_trait": "normal"}, true)
		"result_timeout":
			res.merge({"position": 4, "outcome": "timeout", "time": 240.0, "time_left": 0.0, "fame": 0, "pay": 0,
				"position_bonus": 0, "cargo_loss": 0.0, "cargo_hits": 0, "cargo_touches": 0, "parts": []}, true)
	return res
