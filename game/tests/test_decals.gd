extends TestCase
## Adesivos em PNG (ATB-2): catalogo (6 provisorios + pasta do Marco), colocacao no caminhao, destaque e calotas novas.


func _truck() -> TruckNode:
	var t := TruckNode.new()
	t._ready()
	return t


func test_catalog_has_the_six_placeholder_decals() -> void:
	var ids: Array[String] = DecalCatalog.ids()
	for id in ["kanji_bakusou", "kanji_tamashii", "ondas", "raio", "estrela", "sol"]:
		check(ids.has(id), "adesivo provisorio " + id)
		check(DecalCatalog.texture(id) != null, "textura carrega: " + id)
	check(DecalCatalog.texture("nao_existe") == null, "adesivo inexistente = null")
	check(FileAccess.file_exists("res://assets/decals/LEIA-ME.md"), "a pasta tem o guia para arte propria")


func test_placer_creates_quads_in_the_right_places() -> void:
	var t := _truck()
	check_eq(t._decal_nodes.size(), 0, "sem adesivos no comeco")
	t.apply_decals([
		DecalCatalog.make("estrela", "side_l"), DecalCatalog.make("raio", "side_r"),
		DecalCatalog.make("sol", "rear"), DecalCatalog.make("ondas", "cab")])
	check_eq(t._decal_nodes.size(), 5, "4 adesivos = 5 quads (a cabine leva as duas portas)")
	var left: Node3D = t._decal_nodes[0]
	var right: Node3D = t._decal_nodes[1]
	var rear: Node3D = t._decal_nodes[2]
	check(left.position.x < -1.2 and right.position.x > 1.2, "laterais ficam dos dois lados do bau (%.2f / %.2f)" % [left.position.x, right.position.x])
	check_near(rear.position.z, DecalPlacer.REAR_Z + DecalPlacer.LIFT, 0.001, "traseira na face de tras do bau")
	check(t._decal_nodes[3].position.z < -8.0, "a cabine fica na frente do caminhao (z=%.2f)" % t._decal_nodes[3].position.z)
	t.apply_decals([])
	check_eq(t._decal_nodes.size(), 0, "limpar remove tudo")
	t.free()


func test_decal_position_size_and_color_change_the_quad() -> void:
	var t := _truck()
	var d: Dictionary = DecalCatalog.make("estrela", "side_r")
	t.apply_decals([d])
	var z0: float = (t._decal_nodes[0] as Node3D).position.z
	var h0: float = ((t._decal_nodes[0] as MeshInstance3D).mesh as QuadMesh).size.y
	d["x"] = 0.8
	d["size"] = 0.9
	d["color"] = "#ff2e88"
	t.apply_decals([d])
	var q: MeshInstance3D = t._decal_nodes[0] as MeshInstance3D
	check(q.position.z < z0, "x maior = mais perto da frente")
	check((q.mesh as QuadMesh).size.y > h0, "tamanho maior = quad maior")
	check(((q.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.is_equal_approx(Color("#ff2e88")), "cor aplicada")
	t.free()


func test_decals_add_destaque_and_survive_preview() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	var base: int = gs.destaque()
	gs.profile["decals"] = [DecalCatalog.make("raio", "rear")]
	check_eq(gs.destaque(), base + StyleCatalog.DECAL_POINTS, "adesivo soma destaque")
	check_eq(DecalCatalog.find(gs.profile["decals"], "rear"), 0, "find acha o adesivo do lugar")
	check_eq(DecalCatalog.find(gs.profile["decals"], "cab"), -1, "e nao acha onde nao tem")
	gs.new_profile()
	check_eq((gs.profile["decals"] as Array).size(), 0, "perfil novo comeca sem adesivos")


func test_new_hubcaps_are_in_the_deco_tab() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var ids: Array[String] = []
	for d in gs.parts_for_slot("hubcaps"):
		ids.append(String(d.id))
	for id in ["hub_chrome", "hub_steel_cyan", "hub_chrome_pink", "hub_gold"]:
		check(ids.has(id), "calota " + id)
		check(Tr.t("part." + id) != "part." + id, "traducao da calota " + id)
