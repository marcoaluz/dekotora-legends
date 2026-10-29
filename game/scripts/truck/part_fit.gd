class_name PartFit
extends RefCounted
## Regras de encaixe das pecas da oficina (T-211, catalogo secao 13.2 + decisao 12 do Marco), usadas pelo teste
## (tests/test_part_fit.gd) e pelo relatorio (tools_dev/report_part_fit.gd -> docs/REPORT_ENCAIXE.md):
##  1. as caixas de encaixes diferentes nao se cruzam (todas as pecas instaladas juntas);
##  2. nenhuma caixa de encaixe entra numa zona protegida (farol, lanterna, seta, placa, para-brisa, porta, roda);
##  3. a peca, ja com a escala, cabe inteira na caixa do encaixe (folga TOL);
##  4. a peca nao entra na lataria e encosta nela (T-214: raios na malha real, PartFitSeat; antes: perfis);
##  5. a peca nao toca zona protegida.

const TOL: float = 0.02                  # m de folga para "cabe na caixa"
const EMBED: float = 0.06                # m que a viseira pode encostar/entrar na testa (fixacao)


## AABB das malhas de `node` no espaco de `root` (sem precisar da arvore de cena).
static func aabb_in(node: Node3D, root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null or not m.visible:
			continue
		var t: Transform3D = rel_xform(m, root)
		var box: AABB = t * m.mesh.get_aabb()
		if not t.basis.is_conformal() or absf(t.basis.x.y) + absf(t.basis.y.z) + absf(t.basis.z.x) > 1e-4:
			box = _exact_aabb(m.mesh, t)                # T-214: inclinada/cisalhada: caixa pelos vertices (sem inchar)
		out = box if first else out.merge(box)
		first = false
	return out


static func _exact_aabb(mesh: Mesh, t: Transform3D) -> AABB:
	var f: PackedVector3Array = mesh.get_faces()
	if f.is_empty():
		return t * mesh.get_aabb()
	var lo: Vector3 = t * f[0]
	var hi: Vector3 = lo
	for v in f:
		var w: Vector3 = t * v
		lo = lo.min(w)
		hi = hi.max(w)
	return AABB(lo, hi - lo)


static func rel_xform(n: Node3D, root: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## Cruzam mais que `eps` nos 3 eixos? Encostar nao conta.
static func overlap(a: AABB, b: AABB, eps: float = 0.001) -> bool:
	var lo: Vector3 = a.position.max(b.position)
	var hi: Vector3 = a.end.min(b.end)
	return hi.x - lo.x > eps and hi.y - lo.y > eps and hi.z - lo.z > eps


static func inside(inner: AABB, outer: AABB, tol: float = TOL) -> bool:
	return inner.position.x >= outer.position.x - tol and inner.position.y >= outer.position.y - tol \
		and inner.position.z >= outer.position.z - tol and inner.end.x <= outer.end.x + tol \
		and inner.end.y <= outer.end.y + tol and inner.end.z <= outer.end.z + tol


## Regras 1 e 2 (projeto dos encaixes de um caminhao). Devolve a lista de problemas.
static func design_problems(data: Dictionary) -> Array[String]:
	var probs: Array[String] = []
	var vol: Array = []
	for k in data.get("sockets", {}):
		var s: Dictionary = data["sockets"][k]
		for b in (s.get("boxes", [s["box"]] if s.has("box") else []) as Array):   # T-231: contorno = varias caixas
			vol.append([String(k), TruckSockets.aabb_of(b)])
	for i in vol.size():
		for j in range(i + 1, vol.size()):
			if vol[i][0] != vol[j][0] and overlap(vol[i][1], vol[j][1]):
				probs.append("encaixes %s x %s se cruzam" % [vol[i][0], vol[j][0]])
		for z in data.get("protected", {}):
			var zv: Dictionary = data["protected"][z]
			if _exempt(String(vol[i][0]), zv):
				continue
			if zone_overlaps(zv, vol[i][1]):
				probs.append("encaixe %s entra na zona %s" % [vol[i][0], z])
	return probs


## T-265: a caixa `b` entra na zona `zv`? Zona da roda com `round` ([zc, yc, r], eixo X) = cilindro do pneu + 3 cm (a saia
## com arco contorna a roda e usa os cantos da caixa da zona). Igual a socket_rules.zone_hit (Blender).
static func zone_overlaps(zv: Dictionary, b: AABB, eps: float = 0.001) -> bool:
	if not overlap(b, TruckSockets.aabb_of(zv["box"]), eps):
		return false
	var rd: Array = zv.get("round", [])
	if rd.is_empty():
		return true
	var cz: float = clampf(float(rd[0]), b.position.z, b.end.z)
	var cy: float = clampf(float(rd[1]), b.position.y, b.end.y)
	return Vector2(cz - float(rd[0]), cy - float(rd[1])).length() < float(rd[2]) - eps


## T-265: o ponto `w` esta dentro da zona (caixa encolhida 2 mm; na roda, tambem dentro do cilindro)?
static func zone_has(zv: Dictionary, box: AABB, w: Vector3) -> bool:
	if not box.grow(-0.002).has_point(w):
		return false
	var rd: Array = zv.get("round", [])
	return rd.is_empty() or Vector2(w.z - float(rd[0]), w.y - float(rd[1])).length() < float(rd[2]) - 0.002


static func _exempt(slot: String, zone: Dictionary) -> bool:
	var base: String = slot.trim_suffix("_r").trim_suffix("_l")
	var ex: Array = zone.get("exempt", [])
	return slot in ex or base in ex


## Regras 3 a 5 para uma peca montada (`box` = AABB da peca no espaco do modelo).
static func part_problems(data: Dictionary, entry: Dictionary, box: AABB) -> Array[String]:
	var probs: Array[String] = []
	var slot: String = String(entry.get("socket", ""))
	var s: Dictionary = TruckSockets.socket(data, slot)
	if not s.has("box"):
		return ["encaixe %s nao existe neste caminhao" % slot]
	var sb: AABB = TruckSockets.aabb_of(s["box"])
	if not inside(box, sb):
		probs.append("sai da caixa do encaixe (peca %s, caixa %s)" % [_fmt(box), _fmt(sb)])
	for z in data.get("protected", {}):
		var zv: Dictionary = data["protected"][z]
		if not _exempt(slot, zv) and zone_overlaps(zv, box, 0.002):
			probs.append("cobre a zona protegida %s" % z)
	var cab: Dictionary = data.get("measure", {}).get("cab", {})
	if String(s.get("fit", "")) == "seat":           # T-214: assento real, conferido por raios (PartFitSeat)
		return probs
	if slot == "andon":                               # o deque fica acima do teto em todo o comprimento dele
		for p in cab.get("roof_profile", []):
			if float(p[0]) + 0.05 > box.position.z and float(p[0]) < box.end.z and float(p[1]) > box.position.y + 0.005:
				probs.append("entra no teto da cabine em z=%.2f (teto %.2f, peca %.2f)" % [float(p[0]), float(p[1]), box.position.y])
				break
	elif slot == "visor":                             # a viseira fica na frente da testa (pode encostar EMBED)
		for p in cab.get("front_profile", []):
			if float(p[0]) + 0.05 > box.position.y and float(p[0]) < box.end.y and box.end.z > float(p[1]) + EMBED:
				probs.append("entra na testa da cabine em y=%.2f" % float(p[0]))
				break
	return probs


static func _fmt(b: AABB) -> String:
	return "(%.2f,%.2f,%.2f)-(%.2f,%.2f,%.2f)" % [b.position.x, b.position.y, b.position.z, b.end.x, b.end.y, b.end.z]


## Ids das pecas do catalogo que montam por encaixe (style "deco").
static func socket_parts(catalog: AccessoryCatalog, slots: Array = []) -> Array[String]:
	var out: Array[String] = []
	for e in catalog.data.get("accessories", []):
		if (e as Dictionary).has("socket") and (slots.is_empty() or String(e["socket"]) in slots):
			out.append(String(e["id"]))
	return out


## Monta `id` no modelo e devolve os problemas (lista vazia = cabe).
static func check_part(model: Node3D, data: Dictionary, catalog: AccessoryCatalog, id: String) -> Array[String]:
	var e: Dictionary = catalog.entry(id)
	if PaintFit.handles(e):                          # T-232: pintura = retangulo medido, os 2 lados no mural
		var po: Array[String] = []
		for side in (["R", "L"] if bool(e.get("mirror_for_left", false)) else ["R"]):
			var pn: Node3D = catalog.attach(model, id, side)
			if pn == null:
				po.append("nao montou (sem retangulo em %s)" % PaintFit.socket_name(e, side))
				continue
			po.append_array(PaintFit.problems(model, data, e, pn, side))
			pn.get_parent().remove_child(pn)
			pn.free()
		return po
	if Lot5Fit.is_wheel(e):                          # T-234: calota em cada roda de fora
		return Lot5Fit.wheel_problems(model, data, catalog, id)
	if Lot5Fit.handles(e):                           # T-234: grade, escapamento (2 lados) e buzina
		var lo: Array[String] = []
		for side in (["R", "L"] if bool(e.get("mirror_for_left", false)) else ["R"]):
			var ln: Node3D = catalog.attach(model, id, side)
			if ln == null:
				lo.append("nao montou (sem SOCKET_%s)" % Lot5Fit.socket_name(e, side))
				continue
			lo.append_array(Lot5Fit.problems(model, data, e, ln, side))
			ln.get_parent().remove_child(ln)
			ln.free()
		return lo
	if StripFit.handles(e) or FrameFit.handles(e):   # T-231/T-233: pecas por modulo/grupo, os 2 lados
		var out: Array[String] = []
		for side in (["R", "L"] if bool(e.get("mirror_for_left", false)) else ["R"]):
			var sn: Node3D = catalog.attach(model, id, side)
			if sn == null:
				out.append("nao montou (sem SOCKET_%s)" % StripFit.socket_name(e, side))
				continue
			if FrameFit.handles(e):                  # T-263: retrovisor e escada tambem encostados (raios)
				out.append_array(FrameFit.problems(model, data, e, sn, side))
			else:
				out.append_array(StripFit.problems(model, data, e, sn, side))
			sn.get_parent().remove_child(sn)
			sn.free()
		return out
	var n: Node3D = catalog.attach(model, id)
	if n == null:
		return ["nao montou (sem SOCKET_%s)" % String(catalog.entry(id).get("socket", "?"))]
	var probs: Array[String] = part_problems(data, catalog.entry(id), aabb_in(n, model))
	if String(TruckSockets.socket(data, String(catalog.entry(id).get("socket", ""))).get("fit", "")) == "seat":
		probs.append_array(PartFitSeat.problems(model, String(data.get("model", "")), catalog.entry(id), n))
	n.get_parent().remove_child(n)
	n.free()
	return probs


## Modelo do .glb pronto para encaixar (pontos extras + encaixes da oficina). Caminho de TruckNode.model_path.
static func load_model(path: String, body: String, cab: String) -> Node3D:
	var model: Node3D = TruckNode.instantiate_model(body, cab)      # T-240: .glb unico ou kit (cabine + carroceria)
	TruckNode.add_extra_mounts(model, body, cab)
	TruckSockets.add_nodes(model, path)
	return model
