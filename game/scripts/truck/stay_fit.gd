class_name StayFit
extends RefCounted
## Haste do retrovisor (fit "stay", T-233; base colada na lataria desde a T-263).
## O Blender mede, para cada altura, onde a coluna do para-brisa aceita a chapa de fixacao (`pillar` do encaixe
## mirror_stay_*, blender/scripts/lib/truck_measure.py `pillar`; faixa livre `pad_y`, socket_rules._clear_pads).
## Aqui: a haste escala pela largura da cabine e pela altura do vidro (limitada a faixa livre da coluna), os bracos
## saem logo por fora da lataria e cada ponto de fixacao (`vfit.pads` do catalogo, [x, altura] no espaco da peca) ganha
## uma chapa ENCOSTADA na lataria medida (virada pela normal) e um espacador ate o braco. Assim nao sobra vao entre a
## haste e a cabine em nenhuma cabine. As chapas/espacadores vem do .glb (grupos PADF_ e PADS_) e viram uma malha por
## material no no "PADS" (espaco do ponto de encaixe, sem a escala da peca).

const STAY_S: Vector2 = Vector2(0.9, 1.05)          # escala da haste pela largura da cabine
const STAY_K: Vector2 = Vector2(0.75, 1.3)          # altura da haste pelo vidro
const K_MIN: float = 0.5                            # (coluna livre curta: a haste encolhe ate aqui)
const FLANGE_T: float = 0.012                       # m: espessura da chapa (= blender mirror_t233.FLANGE_T)
const SEARCH: int = 3                               # passos da coluna procurados acima/abaixo de cada chapa


## Monta a haste no ponto de encaixe (`node` ja filho do SOCKET_mirror_stay_*). `sx` = 1 direita, -1 esquerda.
static func apply(node: Node3D, s: Dictionary, entry: Dictionary, sx: float) -> void:
	var sc: float = clampf(float(s.get("width", 2.3)) / float(entry.get("nominal_w", 2.3)), STAY_S.x, STAY_S.y)
	var vf: Dictionary = entry.get("vfit", {})
	var hn: float = float(vf.get("nominal_h", 0.85))
	var k: float = clampf(float(s.get("window_h", hn)) / hn, STAY_K.x, STAY_K.y)
	var pads: Array = vf.get("pads", [])
	var pl: Dictionary = s.get("pillar", {})
	if pads.is_empty() or pl.is_empty():                   # (encaixe antigo, sem coluna medida)
		node.scale = Vector3(sx * sc, k, sc)
		return
	var anchor: Vector3 = (node.get_parent() as Node3D).position
	var hlo: float = INF
	var hhi: float = -INF
	for p in pads:
		hlo = minf(hlo, float(p[1]))
		hhi = maxf(hhi, float(p[1]))
	var band: Array = s.get("pad_y", [anchor.y, anchor.y + 1.0])
	if hhi > hlo:
		k = maxf(minf(k, (float(band[1]) - float(band[0])) / (hhi - hlo)), K_MIN)
	var y_base: float = clampf(anchor.y, float(band[0]) - hlo * k, maxf(float(band[0]) - hlo * k, float(band[1]) - hhi * k))
	# onde cada chapa encosta
	var spots: Array = []
	var x_top: float = 0.0
	var z_sum: float = 0.0
	for p in pads:
		var sp: Array = spot(pl, y_base + float(p[1]) * k)
		if sp.is_empty():
			sp = [sx * absf(anchor.x), anchor.z, sx, 0.0, y_base + float(p[1]) * k]
		spots.append(sp)
		x_top = maxf(x_top, absf(float(sp[0])))
		z_sum += float(sp[1])
	var z0: float = z_sum / spots.size()
	node.position = Vector3(sx * x_top, y_base, z0) - anchor
	node.scale = Vector3(sx * sc, k, sc)
	_build_pads(node, pads, spots, sc, k, sx, String(entry.get("id", "stay")))


## Ponto da coluna mais perto da altura `y` (ate SEARCH passos): [x, z, nx, nz, y] (x e nx com o sinal do lado) ou [].
static func spot(pl: Dictionary, y: float) -> Array:
	var pts: Array = pl.get("pts", [])
	var y0: float = float(pl.get("y0", 0.0))
	var dy: float = float(pl.get("dy", 0.02))
	var i0: int = roundi((y - y0) / dy)
	for d in SEARCH * 2 + 1:
		var i: int = i0 + (((d + 1) / 2) * (1 if d % 2 == 1 else -1))
		if i >= 0 and i < pts.size() and pts[i] is Array:
			var q: Array = pts[i]
			return [float(q[0]), float(q[1]), float(q[2]), float(q[3]), y0 + i * dy]
	return []


static func _build_pads(node: Node3D, pads: Array, spots: Array, sc: float, k: float, sx: float, pid: String) -> void:
	var flange: Array[MeshInstance3D] = []
	var stem: Array[MeshInstance3D] = []
	for mi in StripFit._meshes(node):
		var nm: String = String(mi.name)
		if nm.contains("_PADF_"):
			flange.append(mi)
		elif nm.contains("_PADS_"):
			stem.append(mi)
	if flange.is_empty() and stem.is_empty():
		return
	var holder := Node3D.new()
	holder.name = "PADS"
	node.add_child(holder)
	holder.transform = node.transform.affine_inverse()     # espaco do ponto de encaixe (sem escala/espelho da peca)
	var fx: Array[Transform3D] = []
	var stx: Array[Transform3D] = []
	var info: Array = []
	for i in pads.size():
		var sp: Array = spots[i]
		var n := Vector3(float(sp[2]), 0.0, float(sp[3])).normalized()
		var surf := Vector3(float(sp[0]), float(sp[4]), float(sp[1])) - (node.get_parent() as Node3D).position
		var side := n.cross(Vector3.UP).normalized()
		fx.append(Transform3D(Basis(n, Vector3.UP, side), surf))
		var arm: Vector3 = node.transform * Vector3(float(pads[i][0]), float(pads[i][1]), 0.0)
		var from: Vector3 = surf + n * FLANGE_T
		var d: Vector3 = arm - from
		if d.length() < 0.005:
			d = n * 0.005
		var u2: Vector3 = d.normalized().cross(Vector3.UP)
		if u2.length() < 0.1:
			u2 = d.normalized().cross(Vector3.FORWARD)
		u2 = u2.normalized()
		stx.append(Transform3D(Basis(d, u2, d.normalized().cross(u2)), from))
		info.append({"p": surf + (node.get_parent() as Node3D).position, "n": n})
	var jobs: Array = []
	for list in [[flange, fx], [stem, stx]]:
		for mi in (list[0] as Array):
			var m: MeshInstance3D = mi
			var tmp := MeshInstance3D.new()
			tmp.mesh = m.mesh
			holder.add_child(tmp)
			jobs.append([tmp, list[1]])
			m.get_parent().remove_child(m)
			m.queue_free()
	StripFit._merge(holder, jobs, pid + "_pad")
	node.set_meta("pads", info)                              # (teste de contato: ponto na lataria e normal, no modelo)
