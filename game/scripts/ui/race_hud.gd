class_name RaceHud
extends Control
## HUD da corrida (layout de 480x270; o CanvasLayer pai escala 2x). Regioes fixas e cantos livres para os
## botoes de toque: topo-esquerda = POSICAO; topo-centro = DESTINO (barra com todos os caminhoes + km);
## topo-direita = CARGA (integridade + diagrama de dano por zona, motor e direcao); baixo-centro = velocidade,
## marcha, RPM, turbo e Passing. Tudo vem do TruckSim/RaceSim (nada inventado: sem combustivel no jogo).
## Fontes da identidade visual (Rajdhani para numeros/titulos, Noto para rotulos).

const PINK := Color("#ff2e88")
const CYAN := Color("#21e6ff")
const GOLD := Color("#f5cc5a")
const LABEL := Color(1, 1, 1, 0.66)
const OK_COL := Color("#3fb26f")
const WARN_COL := Color("#f5cc5a")
const BAD_COL := Color("#d1303f")

var sim: RaceSim
var player: int = 0
var countdown: float = 0.0
var banner: String = ""
var banner_time: float = 0.0
var rival_idx: int = -1                  # indice do rival da rota (marcador dourado na barra de progresso)
var cargo_notice: Array[String] = []     # aviso da carga antes da largada (linhas)
var _hf: Font
var _bf: Font
var _panel_sb: StyleBoxFlat


func bind(sim_: RaceSim, player_: int) -> void:
	sim = sim_
	player = player_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(480, 270)        # layout de 480x270 (o CanvasLayer pai escala 2x)
	_hf = UiTheme.heading_font(true)
	_bf = load(UiTheme.BODY_FONT) as Font
	_panel_sb = UiTheme.box(Color(0.03, 0.04, 0.09, 0.66), Color(1, 1, 1, 0.12), 1, 5, 0)


func show_banner(text: String, seconds: float = 1.6) -> void:
	banner = text
	banner_time = seconds


func _process(delta: float) -> void:
	var want: Vector2 = get_viewport_rect().size / 2.0   # T-138: tela comprida = HUD mais largo (cantos nas bordas)
	if size != want:
		size = want
	banner_time = maxf(banner_time - delta, 0.0)
	queue_redraw()


func _num(pos: Vector2, text: String, size: int, col: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(_hf, pos + Vector2(0.6, 0.8), text, align, width, size, Color(0, 0, 0, 0.55))
	draw_string(_hf, pos, text, align, width, size, col)


func _lbl(pos: Vector2, text: String, size: int = 8, col: Color = LABEL, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string(_bf, pos, text, align, width, size, col)


func _panel(r: Rect2, accent: Color = Color(0, 0, 0, 0), accent_left: bool = true) -> void:
	draw_style_box(_panel_sb, r)
	if accent.a > 0.0:
		var x: float = r.position.x if accent_left else r.end.x - 2.0
		draw_rect(Rect2(x, r.position.y + 4, 2, r.size.y - 8), accent)


func _bar(r: Rect2, value: float, col: Color) -> void:
	draw_rect(r, Color(1, 1, 1, 0.1))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(value, 0.0, 1.0), r.size.y)), col)


func _health_color(h: float) -> Color:
	if h > 0.66:
		return OK_COL
	if h > 0.33:
		return WARN_COL
	return BAD_COL


