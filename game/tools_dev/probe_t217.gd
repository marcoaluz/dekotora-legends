extends SceneTree
## T-217: numbers of the route ambience without a window: triangles/surfaces of every opposite-traffic model, the
## stone wall runs per route and how many opposite vehicles each route has.
## Uso: godot --headless --path game -s res://tools_dev/probe_t217.gd


func _initialize() -> void:
	for e in OppositeTraffic3D.MIX:
		var p: String = "%s%s.glb" % [OppositeTraffic3D.DIR, String(e[0])]
		if not ResourceLoader.exists(p):
			print("MODEL %s ausente" % e[0])
			continue
		var m: ArrayMesh = GlbMesh.merged(p)
		var tris: int = 0
		for s in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(s)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			tris += (idx.size() if not idx.is_empty() else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()) / 3
		print("MODEL %-14s tri=%6d superficies=%d tamanho=%s" % [e[0], tris, m.get_surface_count(), m.get_aabb().size])
	for rid in CutLayout.RUNS:
		print("CUTS %s %s" % [rid, CutLayout.RUNS[rid]])
	quit()
