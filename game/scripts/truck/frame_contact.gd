class_name FrameContact
extends RefCounted
## Conferencia de CONTATO (T-263) por raios na malha real do caminhao, para as pecas do lote 4 que encostam na lataria:
##  - retrovisor (fit "stay"): cada chapa de fixacao (meta "pads" do StayFit) encosta na coluna (folga <= TOUCH em algum
##    ponto da chapa, nenhum ponto com vao > GAP_MAX, nada entra > SINK) e nenhuma parte fica na frente do para-brisa;
##  - escada (fit "ladder"): as costas encostam na chapa da frente do bau e nada encosta na cabine/no que fica na frente;
##  - para-choque grande (T-264, fit "bumper" com abas): as costas encostam no nariz e cada aba encosta na lateral da
##    cabine (folga <= WRAP_TOUCH em algum ponto) sem entrar nela (raios de fora para dentro em toda a aba).
## A malha do caminhao e montada SEM os triangulos do espelho de fabrica (o jogo os esconde com a haste montada).

const TOUCH: float = 0.006         # m: folga maxima no ponto que encosta
const GAP_MAX: float = 0.022       # m: maior vao em qualquer canto da chapa (lataria curva embaixo dela)
const SINK: float = 0.006          # m: o quanto a chapa pode entrar na lataria
const FRONT_FREE: float = 0.004    # m: folga minima entre a frente da escada e a cabine
const WRAP_TOUCH: float = 0.012    # m: (T-264) folga maxima no ponto da aba/das costas que encosta

static var _cache: Dictionary = {}


static func problems(model: Node3D, data: Dictionary, entry: Dictionary, node: Node3D, side: String) -> Array[String]:
	match String(entry.get("fit", "")):
		"stay":
			return _stay(model, data, node)
		"ladder":
			return _ladder(model, data, entry, node, side)
		"bumper":
			if BumperWrap.handles(entry):
				return _bumper(model, data, node)
	return []


## Malha do caminhao (sem rodas, pecas e espelho de fabrica), no espaco de `model`.
static func truck_mesh(model: Node3D, data: Dictionary) -> TriangleMesh:
	var key: String = "%s|%d" % [String(data.get("model", "")), model.get_instance_id()]
	if _cache.has(key):
		return _cache[key]
	_cache.clear()                                   # (um caminhao por vez: os testes passam por todos)
	var all_boxes: Array[AABB] = FrameFit.stock_boxes(data, ["r", "l"])
	var mats: Array[String] = FrameFit.stock_mats(data, ["r", "l"])
	var faces := PackedVector3Array()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or PartFitSeat._skip_truck(m, model) or m.has_meta("lod"):
			continue
		var src: Mesh = m.get_meta("stock_mesh") if m.has_meta("stock_mesh") else m.mesh
		var boxes: Array[AABB] = FrameFit.boxes_for(m, all_boxes, mats)
		var f: PackedVector3Array = src.get_faces()
		var t: Transform3D = PartFit.rel_xform(m, model)
		for i in range(0, f.size(), 3):
			var a: Vector3 = t * f[i]
			var b: Vector3 = t * f[i + 1]
			var c: Vector3 = t * f[i + 2]
			if not FrameFit.tri_hidden(a, b, c, boxes):
				faces.append_array(PackedVector3Array([a, b, c]))
	var tm := TriangleMesh.new()
	tm.create_from_faces(faces)
	_cache[key] = tm
	return tm


static func _gap(tm: TriangleMesh, p: Vector3, n: Vector3) -> float:
	var r: Dictionary = tm.intersect_ray(p + n * 0.08, -n)
	if r.is_empty():
		return INF
	return (p + n * 0.08).distance_to(r["position"]) - 0.08


static func _stay(model: Node3D, data: Dictionary, node: Node3D) -> Array[String]:
	var out: Array[String] = []
	var pads: Array = node.get_meta("pads", [])
	if pads.is_empty():
		return ["haste sem chapas de fixacao medidas"]
	var tm: TriangleMesh = truck_mesh(model, data)
	for i in pads.size():
		var p: Vector3 = pads[i]["p"]
		var n: Vector3 = pads[i]["n"]
		var t: Vector3 = n.cross(Vector3.UP).normalized()
		var gaps: Array[float] = []
		for o in [Vector2.ZERO, Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, -1), Vector2(0, 1)]:
			gaps.append(_gap(tm, p + t * (0.016 * o.x) + Vector3.UP * (0.03 * o.y), n))
		var lo: float = gaps.min()
		var hi: float = gaps.max()
		if lo > TOUCH:
			out.append("chapa %d da haste com vao de %.3f m da lataria" % [i, lo])
		if lo < -SINK:
			out.append("chapa %d da haste entra %.3f m na lataria" % [i, -lo])
		if hi > GAP_MAX:
			out.append("chapa %d da haste com canto solto (%.3f m)" % [i, hi])
	# nada da haste na frente do vidro (a zona do para-brisa e isenta para a base na coluna, ao lado do vidro)
	var ws: Dictionary = data.get("protected", {}).get("windshield", {})
	if not ws.is_empty():
		var z: AABB = TruckSockets.aabb_of(ws["box"])
		var half: float = maxf(absf(z.position.x), absf(z.end.x)) - 0.005
		for mi in StripFit._meshes(node):
			var tr: Transform3D = PartFit.rel_xform(mi, model)
			for v in mi.mesh.get_faces():
				var w: Vector3 = tr * v
				if z.has_point(w) and absf(w.x) < half:
					out.append("haste na frente do para-brisa")
					return out
	return out


