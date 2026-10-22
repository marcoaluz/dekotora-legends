extends TestCase
## T-193: models of the new docs/Modelos folders in the game: textured buildings (CityModels), kanji neon of the
## NeonText pack (second atlas of NeonSigns) and the "only one car" (UniqueCar, scenery only, once per race).

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func test_city_models_load_light_and_fit_the_lot() -> void:
	var cm := CityModels.new(TimeOfDay.by_id(&"day"), 5, 2)
	check_eq(cm.model_count(), CityModels.SPEC.size(), "os 8 predios carregam")
	for m in CityModels.SPEC:
		var mesh: ArrayMesh = GlbMesh.merged(CityModels.DIR + m + ".glb")
		var n: int = 0
		for s in mesh.get_surface_count():
			n += mesh.surface_get_array_index_len(s) / 3 if mesh.surface_get_array_index_len(s) > 0 else mesh.surface_get_array_len(s) / 3
		check(n <= 1700, "%s: leve (%d triangulos)" % [m, n])
		check_near(mesh.get_aabb().position.y, 0.0, 0.3, m + ": base no chao")
	var placed: int = 0
	for i in 200:
		var used: Vector3 = cm.try_place(Vector3.ZERO, Basis(), 24.0, 30.0, i % 3, 120.0, float(i) * 10.0)
		if used != Vector3.ZERO:
			placed += 1
			check(used.x <= 24.01 and used.z <= 30.01, "cabe no lote (%.1f x %.1f)" % [used.x, used.z])
	check(placed > 20 and placed < 160, "uma parte dos lotes vira modelo (%d de 200)" % placed)
	check_eq(cm.try_place(Vector3.ZERO, Basis(), 4.0, 4.0, 2, 120.0, 0.0), Vector3.ZERO, "lote pequeno fica com a caixa")


func test_neon_uses_the_t193_atlas_for_one_sign_in_three() -> void:
	var a := NeonSigns.new()
	var b := NeonSigns.new()
	for i in 30:
		for ns in [a, b]:
			(ns as NeonSigns).add(Vector3(i, 5, 0), Vector3.BACK, Vector2(2, 8), i % 16, i % 2 == 0)
	a.commit(TimeOfDay.by_id(&"night"))
	b.commit(TimeOfDay.by_id(&"night"))
	check(a.count_t193 >= 8 and a.count_t193 <= 12, "1 em 3 letreiros com o atlas novo (%d de 30)" % a.count_t193)
	check_eq(a.count + a.count_t193, 30, "nenhum letreiro perdido")
	check_eq(a.count_t193, b.count_t193, "deterministico")
	check(a.get_node_or_null("NeonT193") != null, "segundo MultiMesh (uma chamada de desenho a mais)")
	a.free()
	b.free()


func test_unique_car_is_scenery_once_per_route() -> void:
	check(not Traffic3D.all_models().has("car_skyline"), "o carro unico nao anda no transito")
	check(ResourceLoader.exists(UniqueCar.MODEL), "modelo do carro unico existe")
	for rid in ROUTES:
		check(UniqueCar.SPOTS.has(rid), rid + ": tem lugar escolhido")
		var spot: Array = UniqueCar.SPOTS[rid]
		check(float(spot[2]) >= 15.0, rid + ": fora da mureta (>= 15 m do centro)")
		var r: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		check(r != null, rid + ": rota carrega")
		if r == null:
			continue
		var t: Track = r.build_track()
		var busy: Array[Vector2] = []
		for tu in r.tunnels + r.bridges:
			busy.append(Vector2(tu.x, tu.x + tu.y))
		var z1: float = UniqueCar.spot_z(t, rid, busy)
		check_eq(UniqueCar.spot_z(t, rid, busy), z1, rid + ": mesmo lugar sempre")
		for b in busy:
			check(z1 < b.x - 100.0 or z1 > b.y + 100.0, rid + ": longe de tunel/ponte")
