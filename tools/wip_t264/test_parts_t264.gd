extends TestCase
## Para-choques GRANDES da frente (T-264, capturas 054-062): 5 pecas que dobram a quina da cabine e correm pela lateral
## ate a roda (abas). Em TODOS os caminhoes jogaveis: cabem nas caixas, nao cobrem farol/lanterna/placa/porta/roda,
## as costas encostam no nariz e as abas encostam na lateral sem entrar (FrameContact), a aba vai ate a roda (ou ate
## a porta), placa e seta vao junto, LOD de longe, dano sem buraco.

const WRAP: Array[String] = ["fb_wrap_lamps", "fb_wrap_tower", "fb_wrap_chrome", "fb_wrap_deck4", "fb_wrap_deck_wide"]
const PF := preload("res://tests/test_part_fit.gd")


func test_catalog_and_data() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := AccessoryCatalog.get_instance()
	for id in WRAP:
		var e: Dictionary = c.entry(id)
		var d: PartDef = gs.part(id)
		check(not e.is_empty() and d != null, "%s no catalogo e PartDef" % id)
		if d == null or e.is_empty():
			continue
		check(String(d.slot) == "front_bumper" and d.fame_required == 0, "%s: para-choque da frente sem trava" % id)
		check(String(d.rarity) in ["rara", "lendaria"] and d.fame_min > 0, "%s: raridade e fama minima informativas" % id)
		check(d.price >= 40000 and d.weight_kg > 0.0 and d.durability > 0.0 and d.fame > 0, "%s: numeros" % id)
		check(Tr.t(d.display_key) != d.display_key, "%s: nome pt-BR" % id)
		check(DecoStyle.is_deco(e) and DecoColorDef.find(String(e["default_color"])) != null, "%s: cor de fabrica" % id)
		check(FrameFit.handles(e) and BumperWrap.handles(e), "%s: fit bumper com abas" % id)
		var lim: int = 6000 if String(d.rarity) == "lendaria" else 4500
		check(int(e["triangles"]) <= lim, "%s: %d triangulos" % [id, e["triangles"]])
		check(int(e.get("triangles_lod", 99999)) <= int(e["triangles"]) * 0.35 + 1, "%s: LOD com <= 35%% dos triangulos" % id)
		var mats: Array = e.get("materials_used", [])
		check("deco_plate" in mats and "deco_signal" in mats, "%s: caixa da placa e seta" % id)
		check(mats.size() <= 7, "%s: poucos materiais (%d)" % [id, mats.size()])
		check("deco_neon" in mats or "deco_led" in mats, "%s: luz com cor separada" % id)


func test_every_truck_fits_and_touches() -> void:
	var c := AccessoryCatalog.get_instance()
	var checked: int = 0
	for m in PF.models():
		if m["body"] == "carreta":
			continue
		var sk: Dictionary = TruckSockets.socket(m["data"], "front_bumper")
		var w: Dictionary = sk.get("wrap", {})
		check(w.has("r") and w.has("l"), "%s: abas medidas dos dois lados" % m["stem"])
		var model: Node3D = PartFit.load_model(m["path"], m["body"], m["cab"])
		for id in WRAP:
			var probs: Array[String] = PartFit.check_part(model, m["data"], c, id)
			check(probs.is_empty(), "%s em %s: %s" % [id, m["stem"], "; ".join(probs)])
			checked += 1
		model.free()
	check(checked >= 40 * WRAP.size(), "%d combinacoes conferidas" % checked)


