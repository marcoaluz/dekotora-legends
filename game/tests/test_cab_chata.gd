extends TestCase
## Cabine "chata" (T-119): os 3 .glb existem e abrem, tem rodas e todos os pontos de montagem, os materiais sao os
## do caminhao (texturas compartilhadas funcionam), a garagem lista a cabine e o perfil guarda a escolha.

const BODIES: Array[String] = ["base", "leve", "longo"]
## Pontos usados pelas pecas compraveis (catalog.json) e pela decoracao.
const MOUNTS: Array[String] = ["MOUNT_FRONT_BUMPER", "MOUNT_FRONT_GRILLE", "MOUNT_FRONT_ORNAMENT", "MOUNT_VISOR",
		"MOUNT_ROOF", "MOUNT_ROOF_LIGHTS", "MOUNT_BODY_ROOF", "MOUNT_REAR", "MOUNT_REAR_LAMPS", "MOUNT_REAR_PLATE",
		"MOUNT_REAR_PANEL", "MOUNT_REAR_ROOF", "MOUNT_SIDE_R", "MOUNT_SIDE_L", "MOUNT_FENDER_R", "MOUNT_FENDER_L",
		"MOUNT_STEP_R", "MOUNT_STEP_L", "MOUNT_SIDE_TRIM_R", "MOUNT_SIDE_BOX_R", "MOUNT_SIDE_ORNAMENT_R",
		"MOUNT_SIDE_PANEL_R", "MOUNT_MUDFLAP_R", "MOUNT_WHEEL_FRONT_FACE_R", "MOUNT_WHEEL_FRONT_FACE_L"]
## Materiais que o caminhao pode ter (nomes estaveis: tinta, cromo por matcap, luzes, texturas compartilhadas).
const KNOWN_PREFIX: Array[String] = ["paint_", "chrome", "steel", "rubber", "plastic", "glass", "lamp_", "mesh_perf",
		"diamond", "andon_panel", "mural", "grille_honeycomb", "vent_slots", "box_metal"]


func _model(body: String) -> Node3D:
	var path: String = TruckNode.model_path(body, "chata")
	var scene: PackedScene = load(path) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func test_models_exist_and_load() -> void:
	for body in BODIES:
		var path: String = TruckNode.model_path(body, "chata")
		check(path.ends_with("dekotora_truck_%s_chata.glb" % body), "caminho do modelo %s: %s" % [body, path])
		var m: Node3D = _model(body)
		check(m != null, "abre o .glb %s_chata" % body)
		if m == null:
			continue
		var wheels: Array[Node] = m.find_children("wheel_*", "Node3D", true, false)
		check(wheels.size() >= 6, "%s_chata tem rodas (%d)" % [body, wheels.size()])
		check(m.find_children("wheel_f_*", "Node3D", true, false).size() == 2, "%s_chata: 2 rodas dianteiras (esterco)" % body)
		m.free()


func test_mount_points_present_and_on_the_cab() -> void:
	var m: Node3D = _model("base")
	if m == null:
		check(false, "modelo base_chata nao abriu")
		return
	for n in MOUNTS:
		check(m.find_child(n, true, false) != null, "ponto de montagem %s" % n)
	# frente da chata: grade na face (y ~11,37 no Blender = z -11,37 no Godot), visor no teto (~2,8 m), teto no defletor
	var grille: Node3D = m.find_child("MOUNT_FRONT_GRILLE", true, false) as Node3D
	var visor: Node3D = m.find_child("MOUNT_VISOR", true, false) as Node3D
	var roof: Node3D = m.find_child("MOUNT_ROOF", true, false) as Node3D
	if grille != null:
		check_near(grille.position.z, -11.37, 0.1, "grade na face da cabine")
	if visor != null:
		check_near(visor.position.y, 2.8, 0.1, "visor na altura do teto da chata")
	if roof != null:
		check(roof.position.y > 2.9 and roof.position.y < 3.3, "teto (peças) em cima do defletor: %.2f" % roof.position.y)
	m.free()


func test_materials_are_truck_materials_and_budget() -> void:
	for body in BODIES:
		var m: Node3D = _model(body)
		if m == null:
			continue
		var tris: int = 0
		var paint: bool = false
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			if String(mi.name).contains("paint_white"):
				paint = true
			for s in mesh.get_surface_count():
				var mat: Material = mesh.surface_get_material(s)
				var name: String = mat.resource_name if mat != null else ""
				var ok: bool = false
				for p in KNOWN_PREFIX:
					if name.begins_with(p):
						ok = true
				check(ok, "%s_chata: material conhecido (%s)" % [body, name])
				var arrays: Array = mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		check(paint, "%s_chata: malha paint_white (pintura dos rivais)" % body)
		var limit: int = 90000 if body == "longo" else 78000          # base: bau premium (T-136) +4,5 mil
		check(tris > 40000 and tris < limit, "%s_chata: %d triangulos (limite %d)" % [body, tris, limit])
		m.free()


func test_shared_textures_apply() -> void:
	var m: Node3D = _model("base")
	if m == null:
		check(false, "modelo base_chata nao abriu")
		return
	TruckTextures.apply(m)
	var found: bool = false
	for mi in m.find_children("*paint_white_panel*", "MeshInstance3D", true, false):
		var mat: StandardMaterial3D = (mi as MeshInstance3D).get_active_material(0) as StandardMaterial3D
		if mat != null and mat.albedo_texture != null and mat.albedo_texture.get_width() > 4:
			found = true
	check(found, "pintura da chata recebe a textura compartilhada (nao a miniatura 4x4)")
	m.free()


func test_garage_lists_chata_and_profile_keeps_it() -> void:
	check(TruckNode.CABS.has("chata"), "garagem lista a cabine chata")
	check(Tr.t("cab.chata") != "cab.chata", "nome da cabine em pt-BR")
	check(Tr.t("cab.desc.chata") != "cab.desc.chata", "descricao da cabine em pt-BR")
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.profile["cab"] = "chata"
	gs.profile["body"] = "leve"
	gs.save_profile()
	gs.profile = {}                             # esquece na memoria (new_profile() gravaria por cima do arquivo)
	gs.load_profile()
	check_eq(String(gs.profile.get("cab", "")), "chata", "perfil salvo e carregado guarda a cabine chata")
	check_eq(TruckNode.model_path(String(gs.profile["body"]), String(gs.profile["cab"])),
			"res://assets/vehicles/dekotora/truck/dekotora_truck_leve_chata.glb", "perfil aponta para o .glb certo")
