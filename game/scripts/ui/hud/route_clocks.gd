class_name RouteClocks
extends Control
## T-202: top right of the race HUD. Two clocks with kanji + pt-BR labels, like the original:
## 走行時間 (TEMPO DE PERCURSO, counts up) and 残り時間 (TEMPO RESTANTE = delivery deadline, counts down; yellow under
## 30 s, red blinking under 15 s). Under them the route progress bar with a numbered marker per truck (1-2 in a duel,
## 3-4 in a convoy: the number is the start slot; you = pink, the route rival = gold) and the finish flag; then the
## distance to the destination and the gap to the rival. Local size HudLayout.CLOCKS (shorter without a deadline).

const BAR_X0: float = 8.0
const BAR_X1: float = 136.0

var sim: RaceSim
var player: int = 0
var rival: int = -1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = HudLayout.CLOCKS


func _process(_delta: float) -> void:
	queue_redraw()


func height() -> float:
	return HudLayout.CLOCKS.y if sim != null and sim.deadline > 0.0 else HudLayout.CLOCKS.y - 19.0


func _draw() -> void:
	if sim == null or sim.trucks.is_empty():
		return
	var w: float = HudLayout.CLOCKS.x
	HudStyle.panel(self, Rect2(0, 0, w, height()))
	var run: float = sim.time if sim.deadline <= 0.0 else minf(sim.time, sim.deadline)
	var y: float = 0.0
	_clock_row(y, Tr.t("hud.clock.run_jp"), Tr.t("hud.clock.run"), HudStyle.clock(run), Color.WHITE)
	y += 19.0
	if sim.deadline > 0.0:
		var left: float = sim.time_left()
		var col: Color = Color.WHITE
		if left < 15.0:
			col = HudStyle.BAD_COL if int(Time.get_ticks_msec() / 250) % 2 == 0 else Color.WHITE
		elif left < 30.0:
			col = HudStyle.WARN_COL
		_clock_row(y, Tr.t("hud.clock.left_jp"), Tr.t("hud.clock.left"), HudStyle.clock(left), col)
		y += 19.0
	_progress(y + 12.0)
	_footer(y + 30.0)


func _clock_row(y: float, jp: String, pt: String, value: String, col: Color) -> void:
	HudStyle.lbl(self, Vector2(6, y + 11.0), jp, 9, HudStyle.KANJI)
	HudStyle.lbl(self, Vector2(6, y + 18.0), pt, 6, HudStyle.LABEL)
	HudStyle.num(self, Vector2(0, y + 16.5), value, 15, col, HORIZONTAL_ALIGNMENT_RIGHT, HudLayout.CLOCKS.x - 6.0)


func _progress(y: float) -> void:
	var me: TruckSim = sim.trucks[player]
	var len_px: float = BAR_X1 - BAR_X0
	draw_rect(Rect2(BAR_X0, y - 1.0, len_px, 2.0), Color(1, 1, 1, 0.22))
	var f_me: float = _frac(me.z)
	draw_rect(Rect2(BAR_X0, y - 1.0, len_px * f_me, 2.0), Color(HudStyle.CYAN, 0.6))
	for k in 5:                                       # quarter ticks
		draw_line(Vector2(BAR_X0 + len_px * k / 4.0, y - 2.5), Vector2(BAR_X0 + len_px * k / 4.0, y + 2.5), Color(1, 1, 1, 0.25), 1.0)
	_flag(Vector2(BAR_X1 + 3.0, y - 4.0))
	var order: Array[int] = []                        # others first, the player on top
	for k in sim.trucks.size():
		if k != player:
			order.append(k)
	order.append(player)
	for k in order:
		var col: Color = HudStyle.PINK if k == player else (HudStyle.GOLD if k == rival else Color("#9cc8ff"))
		_marker(Vector2(BAR_X0 + len_px * _frac(sim.trucks[k].z), y), k + 1, col, k == player)


func _frac(z: float) -> float:
	return clampf(z / maxf(sim.finish_z, 1.0), 0.0, 1.0)


## Numbered marker: the player's sits ABOVE the bar pointing down, the others BELOW pointing up, so a rival right
## beside you is never hidden.
func _marker(at: Vector2, n: int, col: Color, me: bool) -> void:
	var r: float = 4.6 if me else 4.0
	var dir: float = -1.0 if me else 1.0              # -1 = above the bar
	var c: Vector2 = at + Vector2(0, dir * 6.2)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-2.0, -dir * 2.5), c + Vector2(2.0, -dir * 2.5), at + Vector2(0, -dir * 0.6)]), col)
	draw_circle(c + Vector2(0.4, 0.6), r, Color(0, 0, 0, 0.5))
	draw_circle(c, r, col)
	draw_arc(c, r, 0.0, TAU, 14, Color(1, 1, 1, 0.8 if me else 0.4), 0.8)
	HudStyle.num(self, c + Vector2(-5.0, 2.6), str(n), 7, Color(0.05, 0.05, 0.1), HORIZONTAL_ALIGNMENT_CENTER, 10.0)


func _flag(p: Vector2) -> void:
	for yy in 3:
		for xx in 3:
			var on: bool = (xx + yy) % 2 == 0
			draw_rect(Rect2(p + Vector2(xx * 2.0, yy * 2.0), Vector2(2, 2)), Color.WHITE if on else Color(0.1, 0.1, 0.12))
	draw_line(p + Vector2(0, 0), p + Vector2(0, 9), Color(1, 1, 1, 0.7), 0.8)


func _footer(y: float) -> void:
	var me: TruckSim = sim.trucks[player]
	var remaining: float = maxf(sim.finish_z - me.z, 0.0)
	HudStyle.lbl(self, Vector2(6, y), Tr.t("hud.destination"), 6, HudStyle.LABEL)
	var km: String = ("%.1f km" % (remaining / 1000.0)).replace(".", ",")
	var lw: float = HudStyle.text_width(Tr.t("hud.destination"), 6, false)
	HudStyle.num(self, Vector2(10.0 + lw, y + 0.5), km, 9, Color.WHITE)
	if rival >= 0 and rival < sim.trucks.size() and rival != player:
		var gap_m: float = sim.trucks[rival].z - me.z
		var txt: String = "%s %s%d m" % [Tr.t("hud.rival"), "+" if gap_m >= 0.0 else "-", int(absf(gap_m))]
		HudStyle.num(self, Vector2(0, y + 0.5), txt, 8, HudStyle.GOLD if gap_m >= 0.0 else HudStyle.OK_COL,
				HORIZONTAL_ALIGNMENT_RIGHT, HudLayout.CLOCKS.x - 6.0)
