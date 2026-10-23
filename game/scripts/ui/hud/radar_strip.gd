class_name RadarStrip
extends Control
## T-202: translucent vertical radar on the left edge (like the original): the road seen from above around the
## player, ahead at the top. Lane lines scroll with the speed; coloured dots/bars: you (pink), the route rival (gold),
## other trucks (light blue), traffic cars close by (cyan), wrecked cars (red, blinking), and the events ahead:
## accident (red), works (orange), narrowing (yellow), 2-lane section (grey). Turns amber inside tunnels.
## Size comes from HudLayout (any height). Data: RadarModel (pure).

const BAND := Color(0.02, 0.04, 0.08, 0.42)
const KIND_COL: Array[Color] = [
	Color("#ff2e88"), Color("#f5cc5a"), Color("#9cc8ff"), Color("#21e6ff"), Color("#ff3b3b"),
	Color("#ff3b3b"), Color("#ff9a1a"), Color("#f5cc5a"), Color("#8a93a8"),
]
const DASH_M: float = 12.0                  # lane dash period (m)

var sim: RaceSim
var player: int = 0
var rival: int = -1
var tunnel: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _y(z_rel: float) -> float:
	return size.y * (1.0 - RadarModel.y_frac(z_rel))


func _x(x: float) -> float:
	return size.x * RadarModel.x_frac(x)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var band: Color = BAND.lerp(Color(0.35, 0.18, 0.02, 0.5), clampf(tunnel, 0.0, 1.0))
	draw_rect(r, band)
	var edge: Color = Color(1, 1, 1, 0.22).lerp(Color(HudStyle.BACK_NIGHT, 0.6), clampf(tunnel, 0.0, 1.0))
	draw_line(Vector2(0.5, 0), Vector2(0.5, size.y), edge, 1.0)
	draw_line(Vector2(size.x - 0.5, 0), Vector2(size.x - 0.5, size.y), edge, 1.0)
	if sim == null or sim.trucks.is_empty():
		return
	_lanes(edge)
	var blink: bool = int(Time.get_ticks_msec() / 200) % 2 == 0
	for b in RadarModel.blips(sim, player, rival):
		var kind: int = int(b["kind"])
		if kind == RadarModel.Kind.WRECK and not blink:
			continue
		var x0: float = _x(float(b["x0"]))
		var x1: float = _x(float(b["x1"]))
		var y1: float = _y(float(b["z0"]))
		var y0: float = _y(float(b["z1"]))
		var br := Rect2(x0, y0, maxf(x1 - x0, 2.0), maxf(y1 - y0, 2.0))
		var col: Color = KIND_COL[kind]
		if kind >= RadarModel.Kind.ACCIDENT:
			if y1 <= 1.0:                             # beyond the top: a small bar on the edge
				br = Rect2(x0, 0.0, maxf(x1 - x0, 2.0), 2.5)
			draw_rect(br, Color(col, 0.45 if kind != RadarModel.Kind.SECTION else 0.3))
			draw_rect(br, Color(col, 0.9), false, 1.0)
		elif kind == RadarModel.Kind.ME:
			draw_rect(br.grow(0.8), Color.WHITE)
			draw_rect(br, col)
		else:
			draw_rect(br, col)
	# where "you" are: a small chevron on the bottom edge line
	var my: float = _y(0.0)
	draw_line(Vector2(0, my), Vector2(2.5, my), Color(HudStyle.PINK, 0.8), 1.0)
	draw_line(Vector2(size.x - 2.5, my), Vector2(size.x, my), Color(HudStyle.PINK, 0.8), 1.0)


## Dashed lane borders scrolling with the player's distance (motion feel).
func _lanes(edge: Color) -> void:
	var z: float = sim.trucks[player].z
	var col := Color(edge, edge.a * 0.8)
	for lx in [-0.25, 0.25]:
		var x: float = _x(lx)
		var m: float = -fmod(z, DASH_M) - RadarModel.BEHIND_M
		while m < RadarModel.AHEAD_M:
			var ya: float = _y(m)
			var yb: float = _y(m + DASH_M * 0.5)
			if ya - yb >= 0.6:
				draw_line(Vector2(x, yb), Vector2(x, ya), col, 0.8)
			m += DASH_M
	for ex in [-0.75, 0.75]:
		draw_line(Vector2(_x(ex), 0), Vector2(_x(ex), size.y), Color(edge, edge.a * 0.6), 0.8)
