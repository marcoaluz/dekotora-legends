extends SceneTree
## Recorta e amplia um pedaco de PNGs (comparar detalhes de capturas; funciona sem tela). T-171.
## godot --headless --path game -s res://tools_dev/crop_zoom.gd -- --rect=X,Y,W,H --zoom=3 --out=ABS.png A.png B.png ...
## Junta os recortes lado a lado (na ordem) num PNG so.


func _init() -> void:
	var rect := Rect2i(0, 0, 200, 120)
	var zoom: int = 3
	var out: String = ""
	var files: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--rect="):
			var p: PackedStringArray = a.substr(7).split(",")
			rect = Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
		elif a.begins_with("--zoom="):
			zoom = int(a.substr(7))
		elif a.begins_with("--out="):
			out = a.substr(6)
		else:
			files.append(a)
	var w: int = rect.size.x * zoom
	var h: int = rect.size.y * zoom
	var sheet := Image.create(w * files.size() + 4 * (files.size() - 1), h, false, Image.FORMAT_RGB8)
	sheet.fill(Color.WHITE)
	for i in files.size():
		var img := Image.load_from_file(files[i])
		if img == null:
			continue
		img.convert(Image.FORMAT_RGB8)
		var c: Image = img.get_region(rect)
		c.resize(w, h, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(c, Rect2i(0, 0, w, h), Vector2i(i * (w + 4), 0))
	sheet.save_png(out)
	print("FOLHA: ", out)
	quit()
