extends TestCase
## Pinturas (T-232): 12 murais (lado direito e esquerdo DIFERENTES), 12 traseiras e 9 tetos em todos os baus fechados
## (leve/medio/longo x 4 cabines, Canter, bau de aluminio, bau rosa). Regras: arte nossa com emissao para a noite,
## retangulo medido no plano real da face, nunca espelhada (kanji legivel), fora das zonas protegidas (a traseira e
## tinta na porta: isenta so da zona das portas), guardada nas carrocerias abertas, peso 0, sem amassar.

const OPEN_BODIES: Array[String] = ["graneleira", "tarp", "tanker", "dump"]
const ROOF_PHRASES: Array[String] = ["一番星", "男花道", "爆走", "御意見無用", "唯我独尊", "義理人情", "浪漫街道", "天下御免", "夜明けまで"]
const PF := preload("res://tests/test_part_fit.gd")


static func paint_ids(slot: String = "", group: String = "") -> Array[String]:
	var out: Array[String] = []
	for e in AccessoryCatalog.get_instance().data.get("accessories", []):
		if PaintFit.handles(e) and (group == "" or PaintFit.group_of(e) == group):
			var d: PartDef = Engine.get_main_loop().root.get_node("GameState").part(String(e["id"]))
			if d != null and (slot == "" or String(d.slot) == slot):
				out.append(String(e["id"]))
	return out


func test_catalog_art_and_data() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	check_eq(paint_ids("mural", "pinturas").size(), 12, "12 murais (grupo Pinturas; T-266: os Wallpapers tem teste proprio)")
	check_eq(paint_ids("rear_paint", "pinturas").size(), 12, "12 traseiras")
	check_eq(paint_ids("roof_paint", "pinturas").size(), 9, "9 tetos")
	var seen_tex: Dictionary = {}
	for id in paint_ids():
		var e: Dictionary = AccessoryCatalog.get_instance().entry(id)
		var d: PartDef = gs.part(id)
		check(d.weight_kg == 0.0 and d.durability == 0.0 and d.fame > 0 and d.price > 0, "%s: pintura (peso 0, risca)" % id)
		check(String(d.rarity) in ["comum", "incomum", "rara", "lendaria"] and d.fame_required == 0, "%s: raridade sem trava" % id)
		check(Tr.t(d.display_key) != d.display_key, "%s: nome pt-BR" % id)
		check(Tr.t("slot." + String(d.slot)) != "slot." + String(d.slot), "%s: nome do encaixe" % id)
		check(GarageDecoNav.area_of(String(d.slot)) != "other", "%s: lugar na garagem" % id)
		for side in (e["paint"] as Dictionary):
			for art in e["paint"][side]:
				check(ResourceLoader.exists(String(art["tex"])) and ResourceLoader.exists(String(art["emit"])), "%s %s: arte e emissao" % [id, side])
				check(not seen_tex.has(String(art["tex"])), "%s: arte unica" % id)
				seen_tex[String(art["tex"])] = true
		if String(d.slot) == "mural":
			check(bool(e["mirror_for_left"]) and e["paint"].has("L"), "%s: lado esquerdo proprio" % id)
			check(String(e["paint"]["R"][0]["tex"]) != String(e["paint"]["L"][0]["tex"]), "%s: esquerdo diferente do direito" % id)
		if String(d.slot) == "roof_paint" and PaintFit.group_of(e) == "pinturas":
			check_eq((e["paint"]["R"] as Array).size(), 2, "%s: teto comprido e curto" % id)


func test_roof_phrases_are_the_approved_ones() -> void:
	for k in 9:
		var d: PartDef = Engine.get_main_loop().root.get_node("GameState").part("roofpaint_%02d" % (k + 1))
		check(d != null and Tr.t(d.display_key).contains(ROOF_PHRASES[k]), "teto %d = %s" % [k + 1, ROOF_PHRASES[k]])


func test_rects_on_every_closed_box() -> void:
	for m in PF.models():
		var open: bool = String(m["body"]) in OPEN_BODIES
		for k in ["mural_r", "mural_l", "rear_paint", "roof_paint"]:
			var s: Dictionary = TruckSockets.socket(m["data"], k)
			if open:
				check(s.is_empty(), "%s %s: carroceria aberta nao tem a face" % [m["stem"], k])
				continue
			check(s.has("rect"), "%s %s: retangulo medido" % [m["stem"], k])
			if not s.has("rect"):
				continue
			var r: Dictionary = s["rect"]
			var u := Vector3(r["u"][0], r["u"][1], r["u"][2])
			var v := Vector3(r["v"][0], r["v"][1], r["v"][2])
			var n := Vector3(r["n"][0], r["n"][1], r["n"][2])
			check(u.cross(v).dot(n) > 0.99, "%s %s: arte nunca espelhada" % [m["stem"], k])
		if not open:
			check("rear_paint" in (m["data"]["protected"]["rear_doors"]["exempt"] as Array), "%s: traseira isenta so das portas" % m["stem"])


