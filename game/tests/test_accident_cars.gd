extends TestCase
## T-143: viatura e carro batido do acidente (modelos leves, giroflex, sem pintura trocavel na viatura) e a cena do
## acidente monta os dois; o jipe entra no transito comum.


func _stats(n: Node) -> Dictionary:
	var tris: int = 0
	var surfaces: int = 0
	var paint: bool = false
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var inst: MeshInstance3D = mi as MeshInstance3D
		var am: ArrayMesh = inst.mesh as ArrayMesh
		for s in inst.mesh.get_surface_count():
			surfaces += 1
			if am != null:
				tris += am.surface_get_array_index_len(s) / 3
			var m: Material = inst.mesh.surface_get_material(s)
			if m != null and m.resource_name == "paint_white":
				paint = true
	return {"tris": tris, "surfaces": surfaces, "paint": paint}


func _load(model: String) -> Node3D:
	var ps: PackedScene = load("%s%s.glb" % [Traffic3D.DIR, model]) as PackedScene
	check(ps != null, model + " carrega")
	return null if ps == null else ps.instantiate() as Node3D


func test_police_car_budget_and_light_bar() -> void:
	var n: Node3D = _load(EventProps.POLICE_MODEL)
	if n == null:
		return
	var st: Dictionary = _stats(n)
	check(int(st["tris"]) >= 3000 and int(st["tris"]) <= 8000, "viatura: triangulos no orcamento (%d)" % int(st["tris"]))
	check(int(st["surfaces"]) <= 4, "viatura: no maximo 4 chamadas (corpo, 2 eixos, giroflex) (%d)" % int(st["surfaces"]))
	check(not st["paint"], "viatura: preto/branco fixo (sem paint_white)")
	check_eq(n.find_children("wheel_*", "Node3D", true, false).size(), 2, "viatura: rodas wheel_f/wheel_r")
	var c: Vector3 = PoliceBeacon.apply(n)
	check(c != Vector3.INF, "viatura: tem a barra de luzes (no beacon)")
	check(c.y > 1.4 and c.y < 2.0, "giroflex no teto (%.2f m)" % c.y)
	check(c.z < -1.0 and c.z > -4.0, "giroflex no meio do carro (z %.2f; frente = -Z)" % c.z)
	var bar: MeshInstance3D = n.find_children("beacon*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	check(bar.material_override is ShaderMaterial, "giroflex animado (shader)")
	n.free()


func test_wreck_budget() -> void:
	var n: Node3D = _load(EventProps.WRECK_MODEL)
	if n == null:
		return
	var st: Dictionary = _stats(n)
	check(int(st["tris"]) >= 3000 and int(st["tris"]) <= 6500, "carro batido: triangulos no orcamento (%d)" % int(st["tris"]))
	check(int(st["surfaces"]) <= 2, "carro batido: pintura + atlas (%d)" % int(st["surfaces"]))
	check(st["paint"], "carro batido: cor trocavel")
	n.free()


func test_accident_scene_has_police_and_wreck() -> void:
	var t := Track.new()
	t.add_section(2000.0, 0.0)
	t.events = TrackEvents.new()
	t.events.add(RaceDemo.parse_event("accident:2-3@900"))
	var path := TrackPath.new(t)
	var b := TrackEvents3D.new()
	b.build(path, TimeOfDay.by_id(&"night"))
	check_eq(int(b.counts.get("police", 0)), 1, "acidente: uma viatura")
	check_eq(int(b.counts.get("wreck", 0)), 1, "acidente: um carro batido")
	check_eq(int(b.counts.get("car", 0)), 2, "acidente: 2 veiculos parados")
	b.free()


func test_jeep_in_regular_traffic() -> void:
	check(Traffic3D.MODELS_BY_KIND[TrafficSim.Kind.CAR].has("car_jeep"), "jipe no transito comum")
	check(not Traffic3D.all_models().has(EventProps.POLICE_MODEL), "viatura so no acidente (nao anda no transito)")
	check(not Traffic3D.all_models().has(EventProps.WRECK_MODEL), "carro batido so no acidente")
