class_name TruckGround
extends RefCounted
## Altura do caminhao em relacao ao chao (T-171). A origem do TruckNode e "a traseira do bau no chao" (y = 0), mas o
## que encosta no chao de verdade e o pneu. Mede o ponto mais baixo das rodas "wheel_*" (malhas) no espaco de `root`
## e o topo de uma superficie (piso/plataforma) de um cenario, sem precisar da arvore de cena.


## Transform de `n` no espaco de `root` (somando os pais ate chegar em `root`).
static func xform_to(root: Node, n: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## Menor y (m) dos vertices das malhas cujo nome comeca com `prefix`, no espaco de `root`. INF se nao achar.
## Usa os vertices (nao a caixa da malha), para a caixa girada nao baixar o ponto do pneu.
static func lowest_y(root: Node, prefix: String = "wheel_") -> float:
	var low: float = INF
	for n in root.find_children(prefix + "*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var t: Transform3D = xform_to(root, mi)
		for s in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			for v in verts:
				low = minf(low, (t * v).y)
	return low


## Ponto mais baixo dos pneus do caminhao (m, no espaco do TruckNode/modelo). 0 se o modelo nao tem rodas.
static func wheel_bottom(model: Node) -> float:
	var y: float = lowest_y(model, "wheel_")
	return 0.0 if y == INF else y


## Topo (maior y, m) das malhas de `root` cujo nome contem `name_part` (ex.: "turntable" do galpao). -INF se nao achar.
static func top_of(root: Node, name_part: String) -> float:
	var top: float = -INF
	for n in root.find_children("*" + name_part + "*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi.mesh == null:
			continue
		var box: AABB = xform_to(root, mi) * mi.mesh.get_aabb()
		top = maxf(top, box.end.y)
	return top
