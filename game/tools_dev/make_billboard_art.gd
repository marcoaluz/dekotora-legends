extends SceneTree
## Gera as artes dos paineis/outdoors da beira da estrada (T-146), 1024 x 384, em
## assets/scenery/billboards/ad_01.png .. ad_04.png (precisa de janela, nao roda com --headless):
##   godot --path game -s res://tools_dev/make_billboard_art.gd
## Tudo ficticio (sem marcas reais): transportadora 銀河運輸 (a do andon 銀河丸), lamen da area de servico,
## campanha de seguranca (sono ao volante) e o festival de Dekotora. Fonte Noto Sans JP (OFL, ja no projeto).
## Para trocar: substitua os PNG (mesma proporcao ~2,7:1) ou ponha user://billboards/ad_01.png etc.

const W: int = 1024
const H: int = 384
const OUT := "res://assets/scenery/billboards/ad_%02d.png"

var _font: FontVariation
var _black: FontVariation


func _initialize() -> void:
	var base: FontFile = load("res://assets/fonts/NotoSansJP.ttf") as FontFile
	_font = FontVariation.new()
	_font.base_font = base
	_font.variation_opentype = {2003265652: 700}
	_black = FontVariation.new()
	_black.base_font = base
	_black.variation_opentype = {2003265652: 900}
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/scenery/billboards"))
	var painters: Array[Callable] = [_ad_transport, _ad_ramen, _ad_safety, _ad_festival]
	for i in painters.size():
		await _render(painters[i], OUT % (i + 1))
	quit()


