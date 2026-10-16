class_name Roadside3D
extends Node3D
## Objetos de beira de estrada em 3D (postes, arvores, placas, guard-rails, pedagio) usando os .glb do
## Blender (assets/scenery/) em MultiMesh: poucos draw calls. Le `track.objects` (mesma lista da versao 2D).

const DIR := "res://assets/scenery/"

var path: TrackPath


func build(path_: TrackPath) -> void:
	path = path_
	var groups: Dictionary = {}     # nome do modelo -> Array[Transform3D]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for o in path.track.objects:
		var z: float = float(o["z"])
		var xu: float = float(o["x"])
		var base: Vector3 = path.world_point(z, xu)
		var yaw: float = path.yaw_at(z)
		var kind: String = String(o["kind"])
		var model: String = kind
		var b := Basis(Vector3.UP, yaw)
		match kind:
			"lamp_post":
				if xu < 0.0:
					b = Basis(Vector3.UP, yaw + PI)   # o braco aponta para a pista
			"tree":
				model = "tree_pine" if rng.randf() < 0.55 else "tree_round"
				var sc: float = rng.randf_range(0.8, 1.5)
				b = Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc * rng.randf_range(0.9, 1.3), sc))
			"sign_green":
				b = Basis(Vector3.UP, yaw + PI)       # o texto fica legivel para quem vem pela pista
		if not groups.has(model):
			groups[model] = []
		groups[model].append(Transform3D(b, base))
	for model in groups:
		_add_multi(GlbMesh.merged("%s%s.glb" % [DIR, model]), groups[model])


func _add_multi(mesh: ArrayMesh, xforms: Array) -> void:
	if xforms.is_empty() or mesh.get_surface_count() == 0:
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.visibility_range_end = 450.0
	add_child(mi)
