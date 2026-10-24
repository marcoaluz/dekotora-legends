extends TestCase
## T-214/T-215: deque de 2 niveis (caixa em cima de canhoes e o contrario) em TODOS os caminhoes, pecas antigas de teto
## fora do jogo (reembolso sem quebrar o save), cor das luzes separada da cor da peca.


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


static func _kind(c: AccessoryCatalog, id: String) -> String:
	return String(SocketSeat.stack_info(c.entry(id)).get("kind", ""))


static func pairs(c: AccessoryCatalog) -> Array:
	return StackFit.shape_pairs(c)


func test_shape_rules() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	var ids: Array[String] = PartFit.socket_parts(c, ["andon"])
	for id in ids:
		check(_kind(c, id) in ["box", "pods"], "%s tem dados de empilhamento" % id)
	check(not SocketSeat.stack_pair_ok(c.entry("deck_led_box"), c.entry("deck_led_panel")), "caixa em cima de caixa: nao")
	check(not SocketSeat.stack_pair_ok(c.entry("deck_pods_round"), c.entry("deck_pods_long")), "canhao em cima de canhao: nao")
	check(SocketSeat.stack_pair_ok(c.entry("deck_pods_round"), c.entry("deck_led_box")), "caixa em cima de canhoes: sim")
	check(SocketSeat.stack_pair_ok(c.entry("deck_led_box"), c.entry("deck_pods_round")), "canhoes em cima de caixa: sim")
	check(not SocketSeat.stack_pair_ok(c.entry("deck_eyebrow"), c.entry("deck_pods_round")), "sobrancelhas neon nao aguentam peca em cima")
	check(SocketSeat.stack_pair_ok(c.entry("deck_pods_round"), c.entry("deck_cap_trio")), "capa baixa vai em cima dos canhoes")
	check(pairs(c).size() >= 40, "%d duplas possiveis" % pairs(c).size())


## A tabela que o jogo consulta (StackFit.TABLE) bate com a conta geometrica refeita agora em TODOS os caminhoes: a dupla
## so aparece na garagem se, montada de verdade, fica dentro da caixa do encaixe, ate a altura maxima, fora das zonas
## protegidas e apoiada na de baixo. (Mudou peca/encaixe? godot --headless --path game -s res://tools_dev/gen_stack_fit.gd)
func test_stack_table_matches_geometry_on_every_truck() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	var all_pairs: Array = pairs(c)
	var tab: Dictionary = StackFit.table()
	var fit: int = 0
	var total: int = 0
	for m in (load("res://tests/test_part_fit.gd") as GDScript).call("models"):
		var stem: String = String(m["stem"])
		check(tab.has(stem), "tabela tem %s" % stem)
		var model: Node3D = PartFit.load_model(m["path"], m["body"], m["cab"])
		for pr in all_pairs:
			total += 1
			var probs: Array[String] = StackFit.problems(model, m["data"], c, pr[0], pr[1])
			var in_table: bool = (tab.get(stem, {}) as Dictionary).has(StackFit.key(pr[0], pr[1]))
			if probs.is_empty():
				fit += 1
			check(in_table == probs.is_empty(), "%s + %s em cima em %s: tabela %s, conta %s" % [pr[0], pr[1], stem,
					"cabe" if in_table else "nao cabe", "cabe" if probs.is_empty() else "; ".join(probs)])
		model.free()
	check(fit > total / 2, "%d de %d duplas x caminhoes cabem" % [fit, total])
	print("  empilhamento: %d de %d duplas x caminhoes cabem" % [fit, total])