func _render(painter: Callable, path: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(W, H)
	c.draw.connect(func() -> void: painter.call(c))
	vp.add_child(c)
	get_root().add_child(vp)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	print("arte: ", path, " erro=", img.save_png(ProjectSettings.globalize_path(path)))
	vp.queue_free()


func _text(c: Control, s: String, center: Vector2, px: int, col: Color, font: Font = null, max_w: float = 0.0) -> void:
	var f: Font = font if font != null else _font
	var w: float = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if max_w > 0.0 and w > max_w:
		px = int(px * max_w / w)
		w = f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	c.draw_string(f, Vector2(center.x - w * 0.5, center.y + (f.get_ascent(px) - f.get_descent(px)) * 0.5), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, px, col)


func _gradient(c: Control, top: Color, bottom: Color) -> void:
	for y in range(0, H, 4):
		c.draw_rect(Rect2(0, y, W, 4), top.lerp(bottom, float(y) / H))


# ---------------------------------------------------------------- 1: transportadora ficticia
func _ad_transport(c: Control) -> void:
	_gradient(c, Color("#0b1a46"), Color("#1d3f8a"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:                                                     # estrelas
		var p := Vector2(rng.randf() * W, rng.randf() * H * 0.6)
		c.draw_circle(p, rng.randf_range(1.0, 2.6), Color(1, 0.95, 0.75, rng.randf_range(0.4, 1.0)))
	var road := PackedVector2Array([Vector2(0, 330), Vector2(W, 300), Vector2(W, H), Vector2(0, H)])
	c.draw_colored_polygon(road, Color("#081030"))
	var y0: float = 236.0                                            # silhueta de caminhao com bau
	c.draw_rect(Rect2(620, y0, 300, 76), Color("#e8ecf4"))
	c.draw_rect(Rect2(920, y0 + 22, 70, 54), Color("#e8ecf4"))
	c.draw_rect(Rect2(940, y0 + 30, 36, 20), Color("#1d3f8a"))
	for x in [660.0, 700.0, 880.0, 960.0]:
		c.draw_circle(Vector2(x, y0 + 84), 15, Color("#0b0b10"))
	for k in 9:
		c.draw_circle(Vector2(632 + k * 34, y0 - 6), 4, Color("#ffd23a"))
	_text(c, "銀河運輸", Vector2(300, 120), 132, Color("#ffd23a"), _black)
	_text(c, "GINGA TRANSPORT", Vector2(300, 214), 44, Color("#f4f5f0"))
	_text(c, "日本全国  夜も走ります", Vector2(300, 290), 46, Color("#f4f5f0"))


# ---------------------------------------------------------------- 2: lamen da area de servico
func _ad_ramen(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color("#c8102e"))
	c.draw_rect(Rect2(0, H - 70, W, 70), Color("#7a0a1c"))
	var ctr := Vector2(820, 190)                                     # tigela com hashis
	c.draw_circle(ctr, 128, Color("#f4efe2"))
	c.draw_circle(ctr, 108, Color("#e3a33a"))
	c.draw_circle(ctr + Vector2(-34, -20), 30, Color("#f9f3e0"))
	c.draw_circle(ctr + Vector2(-34, -20), 13, Color("#f2b630"))
	c.draw_rect(Rect2(ctr.x + 10, ctr.y - 40, 70, 34), Color("#d77a7a"))
	c.draw_line(ctr + Vector2(-60, -170), ctr + Vector2(40, 30), Color("#3b2414"), 9)
	c.draw_line(ctr + Vector2(-20, -178), ctr + Vector2(70, 22), Color("#3b2414"), 9)
	_text(c, "街道ラーメン", Vector2(345, 130), 120, Color("#fff4dc"), _black, 640)
	_text(c, "KAIDŌ RAMEN", Vector2(350, 228), 46, Color("#ffd23a"))
	_text(c, "次のSA  5km", Vector2(350, H - 35), 52, Color("#fff4dc"))


# ---------------------------------------------------------------- 3: campanha de seguranca
func _ad_safety(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color("#f4f5f0"))
	c.draw_rect(Rect2(0, 0, W, 88), Color("#11603a"))
	c.draw_rect(Rect2(0, H - 30, W, 30), Color("#11603a"))
	_text(c, "安全運転", Vector2(W * 0.5, 46), 64, Color("#f4f5f0"), _black)
	_text(c, "眠い時は 休憩を", Vector2(W * 0.5 - 90, 190), 104, Color("#141414"), _black, 760)
	_text(c, "DROWSY? TAKE A BREAK", Vector2(W * 0.5 - 90, 290), 42, Color("#11603a"))
	var m := Vector2(900, 220)                                       # lua (sono)
	c.draw_circle(m, 70, Color("#f3c400"))
	c.draw_circle(m + Vector2(30, -22), 62, Color("#f4f5f0"))
	_text(c, "Zz", Vector2(860, 110), 52, Color("#1c3f94"))


# ---------------------------------------------------------------- 4: festival de Dekotora (neon)
func _ad_festival(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, W, H), Color("#120a1e"))
	for k in 14:                                                     # raios saindo do centro
		var a: float = TAU * k / 14.0
		var p := PackedVector2Array([Vector2(W * 0.5, H * 0.5), Vector2(W * 0.5, H * 0.5) + Vector2(cos(a), sin(a)) * 900,
			Vector2(W * 0.5, H * 0.5) + Vector2(cos(a + 0.12), sin(a + 0.12)) * 900])
		c.draw_colored_polygon(p, Color(1.0, 0.2, 0.6, 0.18))
	for k in 30:                                                     # fileira de luzes
		c.draw_circle(Vector2(20 + k * 34.5, 24), 7, Color("#ffe066") if k % 2 == 0 else Color("#ff4fa3"))
		c.draw_circle(Vector2(20 + k * 34.5, H - 24), 7, Color("#ff4fa3") if k % 2 == 0 else Color("#ffe066"))
	_text(c, "デコトラ祭", Vector2(W * 0.5, 150), 138, Color("#ff4fa3"), _black)
	_text(c, "デコトラ祭", Vector2(W * 0.5 - 4, 146), 138, Color("#ffe3f1"), _black)
	_text(c, "DEKOTORA MATSURI  ·  爆走 夏の祭典", Vector2(W * 0.5, 268), 44, Color("#7ff3ff"), null, 900)
