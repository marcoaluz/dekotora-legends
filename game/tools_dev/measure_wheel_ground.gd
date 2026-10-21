extends SceneTree
## T-171: mede, em cada .glb de caminhao, o ponto mais baixo dos pneus (deveria ser ~0 = chao) e o topo da
## plataforma giratoria do galpao da garagem.
## godot --headless --path game -s res://tools_dev/measure_wheel_ground.gd


func _init() -> void:
	var dir: String = TruckNode.MODEL_DIR
	var names: PackedStringArray = DirAccess.get_files_at(dir)
	for f in names:
		if not f.ends_with(".glb"):
			continue
		var sc: PackedScene = load(dir + f) as PackedScene
		if sc == null:
			continue
		var m: Node3D = sc.instantiate() as Node3D
		var wheels: Array = m.find_children("wheel_*", "MeshInstance3D", true, false)
		print("%-42s rodas %2d  pneu mais baixo %+.3f m" % [f, wheels.size(), TruckGround.wheel_bottom(m)])
		m.free()
	var hall: PackedScene = load(GarageStage.HALL_PATH) as PackedScene
	if hall != null:
		var h: Node3D = hall.instantiate() as Node3D
		for part in ["turntable", "floor"]:
			print("galpao: topo de '%s' = %+.3f m" % [part, TruckGround.top_of(h, part)])
		for mi in h.find_children("*", "MeshInstance3D", true, false):
			var box: AABB = TruckGround.xform_to(h, mi) * (mi as MeshInstance3D).mesh.get_aabb()
			if box.position.y < 0.4 and box.size.x > 3.0:
				print("   %-24s y %.3f .. %.3f  x %.1f z %.1f" % [mi.name, box.position.y, box.end.y, box.get_center().x, box.get_center().z])
		h.free()
	quit()
