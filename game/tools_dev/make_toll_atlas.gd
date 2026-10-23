extends SceneTree
## T-207: gera o atlas da praca de pedagio (precisa de janela: fontes; NAO roda com --headless):
##   godot --path game -s res://tools_dev/make_toll_atlas.gd
## Grava assets/textures/toll/toll_atlas.png (mapa em scripts/road3d/toll_atlas.gd). Depois: godot --headless --path game --import
## Arte 100% nossa (formas por codigo + Noto Sans JP, OFL). Nada de logotipo de operadora real.

const GREEN := Color("#0f5a3a")
const PURPLE := Color("#5b2a86")
const WHITE := Color("#f2f3ef")
const PANEL := Color("#dfe3e1")
const BLUE := Color("#1d4f9c")
const YELLOW := Color("#f2c200")
const BLACK := Color("#161616")

var _font: FontVariation
var _bold: FontVariation
var _rng := RandomNumberGenerator.new()


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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/textures/toll"))
	var vp := SubViewport.new()
	vp.size = Vector2i(TollAtlas.SIZE, TollAtlas.SIZE)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	c.draw.connect(func() -> void: _paint(c))
	vp.add_child(c)
	get_root().add_child(vp)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	var err: int = img.save_png(ProjectSettings.globalize_path(TollAtlas.ATLAS))
	print("atlas do pedagio: ", TollAtlas.ATLAS, " erro=", err)
	quit()


func _r(id: String) -> Rect2:
	return Rect2(TollAtlas.RECTS[id])


func _paint(c: Control) -> void:
	_rng.seed = 207
	c.draw_rect(Rect2(0, 0, TollAtlas.SIZE, TollAtlas.SIZE), Color("#808080"))
	_fascia(c, _r("fascia"), true)
	_fascia(c, _r("fascia_back"), false)
	_panel(c, _r("panel"))
	_ceiling(c, _r("ceiling"))
	_booth(c, _r("booth"), false)
	_booth(c, _r("booth_lit"), true)
	_sign_etc(c, _r("sign_etc"))
	_sign_mix(c, _r("sign_mix"))
	_road(c, _r("road_etc"), Color("#5a3d82"), "ETC")
	_road(c, _r("road_general"), Color("#2f6e4b"), "一般")
	_booth_end(c, _r("booth_end"))
	_chevron(c, _r("chevron"))
	_stripes(c, _r("stripes"))
	_keep_both(c, _r("keep_both"))
	_signal(c, _r("signal_go"), true)
	_signal(c, _r("signal_stop"), false)
	_pillar(c, _r("pillar"))
	c.draw_rect(_r("white"), WHITE)
	_steel(c, _r("steel"))
	_antenna(c, _r("antenna"))
	_lamp(c, _r("lamp"))
	_flat(c, _r("roof"), Color("#4a4f55"), 0.06)
	_beacon(c, _r("beacon"))
	_flat(c, _r("dark"), Color("#1c1d20"), 0.03)
	_curb(c, _r("curb"))
	_glass(c, _r("glass"))


# ---------------------------------------------------------------- pecas
func _noise(c: Control, r: Rect2, col: Color, n: int, size_px: float = 2.0) -> void:
	for i in n:
		var p := Vector2(_rng.randf_range(r.position.x, r.end.x - size_px), _rng.randf_range(r.position.y, r.end.y - size_px))
		c.draw_rect(Rect2(p, Vector2(size_px, size_px)), Color(col, _rng.randf_range(0.04, 0.12)))


func _flat(c: Control, r: Rect2, col: Color, grain: float) -> void:
	c.draw_rect(r, col)
	_noise(c, r, Color.BLACK if grain > 0.0 else Color.WHITE, int(r.size.x * r.size.y / 40.0))


## Rain streaks from the top edge down (dirt), dark and faint.
func _streaks(c: Control, r: Rect2, n: int, max_len: float) -> void:
	for i in n:
		var x: float = _rng.randf_range(r.position.x, r.end.x)
		var l: float = _rng.randf_range(max_len * 0.3, max_len)
		var w: float = _rng.randf_range(1.0, 3.0)
		for k in 6:
			var t: float = float(k) / 6.0
			c.draw_rect(Rect2(x, r.position.y + l * t, w, l / 6.0 + 0.5), Color(0.18, 0.17, 0.15, 0.10 * (1.0 - t)))


