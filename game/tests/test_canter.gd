extends TestCase
## Caminhao base Canter e cabine curta (T-125, malha do JAC 1045): os .glb abrem, tem rodas e todos os pontos de
## montagem (no Canter com escala menor), materiais nossos e sem marca; a simulacao usa massa, comprimento,
## agilidade e torque do BodyDef; o Mercado respeita os 4 t; garagem e perfil guardam a escolha.

const KMH100: float = 100.0 / 3.6
const MODELS: Dictionary = {"canter": ["canter", "padrao"], "base_curta": ["base", "curta"], "leve_curta": ["leve", "curta"],
		"longo_curta": ["longo", "curta"]}
const LIMIT: Dictionary = {"canter": 55000, "base_curta": 70000, "leve_curta": 58000, "longo_curta": 82000}
const MOUNTS: Array[String] = ["MOUNT_FRONT_BUMPER", "MOUNT_FRONT_GRILLE", "MOUNT_FRONT_ORNAMENT", "MOUNT_VISOR",
		"MOUNT_ROOF", "MOUNT_ROOF_LIGHTS", "MOUNT_BODY_ROOF", "MOUNT_REAR", "MOUNT_REAR_LAMPS", "MOUNT_REAR_PLATE",
		"MOUNT_REAR_PANEL", "MOUNT_REAR_ROOF", "MOUNT_SIDE_R", "MOUNT_SIDE_L", "MOUNT_FENDER_R", "MOUNT_FENDER_L",
		"MOUNT_STEP_R", "MOUNT_STEP_L", "MOUNT_SIDE_TRIM_R", "MOUNT_SIDE_BOX_R", "MOUNT_SIDE_ORNAMENT_R",
		"MOUNT_SIDE_PANEL_R", "MOUNT_MUDFLAP_R", "MOUNT_WHEEL_FRONT_FACE_R", "MOUNT_WHEEL_FRONT_FACE_L",
		"MOUNT_WHEEL_REAR_FACE_R", "MOUNT_CAB_SIDE_R"]
const KNOWN_PREFIX: Array[String] = ["paint_", "chrome", "steel", "rubber", "plastic", "glass", "lamp_", "mesh_perf",
		"diamond", "andon_panel", "mural", "grille_honeycomb", "vent_slots"]


func _model(tag: String) -> Node3D:
	var spec: Array = MODELS[tag]
	var scene: PackedScene = load(TruckNode.model_path(String(spec[0]), String(spec[1]))) as PackedScene
	return scene.instantiate() as Node3D if scene != null else null


func test_models_load_with_wheels_and_mounts() -> void:
	for tag in MODELS:
		var spec: Array = MODELS[tag]
		check(TruckNode.model_path(String(spec[0]), String(spec[1])).ends_with("dekotora_truck_%s.glb" % tag), "caminho do %s" % tag)
		var m: Node3D = _model(tag)
		check(m != null, "abre o .glb %s" % tag)
		if m == null:
			continue
		check(m.find_children("wheel_*", "Node3D", true, false).size() >= 6, "%s tem rodas" % tag)
		check(m.find_children("wheel_f_*", "Node3D", true, false).size() == 2, "%s: 2 rodas dianteiras" % tag)
		for n in MOUNTS:
			check(m.find_child(n, true, false) != null, "%s: ponto de montagem %s" % [tag, n])
		m.free()


