extends TestCase
## Ferrovia ao lado da rodovia (T-154): a linha nao invade a pista nem a mureta, respeita tuneis e trechos de 2 faixas,
## o viaduto passa alto o bastante, os trens sao determinísticos e cruzam com o jogador.

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
const FOOT: float = 7.2                  # Railway3D.SHOULDER: pe do aterro (o mais largo da secao)
const CAR_HEIGHT: float = 4.3            # caminhao mais alto + folga


func _setup(rid: String) -> Array:
	var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	var path := TrackPath.new(route.build_track())
	return [route, path, RailwayLayout.lines_for(rid, route.scenery, path)]


## Menor distancia horizontal do ponto ate a linha central da pista (amostras a cada 4 m) e o z dela.
func _nearest_road(path: TrackPath, p: Vector3) -> Vector2:
	var best := Vector2(INF, 0.0)
	var z: float = 0.0
	while z <= path.track.length_m:
		var c: Vector3 = path.center_at(z)
		var d: float = Vector2(p.x - c.x, p.z - c.z).length()
		if d < best.x:
			best = Vector2(d, z)
		z += 4.0
	return best


func test_every_route_has_a_railway_and_a_crossing_where_planned() -> void:
	for rid in ROUTES:
		var lines: Array = _setup(rid)[2]
		check(not lines.is_empty(), rid + ": tem ferrovia")
		var crossings: int = 0
		for l in lines:
			check((l as RailLine).length() > 250.0, rid + ": linha com comprimento de verdade")
			if (l as RailLine).kind == RailLine.Kind.CROSSING:
				crossings += 1
		check_eq(crossings, 0 if rid == "kanto_1_coast" else 1, rid + ": viaduto de trem cruzando a pista")


func test_railway_never_invades_the_road_or_the_barrier() -> void:
	for rid in ROUTES:
		var s: Array = _setup(rid)
		var path: TrackPath = s[1]
		for l in s[2]:
			var line: RailLine = l
			var k: int = 0
			while k < line.pts.size():
				var p: Vector3 = line.pts[k]
				var n: Vector2 = _nearest_road(path, p)
				var keep: float = RoadMesh.BARRIER_IN + RoadMesh.BARRIER_W + FOOT
				if line.kind == RailLine.Kind.PARALLEL:
					check(n.x > keep + 5.0, "%s: linha paralela longe da mureta em s=%.0f (%.1f m)" % [rid, line.cum[k], n.x])
				elif n.x < keep:                          # cruzamento: por cima, com vao livre
					var gap: float = p.y - Railway3D.DECK_DEPTH - path.center_at(n.y).y
					check(gap > CAR_HEIGHT, "%s: viaduto alto sobre a pista (%.1f m)" % [rid, gap])
				k += 5


func test_railway_respects_tunnels_and_two_lane_sections() -> void:
	for rid in ROUTES:
		var s: Array = _setup(rid)
		var route: RouteDef = s[0]
		var blocked: Array[Vector2] = []
		if route.scenery != &"city":                      # na cidade o tunel e uma caixa de 30 m: a linha passa ao lado
			for t in route.tunnels:
				blocked.append(Vector2(t.x + 1.0, t.x + t.y - 1.0))
		if "lane_sections" in route:                      # T-153 (trecho de 2 faixas, ponte, tunel antigo)
			for ls in route.get("lane_sections"):
				var taper: float = float(ls.get("taper", 130.0))
				blocked.append(Vector2(float(ls["start"]) - taper, float(ls["end"]) + taper))
		if "bridges" in route:
			for b in route.get("bridges"):
				blocked.append(Vector2(b.x, b.x + b.y))
		for l in s[2]:
			var line: RailLine = l
			if line.kind != RailLine.Kind.PARALLEL:
				continue
			for z in line.road_z:
				for b in blocked:
					check(z <= b.x or z >= b.y, "%s: ferrovia fora do tunel/trecho estreito (z=%.0f em %s)" % [rid, z, b])


func test_known_two_lane_sections_of_t153_stay_free() -> void:
	# Trechos combinados com a T-153 (mesmo que ela ainda nao esteja na main): litoral 2.270-2.890 m, montanha 650-1.190 m.
	var free := {"kanto_1_coast": Vector2(2270.0, 2890.0), "kanto_3_mountain": Vector2(650.0, 1190.0)}
	for rid in free:
		for l in _setup(rid)[2]:
			for z in (l as RailLine).road_z:
				if (l as RailLine).kind == RailLine.Kind.PARALLEL:
					check(z < free[rid].x or z > free[rid].y, "%s: nada da ferrovia no trecho de 2 faixas (z=%.0f)" % [rid, z])


func _drive(rid: String, seed_: int, steps: int) -> RailTraffic:
	var lines: Array[RailLine] = _setup(rid)[2]
	var tr := RailTraffic.new(lines, seed_, RailwayLayout.main_train(rid))
	var z: float = 300.0
	for i in steps:
		var v: float = 20.0 + 8.0 * sin(float(i) * 0.01)
		tr.update(1.0 / 30.0, z, v)
		z += v / 30.0
	return tr


