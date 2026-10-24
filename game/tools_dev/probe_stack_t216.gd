extends SceneTree
## Sonda (T-216): problemas de uma dupla empilhada num caminhao.
## Uso: godot --headless --path game -s res://tools_dev/probe_stack_t216.gd -- --model=STEM --lower=ID --upper=ID


func _initialize() -> void:
	var stem: String = "dekotora_truck_base_jac"
	var lo: String = "deck_pods_round"
	var up: String = "deck_led_box"
	for a in OS.get_cmdline_user_args():
		var v: String = a.get_slice("=", 1)
		if a.begins_with("--model="):
			stem = v
		elif a.begins_with("--lower="):
			lo = v
		elif a.begins_with("--upper="):
			up = v
	var c := AccessoryCatalog.new()
	c.reload()
	var data: Dictionary = TruckSockets.for_model(stem + ".glb")
	var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", String(data["body"]), String(data["cab"]))
	print("%s: %s + %s -> %s" % [stem, lo, up, StackFit.problems(model, data, c, lo, up)])
	model.free()
	quit()
