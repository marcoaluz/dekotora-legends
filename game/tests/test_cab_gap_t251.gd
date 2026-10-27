extends TestCase
## T-251: em todas as combinacoes do kit a carga encosta na cabine (folga pequena, escapamentos no vao); o chassi nao
## estica; o comprimento na simulacao nao muda. T-252: foguete ate 1,65 (e mais largo), andon da frente do teto na altura
## certa no leve/longo, sem luzinhas soltas na frente da cabine americana.


func _combos() -> Array:
	var out: Array = []
	for body in TruckKit.HOMAGE + TruckKit.OLD_BODIES:
		for cab in CabCatalog.IDS:
			if TruckKit.uses_kit(body, cab):
				out.append([body, cab])
	return out


func _max_y(m: Node3D, pred: Callable) -> float:
	var hi: float = -INF
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		if pred.call(mi):
			for v in ((mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				hi = maxf(hi, ((mi as MeshInstance3D).transform * v).y)
	return hi


func test_cargo_touches_the_cab_in_every_combo() -> void:
	for c in _combos():
		var g: float = TruckKit.gap(c[0], c[1])
		check(g >= 0.03 and g <= 0.27, "%s_%s: folga cabine-carga %.2f m (0,03 a 0,27)" % [c[0], c[1], g])
		var data: Dictionary = TruckSockets.for_model(TruckNode.model_path(c[0], c[1]))
		var front: float = -float(data["measure"]["box"]["front_z"])
		var back: float = float(TruckKit.meta("cab_" + c[1])["back"]) + float(TruckNode.LENGTH_DELTA.get(c[0], 0.0))
		if c[0] in TruckKit.HOMAGE and c[0] != "dump":           # cacamba: a parede fica atras do protetor
			check(back - front <= 0.30, "%s_%s: frente medida do bau %.2f, costas %.2f" % [c[0], c[1], front, back])
		check((data.get("design_problems", ["?"]) as Array).is_empty(), "%s_%s: encaixes sem problema" % [c[0], c[1]])


func test_stretch_keeps_wheels_and_sim_length() -> void:
	var a: Node3D = TruckNode.instantiate_model("tanker", "flat_wide")
	var b: Node3D = TruckNode.instantiate_model("tanker", "curta")
	for w in ["wheel_r_L_1.5_1.06", "wheel_r_L_3.0_1.06", "wheel_f_L"]:
		var wa: Node3D = a.find_child(w.replace(".", "_"), true, false) as Node3D
		var wb: Node3D = b.find_child(w.replace(".", "_"), true, false) as Node3D
		if wa == null:
			wa = a.find_child(w, true, false) as Node3D
			wb = b.find_child(w, true, false) as Node3D
		check(wa != null and wb != null and absf(wa.position.z - wb.position.z) < 0.01, "%s no mesmo lugar" % w)
	check(TruckKit.stretch("tanker", "curta") > 1.0, "tanque estica ~1,3 m com a cabine curta")
	check_eq(BodyDef.find("tanker").length_m, 12.0, "comprimento na simulacao nao mudou")
	a.free()
	b.free()


func test_stacks_follow_the_cab() -> void:
	var em: Dictionary = TruckNode.extra_mounts("pinkbox", "jac")
	var back: float = float(TruckKit.meta("cab_jac")["back"])
	var y: float = (em["MOUNT_STACK_R"][0] as Vector3).y
	check(y < back - 0.1 and y > back - 0.3, "escapamento comprado no vao atras da JAC (y %.2f, costas %.2f)" % [y, back])


func test_rocket_bigger_t252() -> void:
	var e: Dictionary = AccessoryCatalog.get_instance().entry("rocket_round")
	check_near(float(e.get("max_scale", 0.0)), 1.65, 0.001, "foguete cresce ate 1,65")
	check(float(e.get("wide_k", 1.0)) > 1.0, "foguete um pouco mais largo")


func test_leve_longo_front_andon_height_t252() -> void:
	for body in ["leve", "longo"]:
		for cab in ["chata", "americana", "flat_wide"]:
			var m: Node3D = TruckNode.instantiate_model(body, cab)
			var hi: float = _max_y(m, func(mi: Node) -> bool: return String(mi.name).contains("andon_panel"))
			check(hi < 4.3, "%s_%s: andon da frente ate %.2f m (antes ~7 m)" % [body, cab, hi])
			m.free()


func test_americana_brow_lamps_on_the_cab_t252() -> void:
	for body in ["base", "pinkbox"]:
		var m: Node3D = TruckNode.instantiate_model(body, "americana")
		var front: float = INF
		for mi in m.find_children("*paint_white_panel*", "MeshInstance3D", true, false):
			for v in ((mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				front = minf(front, ((mi as MeshInstance3D).transform * v).z)
		var loose: int = 0
		for mi in m.find_children("*lamp_*", "MeshInstance3D", true, false):
			for v in ((mi as MeshInstance3D).mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				var p: Vector3 = (mi as MeshInstance3D).transform * v
				if p.z < front - 0.05 and p.y > 1.8:
					loose += 1
		check_eq(loose, 0, "%s_americana: nenhuma luzinha alta na frente do capo" % body)
		m.free()
