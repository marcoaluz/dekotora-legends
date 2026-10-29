extends TestCase
## Valida a biblioteca de acessorios 3D: catalogo, arquivos .glb, pontos de montagem e dimensoes.
## Roda em headless depois de `godot --headless --path game --import` (que importa os .glb).

const MAX_DIM: float = 6.0   # nenhuma peca passa de 6 m


func _catalog() -> AccessoryCatalog:
	var c := AccessoryCatalog.new()
	c.reload()
	return c


func test_catalog_loads_and_has_entries() -> void:
	var c := _catalog()
	check(c.ids().size() >= 3, "catalogo tem pelo menos os 3 prototipos (%d)" % c.ids().size())
	check(c.categories().size() == 4, "4 categorias")


func test_every_model_file_loads() -> void:
	var c := _catalog()
	for id in c.ids():
		var e: Dictionary = c.entry(String(id))
		if PaintFit.handles(e):                      # T-232: pintura = textura (sem .glb), conferida em test_paint_t232
			continue
		check(ResourceLoader.exists(String(e["model"])), "arquivo existe: " + String(e["model"]))
		var n: Node3D = c.instantiate(String(id))
		check(n != null, "instancia: " + String(id))
		if n != null:
			var meshes: Array[Node] = n.find_children("*", "MeshInstance3D", true, false)
			check(meshes.size() > 0, "%s tem malhas" % id)
			n.free()


func test_mount_points_exist_on_truck() -> void:
	var c := _catalog()
	var truck: Node3D = (load(TruckNode.MODEL_PATH) as PackedScene).instantiate() as Node3D
	TruckNode.add_extra_mounts(truck, "base", CabCatalog.DEFAULT)          # pontos criados em tempo de execucao (T-126)
	TruckSockets.add_nodes(truck, TruckNode.MODEL_PATH)                  # T-211: encaixes das pecas da oficina
	for id in c.ids():
		var e: Dictionary = c.entry(String(id))
		check(truck.find_child(String(e["mount_point"]), true, false) != null, "%s: ponto %s existe" % [id, e["mount_point"]])
		if bool(e.get("mirror_for_left", false)):
			check(truck.find_child(String(e["mount_point_left"]), true, false) != null, "%s: ponto %s existe" % [id, e["mount_point_left"]])
	truck.free()


func test_dimensions_and_budgets() -> void:
	var c := _catalog()
	for id in c.ids():
		var e: Dictionary = c.entry(String(id))
		if PaintFit.handles(e):                      # T-232: pintura sem volume (retangulo medido por caminhao)
			continue
		var d: Dictionary = e["dimensions_m"]
		for k in ["x", "y", "z"]:
			check(float(d[k]) > 0.0 and float(d[k]) < MAX_DIM, "%s dimensao %s em metros (%.2f)" % [id, k, float(d[k])])
		var budget: int = 6000 if String(e.get("tier", "")) == "deluxe" else 4500      # T-172: deluxe gasta mais
		check(int(e["triangles"]) <= budget, "%s dentro do orcamento de triangulos (%d)" % [id, e["triangles"]])
		check((e["fit_warnings"] as Array).is_empty(), "%s sem avisos de encaixe %s" % [id, e["fit_warnings"]])


func test_attach_and_mirror() -> void:
	var c := _catalog()
	var truck: Node3D = (load(TruckNode.MODEL_PATH) as PackedScene).instantiate() as Node3D
	TruckNode.add_extra_mounts(truck, "base", CabCatalog.DEFAULT)          # pontos criados em tempo de execucao (T-126)
	TruckSockets.add_nodes(truck, TruckNode.MODEL_PATH)                  # T-211: encaixes das pecas da oficina
	for id in c.ids():
		var e: Dictionary = c.entry(String(id))
		var r: Node3D = c.attach(truck, String(id), "R")
		check(r != null, "%s monta no lado R" % id)
		if bool(e.get("mirror_for_left", false)):
			var l: Node3D = c.attach(truck, String(id), "L")
			if PaintFit.handles(e):                  # T-232: o lado esquerdo do mural e outra arte (nunca espelhada)
				check(l != null and l.scale.x > 0.0, "%s: lado L com arte propria, sem espelhar" % id)
			elif String(e.get("fit", "")) == "ladder":   # T-263: escada simetrica, girada para fora de cada lado
				check(l != null and l.transform.basis.z.x * r.transform.basis.z.x < 0.0, "%s virada para o lado L" % id)
			else:
				check(l != null and l.scale.x < 0.0, "%s espelhada no lado L" % id)
	truck.free()


func test_catalog_materials_are_defined() -> void:
	var c := _catalog()
	for id in c.ids():
		var e: Dictionary = c.entry(String(id))
		for slot in e["materials_available"]:
			for mat_name in e["materials_available"][slot]:
				check(AccessoryMaterials.DEFS.has(String(mat_name)), "%s: material %s definido" % [id, mat_name])
