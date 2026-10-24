class_name PartFitSeat
extends RefCounted
## Conferencia do ASSENTO das pecas do teto e da viseira com RAIOS na malha real do caminhao (T-214), independente das
## grades que o SocketSeat usa: (1) a peca encosta na lataria (nada de vao), (2) nao entra fundo nela, (3) com o
## assento/enchimento (nos SEAT_*) a folga vista de lado fica fechada. Usado por tests/test_part_fit.gd e pelo relatorio.

const TOUCH_MAX: float = 0.015     # m: maior folga que ainda conta como "encostada" (grade de 5 cm x malha real)
const SINK_MAX: float = 0.03       # m: o quanto a peca pode entrar na lataria (fixacao, EMBED 4 mm + teto abaulado)
const EDGE_GAP_MAX: float = 0.015  # m: folga maxima na borda com o assento (sem luz por baixo)
const OVERHANG: float = 0.30       # m: mais que isto embaixo da borda = a peca passa da lataria (beiral: quina da frente sobre a cupula da americana), nao e vao

static var _truck_cache: Dictionary = {}


## TriangleMesh do caminhao (sem rodas e sem pecas montadas), no espaco de `model`. Cache por `key`.
static func truck_mesh(model: Node3D, key: String) -> TriangleMesh:
	if _truck_cache.has(key):
		return _truck_cache[key]
	var faces := PackedVector3Array()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or _skip_truck(m, model):
			continue
		faces.append_array(_faces(m, model))
	var tm := TriangleMesh.new()
	tm.create_from_faces(faces)
	_truck_cache[key] = tm
	return tm


static func _skip_truck(n: Node, root: Node) -> bool:
	var cur: Node = n
	while cur != null and cur != root:
		var nm: String = String(cur.name)
		if nm.contains("wheel") or nm.begins_with("SOCKET_") or nm.begins_with("MOUNT_") or nm.begins_with("acc_"):
			return true
		cur = cur.get_parent()
	return false


static func _faces(m: MeshInstance3D, root: Node3D) -> PackedVector3Array:
	var t: Transform3D = PartFit.rel_xform(m, root)
	var src: PackedVector3Array = m.mesh.get_faces()
	var out := PackedVector3Array()
	out.resize(src.size())
	for i in src.size():
		out[i] = t * src[i]
	return out


## TriangleMesh da peca no espaco de `model`. `seat` = inclui os nos SEAT_* (assento/enchimento).
static func part_mesh(part: Node3D, model: Node3D, seat: bool, only: Node3D = null) -> TriangleMesh:
	var faces := PackedVector3Array()
	var root: Node3D = only if only != null else part
	var list: Array = [root] if root is MeshInstance3D else []
	list.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for mi in list:
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or (not seat and String(m.name).begins_with(SocketSeat.SEAT_PREFIX)):
			continue
		faces.append_array(_faces(m, model))
	var tm := TriangleMesh.new()
	if faces.size() >= 3:
		tm.create_from_faces(faces)
	return tm


static func _hit(tm: TriangleMesh, from: Vector3, dir: Vector3) -> Variant:
	var r: Dictionary = tm.intersect_ray(from, dir)
	return (r["position"] as Vector3) if not r.is_empty() else null


## Problemas de assento de uma peca montada (lista vazia = assentada certinho).
static func problems(model: Node3D, key: String, entry: Dictionary, part: Node3D) -> Array[String]:
	var slot: String = String(entry.get("socket", ""))
	var truck: TriangleMesh = truck_mesh(model, key)
	if slot == "andon":
		var pods: Array[Node3D] = []
		for c in part.find_children("*POD*", "Node3D", true, false):
			if not String((c as Node).get_parent().name).contains("POD"):
				pods.append(c as Node3D)
		if pods.is_empty():
			return _roof_contact(model, truck, part, null, "deque")
		var out: Array[String] = []
		for p in pods:
			out.append_array(_roof_contact(model, truck, part, p, "canhao " + String(p.name).get_slice("_", String(p.name).get_slice_count("_") - 1)))
		return out
	if slot == "visor":
		var sk: Dictionary = TruckSockets.socket(TruckSockets.for_model(key + ".glb"), "visor")
		return _visor_contact(model, truck, part, float(sk.get("fill_max_z", INF)))
	return []