func _text(c: Control, s: String, center: Vector2, px: int, col: Color, max_w: float = 0.0, font: Font = null) -> void:
	var f: Font = font if font != null else _bold
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if max_w > 0.0 and w > max_w:
		px = int(px * max_w / w)
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var asc: float = f.get_ascent(px)
	var dsc: float = f.get_descent(px)
	c.draw_string(f, Vector2(center.x - w * 0.5, center.y + (asc - dsc) * 0.5), s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _round(c: Control, r: Rect2, col: Color, radius: int, border: Color = Color.TRANSPARENT, bw: int = 0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	c.draw_style_box(sb, r)


## Panel wall: base colour, vertical seams every `seam` px, a darker foot.
func _panels(c: Control, r: Rect2, base: Color, seam: float) -> void:
	c.draw_rect(r, base)
	var x: float = r.position.x + seam
	while x < r.end.x - 1.0:
		c.draw_rect(Rect2(x, r.position.y, 1.5, r.size.y), Color(0, 0, 0, 0.16))
		c.draw_rect(Rect2(x + 1.5, r.position.y, 1.0, r.size.y), Color(1, 1, 1, 0.25))
		x += seam
	_noise(c, r, Color.BLACK, int(r.size.x * r.size.y / 60.0))


func _fascia(c: Control, r: Rect2, front: bool) -> void:
	_panels(c, r, PANEL, 57.0)
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 5), Color("#7d8487"))              # top cap
	var band := Rect2(r.position.x, r.end.y - 18, r.size.x, 14)                              # green band
	c.draw_rect(band, GREEN)
	c.draw_rect(Rect2(r.position.x, r.end.y - 4, r.size.x, 4), Color("#3b4144"))             # lower edge
	_streaks(c, Rect2(r.position.x, r.position.y + 5, r.size.x, r.size.y - 22), 70, 34.0)
	if front:
		var plate := Rect2(r.position.x + r.size.x * 0.5 - 170, r.position.y + 9, 340, 46)
		_round(c, plate, GREEN, 4, WHITE, 3)
		_text(c, "料金所", Vector2(plate.position.x + 110, plate.get_center().y + 1), 34, WHITE)
		_text(c, "TOLL GATE", Vector2(plate.position.x + 255, plate.get_center().y + 1), 22, WHITE, 140.0, _font)
	else:
		_text(c, "ご利用ありがとうございました", Vector2(r.get_center().x, r.position.y + 32), 22, Color("#2a5d47"), 420.0, _font)
		_text(c, "THANK YOU", Vector2(r.get_center().x, r.position.y + 54), 14, Color("#2a5d47"), 200.0, _font)


func _panel(c: Control, r: Rect2) -> void:
	_panels(c, r, PANEL, 32.0)
	c.draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 8), Color("#7d8487"))
	c.draw_rect(Rect2(r.position.x, r.end.y - 30, r.size.x, 22), GREEN)
	c.draw_rect(Rect2(r.position.x, r.end.y - 8, r.size.x, 8), Color("#3b4144"))
	_streaks(c, Rect2(r.position.x, r.position.y + 8, r.size.x, r.size.y - 38), 26, 60.0)


func _ceiling(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color("#8d9396"))
	for k in 9:                                                                               # panel grid
		c.draw_rect(Rect2(r.position.x + k * 32.0, r.position.y, 2, r.size.y), Color(0, 0, 0, 0.22))
	for k in 5:
		c.draw_rect(Rect2(r.position.x, r.position.y + k * 32.0, r.size.x, 2), Color(0, 0, 0, 0.22))
	for y in [r.position.y + 30.0, r.position.y + 86.0]:                                       # 2 LED strips (off)
		var s := Rect2(r.position.x + 18, y, r.size.x - 36, 12)
		c.draw_rect(s.grow(2), Color("#5b6064"))
		c.draw_rect(s, Color("#c9ced1"))
	_noise(c, r, Color.BLACK, 400)


