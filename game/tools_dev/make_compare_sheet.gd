extends SceneTree
## Folha de comparacao (T-155): junta PNGs numa grade (linha a linha), cada um reduzido para a mesma largura.
## Uso: godot --headless --path game -s res://tools_dev/make_compare_sheet.gd -- --out=FOLHA.png [--cols=2] [--w=640] A.png B.png ...
## Ordem: esquerda para a direita, de cima para baixo (antes, depois, antes, depois...). Funciona sem tela.


func _init() -> void:
	var out: String = ""
	var cols: int = 2
	var w: int = 640
	var files: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--cols="):
			cols = maxi(1, int(a.substr(7)))
		elif a.begins_with("--w="):
			w = maxi(64, int(a.substr(4)))
		else:
			files.append(a)
	if out == "" or files.is_empty():
		push_error("uso: -- --out=FOLHA.png [--cols=2] [--w=640] A.png B.png ...")
		quit(1)
		return
	var imgs: Array[Image] = []
	var h: int = 0
	for f in files:
		var img := Image.load_from_file(f)
		if img == null or img.is_empty():
			push_error("nao abriu: " + f)
			quit(1)
			return
		img.convert(Image.FORMAT_RGB8)
		img.resize(w, roundi(float(img.get_height()) * w / img.get_width()), Image.INTERPOLATE_LANCZOS)
		h = maxi(h, img.get_height())
		imgs.append(img)
	var gap: int = 6
	var rows: int = ceili(float(imgs.size()) / cols)
	var sheet := Image.create(cols * w + (cols + 1) * gap, rows * h + (rows + 1) * gap, false, Image.FORMAT_RGB8)
	sheet.fill(Color(0.08, 0.08, 0.09))
	for i in imgs.size():
		var x: int = gap + (i % cols) * (w + gap)
		var y: int = gap + (i / cols) * (h + gap)
		sheet.blit_rect(imgs[i], Rect2i(0, 0, imgs[i].get_width(), imgs[i].get_height()), Vector2i(x, y))
	sheet.save_png(out)
	print("OK folha ", out, " ", sheet.get_size())
	quit(0)
