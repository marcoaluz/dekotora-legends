extends TestCase
## Cabines so de arquivo (T-129): as 4 cabines (chata, jac, curta, americana) existem nos 3 baus, abrem, tem rodas,
## pontos de montagem e materiais nossos; a jac e claramente mais alta que a curta; a americana tem o bico longo
## (eixo dianteiro mais a frente); as 4 cabines feitas por codigo sumiram e perfis/descritores antigos migram.

const BODIES: Array[String] = ["base", "leve", "longo"]
const REMOVED: Array[String] = ["padrao", "classica", "aero", "alta"]
const MOUNTS: Array[String] = ["MOUNT_FRONT_BUMPER", "MOUNT_FRONT_GRILLE", "MOUNT_FRONT_ORNAMENT", "MOUNT_VISOR",
		"MOUNT_ROOF", "MOUNT_ROOF_LIGHTS", "MOUNT_BODY_ROOF", "MOUNT_REAR", "MOUNT_REAR_LAMPS", "MOUNT_REAR_PLATE",
		"MOUNT_REAR_PANEL", "MOUNT_REAR_ROOF", "MOUNT_SIDE_R", "MOUNT_SIDE_L", "MOUNT_FENDER_R", "MOUNT_FENDER_L",
		"MOUNT_STEP_R", "MOUNT_STEP_L", "MOUNT_SIDE_TRIM_R", "MOUNT_SIDE_BOX_R", "MOUNT_SIDE_ORNAMENT_R",
		"MOUNT_SIDE_PANEL_R", "MOUNT_MUDFLAP_R", "MOUNT_WHEEL_FRONT_FACE_R", "MOUNT_WHEEL_FRONT_FACE_L",
		"MOUNT_WHEEL_REAR_FACE_R", "MOUNT_CAB_SIDE_R", "MOUNT_CAB_SIDE_L"]
const KNOWN_PREFIX: Array[String] = ["paint_", "chrome", "steel", "rubber", "plastic", "glass", "lamp_", "mesh_perf",
		"diamond", "andon_panel", "mural", "grille_honeycomb", "vent_slots"]
const TRIS_LIMIT: Dictionary = {"leve": 66000, "base": 78000, "longo": 92000}


func _load(body: String, cab: String) -> Node3D:
	var scene: PackedScene = load(TruckNode.model_path(body, cab)) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func _mount(m: Node3D, n: String) -> Node3D:
	return m.find_child(n, true, false) as Node3D