func test_profile_stack_flow_and_descriptor() -> void:
	var gs: Node = _gs()
	gs.new_profile()
	gs.profile["money"] = 500000
	gs.profile["body"] = "base"
	gs.profile["cab"] = "chata"
	for id in ["deck_pods_round", "deck_led_box", "deck_led_panel"]:
		check(gs.buy(gs.part(id)), "compra " + id)
	check(gs.install("deck_pods_round"), "canhoes no 1o nivel")
	var cands: Array = gs.stack_candidates().map(func(d: PartDef) -> String: return String(d.id))
	check("deck_led_box" in cands and not ("deck_pods_long" in cands), "candidatos so caixas: %s" % [cands])
	check(not gs.install_top("deck_pods_round"), "a mesma peca nao vai em cima dela mesma")
	check(gs.install_top("deck_led_box"), "caixa em cima dos canhoes")
	var ids: Array = gs.installed_part_defs().map(func(d: PartDef) -> String: return String(d.id))
	check("deck_pods_round" in ids and "deck_led_box" in ids, "as duas pecas contam (peso, destaque): %s" % [ids])
	check(bool(gs.part_styles()["deck_led_box"].get("top", false)), "estilo marca a peca de cima")
	check(not (gs.profile.get("part_style", {}) as Dictionary).has("deck_led_box"), "o perfil nao guarda a marca")
	var top_in_desc: bool = false
	for p in gs.truck_descriptor()["parts"]:
		if String(p["id"]) == "deck_led_box":
			top_in_desc = bool(p.get("style", {}).get("top", false))
	check(top_in_desc, "descritor da rede leva a peca de cima")
	check(gs.apply_action("install_top", "deck_led_panel"), "acao do servidor troca a de cima")
	check_eq(gs.top_id(), "deck_led_panel", "outra caixa em cima")
	check(gs.install("deck_led_panel"), "a de cima desce para o 1o nivel")
	check_eq(gs.top_id(), "", "o 2o nivel fica vazio")
	check(gs.install_top("deck_pods_round"), "agora canhoes em cima da caixa")
	gs.uninstall("andon")
	check_eq(gs.top_id(), "", "sem o deque de baixo o de cima sai junto")
	gs.new_profile()


func test_truck_node_mounts_top_on_lower() -> void:
	var gs: Node = _gs()
	var t := TruckNode.new()
	t._ready()
	var defs: Array[PartDef] = [gs.part("deck_pods_round"), gs.part("deck_led_box")]
	t.apply_loadout(defs, {"deck_led_box": {"top": true, "color": "cromo_rosa"}})
	var top: Node = t.find_child("acc_deck_led_box_TOP", true, false)
	check(top != null, "peca de cima montada")
	if top != null:
		check(String(top.get_parent().name).begins_with("acc_deck_pods_round"), "filha da peca de baixo")
		check((top as Node3D).position.y > 0.3, "em cima dos canhoes (y %.2f)" % (top as Node3D).position.y)
	t.free()


func test_garage_lists_only_fitting_tops() -> void:
	var gs: Node = _gs()
	gs.new_profile()
	gs.profile["money"] = 500000
	gs.buy(gs.part("deck_led_box"))
	gs.install("deck_led_box")
	var v := VBoxContainer.new()
	GarageDeckStack.build(v, gs, func(_t: String) -> void: pass)
	var list: Node = v.find_child("StackCandidates", true, false)
	check(list != null and list.get_child_count() == gs.stack_candidates().size(), "garagem lista so as que cabem")
	v.free()
	gs.buy(gs.part("deck_eyebrow"))
	gs.install("deck_eyebrow")
	var v2 := VBoxContainer.new()
	GarageDeckStack.build(v2, gs, func(_t: String) -> void: pass)
	check(v2.find_child("StackCandidates", true, false) == null, "deque que nao aguenta peca em cima: sem lista")
	v2.free()
	gs.new_profile()