static func _ladder(model: Node3D, data: Dictionary, entry: Dictionary, node: Node3D, side: String) -> Array[String]:
	var out: Array[String] = []
	var s: Dictionary = TruckSockets.socket(data, StripFit.socket_name(entry, side))
	if s.has("face_x"):                              # T-263: escada na lateral da cabine (espacadores)
		return _side_ladder(model, data, node)
	if not s.has("face_z"):
		return out
	var tm: TriangleMesh = truck_mesh(model, data)
	var box: AABB = PartFit.aabb_in(node, model)
	var face: float = float(s["face_z"])
	if absf(box.end.z - face) > TOUCH:
		out.append("escada a %.3f m da frente do bau" % (face - box.end.z))
	var cx: float = box.get_center().x
	var touch: float = INF
	for q in 5:
		var y: float = lerpf(box.position.y + 0.08, box.end.y - 0.08, q / 4.0)
		for dx in [-0.09, 0.09]:
			var o := Vector3(cx + dx, y, box.end.z - 0.03)
			var r: Dictionary = tm.intersect_ray(o, Vector3.BACK)
			if not r.is_empty():
				var g: float = (r["position"] as Vector3).z - box.end.z
				touch = minf(touch, g)
				if g < -SINK:
					out.append("escada entra %.3f m no bau" % -g)
			var f: Dictionary = tm.intersect_ray(Vector3(cx + dx, y, box.position.z + 0.02), Vector3.FORWARD)
			if not f.is_empty() and box.position.z - (f["position"] as Vector3).z < FRONT_FREE:
				out.append("escada encosta no que fica na frente (y %.2f)" % y)
	if touch > TOUCH:
		out.append("escada sem contato com o bau (%.3f m)" % touch)
	return out


## T-263: cada espacador da escada da lateral encosta na lataria (ponta a <= 1 cm, sem entrar mais que SINK).
static func _side_ladder(model: Node3D, data: Dictionary, node: Node3D) -> Array[String]:
	var out: Array[String] = []
	var cs: Array = node.get_meta("contacts", [])
	if cs.size() < 2:
		return ["escada com menos de 2 espacadores na lataria"]
	var tm: TriangleMesh = truck_mesh(model, data)
	for i in cs.size():
		var g: float = _gap(tm, cs[i]["p"], cs[i]["n"])
		if g > 0.01:
			out.append("espacador %d da escada a %.3f m da lataria" % [i, g])
		elif g < -SINK - 0.004:
			out.append("espacador %d da escada entra %.3f m na lataria" % [i, -g])
	return out


## T-264: para-choque grande: costas no nariz e abas coladas na lateral (sem entrar). Espaco do modelo.
static func _bumper(model: Node3D, data: Dictionary, node: Node3D) -> Array[String]:
	var out: Array[String] = []
	var s: Dictionary = TruckSockets.socket(data, "front_bumper")
	var tm: TriangleMesh = truck_mesh(model, data)
	var box: AABB = PartFit.aabb_in(node, model)
	var back: float = float(s["anchor"][2])
	var y0: float = box.position.y + 0.03
	var y1: float = box.end.y - 0.03
	var best: float = INF
	var hx: float = float(s.get("width", 2.0)) * 0.5 - 0.05
	for qx in 45:                                     # (a frente da cabine e curva: grade fina em toda a largura)
		for qy in 7:
			var o := Vector3(lerpf(-hx, hx, qx / 44.0), lerpf(y0, y1, qy / 6.0), back - 0.05)
			var r: Dictionary = tm.intersect_ray(o, Vector3.BACK)
			if not r.is_empty():
				best = minf(best, (r["position"] as Vector3).z - back)
	if best > WRAP_TOUCH:
		out.append("costas do para-choque a %.3f m do nariz" % best)
	elif best < -SINK:
		out.append("costas do para-choque entram %.3f m no nariz" % -best)
	for side in ["r", "l"]:
		var w: Dictionary = (s.get("wrap", {}) as Dictionary).get(side, {})
		if w.is_empty():
			continue
		var sx: float = 1.0 if side == "r" else -1.0
		var xin: float = float(w["x"])
		var ln: float = float(w["len"])
		var touch: float = INF
		for qz in 14:
			var z: float = back + lerpf(0.04, ln - 0.03, qz / 13.0)
			for qy in 9:
				var o2 := Vector3(sx * (xin + 0.4), lerpf(y0, y1, qy / 8.0), z)
				var r2: Dictionary = tm.intersect_ray(o2, Vector3(-sx, 0, 0))
				if r2.is_empty():
					continue
				var g: float = xin - absf((r2["position"] as Vector3).x)
				touch = minf(touch, g)
				if g < -SINK:
					out.append("aba %s entra %.3f m na lataria (y %.2f, z %.2f)" % [side, -g, o2.y, z])
					break
		if touch > WRAP_TOUCH:
			out.append("aba %s sem contato com a lateral (%.3f m)" % [side, touch])
	return out
