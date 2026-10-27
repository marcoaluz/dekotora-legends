extends SceneTree
## Sonda da T-233: lista os nos de uma peca (.glb) e onde ficam (sem tela).
## Uso: godot --headless --path game -s res://tools_dev/probe_t233.gd -- --part=fb_fan_plate


func _initialize() -> void:
	var id: String = "fb_fan_plate"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--part="):
			id = a.get_slice("=", 1)
	var n: Node3D = AccessoryCatalog.get_instance().instantiate(id)
	_dump(n, 0)
	n.free()
	quit(0)


func _dump(n: Node, d: int) -> void:
	var extra: String = ""
	if n is Node3D:
		extra = str((n as Node3D).transform)
	print("PROBE ", "  ".repeat(d), n.name, " (", n.get_class(), ") ", extra)
	for c in n.get_children():
		_dump(c, d + 1)
