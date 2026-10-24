extends SceneTree
## Sonda do assento (T-214): monta uma peca num caminhao e imprime transformacao, caixa e problemas.
## Uso: godot --headless --path game -s res://tools_dev/probe_seat_t214.gd -- --model=dekotora_truck_base_americana --part=deck_led_box


func _initialize() -> void:
	var stem: String = "dekotora_truck_base_americana"
	var part: String = "deck_led_box"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="):
			stem = a.get_slice("=", 1)
		elif a.begins_with("--part="):
			part = a.get_slice("=", 1)
	var data: Dictionary = TruckSockets.for_model(stem + ".glb")
	var model: Node3D = PartFit.load_model(TruckNode.MODEL_DIR + stem + ".glb", String(data["body"]), String(data["cab"]))
	var c := AccessoryCatalog.new()
	c.reload()
	var n: Node3D = c.attach(model, part)
	print("socket ", TruckSockets.socket(data, String(c.entry(part)["socket"])))
	print("node xf ", n.transform, " scale ", TruckSockets.fit_scale(data, c.entry(part)))
	print("box ", PartFit.aabb_in(n, model))
	for ch in n.get_children():
		if ch is Node3D:
			print("  child ", ch.name, " ", PartFit.aabb_in(ch, model) if not (ch is MeshInstance3D) else (PartFit.rel_xform(ch, model) * (ch as MeshInstance3D).mesh.get_aabb()))
	dump_skirt(n)
	dump_pods(n, model, data)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--corner="):
			var cc: PackedStringArray = a.get_slice("=", 1).split(",")
			dump_corner(n, model, float(cc[0]), float(cc[1]))
	print("probs ", PartFit.part_problems(data, c.entry(part), PartFit.aabb_in(n, model)))
	print("seat ", PartFitSeat.problems(model, stem, c.entry(part), n))
	model.free()
	quit()


static func dump_skirt(n: Node3D) -> void:
	var sk: MeshInstance3D = n.find_child("SEAT_skirt", true, false) as MeshInstance3D
	if sk == null:
		return
	var f: PackedVector3Array = sk.mesh.get_faces()
	var mx := Vector3(-INF, -INF, -INF)
	var arg := Vector3.ZERO
	for v in f:
		if v.z > mx.z:
			mx = v
	print("skirt max local z vert ", mx, " world ", n.transform * mx)


static func dump_corner(n: Node3D, model: Node3D, cx: float, cz: float) -> void:
	var sk: MeshInstance3D = n.find_child("SEAT_skirt", true, false) as MeshInstance3D
	var t: Transform3D = PartFit.rel_xform(sk, model)
	var f: PackedVector3Array = sk.mesh.get_faces()
	var seen: Dictionary = {}
	for v in f:
		var w: Vector3 = t * v
		if absf(w.x - cx) < 0.08 and absf(w.z - cz) < 0.08:
			seen["%.3f %.3f %.3f" % [w.x, w.y, w.z]] = true
	print("skirt verts near corner: ", seen.keys())
	var tm: TriangleMesh = PartFitSeat.truck_mesh(model, "probe")
	for dz in [-0.04, -0.02, 0.0, 0.02]:
		var r: Dictionary = tm.intersect_ray(Vector3(cx, 5.0, cz + dz), Vector3.DOWN)
		print("  roof at z=%.3f: %s" % [cz + dz, r.get("position", "none")])


static func dump_pods(n: Node3D, model: Node3D, data: Dictionary) -> void:
	var surf: Dictionary = SocketSeat.surfaces(data)
	var tm: TriangleMesh = PartFitSeat.truck_mesh(model, "probe")
	for c in n.find_children("*POD*", "Node3D", true, false):
		var pod: Node3D = c as Node3D
		var box: AABB = PartFit.rel_xform(pod, model) * (pod as MeshInstance3D).mesh.get_aabb() if pod is MeshInstance3D else AABB()
		var cx: float = box.get_center().x
		var line: String = "%s pos %s bottom %.3f |" % [pod.name, pod.position, box.position.y]
		for fx in [0.3, 0.5, 0.7]:
			var x: float = lerpf(box.position.x, box.end.x, fx)
			var z: float = box.get_center().z
			var r: Dictionary = tm.intersect_ray(Vector3(x, 5.0, z), Vector3.DOWN)
			var mesh_y: float = (r["position"] as Vector3).y if not r.is_empty() else -99.0
			line += " x%.2f mesh %.3f grid %.3f pure %.3f" % [x, mesh_y, SocketSeat.roof_h(surf, x, z), SocketSeat.roof_h_pure(surf, x, z)]
		print(line)
