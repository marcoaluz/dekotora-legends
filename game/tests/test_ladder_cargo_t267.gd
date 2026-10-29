extends TestCase
## T-267 (decisao do Marco na T-263, opcao b): na cabine americana e no Canter a porta vai ate o fim da cabine, entao a
## escada vai na LATERAL DA CARGA, logo atras da quina da frente (bau ou carroceria), virada para fora, com a caixa de
## LED passando ~10 cm da borda de cima. Regras de sempre: encaixe medido por raios, nada de cruzar deque, viseira ou
## luz de marcacao, zonas protegidas, espacadores encostados (FrameContact).

const LADDERS: Array[String] = ["ladder_neon", "ladder_green", "ladder_chrome"]
const NO_PLACE: Array[String] = ["dekotora_truck_tanker_americana"]       # lateral do tanque e curva
const REACH: float = 0.75                                                  # = truck_measure.CARGO_REACH + folga
const PF := preload("res://tests/test_part_fit.gd")


static func cargo_models() -> Array:
	var out: Array = []
	for m in PF.models():
		if String(m["cab"]) in ["americana", "canter"] and m["body"] != "carreta":
			out.append(m)
	return out


func _lamp_hits(model: Node3D, box: AABB, s: Dictionary, sx: float) -> int:
	# vertices de luz de fabrica (lanternas, luzes de marcacao) atras dos trilhos da escada (largura medida `width`, da
	# base ate a caixa de LED): a escada nao pode cobri-los
	var hw: float = float(s["width"]) * 0.5
	var zc: float = float(s["anchor"][2])
	var foot := AABB(Vector3(box.position.x - 0.12 if sx > 0.0 else box.position.x, box.position.y, zc - hw),
			Vector3(box.size.x + 0.12, box.size.y, 2.0 * hw))
	var n: int = 0
	for mi in model.find_children("*lamp*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or FrameFit._in_part(m, model):
			continue
		var t: Transform3D = PartFit.rel_xform(m, model)
		for v in m.mesh.get_faces():
			if foot.has_point(t * v):
				n += 1
	return n


func test_cargo_ladder_sockets() -> void:
	var with_place: int = 0
	for m in cargo_models():
		for side in ["r", "l"]:
			var s: Dictionary = TruckSockets.socket(m["data"], "ladder_" + side)
			if String(m["stem"]) in NO_PLACE:
				check(s.is_empty(), "%s: sem escada (lateral curva)" % m["stem"])
				continue
			check(not s.is_empty() and String(s.get("on", "")) == "cargo", "%s %s: escada na carga" % [m["stem"], side])
			check(s.has("sp_free") and not (s["sp_free"] as Array).is_empty(), "%s: faixas dos espacadores" % m["stem"])
			with_place += 1
		check(PartFit.design_problems(m["data"]).is_empty(), "%s: encaixes nao se cruzam (deque, viseira, contorno)" % m["stem"])
	check(with_place >= 18, "%d lados com escada na carga" % with_place)


func test_ladder_at_cargo_front_corner() -> void:
	var c := AccessoryCatalog.get_instance()
	for m in cargo_models():
		if String(m["stem"]) in NO_PLACE:
			continue
		var data: Dictionary = m["data"]
		var mb: Dictionary = data["measure"]["box"]
		var cab: Dictionary = data["measure"]["cab"]
		var model: Node3D = PartFit.load_model(m["path"], m["body"], m["cab"])
		for id in LADDERS:
			var e: Dictionary = c.entry(id)
			for side in ["R", "L"]:
				var n: Node3D = c.attach(model, id, side)
				check(n != null, "%s %s: montou" % [id, m["stem"]])
				if n == null:
					continue
				var s: Dictionary = TruckSockets.socket(data, "ladder_" + side.to_lower())
				var box: AABB = PartFit.aabb_in(n, model)
				var sx: float = 1.0 if side == "R" else -1.0
				var tag: String = "%s %s %s" % [id, m["stem"], side]
				check(box.position.z > float(cab["door"]["z"][1]) and box.position.z > float(cab["roof_back_z"]),
						"%s: atras da porta e da cabine" % tag)
				check(box.position.z >= float(mb["front_z"]) - 0.15 and box.end.z <= float(mb["front_z"]) + REACH,
						"%s: na quina da frente da carga (z %.2f..%.2f, frente %.2f)" % [tag, box.position.z, box.end.z, mb["front_z"]])
				check(box.get_center().x * sx > float(mb["half_w"]) - 0.05, "%s: por fora da lateral certa" % tag)
				var rails: float = float(s["anchor"][1]) + float(s["height"])
				check(box.end.y > rails + 0.1, "%s: caixa de LED acima da borda (topo %.2f)" % [tag, box.end.y])
				check_eq(_lamp_hits(model, box, s, sx), 0, "%s: nao cobre luz de marcacao" % tag)
				var probs: Array[String] = FrameFit.problems(model, data, e, n, side)
				check(probs.is_empty(), "%s: %s" % [tag, "; ".join(probs)])
				var moved: Array = []                                 # 4 cm para fora = solta (o teste pega)
				for ct in n.get_meta("contacts", []):
					moved.append({"p": (ct["p"] as Vector3) + Vector3(sx * 0.04, 0, 0), "n": ct["n"]})
				n.set_meta("contacts", moved)
				check(not FrameContact.problems(model, data, e, n, side).is_empty(), "%s: vao detectado" % tag)
				n.get_parent().remove_child(n)
				n.free()
		model.free()


func test_truck_node_mounts_cargo_ladder_with_led() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for spec in [["base", "americana"], ["canter", "canter"], ["alubox", "americana"]]:
		var t := TruckNode.new()
		t.body_kind = spec[0]
		t.cab_kind = spec[1]
		t._ready()
		t.apply_loadout([gs.part("ladder_chrome")] as Array[PartDef])
		var nodes: Array = t._acc_nodes.get("ladder_chrome", [])
		check_eq(nodes.size(), 2, "%s: escada nos 2 lados" % [spec])
		for nd in nodes:
			var led: int = 0
			for mi in (nd as Node3D).find_children("*", "MeshInstance3D", true, false):
				var mm: MeshInstance3D = mi as MeshInstance3D
				for k in mm.mesh.get_surface_count():
					var sm: Material = mm.mesh.surface_get_material(k)
					if sm != null and sm.resource_name == "deco_led":
						led += 1
			check(led > 0, "%s: caixa com LED (cor de luz separada)" % [spec])
		t.set_lights_on(true)
		t.free()