func test_retired_roof_parts_refund_once() -> void:
	var gs: Node = _gs()
	gs.new_profile()
	var money0: int = gs.money()
	for id in ["roof_lights_crown", "fumi_wing"]:
		gs.add_owned(gs.part(id))
		gs.profile["installed"][String(gs.part(id).slot)] = id
	gs.profile["part_style"] = {"roof_lights_crown": {"color": "x"}}
	check(gs.migrate_profile(), "migracao mexeu no perfil")
	var refund: int = gs.part("roof_lights_crown").price + gs.part("fumi_wing").price
	check_eq(gs.money(), money0 + refund, "reembolso do preco cheio")
	check(not gs.owns("roof_lights_crown") and not gs.owns("fumi_wing"), "pecas sairam do perfil")
	check(not (gs.profile["installed"] as Dictionary).has("roof_lights"), "encaixe antigo vazio")
	check(not (gs.profile["part_style"] as Dictionary).has("roof_lights_crown"), "estilo antigo apagado")
	gs.migrate_profile()
	check_eq(gs.money(), money0 + refund, "rodar de novo nao paga de novo")
	check_eq(gs.take_retired_notice(), refund, "garagem avisa o valor uma vez")
	check_eq(gs.take_retired_notice(), 0, "aviso so uma vez")
	for d in gs.all_parts():
		check(not RetiredParts.has(String(d.id)), "loja sem %s" % d.id)
	for s in RetiredParts.SLOTS:
		check(not (s in gs.slots()), "encaixe %s fora da garagem" % s)
	check(gs.can_buy(gs.part("andon_kanji")) != "", "fora de linha nao se compra")
	for r in ["boss_kanto", "rival_urban"]:
		var rd: Resource = load("res://data/rivals/%s.tres" % r)
		for id in rd.get("part_ids"):
			check(not RetiredParts.has(String(id)), "rival %s sem peca antiga (%s)" % [r, id])
	gs.new_profile()


func test_light_colors_separate_from_part_color() -> void:
	var all: Array[DecoLightDef] = DecoLightDef.all()
	check(all.size() >= 10, "%d cores de luz" % all.size())
	for ld in all:
		check(LightPatterns.ANIMATED.has(ld.lamp) and AccessoryMaterials.DEFS.has(ld.lamp), "%s: luz que pisca (%s)" % [ld.id, ld.lamp])
		check(Tr.t(ld.display_key) != ld.display_key, "%s: nome pt-BR" % ld.id)
		check(ld.price > 0, "%s: preco" % ld.id)
	check(DecoColorDef.all().size() >= 18, "%d cores de peca" % DecoColorDef.all().size())
	var gs: Node = _gs()
	gs.new_profile()
	gs.profile["money"] = 100000
	gs.buy(gs.part("deck_lace"))
	gs.install("deck_lace")
	check_eq(gs.part_light("deck_lace", "led"), "verde", "LED de fabrica da cor preto+ciano = verde")
	check_eq(gs.light_price("deck_lace", "led", "verde"), 0, "voltar a luz de fabrica e de graca")
	var before: int = gs.money()
	var price: int = gs.light_price("deck_lace", "led", "rosa")
	check(price > 0 and gs.set_part_light("deck_lace", "led", "rosa"), "troca o LED para rosa (paga)")
	check_eq(gs.money(), before - price, "cobrou a luz")
	check(gs.apply_action("set_part_light", "deck_lace:neon:laranja"), "acao do servidor troca o neon")
	check_eq(gs.part_color("deck_lace"), "preto_ciano", "a cor da peca nao mudou")
	var st: Dictionary = {}
	for p in gs.truck_descriptor()["parts"]:
		if String(p["id"]) == "deck_lace":
			st = p.get("style", {})
	check(String(st.get("led", "")) == "rosa" and String(st.get("neon", "")) == "laranja", "descritor leva as luzes: %s" % st)
	check(not gs.set_part_light("deck_lace", "estrutura", "rosa"), "papel invalido recusado")
	var c := AccessoryCatalog.get_instance()
	var model: Node3D = PartFit.load_model(TruckNode.model_path("base", "chata"), "base", "chata")
	var n: Node3D = c.attach(model, "deck_lace")
	DecoStyle.apply(n, c.entry("deck_lace"), "preto_ciano", -1, "rosa", "laranja")
	var names: Array[String] = []
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			if m.get_active_material(s) != null:
				names.append(m.get_active_material(s).resource_name)
	check("lamp_pink" + LightPatterns.LENS_SUFFIX in names, "LED rosa com lente")
	check("lamp_orange" in names, "neon laranja")
	var body: Material = null
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			if m.mesh.surface_get_material(s) != null and m.mesh.surface_get_material(s).resource_name == "deco_body":
				body = m.get_active_material(s)
	check(body is StandardMaterial3D and (body as StandardMaterial3D).normal_enabled, "estrutura com textura de detalhe")
	model.free()
	gs.new_profile()
