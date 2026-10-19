extends SceneTree
## Makes the track events atlas (T-139): assets/textures/event_atlas.png (EventAtlas map). Needs a window
## (does not run with --headless): godot --path game -s res://tools_dev/make_event_atlas.gd
## 100% our art: shapes drawn here + Noto Sans JP (OFL, already in the project).

const RED := Color("#c8102e")
const BLUE := Color("#1c3f94")
const YELLOW := Color("#f3c400")
const WHITE := Color("#f4f5f0")
const BLACK := Color("#141414")
const LED := Color("#ffa31a")

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
	var vp := SubViewport.new()
	vp.size = Vector2i(EventAtlas.W, EventAtlas.H)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(vp.size)
	c.draw.connect(func() -> void: _draw_all(c))
	vp.add_child(c)
	get_root().add_child(vp)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	var err: int = img.save_png(ProjectSettings.globalize_path(EventAtlas.ATLAS))
	print("atlas: ", EventAtlas.ATLAS, " ", vp.size, " erro=", err)
	quit()


func _r(id: String) -> Rect2:
	return Rect2(EventAtlas.rects()[id])


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


func _draw_all(c: Control) -> void:
	_speed(c, _r("spd_60"), "60")
	_diamond(c, _r("warn_works"), func(rr: Rect2) -> void: _worker_icon(c, rr))
	_diamond(c, _r("warn_narrow_r"), func(rr: Rect2) -> void: _narrow_icon(c, rr, 1.0))
	_diamond(c, _r("warn_narrow_l"), func(rr: Rect2) -> void: _narrow_icon(c, rr, -1.0))
	_led_arrow(c, _r("arrow_l"), -1.0)
	_led_arrow(c, _r("arrow_r"), 1.0)
	_triangle(c, _r("triangle"))
	_glow(c, _r("glow"))
	_vms(c, _r("vms_accident"), "この先 事故", "車線規制")
	_vms(c, _r("vms_works"), "この先 工事", "車線規制")
	_stripes(c, _r("barricade"))
	var r: Rect2 = _r("kouji")
	c.draw_rect(r, BLACK)
	c.draw_rect(r.grow(-4), YELLOW)
	_text(c, "工事中", r.get_center(), 50, BLACK, r.size.x - 20.0, _bold)
	for id in ["d400", "d200"]:
		r = _r(id)
		c.draw_rect(r, BLACK)
		_round_rect(c, r.grow(-3), WHITE, 5)
		_text(c, id.substr(1) + "m", r.get_center(), 46, BLACK, r.size.x - 14.0, _bold)
	r = _r("aux_narrow")
	c.draw_rect(r, BLACK)
	_round_rect(c, r.grow(-3), WHITE, 6)
	_text(c, "車線減少", r.get_center(), 46, BLACK, r.size.x - 20.0, _bold)
	c.draw_rect(_r("solid_black"), Color("#101012"))
	c.draw_rect(_r("solid_white"), WHITE)
	c.draw_rect(_r("steel"), Color("#5d6168"))
	c.draw_rect(_r("solid_yellow"), YELLOW)
	c.draw_rect(_r("solid_orange"), Color("#ff6a13"))
	c.draw_rect(_r("solid_grey"), Color("#8e939a"))
	_vms(c, _r("vms_lanes2"), "この先 2車線", "追越車線 終わり")          # T-153
	_lanes_board(c, _r("board_lanes2"))


## T-153: blue lane-reduction board: "この先" + three lanes whose right one bends into the middle + "2車線".
func _lanes_board(c: Control, r: Rect2) -> void:
	c.draw_rect(r, WHITE)
	_round_rect(c, r.grow(-5), BLUE, 6)
	_text(c, "この先", r.position + Vector2(52, 36), 30, WHITE, 90.0, _bold)
	_text(c, "2車線", r.position + Vector2(52, 88), 34, WHITE, 92.0, _bold)
	var base: Vector2 = r.position + Vector2(150, 112)
	for k in 2:                                            # two straight arrows
		var x: float = base.x + k * 30.0
		c.draw_line(Vector2(x, base.y), Vector2(x, base.y - 74), WHITE, 7.0, true)
		c.draw_colored_polygon(PackedVector2Array([Vector2(x - 11, base.y - 70), Vector2(x + 11, base.y - 70), Vector2(x, base.y - 92)]), WHITE)
	var bend := PackedVector2Array([Vector2(base.x + 66, base.y), Vector2(base.x + 66, base.y - 30), Vector2(base.x + 36, base.y - 58)])
	c.draw_polyline(bend, WHITE, 7.0, true)                # the right lane bends into the middle one
	c.draw_colored_polygon(PackedVector2Array([Vector2(base.x + 26, base.y - 48), Vector2(base.x + 42, base.y - 66),
		Vector2(base.x + 28, base.y - 70)]), WHITE)


func _speed(c: Control, r: Rect2, s: String) -> void:
	var ctr: Vector2 = r.get_center()
	c.draw_circle(ctr, 62.0, WHITE)
	c.draw_circle(ctr, 58.0, RED)
	c.draw_circle(ctr, 45.0, WHITE)
	_text(c, s, ctr + Vector2(0, 2), 62, BLUE, 78.0, _bold)


func _diamond(c: Control, r: Rect2, icon: Callable) -> void:
	var m: Vector2 = r.get_center()
	var pts := func(h: float) -> PackedVector2Array:
		return PackedVector2Array([m + Vector2(0, -h), m + Vector2(h, 0), m + Vector2(0, h), m + Vector2(-h, 0)])
	c.draw_colored_polygon(pts.call(63.0), BLACK)
	c.draw_colored_polygon(pts.call(57.0), YELLOW)
	c.draw_colored_polygon(pts.call(53.0), BLACK)
	c.draw_colored_polygon(pts.call(50.0), YELLOW)
	icon.call(r)


