extends TestCase
## Oficina lote 5 (T-234): as lacunas da secao 19 (calotas, escapamentos, grades, buzinas, interior e adesivos) em
## TODOS os caminhoes jogaveis (a carreta guardada so entra no relatorio). Regras da decisao 12 do Marco: tudo
## instalado junto, nada cobre farol, lanterna, placa, para-brisa (o interior e a arte NO vidro, isento so ele), porta
## ou roda (a calota e isenta da roda); dano sem buraco; luzes acendem a noite; kanji dos adesivos nunca espelhado.

const HUBS: Array[String] = ["hub_led_ring", "hub_star_gold", "hub_neon_spinner"]
const STACKS: Array[String] = ["stack_neon_twin", "stack_j_amber", "stack_side_triple"]
const GRILLES: Array[String] = ["grille_bars_led", "grille_honey_sun", "grille_slats_neon"]
const HORNS: Array[String] = ["horn_triple", "horn_twin_long", "horn_ship"]
const INTERIORS: Array[String] = ["interior_curtain", "interior_chandelier", "interior_tufted"]
const DECALS: Array[String] = ["decal_frase_01", "decal_frase_02", "decal_frase_03", "decal_frase_04", "decal_frase_05",
	"decal_frase_06", "decal_frase_07", "decal_frase_08", "decal_frase_09", "decal_labaredas", "decal_sol_nascente"]
const PF := preload("res://tests/test_part_fit.gd")


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for l in [HUBS, STACKS, GRILLES, HORNS, INTERIORS]:
		out.append_array(l)
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
		check(d.price > 0 and d.fame > 0 and (d.weight_kg > 0.0 or id in INTERIORS), "%s: numeros" % id)
		check(Tr.t(d.display_key) != d.display_key, "%s: nome pt-BR" % id)
		check(Tr.t("slot." + String(d.slot)) != "slot." + String(d.slot), "%s: nome do encaixe" % id)
		check(GarageDecoNav.area_of(String(d.slot)) != "other", "%s: encaixe tem lugar na garagem" % id)
		check(int(e.get("triangles", 0)) <= 4500, "%s: %d triangulos (pior caso)" % [id, e.get("triangles", 0)])
		if not id in INTERIORS:
			check(DecoStyle.is_deco(e) and DecoColorDef.find(String(e["default_color"])) != null, "%s: cor de fabrica" % id)
	for id in HORNS:
		check(HornCatalog.is_valid((gs.part(id) as PartDef).horn), "%s: traz um som de buzina" % id)
	for id in INTERIORS:
		check(PaintFit.handles(c.entry(id)) and bool(c.entry(id).get("alpha", false)), "%s: arte no vidro (transparente)" % id)


func test_every_truck_fits() -> void:
	var c := AccessoryCatalog.get_instance()
	var checked: int = 0
	var no_horn: Array[String] = []
	for m in PF.models():
		if m["body"] == "carreta":
			continue
		var model: Node3D = PartFit.load_model(m["path"], m["body"], m["cab"])
		for id in all_ids():
			var e: Dictionary = c.entry(id)
			var sk: Dictionary = TruckSockets.socket(m["data"], String(e["socket"]))
			if id in HORNS and sk.is_empty():
				if not m["stem"] in no_horn:
					no_horn.append(m["stem"])
				continue
			check(not sk.is_empty(), "%s em %s: encaixe existe" % [id, m["stem"]])
			var probs: Array[String] = PartFit.check_part(model, m["data"], c, id)
			check(probs.is_empty(), "%s em %s: %s" % [id, m["stem"], "; ".join(probs)])
			checked += 1
		model.free()
	for s in no_horn:          # so a cabine americana (teto curto: o deque de 2 niveis desce ate a viseira) fica sem buzina
		check(s.contains("americana"), "%s: sem lugar para a buzina" % s)
	check(checked >= 50 * 14, "%d combinacoes conferidas" % checked)


