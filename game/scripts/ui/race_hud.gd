class_name RaceHud
extends Control
## HUD da corrida (480x270 de layout; o Godot escala nitido). Velocimetro, RPM e marcha, turbo,
## Passing, posicao, distancia ate o destino, integridade da carga e mini-diagrama do caminhao
## com as zonas coloridas pelo dano. Nao cobre os botoes de toque (cantos inferiores/laterais).

const PINK := Color("#ff2e88")
const CYAN := Color("#21e6ff")
const GOLD := Color("#f5cc5a")
const PANEL := Color(0.04, 0.04, 0.1, 0.62)
const OK_COL := Color("#3fb26f")
const WARN_COL := Color("#f5cc5a")
const BAD_COL := Color("#d1303f")

var sim: RaceSim
var player: int = 0
var countdown: float = 0.0
var banner: String = ""
var banner_time: float = 0.0


func bind(sim_: RaceSim, player_: int) -> void:
	sim = sim_
	player = player_
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = Vector2(480, 270)        # layout de 480x270 (o CanvasLayer pai escala 2x)


func show_banner(text: String, seconds: float = 1.6) -> void:
	banner = text
	banner_time = seconds


func _process(delta: float) -> void:
	banner_time = maxf(banner_time - delta, 0.0)
	queue_redraw()


func _font() -> Font:
	return ThemeDB.fallback_font


func _text(pos: Vector2, text: String, size: int, col: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f: Font = _font()
	draw_string(f, pos + Vector2(1, 1), text, align, width, size, Color(0, 0, 0, 0.7))
	draw_string(f, pos, text, align, width, size, col)


func _bar(rect: Rect2, value: float, col: Color, back: Color = Color(0, 0, 0, 0.5)) -> void:
	draw_rect(rect, back)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(value, 0.0, 1.0), rect.size.y)), col)
	draw_rect(rect, Color(1, 1, 1, 0.35), false, 1.0)


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
	# --- posicao (topo esquerdo)
	var pos: int = 1
	for k in sim.trucks.size():
		if k != player and sim.trucks[k].z > t.z:
			pos += 1
	draw_rect(Rect2(6, 6, 74, 38), PANEL)
	draw_rect(Rect2(6, 6, 3, 38), PINK)
	_text(Vector2(14, 41), "%d" % pos, 26, GOLD)
	_text(Vector2(36, 41), "/ %d" % sim.trucks.size(), 12, Color.WHITE)
	_text(Vector2(14, 16), "POSICAO", 8, Color(1, 1, 1, 0.7))
	# --- distancia ate o destino (topo, centro) com marcadores de todos
	var bar := Rect2(w * 0.5 - 100, 12, 200, 6)
	draw_rect(Rect2(bar.position - Vector2(4, 4), bar.size + Vector2(8, 22)), PANEL)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	for k in sim.trucks.size():
		var f: float = clampf(sim.trucks[k].z / sim.finish_z, 0.0, 1.0)
		var c: Color = PINK if k == player else Color(0.7, 0.8, 1.0)
		draw_rect(Rect2(bar.position.x + bar.size.x * f - 2, bar.position.y - 2, 4, 10), c)
	var remaining: float = maxf(sim.finish_z - t.z, 0.0)
	_text(Vector2(bar.position.x, bar.position.y + 22), "DESTINO  %.1f km" % (remaining / 1000.0), 9, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, bar.size.x)
	# --- carga e mini-diagrama (topo direito)
	var px: float = w - 94
	draw_rect(Rect2(px, 6, 88, 92), PANEL)
	draw_rect(Rect2(px + 85, 6, 3, 92), CYAN)
	_text(Vector2(px + 6, 16), "CARGA", 8, Color(1, 1, 1, 0.7))
	_bar(Rect2(px + 6, 20, 76, 6), t.cargo_integrity(), _health_color(t.cargo_integrity()))
	_draw_truck_diagram(Vector2(px + 44, 62), t)
	# --- velocimetro / RPM / marcha (embaixo, centro)
	var cx: float = w * 0.5
	var by: float = size.y - 6
	draw_rect(Rect2(cx - 78, by - 62, 156, 62), PANEL)
	var kmh: int = roundi(t.speed * 3.6)
	_text(Vector2(cx - 74, by - 22), "%d" % kmh, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 90.0)
	_text(Vector2(cx - 74, by - 8), "km/h", 9, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 90.0)
	var rpm_frac: float = clampf((t.rpm - EngineModel.IDLE_RPM) / (t.engine.redline_rpm - EngineModel.IDLE_RPM), 0.0, 1.0)
	_text(Vector2(cx + 20, by - 30), "%d" % t.gear, 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 24.0)
	_text(Vector2(cx + 20, by - 8), "MARCHA", 7, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 36.0)
	# arco de RPM
	draw_arc(Vector2(cx + 60, by - 26), 20.0, deg_to_rad(150), deg_to_rad(390), 24, Color(0, 0, 0, 0.6), 5.0)
	draw_arc(Vector2(cx + 60, by - 26), 20.0, deg_to_rad(150), deg_to_rad(150 + 240 * rpm_frac), 24, PINK if rpm_frac > 0.85 else CYAN, 5.0)
	_text(Vector2(cx + 40, by - 22), "RPM", 7, Color(1, 1, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 40.0)
	# turbo e passing
	_text(Vector2(cx - 74, by - 56), "TURBO", 7, Color(1, 1, 1, 0.7))
	_bar(Rect2(cx - 40, by - 62, 114, 5), t.boost, CYAN)
	_text(Vector2(cx - 74, by - 47), "PASSING", 7, Color(1, 1, 1, 0.7))
	var pcol: Color = PINK if t.passing_active else GOLD
	_bar(Rect2(cx - 40, by - 52, 114, 5), t.passing_charge, pcol)
	if t.draft > 0.1:
		_text(Vector2(cx - 74, by - 38), "VACUO", 8, CYAN)
	# --- contagem e avisos
	if countdown > 0.0:
		_text(Vector2(0, size.y * 0.4), "%d" % int(ceil(countdown)), 64, GOLD, HORIZONTAL_ALIGNMENT_CENTER, w)
	elif banner_time > 0.0:
		_text(Vector2(0, size.y * 0.35), banner, 28, PINK, HORIZONTAL_ALIGNMENT_CENTER, w)


## Caminhao visto de cima, com as 4 zonas coloridas pelo dano + motor/direcao.
func _draw_truck_diagram(c: Vector2, t: TruckSim) -> void:
	var body := Rect2(c - Vector2(11, 28), Vector2(22, 56))
	draw_rect(body, Color(0.15, 0.15, 0.22, 0.9))
	var zones: Dictionary = {
		"front": Rect2(c + Vector2(-11, -30), Vector2(22, 8)),
		"rear": Rect2(c + Vector2(-11, 22), Vector2(22, 8)),
		"left": Rect2(c + Vector2(-14, -18), Vector2(4, 36)),
		"right": Rect2(c + Vector2(10, -18), Vector2(4, 36)),
	}
	for z in zones:
		draw_rect(zones[z], _health_color(DamageModel.zone_health(t, String(z))))
	var eng: float = float(t.systems["engine"]) / 100.0
	var stg: float = float(t.systems["steering"]) / 100.0
	draw_circle(c + Vector2(0, -12), 4.0, _health_color(eng))
	draw_circle(c + Vector2(0, 4), 3.0, _health_color(stg))
	_text(c + Vector2(-30, 30), "M", 7, Color(1, 1, 1, 0.6))
	_text(c + Vector2(16, 30), "D", 7, Color(1, 1, 1, 0.6))
