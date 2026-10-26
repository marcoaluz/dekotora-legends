extends TestCase
## T-217: route ambience: the other carriageway (OppositeLayout), stone-wall cuts (CutLayout), danchi blocks
## (DanchiLayout), opposite traffic (deterministic, no overtaking), eye adaptation at the tunnels (ExposureAdapt).

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func _path(rid: String) -> TrackPath:
	var r: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	return TrackPath.new(r.build_track(), [])


func test_opposite_layout_band_and_registry() -> void:
	var path: TrackPath = _path("kanto_1_coast")
	check(OppositeLayout.of(path) == null, "sem registro = sem outra pista (testes antigos nao mudam)")
	var o := OppositeLayout.new(path, "kanto_1_coast", &"coast")
	OppositeLayout.register(o)
	check(OppositeLayout.of(path) == o, "registro por pista")
	check(o.occupies(500.0, 20.0), "faixa da outra pista ocupada")
	check(not o.occupies(500.0, -20.0), "lado esquerdo livre")
	check(not o.occupies(500.0, OppositeLayout.CLEAR + 1.0), "alem de CLEAR livre")
	check(OppositeLayout.LANE_END < OppositeLayout.ROAD_OUT and OppositeLayout.LANE0 > OppositeLayout.MEDIAN_IN, "faixas dentro do asfalto")
	check_near(OppositeLayout.push_right(path, 20.0), 20.0 + OppositeLayout.SHIFT, 0.01, "lado direito empurrado")
	check_near(OppositeLayout.push_right(path, -20.0), -20.0, 0.01, "lado esquerdo nao muda")
	RouteAmbience.release()
	check(OppositeLayout.of(path) == null, "release limpa")


func test_walls_never_on_the_railway_side_nor_in_tunnels_or_bridges() -> void:
	for rid in ROUTES:
		var path: TrackPath = _path(rid)
		var r: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		var rails: Array[RailLine] = RailwayLayout.lines_for(rid, r.scenery, path)
		var cuts := CutLayout.new(path, rid)
		for run in cuts.runs:
			var side: float = float(run[2])
			var z: float = float(run[0])
			while z <= float(run[1]):
				for t in r.tunnels:
					check(z < t.x - 1.0 or z > t.x + t.y + 1.0 or cuts.height(z, side) < 0.05, "%s: muro fora do tunel (z=%d)" % [rid, z])
				for b in r.bridges:
					check(z < b.x or z > b.x + b.y, "%s: muro fora da ponte (z=%d)" % [rid, z])
				for l in rails:
					if l.kind == RailLine.Kind.PARALLEL and z >= l.z0 - 20.0 and z <= l.z1 + 20.0:
						check(l.side != side, "%s: muro do lado da ferrovia (z=%d)" % [rid, z])
				if r.scenery == &"coast":
					check(side < 0.0, "litoral: muro so do lado da terra")
				z += 10.0


func test_wall_terrace_is_behind_the_face() -> void:
	var path: TrackPath = _path("kanto_3_mountain")
	var cuts := CutLayout.new(path, "kanto_3_mountain")
	var z: float = 600.0
	var h: float = cuts.height(z, -1.0)
	check(h > 6.0, "muro alto no meio do corte (%.1f m)" % h)
	check_near(cuts.terrace(z, -(cuts.foot(-1.0) + 0.1)), 0.0, 0.01, "chao no pe do muro fica na pista")
	check(cuts.terrace(z, -(cuts.top(z, -1.0) + 2.0)) >= h, "atras do topo: terraco na altura do muro")
	check(cuts.blocks(z, -16.0), "nada de arvore/poste encostado no muro")
	check(not cuts.blocks(z, 16.0), "outro lado livre")
	check(cuts.height(370.5, -1.0) < 0.3, "o muro nasce do chao (rampa)")
	check(cuts.height(803.0, -1.0) > 5.0, "chega alto na boca do tunel (sem rampa)")


