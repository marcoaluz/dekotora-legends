extends SceneTree
## T-202 helper (works headless): crops part of a PNG and enlarges it (nearest) for close-up review sheets.
## godot --headless --path game -s res://tools_dev/crop_image.gd -- --in=ABS.png --out=ABS.png --rect=x,y,w,h [--zoom=2]


func _initialize() -> void:
	var src: String = ""
	var dst: String = ""
	var rect := Rect2i()
	var zoom: int = 1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			src = a.substr(5)
		elif a.begins_with("--out="):
			dst = a.substr(6)
		elif a.begins_with("--rect="):
			var p: PackedStringArray = a.substr(7).split(",")
			rect = Rect2i(int(p[0]), int(p[1]), int(p[2]), int(p[3]))
		elif a.begins_with("--zoom="):
			zoom = maxi(int(a.substr(7)), 1)
	var img := Image.load_from_file(src)
	if img == null:
		push_error("nao abriu " + src)
		quit(1)
		return
	rect = rect.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var out: Image = img.get_region(rect)
	if zoom > 1:
		out.resize(out.get_width() * zoom, out.get_height() * zoom, Image.INTERPOLATE_NEAREST)
	out.save_png(dst)
	print("RECORTE: ", dst, " ", out.get_size())
	quit(0)
