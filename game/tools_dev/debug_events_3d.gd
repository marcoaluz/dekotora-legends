extends SceneTree
## T-139 debug: builds TrackEvents3D for one event on a straight road and prints what each batch got.
## godot --headless --path game -s res://tools_dev/debug_events_3d.gd -- --event=narrow:3@700


func _initialize() -> void:
	var spec: String = "narrow:3@700"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--event="):
			spec = a.substr(8)
	var t := Track.new()
	t.add_section(2000.0, 0.0)
	t.events = TrackEvents.new()
	t.events.add(RaceDemo.parse_event(spec))
	var path := TrackPath.new(t)
	var b := TrackEvents3D.new()
	get_root().add_child(b)
	b.build(path, TimeOfDay.by_id(&"day"))
	print("contagem: ", b.counts)
	for g in b.groups:
		for c in g.get_children():
			if c is MultiMeshInstance3D:
				print("  ", c.get_class(), " instancias=", (c as MultiMeshInstance3D).multimesh.instance_count)
			elif c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
				var m: Mesh = (c as MeshInstance3D).mesh
				print("  malha superficies=", m.get_surface_count(), " vertices=", m.surface_get_array_len(0) if m.get_surface_count() > 0 else 0)
			else:
				print("  ", c.name, " ", c.get_class())
	quit(0)