func test_grille_stretches_to_each_cab() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for cab in ["chata", "flat_wide", "americana"]:
		var t := TruckNode.new()
		t.cab_kind = cab
		t._ready()
		t.apply_loadout([gs.part("grille_honey_sun")] as Array[PartDef])
		var data: Dictionary = TruckSockets.for_model(TruckNode.model_path(t.body_kind, cab))
		var sb: AABB = TruckSockets.aabb_of(TruckSockets.socket(data, "grille")["box"])
		var node: Node3D = t._acc_nodes["grille_honey_sun"][0]
		var box: AABB = PartFit.aabb_in(node, t.model)
		check(box.size.x > sb.size.x * 0.85 and box.size.y > sb.size.y * 0.80, "%s: grade ocupa a caixa (%.2f x %.2f de %.2f x %.2f)" %
				[cab, box.size.x, box.size.y, sb.size.x, sb.size.y])
		var sun: Array = node.find_children("*_CEN_*", "MeshInstance3D", true, false)
		check(not sun.is_empty(), "%s: emblema do meio separado" % cab)
		if not sun.is_empty():                       # emblema de asas: 0,90 x 0,225 m na grade (proporcao 4:1, sem deformar)
			var smi: MeshInstance3D = sun[0] as MeshInstance3D
			var sbox: AABB = PartFit.rel_xform(smi, t.model) * smi.mesh.get_aabb()
			var ratio: float = sbox.size.x / maxf(sbox.size.y, 0.001)
			check(sbox.size.x > 0.3 and absf(ratio - 4.0) < 0.5, "%s: emblema sem deformar (%.2f x %.2f)" % [cab, sbox.size.x, sbox.size.y])
		t.free()


func test_hubcaps_on_every_outer_wheel_scaled_by_radius() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var sizes: Dictionary = {}
	for body in ["base", "canter"]:
		var t := TruckNode.new()
		t.body_kind = body
		t._ready()
		t.apply_loadout([gs.part("hub_led_ring")] as Array[PartDef])
		var nodes: Array = t._acc_nodes["hub_led_ring"]
		check_eq(nodes.size(), t.wheels.outer_wheels().size(), "%s: uma calota por roda de fora" % body)
		sizes[body] = PartFit.aabb_in(nodes[0] as Node3D, t.model).size.y
		for n in nodes:
			check((n as Node3D).get_parent().name.begins_with("wheel_"), "%s: calota presa na roda (gira junto)" % body)
		t.free()
	check(float(sizes["canter"]) < float(sizes["base"]) * 0.92, "calota menor na roda menor do Canter")


func test_interior_on_windshield_and_glows_at_night() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var t := TruckNode.new()
	t._ready()
	t.apply_loadout([gs.part("interior_chandelier")] as Array[PartDef])
	var n: Node3D = t._acc_nodes["interior_chandelier"][0]
	var mat: StandardMaterial3D = n.get_meta("paint_mat") as StandardMaterial3D
	check(mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "interior com transparencia nas bordas")
	t.set_mural_glow(0.8)
	check(mat.emission_energy_multiplier > 0.5, "lustre acende a noite")
	t.set_mural_glow(0.0)
	check_eq(mat.emission_energy_multiplier, 0.0, "de dia sem brilho")
	t.set_part_state("interior_chandelier", "broken")
	check(n.visible, "interior nao some com dano")
	t.free()


func test_lights_and_broken_keep_geometry() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var t := TruckNode.new()
	t._ready()
	var ids: Array[String] = ["hub_neon_spinner", "stack_j_amber", "grille_bars_led", "horn_ship"]
	var defs: Array[PartDef] = []
	for id in ids:
		defs.append(gs.part(id))
	t.apply_loadout(defs)
	t.set_lights_on(true)
	check(t._lamp_mats.has("lamp_amber"), "luz ambar (fendas do J, aro da buzina) acende")
	for id in ids:
		check(t._acc_nodes.has(id) and not (t._acc_nodes[id] as Array).is_empty(), "%s montada" % id)
		t.set_part_state(id, "broken")
		for nd in t._acc_nodes.get(id, []):
			check((nd as Node3D).visible, "%s quebrada continua no lugar" % id)
	t.free()


