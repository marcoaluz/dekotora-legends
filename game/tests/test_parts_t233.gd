extends TestCase
## Oficina lote 4 (T-233): 11 para-choques da frente, 6 hastes de retrovisor, 3 escadas e 8 saias em TODOS os caminhoes
## jogaveis (a carreta guardada so entra no relatorio). Regras da decisao 12 do Marco: tudo instalado junto, nada cobre
## farol, lanterna, placa, para-brisa, porta ou roda (a placa da frente vai para a caixa da placa da peca e a seta da
## frente vai junto com o para-choque); dano sem buraco; luzes acendem a noite.

const FRONT: Array[String] = ["fb_fan_plate", "fb_fan_amber", "fb_fan_red", "fb_fan_gold", "fb_fan_stripe", "fb_fan_chrome",
	"fb_box_amber", "fb_box_steps", "fb_smooth_chrome", "fb_deck_checker", "fb_deck_neon"]
const MIRRORS: Array[String] = ["mirror_stay_l", "mirror_stay_truss", "mirror_stay_frame", "mirror_stay_box", "mirror_stay_chain",
	"mirror_stay_grand"]
const LADDERS: Array[String] = ["ladder_neon", "ladder_green", "ladder_chrome"]
const SKIRTS: Array[String] = ["skirt_chrome_rails", "skirt_neon_twin", "skirt_neon_diamond", "skirt_neon_dash", "skirt_neon_arch",
	"skirt_neon_green", "skirt_neon_gems", "skirt_neon_arrows"]
const OPEN_BODIES: Array[String] = ["graneleira", "tarp", "tanker", "dump"]
const PF := preload("res://tests/test_part_fit.gd")


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	out.append_array(FRONT)
	out.append_array(MIRRORS)
	out.append_array(LADDERS)
	out.append_array(SKIRTS)
	return out


func test_catalog_and_data() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var c := AccessoryCatalog.get_instance()
	for id in all_ids():
		var e: Dictionary = c.entry(id)
		check(not e.is_empty(), "%s no catalogo" % id)
		var d: PartDef = gs.part(id)
		check(d != null, "PartDef %s" % id)
		if d == null or e.is_empty():
			continue
		check(String(d.rarity) in ["comum", "incomum", "rara", "lendaria"] and d.fame_required == 0, "%s: raridade sem trava" % id)
		check(d.price > 0 and d.weight_kg > 0.0 and d.durability > 0.0 and d.fame > 0, "%s: numeros" % id)
		check(Tr.t(d.display_key) != d.display_key, "%s: nome pt-BR" % id)
		check(DecoStyle.is_deco(e) and DecoColorDef.find(String(e["default_color"])) != null, "%s: cor de fabrica" % id)
		var lim: int = 6000 if String(d.rarity) == "lendaria" else 4500
		check(int(e["triangles"]) <= lim, "%s: %d triangulos (pior caso)" % [id, e["triangles"]])
		check(Tr.t("slot." + String(d.slot)) != "slot." + String(d.slot), "%s: nome do encaixe" % id)
		check(GarageDecoNav.area_of(String(d.slot)) != "other", "%s: encaixe tem lugar na garagem" % id)
		check(FrameFit.handles(e), "%s: fit da T-233" % id)
	for id in FRONT:
		check("deco_plate" in c.entry(id).get("materials_used", []), "%s: caixa da placa" % id)


func test_every_truck_fits() -> void:
	var c := AccessoryCatalog.get_instance()
	var checked: int = 0
	for m in PF.models():
		if m["body"] == "carreta":
			continue
		var model: Node3D = PartFit.load_model(m["path"], m["body"], m["cab"])
		var open: bool = String(m["body"]) in OPEN_BODIES
		for id in all_ids():
			var e: Dictionary = c.entry(id)
			var has_socket: bool = TruckSockets.socket(m["data"], String(e["socket"])).size() > 0
			if open and id in LADDERS:
				check(not has_socket, "%s em %s: so para bau fechado" % [id, m["stem"]])
				continue
			check(has_socket, "%s em %s: encaixe existe" % [id, m["stem"]])
			var probs: Array[String] = PartFit.check_part(model, m["data"], c, id)
			check(probs.is_empty(), "%s em %s: %s" % [id, m["stem"], "; ".join(probs)])
			checked += 1
		model.free()
	check(checked >= 15 * 28 + 7 * 25, "%d combinacoes conferidas" % checked)


