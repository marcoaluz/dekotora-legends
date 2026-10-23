extends TestCase
## T-207: visual da praca de pedagio (so apresentacao): atlas, orcamento de triangulos e de materiais, a ilha desenhada
## no MESMO lugar da fisica, a camera da corrida nunca atravessa a cobertura/placas e as linhas tracejadas saem da zebra.


func _plaza_path() -> TrackPath:
	var t := Track.new()
	t.add_section(1200.0, 0.0)
	t.set_toll(TollPlaza.DEFAULT_Z)
	return TrackPath.new(t)


func test_atlas_map_fits_and_does_not_overlap() -> void:
	var tex: Texture2D = load(TollAtlas.ATLAS) as Texture2D
	check(tex != null and tex.get_width() == TollAtlas.SIZE, "atlas do pedagio existe (1024)")
	var ids: Array = TollAtlas.RECTS.keys()
	for i in ids.size():
		var a: Rect2i = TollAtlas.RECTS[ids[i]]
		check(a.position.x >= 0 and a.end.x <= TollAtlas.SIZE and a.end.y <= TollAtlas.SIZE, "%s dentro do atlas" % ids[i])
		for j in range(i + 1, ids.size()):
			check(not a.intersects(TollAtlas.RECTS[ids[j]]), "%s nao cobre %s" % [ids[i], ids[j]])


func test_structure_budget_and_materials() -> void:
	var path := _plaza_path()
	for lit in [false, true]:
		var g := TollGeo.new(path, path.track.toll)
		TollPaint.build(g)
		TollParts.build(g, lit)
		check(g.tris > 800 and g.tris < 4000, "triangulos no orcamento do celular (%d)" % g.tris)
		for key in ["atlas", "concrete", "paint", "band", "glow"]:
			check(g.has(key), "material %s usado" % key)
	var node := TollPlaza3D.new()
	node.build(path, TimeOfDay.by_id(&"night"), 1)
	var meshes: int = 0
	for c in node.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
	check(meshes <= 9, "poucas chamadas de desenho (%d malhas)" % meshes)
	node.free()


func test_island_drawn_where_the_physics_is() -> void:
	var p: TollPlaza = _plaza_path().track.toll
	check_near(TollPaint.LANE_LINE_M, TollPlaza.ISLAND_HALF_M, 0.001, "linha continua na face da ilha")
	check(TollParts.CUSHION_LEN > 1.0, "amortecedor no nariz")
	var span: Vector2 = TollPaint.lines_span(p)
	check(span.x < p.nose_z() - TollPlaza.GORE_M and span.y > p.tail_z() + TollPlaza.REJOIN_M, "tracejado sai de toda a zebra")
	for x in TollParts.pillar_xs():                                   # pilares em cima das ilhas, nunca na passagem
		var on_island: bool = absf(x) < TollPlaza.ISLAND_HALF_M or absf(x) > TollPlaza.OUTER_FACE_M
		check(on_island, "pilar em x=%.1f fica numa ilha" % x)


func test_race_camera_stays_under_the_canopy_and_signs() -> void:
	var path := _plaza_path()
	var rig := RaceCamRig.new(path, path.track.events)
	var sign_bottom: float = TollParts.CANOPY_H0 - 0.95
	check(RaceCamRig.TOLL_H_MAX < sign_bottom - 0.3, "camera passa por baixo das placas (%.2f < %.2f)" % [RaceCamRig.TOLL_H_MAX, sign_bottom])
	check(RaceCamRig.TOLL_H_MAX < 6.4 - 0.5, "e por baixo do portico das antenas")
	for mode in [RaceCamRig.Mode.NEAR, RaceCamRig.Mode.STANDARD, RaceCamRig.Mode.FAR]:
		rig.mode = mode
		var z: float = 100.0
		while z < 200.0:
			var c: Array[Vector3] = rig.chase_target(z, 0.5, 1.0)
			var cz: float = rig.chase_local(z, 0.5, 1.0)[0].x            # camera z along the road
			var h: float = c[0].y - path.world_point(cz, 0.0).y
			var dz: float = cz - path.track.toll.z
			if absf(dz) < TollParts.CANOPY_DZ + 0.5:
				check(h < sign_bottom - 0.3, "modo %d: embaixo da cobertura e das placas (z=%.0f, %.2f m)" % [mode, cz, h])
			if absf(dz - TollParts.GANTRY_DZ) < 0.6:
				check(h < 6.4 - 0.3, "modo %d: embaixo do portico das antenas (%.2f m)" % [mode, h])
			z += 2.0
	check(is_inf(RaceCamRig.new(TrackPath.new(Track.make_test_track())).toll_h_max(150.0)), "sem pedagio: sem limite")
