extends TestCase
## Pecas novas tiradas dos modelos de terceiros (T-126: Kenworth W990, Fumi SC, JAC 1045): dados da loja, texto pt-BR,
## modelo leve e com credito, encaixe em todos os modelos de caminhao (inclusive o Canter e a cabine curta) e destaque.

const IDS: Array[String] = ["kw_exhaust_stacks", "kw_fuel_tank", "kw_steps", "kw_visor", "kw_bumper", "kw_grille",
		"fumi_wing", "fumi_sport_rims", "jac_steel_rims", "jac_toolbox"]
const TRUCKS: Array = [["base", "padrao"], ["leve", "chata"], ["longo", "curta"], ["canter", "padrao"]]


func test_part_data_and_texts() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for id in IDS:
		var d: PartDef = gs.part(id)
		check(d != null, "PartDef %s existe" % id)
		if d == null:
			continue
		check(d.price > 0 and d.fame > 0 and d.weight_kg > 0.0 and d.durability > 0.0, "%s: preco, destaque, peso e durabilidade" % id)
		check(d.fame_required >= 0 and d.fame_required <= 60, "%s: fama necessaria %d" % [id, d.fame_required])
		check(Tr.t(d.display_key) != d.display_key, "%s: nome em pt-BR" % id)
		check(Tr.t("slot." + String(d.slot)) != "slot." + String(d.slot), "%s: nome do encaixe %s em pt-BR" % [id, d.slot])
		check(String(d.slot) in GameState.SLOT_ORDER, "%s: encaixe %s na ordem da garagem" % [id, d.slot])


func test_models_light_and_credited() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	for id in IDS:
		var e: Dictionary = c.entry(id)
		check(not e.is_empty(), "%s no catalogo" % id)
		if e.is_empty():
			continue
		check(int(e["triangles"]) > 150 and int(e["triangles"]) <= 4500, "%s: %d triangulos" % [id, e["triangles"]])
		check(not String(e["license"]).begins_with("original"), "%s: credito do modelo de terceiros" % id)
		check((e["fit_warnings"] as Array).is_empty(), "%s: sem avisos de encaixe" % id)
		var n: Node3D = c.instantiate(id)
		check(n != null, "%s abre" % id)
		if n != null:
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				var mesh: Mesh = (mi as MeshInstance3D).mesh
				for s in mesh.get_surface_count():
					var mat: Material = mesh.surface_get_material(s)
					check(mat != null and (AccessoryMaterials.DEFS.has(mat.resource_name) or mat.resource_name == "plastic_black"), "%s: material nosso (%s)" % [id, mat.resource_name if mat else "-"])
			n.free()


func test_parts_fit_every_truck_model() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	for tc in TRUCKS:
		var truck: Node3D = (load(TruckNode.model_path(String(tc[0]), String(tc[1]))) as PackedScene).instantiate() as Node3D
		TruckNode.add_extra_mounts(truck, String(tc[0]), String(tc[1]))
		for id in IDS:
			var e: Dictionary = c.entry(id)
			for side in (["R", "L"] if bool(e.get("mirror_for_left", false)) else ["R"]):
				check(c.attach(truck, id, side) != null, "%s monta no %s/%s (%s)" % [id, tc[0], tc[1], side])
		var stack: Node3D = truck.find_child("MOUNT_STACK_R", true, false) as Node3D
		check(stack != null and stack.position.y > 0.6, "%s/%s: ponto dos escapamentos atras da cabine" % tc)
		truck.free()


func test_buying_raises_destaque() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.profile["money"] = 900000
	gs.profile["fame"] = 100
	var before: int = gs.destaque()
	for id in ["kw_exhaust_stacks", "fumi_wing", "kw_visor"]:
		check(gs.buy(gs.part(id)), "compra %s" % id)
		check(gs.install(id), "instala %s" % id)
	check_eq(gs.destaque() - before, 18 + 12 + 16, "destaque sobe com as pecas novas")
	var t := TruckSim.new()
	gs.configure_truck(t)
	check(t.mass > 12000.0 + 90.0 + 35.0, "as pecas pesam na simulacao (%.0f kg)" % t.mass)
	gs.new_profile()
