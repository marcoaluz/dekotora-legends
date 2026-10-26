extends SceneTree
## T-232: monta cada pintura (mural, traseira, teto) em cada caminhao e imprime os problemas de encaixe (PaintFit).
## godot --headless --path game -s res://tools_dev/probe_t232.gd -- [--model=STEM] [--parts=id1,id2]

func _initialize() -> void:
	var only: String = ""
	var parts: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="):
			only = a.substr(8)
		elif a.begins_with("--parts="):
			parts = a.substr(8).split(",")
	var cat: AccessoryCatalog = AccessoryCatalog.get_instance()
	var ids: Array[String] = []
	for e in cat.data.get("accessories", []):
		if PaintFit.handles(e) and (parts.is_empty() or String(e["id"]) in parts):
			ids.append(String(e["id"]))
	var total: int = 0
	var bad: int = 0
	for f in DirAccess.get_files_at(TruckNode.MODEL_DIR):
		var n: String = f.trim_suffix(".remap")
		if not n.ends_with(".glb") or (only != "" and n.get_basename() != only):
			continue
		var stem: String = n.get_basename()
		var data: Dictionary = TruckSockets.for_model(TruckNode.MODEL_DIR + n)
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + n, "", "")
		var fits: int = 0
		for id in ids:
			if not TruckSockets.socket(data, String(cat.entry(id)["socket"])).has("rect"):
				continue
			fits += 1
			total += 1
			var probs: Array[String] = PartFit.check_part(model, data, cat, id)
			if not probs.is_empty():
				bad += 1
				print("  %s %s: %s" % [stem, id, ", ".join(probs)])
		print("%s: %d pinturas montadas" % [stem, fits])
		model.free()
	print("TOTAL %d montagens, %d com problema" % [total, bad])
	quit()
