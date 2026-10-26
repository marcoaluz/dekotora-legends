extends TestCase
## T-186: biblioteca de cenario inteira no jogo: todas as arvores misturadas por bioma em bosques (nunca em fila),
## 2 niveis (LOD) por arvore, os 2 postes de luz por tipo de trecho, pessoas no pedagio/viaduto e o retrato do duelo.

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func _setup(rid: String) -> Array:
	var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	var path := TrackPath.new(route.build_track())
	return [route, path]


func _trees(rid: String) -> Array:
	var s: Array = _setup(rid)
	var route: RouteDef = s[0]
	var none: Callable = func(_z: float, _l: float, _p: Vector3) -> bool: return false
	return RoadsideTrees.place(s[1], route.scenery, 186 + rid.hash(), RoadMesh.deck_height(route.scenery), none, [])


func test_every_species_has_both_lods() -> void:
	for kind in RoadsideTrees.MIX:
		for e in RoadsideTrees.MIX[kind]:
			var m: String = String(e[0])
			check(ResourceLoader.exists("res://assets/scenery/%s.glb" % m), "%s.glb existe" % m)
			check(ResourceLoader.exists("res://assets/scenery/%s_lod1.glb" % m), "%s_lod1.glb existe (LOD1)" % m)
			if m.begins_with("tree_leafy"):
				check(ResourceLoader.exists("res://assets/textures/backdrop/%s_leaves.png" % m), "%s: atlas de folhas" % m)


func test_all_species_of_the_biome_appear_and_deterministic() -> void:
	for rid in ROUTES:
		var a: Array = _trees(rid)
		var b: Array = _trees(rid)
		check_eq(a.size(), b.size(), "%s: mesma semente, mesma quantidade" % rid)
		var same: bool = a.size() == b.size()
		for i in mini(a.size(), b.size()):
			same = same and a[i][0] == b[i][0] and (a[i][1] as Transform3D).is_equal_approx(b[i][1])
		check(same, "%s: mesmo cenario com a mesma semente" % rid)
		var seen: Dictionary = {}
		for t in a:
			seen[t[0]] = true
		var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		for e in RoadsideTrees.MIX[route.scenery]:
			check(seen.has(String(e[0])), "%s: a especie %s aparece" % [rid, e[0]])


func test_groves_not_rows_scale_and_yaw() -> void:
	var s: Array = _setup("kanto_3_mountain")
	var trees: Array = _trees("kanto_3_mountain")
	var lats: Array[float] = []
	var yaws: Dictionary = {}
	for t in trees:
		var xf: Transform3D = t[1]
		var sc: float = xf.basis.get_scale().x
		check(sc >= 0.79 and sc <= 1.31, "escala 0,8-1,3 (%.2f)" % sc)
		var tr3: Vector3 = FreecamMath.nearest(s[1], xf.origin)
		check(absf(tr3.y) >= RoadsideTrees.LAT.x - 0.01, "fora da mureta (%.1f m)" % tr3.y)
		lats.append(absf(tr3.y))
		yaws[int(xf.basis.get_euler().y * 4.0)] = true
	var mean: float = 0.0
	for l in lats:
		mean += l
	mean /= float(lats.size())
	var dev: float = 0.0
	for l in lats:
		dev += (l - mean) * (l - mean)
	dev = sqrt(dev / float(lats.size()))
	check(dev > 3.0, "nao estao em fila: distancia lateral varia (desvio %.1f m)" % dev)
	check(yaws.size() >= 20, "giro aleatorio (%d valores diferentes)" % yaws.size())


func test_coast_sea_side_only_palms() -> void:
	var s: Array = _setup("kanto_1_coast")
	for t in _trees("kanto_1_coast"):
		var lat: float = FreecamMath.nearest(s[1], (t[1] as Transform3D).origin).y
		if lat > 0.0:
			check(String(t[0]) in RoadsideTrees.PALMS, "lado do mar so tem coqueiro/arbusto (%s)" % t[0])