func _tris_and_materials(m: Node3D, tag: String) -> int:
	var tris: int = 0
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (mi as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			var mat: Material = mesh.surface_get_material(s)
			var name: String = mat.resource_name if mat != null else ""
			var ok: bool = false
			for p in KNOWN_PREFIX:
				if name.begins_with(p):
					ok = true
			check(ok, "%s: material nosso (%s)" % [tag, name])
			var arrays: Array = mesh.surface_get_arrays(s)
			var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return tris


func test_catalog_ids_and_normalize() -> void:
	check_eq(CabCatalog.IDS.size(), 4, "4 cabines de arquivo")
	check_eq(TruckNode.CABS, CabCatalog.IDS, "a garagem lista as cabines do catalogo")
	check(CabCatalog.is_valid(CabCatalog.DEFAULT), "cabine padrao existe")
	check_eq(CabCatalog.DEFAULT, "chata", "perfil novo comeca com a cara chata")
	for id in CabCatalog.IDS:
		check_eq(CabCatalog.normalize(id), id, "%s continua %s" % [id, id])
		check(Tr.t("cab." + id) != "cab." + id and Tr.t("cab.desc." + id) != "cab.desc." + id, "nome e descricao pt-BR de %s" % id)
	check_eq(CabCatalog.normalize("padrao"), "chata", "padrao -> chata")
	check_eq(CabCatalog.normalize("classica"), "chata", "classica -> chata")
	check_eq(CabCatalog.normalize("alta"), "chata", "alta -> chata")
	check_eq(CabCatalog.normalize("aero"), "jac", "aero -> jac")
	check_eq(CabCatalog.normalize("nao_existe"), CabCatalog.DEFAULT, "id desconhecido -> padrao")
	check_eq(CabCatalog.normalize(""), CabCatalog.DEFAULT, "vazio -> padrao")
	check_eq(CabCatalog.normalize(null), CabCatalog.DEFAULT, "nulo -> padrao")


func test_all_models_load_with_wheels_mounts_and_budget() -> void:
	for body in BODIES:
		for cab in CabCatalog.IDS:
			var tag: String = "%s_%s" % [body, cab]
			var path: String = TruckNode.model_path(body, cab)
			check(path.ends_with("dekotora_truck_%s.glb" % tag), "caminho %s: %s" % [tag, path])
			var m: Node3D = _load(body, cab)
			check(m != null, "abre %s" % tag)
			if m == null:
				continue
			check(m.find_children("wheel_*", "Node3D", true, false).size() >= 6, "%s tem rodas" % tag)
			check_eq(m.find_children("wheel_f_*", "Node3D", true, false).size(), 2, "%s: 2 rodas dianteiras" % tag)
			for n in MOUNTS:
				check(_mount(m, n) != null, "%s: ponto %s" % [tag, n])
			var paint: bool = not m.find_children("*paint_white*", "MeshInstance3D", true, false).is_empty()
			check(paint, "%s: pintura tingivel (paint_white)" % tag)
			var tris: int = _tris_and_materials(m, tag)
			check(tris > 40000 and tris < int(TRIS_LIMIT[body]), "%s: %d triangulos (limite %d)" % [tag, tris, TRIS_LIMIT[body]])
			m.free()


func test_jac_is_taller_than_curta_and_americana_has_long_nose() -> void:
	var jac: Node3D = _load("base", "jac")
	var curta: Node3D = _load("base", "curta")
	var am: Node3D = _load("base", "americana")
	var chata: Node3D = _load("base", "chata")
	if jac == null or curta == null or am == null or chata == null:
		check(false, "modelos nao abriram")
		return
	var hj: float = _mount(jac, "MOUNT_ROOF").position.y
	var hc: float = _mount(curta, "MOUNT_ROOF").position.y
	check(hj > hc + 0.25, "jac (%.2f m) bem mais alta que a curta (%.2f m)" % [hj, hc])
	check(hj > 2.8 and hj < 3.2, "teto da jac perto do teto do bau (3,2 m): %.2f" % hj)
	# frente: Godot -Z = frente; CAB_FRONT_DELTA bate com o para-choque de cada cabine
	for pair in [[jac, "jac"], [am, "americana"]]:
		var m: Node3D = pair[0]
		var z: float = _mount(m, "MOUNT_FRONT_BUMPER").position.z
		var expect: float = -11.5 - float(TruckNode.CAB_FRONT_DELTA.get(String(pair[1]), 0.0))
		check(absf(z - expect) < 0.2, "%s: para-choque em %.2f (esperado ~%.2f)" % [pair[1], z, expect])
	var wf_am: Node3D = am.find_child("wheel_f_R", true, false) as Node3D
	var wf_ch: Node3D = chata.find_child("wheel_f_R", true, false) as Node3D
	check(wf_am.position.z < wf_ch.position.z - 0.3, "americana: eixo dianteiro mais a frente (%.2f vs %.2f)" % [wf_am.position.z, wf_ch.position.z])
	check_near(_mount(am, "MOUNT_WHEEL_FRONT_FACE_R").position.z, wf_am.position.z, 0.02, "calota segue o eixo da americana")
	var wf_jac: Node3D = jac.find_child("wheel_f_R", true, false) as Node3D
	check_near(wf_jac.position.y, 0.55, 0.02, "jac: roda dianteira maior (arco do JAC)")
	for m in [jac, curta, am, chata]:
		(m as Node3D).free()


func test_removed_code_cabs_are_gone() -> void:
	for body in BODIES:
		check(not ResourceLoader.exists("res://assets/vehicles/dekotora/truck/dekotora_truck_%s.glb" % body), "sem o .glb antigo %s (cabine padrao)" % body)
		for cab in REMOVED:
			check(not ResourceLoader.exists("res://assets/vehicles/dekotora/truck/dekotora_truck_%s_%s.glb" % [body, cab]), "sem %s_%s" % [body, cab])
			check(not TruckNode.CABS.has(cab), "garagem nao lista %s" % cab)
			check(ResourceLoader.exists(TruckNode.model_path(body, cab)), "id antigo %s ainda abre um modelo (%s)" % [cab, TruckNode.model_path(body, cab)])
	check(ResourceLoader.exists(TruckNode.MODEL_PATH), "modelo padrao (acessorios) existe")
	check(ResourceLoader.exists(TruckNode.MODEL_PATHS["carreta"]), "carreta guardada ainda existe")


func test_old_profile_migrates() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	check_eq(String(gs.profile.get("cab", "")), CabCatalog.DEFAULT, "perfil novo ja vem com a cabine padrao")
	for old in REMOVED:
		gs.profile["cab"] = old
		gs.profile["body"] = "leve"
		gs.save_profile()
		var rev: int = int(gs.profile["rev"])
		gs.profile = {}
		gs.load_profile()
		check_eq(String(gs.profile["cab"]), CabCatalog.normalize(old), "perfil antigo com %s carrega com %s" % [old, CabCatalog.normalize(old)])
		check_eq(int(gs.profile["rev"]), rev, "migrar nao muda rev (sincronizacao)")
		check_eq(int(gs.profile["money"]), 50000, "resto do perfil intacto")
		check(ResourceLoader.exists(TruckNode.model_path(String(gs.profile["body"]), String(gs.profile["cab"]))), "modelo do perfil migrado existe")
	gs.profile.erase("cab")                          # perfil de antes da escolha de cabine
	gs.save_profile()
	gs.profile = {}
	gs.load_profile()
	check_eq(String(gs.profile["cab"]), CabCatalog.DEFAULT, "perfil sem cabine ganha a padrao")
	gs.profile["cab"] = "aero"
	check_eq(String(gs.truck_descriptor()["cab"]), "jac", "descritor de rede leva a cabine ja migrada")
	gs.new_profile()


func test_server_profiles_and_descriptors_migrate() -> void:
	var dir: String = "user://test_profiles_t129/"
	var d := DirAccess.open("user://")
	if d != null and d.dir_exists("test_profiles_t129"):
		var sub := DirAccess.open(dir)
		for f in sub.get_files():
			sub.remove(f)
	var store := ProfileStore.new(dir)
	var gs: Node = store.get_profile("EEEE6666")
	gs.profile["cab"] = "classica"                   # perfil guardado no servidor por uma versao antiga
	gs.save_profile()
	store.release_all()
	var store2 := ProfileStore.new(dir)
	var gs2: Node = store2.get_profile("EEEE6666")
	check_eq(String(gs2.profile["cab"]), "chata", "perfil do servidor com cabine antiga carrega migrado")
	var offline: Dictionary = gs2.profile.duplicate(true)
	offline["cab"] = "aero"
	offline["rev"] = int(gs2.profile["rev"]) + 3
	var after: Node = store2.sync_from_client("EEEE6666", offline)
	check_eq(String(after.profile["cab"]), "jac", "perfil antigo vindo do cliente e migrado ao ser adotado")
	store2.release_all()
	# descritor recebido de um cliente antigo (sem "cab" ou com id removido) e o grid online
	check_eq(CabCatalog.normalize(TruckConfig.basic_descriptor().get("cab", "")), CabCatalog.DEFAULT, "bot da rede sem cabine -> padrao")
	var node := TruckNode.new()
	node.cab_kind = "alta"
	check_eq(node.shown_cab(), "chata", "TruckNode com id antigo mostra a cabine nova")
	node.free()
