extends TestCase
## T-188 (etapa 1): cenario novo so no trecho-piloto de cada rota: terreno com relevo que nunca cobre a pista, montanhas
## do meio longe da pista, quarteiroes com recuo, ceu/luar numa COPIA da hora do dia, deterministico.

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func _path(rid: String) -> TrackPath:
	var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	return TrackPath.new(route.build_track())


func _field(rid: String) -> TerrainField:
	var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	var path := TrackPath.new(route.build_track())
	return TerrainField.new(path, route.scenery, ScenicZone.zone(rid, path.track.length_m), [], 188)


func test_zone_default_is_one_stretch_per_route() -> void:
	check_eq(ScenicZone.mode(), "segment", "padrao: so o trecho-piloto")
	for rid in ROUTES:
		var z: Vector2 = ScenicZone.zone(rid)
		check(z.y - z.x >= 700.0 and z.y - z.x <= 1100.0, "%s: trecho de ~1 km (%d-%d)" % [rid, int(z.x), int(z.y)])
		check_near(ScenicZone.weight(z, z.x), 0.0, 0.001, "%s: relevo comeca do zero" % rid)
		check_near(ScenicZone.weight(z, (z.x + z.y) * 0.5), 1.0, 0.001, "%s: relevo cheio no meio" % rid)
		check_near(ScenicZone.weight(z, z.y + 10.0), 0.0, 0.001, "%s: nada depois do trecho" % rid)


func test_nearest_finds_the_road_coordinates() -> void:
	var f: TerrainField = _field("kanto_3_mountain")
	for z in [1200.0, 1500.0, 1900.0]:
		for lat in [-60.0, -20.0, 25.0, 90.0]:
			var p: Vector3 = f.path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M)
			var n: Vector3 = f.nearest(Vector2(p.x, p.z))
			check_near(n.x, absf(lat), 1.5, "distancia ate a pista (z %d, %d m)" % [int(z), int(lat)])
			check_near(n.y, z, 5.0, "z da pista (z %d, %d m)" % [int(z), int(lat)])
			check_eq(n.z, signf(lat), "lado (z %d, %d m)" % [int(z), int(lat)])


func test_terrain_flat_near_any_road_and_rises_away() -> void:
	for rid in ROUTES:
		var f: TerrainField = _field(rid)
		var top: float = 0.0
		var z: float = f.zone.x
		while z <= f.zone.y:
			for lat in [-345.0, -200.0, -120.0, -46.0, -30.0, -16.0, 16.0, 30.0, 46.0, 120.0, 200.0, 345.0]:
				var p: Vector3 = f.path.world_point(z, lat / Track.ROAD_HALF_WIDTH_M)
				var wp := Vector2(p.x, p.z)
				var h: float = f.rel_height(z, lat, wp)
				var near: Vector3 = f.nearest(wp)
				if near.x <= TerrainField.FLAT_M and not (f.kind == &"coast" and lat > 0.0):
					check(absf(h) < 0.01, "%s: plano perto da pista (z %d, %d m, h %.2f)" % [rid, int(z), int(lat), h])
				if f.kind != &"coast" or lat < 0.0:
					check(h >= -0.001, "%s: o morro nunca afunda abaixo da pista (z %d, %d m)" % [rid, int(z), int(lat)])
				top = maxf(top, h)
			z += 50.0
		if f.kind == &"city":
			check_near(top, 0.0, 0.001, "cidade: chao plano embaixo do viaduto")
		else:
			check(top > 40.0, "%s: relevo de verdade (max %.0f m)" % [rid, top])


