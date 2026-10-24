extends SceneTree
## Sonda (T-214): inclinacao e altura do deque assentado em cada caminhao.


func _initialize() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	var part: String = "deck_led_box"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			part = a.get_slice("=", 1)
	var files: Array = Array(DirAccess.get_files_at(TruckSockets.DIR))
	files.sort()
	for f in files:
		if String(f).ends_with(".surf.json") or not String(f).ends_with(".json"):
			continue
		var stem: String = String(f).get_basename()
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", String(data["body"]), String(data["cab"]))
		var n: Node3D = c.attach(model, part)
		var ang: float = rad_to_deg(atan2(n.transform.basis.z.y, n.transform.basis.z.z))
		print("%-40s pitch %6.2f pos %s probs %s" % [stem, ang, n.position, PartFit.check_part(model, data, c, part)])
		model.free()
	quit()
