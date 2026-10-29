extends SceneTree
## Saias grandes (T-265): triangulos de cada saia (malha de perto e de longe, um lado) em TODOS os caminhoes jogaveis e o
## pior caso, para o catalogo (`build_t265_parts.py -- --tris ARQ.json`). Tambem imprime trechos e arcos por caminhao.
## Uso (raiz do projeto): godot --headless --path game -s res://tools_dev/measure_t265.gd -- [--out=ABS.json] [--verbose]

func _initialize() -> void:
	var out: String = ""
	var verbose: bool = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.get_slice("=", 1)
		elif a == "--verbose":
			verbose = true
	var c := AccessoryCatalog.get_instance()
	var ids: Array[String] = PartFit.socket_parts(c, ["side_skirts_r"]).filter(func(i: String) -> bool: return SkirtFit.handles(c.entry(i)))
	var worst: Dictionary = {}
	var where: Dictionary = {}
	var files: Array = Array(DirAccess.get_files_at(TruckSockets.DIR))
	files.sort()
	for f in files:
		if not String(f).ends_with(".json") or String(f).ends_with(".surf.json"):
			continue
		var stem: String = String(f).get_basename()
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		if String(data.get("body", "")) == "carreta":
			continue
		var s: Dictionary = TruckSockets.socket(data, "side_skirts_r")
		if s.is_empty():
			print("SEM SAIA ", stem)
			continue
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", String(data["body"]), String(data["cab"]))
		var line: PackedStringArray = []
		for id in ids:
			var n: Node3D = c.attach(model, id, "R")
			if n == null:
				continue
			var t0: int = int(n.get_meta("skirt_tris", 0))
			var t1: int = int(n.get_meta("skirt_tris_lod", 0))
			if not worst.has(id) or t0 > int(worst[id][0]):
				worst[id] = [t0, maxi(t1, int(worst.get(id, [0, 0])[1]))]
				where[id] = stem
			else:
				worst[id][1] = maxi(int(worst[id][1]), t1)
			line.append("%s=%d/%d" % [id.trim_prefix("skirt_"), t0, t1])
			n.get_parent().remove_child(n)
			n.free()
		model.free()
		var runs: PackedStringArray = []
		for r in s.get("runs", []):
			runs.append("%.2f..%.2f" % [float(r[0]), float(r[1])])
		print("%-40s trechos %s | arcos %d | chao %.2f topo %.2f" % [stem, " ".join(runs), (s.get("arcs", []) as Array).size(),
				float(s.get("floor_y", 0.0)), float(s["anchor"][1])])
		if verbose:
			print("    ", " ".join(line))
	for id in worst:
		print("PIOR %-20s %5d tri perto, %4d longe (%s)" % [id, worst[id][0], worst[id][1], where[id]])
	if out != "":
		var fa := FileAccess.open(out, FileAccess.WRITE)
		fa.store_string(JSON.stringify(worst, " ", true))
		fa.close()
		print("OK ", out)
	quit()
