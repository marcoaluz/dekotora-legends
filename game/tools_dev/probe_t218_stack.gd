extends SceneTree
## Probe T-218: why stacked deck pairs fail on a truck (prints the problems of each failing pair).
func _initialize() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	var stem: String = "dekotora_truck_alubox"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--stem="):
			stem = a.substr(7)
	var data: Dictionary = TruckSockets.for_model(stem + ".glb")
	var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", String(data["body"]), String(data["cab"]))
	var n: int = 0
	for pr in StackFit.shape_pairs(c):
		var p: Array = StackFit.problems(model, data, c, pr[0], pr[1])
		if not p.is_empty() and n < 12:
			print(pr, " -> ", p)
			n += 1
	print("andon: ", data["sockets"]["andon"])
	model.free()
	quit()
