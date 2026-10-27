extends SceneTree
## T-240: sonda sem tela da cabine trocavel. Monta cada combinacao do kit e imprime malhas, nos da cabine sem par,
## rodas, pontos de montagem e o tempo de montagem.
##   godot --headless --path game -s res://tools_dev/probe_t240.gd -- [--body=alubox] [--cab=chata]


func _initialize() -> void:
	var body_f: String = ""
	var cab_f: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--body="):
			body_f = a.substr(7)
		elif a.begins_with("--cab="):
			cab_f = a.substr(6)
	for body in TruckKit.HOMAGE + TruckKit.OLD_BODIES:
		if body_f != "" and body != body_f:
			continue
		for cab in CabCatalog.IDS:
			if (cab_f != "" and cab != cab_f) or not TruckKit.uses_kit(body, cab):
				continue
			var t0: int = Time.get_ticks_usec()
			var m: Node3D = TruckNode.instantiate_model(body, cab)
			var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			if m == null:
				print("T240 %s_%s FALTA" % [body, cab])
				continue
			var meshes: int = m.find_children("*", "MeshInstance3D", true, false).size()
			var solo: Array[String] = []
			for n in TruckKit.cab_only_nodes(m):
				if n is MeshInstance3D and not String(n.name).begins_with("wheel_"):
					solo.append(String(n.name))
			var wheels: int = m.find_children("wheel_*", "Node3D", true, false).size()
			var mounts: int = m.find_children("MOUNT_*", "Node3D", true, false).size()
			print("T240 %s_%s malhas=%d rodas=%d mounts=%d %.0fms so_cabine=%s" % [body, cab, meshes, wheels, mounts, ms, solo])
			m.free()
	quit()