func _draw() -> void:
	if sim == null or sim.trucks.is_empty():
		return
	var t: TruckSim = sim.trucks[player]
	var w: float = size.x
	_draw_position(t)
	_draw_destination(t, w)
	_draw_cargo(t, w)
	_draw_timer(w)
	_draw_dash(t, w)
	if Settings.show_fps:
		_lbl(Vector2(w * 0.5 - 20, 66), "FPS %d" % Engine.get_frames_per_second(), 8, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	if countdown > 0.0:
		var low: float = 0.58 if cargo_notice.is_empty() else 0.6
		_num(Vector2(0, size.y * low), "%d" % int(ceil(countdown)), 56, GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
		_num(Vector2(0, size.y * 0.7), Tr.t("hud.lane_hint"), 11, Color(1, 1, 1, 0.85), HORIZONTAL_ALIGNMENT_CENTER, w)
		_draw_cargo_notice(w)
	elif banner_time > 0.0:
		_num(Vector2(0, size.y * 0.36), banner, 26, PINK, HORIZONTAL_ALIGNMENT_CENTER, w)


func _draw_position(t: TruckSim) -> void:
	var pos: int = 1
	for k in sim.trucks.size():
		if k != player and sim.trucks[k].z > t.z:
			pos += 1
	var r := Rect2(6, 6, 74, 42)
	_panel(r, PINK)
	_lbl(Vector2(13, 18), Tr.t("hud.position"), 8)
	_num(Vector2(13, 44), "%d" % pos, 30, GOLD)
	_num(Vector2(33, 44), "/ %d" % sim.trucks.size(), 13, Color.WHITE)


func _draw_destination(t: TruckSim, w: float) -> void:
	var r := Rect2(w * 0.5 - 104, 6, 208, 30)
	_panel(r)
	var remaining: float = maxf(sim.finish_z - t.z, 0.0)
	_lbl(Vector2(r.position.x + 8, 17), Tr.t("hud.destination"), 8)
	_num(Vector2(r.position.x, 17), ("%.1f km" % (remaining / 1000.0)).replace(".", ","), 11, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8)
	var bar := Rect2(r.position.x + 8, 23, r.size.x - 16, 4)
	draw_rect(bar, Color(1, 1, 1, 0.12))
	var f_me: float = clampf(t.z / sim.finish_z, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * f_me, bar.size.y)), Color(CYAN, 0.55))
	for k in sim.trucks.size():                      # os outros ficam discretos; voce (rosa) e o rival (dourado) aparecem
		if k == player or k == rival_idx:
			continue
		var fo: float = clampf(sim.trucks[k].z / sim.finish_z, 0.0, 1.0)
		draw_rect(Rect2(bar.position.x + bar.size.x * fo - 1.0, bar.position.y - 1, 2, 6), Color(0.75, 0.82, 1.0, 0.55))
	if rival_idx >= 0 and rival_idx < sim.trucks.size():
		var fr: float = clampf(sim.trucks[rival_idx].z / sim.finish_z, 0.0, 1.0)
		var rx: float = bar.position.x + bar.size.x * fr
		draw_rect(Rect2(rx - 1.5, bar.position.y - 3, 3, 10), GOLD)
		draw_colored_polygon(PackedVector2Array([Vector2(rx - 3, bar.position.y + 8), Vector2(rx + 3, bar.position.y + 8), Vector2(rx, bar.position.y + 4)]), GOLD)
		var gap_m: float = sim.trucks[rival_idx].z - t.z
		var gap_txt: String = "%s %s%d m" % [Tr.t("hud.rival"), "+" if gap_m >= 0.0 else "-", int(absf(gap_m))]
		_lbl(Vector2(r.position.x, 17), gap_txt, 8, GOLD if gap_m >= 0.0 else OK_COL, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	var fm: float = f_me
	draw_rect(Rect2(bar.position.x + bar.size.x * fm - 2.0, bar.position.y - 3, 4, 10), PINK)
	draw_colored_polygon(PackedVector2Array([Vector2(bar.position.x + bar.size.x * fm - 3, bar.position.y - 5), Vector2(bar.position.x + bar.size.x * fm + 3, bar.position.y - 5), Vector2(bar.position.x + bar.size.x * fm, bar.position.y - 1)]), PINK)


## Aviso da carga antes da largada: nome, peso e o que muda na direcao (fragil/pesada/pereciv.).
func _draw_cargo_notice(w: float) -> void:
	if cargo_notice.is_empty():
		return
	var h: float = 14.0 + 13.0 * cargo_notice.size()
	var r := Rect2(w * 0.5 - 130, 66, 260, h)
	_panel(r, GOLD)
	for i in cargo_notice.size():
		_num(Vector2(r.position.x, r.position.y + 15.0 + 13.0 * i), cargo_notice[i], 11 if i == 0 else 9, GOLD if i == 0 else Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Tempo de viagem (sobe) e prazo de entrega (desce). O prazo fica vermelho e pisca nos ultimos 15 s.
func _draw_timer(w: float) -> void:
	if sim.deadline <= 0.0:
		return
	var r := Rect2(w * 0.5 - 104, 40, 208, 18)
	_panel(r)
	var run: float = minf(sim.time, sim.deadline)
	var left: float = sim.time_left()
	_lbl(Vector2(r.position.x + 8, 52), Tr.t("hud.time"), 8)
	_num(Vector2(r.position.x + 40, 53), _clock(run), 11, Color.WHITE)
	var urgent: bool = left < 15.0
	var col: Color = Color.WHITE
	if urgent:
		col = BAD_COL if int(Time.get_ticks_msec() / 250) % 2 == 0 else Color.WHITE
	elif left < 30.0:
		col = WARN_COL
	_lbl(Vector2(r.position.x + 108, 52), Tr.t("hud.deadline"), 8)
	_num(Vector2(r.position.x + 140, 53), _clock(left), 11, col)


static func _clock(seconds: float) -> String:
	var s: int = int(ceil(seconds))
	return "%d:%02d" % [s / 60, s % 60]


func _draw_cargo(t: TruckSim, w: float) -> void:
	var r := Rect2(w - 94, 6, 88, 96)
	_panel(r, CYAN, false)
	var ci: float = t.cargo_integrity()
	_lbl(Vector2(r.position.x + 7, 17), Tr.t("hud.cargo"), 8)
	_num(Vector2(r.position.x, 17), "%d%%" % roundi(ci * 100.0), 11, _health_color(ci), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 8)
	_bar(Rect2(r.position.x + 7, 21, r.size.x - 15, 4), ci, _health_color(ci))
	_draw_truck_diagram(Vector2(r.position.x + 44, 62), t)


func _draw_dash(t: TruckSim, w: float) -> void:
	var cx: float = w * 0.5
	var r := Rect2(cx - 82, size.y - 66, 164, 60)    # nao encosta nos botoes de toque
	_panel(r)
	var x0: float = r.position.x + 8
	var y0: float = r.position.y
	# turbo e Passing (barras finas no topo do painel)
	_lbl(Vector2(x0, y0 + 10), "TURBO", 7)
	_bar(Rect2(x0 + 34, y0 + 5, 52, 4), t.boost, CYAN)
	_lbl(Vector2(x0 + 92, y0 + 10), "PASSING", 7)
	_bar(Rect2(x0 + 126, y0 + 5, 24, 4), t.passing_charge, PINK if t.passing_active else GOLD)
	# velocidade
	var kmh: int = roundi(t.speed * 3.6)
	var kmh_col: Color = BAD_COL if t.jolted() else Color.WHITE      # T-152: vermelho no tranco (a batida custou velocidade)
	_num(Vector2(x0 - 4, y0 + 44), "%d" % kmh, 34, kmh_col, HORIZONTAL_ALIGNMENT_CENTER, 66.0)
	_lbl(Vector2(x0 - 4, y0 + 55), "km/h", 8, LABEL, HORIZONTAL_ALIGNMENT_CENTER, 66.0)
	# marcha
	_num(Vector2(x0 + 62, y0 + 44), "%d" % t.gear, 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 34.0)
	_lbl(Vector2(x0 + 54, y0 + 55), Tr.t("hud.gear"), 7, LABEL, HORIZONTAL_ALIGNMENT_CENTER, 50.0)
	# RPM: arco com marcas e faixa vermelha
	var c := Vector2(x0 + 128, y0 + 38)
	var rad: float = 16.0
	var rpm_frac: float = clampf((t.rpm - EngineModel.IDLE_RPM) / (t.engine.redline_rpm - EngineModel.IDLE_RPM), 0.0, 1.0)
	var a0: float = deg_to_rad(150.0)
	var span: float = deg_to_rad(240.0)
	draw_arc(c, rad, a0, a0 + span, 28, Color(1, 1, 1, 0.12), 4.0)
	draw_arc(c, rad, a0 + span * 0.85, a0 + span, 8, Color(BAD_COL, 0.7), 4.0)
	draw_arc(c, rad, a0, a0 + span * rpm_frac, 28, PINK if rpm_frac > 0.85 else CYAN, 4.0)
	for i in 7:
		var a: float = a0 + span * i / 6.0
		draw_line(c + Vector2.from_angle(a) * (rad - 6), c + Vector2.from_angle(a) * (rad - 3), Color(1, 1, 1, 0.4), 1.0)
	_lbl(Vector2(c.x - 15, c.y + 3), "RPM", 7, LABEL, HORIZONTAL_ALIGNMENT_CENTER, 30.0)
	_draw_lane_signal(t, cx, r.position.y - 9.0)
	_draw_curve_warning(t, cx, r.position.y - 44.0)
	if t.draft > 0.1:                                # chip de vacuo acima do painel
		var dr := Rect2(cx - 24, r.position.y - 27, 48, 11)
		draw_style_box(_panel_sb, dr)
		_lbl(Vector2(dr.position.x, dr.position.y + 8.5), Tr.t("hud.draft"), 7, CYAN, HORIZONTAL_ALIGNMENT_CENTER, dr.size.x)


## Aviso de curva (T-132): amarelo "CURVA! ALIVIE" quando a velocidade passa do limite da curva a frente;
## vermelho piscando "DERRAPANDO!" quando o caminhao perdeu a faixa (passou de +30%).
func _draw_curve_warning(t: TruckSim, cx: float, y: float) -> void:
	var warn: float = t.curve_warning(sim.track) if countdown <= 0.0 else 0.0
	if not t.escaping and warn <= 0.0:
		return
	var blink: bool = int(Time.get_ticks_msec() / 140) % 2 == 0
	var col: Color = (BAD_COL if blink else Color.WHITE) if t.escaping else Color(WARN_COL, 0.55 + 0.45 * warn)
	var text: String = Tr.t("hud.curve_escape") if t.escaping else Tr.t("hud.curve_warn")
	var r := Rect2(cx - 60, y, 120, 15)
	_panel(r, col)
	_num(Vector2(r.position.x, r.position.y + 12), text, 11, col, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


## Setas de faixa: a do lado escolhido pisca em ambar enquanto o 2o toque ainda vale; pontos mostram a faixa atual.
func _draw_lane_signal(t: TruckSim, cx: float, y: float) -> void:
	var blink: bool = int(Time.get_ticks_msec() / 160) % 2 == 0
	for side in [-1, 1]:
		var on: bool = t.signal_dir == side
		var col: Color = Color("#ffa30d") if on and blink else (Color(1, 1, 1, 0.16) if not on else Color(1, 1, 1, 0.3))
		var c := Vector2(cx + side * 50.0, y)
		draw_colored_polygon(PackedVector2Array([c + Vector2(side * 7.0, 0), c + Vector2(-side * 4.0, -6), c + Vector2(-side * 4.0, 6)]), col)
	for i in 5:
		var lc := Vector2(cx - 12.0 + i * 6.0, y)
		var cur: bool = i == t.lane
		draw_circle(lc, 2.2 if cur else 1.4, Color.WHITE if cur else Color(1, 1, 1, 0.3))
	_draw_horn_icon(Vector2(cx - 31.0, y), t.horn)
	_draw_brake_icon(Vector2(cx + 31.0, y), t.hard_braking)


## Buzina (T-144, como no original: seta · buzina · seta): corneta que acende em dourado com ondas de som.
func _draw_horn_icon(c: Vector2, on: bool) -> void:
	var col: Color = GOLD if on else Color(1, 1, 1, 0.22)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-4, -1.5), c + Vector2(2.5, -4.5), c + Vector2(2.5, 4.5), c + Vector2(-4, 1.5)]), col)
	draw_rect(Rect2(c + Vector2(-6.5, -1.2), Vector2(2.5, 2.4)), col)
	if on:
		for k in 2:
			draw_arc(c + Vector2(3.0, 0), 3.5 + k * 2.5, -0.9, 0.9, 8, Color(GOLD, 0.85 - k * 0.3), 1.0, true)


