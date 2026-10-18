extends SceneTree
## Gera os 2 atlas da T-130 (precisa de janela, nao roda com --headless):
##   assets/textures/plates_atlas.png      64 placas de veiculo ficticias (PlateCatalog)
##   assets/textures/road_signs_atlas.png  sinalizacao japonesa (SignAtlas)
## godot --path game -s res://tools_dev/make_sign_atlases.gd
## Arte 100% nossa: formas desenhadas aqui + fonte Noto Sans JP (OFL, ja no projeto).

const RED := Color("#c8102e")
const BLUE := Color("#1c3f94")
const YELLOW := Color("#f3c400")
const GREEN := Color("#11603a")
const WHITE := Color("#f4f5f0")
const BLACK := Color("#141414")

var _font: FontVariation
var _bold: FontVariation


func _initialize() -> void:
	var base: FontFile = load("res://assets/fonts/NotoSansJP.ttf") as FontFile
	_font = FontVariation.new()
	_font.base_font = base
	_font.variation_opentype = {2003265652: 700}
	_bold = FontVariation.new()
	_bold.base_font = base
	_bold.variation_opentype = {2003265652: 900}
	_run.call_deferred()


func _run() -> void:
	var pw: int = PlateCatalog.COLS * PlateCatalog.CELL_PX.x
	var ph: int = PlateCatalog.ROWS * PlateCatalog.CELL_PX.y
	await _render(Vector2i(pw, ph), _draw_plates, PlateCatalog.ATLAS)
	await _render(Vector2i(SignAtlas.SIZE, SignAtlas.SIZE), _draw_signs, SignAtlas.ATLAS)
	quit()


