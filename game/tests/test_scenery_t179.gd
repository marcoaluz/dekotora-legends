extends TestCase
## T-179: as montanhas nevadas da T-169 tem de APARECER na corrida normal (todas as rotas e a corrida rapida).
## Causas encontradas: (1) os 4 macicos estavam "do avesso" (normais e faces para baixo: via-se o lado de dentro da
## encosta de tras, escuro); (2) a camera cortava tudo alem de 900 m (o fundo dos macicos virava "laminas");
## (3) a neblina da tarde/noite apagava o resto; (4) neve so nas pontas fora da rota da montanha.

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func _arrays(i: int) -> Array:
	return BackdropKit.mountain_mesh(i).surface_get_arrays(0)


func test_massifs_face_up_and_out() -> void:
	for i in BackdropKit.MOUNTAINS.size():
		var a: Array = _arrays(i)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
		var up: int = 0
		var front: int = 0
		var tris: int = idx.size() / 3
		for t in tris:
			var i0: int = idx[t * 3]
			var i1: int = idx[t * 3 + 1]
			var i2: int = idx[t * 3 + 2]
			var fn: Vector3 = (v[i1] - v[i0]).cross(v[i2] - v[i0])   # no Godot a face da frente tem cross oposto a normal
			if fn.y < 0.0:
				front += 1
			if (n[i0] + n[i1] + n[i2]).y > 0.0:
				up += 1
		var name: String = BackdropKit.MOUNTAINS[i]
		check(up >= tris * 0.97, "%s: normais para cima (%d de %d)" % [name, up, tris])
		check(front >= tris * 0.97, "%s: faces viradas para cima/fora (%d de %d)" % [name, front, tris])


## Mesma conta do shader (BackdropKit.MOUNTAIN_SHADER): quanto do macico fica branco.
func _snow_share(i: int, amount: float) -> float:
	var a: Array = _arrays(i)
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
	var c: PackedColorArray = a[Mesh.ARRAY_COLOR]
	var thr: float = 1.0 - 0.62 * amount
	var line: float = lerpf(0.9, 0.42, amount)
	var sum: float = 0.0
	for k in v.size():
		var s_h: float = smoothstep(line, line + 0.1, v[k].y / 0.36) * smoothstep(0.2, 0.5, n[k].y)
		sum += maxf(smoothstep(thr, thr + 0.06, c[k].r), s_h)
	return sum / float(v.size())


func test_snow_is_visible_on_every_route() -> void:
	for kind in [&"mountain", &"coast", &"city"]:
		var amount: float = BackdropKit.snow_for(kind)
		for i in BackdropKit.MOUNTAINS.size():
			var share: float = _snow_share(i, amount)
			check(share >= (0.3 if kind == &"mountain" else 0.15), "%s %s: neve em %.0f%% do macico" % [kind, BackdropKit.MOUNTAINS[i], share * 100.0])
	for tid in [&"day", &"dusk", &"night"]:
		var m: ShaderMaterial = BackdropKit.mountain_material(TimeOfDay.by_id(tid), &"coast")
		check(float(m.get_shader_parameter("haze_max")) <= 0.5, "%s: a neblina propria nunca apaga a montanha" % tid)
	check(BackdropKit.MOUNTAIN_SHADER.contains("fog_disabled"), "montanha fora da neblina do jogo (300-600 m)")


func test_massifs_are_placed_far_but_inside_the_camera_view() -> void:
	check(BackdropKit.CAMERA_FAR > 900.0, "camera ve alem dos 900 m antigos")
	var tracks: Array = []
	for rid in ROUTES:
		var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		tracks.append([rid, route.scenery, TrackPath.new(route.build_track())])
	tracks.append(["corrida_rapida", &"city", TrackPath.new(Track.make_test_track())])
	for t in tracks:
		var path: TrackPath = t[2]
		var city := CityBuilder.new()
		city.build(path, 21, t[1], TimeOfDay.by_id(&"day"))
		var want: int = int(CityBuilder.MASSIF_COUNT[t[1]])
		check(city.massif_count == want or city.massif_count == want / 2, "%s: %d macicos" % [t[0], city.massif_count])
		check(city.massif_count >= 6, "%s: pelo menos 6 macicos no horizonte" % t[0])
		for it in city.massif_items:
			var xf: Transform3D = it[0]
			var w: float = xf.basis.x.length()
			var foot: float = INF
			var far: float = 0.0
			var z: float = 0.0
			while z <= path.track.length_m:
				var q: Vector3 = path.world_point(z, 0.0, 0.0)
				var d: float = Vector2(xf.origin.x - q.x, xf.origin.z - q.z).length()
				foot = minf(foot, d - w * 0.5)
				far = maxf(far, d + w * 0.72)          # canto da pegada quadrada (meia diagonal)
				z += 50.0
			check(foot >= 600.0, "%s: pe do macico longe da pista (%.0f m)" % [t[0], foot])
			check(far < BackdropKit.CAMERA_FAR - 100.0, "%s: macico inteiro dentro da vista (%.0f m)" % [t[0], far])
		city.free()
