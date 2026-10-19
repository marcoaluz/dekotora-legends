extends SceneTree
## T-146 depuracao: monta os eventos de uma rota e imprime as malhas do kit (AABB, superficies, materiais).
## godot --headless --path game -s res://tools_dev/debug_kit.gd -- --route=kanto_3_mountain


func _initialize() -> void:
	var rid: String = "kanto_3_mountain"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route="):
			rid = a.substr(8)
	var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	var track: Track = route.build_track()
	track.events = TrackEvents.new()
	for d in route.events:
		track.events.add(d)
	var path := TrackPath.new(track)
	var tod: TimeOfDay = TimeOfDay.by_id(&"day")
	var b := TrackEvents3D.new()
	get_root().add_child(b)
	b.build(path, tod)
	print("contagem: ", b.counts)
	for mi in b.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		print("  ", mi.get_parent().name, " aabb=", m.get_aabb(), " sup=", m.get_surface_count(),
			" mat0=", m.surface_get_material(0) if m.get_surface_count() > 0 else null, " override=", (mi as MeshInstance3D).material_override)
	var k := KitProps3D.new()
	get_root().add_child(k)
	k.build(path, route.scenery, tod, route.tunnels)
	for mi in k.find_children("*", "MeshInstance3D", true, false):
		print("  kit ", (mi as MeshInstance3D).mesh.get_aabb(), " range=", (mi as MeshInstance3D).visibility_range_end)
	for t in route.tunnels:
		print("  tunel ", t, " ponto=", path.world_point(t.x, 0.0, 0.0))
	var jm: ArrayMesh = RoadsideKit.mesh("barrier_jersey", tod)
	print("jersey aabb=", jm.get_aabb(), " sup=", jm.get_surface_count())
	var ev: TrackEvents.Event = path.track.events.list[0]
	print("evento z=", ev.z, " full=", ev.full_z(), " fim=", ev.end_z(), " pt=", path.world_point(ev.full_z(), 0.5, 0.0))
	quit()