## A aba vai ate o fim medido (roda ou porta), o lado de dentro fica na lataria + 4 mm, e a peca fica entre o chao e o farol.
func test_wing_reaches_wheel_and_height() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for pair in [["base", "chata"], ["base", "curta"], ["base", "americana"], ["base", "flat_wide"], ["canter", "canter"]]:
		var t := TruckNode.new()
		t.body_kind = pair[0]
		t.cab_kind = pair[1]
		t._ready()
		var defs: Array[PartDef] = [gs.part("fb_wrap_deck_wide")]
		t.apply_loadout(defs)
		var data: Dictionary = TruckSockets.for_model(TruckNode.model_path(pair[0], t.cab_kind))
		var sk: Dictionary = TruckSockets.socket(data, "front_bumper")
		var node: Node3D = t._acc_nodes["fb_wrap_deck_wide"][0]
		var box: AABB = PartFit.aabb_in(node, t.model)
		var back: float = float(sk["anchor"][2])
		var ln: float = float(sk["wrap"]["r"]["len"])
		check_near(box.end.z, back + ln, 0.02, "%s: aba ate o fim medido (%.2f m)" % [pair, ln])
		check(box.end.y <= float(sk["box"][1][1]) + 0.02 and box.position.y >= float(sk["box"][0][1]) - 0.02,
				"%s: entre o chao e o farol (%.2f-%.2f)" % [pair, box.position.y, box.end.y])
		check(node.find_children("*_cap_*", "MeshInstance3D", true, false).size() == 2, "%s: tampas da quina" % [pair])
		var spots: Array = FrameFit.signal_spots(t, t.model)
		check(spots.size() == 2, "%s: setas no para-choque" % [pair])
		if spots.size() == 2:
			check((spots[0] as Transform3D).origin.x < -0.8 and (spots[1] as Transform3D).origin.x > 0.8, "%s: setas nas quinas" % [pair])
		t.free()
	# altura: na chata (farol alto) a caixa alta fica grande; o para-choque da T-233 continua com 0,55 m
	var t2 := TruckNode.new()
	t2._ready()
	var defs2: Array[PartDef] = [gs.part("fb_wrap_lamps")]
	t2.apply_loadout(defs2)
	var h: float = PartFit.aabb_in(t2._acc_nodes["fb_wrap_lamps"][0], t2.model).size.y
	check(h >= 0.78, "caixa alta na chata com %.2f m de altura" % h)
	t2.free()


func test_lod_plate_and_broken() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var t := TruckNode.new()
	t._ready()
	var defs: Array[PartDef] = [gs.part("fb_wrap_deck4")]
	t.apply_loadout(defs)
	t.set_lights_on(true)
	var node: Node3D = t._acc_nodes["fb_wrap_deck4"][0]
	var near: int = 0
	var far: int = 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.visibility_range_begin > 0.0:
			far += 1
		elif m.visibility_range_end > 0.0:
			near += 1
	check(near > 0 and far > 0, "LOD: malha completa de perto (%d) e simples de longe (%d)" % [near, far])
	check(not node.find_children("*deco_plate*", "MeshInstance3D", true, false).is_empty(), "caixa da placa na peca")
	t.set_part_state("fb_wrap_deck4", "broken")
	check(node.visible, "quebrada continua no lugar (sem buraco)")
	var lit: int = 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m2: MeshInstance3D = mi as MeshInstance3D
		for k in m2.mesh.get_surface_count():
			if m2.get_active_material(k) is ShaderMaterial:
				lit += 1
	check_eq(lit, 0, "quebrada: luzes apagadas")
	t.free()


func test_old_bumpers_unchanged() -> void:
	check_near(FrameFit.bumper_k(0.886, 1.0, 0.13, 0.2, 0.09), (0.55 - 0.22) / 0.2, 0.001, "T-233: altura alvo de 0,55 m")
	var e: Dictionary = AccessoryCatalog.get_instance().entry("fb_deck_neon")
	check(not BumperWrap.handles(e), "para-choque da T-233 sem abas")


func test_bots_rivals_and_protocol() -> void:
	var seen: Dictionary = {}
	for s in 60:
		for p in TruckConfig.bot_part_ids(s):
			seen[p] = true
	check(seen.keys().any(func(i: String) -> bool: return String(i) in WRAP), "bots sorteiam para-choque grande")
	var ids: Array[String] = []
	for f in DirAccess.get_files_at("res://data/rivals/"):
		var r: RivalDef = load("res://data/rivals/" + f.trim_suffix(".remap")) as RivalDef if f.trim_suffix(".remap").ends_with(".tres") else null
		if r != null:
			for p in r.part_ids:
				ids.append(String(p))
	check(ids.any(func(i: String) -> bool: return i in WRAP), "algum rival usa para-choque grande")
	check(Protocol.VERSION >= 23, "protocolo 23 (T-264: pecas novas no descritor e nos bots)")