func test_every_truck_fits_every_paint() -> void:
	var c := AccessoryCatalog.get_instance()
	var checked: int = 0
	for m in PF.models():
		if String(m["body"]) in OPEN_BODIES:
			continue
		var model: Node3D = PartFit.load_model(m["path"], m["body"], m["cab"])
		for id in paint_ids():
			var probs: Array[String] = PartFit.check_part(model, m["data"], c, id)
			check(probs.is_empty(), "%s em %s: %s" % [id, m["stem"], "; ".join(probs)])
			checked += 1
		model.free()
	check(checked >= 33 * 16, "%d combinacoes conferidas" % checked)


func test_window_never_stretches_much() -> void:
	for pair in [[4.0, 4.1], [4.0, 2.6], [4.0, 6.1], [1.25, 1.07], [0.25, 0.3], [0.5, 0.45]]:
		var art: float = pair[0]
		var rect: float = pair[1]
		var w: Rect2 = PaintFit.uv_window(art, rect)
		var shown: float = art * w.size.x / w.size.y            # proporcao da janela da arte
		check(shown / rect >= PaintFit.STRETCH.x - 0.001 and shown / rect <= PaintFit.STRETCH.y + 0.001,
				"arte %.2f no retangulo %.2f estica %.2f" % [art, rect, rect / shown])
		check(w.position.x >= 0.0 and w.end.x <= 1.0001 and w.position.y >= 0.0 and w.end.y <= 1.0001, "janela dentro da arte")


func test_truck_node_mounts_glows_and_never_dents() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for body in ["base", "pinkbox", "graneleira"]:
		var t := TruckNode.new()
		t.body_kind = body
		t._ready()                                   # fora da arvore: monta o modelo na hora
		var defs: Array[PartDef] = [gs.part("mural_koi"), gs.part("rearpaint_oni"), gs.part("roofpaint_03")]
		t.apply_loadout(defs)
		var nodes: int = 0
		for id in ["mural_koi", "rearpaint_oni", "roofpaint_03"]:
			nodes += (t._acc_nodes.get(id, []) as Array).size()
		if body == "graneleira":
			check_eq(nodes, 0, "graneleira: pinturas guardadas")
			t.free()
			continue
		check_eq(nodes, 4, "%s: mural nos 2 lados + traseira + teto" % body)
		t.set_mural_glow(0.8)
		var mat: StandardMaterial3D = (t._acc_nodes["mural_koi"][0] as Node3D).get_meta("paint_mat")
		check(mat.emission_enabled and mat.emission_texture != null and mat.emission_energy_multiplier > 0.5, "%s: mural acende a noite" % body)
		t.set_mural_glow(0.0)
		check(mat.emission_energy_multiplier == 0.0, "%s: de dia sem emissao" % body)
		var l_mat: StandardMaterial3D = (t._acc_nodes["mural_koi"][1] as Node3D).get_meta("paint_mat")
		check(l_mat.albedo_texture != mat.albedo_texture, "%s: lado esquerdo com arte propria" % body)
		var before: Transform3D = (t._acc_nodes["mural_koi"][0] as Node3D).transform
		t.set_part_state("mural_koi", "dent")
		t.set_part_state("rearpaint_oni", "broken")
		check((t._acc_nodes["mural_koi"][0] as Node3D).transform.is_equal_approx(before), "%s: pintura nao entorta" % body)
		check((t._acc_nodes["rearpaint_oni"][0] as Node3D).visible, "%s: pintura nao some" % body)
		t.free()


func test_box_only_in_profile() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.profile["money"] = 200000
	check(gs.buy(gs.part("mural_hoo")) and gs.install("mural_hoo"), "compra e instala o mural")
	check(gs.installed_part_defs().any(func(d: PartDef) -> bool: return d.id == &"mural_hoo"), "bau: mural conta")
	gs.profile["body"] = "tanker"
	check(not gs.installed_part_defs().any(func(d: PartDef) -> bool: return d.id == &"mural_hoo"), "tanque: mural guardado")
	gs.new_profile()


func test_bots_and_rivals_paint() -> void:
	var seen: Dictionary = {}
	for s in 16:
		for p in TruckConfig.bot_part_ids(s):
			seen[p] = true
		check(TruckConfig.bot_part_ids(s) == TruckConfig.bot_part_ids(s), "sorteio do bot repete pela semente")
	for slot in ["mural", "rear_paint", "roof_paint"]:
		check(paint_ids(slot).any(func(i: String) -> bool: return seen.has(i)), "bots sorteiam %s" % slot)
	var boss: RivalDef = load("res://data/rivals/boss_kanto.tres") as RivalDef
	check("mural_ryu_kumo" in boss.part_ids, "chefe com mural de dragao")
	check(Protocol.VERSION >= 17, "protocolo 17 (T-232: pinturas no descritor)")
