extends TestCase
## T-163/T-164/T-169: pecas novas de cenario (so visuais). Viaduto que cruza por cima (vao livre, pilares fora da pista
## e da ferrovia), postes de energia (fora da mureta, longe de tuneis/trechos e de baixo do viaduto), semaforos de faixa
## nos tuneis (ligados aos eventos) e os modelos reduzidos para o celular (montanhas, arvore, agua, poste, viaduto).

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func _route(rid: String) -> Array:
	var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	return [route, TrackPath.new(route.build_track())]


func _tris(path: String) -> int:
	var m: ArrayMesh = GlbMesh.merged(path)
	var n: int = 0
	for s in m.get_surface_count():
		var a: Array = m.surface_get_arrays(s)
		var idx: Variant = a[Mesh.ARRAY_INDEX]
		n += ((idx as PackedInt32Array).size() if idx != null else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
	return n


func test_reduced_models_fit_the_phone_budget() -> void:
	for i in 4:
		var p: String = BackdropKit.GLB_DIR + BackdropKit.MOUNTAINS[i] + ".glb"
		check(ResourceLoader.exists(p), "existe " + p)
		check(_tris(p) <= 1000, "macico com ate 1000 triangulos: %d" % _tris(p))
	check(_tris(BackdropKit.TREE) <= 400, "arvore de folhas com ate 400 triangulos: %d" % _tris(BackdropKit.TREE))
	check(ResourceLoader.exists(BackdropKit.WATER_NRM), "mapa de ondas existe")
	check(ResourceLoader.exists(BackdropKit.LEAVES_TEX), "textura das folhas existe")
	check(_tris(PontesKit.DIR + "power_pole_tr.glb") <= 300, "poste com transformador ate 300 triangulos")
	check(_tris(PontesKit.DIR + "overpass_deck.glb") <= 600, "modulo do viaduto ate 600 triangulos")
	check(_tris(PontesKit.DIR + "overpass_deck_lite.glb") <= 100, "modulo leve do viaduto ate 100 triangulos")
	var tree: ArrayMesh = BackdropKit.tree_mesh(null)
	check_eq(tree.get_surface_count(), 2, "arvore: tronco + folhas")


func test_overpass_clears_the_road_and_keeps_piers_off_it() -> void:
	var total: int = 0
	for rid in ROUTES:
		var r: Array = _route(rid)
		var route: RouteDef = r[0]
		var path: TrackPath = r[1]
		var deck: float = RoadMesh.deck_height(route.scenery)
		var rails: Array[RailLine] = RailwayLayout.lines_for(rid, route.scenery, path)
		var ov := Overpass3D.new()
		ov.build(path, rid, null, -1.2 - deck, rails)
		check_eq(ov.spans.size(), OverpassLayout.for_route(rid).size(), rid + ": viadutos montados")
		for k in ov.spans.size():
			var o: Dictionary = OverpassLayout.for_route(rid)[k]
			var z: float = float(o["z"])
			check(not RoadMesh.in_tunnel(z, route.tunnels, 80.0), rid + ": viaduto longe dos tuneis")
			check(LaneSections.at(path.track.events, z, 80.0) == null, rid + ": viaduto longe dos trechos de 2 faixas")
			for l in rails:
				if l.kind == RailLine.Kind.CROSSING:
					check(absf(l.z_cross - z) > 150.0, rid + ": longe do viaduto de trem")
			var ax: Dictionary = OverpassLayout.axis(path, o)
			var span: Vector2 = ov.spans[k]
			check(span.x < -100.0 and span.y > 100.0, rid + ": viaduto passa bem alem da pista %s" % span)
			var s: float = span.x
			while s <= span.y:
				var q: Vector3 = (ax["c"] as Vector3) + (ax["d"] as Vector3) * s
				var n: Dictionary = Overpass3D.nearest_road(path, q)
				if float(n["dist"]) < 16.0:
					var free: float = float(ax["top"]) - OverpassLayout.BEAM_BOTTOM - float(n["y"])
					check(free >= OverpassLayout.CLEAR - 0.3, rid + ": vao livre %.1f m em s=%.0f" % [free, s])
				s += 5.0
		for p in ov.piers:
			total += 1
			check(float(Overpass3D.nearest_road(path, p)["dist"]) >= OverpassLayout.PIER_ROAD_GAP, rid + ": pilar fora da pista")
		ov.free()
	check(total >= 8, "pilares colocados: %d" % total)


func test_power_poles_stay_outside_and_away_from_tunnels_and_overpass() -> void:
	for rid in ROUTES:
		var r: Array = _route(rid)
		var route: RouteDef = r[0]
		var path: TrackPath = r[1]
		var poles: Array = PowerLineLayout.poles(rid, route.scenery, path.track, route.tunnels)
		if rid == "kanto_2_viaduct":
			check(poles.is_empty(), "cidade (viaduto) sem postes")
			continue
		check(poles.size() > 20, rid + ": postes ao longo da rota %d" % poles.size())
		check(PowerLineLayout.LATERAL_M > RoadMesh.BARRIER_IN + RoadMesh.BARRIER_W, "postes fora da mureta")
		var out: Array = OverpassLayout.keep_out(path, rid)
		for p in poles:
			check(not RoadMesh.in_tunnel(float(p[0]), route.tunnels, 60.0), rid + ": poste fora do tunel")
			check(LaneSections.at(path.track.events, float(p[0]), 40.0) == null, rid + ": poste fora do trecho de 2 faixas")
		var kept: Array = PowerLines3D.filter_overpass(path, poles, out)
		var runs_before: int = PowerLineLayout.corridors(poles).size()
		var runs_after: int = PowerLineLayout.corridors(kept).size()
		for i in kept.size():
			var a: Vector3 = PowerLines3D.transform_of(path, kept[i]).origin
			check(not OverpassLayout.blocked(out, a, 2.0), rid + ": nenhum poste sob o viaduto")
			if i > 0 and int(kept[i - 1][3]) == int(kept[i][3]):
				var m: Vector3 = (PowerLines3D.transform_of(path, kept[i - 1]).origin + a) * 0.5
				check(not OverpassLayout.blocked(out, m, 2.0), rid + ": nenhum fio atravessando o viaduto")
		if rid == "kanto_3_mountain":
			check(runs_after > runs_before, "montanha: a linha de postes e cortada no viaduto")


func test_tunnel_lane_signals_follow_closed_lanes() -> void:
	var evs := TrackEvents.new()
	var ev := TrackEvents.Event.new()
	ev.kind = TrackEvents.Kind.WORKS
	ev.z = 1000.0
	ev.length = 200.0
	ev.lo = 3
	ev.hi = 3
	evs.list.append(ev)
	check_eq(TunnelSignals3D.closed_lanes(evs, 700.0), [false, false, true] as Array[bool], "obra 300 m a frente: X na faixa 3")
	check_eq(TunnelSignals3D.closed_lanes(evs, 1100.0), [false, false, true] as Array[bool], "dentro da obra: X")
	check_eq(TunnelSignals3D.closed_lanes(evs, 300.0), [false, false, false] as Array[bool], "obra longe (700 m): setas verdes")
	check_eq(TunnelSignals3D.closed_lanes(evs, 1300.0), [false, false, false] as Array[bool], "depois da obra: setas verdes")
	var r: Array = _route("kanto_3_mountain")
	var route: RouteDef = r[0]
	var sig := TunnelSignals3D.new()
	sig.build(r[1], route.tunnels, null)
	check(sig.gantries.size() >= route.tunnels.size(), "pelo menos 1 portico por tunel")
	var saw_old: bool = false
	for g in sig.gantries:
		if (g["lanes"] as Array).size() == 2:
			saw_old = true
	check(saw_old, "tunel antigo de 2 faixas com 2 sinais")
	sig.free()