func test_danchi_blocks_stay_between_road_and_rail_and_off_the_tunnel() -> void:
	var path: TrackPath = _path("kanto_2_viaduct")
	var d := DanchiLayout.new(path, "kanto_2_viaduct")
	check(d.blocks.size() >= 15, "varios predios (%d)" % d.blocks.size())
	for b in d.blocks:
		check(float(b[3]) > OppositeLayout.MEDIAN_IN + 3.0 and float(b[4]) < 34.0, "entre a mureta e a ferrovia (40 m)")
		check(float(b[1]) < 980.0 or float(b[0]) > 1280.0, "fora da caixa do tunel")
		check(float(b[1]) < 1490.0 or float(b[0]) > 1510.0, "fora do cruzamento da ferrovia")
	var n: int = d.blocks.size()
	d.clear_around(800.0, 30.0)
	check(d.blocks.size() < n, "clear_around tira os predios do lote do carro unico")
	check(DanchiLayout.footprints("kanto_2_viaduct").size() == n, "deterministico")


func test_opposite_traffic_is_deterministic_and_never_overlaps() -> void:
	var path: TrackPath = _path("kanto_3_mountain")
	var o := OppositeLayout.new(path, "kanto_3_mountain", &"mountain")
	var a := OppositeTraffic3D.new()
	var b := OppositeTraffic3D.new()
	a.build(o, TimeOfDay.by_id(&"day"), 1, 99)
	b.build(o, TimeOfDay.by_id(&"day"), 1, 99)
	check(a.vehicles.size() > 40, "transito na outra pista (%d)" % a.vehicles.size())
	check_eq(a.vehicles.size(), b.vehicles.size(), "mesma semente, mesmo transito")
	for t in [0.0, 13.7, 61.0]:
		for lane in OppositeLayout.LANES:
			var spans: Array = []
			for k in a.vehicles.size():
				if int(a.vehicles[k][1]) == lane:
					spans.append(a.rear_z(k, t))
			check(spans.size() > 5, "faixa %d com carros" % lane)
		check_near(a.rear_z(3, t), b.rear_z(3, t), 0.001, "posicao so depende do relogio")
	check(a.rear_z(0, 1.0) < a.rear_z(0, 0.0) or a.rear_z(0, 1.0) > a.rear_z(0, 0.0) + 100.0, "andam para -z (contra a gente)")
	for k in a.vehicles.size():                   # same speed per lane: gaps never change
		for j in a.vehicles.size():
			if j != k and a.vehicles[j][1] == a.vehicles[k][1]:
				var d0: float = float(a.vehicles[j][2]) - float(a.vehicles[k][2])
				if d0 > 0.0 and d0 < 200.0:
					check(d0 >= float(a.vehicles[k][3]) + OppositeTraffic3D.GAP.x - 0.01, "sem carro dentro do outro")
	a.free()
	b.free()


func test_exposure_adapts_slowly_to_dark_fast_to_light() -> void:
	var env := Environment.new()
	env.tonemap_exposure = 1.0
	var e := ExposureAdapt.new(env, 1.0, false)
	check_near(e.step(0.016, 0.0), 1.0, 0.001, "fora do tunel: nada muda")
	var first: float = e.step(0.016, 1.0)
	check(first < 0.7, "entrou de dia: escurece primeiro (%.2f)" % first)
	for i in 600:
		e.step(0.016, 1.0)
	check_near(e.step(0.016, 1.0), 1.0, 0.05, "depois de uns segundos o olho se acostuma")
	var out: float = e.step(0.016, 0.0)
	check(out > 1.8, "saiu: clarao (%.2f)" % out)
	for i in 60:
		e.step(0.016, 0.0)
	check(e.step(0.016, 0.0) < 1.15, "volta ao normal em ~1 s")
	var r := ExposureAdapt.new(env, 1.0, true)
	for i in 300:
		r.step(0.016, 1.0)
	check(r.step(0.016, 0.0) <= 1.3 + 0.001, "Reduzir claroes limita o pico")
	var n := ExposureAdapt.new(env, 0.0, false)
	check(n.step(0.016, 1.0) >= 1.0, "de noite o tunel e mais claro (efeito ao contrario)")