## Worker digging (road works): head, body, legs, shovel and a mound.
func _worker_icon(c: Control, r: Rect2) -> void:
	var m: Vector2 = r.get_center()
	c.draw_circle(m + Vector2(-8, -24), 6.0, BLACK)
	c.draw_line(m + Vector2(-8, -16), m + Vector2(-2, 6), BLACK, 7.0, true)
	c.draw_line(m + Vector2(-2, 6), m + Vector2(-14, 26), BLACK, 6.0, true)
	c.draw_line(m + Vector2(-2, 6), m + Vector2(8, 26), BLACK, 6.0, true)
	c.draw_line(m + Vector2(-6, -8), m + Vector2(12, 2), BLACK, 5.0, true)
	c.draw_line(m + Vector2(6, -6), m + Vector2(22, 18), BLACK, 4.0, true)
	c.draw_colored_polygon(PackedVector2Array([m + Vector2(18, 18), m + Vector2(28, 14), m + Vector2(30, 24), m + Vector2(22, 27)]), BLACK)
	c.draw_colored_polygon(PackedVector2Array([m + Vector2(12, 30), m + Vector2(24, 24), m + Vector2(36, 30)]), BLACK)


## Lane reduction: one straight edge and the other bending in (side +1 = the right lane ends).
func _narrow_icon(c: Control, r: Rect2, side: float) -> void:
	var m: Vector2 = r.get_center()
	c.draw_line(m + Vector2(-side * 16, 32), m + Vector2(-side * 16, -32), BLACK, 6.0, true)
	var bend := PackedVector2Array([m + Vector2(side * 20, 32), m + Vector2(side * 20, 6), m + Vector2(side * 2, -14), m + Vector2(side * 2, -32)])
	c.draw_polyline(bend, BLACK, 6.0, true)
	c.draw_line(m + Vector2(side * 2, 26), m + Vector2(side * 2, 14), BLACK, 3.0)   # the lane line that ends
	c.draw_line(m + Vector2(side * 2, 6), m + Vector2(side * 2, -2), BLACK, 3.0)


## Arrow board (LED dots on transparent: the game draws it additively over a black board).
func _led_arrow(c: Control, r: Rect2, dir: float) -> void:
	var m: Vector2 = r.get_center()
	var dots: Array[Vector2] = []
	for i in 7:                                          # shaft
		dots.append(Vector2(dir * (-34.0 + i * 10.0), 0.0))
	for i in 5:                                          # head: two diagonals from the tip
		var k: float = float(i) * 10.0
		dots.append(Vector2(dir * (36.0 - k), -k))
		dots.append(Vector2(dir * (36.0 - k), k))
	for d in dots:
		c.draw_circle(m + d, 5.5, Color(1.0, 0.82, 0.25))
		c.draw_circle(m + d, 3.0, Color(1.0, 0.95, 0.7))


func _triangle(c: Control, r: Rect2) -> void:
	var o: Vector2 = r.position
	var outer := PackedVector2Array([o + Vector2(64, 10), o + Vector2(122, 112), o + Vector2(6, 112)])
	var inner := PackedVector2Array([o + Vector2(64, 40), o + Vector2(96, 96), o + Vector2(32, 96)])
	c.draw_colored_polygon(outer, RED)
	c.draw_polyline(PackedVector2Array([outer[0], outer[1], outer[2], outer[0]]), WHITE, 3.0, true)
	c.draw_colored_polygon(inner, Color(1, 1, 1, 0))      # hole (cleared below)
	_fill_clear(c, inner)


func _fill_clear(c: Control, poly: PackedVector2Array) -> void:
	# draw_colored_polygon with alpha 0 does not erase: paint the hole with dark grey (reads as "see-through")
	c.draw_colored_polygon(poly, Color(0.12, 0.12, 0.13, 1.0))


func _glow(c: Control, r: Rect2) -> void:
	var m: Vector2 = r.get_center()
	for i in 24:
		var t: float = 1.0 - float(i) / 24.0
		c.draw_circle(m, 62.0 * t, Color(1, 1, 1, 0.05 + 0.1 * (1.0 - t)))
	c.draw_circle(m, 10.0, Color(1, 1, 1, 1))


func _vms(c: Control, r: Rect2, l1: String, l2: String) -> void:
	c.draw_rect(r, Color("#2a2c31"))
	_round_rect(c, r.grow(-5), Color("#060607"), 4)
	_text(c, l1, r.position + Vector2(r.size.x * 0.5, 40), 44, LED, r.size.x - 24.0, _bold)
	_text(c, l2, r.position + Vector2(r.size.x * 0.5, 92), 44, LED, r.size.x - 24.0, _bold)


func _stripes(c: Control, r: Rect2) -> void:
	c.draw_rect(r, YELLOW)
	var k: float = -r.size.y
	while k < r.size.x:
		var a: Vector2 = r.position + Vector2(k, r.size.y)
		c.draw_colored_polygon(PackedVector2Array([a, a + Vector2(18, 0), a + Vector2(18 + r.size.y, -r.size.y), a + Vector2(r.size.y, -r.size.y)]), BLACK)
		k += 40.0
	c.draw_rect(Rect2(r.position, Vector2(r.size.x, 64)), BLACK, false, 4.0)
