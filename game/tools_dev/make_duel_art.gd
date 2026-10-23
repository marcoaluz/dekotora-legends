extends SceneTree
## T-204: generates the art of the duel opening in assets/textures/duel/ (needs a window, does not run --headless):
##   godot --path game -s res://tools_dev/make_duel_art.gd [-- --only=raijin,fujin,title,aura,fog]
##   raijin.png / fujin.png  1024x1280 guardians (our drawing, duel_art_raijin.gd / duel_art_fujin.gd)
##   title_taiketsu.png      1024x560 kanji 対決, red-orange gradient, ink + gold outline (Noto Sans JP Black, OFL)
##   aura.png                512x512 white flame halo (tinted and added in the game)
##   fog_puff.png            256x256 white soft cloud puff (ground fog of the studio)
## Deterministic (fixed seeds). Shapes are drawn 2x bigger with 4x MSAA and reduced (smooth edges).

const OUT_DIR := "res://assets/textures/duel"
const RAIJIN = preload("res://tools_dev/duel_art_raijin.gd")
const FUJIN = preload("res://tools_dev/duel_art_fujin.gd")
const SS: int = 2

var _only: PackedStringArray = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7).split(",")
	_run.call_deferred()


func _want(n: String) -> bool:
	return _only.is_empty() or n in _only


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if _want("raijin"):
		await _save(await _render(Vector2i(1024, 1280), RAIJIN.paint), "raijin.png")
	if _want("fujin"):
		await _save(await _render(Vector2i(1024, 1280), FUJIN.paint), "fujin.png")
	if _want("title"):
		await _title()
	if _want("aura"):
		_save(_aura(512), "aura.png")
	if _want("fog"):
		_save(_fog_puff(256), "fog_puff.png")
	quit()


func _save(img: Image, name: String) -> void:
	var path: String = ProjectSettings.globalize_path(OUT_DIR + "/" + name)
	print("arte T-204: ", path, " ", img.get_size(), " erro=", img.save_png(path))


## Draws `painter(canvas)` on a transparent SubViewport `SS` times bigger and reduces it to `size`.
func _render(size: Vector2i, painter: Callable) -> Image:
	var vp := SubViewport.new()
	vp.size = size * SS
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(size * SS)
	c.draw.connect(func() -> void:
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(SS, SS))
		painter.call(c))
	vp.add_child(c)
	get_root().add_child(vp)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	img.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return img


# ---------------------------------------------------------------- title 対決
func _title() -> void:
	var font := FontVariation.new()
	font.base_font = load("res://assets/fonts/NotoSansJP.ttf") as FontFile
	font.variation_opentype = {2003265652: 900}
	var size := Vector2i(1024, 560)
	var px: int = 400
	var text: String = "対決"
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var base := Vector2((size.x - w) * 0.5, size.y * 0.5 + (font.get_ascent(px) - font.get_descent(px)) * 0.5 - 6.0)
	var masks: Array[Image] = []
	for outline in [0, 46, 70, 112]:                                # fill, ink, gold ring, dark glow
		var o: int = outline
		var img: Image = await _render(size, func(ci: CanvasItem) -> void:
			if o == 0:
				ci.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)
			else:
				ci.draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, o, Color.WHITE)
				ci.draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE))
		masks.append(img)
	var noise := FastNoiseLite.new()
	noise.seed = 204
	noise.frequency = 0.02
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var top := Color("#ffe14a")
	var mid := Color("#ff7a12")
	var bot := Color("#c8091a")
	var y0: float = base.y - font.get_ascent(px) * 0.86
	var y1: float = base.y + font.get_descent(px) * 0.2
	for y in size.y:
		var g: float = clampf((float(y) - y0) / (y1 - y0), 0.0, 1.0)
		var grad: Color = top.lerp(mid, g / 0.45) if g < 0.45 else mid.lerp(bot, (g - 0.45) / 0.55)
		for x in size.x:
			var a_fill: float = masks[0].get_pixel(x, y).a
			var a_ink: float = masks[1].get_pixel(x, y).a
			var a_gold: float = masks[2].get_pixel(x, y).a
			var a_glow: float = masks[3].get_pixel(x, y).a
			var streak: float = 1.0 - 0.16 * clampf(noise.get_noise_2d(float(x) * 0.35, float(y) * 4.0) * 0.5 + 0.5, 0.0, 1.0)
			var col := Color(0.32, 0.02, 0.06, a_glow * 0.55)                          # dark red glow
			col = _over(col, Color(1.0, 0.82, 0.38, a_gold))                         # gold ring
			col = _over(col, Color(0.09, 0.02, 0.05, a_ink))                         # ink
			col = _over(col, Color(grad.r * streak, grad.g * streak, grad.b * streak, a_fill))
			out.set_pixel(x, y, col)
	_save(out, "title_taiketsu.png")


static func _over(dst: Color, src: Color) -> Color:
	var a: float = src.a + dst.a * (1.0 - src.a)
	if a <= 0.0001:
		return Color(0, 0, 0, 0)
	var c: Color = (Color(src.r, src.g, src.b) * src.a + Color(dst.r, dst.g, dst.b) * dst.a * (1.0 - src.a)) / a
	return Color(c.r, c.g, c.b, a)


# ---------------------------------------------------------------- aura (flame halo) and fog puff
func _aura(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 2041
	noise.frequency = 0.9
	for y in n:
		for x in n:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) / float(n) * 2.0 - Vector2.ONE
			var r: float = p.length()
			var a: float = atan2(p.y, p.x)
			var tongues: float = pow(absf(sin(a * 9.0 + 0.6 * sin(a * 3.0))), 0.6)    # 18 flame tongues
			var edge: float = 0.74 + 0.16 * tongues + 0.05 * noise.get_noise_2d(cos(a) * 3.0, sin(a) * 3.0)
			var rim: float = exp(-pow((r - edge * 0.93) / 0.07, 2.0))                    # bright flame band
			var body: float = clampf(1.0 - r / edge, 0.0, 1.0)                           # soft glow inside
			var inner_ring: float = exp(-pow((r - 0.5) / 0.025, 2.0)) * 0.55             # thin halo ring
			var v: float = clampf(rim * 0.95 + body * body * 0.55 + inner_ring, 0.0, 1.0) * clampf((1.02 - r) / 0.08, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, v))
	return img


func _fog_puff(n: int) -> Image:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 2042
	noise.fractal_octaves = 4
	noise.frequency = 0.018
	for y in n:
		for x in n:
			var p := Vector2(float(x) + 0.5, float(y) + 0.5) / float(n) * 2.0 - Vector2.ONE
			var r: float = Vector2(p.x, p.y * 1.25).length()
			var fall: float = clampf(1.0 - r, 0.0, 1.0)
			var nv: float = noise.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var v: float = clampf(fall * fall * (0.55 + 0.9 * nv), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, v))
	return img
