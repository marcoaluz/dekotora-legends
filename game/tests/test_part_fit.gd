extends TestCase
## Encaixe das pecas da oficina (T-211) em TODAS as combinacoes cabine x bau (+ Canter): caixas-limite que nao se
## cruzam, zonas protegidas livres (decisao 12 do Marco: tudo instalado junto, nada cobre farol, lanterna, seta,
## placa, para-brisa, porta ou roda), deque e viseira dentro da caixa e fora da lataria, escala 0,85-1,15, dano sem
## buraco, cor L/R com preco e letreiro de lista. A carreta (guardada) so entra no relatorio, nao reprova aqui.
## Relatorio legivel: godot --headless --path game -s res://tools_dev/report_part_fit.gd  (-> docs/REPORT_ENCAIXE.md)

const SLOTS: Array = ["andon", "visor"]
const N_DECK: int = 17
const N_VISOR: int = 14


static func models() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files: Array = Array(DirAccess.get_files_at(TruckSockets.DIR))
	files.sort()
	for f in files:
		if not String(f).ends_with(".json") or String(f).ends_with(".surf.json"):
			continue
		var stem: String = String(f).get_basename()
		var data: Dictionary = TruckSockets.for_model(stem + ".glb")
		out.append({"stem": stem, "data": data, "path": TruckNode.MODEL_DIR + stem + ".glb",
				"body": String(data.get("body", "")), "cab": String(data.get("cab", ""))})
	return out


func test_every_model_has_sockets() -> void:
	var stems: Array = models().map(func(m: Dictionary) -> String: return String(m["stem"]))
	for body in ["base", "leve", "longo", "graneleira"]:
		for cab in CabCatalog.IDS:
			check("dekotora_truck_%s_%s" % [body, cab] in stems, "encaixes de %s/%s" % [body, cab])
	check("dekotora_truck_canter" in stems, "encaixes do Canter")


func test_socket_boxes_never_cross() -> void:
	for m in models():
		if m["body"] == "carreta":
			continue
		var probs: Array[String] = PartFit.design_problems(m["data"])
		check(probs.is_empty(), "%s: %s" % [m["stem"], "; ".join(probs)])
		for slot in SLOTS:
			check(TruckSockets.socket(m["data"], slot).has("anchor"), "%s: encaixe %s com ponto" % [m["stem"], slot])


func test_deck_and_visor_fit_every_cab_and_body() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	var ids: Array[String] = PartFit.socket_parts(c, SLOTS)
	check_eq(ids.size(), N_DECK + N_VISOR, "31 pecas do lote 1 no catalogo")
	var checked: int = 0
	for m in models():
		if m["body"] == "carreta":
			continue
		var model: Node3D = PartFit.load_model(m["path"], m["body"], m["cab"])
		for id in ids:
			var probs: Array[String] = PartFit.check_part(model, m["data"], c, id)
			check(probs.is_empty(), "%s em %s: %s" % [id, m["stem"], "; ".join(probs)])
			checked += 1
		model.free()
	check(checked >= 17 * 31, "%d combinacoes conferidas" % checked)


func test_all_parts_installed_together_scale_limits() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	for m in models():
		if m["body"] == "carreta":
			continue
		for id in PartFit.socket_parts(c, SLOTS):
			var sc: float = TruckSockets.fit_scale(m["data"], c.entry(id))
			var lo: float = 0.85
			var sk: Dictionary = TruckSockets.socket(m["data"], String(c.entry(id)["socket"]))
			if sk.has("max_depth"):                   # T-214: teto curto (americana): menor pelo fundo, nunca < 0,7
				lo = minf(lo, maxf(0.7, float(sk["max_depth"]) / TruckSockets.DECK_DEPTH) - 0.001)
			check(sc >= lo and sc <= 1.15, "%s em %s: escala %.2f" % [id, m["stem"], sc])
		# um deque e uma viseira juntos: as caixas sao separadas (regra 1), entao as pecas tambem
		var deck: AABB = TruckSockets.aabb_of(TruckSockets.socket(m["data"], "andon")["box"])
		var visor: AABB = TruckSockets.aabb_of(TruckSockets.socket(m["data"], "visor")["box"])
		check(not PartFit.overlap(deck, visor), "%s: deque x viseira separados" % m["stem"])


func test_part_data_rarity_no_lock() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := AccessoryCatalog.new()
	c.reload()
	for id in PartFit.socket_parts(c, SLOTS):
		var d: PartDef = gs.part(id)
		check(d != null, "PartDef %s" % id)
		if d == null:
			continue
		check(String(d.rarity) in ["comum", "incomum", "rara", "lendaria"], "%s: raridade %s" % [id, d.rarity])
		check(d.fame_required == 0, "%s: nao trava por Fama (decisao 4)" % id)
		check(d.price > 0 and d.weight_kg > 0.0 and d.durability > 0.0 and d.fame > 0, "%s: numeros" % id)
		check(Tr.t(d.display_key) != d.display_key, "%s: nome pt-BR" % id)
		var e: Dictionary = c.entry(id)
		check(int(e["triangles"]) <= 4500, "%s: %d triangulos" % [id, e["triangles"]])
		check(DecoColorDef.find(String(e["default_color"])) != null, "%s: cor de fabrica existe" % id)


