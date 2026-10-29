extends SceneTree
## Sonda da T-263: monta uma haste/escada e imprime onde ficou (caixa no modelo, chapas, ponto do encaixe).
## godot --headless --path game -s res://tools_dev/probe_t263.gd -- --body=base --cab=chata --part=mirror_stay_l [--side=L]


func _initialize() -> void:
	var body: String = "base"
	var cab: String = "chata"
	var part: String = "mirror_stay_l"
	var side: String = "L"
	for a in OS.get_cmdline_user_args():
		var v: String = a.get_slice("=", 1)
		if a.begins_with("--body="):
			body = v
		elif a.begins_with("--cab="):
			cab = v
		elif a.begins_with("--part="):
			part = v
		elif a.begins_with("--side="):
			side = v
	var path: String = TruckNode.model_path(body, cab)
	var data: Dictionary = TruckSockets.for_model(path)
	var model: Node3D = PartFit.load_model(path, body, cab)
	var n: Node3D = AccessoryCatalog.get_instance().attach(model, part, side)
	var e: Dictionary = AccessoryCatalog.get_instance().entry(part)
	print("socket ", (n.get_parent() as Node3D).position, " node pos ", n.position, " scale ", n.scale)
	print("aabb ", PartFit.aabb_in(n, model))
	for m in StripFit._meshes(n):
		print("  ", m.name, " ", PartFit.rel_xform(m, model) * m.mesh.get_aabb())
	for p in n.get_meta("pads", []):
		print("  pad ", p)
	print("problemas ", FrameFit.problems(model, data, e, n, side))
	model.free()
	quit()