func test_bumper_fits_height_and_carries_plate_and_signal() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for body in ["canter", "base", "alubox"]:
		var t := TruckNode.new()
		t.body_kind = body
		t._ready()                                   # fora da arvore: monta o modelo na hora
		var defs: Array[PartDef] = [gs.part("fb_box_amber")]
		t.apply_loadout(defs)
		var data: Dictionary = TruckSockets.for_model(TruckNode.model_path(body, t.cab_kind))
		var sk: Dictionary = TruckSockets.socket(data, "front_bumper")
		var node: Node3D = t._acc_nodes["fb_box_amber"][0]
		var box: AABB = PartFit.aabb_in(node, t.model)
		check(box.end.y <= float(sk["box"][1][1]) + 0.02 and box.position.y >= float(sk["box"][0][1]) - 0.02,
				"%s: para-choque entre o chao e o farol (%.2f-%.2f)" % [body, box.position.y, box.end.y])
		var spots: Array = FrameFit.signal_spots(t, t.model)
		check(spots.size() == 2, "%s: setas no para-choque" % body)
		if spots.size() == 2:
			check(t.signals.spots[0] == "bumper" and t.signals.spots[1] == "bumper", "%s: seta no ponto do para-choque" % body)
			var bl: AABB = t.signals.box_of(0, t)       # T-239: a seta e filha do ponto SIGNAL (antes: caixa no TruckNode)
			check(bl.get_center().distance_to((spots[0] as Transform3D).origin) < 0.01, "%s: seta esquerda foi junto" % body)
			check(bl.get_center().x < 0.0 and t.signals.box_of(1, t).get_center().x > 0.0, "%s: esquerda/direita" % body)
		t.free()


func test_stock_mirror_hidden_and_restored() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var t := TruckNode.new()
	t._ready()
	var count := func() -> int:
		var n: int = 0
		for mi in t.model.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).has_meta("stock_mesh"):
				n += 1
		return n
	var defs: Array[PartDef] = [gs.part("mirror_stay_grand")]
	t.apply_loadout(defs)
	check(count.call() > 0, "espelho de fabrica escondido com a haste")
	t.apply_loadout([] as Array[PartDef])
	check_eq(count.call(), 0, "espelho de fabrica volta sem a haste")
	t.free()


func test_lights_at_night_and_broken_keeps_geometry() -> void:
	var t := TruckNode.new()
	t._ready()
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var ids: Array[String] = ["fb_fan_amber", "mirror_stay_grand", "ladder_green", "skirt_neon_gems"]
	var defs: Array[PartDef] = []
	for id in ids:
		defs.append(gs.part(id))
	t.apply_loadout(defs)
	t.set_lights_on(true)
	check(t._lamp_mats.has("lamp_amber"), "lampadas ambar do para-choque viram luz que acende")
	for id in ids:
		check(t._acc_nodes.has(id) and not (t._acc_nodes[id] as Array).is_empty(), "%s montada" % id)
		t.set_part_state(id, "broken")
		for n in t._acc_nodes.get(id, []):
			var node: Node3D = n
			check(node.visible, "%s quebrada continua no lugar" % id)
			var lit: int = 0
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				var m: MeshInstance3D = mi as MeshInstance3D
				for k in m.mesh.get_surface_count():
					if m.get_active_material(k) is ShaderMaterial:
						lit += 1
			check_eq(lit, 0, "%s quebrada: luzes apagadas" % id)
	t.free()


func test_bots_and_rivals_use_new_parts() -> void:
	var ids: Array[String] = []
	for f in DirAccess.get_files_at("res://data/rivals/"):
		if not f.trim_suffix(".remap").ends_with(".tres"):
			continue
		var r: RivalDef = load("res://data/rivals/" + f.trim_suffix(".remap")) as RivalDef
		if r != null:
			for p in r.part_ids:
				ids.append(String(p))
	check(ids.any(func(i: String) -> bool: return i in FRONT), "algum rival usa para-choque da frente novo")
	check(ids.any(func(i: String) -> bool: return i in SKIRTS or i in MIRRORS), "algum rival usa saia ou retrovisor novo")
	var seen: Dictionary = {}
	for s in 24:
		for p in TruckConfig.bot_part_ids(s):
			seen[p] = true
	check(seen.keys().any(func(i: String) -> bool: return String(i) in FRONT), "bots sorteiam para-choque da frente novo")
	check(seen.keys().any(func(i: String) -> bool: return String(i) in SKIRTS), "bots sorteiam saia nova")
