extends TestCase
## Caminhoes de homenagem (T-218): os 5 abrem com rodas, pontos de montagem e materiais nossos, tem 3 LODs, encaixes
## medidos sem problema; T-240: com QUALQUER cabine (kit cabine + carroceria); nenhum texto de marca real nos nomes; o mural do baú rosa e o proprio (com emissao);
## o tanque leva combustivel e so ele; compra na garagem (preco/Fama); rivais e bots podem receber os modelos novos.

const IDS: Array[String] = ["alubox", "tarp", "pinkbox", "tanker", "dump"]
const MOUNTS: Array[String] = ["MOUNT_FRONT_BUMPER", "MOUNT_FRONT_GRILLE", "MOUNT_VISOR", "MOUNT_ROOF", "MOUNT_ROOF_LIGHTS",
		"MOUNT_BODY_ROOF", "MOUNT_REAR", "MOUNT_REAR_LAMPS", "MOUNT_REAR_PLATE", "MOUNT_REAR_PANEL", "MOUNT_REAR_ROOF",
		"MOUNT_SIDE_R", "MOUNT_SIDE_L", "MOUNT_SIDE_PANEL_R", "MOUNT_SIDE_PANEL_L", "MOUNT_MUDFLAP_R",
		"MOUNT_WHEEL_FRONT_FACE_R", "MOUNT_WHEEL_REAR_FACE_R", "MOUNT_STEP_R", "MOUNT_CAB_SIDE_R"]
const KNOWN_PREFIX: Array[String] = ["paint_", "chrome", "steel", "rubber", "plastic", "glass", "lamp_", "mesh_perf",
		"diamond", "andon_panel", "mural", "vent_slots", "box_alu", "box_pink", "tarp", "rope", "band_white", "tank_shell",
		"dump_bed"]
## Nomes de marcas reais que nao podem aparecer em nenhum nome de no/material/arquivo (minusculas).
const BANNED: Array[String] = ["mitsubishi", "fuso", "nissan", "isuzu", "hino", "ud ", "toyota", "volvo", "scania",
		"kenworth", "freightliner", "great"]


func _gs() -> Node:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	return gs


func _tris(root: Node) -> int:
	var n: int = 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
			n += idx.size() / 3
	return n


func test_models_lods_and_mounts() -> void:
	for id in IDS:
		var bd: BodyDef = BodyDef.find(id)
		check(bd != null, "BodyDef %s existe" % id)
		check(not TruckNode.FIXED_CAB.has(id), "%s: cabine trocavel (T-240)" % id)
		check(bd.factory_cab in CabCatalog.IDS, "%s: cabine de fabrica %s existe" % [id, bd.factory_cab])
		for cab in CabCatalog.IDS:
			var tag: String = "%s_%s" % [id, cab]
			var path: String = TruckNode.model_path(id, cab)
			check(path.ends_with("dekotora_truck_%s.glb" % tag), "caminho do %s: %s" % [tag, path])
			check(TruckKit.uses_kit(id, cab) and TruckNode.model_exists(id, cab), "%s: montado pelo kit" % tag)
			var m: Node3D = TruckNode.instantiate_model(id, cab)
			check(m != null, "abre %s" % tag)
			if m == null:
				continue
			check(m.find_children("wheel_f_*", "Node3D", true, false).size() == 2, "%s: 2 rodas dianteiras" % tag)
			check(m.find_children("wheel_r_*", "Node3D", true, false).size() == 8, "%s: rodado duplo em 2 eixos" % tag)
			for n in MOUNTS:
				check(m.find_children(n, "Node3D", true, false).size() == 1, "%s: um ponto de montagem %s" % [tag, n])
			var t0: int = _tris(m)
			check(t0 > 20000 and t0 < 80000, "%s LOD0 com %d triangulos (limite 80 mil, como o baú medio)" % [tag, t0])
			for mi in m.find_children("*", "MeshInstance3D", true, false):
				for s in (mi as MeshInstance3D).mesh.get_surface_count():
					var mat: Material = (mi as MeshInstance3D).mesh.surface_get_material(s)
					var mn: String = mat.resource_name if mat != null else ""
					var ok: bool = false
					for p in KNOWN_PREFIX:
						ok = ok or mn.begins_with(p)
					check(ok, "%s: material nosso (%s)" % [tag, mn])
			var prev: int = t0
			for k in [1, 2]:
				var lod: Node3D = TruckKit.lod(id, cab, k)
				check(lod != null, "%s tem LOD%d" % [tag, k])
				if lod == null:
					continue
				var tk: int = _tris(lod)
				check(tk < prev * 0.5, "%s LOD%d mais leve (%d < metade de %d)" % [tag, k, tk, prev])
				check(lod.find_children("wheel_*", "Node3D", true, false).is_empty(), "%s LOD%d sem nos wheel_* (nao gira)" % [tag, k])
				check(lod.find_children("MOUNT_*", "Node3D", true, false).is_empty(), "%s LOD%d sem pontos de montagem" % [tag, k])
				prev = tk
				lod.free()
			m.free()


func test_no_real_brand_names() -> void:
	for id in IDS:
		var names: Array[String] = [id, String(BodyDef.find(id).factory_cab), Tr.t("body." + id), Tr.t("body.desc." + id)]
		for cab in CabCatalog.IDS:
			var m: Node3D = TruckNode.instantiate_model(id, cab)
			for n in m.find_children("*", "Node", true, false):
				names.append(String(n.name))
			m.free()
		for s in names:
			for b in BANNED:
				check(not s.to_lower().contains(b), "%s: nome sem marca real (%s contem %s)" % [id, s, b])


