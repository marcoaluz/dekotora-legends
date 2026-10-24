class_name PartFit
extends RefCounted
## Regras de encaixe das pecas da oficina (T-211, catalogo secao 13.2 + decisao 12 do Marco), usadas pelo teste
## (tests/test_part_fit.gd) e pelo relatorio (tools_dev/report_part_fit.gd -> docs/REPORT_ENCAIXE.md):
##  1. as caixas de encaixes diferentes nao se cruzam (todas as pecas instaladas juntas);
##  2. nenhuma caixa de encaixe entra numa zona protegida (farol, lanterna, seta, placa, para-brisa, porta, roda);
##  3. a peca, ja com a escala, cabe inteira na caixa do encaixe (folga TOL);
##  4. a peca nao entra na lataria (perfil do teto para o deque, perfil da testa para a viseira);
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
		var box: AABB = rel_xform(m, root) * m.mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


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
		if s.has("box"):
			vol.append([String(k), TruckSockets.aabb_of(s["box"])])
	for i in vol.size():
		for j in range(i + 1, vol.size()):
			if overlap(vol[i][1], vol[j][1]):
				probs.append("encaixes %s x %s se cruzam" % [vol[i][0], vol[j][0]])
		for z in data.get("protected", {}):
			var zv: Dictionary = data["protected"][z]
			if _exempt(String(vol[i][0]), zv):
				continue
			if overlap(vol[i][1], TruckSockets.aabb_of(zv["box"])):
				probs.append("encaixe %s entra na zona %s" % [vol[i][0], z])
	return probs


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
		if not _exempt(slot, zv) and overlap(box, TruckSockets.aabb_of(zv["box"]), 0.002):
			probs.append("cobre a zona protegida %s" % z)
	var cab: Dictionary = data.get("measure", {}).get("cab", {})
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
	var n: Node3D = catalog.attach(model, id)
	if n == null:
		return ["nao montou (sem SOCKET_%s)" % String(catalog.entry(id).get("socket", "?"))]
	var probs: Array[String] = part_problems(data, catalog.entry(id), aabb_in(n, model))
	n.get_parent().remove_child(n)
	n.free()
	return probs


## Modelo do .glb pronto para encaixar (pontos extras + encaixes da oficina). Caminho de TruckNode.model_path.
static func load_model(path: String, body: String, cab: String) -> Node3D:
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	TruckNode.add_extra_mounts(model, body, cab)
	TruckSockets.add_nodes(model, path)
	return model
