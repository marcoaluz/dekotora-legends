extends SceneTree
## T-265 (depuracao): lista os vertices da saia fora das caixas do encaixe (ou dentro de zona protegida) num caminhao.
## Uso: godot --headless --path game -s res://tools_dev/probe_t265_out.gd -- --stem=dekotora_truck_tarp_americana [--part=ID] [--side=R]

func _initialize() -> void:
	var stems: Array[String] = []
	var parts: Array[String] = []
	var side: String = "R"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stem="):
			stems.append_array(Array(a.get_slice("=", 1).split(",")))
		elif a.begins_with("--part="):
			parts.append_array(Array(a.get_slice("=", 1).split(",")))
		elif a.begins_with("--side="):
			side = a.get_slice("=", 1)
	var c := AccessoryCatalog.get_instance()
	if parts.is_empty():
		parts.assign(PartFit.socket_parts(c, ["side_skirts_r"]).filter(func(i: String) -> bool: return SkirtFit.handles(c.entry(i))))
	for stem in stems:
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", String(data["body"]), String(data["cab"]))
		var slot: String = "side_skirts_" + side.to_lower()
		var s: Dictionary = TruckSockets.socket(data, slot)
		var boxes: Array[AABB] = []
		for b in s.get("boxes", []):
			boxes.append(TruckSockets.aabb_of(b).grow(PartFit.TOL))
		print(stem, " anchor ", s.get("anchor"), " floor ", s.get("floor_y"), " runs ", s.get("runs"), " arcs ", s.get("arcs"))
		for id in parts:
			var n: Node3D = c.attach(model, id, side)
			if n == null:
				print("  ", id, " nao montou")
				continue
			var bad: Dictionary = {}
			for mi in StripFit._meshes(n):
				var t: Transform3D = PartFit.rel_xform(mi, model)
				for v in mi.mesh.get_faces():
					var w: Vector3 = t * v
					var ok: bool = false
					for b in boxes:
						if b.has_point(w):
							ok = true
							break
					if not ok:
						var key: String = "%s (%.3f, %.3f, %.3f)" % [mi.name, w.x, w.y, w.z]
						bad[key] = int(bad.get(key, 0)) + 1
			print("  ", id, ": ", bad.size(), " pontos fora")
			for k in bad:
				var near: String = ""
				print("     ", k, " x", bad[k])
			if not bad.is_empty():
				var first: String = String(bad.keys()[0])
				var nums: PackedStringArray = first.get_slice("(", 1).trim_suffix(")").split(",")
				var w0 := Vector3(float(nums[0]), float(nums[1]), float(nums[2]))
				for b in boxes:
					if absf(clampf(w0.z, b.position.z, b.end.z) - w0.z) < 0.05 and absf(clampf(w0.y, b.position.y, b.end.y) - w0.y) < 0.05:
						print("       caixa perto: ", b)
			n.get_parent().remove_child(n)
			n.free()
		model.free()
	quit()