func test_trains_are_deterministic() -> void:
	for rid in ROUTES:
		var a: RailTraffic = _drive(rid, 1234, 1500)
		var b: RailTraffic = _drive(rid, 1234, 1500)
		var la: Array = a.car_list()
		var lb: Array = b.car_list()
		check_eq(la.size(), lb.size(), rid + ": mesmos vagoes")
		for i in mini(la.size(), lb.size()):
			check(((la[i][1] as Transform3D).origin - (lb[i][1] as Transform3D).origin).length() < 0.001, rid + ": mesma posicao")
		check_eq(a.passes, b.passes, rid + ": mesmas passagens")


func test_a_train_meets_the_player_soon_after_the_start() -> void:
	var lines: Array[RailLine] = _setup("kanto_1_coast")[2]
	var tr := RailTraffic.new(lines, 7, RailTraffic.Type.FREIGHT)
	var z: float = 400.0
	var closest: float = INF
	for i in 30 * 14:
		tr.update(1.0 / 30.0, z, 25.0)
		z += 25.0 / 30.0
		for t in tr.trains:
			closest = minf(closest, absf(lines[t.line].z_at(t.center) - z))
	check(closest < 60.0, "um trem passa pelo jogador nos primeiros 14 s (mais perto: %.0f m)" % closest)


func test_crossing_train_is_over_the_road_when_the_player_arrives() -> void:
	var s: Array = _setup("kanto_3_mountain")
	var lines: Array[RailLine] = s[2]
	var tr := RailTraffic.new(lines, 99, RailTraffic.Type.FREIGHT)
	var cross: RailLine = null
	for l in lines:
		if l.kind == RailLine.Kind.CROSSING:
			cross = l
	var z: float = 0.0
	var v: float = 22.0
	var over: bool = false
	while z < cross.z_cross + 5.0:
		tr.update(1.0 / 30.0, z, v)
		z += v / 30.0
	for t in tr.trains:
		if lines[t.line] == cross:
			over = absf(t.center - cross.length() * 0.5) < t.length * 0.5
	check(over, "trem em cima da pista quando o caminhao passa embaixo do viaduto")


func test_car_transforms_follow_the_rails() -> void:
	var lines: Array[RailLine] = _setup("kanto_2_viaduct")[2]
	var tr := RailTraffic.new(lines, 5, RailTraffic.Type.LRT)
	tr.update(4.0, 600.0, 0.0)
	for it in tr.car_list():
		var xf: Transform3D = it[1]
		var t: RailTraffic.Train = it[2]
		var l: RailLine = lines[t.line]
		var s0: float = l.s_at_z(l.road_z[0])
		var best: float = INF
		for p in l.pts:
			best = minf(best, Vector2(xf.origin.x - p.x, xf.origin.z - p.z).length())
		check(best < RailLine.TRACK_SPACING * 0.5 + 1.2, "vagao em cima da via (%.2f m do eixo)" % best)
		check(absf(xf.basis.y.dot(Vector3.UP)) > 0.99, "vagao em pe")
		check(s0 >= 0.0, "linha valida")


func test_city_keeps_buildings_off_the_crossing() -> void:
	var s: Array = _setup("kanto_2_viaduct")
	var city := CityBuilder.new()
	city.keep_out = RailwayLayout.keep_out(s[2])
	check_eq(city.keep_out.size(), 1, "um corredor (o viaduto que cruza a pista)")
	var line: RailLine = null
	for l in s[2]:
		if l.kind == RailLine.Kind.CROSSING:
			line = l
	check(city._blocked(line.point(30.0), 10.0), "predio em cima da linha e retirado")
	check(not city._blocked(line.point(line.length() * 0.5) + Vector3(0, 0, 400), 10.0), "predio longe da linha fica")
	city.free()


func test_models_are_light_and_textures_small() -> void:
	var day: TimeOfDay = TimeOfDay.by_id(&"day")
	var caps := {"rail_mast": 300, "rail_pier": 50, "rail_pier_cap": 50, "rail_portal": 200, "train_loco": 1500,
		"train_wagon_a": 800, "train_wagon_b": 800, "train_wagon_c": 800, "train_lrt": 8000}
	for m in caps:
		var mesh: ArrayMesh = RailKit.mesh(m, day)
		check(mesh != null, m + ": modelo carregado")
		if mesh == null:
			continue
		var n: int = 0
		for si in mesh.get_surface_count():
			n += mesh.surface_get_array_len(si) if mesh.surface_get_array_index_len(si) == 0 else mesh.surface_get_array_index_len(si)
		check(n / 3 <= int(caps[m]), "%s: leve (%d triangulos)" % [m, n / 3])
	for t in ["rail_bed", "rail_atlas", "rail_atlas_emit", "lrt_body", "lrt_door"]:
		var tex: Texture2D = load(RailKit.TEX + t + ".png") as Texture2D
		check(tex != null and tex.get_width() <= 1024, t + ": textura de no maximo 1024 px")