func test_canter_size_and_scaled_mounts() -> void:
	var m: Node3D = _model("canter")
	if m == null:
		check(false, "canter nao abriu")
		return
	var bumper: Node3D = m.find_child("MOUNT_FRONT_BUMPER", true, false) as Node3D
	var roof: Node3D = m.find_child("MOUNT_BODY_ROOF", true, false) as Node3D
	var cab_roof: Node3D = m.find_child("MOUNT_ROOF", true, false) as Node3D
	check_near(bumper.position.z, -6.88, 0.08, "para-choque do Canter a 6,9 m da traseira")
	check_near(-11.5 - float(TruckNode.LENGTH_DELTA["canter"]), bumper.position.z, 0.1, "LENGTH_DELTA bate com o modelo")
	check_near(bumper.scale.x, 0.88, 0.02, "pecas da cabine encolhem para o Canter (escala do ponto)")
	check_near(roof.scale.x, 0.92, 0.02, "pecas do bau encolhem para o Canter")
	check(roof.position.y > 2.9 and roof.position.y < 3.1, "teto do bau a ~3 m: %.2f" % roof.position.y)
	check(cab_roof.position.y > 2.1 and cab_roof.position.y < 2.5, "teto da cabine a ~2,3 m: %.2f" % cab_roof.position.y)
	var curta: Node3D = _model("base_curta")
	var cb: Node3D = curta.find_child("MOUNT_FRONT_BUMPER", true, false) as Node3D
	check_near(cb.position.z, -11.5, 0.08, "cabine curta: frente no mesmo lugar das outras cabines")
	check_near(cb.scale.x, 1.0, 0.02, "cabine curta: pecas em tamanho normal")
	m.free()
	curta.free()


func test_materials_budget_and_no_brand() -> void:
	for tag in MODELS:
		var m: Node3D = _model(tag)
		if m == null:
			continue
		var tris: int = 0
		var paint: bool = false
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			paint = paint or String(mi.name).contains("paint_white")
			check(not String(mi.name).to_lower().contains("emblema"), "%s: sem emblema do JAC (%s)" % [tag, mi.name])
			for s in mesh.get_surface_count():
				var mat: Material = mesh.surface_get_material(s)
				var name: String = mat.resource_name if mat != null else ""
				var ok: bool = false
				for p in KNOWN_PREFIX:
					ok = ok or name.begins_with(p)
				check(ok, "%s: material nosso (%s)" % [tag, name])
				var arrays: Array = mesh.surface_get_arrays(s)
				var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				tris += idx.size() / 3 if idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		check(paint, "%s: pintura paint_white (rivais tingem)" % tag)
		check(tris > 30000 and tris < int(LIMIT[tag]), "%s: %d triangulos (limite %d)" % [tag, tris, LIMIT[tag]])
		m.free()


func _sim_truck(body: String) -> TruckSim:
	var t := TruckSim.new()
	var desc: Dictionary = TruckConfig.basic_descriptor()
	desc["body"] = body
	TruckConfig.apply(t, desc)
	return t


func _zero_to_100(t: TruckSim) -> float:
	var track := Track.new()
	track.add_section(8000.0, 0.0)
	var cmd := Commands.make(0.0, 1.0, 0.0)
	var time: float = 0.0
	while t.speed < KMH100 and time < 120.0:
		t.step(1.0 / 30.0, cmd, track)
		time += 1.0 / 30.0
	return time


## Tempo (s) da primeira troca de faixa a 25 m/s: do 2o toque ate chegar a 90% da faixa vizinha.
func _lane_change_time(t: TruckSim) -> float:
	var track := Track.new()
	track.add_section(4000.0, 0.0)
	t.speed = 25.0
	var dt: float = 1.0 / 30.0
	for steer in [1.0, 0.0, 1.0]:                  # toque, solta, toque = troca
		t.step(dt, Commands.make(steer, 0.6, 0.0), track)
	var goal: float = Lanes.X[t.lane]
	var x0: float = t.x
	var time: float = 0.0
	while absf(t.x - x0) < absf(goal - x0) * 0.9 and time < 5.0:
		t.step(dt, Commands.make(0.0, 0.6, 0.0), track)
		time += dt
	return time