func _booth(c: Control, r: Rect2, lit: bool) -> void:
	c.draw_rect(r, WHITE)
	var win := Rect2(r.position.x + 14, r.position.y + 10, r.size.x - 28, 66)                # window
	if lit:
		for k in 12:
			var t: float = float(k) / 11.0
			c.draw_rect(Rect2(win.position.x, win.position.y + win.size.y * t, win.size.x, win.size.y / 11.0 + 1.0),
				Color("#ffe3a8").lerp(Color("#e9953f"), t))
		c.draw_rect(Rect2(win.position.x + 6, win.position.y + 3, win.size.x - 12, 3), Color("#fffbe8"))     # ceiling lamp
		var head := Vector2(win.position.x + win.size.x * 0.38, win.position.y + 32)           # attendant
		c.draw_circle(head, 9.0, Color("#3a2c22"))
		c.draw_colored_polygon(PackedVector2Array([head + Vector2(-20, 12), head + Vector2(20, 12),
			head + Vector2(26, 40), head + Vector2(-26, 40)]), Color("#1d2f5c"))
		c.draw_rect(Rect2(head.x - 6, head.y - 13, 12, 5), Color("#1d2f5c"))                   # cap
		c.draw_rect(Rect2(win.position.x + win.size.x * 0.62, win.position.y + 40, 40, 26), Color("#5d6a72"))   # terminal
	else:
		for k in 12:
			var t: float = float(k) / 11.0
			c.draw_rect(Rect2(win.position.x, win.position.y + win.size.y * t, win.size.x, win.size.y / 11.0 + 1.0),
				Color("#7f97a8").lerp(Color("#25333d"), t))
		c.draw_colored_polygon(PackedVector2Array([win.position + Vector2(40, 0), win.position + Vector2(78, 0),
			win.position + Vector2(30, win.size.y), win.position + Vector2(-8, win.size.y)].map(
				func(p: Vector2) -> Vector2: return Vector2(clampf(p.x, win.position.x, win.end.x), p.y))), Color(1, 1, 1, 0.16))
	for mx in [0.0, 0.5, 1.0]:                                                                # mullions
		c.draw_rect(Rect2(win.position.x + win.size.x * mx - 2.5, win.position.y, 5, win.size.y), Color("#3e4448"))
	c.draw_rect(Rect2(win.position.x - 2, win.position.y - 3, win.size.x + 4, 4), Color("#3e4448"))
	c.draw_rect(Rect2(win.position.x - 2, win.end.y, win.size.x + 4, 5), Color("#3e4448"))
	c.draw_rect(Rect2(r.position.x, r.position.y + 84, r.size.x, 12), BLUE)                  # blue band
	c.draw_rect(Rect2(r.position.x, r.position.y + 98, r.size.x, 3), Color("#c43a3a"))
	_panels(c, Rect2(r.position.x, r.position.y + 101, r.size.x, r.size.y - 101), Color("#e7e9e6"), 42.0)
	_streaks(c, Rect2(r.position.x, r.position.y + 101, r.size.x, 27), 14, 20.0)


func _booth_end(c: Control, r: Rect2) -> void:
	_panels(c, r, Color("#e7e9e6"), 64.0)
	var door := Rect2(r.position.x + 30, r.position.y + 18, 68, 108)
	c.draw_rect(door, Color("#a9b0b4"))
	c.draw_rect(door, Color("#4b5257"), false, 3.0)
	c.draw_rect(Rect2(door.position.x + 12, door.position.y + 12, 44, 34), Color("#33414b"))
	c.draw_rect(Rect2(door.end.x - 14, door.position.y + 58, 6, 14), Color("#2c3135"))
	c.draw_rect(Rect2(r.position.x, r.position.y + 6, r.size.x, 6), BLUE)


func _sign_etc(c: Control, r: Rect2) -> void:
	c.draw_rect(r, BLACK)
	_round(c, r.grow(-6), PURPLE, 10, WHITE, 5)
	_text(c, "ETC", Vector2(r.position.x + 98, r.get_center().y + 2), 70, WHITE)
	_text(c, "専用", Vector2(r.position.x + 196, r.get_center().y + 2), 38, WHITE, 70.0)


func _sign_mix(c: Control, r: Rect2) -> void:
	c.draw_rect(r, BLACK)
	var a := Rect2(r.position.x + 6, r.position.y + 6, r.size.x * 0.5 - 6, r.size.y - 12)
	var b := Rect2(r.position.x + r.size.x * 0.5, r.position.y + 6, r.size.x * 0.5 - 6, r.size.y - 12)
	_round(c, a, PURPLE, 10, WHITE, 5)
	_round(c, b, GREEN, 10, WHITE, 5)
	_text(c, "ETC", a.get_center() + Vector2(0, 2), 54, WHITE, a.size.x - 24)
	_text(c, "一般", b.get_center() + Vector2(0, 2), 52, WHITE, b.size.x - 24)


func _road(c: Control, r: Rect2, col: Color, s: String) -> void:
	c.draw_rect(r, col)
	_noise(c, r, Color.BLACK, 1800, 2.0)
	_noise(c, r, Color.WHITE, 500, 1.0)
	_text(c, s, r.get_center() + Vector2(0, 3), 96, Color("#f4f2ea"), r.size.x - 40)


## Pattern cell drawn in 2 x 2 px blocks: `black(u, v)` (pixels from the cell corner) says where it is black.
func _pattern(c: Control, r: Rect2, black: Callable) -> void:
	c.draw_rect(r, YELLOW)
	var y: float = 0.0
	while y < r.size.y:
		var x: float = 0.0
		while x < r.size.x:
			if black.call(x + 1.0, y + 1.0):
				c.draw_rect(Rect2(r.position.x + x, r.position.y + y, 2, 2), BLACK)
			x += 2.0
		y += 2.0
	_noise(c, r, Color.BLACK, 260)