func test_colors_have_price_and_tiers() -> void:
	var all: Array[DecoColorDef] = DecoColorDef.all()
	check(all.size() >= 8, "%d cores L/R" % all.size())
	for cd in all:
		check(cd.price > 0, "%s: tem preco" % cd.id)
		check(Tr.t(cd.display_key) != cd.display_key, "%s: nome pt-BR" % cd.id)
		for mat in cd.roles().values():
			check(AccessoryMaterials.DEFS.has(String(mat)), "%s: material %s existe" % [cd.id, mat])
	var cheap: int = 999999
	var dear: int = 0
	for cd in all:
		if cd.tier == &"comum":
			cheap = mini(cheap, cd.price)
		else:
			dear = maxi(dear, cd.price)
	check(cheap < dear, "comuns mais baratas que metalicas/neon")


func test_color_change_costs_money_and_goes_to_descriptor() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.profile["money"] = 100000
	var d: PartDef = gs.part("deck_led_box")
	check(gs.buy(d) and gs.install("deck_led_box"), "compra e instala o deque")
	var before: int = gs.money()
	check(gs.color_price("deck_led_box", "preto_ciano") == 0, "cor de fabrica de graca")
	var price: int = gs.color_price("deck_led_box", "cromo_rosa")
	check(price > 0, "cor metalica tem preco")
	check(gs.set_part_color("deck_led_box", "cromo_rosa"), "troca a cor")
	check_eq(gs.money(), before - price, "cobrou a cor")
	check(gs.set_part_sign("deck_led_box", 4), "escolhe o letreiro (lista pronta)")
	check(not gs.set_part_sign("deck_led_box", 99), "letreiro fora da lista recusado")
	var desc: Dictionary = gs.truck_descriptor()
	var found: bool = false
	for p in desc["parts"]:
		if String(p["id"]) == "deck_led_box":
			found = String(p.get("style", {}).get("color", "")) == "cromo_rosa" and int(p["style"]["sign"]) == 4
	check(found, "descritor da rede leva cor e letreiro")
	check(gs.apply_action("set_part_color", "deck_led_box:preto_ciano"), "acao do servidor volta a cor de fabrica")
	check_eq(gs.part_color("deck_led_box"), "preto_ciano", "cor de fabrica de volta")
	gs.new_profile()


func test_style_and_broken_part_keeps_geometry() -> void:
	var c := AccessoryCatalog.get_instance()
	var path: String = TruckNode.model_path("base", "chata")
	var model: Node3D = PartFit.load_model(path, "base", "chata")
	var n: Node3D = c.attach(model, "deck_led_box")
	check(n != null, "deque monta no caminhao padrao")
	DecoStyle.apply(n, c.entry("deck_led_box"), "cromo_rosa", 3)
	var names: Array[String] = []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			names.append(m.get_active_material(s).resource_name)
	check("chrome" in names and "lamp_pink" + LightPatterns.LENS_SUFFIX in names and "deco_sign" in names, "cor cromo + rosa e letreiro: %s" % [names])
	var sm: StandardMaterial3D = DecoStyle.sign_material(3, int(c.entry("deck_led_box")["sign_cell"]))
	check(sm.uv1_offset != Vector3.ZERO, "letreiro trocado desloca a UV")
	DecoStyle.set_broken(n, c)
	check(n.visible, "quebrada continua visivel (dano sem buraco)")
	check(absf(n.rotation.z) > deg_to_rad(5.0), "quebrada fica torta")
	var lit: int = 0
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			if m.get_active_material(s).resource_name.begins_with("lamp_") and m.get_active_material(s).resource_name != "lamp_off":
				lit += 1
	check_eq(lit, 0, "luzes apagadas na peca quebrada")
	model.free()


func test_garage_card_shows_colors_signs_and_rarity() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.profile["money"] = 100000
	gs.buy(gs.part("deck_lace"))
	var v := VBoxContainer.new()
	GarageDecoStyle.build(v, gs, gs.part("deck_lace"), func(_t: String) -> void: pass)
	var colors: Node = v.find_child("Colors_deck_lace", true, false)
	check(colors != null and colors.get_child_count() == DecoColorDef.all().size(), "grade de cores L/R no cartao")
	check(v.find_child("Signs_deck_lace", true, false) != null, "lista de letreiros no cartao")
	var lbl: Label = GarageDecoStyle.rarity_line(gs.part("deck_lace"))
	check(lbl.text.contains(Tr.t("rarity.rara")), "raridade no cartao: %s" % lbl.text)
	check(GarageDecoStyle.rarity_line(gs.part("visor_basic")).text == Tr.t("garage.classic"), "peca antiga = Classica")
	v.free()
	lbl.free()
	gs.new_profile()
