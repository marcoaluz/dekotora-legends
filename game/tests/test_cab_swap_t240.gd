extends TestCase
## Cabine trocavel (T-240): o kit (cabine + carroceria em .glb separados) monta sem um .glb por combinacao; as malhas de
## mesmo material viram uma so (mesmas chamadas de desenho do .glb unico); a cabine anda com o comprimento do bau; os
## encaixes de todas as combinacoes foram medidos; compra vem com a cabine de fabrica; rivais/bots de homenagem ficam com
## a cabine de fabrica; a garagem oferece todas as cabines; protocolo 20.


func _gs() -> Node:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	return gs


func _meshes(m: Node3D) -> Dictionary:
	var out: Dictionary = {}
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mat: Material = (mi as MeshInstance3D).mesh.surface_get_material(0)
		var key: String = mat.resource_name if mat != null else String(mi.name)
		if not String(mi.name).begins_with("wheel_"):
			out[key] = int(out.get(key, 0)) + 1
	return out


func test_one_mesh_per_material_like_a_single_glb() -> void:
	for body in TruckKit.HOMAGE + TruckKit.OLD_BODIES:
		for cab in CabCatalog.IDS:
			if not TruckKit.uses_kit(body, cab):
				continue
			var m: Node3D = TruckNode.instantiate_model(body, cab)
			for k in _meshes(m):
				check_eq(int(_meshes(m)[k]), 1, "%s_%s: material %s numa malha so" % [body, cab, k])
			m.free()


func test_merged_mesh_is_cached_and_shared() -> void:
	var a: Node3D = TruckNode.instantiate_model("alubox", "chata")
	var b: Node3D = TruckNode.instantiate_model("alubox", "chata")
	var ma: MeshInstance3D = a.find_child("truck_chrome", true, false) as MeshInstance3D
	var mb: MeshInstance3D = b.find_child("truck_chrome", true, false) as MeshInstance3D
	check(ma != null and mb != null and ma.mesh == mb.mesh, "a mesma malha juntada serve todos os caminhoes iguais")
	a.free()
	b.free()


func test_cab_keeps_its_place_and_moves_with_box_length() -> void:
	for body in ["base", "leve", "longo"]:
		var m: Node3D = TruckNode.instantiate_model(body, "flat_wide")
		var w: Node3D = m.find_child("wheel_f_L", true, false) as Node3D
		var want: float = -10.2 - float(TruckNode.LENGTH_DELTA[body])
		check_near(w.position.z, want, 0.02, "%s: roda da frente da cabine nova no eixo do bau (z %.2f)" % [body, want])
		m.free()


func test_all_kit_combos_have_measured_sockets_and_stack_table() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/vehicles/dekotora/truck/stack_fit.json"))
	for body in TruckKit.HOMAGE + TruckKit.OLD_BODIES:
		for cab in CabCatalog.IDS:
			if not TruckKit.uses_kit(body, cab):
				continue
			var path: String = TruckNode.model_path(body, cab)
			var data: Dictionary = TruckSockets.for_model(path)
			check(not data.is_empty(), "%s_%s: encaixes medidos" % [body, cab])
			check((data.get("design_problems", ["?"]) as Array).is_empty(), "%s_%s: sem problemas" % [body, cab])
			check(str(table).contains(path.get_file().get_basename()), "%s_%s: na tabela do deque" % [body, cab])


func test_buy_comes_with_factory_cab_then_swaps() -> void:
	var gs: Node = _gs()
	gs.profile["money"] = 10000000
	gs.profile["fame"] = 100000
	gs.profile["cab"] = "jac"
	check(gs.buy_body("pinkbox"), "compra o baú rosa")
	check_eq(String(gs.profile["cab"]), "flat_wide", "vem com a cabine de fabrica")
	gs.profile["cab"] = "americana"
	check_eq(String(gs.truck_descriptor()["cab"]), "americana", "descritor leva a cabine escolhida")
	check(TruckNode.model_path("pinkbox", "americana").ends_with("dekotora_truck_pinkbox_americana.glb"), "modelo da escolha")
	gs.new_profile()


func test_rivals_and_bots_keep_factory_cab() -> void:
	check_eq(BodyDef.default_cab("pinkbox", "chata"), "flat_wide", "Trovao Rosa: cabine plana larga")
	check_eq(BodyDef.default_cab("dump", "jac"), "flat_quad", "Dragao de Aco: plana de 4 farois")
	check_eq(BodyDef.default_cab("base", "jac"), "jac", "bau antigo: cabine sorteada de sempre")


func test_garage_offers_every_cab_on_homage_and_old_boxes() -> void:
	for body in TruckKit.HOMAGE + TruckKit.OLD_BODIES:
		check_eq(TruckKit.cabs_for(body).size(), CabCatalog.IDS.size(), "%s aceita as %d cabines" % [body, CabCatalog.IDS.size()])
		check(not TruckNode.FIXED_CAB.has(body), "%s sem cabine fixa" % body)
		for cab in CabCatalog.IDS:
			check(TruckNode.model_exists(body, cab), "%s_%s existe" % [body, cab])
	check(TruckNode.FIXED_CAB.has("canter"), "Canter continua com a cabine dele")


func test_protocol_20() -> void:
	check(Protocol.VERSION >= 20, "protocolo 20: cabine trocavel no descritor")
