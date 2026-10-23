extends TestCase
## T-130: sinalizacao da pista (atlas sem sobreposicao, aparece em todas as rotas, 2 chamadas de desenho).


func test_sign_atlas_layout() -> void:
	var rs: Dictionary = SignAtlas.rects()
	var list: Array = rs.values()
	for i in list.size():
		var a: Rect2i = list[i]
		check(a.position.x >= 0 and a.position.y >= 0 and a.end.x <= SignAtlas.SIZE and a.end.y <= SignAtlas.SIZE, "dentro do atlas")
		for j in range(i + 1, list.size()):
			check(not a.intersects(list[j]), "figuras nao se sobrepoem: %s x %s" % [rs.keys()[i], rs.keys()[j]])
	for p in SignAtlas.places():
		check(SignAtlas.has("place_" + String(p)), "painel tem o lugar " + String(p))
	var tex: Texture2D = load(SignAtlas.ATLAS) as Texture2D
	check(tex != null and tex.get_width() == SignAtlas.SIZE, "atlas da sinalizacao existe (1024)")


func test_signs_on_every_route_two_draws() -> void:
	for rid in ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]:
		var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		var path := TrackPath.new(route.build_track())
		var signs := RoadSigns.new()
		signs.build(path, route.scenery, TimeOfDay.by_id(route.time_of_day), route.tunnels, route.places, String(route.id))
		var c: Dictionary = signs.counts
		check(int(c.get("limit", 0)) >= 2, rid + ": placas de limite de velocidade")
		check(int(c.get("distance", 0)) >= 1, rid + ": painel de distancia")
		check_eq(int(c.get("stop", 0)), 0, rid + ": sem 止まれ/pare: a praca de pedagio da T-207 tem placas proprias e nao para ninguem")
		check_eq(int(c.get("exit", 0)), 1, rid + ": placa de saida")
		check_eq(int(c.get("tunnel_plaque", 0)) + int(c.get("tunnel_plaque_old", 0)), route.tunnels.size(),
			rid + ": placa na boca de cada tunel (a do tunel antigo da T-153 e de pedra, no Tunnel3D)")
		if rid != "kanto_1_coast":
			check(int(c.get("chevron", 0)) > 0, rid + ": chevrons nas curvas fortes")
			check(int(c.get("curve", 0)) > 0, rid + ": aviso de curva")
		var geo: int = 0
		for g in signs.find_children("*", "GeometryInstance3D", true, false):
			geo += 1
		# T-146: faces (1) + caixas da placa do tunel (0 ou 1) + chapas/postes do kit (1 malha por bloco de 400 m)
		var blocks: int = ceili(path.track.length_m / 400.0)
		check(geo >= 2 and geo <= 2 + blocks, rid + ": sinalizacao em poucas chamadas de desenho (%d)" % geo)
		signs.free()
