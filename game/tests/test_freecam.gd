extends TestCase
## T-181: camera livre de exploracao. Ligar/desligar nao muda a simulacao (a corrida congela e volta no mesmo
## ponto), teleporte por km, nome do arquivo do print, quem pode usar (nunca online), a opcao salva e a mira
## (nome do objeto e o .glb de origem: cena instanciada, MultiMesh e lote MeshBatch).

const IN_TREE := true          # monta a corrida de verdade (race3d.tscn) e precisa do /root/...
const GLB := "res://assets/scenery/tree_pine.glb"


func _race(route_id: String) -> Node:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.pending_route = load("res://data/routes/%s.tres" % route_id) as RouteDef
	gs.pending_contract = {}
	var scene: Node = (load("res://scenes/race/race3d.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	return scene


## Tudo o que a simulacao guarda e que muda com o tempo (caminhoes, transito, relogio).
func _digest(sim: RaceSim) -> Array:
	var out: Array = [sim.time, sim.tick, sim.events.size()]
	for t in sim.trucks:
		out.append_array([t.z, t.x, t.speed, t.lateral_vel, t.rpm, t.gear, t.boost])
	for c in sim.traffic.cars:
		out.append_array([c.z, c.x, c.speed, c.lane])
	return out


func test_toggle_freezes_sim_and_returns_to_same_camera() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.last_duel_key = ""
	var race: Node = _race("kanto_1_coast")
	var fc: Freecam = race._freecam
	check(fc != null, "build de debug (testes): a camera livre existe na corrida offline")
	if fc == null:
		race.free()
		return
	if race._intro != null and race._intro.running():
		race._intro.skip()
	for n in 45:                                     # contagem de 3 s + ~1,5 s de corrida
		race._process(0.1)
	var sim: RaceSim = race.sim
	check(sim.time > 0.5, "a corrida andou antes (%.2f s)" % sim.time)
	var before: Array = _digest(sim)
	var acc: float = race._acc
	var cam_xf: Transform3D = race._cam.global_transform
	var muted: bool = AudioServer.is_bus_mute(0)
	fc.activate()
	check(fc.active, "liga")
	check(race.get_viewport().get_camera_3d() == fc.cam, "a camera livre vira a camera atual")
	check(not race._hud_layer.visible, "HUD da corrida some")
	for n in 30:
		race._process(0.1)
		fc._process(0.1)
	fc.teleport_km(1.0)
	var where: Vector3 = fc.cam_track()
	check_near(where.x, 1000.0, 1.0, "teleporte: km 1 da rota")
	check_near(where.z, FreecamMath.TELEPORT_HEIGHT, 0.05, "teleporte: 6 m acima da pista")
	check_near(where.y, 0.0, 0.05, "teleporte: no meio da pista")
	for n in 10:
		race._process(0.1)
	check(_digest(sim) == before, "com a camera livre a simulacao nao anda (tempo, caminhoes, transito)")
	check_near(race._acc, acc, 0.0, "nem acumula tempo para depois")
	fc.toggle_hud()
	check(not (fc._overlay._info.get_parent() as CanvasItem).visible, "H esconde o painel")
	fc.toggle_hud()
	check((fc._overlay._info.get_parent() as CanvasItem).visible, "H mostra de novo")
	var shot: String = fc.shot_path()
	check(shot.begins_with("user://shots/kanto_1_coast_km1.000_") and shot.ends_with(".png"), "print com rota e km no nome: %s" % shot)
	fc.deactivate()
	check(not fc.active, "desliga")
	check(race.get_viewport().get_camera_3d() == race._cam, "volta para a camera da corrida")
	check(race._cam.global_transform.is_equal_approx(cam_xf), "... no mesmo ponto")
	check(race._hud_layer.visible, "HUD volta")
	check_eq(AudioServer.is_bus_mute(0), muted, "som volta como estava")
	check(_digest(sim) == before, "desligar tambem nao mexe na simulacao")
	for n in 5:
		race._process(0.1)
	check(sim.time > float(before[0]), "depois de desligar a corrida continua")
	race.free()
	gs.new_profile()


func test_teleport_pose_and_km_parsing() -> void:
	check_near(FreecamMath.parse_km("1,2"), 1.2, 0.0001, "1,2")
	check_near(FreecamMath.parse_km(" 1.2 "), 1.2, 0.0001, "1.2")
	check_near(FreecamMath.parse_km("2 km"), 2.0, 0.0001, "2 km")
	check_near(FreecamMath.parse_km("800m"), 0.8, 0.0001, "800 m = 0,8 km")
	check_near(FreecamMath.parse_km("0"), 0.0, 0.0001, "0")
	for bad in ["", "abc", "-1", "1,2,3", "km"]:
		check(is_nan(FreecamMath.parse_km(bad)), "invalido: '%s'" % bad)
	var route: RouteDef = load("res://data/routes/kanto_3_mountain.tres") as RouteDef
	var path := TrackPath.new(route.build_track())
	for km in [0.0, 0.75, 1.5]:
		var z: float = FreecamMath.teleport_z(path, km)
		check_near(z, km * 1000.0, 0.001, "km %.2f" % km)
		var pose: Array = FreecamMath.teleport_pose(path, z)
		var p: Vector3 = pose[0]
		check(p.is_equal_approx(path.world_point(z, 0.0, 6.0)), "centro da pista, 6 m acima (km %.2f)" % km)
		var near: Vector3 = FreecamMath.nearest(path, p)
		check_near(near.x, z, 0.5, "o km da camera volta igual (km %.2f)" % km)
		var fwd: Vector3 = -FreecamMath.basis_from(float(pose[1]), float(pose[2])).z
		check(fwd.dot(path.forward_at(z)) > 0.95, "olhando no sentido da pista (km %.2f)" % km)
	check_near(FreecamMath.teleport_z(path, 999.0), path.track.length_m - 0.01, 0.001, "km alem do fim: fica no fim da rota")
	check_eq(FreecamMath.format_km(1234.0), "km 1,234", "km com virgula")


func test_shot_file_name() -> void:
	check_eq(FreecamMath.shot_file_name("kanto_1_coast", 1200.0, "Roadside3D > lamp_post #12", "20261021-153012"),
		"kanto_1_coast_km1.200_Roadside3D_lamp_post_12_20261021-153012.png", "rota, km, objeto e hora")
	check_eq(FreecamMath.shot_file_name("quick", 50.0, "", "20261021-153012"), "quick_km0.050_nada_20261021-153012.png", "sem objeto")
	check_eq(FreecamMath.sanitize("Câmera/árvore: ok?"), "C_mera_rvore_ok", "so letras, numeros, - e _")
	check(FreecamMath.sanitize("x".repeat(100)).length() <= 48, "nome curto")
	check_eq(FreecamMath.stamp({"year": 2026, "month": 10, "day": 21, "hour": 15, "minute": 3, "second": 9}), "20261021-150309", "hora")


func test_allowed_never_online() -> void:
	for dbg in [false, true]:
		for opt in [false, true]:
			for flag in [false, true]:
				check(not FreecamMath.allowed(true, dbg, opt, flag), "online nunca (debug=%s opcao=%s flag=%s)" % [dbg, opt, flag])
	check(FreecamMath.allowed(false, true, false, false), "build de debug")
	check(FreecamMath.allowed(false, false, true, false), "opcao Modo explorador")
	check(FreecamMath.allowed(false, false, false, true), "--freecam")
	check(not FreecamMath.allowed(false, false, false, false), "versao final sem opcao: nao")
	var fake := Node3D.new()
	check(Freecam.attach(fake, null, null, null, null, true) == null, "corrida online: nem cria")
	check_eq(fake.get_child_count(), 0, "... nada pendurado na cena")
	fake.free()


func test_explorer_option_is_saved() -> void:
	var st: Node = Engine.get_main_loop().root.get_node("Settings")
	var old: bool = st.explorer_mode
	var file: String = "user://test_settings_t181.cfg"
	st.explorer_mode = true
	st.save_settings(file)
	st.explorer_mode = false
	st.load_settings(file)
	check(st.explorer_mode, "Modo explorador gravado e lido de volta")
	var cfg := ConfigFile.new()
	cfg.load(file)
	check(bool(cfg.get_value("advanced", "explorer_mode", false)), "secao [advanced] do settings.cfg")
	st.explorer_mode = old
	DirAccess.remove_absolute(file)


func test_picker_names_object_and_glb() -> void:
	var root := Node3D.new()
	root.name = "Mundo"
	Engine.get_main_loop().root.add_child(root)
	var box := MeshInstance3D.new()
	box.name = "caixa_teste"
	box.mesh = BoxMesh.new()
	box.position = Vector3(0, 0, -10)
	root.add_child(box)
	var picker := FreecamPicker.new(root, null)
	var hit: Dictionary = picker.pick(Vector3.ZERO, Vector3.FORWARD)
	check_eq(String(hit.get("name", "")), "caixa_teste", "malha simples: nome do no")
	check_near(float(hit.get("distance", 0.0)), 9.5, 0.01, "distancia ate a face da caixa")
	check_eq(String(hit.get("file", "?")), "", "caixa feita por codigo: sem .glb")
	# .glb instanciado (transito, caminhoes): o arquivo vem da cena
	var holder := Node3D.new()
	holder.name = "Cenario"
	holder.position = Vector3(40, 0, 0)
	root.add_child(holder)
	var tree: Node3D = (load(GLB) as PackedScene).instantiate()
	holder.add_child(tree)
	var c: Vector3 = _center(tree)
	picker.clear()
	hit = picker.pick(c + Vector3(0, 0, 30), Vector3.FORWARD)
	check_eq(String(hit.get("file", "")), GLB, ".glb instanciado")
	check_eq(String(hit.get("system", "")), "Cenario", "sistema = no de cima")
	holder.free()
	# MultiMesh (arvores, postes): o arquivo vem do GlbMesh.merged. Sem tela o Godot nao guarda a posicao de cada
	# copia (servidor de render falso: todas na origem), entao quem desloca aqui e o proprio no.
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = MultiMesh.new()
	mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	mmi.multimesh.mesh = GlbMesh.merged(GLB)
	mmi.multimesh.instance_count = 1
	mmi.position = Vector3(80, 0, 0)
	root.add_child(mmi)
	var mc: Vector3 = mmi.multimesh.mesh.get_aabb().get_center() + Vector3(80, 0, 0)
	picker.clear()
	hit = picker.pick(mc + Vector3(0, 0, 30), Vector3.FORWARD)
	check_eq(String(hit.get("file", "")), GLB, "MultiMesh: .glb de origem")
	check_eq(int(hit.get("instance", -1)), 0, "MultiMesh: qual copia")
	check_eq(String(FreecamPicker.describe(mmi, root, mmi.multimesh.mesh, 0, Vector3.ZERO, 7)["name"]), "tree_pine #7", "nome = arquivo + copia")
	mmi.free()
	# MeshBatch (placas, barreiras): a peca sob a mira dentro do lote
	var batch := MeshBatch.new()
	batch.add(GlbMesh.merged(GLB), Transform3D(Basis.IDENTITY, Vector3(0, 0, -200)), 0.0)
	batch.add(box.mesh, Transform3D(Basis.IDENTITY, Vector3(0, 0, -300)), 0.0)
	box.free()
	var parent := Node3D.new()
	root.add_child(parent)
	batch.commit(parent)
	var bc: Vector3 = GlbMesh.merged(GLB).get_aabb().get_center() + Vector3(0, 0, -200)
	picker.clear()
	hit = picker.pick(Vector3(bc.x, bc.y, -100), Vector3.FORWARD)
	check_eq(String(hit.get("file", "")), GLB, "lote MeshBatch: .glb da peca")
	root.free()


func _center(n: Node) -> Vector3:
	var box := AABB()
	var first: bool = true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		var b: AABB = mi.global_transform * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center()
