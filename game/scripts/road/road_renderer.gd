class_name RoadRenderer
extends Node2D
## Desenha a estrada pseudo-3D (estilo OutRun) com um unico _draw(): ceu, grama, zebra, asfalto
## e faixas, de tras para frente. Poucos nos: tudo e uma chamada de desenho so.

const NIGHT_SKY_TOP := Color("#0b0a14")
const NIGHT_SKY_MID := Color("#1e1b3d")
const NIGHT_SKY_LOW := Color("#3c3a73")
const FOG := Color("#1e1b3d")
const GRASS_A := Color("#123a2a")
const GRASS_B := Color("#0f3024")
const ROAD_A := Color("#26262b")
const ROAD_B := Color("#2d2d33")
const RUMBLE_A := Color("#ff2e88")
const RUMBLE_B := Color("#dfe6f0")
const LANE := Color("#ffe9c2")
const BAND_LEN: int = 4            # segmentos por faixa alternada

var projector := SpriteProjector.new()
var draw_sky: bool = true           # false quando o ParallaxBg desenha o ceu


func update_view(track: Track, player_z: float, player_x: float) -> void:
	projector.update(track, player_z, player_x)
	queue_redraw()


func _fog(c: Color, z: float) -> Color:
	var t: float = clampf(z / (float(projector.draw_dist) * Track.SEG_LEN), 0.0, 1.0)
	return c.lerp(FOG, t * t)


func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([a, b, c, d]), col)


func _draw() -> void:
	var p := projector
	if p.track == null:
		return
	var w: float = SpriteProjector.SCREEN_W
	var h: float = SpriteProjector.SCREEN_H
	var hy: float = SpriteProjector.HORIZON_Y
	if draw_sky:   # ceu em tres faixas
		draw_rect(Rect2(0, 0, w, hy * 0.45), NIGHT_SKY_TOP)
		draw_rect(Rect2(0, hy * 0.45, w, hy * 0.35), NIGHT_SKY_MID)
		draw_rect(Rect2(0, hy * 0.8, w, hy * 0.2 + 1.0), NIGHT_SKY_LOW)
	# chao base
	draw_rect(Rect2(0, hy, w, h - hy), GRASS_A)
	var n: int = p.draw_dist
	# projeta todas as linhas
	var lines: Array[Vector3] = []
	lines.resize(n + 1)
	for i in n + 1:
		lines[i] = p.project_line(i)
	var half: float = Track.ROAD_HALF_WIDTH_M
	# de tras para frente (painter's algorithm)
	for i in range(n - 1, -1, -1):
		var l1: Vector3 = lines[i]       # perto
		var l2: Vector3 = lines[i + 1]   # longe
		if l1.y <= l2.y:
			continue                      # segmento atras de uma colina
		var seg: int = p.base_index + i
		var band: bool = (seg / BAND_LEN) % 2 == 0
		var z: float = p.zr[i]
		var y1: float = l1.y
		var y2: float = l2.y
		if not band:
			_quad(Vector2(0, y2), Vector2(w, y2), Vector2(w, y1), Vector2(0, y1), _fog(GRASS_B, z))
		var r1: float = half * l1.z
		var r2: float = half * l2.z
		var rum1: float = r1 * 1.12
		var rum2: float = r2 * 1.12
		var rc: Color = _fog(RUMBLE_A if band else RUMBLE_B, z)
		_quad(Vector2(l2.x - rum2, y2), Vector2(l2.x - r2, y2), Vector2(l1.x - r1, y1), Vector2(l1.x - rum1, y1), rc)
		_quad(Vector2(l2.x + r2, y2), Vector2(l2.x + rum2, y2), Vector2(l1.x + rum1, y1), Vector2(l1.x + r1, y1), rc)
		_quad(Vector2(l2.x - r2, y2), Vector2(l2.x + r2, y2), Vector2(l1.x + r1, y1), Vector2(l1.x - r1, y1),
			_fog(ROAD_A if band else ROAD_B, z))
		if band:
			var lc: Color = _fog(LANE, z)
			for lane in [-0.5, 0.0, 0.5]:
				var lw1: float = r1 * 0.018
				var lw2: float = r2 * 0.018
				var c1: float = l1.x + r1 * lane
				var c2: float = l2.x + r2 * lane
				_quad(Vector2(c2 - lw2, y2), Vector2(c2 + lw2, y2), Vector2(c1 + lw1, y1), Vector2(c1 - lw1, y1), lc)
