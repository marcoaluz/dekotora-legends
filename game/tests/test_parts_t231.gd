extends TestCase
## Oficina lote 2 (T-231): 11 para-choques traseiros com lanternas, 7 foguetes e 3 contornos do bau em TODOS os
## caminhoes jogaveis (a carreta guardada so entra no relatorio). Regras da decisao 12 do Marco: tudo instalado junto,
## nada cobre farol, lanterna (as de fabrica de baixo sao SUBSTITUIDAS pelas da peca), placa, porta ou roda; dano sem
## buraco; luzes acendem a noite; a placa vai para a caixa da placa da peca.

const REAR: Array[String] = ["rb_square_row", "rb_round_twin", "rb_square_grid", "rb_round_grid", "rb_target", "rb_double_deck",
	"rb_neon_rows", "rb_neon_plate", "rb_bullet", "rb_torpedo", "rb_grand_panel"]
const ROCKETS: Array[String] = ["rocket_round", "rocket_square", "rocket_twin", "rocket_led", "rocket_flat_neon", "rocket_neon_dash",
	"rocket_frame"]
const BOXLIGHTS: Array[String] = ["boxlight_dash_r", "boxlight_dash_l", "boxlight_dash_top"]
const OPEN_BODIES: Array[String] = ["graneleira", "tarp", "tanker", "dump"]
const PF := preload("res://tests/test_part_fit.gd")


static func all_ids() -> Array[String]:
	var out: Array[String] = []
	out.append_array(REAR)
	out.append_array(ROCKETS)
	out.append_array(BOXLIGHTS)
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
		check(int(e["triangles"]) <= lim, "%s: %d triangulos (no bau mais comprido)" % [id, e["triangles"]])
		check(Tr.t("slot." + String(d.slot)) != "slot." + String(d.slot), "%s: nome do encaixe" % id)
		check(GarageDecoNav.area_of(String(d.slot)) != "other", "%s: encaixe tem lugar na garagem" % id)
	for id in REAR:
		var mats: Array = c.entry(id).get("materials_used", [])
		check("lamp_tail" in mats and "deco_plate" in mats, "%s: lanternas proprias e caixa da placa" % id)


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
			if open and id not in REAR:
				check(not has_socket, "%s em %s: so para bau fechado" % [id, m["stem"]])
				continue
			check(has_socket, "%s em %s: encaixe existe" % [id, m["stem"]])
			var probs: Array[String] = PartFit.check_part(model, m["data"], c, id)
			check(probs.is_empty(), "%s em %s: %s" % [id, m["stem"], "; ".join(probs)])
			checked += 1
		model.free()
	check(checked >= 22 * 11 + 14 * 10, "%d combinacoes conferidas" % checked)


func test_contour_covers_most_of_the_box() -> void:
	for m in PF.models():
		if m["body"] == "carreta" or String(m["body"]) in OPEN_BODIES:
			continue
		var bx: Dictionary = m["data"]["measure"]["box"]
		var perim_side: float = 2.0 * (float(bx["rear_z"]) - float(bx["front_z"]) + float(bx["top_y"]) - float(bx["bottom_y"]))
		for k in ["box_light_r", "box_light_l"]:
			var tot: float = 0.0
			for g in TruckSockets.socket(m["data"], k).get("strips", []):
				tot += StripFit._v(g["a"]).distance_to(StripFit._v(g["b"]))
			check(tot >= perim_side * 0.6, "%s %s: contorno cobre %.1f de %.1f m" % [m["stem"], k, tot, perim_side])
		var rk: Dictionary = TruckSockets.socket(m["data"], "rocket_r")
		check(float(rk.get("length", 0.0)) >= (float(bx["rear_z"]) - float(bx["front_z"])) * 0.8, "%s: foguete quase do comprimento do bau" % m["stem"])