## Inverted V chevrons (pass on both sides).
func _chevron(c: Control, r: Rect2) -> void:
	var cx: float = r.size.x * 0.5
	_pattern(c, r, func(u: float, v: float) -> bool: return fposmod(v + absf(u - cx) * 0.75, 44.0) < 20.0)


func _stripes(c: Control, r: Rect2) -> void:
	_pattern(c, r, func(u: float, v: float) -> bool: return fposmod(u + v, 45.25) < 22.6)


func _keep_both(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color("#3a3f44"))
	var ctr: Vector2 = r.get_center()
	c.draw_circle(ctr, 60.0, WHITE)
	c.draw_circle(ctr, 54.0, BLUE)
	for s in [-1.0, 1.0]:
		var a: Vector2 = ctr + Vector2(0, -32)
		var b: Vector2 = ctr + Vector2(26.0 * s, 26)
		c.draw_line(a, b, WHITE, 9.0)
		var d: Vector2 = (b - a).normalized()
		var n := Vector2(-d.y, d.x)
		c.draw_colored_polygon(PackedVector2Array([b + d * 14.0, b + n * 13.0, b - n * 13.0]), WHITE)


func _signal(c: Control, r: Rect2, go: bool) -> void:
	c.draw_rect(r, Color("#202224"))
	_round(c, r.grow(-8), Color("#0b0c0d"), 12, Color("#3d4246"), 4)
	var ctr: Vector2 = r.get_center()
	if go:
		var g := Color("#36ff8c")
		c.draw_rect(Rect2(ctr.x - 9, ctr.y - 40, 18, 46), g)
		c.draw_colored_polygon(PackedVector2Array([Vector2(ctr.x - 32, ctr.y + 2), Vector2(ctr.x + 32, ctr.y + 2),
			Vector2(ctr.x, ctr.y + 40)]), g)
	else:
		var red := Color("#ff2a2a")
		for s in [-1.0, 1.0]:
			c.draw_line(ctr + Vector2(-32, -32 * s), ctr + Vector2(32, 32 * s), red, 14.0)


func _pillar(c: Control, r: Rect2) -> void:
	_panels(c, r, Color("#c6d0cb"), 64.0)
	_streaks(c, r, 10, 90.0)
	for k in 10:
		var t: float = float(k) / 10.0
		c.draw_rect(Rect2(r.position.x, r.end.y - 26 + 2.6 * k, r.size.x, 2.6), Color(0.25, 0.22, 0.18, 0.06 + 0.3 * t))


func _steel(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color("#a6adb3"))
	_noise(c, r, Color.WHITE, 500, 2.0)
	_noise(c, r, Color.BLACK, 700, 2.0)
	_streaks(c, r, 8, 120.0)


func _antenna(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color("#e9ecec"))
	c.draw_rect(r.grow(-4), Color("#3c4247"), false, 3.0)
	c.draw_circle(r.get_center(), 34.0, Color("#c8cdd0"))
	c.draw_circle(r.get_center(), 26.0, Color("#9aa2a7"))
	c.draw_rect(Rect2(r.position.x + 12, r.end.y - 24, 40, 10), Color("#2a64b8"))


func _lamp(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color("#e6f1ff"))
	c.draw_rect(r.grow(-10), Color("#ffffff"))
	c.draw_rect(r, Color("#7d858a"), false, 6.0)


func _beacon(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color("#ff9a1a"))
	c.draw_circle(r.get_center(), 40.0, Color("#ffd27a"))
	c.draw_circle(r.get_center(), 20.0, Color("#fff4d6"))


func _curb(c: Control, r: Rect2) -> void:
	c.draw_rect(r, Color("#b9b8b2"))
	_noise(c, r, Color.BLACK, 900, 2.0)
	c.draw_rect(Rect2(r.position.x, r.position.y, 14, r.size.y), YELLOW)
	c.draw_rect(Rect2(r.end.x - 14, r.position.y, 14, r.size.y), YELLOW)


func _glass(c: Control, r: Rect2) -> void:
	for k in 12:
		var t: float = float(k) / 11.0
		c.draw_rect(Rect2(r.position.x, r.position.y + r.size.y * t, r.size.x, r.size.y / 11.0 + 1.0), Color("#8aa1b0").lerp(Color("#25333d"), t))
	c.draw_rect(r, Color("#3e4448"), false, 6.0)
