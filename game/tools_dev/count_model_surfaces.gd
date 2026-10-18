extends SceneTree
## T-139: surfaces (~ draw calls) and triangles of each traffic model (to pick the cheapest for the accident).
## godot --headless --path game -s res://tools_dev/count_model_surfaces.gd


func _initialize() -> void:
	for m in Traffic3D.all_models():
		var n: Node3D = (load("%s%s.glb" % [Traffic3D.DIR, m]) as PackedScene).instantiate() as Node3D
		var surf: int = 0
		var tris: int = 0
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			surf += mesh.get_surface_count()
			for s in mesh.get_surface_count():
				var idx: PackedInt32Array = mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX]
				tris += (idx.size() if idx.size() > 0 else mesh.surface_get_array_len(s)) / 3
		print("%-14s superficies=%d triangulos=%d" % [m, surf, tris])
		n.free()
	quit(0)