func test_coast_sea_side_keeps_the_beach_profile() -> void:
	var f: TerrainField = _field("kanto_1_coast")
	var z: float = (f.zone.x + f.zone.y) * 0.5
	for lat in [14.0, 20.0, 24.0]:
		check_near(f.rel_height(z, lat, Vector2.ZERO), 0.0, 0.2, "grama/areia no nivel da pista (%d m)" % int(lat))
	check_near(f.rel_height(z, 39.5, Vector2.ZERO), -1.6, 0.2, "linha d'agua igual a RoadMesh (-1,6 m)")
	check(f.rel_height(z, 200.0, Vector2.ZERO) < -4.0, "mar no meio da baia")
	check(f.rel_height(z, 420.0, Vector2(10.0, 10.0)) > 0.0, "margem do outro lado da baia (predios em terra)")


func test_mid_ridges_far_from_every_part_of_the_route() -> void:
	for rid in ["kanto_1_coast", "kanto_3_mountain"]:
		var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		var path := TrackPath.new(route.build_track())
		var r := MountainRidges.new()
		r.build(path, route.scenery, null, ScenicZone.zone(rid), 188)
		check(r.piece_count >= 3, "%s: cordilheira do meio (%d pedacos)" % [rid, r.piece_count])
		for c in r.centres:
			var best: float = INF
			var z: float = 0.0
			while z <= path.track.length_m:
				var q: Vector3 = path.center_at(z)
				best = minf(best, Vector2(c.x - q.x, c.z - q.z).length())
				z += 10.0
			check(best >= 500.0, "%s: pedaco a %.0f m da pista (>= 500)" % [rid, best])
		r.free()


func test_city_blocks_setback_and_determinism() -> void:
	var counts: Array[int] = []
	for _k in 2:
		var f: TerrainField = _field("kanto_2_viaduct")
		var tod: TimeOfDay = TimeOfDay.by_id(&"night")
		var b := CityBlocks.new()
		b.build(f, tod, OverpassLayout.keep_out(f.path, "kanto_2_viaduct"), 188)
		check(b.building_count > 60, "cidade: quarteiroes com predios (%d)" % b.building_count)
		check(b.nearest_facade_m >= 40.0, "recuo: fachada mais perto a %.1f m do eixo (>= 40)" % b.nearest_facade_m)
		counts.append(b.building_count)
		b.free()
	check_eq(counts[0], counts[1], "mesma semente, mesmos predios")


func test_coast_town_on_land_side() -> void:
	var f: TerrainField = _field("kanto_1_coast")
	var b := CityBlocks.new()
	b.build(f, TimeOfDay.by_id(&"day"), [], 188)
	check(b.building_count > 5, "litoral: casas nos morros (%d)" % b.building_count)
	b.free()


func test_atmos_tune_is_a_copy_with_moonlight() -> void:
	var night: TimeOfDay = TimeOfDay.by_id(&"night")
	var before: Color = night.sky_horizon
	var t: TimeOfDay = AtmosTune.tune(night)
	check(t != night, "copia, nao o .tres")
	check_eq(night.sky_horizon, before, "preset original intacto")
	check(t.sky_horizon.get_luminance() > before.get_luminance(), "horizonte da noite mais claro (silhuetas)")
	check(t.light_color.b > t.light_color.r, "luar azulado")
	var day: TimeOfDay = AtmosTune.tune(TimeOfDay.by_id(&"day"))
	check(day.fog_density > TimeOfDay.by_id(&"day").fog_density, "perspectiva aerea de dia")


func test_massif_smooth_normals_shared_by_position() -> void:
	if not BackdropKit.mountains_available():
		return
	var m: ArrayMesh = MassifLook.smooth(BackdropKit.mountain_mesh(0))
	var arr: Array = m.surface_get_arrays(0)
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var seen: Dictionary = {}
	var bad: int = 0
	var up: int = 0
	for i in v.size():
		var k: Vector3i = Vector3i((v[i] * 1000.0).round())
		if seen.has(k) and not (seen[k] as Vector3).is_equal_approx(n[i]):
			bad += 1
		seen[k] = n[i]
		if n[i].y > 0.0:
			up += 1
	check_eq(bad, 0, "mesma posicao, mesma normal (sem facetas)")
	check(up > v.size() * 0.9, "normais para cima (%d de %d)" % [up, v.size()])