func test_horn_part_sets_the_horn_sound() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	check_eq((gs.part("horn_ship") as PartDef).horn, "horn_ship_deep", "buzina de navio = som de navio")
	check_eq((gs.part("horn_triple") as PartDef).horn, "horn_musical_dekotora", "corneta tripla = melodia")


func test_decals_listed_with_names_and_white_ink() -> void:
	var ids: Array[String] = DecalCatalog.ids()
	for id in DECALS:
		check(id in ids, "adesivo %s na lista" % id)
		check(Tr.t("decal." + id) != "decal." + id, "adesivo %s com nome" % id)
		var tex: Texture2D = DecalCatalog.texture(id)
		check(tex != null and tex.get_width() >= 256, "adesivo %s carrega" % id)


func test_bots_draw_new_hubs_and_grilles() -> void:
	var seen: Dictionary = {}
	for s in 120:
		for p in TruckConfig.bot_part_ids(s):
			seen[p] = true
	check(seen.keys().any(func(i: String) -> bool: return String(i) in HUBS), "bots sorteiam calota nova")
	check(seen.keys().any(func(i: String) -> bool: return String(i) in GRILLES), "bots sorteiam grade nova")
	check(Protocol.VERSION >= 21, "protocolo 21 (lote 5 no descritor e nos bots)")


# ---------------------------------------------------------------------------------------------- T-256 (refino)

func test_horn_sides_option() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for opt in [["both", 2], ["left", 1], ["right", 1]]:
		var t := TruckNode.new()
		t._ready()
		var st: Dictionary = {} if opt[0] == "both" else {"horn_triple": {"side": opt[0]}}
		t.apply_loadout([gs.part("horn_triple")] as Array[PartDef], st)
		var nodes: Array = t._acc_nodes["horn_triple"]
		check_eq(nodes.size(), int(opt[1]), "buzina %s: %d conjunto(s)" % [opt[0], opt[1]])
		for n in nodes:
			var c: Vector3 = PartFit.aabb_in(n as Node3D, t.model).get_center()
			if opt[0] == "left":
				check(c.x < -0.3, "so a esquerda (x %.2f)" % c.x)
			elif opt[0] == "right":
				check(c.x > 0.3, "so a direita (x %.2f)" % c.x)
		t.free()
	check(Lot5Fit.HORN_SIDES == ["both", "left", "right"], "3 disposicoes")