func test_rail_keeps_trees_out() -> void:
	var s: Array = _setup("kanto_3_mountain")
	var route: RouteDef = s[0]
	var rails: Array = RailwayLayout.lines_for("kanto_3_mountain", route.scenery, s[1])
	var none: Callable = func(_z: float, _l: float, _p: Vector3) -> bool: return false
	for t in RoadsideTrees.place(s[1], route.scenery, 7, 0.0, none, rails):
		var tr3: Vector3 = FreecamMath.nearest(s[1], (t[1] as Transform3D).origin)
		var bad: bool = tr3.y < 0.0 and tr3.x > 1260.0 and tr3.x < 2060.0 and absf(absf(tr3.y) - 38.0) < RoadsideTrees.RAIL_CLEAR - 0.5
		check(not bad, "arvore em cima da ferrovia em z %.0f" % tr3.x)


func test_two_lamp_models_by_stretch() -> void:
	var none: Array[Vector2] = []
	var bridge: Array[Vector2] = [Vector2(2200.0, 300.0)]
	check_eq(Roadside3D.lamp_model(150.0, 9.0, &"city", none), "lamp_post", "praca do pedagio: poste antigo")
	check_eq(Roadside3D.lamp_model(1200.0, 9.0, &"city", none), "lamp_bridge", "viaduto da cidade: poste da ponte")
	# T-217: no chao (serra e litoral) o poste de braco curvo longo (lamp_arc); antes lamp_bridge / lamp_post
	check_eq(Roadside3D.lamp_model(1200.0, 0.0, &"mountain", none), "lamp_arc", "serra: braco curvo (T-217)")
	check_eq(Roadside3D.lamp_model(1200.0, 0.0, &"coast", none), "lamp_arc", "litoral: braco curvo (T-217)")
	check_eq(Roadside3D.lamp_model(2300.0, 0.0, &"coast", bridge), "lamp_bridge", "ponte do litoral: poste da ponte")


func test_people_kit() -> void:
	check(PeopleKit.available(), "person.glb importado")
	var m: ArrayMesh = GlbMesh.merged(PeopleKit.DIR + "person.glb")
	var cols: Variant = m.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	check(cols != null, "pessoa tem cor por vertice (regioes)")
	var regions: Dictionary = {}
	if cols != null:
		for c in (cols as PackedColorArray):
			regions[snappedf(c.r, 0.25)] = true
	check_eq(regions.size(), 5, "5 regioes: pele, cabelo, camisa, calca, sapato")
	var rng := RandomNumberGenerator.new()
	var g: Node3D = PeopleKit.group([PeopleKit.stand(Vector3.ZERO, Vector3.FORWARD, 1.0)], [PeopleKit.look(rng)], null)
	check_eq(g.get_child_count(), 2, "perto e longe (2 LODs)")
	var mm: MultiMesh = (g.get_child(0) as MultiMeshInstance3D).multimesh
	check(mm.use_colors and mm.use_custom_data, "cor + dados por copia (armadilha: dados sem cor viram COLOR)")
	g.free()
	for rid in ["kanto_2_viaduct", "kanto_3_mountain"]:
		var s: Array = _setup(rid)
		var holder := Node3D.new()
		PeopleKit.populate(holder, s[1], rid, null)
		var root: Node = holder.get_node_or_null("PeopleKit")
		check(root != null and root.get_child_count() == 2, "%s: grupo do pedagio + grupo do viaduto" % rid)
		if root != null and root.get_child_count() > 1:
			check_eq((root.get_child(0).get_child(0) as MultiMeshInstance3D).multimesh.instance_count, 5, "%s: 5 no pedagio" % rid)
			check_eq((root.get_child(1).get_child(0) as MultiMeshInstance3D).multimesh.instance_count, 5, "%s: 5 no viaduto" % rid)
		holder.free()


func test_duel_portrait_art() -> void:
	check(ResourceLoader.exists(DuelBand.BUST_BASE), "retrato: busto")
	check(ResourceLoader.exists(DuelBand.BUST_SHIRT), "retrato: camisa (pinta com a cor do caminhao)")
