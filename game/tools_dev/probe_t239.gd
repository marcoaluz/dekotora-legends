extends SceneTree
## Sonda da T-239: lista as superficies de luz (materiais lamp_* e outros com emissao) de cada caminhao, com a caixa
## (em metros do caminhao: x lado, y altura, z = da traseira do bau para tras positivo). Sem tela.
## Uso: godot --headless --path game -s res://tools_dev/probe_t239.gd -- [--model=dekotora_truck_base_chata] [--rear=1.5]
##   --rear=M: so superficies com z > -M (perto da traseira), com as pecas soltas de cada uma.
##   --box=x0,y0,z0,x1,y1,z1: pecas soltas de QUALQUER material inteiras dentro da caixa.


func _initialize() -> void:
	var only: String = ""
	var rear: float = -1.0
	var box: AABB = AABB()
	var use_box: bool = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--model="):
			only = a.get_slice("=", 1)
		elif a.begins_with("--rear="):
			rear = float(a.get_slice("=", 1))
		elif a.begins_with("--box="):
			var c: PackedFloat64Array = a.get_slice("=", 1).split_floats(",")
			box = AABB(Vector3(c[0], c[1], c[2]), Vector3(c[3] - c[0], c[4] - c[1], c[5] - c[2]))
			use_box = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--truck="):                # T-239: --truck=corpo:cabine -> o que sobrou na porta e as setas
			_truck(a.get_slice("=", 1).get_slice(":", 0), a.get_slice("=", 1).get_slice(":", 1))
			quit(0)
			return
	var dir := DirAccess.open(TruckNode.MODEL_DIR)
	for f in dir.get_files():
		if not f.ends_with(".glb") or (only != "" and not f.begins_with(only)):
			continue
		var root: Node3D = (load(TruckNode.MODEL_DIR + f) as PackedScene).instantiate() as Node3D
		print("MODEL ", f)
		for mi in root.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			var t: Transform3D = PartFit.rel_xform(m, root)
			for s in m.mesh.get_surface_count():
				var mat: Material = m.mesh.surface_get_material(s)
				if mat == null:
					continue
				var nm: String = mat.resource_name
				if use_box:
					var arr2: Array = m.mesh.surface_get_arrays(s)
					for c in _clusters(arr2[Mesh.ARRAY_VERTEX], arr2[Mesh.ARRAY_INDEX], t):
						var cb2: AABB = c
						if box.encloses(cb2):
							print("     piece ", m.name, " ", nm, " pos=", cb2.position.snapped(Vector3.ONE * 0.01), " size=", cb2.size.snapped(Vector3.ONE * 0.01))
					continue
				var lit: bool = nm.begins_with("lamp") or nm.contains("neon") or nm.contains("andon") \
						or (mat is BaseMaterial3D and (mat as BaseMaterial3D).emission_enabled)
				if not lit:
					continue
				var arr: Array = m.mesh.surface_get_arrays(s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				var b := AABB(t * v[0], Vector3.ZERO)
				for p in v:
					b = b.expand(t * p)
				if rear > 0.0 and b.end.z < -rear:
					continue
				print("  ", m.name, " s", s, " ", nm, " pos=", b.position.snapped(Vector3.ONE * 0.01), " size=",
						b.size.snapped(Vector3.ONE * 0.01), " nv=", v.size())
				if rear > 0.0:
					for c in _clusters(v, arr[Mesh.ARRAY_INDEX], t):
						var cb: AABB = c
						if cb.end.z >= -rear:
							print("     piece ", nm, " pos=", cb.position.snapped(Vector3.ONE * 0.01), " size=", cb.size.snapped(Vector3.ONE * 0.01))
		root.free()
	quit(0)


## Pecas soltas (componentes ligados por vertice na mesma posicao) de uma superficie, como caixas.
func _clusters(v: PackedVector3Array, idx: PackedInt32Array, t: Transform3D) -> Array:
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(v.size())
	for i in v.size():
		parent[i] = i
	var by_pos: Dictionary = {}
	for i in v.size():
		var key: Vector3i = Vector3i((v[i] * 1000.0).round())
		if by_pos.has(key):
			_union(parent, i, int(by_pos[key]))
		else:
			by_pos[key] = i
	for k in range(0, idx.size(), 3):
		_union(parent, idx[k], idx[k + 1])
		_union(parent, idx[k], idx[k + 2])
	var boxes: Dictionary = {}
	for i in v.size():
		var r: int = _find(parent, i)
		var p: Vector3 = t * v[i]
		boxes[r] = (boxes[r] as AABB).expand(p) if boxes.has(r) else AABB(p, Vector3.ZERO)
	var out: Array = boxes.values()
	out.sort_custom(func(a: AABB, b: AABB) -> bool: return a.position.y * 100.0 + a.position.x < b.position.y * 100.0 + b.position.x)
	return out


func _find(p: PackedInt32Array, i: int) -> int:
	while p[i] != i:
		p[i] = p[p[i]]
		i = p[i]
	return i


func _union(p: PackedInt32Array, a: int, b: int) -> void:
	var ra: int = _find(p, a)
	var rb: int = _find(p, b)
	if ra != rb:
		p[ra] = rb


func _truck(body: String, cab: String) -> void:
	var t := TruckNode.new()
	t.body_kind = body
	if cab != "":
		t.cab_kind = cab
	t._ready()
	var data: Dictionary = t._sockets
	var z: AABB = RearDoorLamps.zone(data)
	print("ZONE ", z)
	for mi in t.model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat: Material = m.mesh.surface_get_material(s)
			if mat != null and mat.resource_name.begins_with("lamp_") and z.size != Vector3.ZERO:
				for p in LampMesh.pieces(m, s, t.model, z):
					print("LEFT ", m.name, " lod=", m.get_meta("lod", 0), " par=", m.get_parent().name, " ", mat.resource_name, " ", p.box)
	for i in 4:
		print("SIGNAL ", i, " ", t.signals.spots[i], " ", t.signals.box_of(i, t))
		for n in t.signals.slots[i]:
			print("    part ", PartFit.rel_xform(n, t) * (n as MeshInstance3D).mesh.get_aabb())
	t.free()