func test_canter_balance_light_agile_small() -> void:
	var std: TruckSim = _sim_truck("base")
	var can: TruckSim = _sim_truck("canter")
	check_near(std.mass, 8000.0 + 4000.0 + 220.0, 1.0, "caminhao padrao igual a antes (8 t + 4 t de carga + para-choques)")
	check(can.mass < std.mass * 0.5, "Canter bem mais leve: %.0f kg" % can.mass)
	check_eq(can.length, 7.0, "Canter ocupa 7 m na pista")
	check_eq(std.length, Collision.LEN, "baus grandes continuam com 12 m")
	var t_std: float = _zero_to_100(_sim_truck("base"))
	var t_can: float = _zero_to_100(_sim_truck("canter"))
	var l_std: float = _lane_change_time(_sim_truck("base"))
	var l_can: float = _lane_change_time(_sim_truck("canter"))
	print("Canter: 0-100 %.1f s (padrao %.1f s); troca de faixa %.2f s (padrao %.2f s); curva 1,0 segura a %.0f km/h (padrao %.0f)" % [
		t_can, t_std, l_can, l_std, TruckSim.curve_safe_speed(1.0, can.grip()) * 3.6, TruckSim.curve_safe_speed(1.0, std.grip()) * 3.6])
	check(t_can < t_std and t_can > t_std * 0.7, "Canter arranca um pouco melhor, sem passar do V8 (%.1f s vs %.1f s)" % [t_can, t_std])
	check(l_can < l_std * 0.92, "Canter troca de faixa mais rapido (%.2f s vs %.2f s)" % [l_can, l_std])
	check(TruckSim.curve_safe_speed(1.0, can.grip()) > TruckSim.curve_safe_speed(1.0, std.grip()), "Canter faz curva mais rapido")


func test_canter_short_hitbox_and_pushed_by_heavy() -> void:
	var tr := Track.new()
	tr.add_section(2000.0, 0.0)
	var sim := RaceSim.new(tr, -1, 3)
	var a: int = sim.add_truck(100.0, 0.0)
	var b: int = sim.add_truck(108.0, 0.0)                 # 8 m a frente: so o caminhao de 12 m encostaria
	TruckConfig.apply(sim.trucks[a], {"parts": [], "body": "canter"})
	TruckConfig.apply(sim.trucks[b], {"parts": [], "body": "base"})
	var col := Collision.new()
	check(col.resolve_trucks(sim.trucks, 1.0 / 30.0).is_empty() and absf(sim.trucks[a].z - 100.0) < 0.001,
			"Canter de 7 m a 8 m de distancia nao encosta")
	# lado a lado: o Canter (leve) e empurrado mais longe que o caminhao grande
	var s2 := RaceSim.new(tr, -1, 3)
	var c: int = s2.add_truck(100.0, 0.0)
	var d: int = s2.add_truck(100.0, 0.3)
	TruckConfig.apply(s2.trucks[c], {"parts": [], "body": "canter"})
	TruckConfig.apply(s2.trucks[d], {"parts": [], "body": "base"})
	Collision.new().resolve_trucks(s2.trucks, 1.0 / 30.0)
	check(absf(s2.trucks[c].x - 0.0) > absf(s2.trucks[d].x - 0.3) * 1.5, "o Canter vai mais longe no empurrao")


func test_contracts_fit_canter_box() -> void:
	check_eq(Contracts.capacity_t("canter"), 4.0, "bau do Canter leva 4 t")
	check_eq(Contracts.capacity_t("base"), 12.0, "bau medio continua 12 t")
	var routes: Array[RouteDef] = FreightMarket.all_routes()
	var list: Array[Dictionary] = Contracts.generate(99, routes, func(_r: RouteDef) -> bool: return true, "canter")
	var fits: int = 0
	for c in list:
		if float(c["weight_t"]) <= 4.0:
			fits += 1
	check(fits >= routes.size(), "cada trecho tem frete que cabe no Canter (%d de %d)" % [fits, list.size()])


func test_garage_and_profile() -> void:
	check(TruckNode.CABS.has("curta"), "garagem lista a cabine curta")
	for key in ["body.canter", "body.desc.canter", "cab.curta", "cab.desc.curta", "garage.cab_fixed"]:
		check(Tr.t(key) != key, "texto pt-BR %s" % key)
	check_eq(TruckNode.model_path("canter", "aero"), TruckNode.MODEL_PATHS["canter"], "Canter ignora a cabine do perfil")
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.profile["body"] = "canter"
	gs.save_profile()
	gs.profile = {}
	gs.load_profile()
	check_eq(String(gs.profile.get("body", "")), "canter", "perfil guarda o Canter")
	check_eq(String(gs.truck_descriptor().get("body", "")), "canter", "descritor (servidor/rede) leva o modelo")
	check(gs.capacity_t() == 4.0, "Mercado usa a capacidade do Canter")
	gs.new_profile()
