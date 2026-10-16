class_name Roadside3D
extends Node3D
## Objetos de beira de estrada em 3D (postes de luz, arvores, placas) com MultiMesh: poucos draw
## calls. Usa a lista `track.objects` (mesma da versao 2D), entao os dois visuais combinam.
## Provisorio: formas simples em codigo ate os modelos .glb de cenario (P46).

var path: TrackPath


func build(path_: TrackPath) -> void:
	path = path_
	var lamps: Array[Transform3D] = []
	var heads: Array[Transform3D] = []
	var trees: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var rails: Array[Transform3D] = []
	var signs: Array[Transform3D] = []
	for o in path.track.objects:
		var z: float = float(o["z"])
		var xu: float = float(o["x"])
		var base: Vector3 = path.world_point(z, xu)
		var yaw: float = path.yaw_at(z)
		var b := Basis(Vector3.UP, yaw)
		match String(o["kind"]):
			"lamp_post":
				lamps.append(Transform3D(b, base + Vector3.UP * 3.8))
				var inward: float = -signf(xu)
				var head_pos: Vector3 = base + b * Vector3(inward * 1.6, 7.4, 0.0)
				heads.append(Transform3D(b, head_pos))
			"tree":
				var s: float = 0.8 + fmod(z * 0.37, 0.7)
				trees.append(Transform3D(b * Basis.from_scale(Vector3(s, s, s)), base + Vector3.UP * 1.0))
				crowns.append(Transform3D(b * Basis.from_scale(Vector3(s, s, s)), base + Vector3.UP * (3.4 * s)))
			"guardrail":
				rails.append(Transform3D(b, base + Vector3.UP * 0.55))
			"sign_green":
				signs.append(Transform3D(b, base + Vector3.UP * 4.2))
	_add_multi(_cyl(0.13, 7.6, 8), lamps, _mat(Color("#4a5262"), 0.5, 0.6))
	var lamp_mat := StandardMaterial3D.new()
	lamp_mat.albedo_color = Color("#ffb347")
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color("#ffb347")
	lamp_mat.emission_energy_multiplier = 4.0
	_add_multi(_box(Vector3(1.2, 0.18, 0.5)), heads, lamp_mat)
	_add_multi(_cyl(0.28, 2.0, 6), trees, _mat(Color("#5a3a10"), 0.9, 0.0))
	var leaf := _mat(Color("#14513a"), 0.85, 0.0)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.7
	cone.height = 4.6
	cone.radial_segments = 8
	_add_multi(cone, crowns, leaf)
	_add_multi(_box(Vector3(4.0, 0.32, 0.08)), rails, _mat(Color("#c9d2e0"), 0.25, 1.0))
	var sign_mat := _mat(Color("#1f6e48"), 0.6, 0.1)
	_add_multi(_box(Vector3(5.0, 2.4, 0.15)), signs, sign_mat)


func _mat(c: Color, rough: float, metal: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _cyl(r: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = seg
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _add_multi(mesh: Mesh, xforms: Array[Transform3D], mat: Material) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	add_child(mi)
