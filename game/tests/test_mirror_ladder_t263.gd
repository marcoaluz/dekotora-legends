extends TestCase
## T-263 (pedido do Marco): retrovisor COLADO na lataria (sem vao) em todas as cabines e escada no lugar da referencia
## (capturas 111-113: na FRENTE do bau, atras da cabine, virada para a frente). O teste de todos os caminhoes x pecas
## (com contato) esta em test_parts_t233.gd (PartFit.check_part -> FrameFit.problems -> FrameContact).

const MIRRORS: Array[String] = ["mirror_stay_l", "mirror_stay_truss", "mirror_stay_frame", "mirror_stay_box", "mirror_stay_chain",
	"mirror_stay_grand"]
const LADDERS: Array[String] = ["ladder_neon", "ladder_green", "ladder_chrome"]
const PF := preload("res://tests/test_part_fit.gd")


func _mount(model: Node3D, id: String, side: String) -> Node3D:
	return AccessoryCatalog.get_instance().attach(model, id, side)


func test_every_cab_has_a_measured_pillar() -> void:
	var cabs: Dictionary = {}
	for m in PF.models():
		if m["body"] == "carreta":
			continue
		for side in ["r", "l"]:
			var s: Dictionary = TruckSockets.socket(m["data"], "mirror_stay_" + side)
			check(s.has("pillar") and s.has("pad_y"), "%s: coluna medida (%s)" % [m["stem"], side])
			if s.has("pad_y"):
				check(float(s["pad_y"][1]) - float(s["pad_y"][0]) >= 0.25, "%s: faixa livre da coluna" % m["stem"])
		cabs[m["cab"]] = true
	check(cabs.size() >= 7, "%d cabines conferidas" % cabs.size())


func test_stay_pads_touch_and_detect_gap() -> void:
	for spec in [["base", "chata"], ["base", "jac"], ["base", "curta"], ["base", "americana"], ["canter", "canter"],
			["base", "flat_wide"], ["pinkbox", "flat_quad"]]:
		var path: String = TruckNode.model_path(spec[0], spec[1])
		var data: Dictionary = TruckSockets.for_model(path)
		var model: Node3D = PartFit.load_model(path, spec[0], spec[1])
		var e: Dictionary = AccessoryCatalog.get_instance().entry("mirror_stay_frame")
		for side in ["R", "L"]:
			var n: Node3D = _mount(model, "mirror_stay_frame", side)
			check(n != null, "%s: montou %s" % [path, side])
			if n == null:
				continue
			check_eq((n.get_meta("pads", []) as Array).size(), 2, "%s: 2 chapas de fixacao" % spec[1])
			check(n.find_child("PADS", false, false) != null, "%s: chapas e espacadores montados" % spec[1])
			var probs: Array[String] = FrameContact.problems(model, data, e, n, side)
			check(probs.is_empty(), "%s %s: encostada (%s)" % [spec[1], side, "; ".join(probs)])
			# a mesma haste 4 cm para fora = vao (o teste pega)
			var pads: Array = n.get_meta("pads")
			var moved: Array = []
			var sx: float = 1.0 if side == "R" else -1.0
			for p in pads:
				moved.append({"p": (p["p"] as Vector3) + Vector3(sx * 0.04, 0, 0), "n": p["n"]})
			n.set_meta("pads", moved)
			check(not FrameContact.problems(model, data, e, n, side).is_empty(), "%s: vao de 4 cm e detectado" % spec[1])
			n.get_parent().remove_child(n)
			n.free()
		model.free()


func test_stock_mirror_fully_hidden() -> void:
	for cab in ["chata", "jac", "americana", "flat_wide"]:
		var path: String = TruckNode.model_path("base", cab)
		var data: Dictionary = TruckSockets.for_model(path)
		var model: Node3D = PartFit.load_model(path, "base", cab)
		var all_boxes: Array[AABB] = FrameFit.stock_boxes(data, ["r", "l"])
		var mats: Array[String] = FrameFit.stock_mats(data, ["r", "l"])
		FrameFit.hide_stock(model, all_boxes, mats)
		var left: int = 0
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			if m.mesh == null or not m.has_meta("stock_mesh"):
				continue
			var t: Transform3D = PartFit.rel_xform(m, model)
			var boxes: Array[AABB] = FrameFit.boxes_for(m, all_boxes, mats)
			var f: PackedVector3Array = m.mesh.get_faces()
			for i in range(0, f.size(), 3):
				if FrameFit.tri_hidden(t * f[i], t * f[i + 1], t * f[i + 2], boxes):
					left += 1
		check_eq(left, 0, "%s: nada do espelho de fabrica sobra (nem a raiz do braco)" % cab)
		model.free()