func _render(size: Vector2i, painter: Callable, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = size
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(size)
	c.draw.connect(func() -> void: painter.call(c))
	vp.add_child(c)
	get_root().add_child(vp)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	var err: int = img.save_png(ProjectSettings.globalize_path(path))
	print("atlas: ", path, " ", size, " erro=", err)
	vp.queue_free()


# ---------------------------------------------------------------- texto
func _text(c: Control, s: String, center: Vector2, px: int, col: Color, max_w: float = 0.0, font: Font = null) -> void:
	var f: Font = font if font != null else _font
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if max_w > 0.0 and w > max_w:
		px = int(px * max_w / w)
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var asc: float = f.get_ascent(px)
	var dsc: float = f.get_descent(px)
	c.draw_string(f, Vector2(center.x - w * 0.5, center.y + (asc - dsc) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _round_rect(c: Control, r: Rect2, col: Color, radius: int, border: Color = Color.TRANSPARENT, bw: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	c.draw_style_box(sb, r)


# ---------------------------------------------------------------- placas de veiculo
func _draw_plates(c: Control) -> void:
	for cell in PlateCatalog.COUNT:
		var p: Dictionary = PlateCatalog.plate(cell)
		var cols: Array = PlateCatalog.COLORS[int(p["style"])]
		var bg: Color = cols[0]
		var fg: Color = cols[1]
		var r := Rect2(PlateCatalog.pixel_rect(cell))
		c.draw_rect(r, bg.darkened(0.35))
		var inner := r.grow(-2)
		_round_rect(c, inner, bg, 6, fg.lerp(bg, 0.55), 2)
		for bx in [0.25, 0.75]:                                    # parafusos
			c.draw_circle(r.position + Vector2(r.size.x * bx, 9), 2.6, bg.darkened(0.45))
		var o: Vector2 = r.position
		_text(c, "%s %s" % [p["region"], p["cls"]], o + Vector2(64, 20), 17, fg, 80.0)
		_text(c, String(p["kana"]), o + Vector2(15, 44), 17, fg)
		_text(c, String(p["number"]), o + Vector2(74, 43), 36, fg, 96.0, _bold)


# ---------------------------------------------------------------- sinalizacao
func _r(id: String) -> Rect2:
	return Rect2(SignAtlas.rects()[id])


func _draw_signs(c: Control) -> void:
	for v in [50, 60, 80, 100]:
		_speed(c, _r("spd_%d" % v), str(v))
	_stop(c, _r("stop"))
	_diamond(c, _r("warn_curve_r"), func(rr: Rect2) -> void: _curve_icon(c, rr, 1.0))
	_diamond(c, _r("warn_curve_l"), func(rr: Rect2) -> void: _curve_icon(c, rr, -1.0))
	_diamond(c, _r("warn_tunnel"), func(rr: Rect2) -> void: _tunnel_icon(c, rr))
	_diamond(c, _r("warn_rocks"), func(rr: Rect2) -> void: _rocks_icon(c, rr))
	_chevron(c, _r("chev_r"), 1.0)
	_chevron(c, _r("chev_l"), -1.0)
	var r: Rect2 = _r("km")
	c.draw_rect(r, GREEN)
	_text(c, "km", r.get_center() + Vector2(0, 6), 64, WHITE)
	r = _r("enchou")
	c.draw_rect(r, WHITE)
	_text(c, "延長", r.get_center(), 50, BLACK)
	c.draw_rect(_r("solid_green"), GREEN)
	c.draw_rect(_r("solid_white"), WHITE)
	c.draw_rect(_r("solid_back"), Color("#8e939a"))
	_plate_text(c, _r("aux_tunnel"), "トンネル", 64)
	_plate_text(c, _r("aux_slow"), "この先 急カーブ", 46)
	r = _r("exit")
	c.draw_rect(r, WHITE)
	_round_rect(c, r.grow(-4), GREEN, 10)
	_text(c, "出口", r.position + Vector2(88, 62), 70, WHITE, 0.0, _bold)
	_text(c, "EXIT", r.position + Vector2(200, 40), 30, WHITE)
	var a: Vector2 = r.position + Vector2(200, 92)                  # seta para a esquerda-frente (saida pela esquerda)
	c.draw_line(a + Vector2(18, 18), a + Vector2(-14, -14), WHITE, 9.0, true)
	c.draw_colored_polygon(PackedVector2Array([a + Vector2(-26, -26), a + Vector2(-2, -24), a + Vector2(-24, -2)]), WHITE)
	r = _r("tomare")                                               # pintura no asfalto: branco sobre transparente
	_text(c, "止まれ", r.get_center() + Vector2(0, 4), 96, Color(0.96, 0.96, 0.94), 246.0, _bold)
	for rid in SignAtlas.TUNNEL_NAMES:
		_plate_text(c, _r("tun_" + String(rid)), String(SignAtlas.TUNNEL_NAMES[rid]), 76)
	for place in SignAtlas.places():
		r = _r("place_" + String(place))
		c.draw_rect(r, GREEN)
		_text(c, String(RoadFurniture.KANJI[place]), r.position + Vector2(128, 36), 54, WHITE, 236.0, _bold)
		_text(c, String(RoadFurniture.ROMAJI.get(place, place)), r.position + Vector2(128, 78), 24, WHITE, 236.0)
	for i in SignAtlas.DIGITS.length():
		var d: String = SignAtlas.DIGITS[i]
		r = _r("g" + d)
		c.draw_rect(r, GREEN)
		_text(c, d, r.get_center(), 76, WHITE, 44.0, _bold)
		r = _r("w" + d)
		c.draw_rect(r, WHITE)
		_text(c, d, r.get_center(), 76, BLACK, 44.0, _bold)
	r = _r("wm")
	c.draw_rect(r, WHITE)
	_text(c, "m", r.get_center() + Vector2(0, 8), 64, BLACK, 44.0)


func _plate_text(c: Control, r: Rect2, s: String, px: int) -> void:
	c.draw_rect(r, BLACK)
	_round_rect(c, r.grow(-4), WHITE, 8)
	_text(c, s, r.get_center(), px, BLACK, r.size.x - 24.0)


func _speed(c: Control, r: Rect2, s: String) -> void:
	var ctr: Vector2 = r.get_center()
	c.draw_circle(ctr, 62.0, WHITE)
	c.draw_circle(ctr, 58.0, RED)
	c.draw_circle(ctr, 45.0, WHITE)
	_text(c, s, ctr + Vector2(0, 2), 62 if s.length() < 3 else 46, BLUE, 78.0, _bold)


func _stop(c: Control, r: Rect2) -> void:
	var o: Vector2 = r.position
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(2, 8), o + Vector2(126, 8), o + Vector2(64, 124)]), WHITE)
	c.draw_colored_polygon(PackedVector2Array([o + Vector2(14, 15), o + Vector2(114, 15), o + Vector2(64, 110)]), RED)
	_text(c, "止まれ", o + Vector2(64, 38), 28, WHITE, 56.0, _bold)


func _diamond(c: Control, r: Rect2, icon: Callable) -> void:
	var m: Vector2 = r.get_center()
	var pts := func(h: float) -> PackedVector2Array:
		return PackedVector2Array([m + Vector2(0, -h), m + Vector2(h, 0), m + Vector2(0, h), m + Vector2(-h, 0)])
	c.draw_colored_polygon(pts.call(63.0), BLACK)
	c.draw_colored_polygon(pts.call(57.0), YELLOW)
	c.draw_colored_polygon(pts.call(53.0), BLACK)
	c.draw_colored_polygon(pts.call(50.0), YELLOW)
	icon.call(r)


func _curve_icon(c: Control, r: Rect2, dir: float) -> void:
	var m: Vector2 = r.get_center()
	var pts := PackedVector2Array()
	for i in 13:                                                   # sobe reto e dobra para o lado da curva
		var t: float = float(i) / 12.0
		var y: float = lerpf(30.0, -14.0, t)
		var x: float = -dir * 10.0 + dir * 26.0 * pow(maxf(t - 0.35, 0.0) / 0.65, 2.0)
		pts.append(m + Vector2(x, y))
	c.draw_polyline(pts, BLACK, 9.0, true)
	var tip: Vector2 = pts[pts.size() - 1]
	var back: Vector2 = (pts[pts.size() - 1] - pts[pts.size() - 3]).normalized()
	var side := Vector2(-back.y, back.x)
	c.draw_colored_polygon(PackedVector2Array([tip + back * 14.0, tip + side * 10.0, tip - side * 10.0]), BLACK)


func _tunnel_icon(c: Control, r: Rect2) -> void:
	var m: Vector2 = r.get_center() + Vector2(0, 8)
	c.draw_rect(Rect2(m + Vector2(-26, -10), Vector2(52, 26)), BLACK)
	c.draw_circle(m + Vector2(0, -10), 26.0, BLACK)
	c.draw_rect(Rect2(m + Vector2(-15, -4), Vector2(30, 20)), YELLOW)
	c.draw_circle(m + Vector2(0, -4), 15.0, YELLOW)
	c.draw_line(m + Vector2(0, 2), m + Vector2(0, 14), BLACK, 3.0)


func _rocks_icon(c: Control, r: Rect2) -> void:
	var m: Vector2 = r.get_center()
	c.draw_colored_polygon(PackedVector2Array([m + Vector2(-30, 28), m + Vector2(-30, -26), m + Vector2(-12, -26),
		m + Vector2(-12, 28)]), BLACK)
	for p in [Vector2(2, -18), Vector2(14, -2), Vector2(4, 14), Vector2(22, 20)]:
		c.draw_circle(m + p, 6.5, BLACK)
	c.draw_line(m + Vector2(-12, 28), m + Vector2(32, 28), BLACK, 4.0)


func _chevron(c: Control, r: Rect2, dir: float) -> void:
	c.draw_rect(r, RED)
	c.draw_rect(r.grow(-3), RED.darkened(0.1), false, 2.0)
	var m: Vector2 = r.get_center()
	for k in 2:                                                     # duas setas brancas ">>"
		var cx: float = m.x + dir * (k * 34.0 - 22.0)
		var tip := Vector2(cx + dir * 24.0, m.y)
		c.draw_colored_polygon(PackedVector2Array([Vector2(cx - dir * 12.0, m.y - 44.0), Vector2(cx + dir * 4.0, m.y - 44.0),
			tip + Vector2(dir * 4.0, 0), Vector2(cx + dir * 4.0, m.y + 44.0), Vector2(cx - dir * 12.0, m.y + 44.0),
			tip - Vector2(dir * 12.0, 0)]), WHITE)
