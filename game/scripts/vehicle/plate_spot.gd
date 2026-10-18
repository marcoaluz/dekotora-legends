class_name PlateSpot
extends RefCounted
## Onde a placa encosta no veiculo: raios contra os triangulos do modelo (TriangleMesh do Godot, busca em C++),
## para a placa ficar 5 mm na frente da lataria/para-choque sem tabela por modelo. Frente do veiculo = -Z.

const GAP: float = 0.005


## [TriangleMesh, Transform3D (malha -> raiz)] de cada malha visivel sob `root` que cruza a faixa da placa
## (|x| < 0,6 m e altura entre `y0` e `y1`). A malha e duplicada antes: o Mesh guarda em cache o TriangleMesh
## que gera, e o do caminhao inteiro ocupava ~10 MB por modelo para sempre; assim ele some com o array.
static func triangle_meshes(root: Node, y0: float = -INF, y1: float = INF) -> Array:
	var out: Array = []
	var list: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		list.append(root)
	var band := AABB(Vector3(-0.6, maxf(y0, -100.0), -1000.0), Vector3(1.2, minf(y1, 100.0) - maxf(y0, -100.0), 2000.0))
	for mi in list:
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or not m.visible or dying(m, root):
			continue
		var xf: Transform3D = rel_transform(m, root)
		if not (xf * m.mesh.get_aabb()).intersects(band):
			continue
		var tm: TriangleMesh = (m.mesh.duplicate() as Mesh).generate_triangle_mesh()
		if tm != null:
			out.append([tm, xf])
	return out


## `n` ou um pai ate `root` foi marcado para sair (queue_free de peca trocada no mesmo quadro).
static func dying(n: Node, root: Node) -> bool:
	var c: Node = n
	while c != null and c != root:
		if c.is_queued_for_deletion():
			return true
		c = c.get_parent()
	return false


## Transform de `n` no espaco de `root` (funciona fora da arvore de cena).
static func rel_transform(n: Node, root: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## z da superficie mais externa em volta de (x, y) no espaco da raiz (`front` = olhando de -Z); NAN se nada.
## Lanca 9 raios (3 x 3) num retangulo de meia largura `half_w` e meia altura `half_h`.
static func surface_z(tms: Array, xy: Vector2, half_w: float, front: bool, half_h: float = 0.04) -> float:
	var best: float = NAN
	var dir := Vector3(0.0, 0.0, 1.0 if front else -1.0)
	for dx in [-half_w, 0.0, half_w]:
		for dy in [-half_h, 0.0, half_h]:
			var from := Vector3(xy.x + dx, xy.y + dy, -60.0 if front else 60.0)
			for e in tms:
				var xf: Transform3D = e[1]
				var inv: Transform3D = xf.affine_inverse()
				var r: Dictionary = (e[0] as TriangleMesh).intersect_ray(inv * from, (inv.basis * dir).normalized())
				if r.is_empty():
					continue
				var z: float = (xf * (r["position"] as Vector3)).z
				if is_nan(best) or (z < best if front else z > best):
					best = z
	return best


## Transform local da placa (centro, virada para fora) para um veiculo cuja malha esta em `tms`.
## `fallback_z` e usado se os raios nao acham nada.
static func plate_transform(tms: Array, y: float, size: Vector2, front: bool, fallback_z: float) -> Transform3D:
	var z: float = surface_z(tms, Vector2(0.0, y), size.x * 0.4, front, size.y * 0.35)
	if is_nan(z):
		z = fallback_z
	z += -GAP if front else GAP
	var b := Basis(Vector3.UP, PI) if front else Basis.IDENTITY       # o quad olha para +Z
	return Transform3D(b * Basis.from_scale(Vector3(size.x, size.y, 1.0)), Vector3(0.0, y, z))