func test_grille_follows_front_and_cab_art() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for cab in ["jac", "chata", "flat_wide"]:
		var t := TruckNode.new()
		t.cab_kind = cab
		t._ready()
		var data: Dictionary = TruckSockets.for_model(TruckNode.model_path(t.body_kind, cab))
		var sk: Dictionary = TruckSockets.socket(data, "grille")
		var sb: AABB = TruckSockets.aabb_of(sk["box"])
		t.apply_loadout([gs.part("grille_bars_led")] as Array[PartDef], {"grille_bars_led": {"art": 13}})
		var node: Node3D = t._acc_nodes["grille_bars_led"][0]
		check(absf(node.transform.basis.y.z - float(sk["lean"]) * node.transform.basis.y.y) < 0.001, "%s: grade inclinada pela frente" % cab)
		var art: Array = node.find_children("cab_art", "MeshInstance3D", true, false)
		check_eq(art.size(), 1, "%s: adesivo na lataria" % cab)
		check_eq(node.find_children("cab_art_leds", "MeshInstance3D", true, false).size(), 1, "%s: LEDs do adesivo" % cab)
		var inside_grille: int = 0
		for mi in node.find_children("*", "MeshInstance3D", true, false):    # T-259: nada de arte DENTRO da grade
			var m: MeshInstance3D = mi as MeshInstance3D
			for k in m.mesh.get_surface_count():
				var sm: Material = m.mesh.surface_get_material(k)
				if sm != null and sm.resource_name in ["acrylic_art", "deco_art"]:
					inside_grille += 1
		check_eq(inside_grille, 0, "%s: grade sem painel de arte dentro" % cab)
		if not art.is_empty():
			var mi: MeshInstance3D = art[0] as MeshInstance3D
			var xf: Transform3D = PartFit.rel_xform(mi, t.model)
			var gb := AABB()
			var first: bool = true
			for gm in node.find_children("*", "MeshInstance3D", true, false):     # so a grade (sem colar/adesivo)
				if (gm as Node).has_meta("lot5_extra"):
					continue
				var bb: AABB = PartFit.rel_xform(gm as Node3D, t.model) * (gm as MeshInstance3D).mesh.get_aabb()
				gb = bb if first else gb.merge(bb)
				first = false
			var ab: AABB = xf * mi.mesh.get_aabb()
			var ws: AABB = TruckSockets.aabb_of(data["measure"]["cab"]["windshield"])
			check(ab.position.y >= gb.end.y - 0.05 and ab.end.y <= ws.position.y, "%s: faixa entre a grade e o para-brisa" % cab)
			check(ab.size.x > sb.size.x, "%s: faixa de lado a lado (mais larga que a grade)" % cab)
			var faces: PackedVector3Array = mi.mesh.get_faces()
			var bad: int = 0
			for f in range(0, faces.size(), 3):
				var c: Vector3 = xf * ((faces[f] + faces[f + 1] + faces[f + 2]) / 3.0)
				for z in data.get("protected", {}):
					if String(z).begins_with(("headlight")) or String(z).begins_with("front_lamp") or String(z).begins_with("front_plate"):
						if TruckSockets.aabb_of(data["protected"][z]["box"]).grow(-0.01).has_point(c):
							bad += 1
			check_eq(bad, 0, "%s: adesivo recortado em volta das luzes e da placa" % cab)
		t.set_mural_glow(0.8)
		check((node.get_meta("cab_art") as StandardMaterial3D).emission_energy_multiplier > 0.0, "%s: arte acende fraco a noite" % cab)
		t.free()
	var t2 := TruckNode.new()
	t2.cab_kind = "jac"
	t2._ready()
	t2.apply_loadout([gs.part("grille_slats_neon")] as Array[PartDef])
	check(not (t2._acc_nodes["grille_slats_neon"][0] as Node3D).find_children("collar", "MeshInstance3D", true, false).is_empty(),
			"jac: colar fecha a folga atras da grade")
	t2.free()


func test_new_options_are_free_and_go_to_descriptor() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.profile["money"] = 200000
	check(gs.buy(gs.part("horn_ship")) and gs.buy(gs.part("grille_honey_sun")), "compra buzina e grade")
	check(gs.install("horn_ship") and gs.install("grille_honey_sun"), "instala buzina e grade")
	var m: int = gs.money()
	check(gs.set_part_side("horn_ship", "left"), "escolhe so a esquerda")
	check(not gs.set_part_side("horn_ship", "meio"), "disposicao invalida recusada")
	check(gs.set_part_art("grille_honey_sun", 12), "escolhe a arte de ondas na lata")
	check(not gs.set_part_art("grille_honey_sun", 3), "celula invalida recusada")
	check_eq(gs.money(), m, "opcoes de graca")
	var desc: Dictionary = gs.truck_descriptor()
	var side: String = ""
	var art: int = -1
	for p in desc["parts"]:
		if String(p["id"]) == "horn_ship":
			side = String(p.get("style", {}).get("side", ""))
		if String(p["id"]) == "grille_honey_sun":
			art = int(p.get("style", {}).get("art", -1))
	check(side == "left" and art == 12, "descritor da rede leva a disposicao e a arte")
	check(gs.apply_action("set_part_side", "horn_ship:both"), "acao do servidor volta aos dois lados")
	check(not gs.part_style("horn_ship").has("side"), "dois lados = padrao (nao grava)")
	gs.new_profile()