## Teto: folga entre o fundo da peca (ou de um canhao) e o teto embaixo, numa grade de raios verticais. Onde a folga
## passa de TOUCH_MAX na borda, um raio de lado (de fora para dentro, no meio da folga) precisa bater no assento.
static func _roof_contact(model: Node3D, truck: TriangleMesh, part: Node3D, only: Node3D, label: String) -> Array[String]:
	var out: Array[String] = []
	var pm: TriangleMesh = part_mesh(part, model, false, only)
	var box: AABB = _aabb_of(only if only != null else part, model, true)
	var seat_m: TriangleMesh = part_mesh(part, model, true) if only == null else null
	var gaps: Array[float] = []
	var open_edges: int = 0
	var first_open: String = ""
	var n: int = 9
	for i in n:
		for j in n:
			var x: float = lerpf(box.position.x + 0.03, box.end.x - 0.03, i / float(n - 1))
			var z: float = lerpf(box.position.z + 0.03, box.end.z - 0.03, j / float(n - 1))
			var bot: Variant = _hit(pm, Vector3(x, box.position.y - 0.5, z), Vector3.UP)
			if bot == null:
				continue
			var by: float = (bot as Vector3).y
			var top: Variant = _hit(truck, Vector3(x, box.end.y + 1.0, z), Vector3.DOWN)
			if top != null and (top as Vector3).y > by + 0.05:
				out.append("%s atravessa a lataria em x=%.2f z=%.2f" % [label, x, z])
				return out
			var roof: Variant = _hit(truck, Vector3(x, by + 0.05, z), Vector3.DOWN)
			if roof == null:
				continue
			var g: float = by - (roof as Vector3).y
			gaps.append(g)
			var edge: bool = i == 0 or i == n - 1 or j == 0 or j == n - 1
			if seat_m == null or not edge or g <= EDGE_GAP_MAX or g > OVERHANG:
				continue
			var dir: Vector3 = Vector3.ZERO
			if i == 0:
				dir = Vector3.RIGHT
			elif i == n - 1:
				dir = Vector3.LEFT
			elif j == 0:
				dir = Vector3.BACK
			else:
				dir = Vector3.FORWARD
			var mid := Vector3(x, (roof as Vector3).y + g * 0.5, z)
			var from: Vector3 = mid - dir * 0.6
			var h: Variant = _hit(seat_m, from, dir)
			# (a borda da caixa pode ficar ate 15 cm para dentro de um enfeite que sobra na frente/lado)
			if h == null or (h as Vector3).distance_to(from) > 0.6 + 0.15:
				open_edges += 1
				if first_open == "":
					first_open = " (ex.: x=%.2f z=%.2f folga %.3f)" % [x, z, g]
	if gaps.is_empty():
		return ["%s sem teto embaixo" % label]
	var lo: float = gaps.min()
	if lo > TOUCH_MAX:
		out.append("%s nao encosta no teto (folga minima %.3f m)" % [label, lo])
	if lo < -SINK_MAX:
		out.append("%s entra %.3f m no teto" % [label, -lo])
	if open_edges > 0:
		out.append("%s: %d pontos da borda com vao visivel de lado%s" % [label, open_edges, first_open])
	return out


static func _aabb_of(n: Node3D, model: Node3D, skip_seat: bool = false) -> AABB:
	var out := AABB()
	var first: bool = true
	var list: Array = [n] if n is MeshInstance3D else []
	list.append_array(n.find_children("*", "MeshInstance3D", true, false))
	for mi in list:
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or (skip_seat and String(m.name).begins_with(SocketSeat.SEAT_PREFIX)):
			continue
		var b: AABB = PartFit.rel_xform(m, model) * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Viseira: nas colunas do centro, (1) as costas (sem enchimento) nao entram fundo na testa (raio de tras para a frente
## na altura do meio) e (2) olhando de cima, o tampo (aba + enchimento) chega ate a testa ou ate a frente do deque, onde
## o enchimento para (`fill_max_z`): nenhuma faixa de vao entre a viseira e a cabine.
static func _visor_contact(model: Node3D, truck: TriangleMesh, part: Node3D, fill_max_z: float) -> Array[String]:
	var out: Array[String] = []
	var bare: TriangleMesh = part_mesh(part, model, false)
	var full: TriangleMesh = part_mesh(part, model, true)
	var box: AABB = _aabb_of(part, model, true)
	var y: float = box.position.y + box.size.y * 0.5
	var worst_gap: float = -INF
	var worst_sink: float = -INF
	for i in 7:
		var x: float = lerpf(-0.6, 0.6, i / 6.0)
		var testa: Variant = _hit(truck, Vector3(x, y, box.position.z - 1.0), Vector3.BACK)   # da frente para tras (+z)
		if testa == null:
			continue
		var tz: float = (testa as Vector3).z
		var b0: Variant = _hit(bare, Vector3(x, y, tz + 0.6), Vector3.FORWARD)               # de tras para a frente (-z)
		if b0 != null:
			worst_sink = maxf(worst_sink, (b0 as Vector3).z - tz)
		# de cima: do ponto da testa para a frente, o 1o z em que o raio para baixo bate no tampo da peca
		var lim: float = minf(tz, fill_max_z + 0.004)
		var z: float = lim - 0.005
		var covered: float = INF
		while z > box.position.z:
			var hp: Variant = _hit(full, Vector3(x, box.end.y + 0.5, z), Vector3.DOWN)
			if hp != null and (hp as Vector3).y >= box.position.y + box.size.y * 0.4:
				covered = lim - z
				break
			z -= 0.01
		worst_gap = maxf(worst_gap, covered)
	if worst_gap == -INF:
		return ["viseira sem testa atras"]
	if worst_gap > TOUCH_MAX:
		out.append("vao entre a viseira e a testa (%.3f m)" % worst_gap)
	if worst_sink > PartFit.EMBED:
		out.append("viseira entra %.3f m na testa" % worst_sink)
	return out
