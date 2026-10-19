extends TestCase
## Carroceria graneleira (T-145): os 4 .glb (uma por cabine) abrem com rodas, pontos de montagem e materiais nossos;
## a simulacao usa o BodyDef dela; a regra carga x carroceria (bau fechado x aberta) bloqueia com o motivo certo; o
## quadro de fretes sempre tem um frete possivel para cada modelo; perfil, migracao e descritor de rede levam o modelo.

const BODIES: Array[String] = ["canter", "leve", "base", "longo", "graneleira"]
const TRIS_LIMIT: int = 80000                       # base_chata (bau premium) tem ~77 mil
const MOUNTS: Array[String] = ["MOUNT_FRONT_BUMPER", "MOUNT_FRONT_GRILLE", "MOUNT_VISOR", "MOUNT_ROOF", "MOUNT_ROOF_LIGHTS",
		"MOUNT_BODY_ROOF", "MOUNT_REAR", "MOUNT_REAR_LAMPS", "MOUNT_REAR_PLATE", "MOUNT_REAR_PANEL", "MOUNT_REAR_ROOF",
		"MOUNT_SIDE_R", "MOUNT_SIDE_L", "MOUNT_SIDE_TRIM_R", "MOUNT_SIDE_BOX_R", "MOUNT_SIDE_ORNAMENT_R", "MOUNT_SIDE_PANEL_R",
		"MOUNT_SIDE_PANEL_L", "MOUNT_MUDFLAP_R", "MOUNT_WHEEL_FRONT_FACE_R", "MOUNT_WHEEL_REAR_FACE_R", "MOUNT_STEP_R"]
const KNOWN_PREFIX: Array[String] = ["paint_", "chrome", "steel", "rubber", "plastic", "glass", "lamp_", "mesh_perf",
		"diamond", "andon_panel", "mural", "grille_honeycomb", "vent_slots"]
const CLOSED: Array[String] = ["eletronicos", "alimentos", "ceramica"]
const BULK: Array[String] = ["graos", "brita"]
const EITHER: Array[String] = ["madeira", "aco", "pecas_industriais"]


func _gs() -> Node:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	return gs


func _tris(root: Node) -> int:
	var n: int = 0
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			n += (idx as PackedInt32Array).size() / 3 if idx != null else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func test_models_load_for_every_cab() -> void:
	for cab in CabCatalog.IDS:
		var path: String = TruckNode.model_path("graneleira", cab)
		check(path.ends_with("dekotora_truck_graneleira_%s.glb" % cab), "caminho da graneleira com cabine %s" % cab)
		var scene: PackedScene = load(path) as PackedScene
		check(scene != null, "abre %s" % path)
		if scene == null:
			continue
		var m: Node3D = scene.instantiate() as Node3D
		check_eq(m.find_children("wheel_f_*", "Node3D", true, false).size(), 2, "%s: 2 rodas dianteiras" % cab)
		check_eq(m.find_children("wheel_r_*", "Node3D", true, false).size(), 8, "%s: 2 eixos traseiros com rodado duplo" % cab)
		for n in MOUNTS:
			check(m.find_child(n, true, false) != null, "%s: ponto de montagem %s" % [cab, n])
		var tris: int = _tris(m)
		check(tris > 40000 and tris <= TRIS_LIMIT, "%s: %d triangulos (limite %d)" % [cab, tris, TRIS_LIMIT])
		var mural: bool = false
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var mat: Material = mesh.surface_get_material(s)
				var mn: String = mat.resource_name if mat != null else ""
				mural = mural or mn == "mural"
				var known: bool = false
				for p in KNOWN_PREFIX:
					known = known or mn.begins_with(p)
				check(known, "%s: material nosso (%s)" % [cab, mn])
		check(mural, "%s: tampas com o material do mural (PNG trocavel)" % cab)
		m.free()


