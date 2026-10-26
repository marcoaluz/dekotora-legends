extends SceneTree
## Sonda da T-231: monta pecas da oficina num caminhao sem tela e imprime malhas e problemas de encaixe.
## Uso: godot --headless --path game -s res://tools_dev/probe_t231.gd -- --model=base_chata --parts=rocket_round,boxlight_dash_r


func _initialize() -> void:
	var stem: String = "base_chata"
	var ids: PackedStringArray = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="):
			stem = a.get_slice("=", 1)
		elif a.begins_with("--parts="):
			ids = a.get_slice("=", 1).split(",")
	var path: String = TruckNode.MODEL_DIR + "dekotora_truck_%s.glb" % stem
	var data: Dictionary = TruckSockets.for_model(path)
	var c := AccessoryCatalog.get_instance()
	var model: Node3D = PartFit.load_model(path, String(data.get("body", "")), String(data.get("cab", "")))
	for id in ids:
		var e: Dictionary = c.entry(id)
		for side in (["R", "L"] if bool(e.get("mirror_for_left", false)) else ["R"]):
			var n: Node3D = c.attach(model, id, side)
			if n == null:
				print("PROBE %s %s: nao montou" % [id, side])
				continue
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				var m: MeshInstance3D = mi as MeshInstance3D
				var b: AABB = PartFit.rel_xform(m, model) * m.mesh.get_aabb()
				print("PROBE %s %s %s faces=%d aabb=%s" % [id, side, m.name, m.mesh.get_faces().size() / 3, b])
		print("PROBE %s problemas: %s" % [id, PartFit.check_part(model, data, c, id)])
	model.free()
	quit(0)
