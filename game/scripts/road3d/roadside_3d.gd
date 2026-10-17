class_name Roadside3D
extends Node3D
## Objetos de beira de estrada em 3D (postes, arvores, placas, guard-rails, pedagio) usando os .glb do
## Blender (assets/scenery/) em MultiMesh: poucos draw calls. Le `track.objects` (mesma lista da versao 2D)
## e escolhe a vegetacao pelo cenario: litoral = palmeiras + arbustos + pedras na praia; montanha = pinheiros
## + pedras; cidade = arvores redondas/pinheiros + arbustos. Extras so visuais (semente fixa, sem mexer na sim).
## Postes acesos (TimeOfDay.lamps_on): "poca" de luz de sodio pintada no asfalto (quad aditivo, sem luz real:
## o Compatibility so aceita 8 luzes por objeto). De dia as lampadas ficam apagadas.

const DIR := "res://assets/scenery/"
const CHUNK_M: float = 150.0      # um MultiMesh por modelo e por trecho: o corte por distancia (visibility_range)
                                  # usa o centro do bloco; um bloco do tamanho da pista inteira sumia de vez
const POOL := "pool"              # chave dos grupos das pocas de luz

var path: TrackPath
var tod: TimeOfDay
var _pool_mesh: PlaneMesh
var _lamp_off: ArrayMesh


func build(path_: TrackPath, kind: StringName = &"city", tod_: TimeOfDay = null, tunnels: Array[Vector2] = []) -> void:
	path = path_
	tod = tod_ if tod_ != null else TimeOfDay.by_id(&"night")
	var deck: float = RoadMesh.deck_height(kind)    # viaduto: o que fica alem da mureta esta la embaixo, no chao
	var groups: Dictionary = {}     # nome do modelo -> Array[Transform3D]
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for o in path.track.objects:
		var z: float = float(o["z"])
		var xu: float = float(o["x"])
		if RoadMesh.in_tunnel(z, tunnels, 6.0):
			continue                                  # dentro do tunel nao ha postes nem arvores
		var outside: bool = absf(xu) * Track.ROAD_HALF_WIDTH_M > RoadMesh.BARRIER_IN
		var base: Vector3 = path.world_point(z, xu, -deck if outside else 0.0)
		var yaw: float = path.yaw_at(z)
		var k: String = String(o["kind"])
		var model: String = k
		var b := Basis(Vector3.UP, yaw)
		match k:
			"lamp_post":
				if xu < 0.0:
					b = Basis(Vector3.UP, yaw + PI)   # o braco aponta para a pista
				if tod.lamps_on and tod.pool_energy > 0.0:
					_put(groups, POOL, Transform3D(Basis(Vector3.UP, yaw), path.world_point(z, xu * 0.6, 0.06)))
			"tree":
				model = _tree_model(kind, rng)
				var sc: float = rng.randf_range(0.8, 1.5)
				b = Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(sc, sc * rng.randf_range(0.9, 1.3), sc))
			"sign_green":
				if deck > 0.0:
					continue                          # no viaduto as placas ficam nos porticos
				b = Basis(Vector3.UP, yaw + PI)       # o texto fica legivel para quem vem pela pista
		_put(groups, model, Transform3D(b, base))
	_extras(groups, kind, rng, deck, tunnels)
	var pool_mat: StandardMaterial3D = _pool_material()
	for key in groups:
		var name: String = String(key).get_slice("#", 0)
		if name == POOL:
			_add_multi(_pool(), groups[key], pool_mat)
		elif name == "lamp_post" and not tod.lamps_on:
			_add_multi(_lamp_unlit(), groups[key])
		else:
			_add_multi(GlbMesh.merged("%s%s.glb" % [DIR, name]), groups[key])


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
func _extras(groups: Dictionary, kind: StringName, rng: RandomNumberGenerator, deck: float, tunnels: Array[Vector2]) -> void:
	var z: float = 10.0
	var hw: float = Track.ROAD_HALF_WIDTH_M
	while z < path.track.length_m - 5.0:
		var yaw: float = path.yaw_at(z)
		var sc: float = rng.randf_range(0.6, 1.3)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3.ONE * sc)
		var left: Vector3 = path.world_point(z, -rng.randf_range(14.5, 19.0) / hw, -deck)
		if RoadMesh.in_tunnel(z, tunnels, 6.0):
			z += 20.0
			continue
		_put(groups, "bush" if kind != &"mountain" else "rock", Transform3D(b, left))
		if kind == &"coast":                     # pedras na areia, perto do mar
			var beach: Vector3 = path.world_point(z + 6.0, rng.randf_range(27.0, 36.0) / hw, -1.0)
			_put(groups, "rock", Transform3D(Basis(Vector3.UP, yaw + rng.randf()) * Basis.from_scale(Vector3.ONE * rng.randf_range(0.7, 1.8)), beach))
		z += rng.randf_range(14.0, 30.0)


func _add_multi(mesh: Mesh, xforms: Array, mat: Material = null) -> void:
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
	if mat != null:
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _pool() -> PlaneMesh:
	if _pool_mesh == null:
		_pool_mesh = PlaneMesh.new()
		_pool_mesh.size = Vector2(16, 22)
	return _pool_mesh


## Gradiente radial laranja (sodio) somado ao asfalto; a forca vem do preset de hora do dia.
func _pool_material() -> StandardMaterial3D:
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.62, 0.25, 1.0))
	g.set_color(1, Color(1.0, 0.5, 0.15, 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.albedo_color = Color(1, 1, 1, tod.pool_energy)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


## Poste com a lampada apagada (copia da malha sem emissao): usado de dia.
func _lamp_unlit() -> ArrayMesh:
	if _lamp_off == null:
		_lamp_off = GlbMesh.merged(DIR + "lamp_post.glb").duplicate() as ArrayMesh
		for s in _lamp_off.get_surface_count():
			var m: StandardMaterial3D = _lamp_off.surface_get_material(s) as StandardMaterial3D
			if m != null and m.emission_enabled:
				var off: StandardMaterial3D = m.duplicate() as StandardMaterial3D
				off.emission_enabled = false
				off.albedo_color = Color("#d8dde4")
				_lamp_off.surface_set_material(s, off)
	return _lamp_off
