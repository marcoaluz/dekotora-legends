class_name StackFit
extends RefCounted
## Conferencia GEOMETRICA de uma dupla do deque de 2 niveis (T-215) num caminhao: monta a de baixo assentada no teto
## real, poe a de cima e confere (1) dentro da caixa do encaixe, (2) ate a altura maxima `stack_max_y`, (3) fora das zonas
## protegidas (para-brisa...), (4) a de cima apoiada na de baixo (raios). O resultado de todas as duplas x caminhoes fica
## numa tabela (`TABLE`, gerada por tools_dev/gen_stack_fit.gd) que o jogo consulta (DeckStack.fits), sem montar nada em
## tempo de jogo. O teste (tests/test_deck_stack.gd) refaz a conta e confere que a tabela esta em dia.

const FRONT_ALLOW: float = 0.32    # m: no arranjo da T-216 os canhoes podem passar isto da frente da caixa do encaixe
const TABLE := "res://assets/vehicles/dekotora/truck/stack_fit.json"

static var _table: Dictionary = {}
static var _loaded: bool = false


## Duplas que cabem por modelo: {stem: {"baixo|cima": true}}. Vazio se a tabela nao existe.
static func table() -> Dictionary:
	if not _loaded:
		_loaded = true
		if FileAccess.file_exists(TABLE):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
			if parsed is Dictionary:
				for stem in (parsed as Dictionary).get("fits", {}):
					var d: Dictionary = {}
					for k in parsed["fits"][stem]:
						d[String(k)] = true
					_table[String(stem)] = d
	return _table


static func key(lower: String, upper: String) -> String:
	return lower + "|" + upper


## Problemas da dupla montada no `model` (vazio = cabe). Monta e desmonta (o modelo volta como estava).
static func problems(model: Node3D, data: Dictionary, c: AccessoryCatalog, lower_id: String, upper_id: String) -> Array[String]:
	var probs: Array[String] = []
	var sk: Dictionary = TruckSockets.socket(data, "andon")
	if not sk.has("box") or not sk.has("stack_max_y"):
		return ["sem encaixe de deque de 2 niveis"]
	var lower: Node3D = c.attach(model, lower_id)
	if lower == null:
		return ["nao montou"]
	var upper: Node3D = c.instantiate(upper_id)
	lower.add_child(upper)
	SocketSeat.place_upper(upper, lower, c.entry(lower_id), c.entry(upper_id))
	var box: AABB = PartFit.aabb_in(lower, model)
	var limit: AABB = TruckSockets.aabb_of(sk["box"])
	var arranged: bool = lower.find_child(StackArrange.PREFIX + "*", true, false) != null
	if arranged:                                     # T-216: os canhoes passam um pouco da frente do deque
		limit.position.z -= FRONT_ALLOW
		limit.size.z += FRONT_ALLOW
	if not PartFit.inside(box, limit):
		probs.append("sai da caixa do encaixe")
	var vs: Dictionary = TruckSockets.socket(data, "visor")
	if vs.has("box") and PartFit.overlap(box, TruckSockets.aabb_of(vs["box"]), 0.002):
		probs.append("entra no lugar da viseira")
	if arranged and float(upper.get_meta("stack_offset", 0.0)) < StackArrange.AHEAD_MIN - 0.001:
		probs.append("os canhoes nao ficam a frente da caixa (%.2f m)" % float(upper.get_meta("stack_offset", 0.0)))
	if arranged:                                     # os pes de tras chegam no teto
		var truck: TriangleMesh = PartFitSeat.truck_mesh(model, String(data.get("model", "")))
		for f in lower.find_children(StackArrange.PREFIX + "foot_*", "MeshInstance3D", true, false):
			var fb: AABB = PartFit.rel_xform(f as Node3D, model) * (f as MeshInstance3D).mesh.get_aabb()
			var fc: Vector3 = fb.get_center()
			var hit: Dictionary = truck.intersect_ray(Vector3(fc.x, fb.end.y + 0.3, fc.z), Vector3.DOWN)
			if hit.is_empty() or absf((hit["position"] as Vector3).y - fb.position.y) > 0.03:
				probs.append("pe de tras nao chega no teto (%s)" % f.name)
	if box.end.y > float(sk["stack_max_y"]) + 0.03:
		probs.append("passa da altura maxima %.2f (topo %.2f)" % [float(sk["stack_max_y"]), box.end.y])
	for z in data.get("protected", {}):
		if PartFit.overlap(box, TruckSockets.aabb_of(data["protected"][z]["box"]), 0.002):
			probs.append("cobre a zona %s" % z)
	var g: Vector2 = rest_gap(lower, upper, model)
	if g.x > PartFitSeat.TOUCH_MAX or g.y < -PartFitSeat.SINK_MAX:
		probs.append("apoio: folga minima %.3f, entra %.3f" % [g.x, -g.y])
	lower.get_parent().remove_child(lower)
	lower.free()
	return probs


## (folga minima, folga mais negativa) entre o fundo da peca de cima e o topo da de baixo, na area em comum.
static func rest_gap(lower: Node3D, upper: Node3D, model: Node3D) -> Vector2:
	var faces_lo := PackedVector3Array()
	for mi in lower.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or upper.is_ancestor_of(m) or String(m.name).begins_with(SocketSeat.SEAT_PREFIX):
			continue
		var t: Transform3D = PartFit.rel_xform(m, model)
		for v in m.mesh.get_faces():
			faces_lo.append(t * v)
	var lo := TriangleMesh.new()
	lo.create_from_faces(faces_lo)
	var up: TriangleMesh = PartFitSeat.part_mesh(upper, model, false)
	var bl: AABB = PartFit.aabb_in(lower, model)
	var bu: AABB = PartFit.aabb_in(upper, model)
	var x0: float = maxf(bl.position.x, bu.position.x) + 0.04
	var x1: float = minf(bl.end.x, bu.end.x) - 0.04
	var z0: float = maxf(bl.position.z, bu.position.z) + 0.04
	var z1: float = minf(bl.end.z, bu.end.z) - 0.04
	var gmin: float = INF
	for i in 11:
		for j in 11:
			var x: float = lerpf(x0, x1, i / 10.0)
			var z: float = lerpf(z0, z1, j / 10.0)
			var a: Dictionary = up.intersect_ray(Vector3(x, bl.position.y - 0.5, z), Vector3.UP)
			var b: Dictionary = lo.intersect_ray(Vector3(x, bu.end.y + 0.5, z), Vector3.DOWN)
			if a.is_empty() or b.is_empty():
				continue
			gmin = minf(gmin, (a["position"] as Vector3).y - (b["position"] as Vector3).y)
	return Vector2(gmin, gmin)


## Todas as duplas validas pelo formato (de baixo, de cima), na ordem do catalogo.
static func shape_pairs(c: AccessoryCatalog) -> Array:
	var out: Array = []
	var ids: Array[String] = PartFit.socket_parts(c, ["andon"])
	for lo in ids:
		for up in ids:
			if lo != up and SocketSeat.stack_pair_ok(c.entry(lo), c.entry(up)):
				out.append([lo, up])
	return out