func test_sockets_measured_without_problems() -> void:
	for id in IDS:
		for cab in CabCatalog.IDS:
			var tag: String = "%s_%s" % [id, cab]
			var data: Dictionary = TruckSockets.for_model(TruckNode.model_path(id, cab))
			check(not data.is_empty(), "%s: encaixes medidos" % tag)
			check((data.get("design_problems", ["?"]) as Array).is_empty(), "%s: sem problemas de projeto" % tag)
			check(TruckSockets.socket(data, "andon").has("anchor"), "%s: deque tem lugar no teto" % tag)
			check(TruckSockets.socket(data, "visor").has("anchor"), "%s: viseira tem lugar na testa" % tag)
			check(String(data.get("cab", "")) == cab, "%s: cabine do JSON" % tag)


func test_truck_node_lods_and_own_mural() -> void:
	var t := TruckNode.new()
	t.body_kind = "pinkbox"
	t.cab_kind = "flat_wide"
	t._ready()                                       # fora da arvore: monta o modelo na hora
	check(t.model != null, "TruckNode abre o baú rosa")
	check(t.lod_count() == 2, "TruckNode poe os 2 LODs leves (%d)" % t.lod_count())
	check(t.shown_cab() == "flat_wide", "cabine mostrada = a escolhida")
	var mural_ok: bool = false
	for mi in t.model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat: StandardMaterial3D = m.get_surface_override_material(s) as StandardMaterial3D
			if mat != null and mat.albedo_texture != null and mat.albedo_texture.resource_path.ends_with("mural_geisha.png"):
				mural_ok = mat.emission_texture != null and mat.emission_texture.resource_path.ends_with("mural_geisha_emit.png")
	check(mural_ok, "baú rosa usa o mural proprio com o mapa de emissao dos neons")
	t.set_paint_color(Color.RED)
	t.set_mural_glow(0.8)
	var lod0_end: float = -1.0
	for mi in t.model.get_child(0).find_children("*", "MeshInstance3D", true, false):
		lod0_end = (mi as MeshInstance3D).visibility_range_end
		break
	check_near(lod0_end, TruckNode.LOD_RANGES[0], 0.01, "LOD0 some a partir de %.0f m" % TruckNode.LOD_RANGES[0])
	t.free()
	var old := TruckNode.new()                       # caminhao antigo: sem LODs (nada mudou)
	old.body_kind = "base"
	old._ready()
	check(old.lod_count() == 0, "baú medio continua sem LODs extras")
	old.free()


func test_tanker_carries_fuel_and_only_it() -> void:
	var fuel: Dictionary = {"cargo": "combustivel", "needs": "tank", "weight_t": 10.0}
	check(Contracts.fits(fuel, "tanker"), "tanque leva combustivel")
	for b in ["base", "graneleira", "alubox", "tarp", "dump"]:
		check(not Contracts.fits(fuel, b), "%s nao leva combustivel" % b)
	check(Contracts.missing_body({"needs": "open", "weight_t": 9.0}, "tanker") == &"open", "tanque nao leva granel")
	check(Contracts.fits({"needs": "any", "weight_t": 9.0}, "tanker"), "tanque leva carga comum")
	check(Contracts.body_kind("dump") == &"open" and Contracts.body_kind("tarp") == &"open", "caçamba e lona = abertas")
	check(Contracts.body_kind("alubox") == &"box" and Contracts.body_kind("pinkbox") == &"box", "baús = fechados")


func test_buy_body_in_garage() -> void:
	var gs: Node = _gs()
	check(not gs.body_owned("pinkbox"), "perfil novo nao tem o baú rosa")
	check(gs.body_owned("base") and gs.body_owned("canter"), "modelos antigos sao de graca")
	check(gs.can_buy_body("alubox") != "", "sem Fama nao compra (alubox pede %d)" % BodyDef.find("alubox").fame_required)
	gs.profile["fame"] = 500
	gs.profile["money"] = 1000000
	check(gs.buy_body("alubox"), "compra o baú de aluminio")
	check(gs.body_owned("alubox") and String(gs.profile["body"]) == "alubox", "ficou com o modelo e escolheu")
	check(String(gs.profile["paint"]) == BodyDef.find("alubox").default_paint, "pintou na cor de fabrica")
	check(int(gs.profile["money"]) == 1000000 - BodyDef.find("alubox").price, "descontou o preco")
	check(String(gs.truck_descriptor()["body"]) == "alubox", "descritor de rede leva o modelo comprado")
	gs.profile["body"] = "tanker"                        # escolhido sem comprar (perfil adulterado)
	check(String(gs.truck_descriptor()["body"]) == "base", "modelo nao comprado vira o baú medio no descritor")
	gs.migrate_profile()
	check(String(gs.profile["body"]) == "base", "migracao tira o modelo nao comprado")
	check(gs.apply_action("buy_body", "dump"), "acao de rede buy_body (servidor)")
	gs.new_profile()


func test_rivals_and_bots_can_get_new_trucks() -> void:
	for id in IDS:
		check(BodyDef.BOT_POOL.has(id), "%s pode ser sorteado para bots/rival" % id)
	var fixed: int = 0
	for f in DirAccess.get_files_at("res://data/rivals/"):
		var rv: RivalDef = load("res://data/rivals/" + f.trim_suffix(".remap")) as RivalDef
		if rv != null and rv.body != "":
			check(BodyDef.find(rv.body) != null, "rival %s com modelo valido (%s)" % [rv.id, rv.body])
			fixed += 1
	check(fixed >= 3, "pelo menos 3 rivais com caminhao de homenagem (%d)" % fixed)
	check(Protocol.VERSION >= 14, "protocolo 14 (T-218: modelos novos e bots com modelo no setup)")