func test_rear_bumper_full_width_and_carries_plate() -> void:
	var t := TruckNode.new()
	t.body_kind = "canter"
	t._ready()                                       # fora da arvore: monta o modelo na hora
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var defs: Array[PartDef] = [gs.part("rb_round_twin")]
	t.apply_loadout(defs)
	var data: Dictionary = TruckSockets.for_model(TruckNode.model_path("canter", ""))
	check(float(TruckSockets.socket(data, "rear_bumper")["width"]) > 2.0, "Canter: para-choque da largura do bau (era 8 cm)")
	var s: Array = TruckPlateSpots.spots(t, t.model, t.shown_cab())
	var holder: MeshInstance3D = t.model.find_child("*deco_plate*", true, false) as MeshInstance3D
	check(holder != null, "caixa da placa montada")
	if holder != null:
		var hb: AABB = PlateSpot.rel_transform(holder, t) * holder.mesh.get_aabb()
		var o: Vector3 = (s[1] as Transform3D).origin
		check(absf(o.x - hb.get_center().x) < 0.02 and absf(o.y - hb.get_center().y) < 0.02 and o.z > hb.end.z, "placa de tras na caixa da placa")
		check(bool(s[2]), "placa de tras visivel")
	t.free()


func test_tail_lamps_light_at_night_and_broken_keeps_geometry() -> void:
	var t := TruckNode.new()
	t._ready()                                       # fora da arvore: monta o modelo na hora
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var defs: Array[PartDef] = [gs.part("rb_target"), gs.part("rocket_led"), gs.part("boxlight_dash_r")]
	t.apply_loadout(defs)
	t.set_lights_on(true)
	var tail: ShaderMaterial = t._lamp_mats.get("lamp_tail") as ShaderMaterial
	check(tail != null, "lanterna da peca vira luz que acende")
	if tail != null:
		check(float(tail.get_shader_parameter("level")) >= 1.0 and float(tail.get_shader_parameter("floor_level")) > 0.0, "acesa a noite, vermelha de dia")
		t.set_light_pattern("sequential")
		check(int(tail.get_shader_parameter("pattern")) == 0, "lanterna nao pisca com o padrao das luzinhas")
	for id in ["rb_target", "rocket_led", "boxlight_dash_r"]:
		t.set_part_state(id, "broken")
		for n in t._acc_nodes[id]:
			var node: Node3D = n
			check(node.visible, "%s quebrada continua no lugar" % id)
			var lit: int = 0
			for mi in node.find_children("*", "MeshInstance3D", true, false):
				var m: MeshInstance3D = mi as MeshInstance3D
				for k in m.mesh.get_surface_count():
					var mat: Material = m.get_active_material(k)
					if mat is ShaderMaterial:
						lit += 1
			check_eq(lit, 0, "%s quebrada: luzes apagadas" % id)
	var rocket: Node3D = t._acc_nodes["rocket_led"][0]
	check(absf(rocket.transform.basis.get_euler().x) < 0.01, "foguete quebrado tomba de lado, sem levantar a ponta")
	var contour: Node3D = t._acc_nodes["boxlight_dash_r"][0]
	check(contour.transform.basis.is_equal_approx(Basis.IDENTITY), "contorno quebrado nao sai do lugar")
	t.free()


func test_box_only_parts_hidden_on_open_bodies() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.profile["money"] = 200000
	check(gs.buy(gs.part("rocket_round")) and gs.install("rocket_round"), "compra e instala o foguete")
	check(gs.installed_part_defs().any(func(d: PartDef) -> bool: return d.id == &"rocket_round"), "bau: foguete conta")
	gs.profile["body"] = "graneleira"
	check(not gs.installed_part_defs().any(func(d: PartDef) -> bool: return d.id == &"rocket_round"), "graneleira: foguete guardado")
	var desc: Dictionary = gs.truck_descriptor()
	check(desc.has("parts"), "descritor da rede")
	gs.new_profile()


func test_bots_and_rivals_use_new_parts() -> void:
	var ids: Array[String] = []
	for f in DirAccess.get_files_at("res://data/rivals/"):
		if not f.trim_suffix(".remap").ends_with(".tres"):
			continue
		var r: RivalDef = load("res://data/rivals/" + f.trim_suffix(".remap")) as RivalDef
		if r != null:
			for p in r.part_ids:
				ids.append(String(p))
	check(ids.any(func(i: String) -> bool: return i.begins_with("rb_") and i not in ["rb_basic", "rb_chrome"]), "algum rival usa para-choque traseiro novo")
	check(ids.any(func(i: String) -> bool: return i.begins_with("rocket_")), "algum rival usa foguete")
	var seen: Dictionary = {}
	for s in 12:
		for p in TruckConfig.bot_part_ids(s):
			seen[p] = true
	check(seen.keys().any(func(i: String) -> bool: return String(i) in REAR), "bots sorteiam para-choque traseiro novo")