## Freada forte (T-144): circulo com "!" que acende em vermelho.
func _draw_brake_icon(c: Vector2, on: bool) -> void:
	var col: Color = BAD_COL if on else Color(1, 1, 1, 0.22)
	draw_arc(c, 4.5, 0.0, TAU, 16, col, 1.2, true)
	draw_arc(c, 6.5, 2.4, 3.9, 6, col, 1.0, true)
	draw_arc(c, 6.5, -0.75, 0.75, 6, col, 1.0, true)
	draw_line(c + Vector2(0, -2.6), c + Vector2(0, 0.8), col, 1.3)
	draw_circle(c + Vector2(0, 2.3), 0.7, col)


## Caminhao visto de cima, com as 4 zonas coloridas pelo dano + motor (M) e direcao (D).
func _draw_truck_diagram(c: Vector2, t: TruckSim) -> void:
	var body := Rect2(c - Vector2(11, 28), Vector2(22, 56))
	draw_rect(body, Color(0.15, 0.16, 0.24, 0.9))
	var zones: Dictionary = {
		"front": Rect2(c + Vector2(-11, -30), Vector2(22, 7)),
		"rear": Rect2(c + Vector2(-11, 23), Vector2(22, 7)),
		"left": Rect2(c + Vector2(-14, -18), Vector2(3, 36)),
		"right": Rect2(c + Vector2(11, -18), Vector2(3, 36)),
	}
	for z in zones:
		draw_rect(zones[z], _health_color(DamageModel.zone_health(t, String(z))))
	var eng: float = float(t.systems["engine"]) / 100.0
	var stg: float = float(t.systems["steering"]) / 100.0
	draw_circle(c + Vector2(0, -12), 4.0, _health_color(eng))
	draw_circle(c + Vector2(0, 4), 3.0, _health_color(stg))
	_lbl(c + Vector2(-34, -9), "M", 8, LABEL)
	_lbl(c + Vector2(-34, 7), "D", 8, LABEL)
	draw_line(c + Vector2(-28, -12), c + Vector2(-5, -12), Color(1, 1, 1, 0.25), 1.0)
	draw_line(c + Vector2(-28, 4), c + Vector2(-4, 4), Color(1, 1, 1, 0.25), 1.0)
