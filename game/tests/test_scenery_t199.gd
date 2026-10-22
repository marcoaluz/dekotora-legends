extends TestCase
## T-199: scenery polish (thicker Gleditsia crowns, building details, roadside details, km posts).

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func test_crown_thicken_appends_one_turned_copy() -> void:
	var src: ArrayMesh = GlbMesh.merged("res://assets/scenery/tree_leafy.glb")
	check(src != null and src.get_surface_count() > 0, "Gleditsia model loads")
	if src == null:
		return
	for s in src.get_surface_count():
		var mat: Material = src.surface_get_material(s)
		if mat == null or not mat.resource_name.begins_with("tree_leaves"):
			continue
		var a: Array = src.surface_get_arrays(s)
		var b: Array = TreeCrown.thicken(a)
		var n: int = (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		check_eq((b[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), n * 2, "leaf vertices doubled")
		check_eq((b[Mesh.ARRAY_INDEX] as PackedInt32Array).size(), (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() * 2, "leaf triangles doubled")
		var box := AABB((a[Mesh.ARRAY_VERTEX] as PackedVector3Array)[0], Vector3.ZERO)
		for v in a[Mesh.ARRAY_VERTEX]:
			box = box.expand(v)
		var inner: PackedVector3Array = (b[Mesh.ARRAY_VERTEX] as PackedVector3Array).slice(n)
		for v in inner:
			check(v.y >= box.position.y - 0.01 and v.y <= box.end.y + 0.01, "copy stays inside the crown height")
			break
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b)
		check_eq(m.get_surface_count(), 1, "thickened arrays build a valid surface")


func test_city_details_are_deterministic_and_bounded() -> void:
	var counts: Array = []
	for _k in 2:
		var d := CityDetails.new(21)
		for i in 30:
			var by := Basis(Vector3.UP, 0.1 * float(i))
			d.building(Vector3(float(i) * 30.0, 0.0, 50.0), by, -by.x, by.z, 15.0, 18.0, 3.5 * float(3 + i % 12) + 1.0,
				3.5 * float(3 + i % 12) + 1.0, Color("#9a958c"), i % 3, i % 4 == 0, i % 3 == 0, float(i) * 30.0)
			d.house(Vector3(float(i) * 30.0, 0.0, -50.0), by, 9.0, 12.0, 7.0, i % 2 == 0, float(i) * 30.0, 1.0)
		counts.append(Vector2i(d.near_count, d.far_count))
	check_eq(counts[0], counts[1], "same seed = same details")
	check(counts[0].x > 30 and counts[0].y >= 60, "details were added (%s)" % str(counts[0]))
	check(counts[0].x < 60 * 30, "near details stay bounded (%d)" % counts[0].x)


func test_km_post_digits_and_joints_on_every_route() -> void:
	for rid in ROUTES:
		var def: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
		var path := TrackPath.new(def.build_track())
		var f := RoadFurniture.new()
		var tunnels: Array[Vector2] = def.tunnels
		f.build(path, def.scenery, load("res://data/time/night.tres") as TimeOfDay, tunnels, PackedStringArray(["Yokohama", "Atami"]))
		var boxes: int = 0
		for bi in f._blocks:
			boxes += (f._blocks[bi] as Array).size()
		check(boxes > int(path.track.length_m / RoadDetails.JOINT_M), rid + ": joints and posts added (%d boxes)" % boxes)
		check(f.faces_layer().quad_count() >= int(path.track.length_m / 100.0) - 2, rid + ": km post digits")
		f.free()
