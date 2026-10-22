extends TestCase
## T-189: scenery life (only visual): wind, birds, smoke/steam/insects, cloud shadows.


func _path() -> TrackPath:
	return TrackPath.new(Track.make_test_track())


func test_wind_names_and_material() -> void:
	check(LifeWind.is_tree("res://assets/scenery/tree_cedar.glb"), "cedar sways")
	check(LifeWind.is_tree("res://assets/scenery/palm_bent_lod1.glb"), "palm LOD sways")
	check(LifeWind.is_tree("bush"), "bush sways")
	check(not LifeWind.is_tree("res://assets/scenery/lamp_post.glb"), "lamp does not sway")
	check(LifeWind.params_for("palm_tall") == LifeWind.PALM, "palms bend more")
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.6, 0.4)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	var w: ShaderMaterial = LifeWind.windy_material(m, LifeWind.TREE, 1.0)
	check_near(float(w.get_shader_parameter("scissor")), 0.4, 0.001, "alpha scissor kept")
	check(bool(w.get_shader_parameter("use_vcol")), "vertex colour kept")
	check(w.shader.code.contains("cull_disabled"), "double-sided leaves kept")
	check(float(w.get_shader_parameter("flutter")) > 0.0, "leaves flutter")


func test_windy_copy_keeps_surfaces() -> void:
	var src := ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 3, 0)])
	src.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	src.surface_set_material(0, StandardMaterial3D.new())
	src.resource_name = "res://assets/scenery/tree_pine.glb"
	var out: ArrayMesh = LifeWind.windy_copy(src, LifeWind.TREE, 1.0)
	check_eq(out.get_surface_count(), 1, "same surfaces")
	check(out.surface_get_material(0) is ShaderMaterial, "material became the swaying shader")
	check(src.surface_get_material(0) is StandardMaterial3D, "source mesh untouched (cached .glb stays as it was)")
	check_eq(out.resource_name, src.resource_name, "explorer camera still shows the .glb")


func test_emitter_sources_deterministic() -> void:
	var path: TrackPath = _path()
	var tod: TimeOfDay = TimeOfDay.by_id(&"day")
	var a := LifeEmitters.new()
	a.setup(path, "kanto_1_coast", &"coast", tod, 2, null, [] as Array[Vector2], [] as Array[Vector2])
	var b := LifeEmitters.new()
	b.setup(path, "kanto_1_coast", &"coast", tod, 2, null, [] as Array[Vector2], [] as Array[Vector2])
	check(a.sources["smoke"].size() > 0, "coast has chimneys")
	check(a.sources["steam"].size() > 0, "ground-level road has drains")
	check_eq(a.sources["smoke"], b.sources["smoke"], "same route = same chimneys")
	var c := LifeEmitters.new()
	c.setup(path, "kanto_2_viaduct", &"city", tod, 2, null, [] as Array[Vector2], [] as Array[Vector2])
	check_eq(c.sources["steam"].size(), 0, "no drains on the elevated viaduct")
	a.free()
	b.free()
	c.free()


func test_birds_and_clouds() -> void:
	var path: TrackPath = _path()
	var birds := LifeBirds.new()
	birds.setup(path, "kanto_3_mountain", &"mountain", TimeOfDay.by_id(&"day"), 3)
	check(birds.multimesh.instance_count >= 3 * LifeBirds.FLOCK_MIN, "3 flocks of birds")
	birds.update(0.1, 500.0)
	birds.free()
	var tex: ImageTexture = CloudShadows.blob_texture(7)
	var img: Image = tex.get_image()
	check(img.get_pixel(64, 64).a > 0.8, "cloud shadow is dense in the middle")
	check(img.get_pixel(1, 1).a < 0.05, "and soft at the border")
	check(not CloudShadows.available(TimeOfDay.by_id(&"night")), "no cloud shadows at night")
