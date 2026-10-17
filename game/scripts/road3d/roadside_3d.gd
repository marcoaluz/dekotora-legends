class_name Roadside3D
extends Node3D
## Objetos de beira de estrada em 3D (postes, arvores, placas, guard-rails, pedagio) usando os .glb do
## Blender (assets/scenery/) em MultiMesh: poucos draw calls. Le `track.objects` (mesma lista da versao 2D)
## e escolhe a vegetacao pelo cenario: litoral = palmeiras + arbustos + pedras na praia; montanha = pinheiros
## + pedras; cidade = arvores redondas/pinheiros + arbustos. Extras so visuais (semente fixa, sem mexer na sim).

const DIR := "res://assets/scenery/"
const CHUNK_M: float = 150.0      # um MultiMesh por modelo e por trecho: o corte por distancia (visibility_range)
                                  # usa o centro do bloco; um bloco do tamanho da pista inteira sumia de vez

var path: TrackPath


func build(path_: TrackPath, kind: StringName = &"city") -> void:
	path = path_
	var groups: Dictionary = {}     # nome do modelo -> Array[Transform3D]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for o in path.track.objects:
		var z: float = float(o["z"])
		var xu: float = float(o["x"])
		var base: Vector3 = path.world_point(z, xu)
		var yaw: float = path.yaw_at(z)
		var k: String = String(o["kind"])
		var model: String = k
		var b := Basis(Vector3.UP, yaw)
		match k:
			"lamp_post":
				if xu < 0.0:
					b = Basis(Vector3.UP, yaw + PI)   # o braco aponta para a pista
				_pool(path.world_point(z, xu * 0.6, 0.06), yaw)   # PROTOTIPO: poca de luz de sodio no asfalto
			"tree":
				model = _tree_model(kind, rng)
				var sc: float = rng.randf_range(0.8, 1.5)
				b = Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc * rng.randf_range(0.9, 1.3), sc))
			"sign_green":
				b = Basis(Vector3.UP, yaw + PI)       # o texto fica legivel para quem vem pela pista
		_put(groups, model, Transform3D(b, base))
	_extras(groups, kind, rng)
	for key in groups:
		_add_multi(GlbMesh.merged("%s%s.glb" % [DIR, String(key).get_slice("#", 0)]), groups[key])


func _tree_model(kind: StringName, rng: RandomNumberGenerator) -> String:
	var r: float = rng.randf()
	match kind:
		&"coast":
			return "palm" if r < 0.7 else "bush"
		&"mountain":
			return "tree_pine" if r < 0.8 else "rock"
	return "tree_pine" if r < 0.45 else ("tree_round" if r < 0.85 else "bush")


func _put(groups: Dictionary, model: String, t: Transform3D) -> void:
	var key: String = "%s#%d_%d" % [model, int(floor(t.origin.x / CHUNK_M)), int(floor(t.origin.z / CHUNK_M))]
	if not groups.has(key):
		groups[key] = []
	groups[key].append(t)


## Vegetacao extra fora da pista (arbustos ao pe da mureta, pedras na praia/encosta).
func _extras(groups: Dictionary, kind: StringName, rng: RandomNumberGenerator) -> void:
	var z: float = 10.0
	var hw: float = Track.ROAD_HALF_WIDTH_M
	while z < path.track.length_m - 5.0:
		var yaw: float = path.yaw_at(z)
		var sc: float = rng.randf_range(0.6, 1.3)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * sc)
		var left: Vector3 = path.world_point(z, -rng.randf_range(11.0, 16.0) / hw)
		_put(groups, "bush" if kind != &"mountain" else "rock", Transform3D(b, left))
		if kind == &"coast":                     # pedras na areia, perto do mar
			var beach: Vector3 = path.world_point(z + 6.0, rng.randf_range(27.0, 36.0) / hw, -1.0)
			_put(groups, "rock", Transform3D(Basis(Vector3.UP, yaw + rng.randf()) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.7, 1.8)), beach))
		z += rng.randf_range(14.0, 30.0)


func _add_multi(mesh: ArrayMesh, xforms: Array) -> void:
	if xforms.is_empty() or mesh == null or mesh.get_surface_count() == 0:
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


var _pool_mat: StandardMaterial3D
## PROTOTIPO: "poca" de luz pintada no chao (quad aditivo com gradiente radial); barato no celular.
func _pool(pos: Vector3, yaw: float) -> void:
	if _pool_mat == null:
		var g := Gradient.new()
		g.set_color(0, Color(1.0, 0.62, 0.25, 0.75))
		g.set_color(1, Color(1.0, 0.5, 0.15, 0.0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_pool_mat = StandardMaterial3D.new()
		_pool_mat.albedo_texture = t
		_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var q := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(16, 22)
	q.mesh = pm
	q.material_override = _pool_mat
	q.position = pos
	q.rotation.y = yaw
	add_child(q)
