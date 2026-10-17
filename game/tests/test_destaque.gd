extends TestCase
## Nota de destaque (ATB-2): pecas + escape + pintura + adesivos; vale na corrida e no resultado.


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func test_paint_and_decal_points() -> void:
	check_eq(StyleCatalog.paint_points("#e9eef5"), 0, "pintura de fabrica nao soma")
	check_eq(StyleCatalog.paint_points("#F0B83A"), 14, "dourado soma 14 (sem diferenciar maiuscula)")
	check(StyleCatalog.paint_points("#123456") > 0, "cor fora da lista soma um valor padrao")
	check_eq(StyleCatalog.decal_points([{}, {}]), 2 * StyleCatalog.DECAL_POINTS, "cada adesivo soma")
	check_eq(StyleCatalog.decal_points([{}, {}, {}, {}, {}, {}]), StyleCatalog.MAX_DECALS * StyleCatalog.DECAL_POINTS, "teto de adesivos")


func test_destaque_sums_parts_paint_and_decals() -> void:
	var gs: Node = _gs()
	gs.new_profile()
	var base: int = gs.destaque()
	gs.profile["paint"] = "#f0b83a"
	check_eq(gs.destaque(), base + 14, "pintura dourada +14")
	gs.profile["decals"] = [{"id": "estrela", "slot": "side_l"}, {"id": "raio", "slot": "rear"}]
	check_eq(gs.destaque(), base + 14 + 2 * StyleCatalog.DECAL_POINTS, "adesivos somam")
	check_eq(gs.total_fame_rating(), gs.destaque(), "nome antigo continua valendo")
	var pv: Dictionary = gs.preview({"paint": "#2b2f3a", "decals": []})
	check_eq(int(pv["rating"]), base + 3, "a previa ao vivo troca pintura e adesivos sem alterar o perfil")
	check_eq(String(gs.profile["paint"]), "#f0b83a", "o perfil continua igual depois da previa")
	gs.new_profile()


func test_destaque_reaches_the_race_and_the_result() -> void:
	var gs: Node = _gs()
	gs.new_profile()
	gs.profile["paint"] = "#ff2e88"
	gs.profile["decals"] = [{"id": "estrela", "slot": "cab"}]
	var t := TruckSim.new()
	gs.configure_truck(t)
	check_eq(t.style_points, 9 + StyleCatalog.DECAL_POINTS, "a simulacao recebe os pontos de estilo")
	check_near(RaceRules.intact_fame(t), float(gs.destaque()) - 0.0, 0.01, "destaque da corrida = destaque da garagem (pecas inteiras)")
	var res: Dictionary = RaceRules.build_result(t, 1, 10000, 50.0, 0.0)
	check_eq(int(res["destaque"]), gs.destaque(), "resultado mostra o destaque")
	gs.new_profile()
