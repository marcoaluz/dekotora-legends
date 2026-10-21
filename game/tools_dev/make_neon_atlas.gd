extends SceneTree
## T-188: neon shop signs with kanji for the city blocks (precisa de janela, nao roda com --headless):
##   assets/textures/scenic/neon_atlas.png  1024 x 512
##     left half : 16 vertical signs (tategaki), 64 x 256 each, 8 per row
##     right half: 8 horizontal signs, 256 x 128 each, 2 per row
## godot --path game -s res://tools_dev/make_neon_atlas.gd
## Fictional shop names only; font Noto Sans JP (OFL, already in the project). Map in NeonSigns.cell_uv().

const OUT := "res://assets/textures/scenic/neon_atlas.png"
const BOARD := Color("#120e16")
const NEON: Array[Color] = [Color("#ff2e88"), Color("#21e6ff"), Color("#ffd23a"), Color("#3dff7a"),
	Color("#ff8a2a"), Color("#b44dff"), Color("#fff1d0"), Color("#ff4040")]

var _font: FontVariation


func _initialize() -> void:
	_font = FontVariation.new()
	_font.base_font = load("res://assets/fonts/NotoSansJP.ttf") as FontFile
	_font.variation_opentype = {2003265652: 800}
	_run.call_deferred()


func _run() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(1024, 512)
	vp.transparent_bg = false
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var c := Control.new()
	c.size = Vector2(1024, 512)
	c.draw.connect(func() -> void: _paint(c))
	vp.add_child(c)
	get_root().add_child(vp)
	for i in 4:
		await process_frame
	var img: Image = vp.get_texture().get_image()
	print("neon atlas: ", OUT, " erro=", img.save_png(ProjectSettings.globalize_path(OUT)))
	quit()


func _paint(c: Control) -> void:
	c.draw_rect(Rect2(0, 0, 1024, 512), Color.BLACK)
	var vt: PackedStringArray = NeonSigns.VERTICAL
	for i in vt.size():
		var r := Rect2((i % 8) * 64, (i / 8) * 256, 64, 256)
		_board(c, r, NEON[i % NEON.size()])
		var chars: int = vt[i].length()
		var px: int = int(minf(46.0, 220.0 / float(chars)))
		for k in chars:
			var cy: float = r.position.y + 128.0 + (float(k) - float(chars - 1) * 0.5) * px * 1.05
			_glow_text(c, vt[i][k], Vector2(r.get_center().x, cy), px, NEON[i % NEON.size()])
	var hz: PackedStringArray = NeonSigns.HORIZONTAL
	for i in hz.size():
		var r := Rect2(512 + (i % 2) * 256, (i / 2) * 128, 256, 128)
		var col: Color = NEON[(i * 3 + 1) % NEON.size()]
		_board(c, r, col)
		_glow_text(c, hz[i], r.get_center(), 52, col, 220.0)


## Dark board with a double neon tube along the border.
func _board(c: Control, r: Rect2, col: Color) -> void:
	c.draw_rect(r.grow(-2), BOARD)
	c.draw_rect(r.grow(-6), col * Color(1, 1, 1, 0.35), false, 4.0)
	c.draw_rect(r.grow(-7), col.lightened(0.4), false, 1.5)


## Text with a soft halo (several wider, fainter passes) so it reads as a lit tube.
func _glow_text(c: Control, s: String, center: Vector2, px: int, col: Color, max_w: float = 0.0) -> void:
	var w: float = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if max_w > 0.0 and w > max_w:
		px = int(px * max_w / w)
		w = _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var asc: float = _font.get_ascent(px)
	var dsc: float = _font.get_descent(px)
	var pos := Vector2(center.x - w * 0.5, center.y + (asc - dsc) * 0.5)
	for k in [6, 4, 2]:
		c.draw_string_outline(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, k * 2, col * Color(1, 1, 1, 0.16))
	c.draw_string(_font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, px, col.lightened(0.55))
