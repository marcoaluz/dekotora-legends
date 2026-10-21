extends TestCase
## Pecas DELUXE (T-172): dados da loja e texto pt-BR, orcamento de celular, encaixe em todos os modelos de caminhao e
## a luz que acompanha dia/noite (brilho no chao do neon e acrilico do andon; AccessoryGlow).

const IDS: Array[String] = ["andon_ichiban_dx", "marker_crown_dx", "underglow_neon_dx", "side_bumper_dx", "step_lit_dx",
		"rear_tail_bar_dx"]
const TRUCKS: Array = [["base", "chata"], ["base", "americana"], ["leve", "chata"], ["longo", "curta"], ["base", "jac"],
		["canter", "chata"], ["graneleira", "chata"]]


func test_part_data_and_texts() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	for id in IDS:
		var d: PartDef = gs.part(id)
		check(d != null, "PartDef %s existe" % id)
		if d == null:
			continue
		check(d.price > 0 and d.fame > 0 and d.weight_kg > 0.0 and d.durability > 0.0, "%s: preco, destaque, peso e durabilidade" % id)
		check(d.accessory_id == id, "%s: modelo %s" % [id, d.accessory_id])
		check(Tr.t(d.display_key) != d.display_key, "%s: nome em pt-BR" % id)
		check(Tr.t("slot." + String(d.slot)) != "slot." + String(d.slot), "%s: nome do encaixe %s em pt-BR" % [id, d.slot])
		check(String(d.slot) in GameState.SLOT_ORDER, "%s: encaixe %s na ordem da garagem" % [id, d.slot])


func test_catalog_tier_and_budget() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	for id in IDS:
		var e: Dictionary = c.entry(id)
		check(not e.is_empty(), "%s no catalogo" % id)
		if e.is_empty():
			continue
		check(String(e.get("tier", "")) == "deluxe", "%s marcada como deluxe" % id)
		check(int(e["triangles"]) >= 500 and int(e["triangles"]) <= 6000, "%s: %d triangulos" % [id, e["triangles"]])
		check((e["fit_warnings"] as Array).is_empty(), "%s: sem avisos de encaixe" % id)
		var n: Node3D = c.instantiate(id)
		check(n != null, "%s abre" % id)
		if n != null:
			var surfaces: int = 0
			for mi in n.find_children("*", "MeshInstance3D", true, false):
				surfaces += (mi as MeshInstance3D).mesh.get_surface_count()
			check(surfaces <= 7, "%s: %d materiais (chamadas de desenho por lado)" % [id, surfaces])
			n.free()


func test_parts_fit_every_truck_model() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	for tc in TRUCKS:
		var truck: Node3D = (load(TruckNode.model_path(String(tc[0]), String(tc[1]))) as PackedScene).instantiate() as Node3D
		TruckNode.add_extra_mounts(truck, String(tc[0]), String(tc[1]))
		for id in IDS:
			var e: Dictionary = c.entry(id)
			for side in (["R", "L"] if bool(e.get("mirror_for_left", false)) else ["R"]):
				check(c.attach(truck, id, side) != null, "%s monta no %s/%s (%s)" % [id, tc[0], tc[1], side])
		truck.free()


func test_floor_glow_follows_lights() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	var n: Node3D = c.instantiate("underglow_neon_dx")
	var g := AccessoryGlow.new()
	g.apply(n)
	check_near(g.floor_level(), 1.0, 0.001, "neon de chao aceso a noite")
	g.set_level(0.12)
	check(g.floor_level() < 0.05, "de dia o chao quase nao brilha (%.3f)" % g.floor_level())
	g.set_level(0.4)
	check_near(g.floor_level(), 0.4, 0.001, "previa de dia da garagem")
	var found: bool = false
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat: Material = m.get_active_material(s)
			if mat is ShaderMaterial and mat.resource_name == "glow_floor":
				found = true
				var col: Color = (mat as ShaderMaterial).get_shader_parameter("color")
				check(col.b > col.r, "brilho com a cor do neon (ciano)")
				check(m.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "brilho sem sombra")
	check(found, "quadrado do chao virou o shader aditivo")
	n.free()


func test_andon_acrylic_dims_by_day() -> void:
	var c := AccessoryCatalog.new()
	c.reload()
	var n: Node3D = c.instantiate("andon_ichiban_dx")
	var g := AccessoryGlow.new()
	g.apply(n)
	var acr: StandardMaterial3D = null
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat: Material = m.get_active_material(s)
			if mat is StandardMaterial3D and AccessoryGlow.is_acrylic(mat.resource_name):
				acr = mat
	check(acr != null and acr.emission_texture != null, "face de acrilico com textura acesa")
	if acr != null:
		var night: float = acr.emission_energy_multiplier
		g.set_level(0.12)
		check(acr.emission_energy_multiplier < night * 0.5, "acrilico mais fraco de dia (%.2f -> %.2f)" % [night, acr.emission_energy_multiplier])
	var txt: Node = n.find_child("SIGN_TEXT*", true, false)
	check(txt != null, "letreiro SIGN_TEXT separado (texto trocavel)")
	n.free()
