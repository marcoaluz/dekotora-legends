class_name IndicatorStrip
extends Control
## T-202: the row beside the gauge: two GREEN turn arrows that blink with the lane signal (1st tap turns the signal
## on, 2nd changes lane: TruckSim.signal_dir, same rhythm as the truck lamps and the relay tick: SignalBlink) and, in
## between, the lamps: headlights, hazard, horn, brake. Under them, the 5 lane dots (current lane white; a lane closed
## ahead turns red). Local size HudLayout.STRIP, scaled as a whole. Only reads values.

const BOX_H: float = 13.0
const LAMP_W: float = 14.5
const HEAD_COL := Color("#7fd6ff")

var signal_dir: int = 0
var headlights: bool = false
var hazard: bool = false
var horn: bool = false
var brake_hard: bool = false
var brake_held: bool = false
var lane: int = Lanes.CENTER
var blocked: Array[bool] = [false, false, false, false, false]   # lane closed ahead (Lanes indices)
var amber: float = 0.0
var _blink := SignalBlink.new()
var _hazard_blink := SignalBlink.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = HudLayout.STRIP


func _process(_delta: float) -> void:
	_blink.update(signal_dir, SignalBlink.now())
	_hazard_blink.update(2 if hazard else 0, SignalBlink.now())
	queue_redraw()


## Is the arrow of `side` (-1/+1) lit right now (tests)?
func arrow_lit(side: int) -> bool:
	return signal_dir == side and _blink.lit


func _draw() -> void:
	_arrow(Rect2(0, 0, 16, BOX_H), -1)
	_arrow(Rect2(HudLayout.STRIP.x - 16.0, 0, 16, BOX_H), 1)
	var x0: float = 19.0
	for i in 4:
		var r := Rect2(x0 + i * (LAMP_W + 1.0), 0, LAMP_W, BOX_H)
		_box(r)
		var c: Vector2 = r.get_center()
		match i:
			0:
				_headlight(c, headlights)
			1:
				_hazard(c, hazard and _hazard_blink.lit)
			2:
				_horn(c, horn)
			3:
				_brake(c, brake_hard, brake_held)
	_lane_dots(Vector2(HudLayout.STRIP.x * 0.5, 19.5))


func _box(r: Rect2) -> void:
	draw_rect(r, Color(0.02, 0.03, 0.06, 0.72))
	draw_rect(r, Color(1, 1, 1, 0.14), false, 1.0)
	draw_line(r.position + Vector2(1, 1), Vector2(r.end.x - 1, r.position.y + 1), Color(1, 1, 1, 0.1), 1.0)


func _arrow(r: Rect2, side: int) -> void:
	_box(r)
	var on: bool = signal_dir == side
	var lit: bool = on and _blink.lit
	var col: Color = HudStyle.ARROW_ON if lit else (Color(HudStyle.ARROW_ON, 0.35) if on else HudStyle.ARROW_OFF)
	var c: Vector2 = r.get_center()
	var d: float = float(side)
	var pts := PackedVector2Array([c + Vector2(d * 6.0, 0), c + Vector2(d * 0.5, -5.0), c + Vector2(d * 0.5, -2.2),
			c + Vector2(-d * 5.5, -2.2), c + Vector2(-d * 5.5, 2.2), c + Vector2(d * 0.5, 2.2), c + Vector2(d * 0.5, 5.0)])
	if lit:
		HudStyle.glow(self, c, 5.0, col)
	draw_colored_polygon(pts, col)


func _headlight(c: Vector2, on: bool) -> void:
	var col: Color = HEAD_COL if on else HudStyle.LAMP_OFF
	if on:
		HudStyle.glow(self, c, 4.0, col)
	draw_arc(c + Vector2(-1.5, 0), 3.6, PI * 0.5, PI * 1.5, 8, col, 1.3)       # lamp body (D shape)
	draw_line(c + Vector2(-1.5, -3.6), c + Vector2(-1.5, 3.6), col, 1.3)
	for k in 3:
		var y: float = -2.6 + k * 2.6
		draw_line(c + Vector2(0.8, y), c + Vector2(4.6, y + 0.9), col, 1.0)


func _hazard(c: Vector2, on: bool) -> void:
	var col: Color = HudStyle.BAD_COL if on else HudStyle.LAMP_OFF
	if on:
		HudStyle.glow(self, c, 4.0, col)
	var p := PackedVector2Array([c + Vector2(0, -4.8), c + Vector2(5.2, 4.0), c + Vector2(-5.2, 4.0), c + Vector2(0, -4.8)])
	draw_polyline(p, col, 1.3)
	var q := PackedVector2Array([c + Vector2(0, -1.8), c + Vector2(2.6, 2.4), c + Vector2(-2.6, 2.4), c + Vector2(0, -1.8)])
	draw_polyline(q, col, 1.0)


## Horn (T-144): a trumpet that lights gold with sound waves.
func _horn(c: Vector2, on: bool) -> void:
	var col: Color = HudStyle.GOLD if on else HudStyle.LAMP_OFF
	if on:
		HudStyle.glow(self, c, 4.0, col)
	var o: Vector2 = c + Vector2(-1.2, 0)
	draw_colored_polygon(PackedVector2Array([o + Vector2(-3, -1.3), o + Vector2(2.2, -3.8), o + Vector2(2.2, 3.8), o + Vector2(-3, 1.3)]), col)
	draw_rect(Rect2(o + Vector2(-5, -1.0), Vector2(2.0, 2.0)), col)
	if on:
		for k in 2:
			draw_arc(o + Vector2(2.8, 0), 2.4 + k * 1.9, -0.9, 0.9, 6, Color(col, 0.9 - k * 0.3), 0.9)


## Brake: circle with "!" (hard braking = bright red, brake held = dim red).
func _brake(c: Vector2, hard: bool, held: bool) -> void:
	var col: Color = HudStyle.BAD_COL if hard else (Color(HudStyle.BAD_COL, 0.6) if held else HudStyle.LAMP_OFF)
	if hard:
		HudStyle.glow(self, c, 4.0, col)
	draw_arc(c, 3.6, 0.0, TAU, 14, col, 1.1)
	draw_arc(c, 5.4, 2.4, 3.9, 5, col, 0.9)
	draw_arc(c, 5.4, -0.75, 0.75, 5, col, 0.9)
	draw_line(c + Vector2(0, -2.2), c + Vector2(0, 0.6), col, 1.1)
	draw_circle(c + Vector2(0, 1.9), 0.6, col)


func _lane_dots(c: Vector2) -> void:
	for i in 5:
		var p: Vector2 = c + Vector2((i - 2) * 8.0, 0)
		var road: bool = Lanes.is_road_lane(i)
		var cur: bool = i == lane
		var col: Color = Color(1, 1, 1, 0.28 if road else 0.14)
		if i < blocked.size() and blocked[i]:
			col = Color(HudStyle.BAD_COL, 0.9)
		if cur:
			col = Color.WHITE if not (i < blocked.size() and blocked[i]) else HudStyle.BAD_COL
		draw_circle(p, 2.3 if cur else (1.6 if road else 1.1), col)
