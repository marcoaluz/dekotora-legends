extends SceneTree
## Dev (T-130): perfil da frente e da traseira de cada veiculo (raios contra a malha), para escolher a altura
## das placas (LicensePlate). Imprime, por altura, a distancia da superficie em z (frente = -Z).
## godot --headless --path game -s res://tools_dev/measure_plates.gd   (ONLY=car_ ou ONLY=base_ filtra)


func _profile(root: Node3D, front: bool, y0: float, y1: float, half_w: float) -> String:
	var t0: int = Time.get_ticks_usec()
	var tm: Array = PlateSpot.triangle_meshes(root)
	var out: Array = []
	var y: float = y0
	while y <= y1 + 0.001:
		var hit: float = PlateSpot.surface_z(tm, Vector2(0.0, y), half_w, front)
		out.append("%.2f:%s" % [y, "--" if is_nan(hit) else "%.3f" % hit])
		y += 0.05
	return " ".join(out) + "  (%d ms)" % ((Time.get_ticks_usec() - t0) / 1000)


func _initialize() -> void:
	var only: String = OS.get_environment("ONLY")
	for f in DirAccess.get_files_at("res://assets/vehicles/dekotora/truck/"):
		if not f.ends_with(".glb") or (only != "" and not f.contains(only)):
			continue
		var root := Node3D.new()
		root.add_child((load("res://assets/vehicles/dekotora/truck/" + f) as PackedScene).instantiate())
		print(f, "\n  F ", _profile(root, true, 0.3, 1.3, 0.15), "\n  R ", _profile(root, false, 0.6, 1.3, 0.15))
		root.free()
	for car in Traffic3D.all_models():
		if only != "" and not car.contains(only):
			continue
		var root := Node3D.new()
		root.add_child((load("res://assets/vehicles/traffic/%s.glb" % car) as PackedScene).instantiate())
		print(car, "\n  F ", _profile(root, true, 0.2, 1.1, 0.12), "\n  R ", _profile(root, false, 0.2, 1.1, 0.12))
		root.free()
	quit()
