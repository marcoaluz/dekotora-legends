extends TestCase
## T-192 (T-188 etapa 2): cenario novo na rota inteira por padrao, arvores de codigo refeitas (folhagem em cartoes com
## atlas, 2 LODs), tom por arvore, pintura 速度落とせ empilhada dentro da faixa.

const FOLIAGE: Array[String] = ["tree_pine", "tree_cedar", "tree_round", "bush", "palm", "palm_tall", "palm_bent"]


func test_whole_route_is_the_default_and_segment_still_exists() -> void:
	check_eq(ScenicZone.mode(), "all", "padrao: rota inteira")
	for rid in ScenicZone.ZONES:
		var z: Vector2 = ScenicZone.zone(String(rid), 3000.0)
		check_eq(z, Vector2(0.0, 3000.0), "%s: zona da rota inteira" % rid)
		check(ScenicZone.pilot(String(rid)).y > ScenicZone.pilot(String(rid)).x, "%s: trecho-piloto guardado" % rid)
		check_near(ScenicZone.weight(z, 1500.0), 1.0, 0.001, "%s: relevo cheio no meio da rota" % rid)


func test_redone_trees_have_leaf_cards_and_two_lods() -> void:
	check(ResourceLoader.exists(BackdropKit.FOLIAGE_TEX), "atlas de folhagem existe")
	for n in FOLIAGE:
		check(BackdropKit.is_card_tree(n) and BackdropKit.is_card_tree(n + "_lod1"), "%s usa o material de cartoes" % n)
		var near: ArrayMesh = BackdropKit.tree_mesh_of(n, TimeOfDay.by_id(&"day"))
		var far: ArrayMesh = BackdropKit.tree_mesh_of(n + "_lod1", TimeOfDay.by_id(&"day"))
		check(near != null and far != null, "%s: LOD0 e LOD1" % n)
		if near == null or far == null:
			continue
		var leafy: bool = false
		for s in near.get_surface_count():
			var m: StandardMaterial3D = near.surface_get_material(s) as StandardMaterial3D
			if m != null and m.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				leafy = m.albedo_texture != null and m.albedo_texture.resource_path == BackdropKit.FOLIAGE_TEX
		check(leafy, "%s: folhas recortadas por alfa no atlas" % n)
		check(_tris(far) * 5 < _tris(near) * 2, "%s: LOD1 bem mais leve (%d x %d tri)" % [n, _tris(far), _tris(near)])
		check(near.get_aabb().position.y > -0.5, "%s: base no chao (no maximo meio metro enterrada)" % n)


func test_tree_tint_is_deterministic_and_green() -> void:
	var a: Color = Roadside3D.tree_tint(Vector3(10.0, 0.0, 250.0))
	check_eq(a, Roadside3D.tree_tint(Vector3(10.0, 0.0, 250.0)), "mesma posicao, mesmo tom")
	var seen: Dictionary = {}
	for i in 40:
		var c: Color = Roadside3D.tree_tint(Vector3(float(i) * 7.3, 0.0, float(i) * 31.0))
		check(c.g >= c.b and c.r <= 1.0 and c.g >= 0.75, "tom verde e sem estourar (%s)" % str(c))
		seen[snappedf(c.r, 0.05)] = true
	check(seen.size() >= 3, "tons variados (%d)" % seen.size())


func test_road_paint_stacked_inside_the_lane() -> void:
	check_eq(RoadFurniture.road_text_lines("速度落とせ"), "せ\nと\n落\n度\n速", "empilhado, 1a letra mais perto")
	check_eq(RoadFurniture.road_text_lines("80"), "80", "numero numa linha")
	check_eq(RoadFurniture.road_text_lines("↑"), "↑", "seta numa linha")
	var em_m: float = 80.0 * 0.02                         # largura de 1 caractere (fonte 80, pixel 0,02 m)
	check(em_m < 0.5 * Track.ROAD_HALF_WIDTH_M, "1 letra (%.2f m) cabe na faixa (%.1f m)" % [em_m, 0.5 * Track.ROAD_HALF_WIDTH_M])


func _tris(m: ArrayMesh) -> int:
	var n: int = 0
	for s in m.get_surface_count():
		var idx: PackedInt32Array = m.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
		n += idx.size() / 3 if idx.size() > 0 else (m.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return n
