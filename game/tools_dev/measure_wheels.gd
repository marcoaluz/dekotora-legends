extends SceneTree
## Dev (T-133): rodas de cada caminhao: nome, pai, posicao, raio (caixa da malha), largura e os pontos
## MOUNT_WHEEL_* (posicao/escala). Tambem as pecas de roda (calotas/rodas da loja): tamanho e eixo fino.
## godot --headless --path game -s res://tools_dev/measure_wheels.gd   (ONLY=canter filtra)


func _rel(n: Node, top: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != top and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _aabb(n: Node3D, top: Node) -> AABB:
	# caixa das malhas do no (e filhos) em eixos do pai do no (o modelo), centrada na origem do no
	var box := AABB()
	var first: bool = true
	var inv: Transform3D = Transform3D(Basis.IDENTITY, _rel(n, top).origin).affine_inverse()
	for mi in [n] + n.find_children("*", "MeshInstance3D", true, false):
		if not (mi is MeshInstance3D) or (mi as MeshInstance3D).mesh == null:
			continue
		var m: MeshInstance3D = mi
		var b: AABB = (inv * _rel(m, top)) * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func _initialize() -> void:
	var only: String = OS.get_environment("ONLY")
	for f in DirAccess.get_files_at("res://assets/vehicles/dekotora/truck/"):
		if not f.ends_with(".glb") or (only != "" and not f.contains(only)):
			continue
		var root := Node3D.new()
		root.add_child((load("res://assets/vehicles/dekotora/truck/" + f) as PackedScene).instantiate())
		print("== ", f)
		for w in root.find_children("wheel_*", "Node3D", true, false):
			var n: Node3D = w
			var b: AABB = _aabb(n, root)
			print("  %-26s pai=%-18s tipo=%s pos=(%.3f, %.3f, %.3f) filhos=%d raio=%.3f larg=%.3f centro=(%.3f,%.3f,%.3f) basis_ok=%s" % [
				n.name, n.get_parent().name, n.get_class(), n.position.x, n.position.y, n.position.z, n.get_child_count(),
				maxf(b.size.y, b.size.z) * 0.5, b.size.x, b.get_center().x, b.get_center().y, b.get_center().z,
				str(n.transform.basis.is_equal_approx(Basis.IDENTITY))])
		for mnt in root.find_children("MOUNT_WHEEL*", "Node3D", true, false):
			var e: Node3D = mnt
			print("  %-26s pai=%-18s pos=(%.3f, %.3f, %.3f) escala=%.3f" % [e.name, e.get_parent().name, e.position.x,
				e.position.y, e.position.z, e.scale.x])
		root.free()
	var cat: AccessoryCatalog = AccessoryCatalog.get_instance()
	for id in ["hubcap_decorative", "fumi_sport_rims", "jac_steel_rims"]:
		var n: Node3D = cat.instantiate(id)
		var b: AABB = _aabb(n, null)
		print("peca %s: caixa pos=%s tam=%s" % [id, str(b.position), str(b.size)])
		n.free()
	quit()