func test_mounts_moved_to_open_body() -> void:
	var m: Node3D = (load(TruckNode.model_path("graneleira", "chata")) as PackedScene).instantiate() as Node3D
	var roof: Node3D = m.find_child("MOUNT_BODY_ROOF", true, false) as Node3D
	var panel: Node3D = m.find_child("MOUNT_SIDE_PANEL_R", true, false) as Node3D
	var bumper: Node3D = m.find_child("MOUNT_FRONT_BUMPER", true, false) as Node3D
	check(roof.position.y > 2.9 and roof.position.y < 3.2, "teto = topo da lona (~3,1 m): %.2f" % roof.position.y)
	check(panel.position.y > 1.2 and panel.position.y < 1.8, "painel lateral nas tampas (~1,5 m): %.2f" % panel.position.y)
	var base: Node3D = (load(TruckNode.model_path("base", "chata")) as PackedScene).instantiate() as Node3D
	var bb: Node3D = base.find_child("MOUNT_FRONT_BUMPER", true, false) as Node3D
	check_near(bumper.position.z, bb.position.z, 0.01, "mesmo comprimento do bau medio (para-choque no mesmo lugar)")
	base.free()
	check_near(float(TruckNode.LENGTH_DELTA["graneleira"]), 0.0, 0.001, "LENGTH_DELTA = bau medio")
	m.free()


func test_truck_node_builds_and_wheels_spin() -> void:
	var t := TruckNode.new()
	t.body_kind = "graneleira"
	t.cab_kind = "jac"
	t._ready()
	check(t.model != null, "TruckNode monta a graneleira")
	var w: Node3D = t.model.find_children("wheel_r_*", "Node3D", true, false)[0] as Node3D
	var before: Basis = w.basis
	t.animate(10.0, 0.1)
	check(not w.basis.is_equal_approx(before), "rodas giram com a velocidade")
	t.free()


func test_body_def_in_simulation() -> void:
	var d: BodyDef = BodyDef.find("graneleira")
	check(d != null, "data/bodies/graneleira.tres")
	check_eq(d.cargo_kind, &"open", "graneleira = carroceria aberta")
	check_eq(Contracts.capacity_t("graneleira"), 14.0, "graneleira leva 14 t")
	for b in ["canter", "leve", "base", "longo"]:
		check_eq(Contracts.body_kind(b), &"box", "%s = bau fechado" % b)
	var t := TruckSim.new()
	TruckConfig.apply(t, {"parts": [], "body": "graneleira"})
	var tb := TruckSim.new()
	TruckConfig.apply(tb, {"parts": [], "body": "base"})
	check_near(t.length, 12.0, 0.001, "hitbox de 12 m (igual ao bau medio)")
	check_near(tb.mass - t.mass, 500.0, 0.01, "500 kg mais leve vazia que o bau medio")


func test_cargo_rule_by_body_kind() -> void:
	for id in CLOSED + BULK + EITHER:
		var cg: CargoDef = load("res://data/cargo/%s.tres" % id) as CargoDef
		check(cg != null, "carga %s existe" % id)
		var want: StringName = &"box" if id in CLOSED else (&"open" if id in BULK else &"any")
		check_eq(cg.needs, want, "%s exige %s" % [id, want])
		var c: Dictionary = {"cargo": id, "weight_t": cg.weight_min_t}            # sem "needs": perfil antigo
		check_eq(Contracts.missing_body(c, "graneleira"), &"box" if want == &"box" else &"", "%s na graneleira" % id)
		check_eq(Contracts.missing_body(c, "base"), &"open" if want == &"open" else &"", "%s no bau medio" % id)


func test_block_reasons() -> void:
	var gs: Node = _gs()
	gs.profile["body"] = "base"
	check_eq(gs.contract_block_reason({"cargo": "graos", "needs": "open", "weight_t": 10.0, "route": "kanto_1_coast"}),
			"PRECISA DE GRANELEIRA", "graos no bau")
	gs.profile["body"] = "graneleira"
	check_eq(gs.contract_block_reason({"cargo": "eletronicos", "needs": "box", "weight_t": 4.0, "route": "kanto_1_coast"}),
			"PRECISA DE BAÚ", "eletronicos na graneleira")
	check_eq(gs.contract_block_reason({"cargo": "aco", "needs": "any", "weight_t": 15.0, "route": "kanto_1_coast"}),
			"PESADA DEMAIS", "15 t nao cabe na graneleira")
	check_eq(gs.contract_block_reason({"cargo": "madeira", "needs": "any", "weight_t": 12.0, "route": "kanto_1_coast"}),
			"", "madeira 12 t vai na graneleira")
	check_eq(gs.contract_block_reason({"cargo": "brita", "weight_t": 12.0, "route": "kanto_1_coast"}),
			"", "contrato sem campo needs usa a carga (brita) e serve")
	gs.new_profile()