func test_ladder_on_cab_side_behind_door() -> void:
	# correcao do Marco: "as escadas sao do lado da cabine, tipo do lado da porta" (capturas 111-113)
	for spec in [["base", "chata"], ["base", "jac"], ["base", "curta"], ["base", "flat_wide"], ["graneleira", "chata"],
			["alubox", "jac"], ["pinkbox", "flat_quad"], ["leve", "curta"]]:
		var path: String = TruckNode.model_path(spec[0], spec[1])
		var data: Dictionary = TruckSockets.for_model(path)
		var cab: Dictionary = data["measure"]["cab"]
		var door: Array = cab["door"]["z"]
		var model: Node3D = PartFit.load_model(path, spec[0], spec[1])
		for id in LADDERS:
			var e: Dictionary = AccessoryCatalog.get_instance().entry(id)
			for side in ["R", "L"]:
				var n: Node3D = _mount(model, id, side)
				check(n != null, "%s %s: montou" % [id, path])
				if n == null:
					continue
				var box: AABB = PartFit.aabb_in(n, model)
				var sx: float = 1.0 if side == "R" else -1.0
				check(box.position.z > float(door[1]), "%s %s: atras da porta (nao a cobre)" % [id, spec])
				check(box.end.z < float(data["measure"]["box"]["front_z"]) if data["measure"].has("box") else true,
						"%s %s: na cabine, antes da carga" % [id, spec])
				check(absf(box.get_center().x) > float(cab["half_w"]) - 0.15 and box.get_center().x * sx > 0.0,
						"%s %s %s: na lateral certa, por fora" % [id, spec, side])
				check(box.end.y >= float(cab["roof_shell_y"]) - 0.45, "%s %s: sobe ate o teto" % [id, spec])
				check(FrameContact.problems(model, data, e, n, side).is_empty(), "%s %s %s: encostada" % [id, spec, side])
				var moved: Array = []                              # 4 cm para fora = solta (o teste pega)
				for c in n.get_meta("contacts", []):
					moved.append({"p": (c["p"] as Vector3) + Vector3(sx * 0.04, 0, 0), "n": c["n"]})
				n.set_meta("contacts", moved)
				check(not FrameContact.problems(model, data, e, n, side).is_empty(), "%s %s: vao detectado" % [id, spec])
				n.get_parent().remove_child(n)
				n.free()
		model.free()


func test_ladder_passes_roof_with_led_box_and_step() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for cab in ["chata", "curta"]:
		var t := TruckNode.new()
		t.cab_kind = cab
		t._ready()
		t.apply_loadout([gs.part("ladder_green")] as Array[PartDef])
		var data: Dictionary = TruckSockets.for_model(TruckNode.model_path(t.body_kind, cab))
		var roof: float = float(data["measure"]["cab"]["roof_shell_y"])
		for n in t._acc_nodes["ladder_green"]:
			var box: AABB = PartFit.aabb_in(n as Node3D, t.model)
			check(box.end.y > roof + 0.2, "%s: escada passa do teto com a caixa de LED (topo %.2f, teto %.2f)" % [cab, box.end.y, roof])
			var led: int = 0
			for mi in (n as Node3D).find_children("*", "MeshInstance3D", true, false):
				var m: MeshInstance3D = mi as MeshInstance3D
				for k in m.mesh.get_surface_count():
					var sm: Material = m.mesh.surface_get_material(k)
					if sm != null and sm.resource_name == "deco_led":
						led += 1
			check(led > 0, "%s: caixa com LED (cor de luz separada)" % cab)
		t.free()
