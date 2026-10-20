extends TestCase
## Kit de beira de estrada (T-146): modelos reduzidos, outdoors, bocas de tunel, eventos e porticos.

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func _tris(m: Mesh) -> int:
	var n: int = 0
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		n += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] != null \
			else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n


func test_models_exist_light_and_with_our_materials() -> void:
	var day: TimeOfDay = TimeOfDay.by_id(&"day")
	for name in RoadsideKit.MODELS:
		var m: ArrayMesh = RoadsideKit.mesh(name, day)
		check(m != null and m.get_surface_count() >= 1, name + ": modelo carregado")
		if m == null:
			continue
		check(_tris(m) <= 400, name + ": leve para celular (%d triangulos)" % _tris(m))
		for s in m.get_surface_count():
			check(m.surface_get_material(s) is BaseMaterial3D, name + ": material do kit")
	for i in RoadsideKit.ART_COUNT:
		check(RoadsideKit.art(i + 1) != null, "arte do outdoor %d" % (i + 1))
	for t in ["barrier_albedo", "barrier_orm", "barrier_nrm", "sign_metal", "truss_fence"]:
		var tex: Texture2D = load(RoadsideKit.TEX + t + ".png") as Texture2D
		check(tex != null and tex.get_width() <= 1024, t + ": textura de no maximo 1024 px")


func test_plates_match_sign_shapes() -> void:
	check_eq(String(RoadsideKit.plate_for("spd_80")[0]), "sign_plate_round", "limite: chapa redonda")
	check_eq(String(RoadsideKit.plate_for("warn_curve_r")[0]), "sign_plate_diamond", "aviso: losango")
	check_eq(String(RoadsideKit.plate_for("stop")[0]), "sign_plate_tri", "pare: triangulo")
	check(bool(RoadsideKit.plate_for("stop")[3]), "pare: triangulo de ponta para baixo")
	check_eq(String(RoadsideKit.plate_for("exit")[0]), "sign_plate_rect", "saida: retangulo")


func test_billboards_and_tunnel_walls_on_every_route() -> void:
	for rid in ROUTES:
		var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		var path := TrackPath.new(route.build_track())
		var kit := KitProps3D.new()
		kit.build(path, route.scenery, TimeOfDay.by_id(route.time_of_day), route.tunnels)
		check(int(kit.counts.get("billboard", 0)) >= 2, rid + ": outdoors na beira da estrada")
		check_eq(int(kit.counts.get("portal_wall", 0)), route.tunnels.size() * 2 * KitProps3D.PORTAL_STEPS.size(), rid + ": muros listrados nas bocas (T-155: 4 pecas de cada lado)")
		kit.free()


func test_events_get_barriers() -> void:
	var t := Track.new()
	t.add_section(3000.0, 0.0)
	var evs := TrackEvents.new()
	evs.add({"kind": "works", "z": 600.0, "length": 170.0, "lanes": [3]})
	evs.add({"kind": "accident", "z": 1400.0, "lanes": [2, 3]})
	evs.add({"kind": "narrow", "z": 2200.0, "lanes": [1]})
	t.events = evs
	var b := TrackEvents3D.new()
	b.build(TrackPath.new(t), TimeOfDay.by_id(&"night"))
	check(int(b.counts.get("kit_barrier_jersey", 0)) >= 40, "obras: fileira de barreiras de concreto")
	check(int(b.counts.get("kit_barrier_aframe", 0)) >= 1, "acidente: cavaletes de metal")
	check(int(b.counts.get("kit_debris_metal", 0)) >= 1, "acidente: destrocos")
	check(int(b.counts.get("kit_barrier_wall", 0)) >= 1, "estreitamento: muro listrado no fim da faixa")
	b.free()


func test_gantries_use_truss() -> void:
	var route: RouteDef = load("res://data/routes/kanto_2_viaduct.tres") as RouteDef
	var path := TrackPath.new(route.build_track())
	var f := RoadFurniture.new()
	f.build(path, route.scenery, TimeOfDay.by_id(route.time_of_day), route.tunnels, route.places)
	var truss: int = 0
	for mi in f.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m is ArrayMesh and m.get_surface_count() > 0:
			var mat: BaseMaterial3D = m.surface_get_material(0) as BaseMaterial3D
			if mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				truss += 1
	check(truss >= 2, "porticos de trelica (%d)" % truss)
	f.free()
