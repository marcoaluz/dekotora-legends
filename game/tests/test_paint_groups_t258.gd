extends TestCase
## T-258: grupos das pinturas (Pinturas / Wallpapers). Catalogo e saves antigos sem o campo = "pinturas"; a garagem
## filtra o seletor de mural, traseira e teto (Todos / Pinturas / Wallpapers).


func test_group_default_and_values() -> void:
	check_eq(PaintFit.group_of({}), "pinturas", "sem campo = Pinturas")
	check_eq(PaintFit.group_of({"group": "wallpapers"}), "wallpapers", "wallpaper")
	check_eq(PaintFit.group_of({"group": "outra"}), "pinturas", "grupo desconhecido = Pinturas")
	var c := AccessoryCatalog.get_instance()
	for e in c.data.get("accessories", []):
		if PaintFit.handles(e) and String(e.get("socket", "")) != "interior":
			check(PaintFit.group_of(e) in PaintFit.GROUPS, "%s tem grupo" % e["id"])


func test_filter_keeps_order_and_all() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var plist: Array[PartDef] = gs.parts_for_slot("mural")
	check(plist.size() >= 12, "murais na lista")
	check_eq(GarageShop.filter_paints(plist, "all").size(), plist.size(), "Todos = todos")
	check_eq(GarageShop.filter_paints(plist, "pinturas").size() + GarageShop.filter_paints(plist, "wallpapers").size(),
			plist.size(), "Pinturas + Wallpapers = todos")
	var pin: Array[PartDef] = GarageShop.filter_paints(plist, "pinturas")
	check(pin.size() > 0 and pin[0] == plist[0], "ordem mantida")


func test_texts() -> void:
	for k in ["all", "pinturas", "wallpapers", "empty"]:
		check(Tr.t("garage.paint_group." + k) != "garage.paint_group." + k, "texto %s" % k)