func test_board_always_has_a_possible_contract_per_body() -> void:
	var routes: Array[RouteDef] = FreightMarket.all_routes()
	var all := func(_r: RouteDef) -> bool: return true
	for body in BODIES:
		for s in 60:
			var list: Array[Dictionary] = Contracts.generate(s * 7919 + 3, routes, all, body)
			for r in routes:
				var ok: bool = false
				for c in list:
					if String(c["route"]) == String(r.id) and Contracts.fits(c, body):
						ok = true
				check(ok, "%s, semente %d: trecho %s tem frete possivel" % [body, s, r.id])
	var g: Array[Dictionary] = Contracts.generate(11, routes, all, "graneleira")
	check(g[0].has("needs"), "contrato novo traz o tipo de carroceria")


func test_switching_body_refreshes_board_when_nothing_fits() -> void:
	var gs: Node = _gs()
	gs.profile["body"] = "graneleira"
	var st: Dictionary = gs.contracts_state()
	st["list"] = [{"id": "x", "route": "kanto_1_coast", "origin": "A", "destination": "B", "cargo": "eletronicos", "needs": "box",
			"weight_t": 4.0, "reward": 1000, "fragility": 1.8, "trait": "fragile", "deadline_s": 133.0}]
	check(not gs.board_serves_body(st["list"]), "quadro so com eletronicos nao serve a graneleira")
	var board: Array = gs.contract_board()
	check(gs.board_serves_body(board), "o quadro e sorteado de novo para a graneleira")
	var any_ok: bool = false
	for c in board:
		any_ok = any_ok or gs.contract_block_reason(c) == ""
	check(any_ok, "ha um frete que pode ser aceito agora")
	gs.profile["body"] = "leve"
	check(gs.board_serves_body(gs.contract_board()), "voltar para o bau leve tambem tem frete possivel")
	gs.new_profile()


func test_profile_migration_and_descriptor() -> void:
	var gs: Node = _gs()
	gs.profile["body"] = "graneleira"
	gs.save_profile()
	gs.profile = {}
	gs.load_profile()
	check_eq(String(gs.profile.get("body", "")), "graneleira", "perfil guarda a graneleira")
	check_eq(String(gs.truck_descriptor().get("body", "")), "graneleira", "descritor (servidor/rede) leva o modelo")
	check(not gs.migrate_profile(), "perfil atual nao muda na migracao")
	gs.profile["body"] = "tanque_inexistente"
	gs.profile["contracts"] = {"seed": 5, "done": [], "list": [{"route": "kanto_1_coast", "cargo": "graos", "weight_t": 9.0}]}
	check(gs.migrate_profile(), "migracao corrige o perfil")
	check_eq(String(gs.profile["body"]), "base", "modelo desconhecido vira o bau medio")
	check_eq(String(gs.profile["contracts"]["list"][0]["needs"]), "open", "contrato antigo ganha o tipo de carroceria")
	gs.new_profile()


func test_garage_lists_graneleira_and_bots_use_it() -> void:
	var garage: Dictionary = (load("res://scripts/ui/garage_screen.gd") as GDScript).get_script_constant_map()
	check((garage["BODIES"] as Array).has("graneleira"), "garagem lista a graneleira (aba Modelo)")
	var race: Dictionary = (load("res://scripts/road3d/race_scene_3d.gd") as GDScript).get_script_constant_map()
	check((race["RIVAL_BODIES"] as Array).has("graneleira"), "bots da corrida offline usam a graneleira")
	for b in garage["BODIES"]:
		check(BodyDef.find(String(b)) != null, "modelo da garagem tem BodyDef: %s" % b)
