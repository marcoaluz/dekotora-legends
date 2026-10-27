class_name FrameFit
extends RefCounted
## Pecas da oficina do lote 4 (T-233) que se ajustam ao caminhao, montadas a partir de grupos do .glb
## (blender/scripts/accessories/{front,mirror,ladder,skirt}_t233.py):
##  - fit "bumper" (para-choque da frente): escala uniforme pela largura da cabine; TOP_ fica no topo (embaixo do farol
##    mais baixo), MID_ estica/encolhe na altura para a peca caber entre o chao e o farol e cobrir o para-choque de
##    fabrica, BOT_ acompanha o fundo e CEN_ fica no meio. Os pontos SIGNAL_L/R levam a seta da frente (TruckNode);
##  - fit "stay" (haste do retrovisor): largura pela cabine, altura pelo vidro de cada cabine; o espelho de fabrica
##    some (`hide_stock`, caixa `hide` do encaixe) enquanto a haste esta montada;
##  - fit "ladder" (escada): o degrau MID_ se repete ate o topo do bau; TOP_ vai para o fim;
##  - fit "runs" (saia): um pedaco (HEAD_ + MID_ repetido + TAIL_) em cada trecho livre medido embaixo do bau.
## Tudo vira UMA malha por material (StripFit._merge), feita uma vez na montagem.

const FITS: Array[String] = ["bumper", "stay", "ladder", "runs"]
## Altura que o para-choque tenta ter (m): cobre o para-choque de fabrica nas cabines de farol alto (chata), sem passar
## da altura livre do encaixe nas de farol baixo (Canter, HAYATE).
const BUMPER_TARGET_H: float = 0.55
const BUMPER_K: Vector2 = Vector2(0.05, 2.2)        # limites do estica/encolhe da faixa do meio
const STAY_S: Vector2 = Vector2(0.9, 1.05)          # escala da haste pela largura da cabine
const STAY_K: Vector2 = Vector2(0.75, 1.3)          # altura da haste pelo vidro

static var _hidden_cache: Dictionary = {}           # "rid|caixa" -> ArrayMesh sem os triangulos do espelho de fabrica


static func handles(entry: Dictionary) -> bool:
	return String(entry.get("fit", "")) in FITS


static func apply(node: Node3D, data: Dictionary, entry: Dictionary, side: String) -> bool:
	var s: Dictionary = TruckSockets.socket(data, StripFit.socket_name(entry, side))
	if s.is_empty():
		return false
	var sx: float = -1.0 if side == "L" else 1.0
	var pid: String = String(entry.get("id", "part"))
	var fit: String = String(entry.get("fit", ""))
	var jobs: Array = []
	if fit == "bumper":
		var sc: float = TruckSockets.fit_scale(data, entry)
		node.scale = Vector3.ONE * sc
		var v: Dictionary = entry.get("vfit", {})
		var t: float = float(v.get("top", 0.13))
		var m: float = float(v.get("mid", 0.2))
		var b: float = float(v.get("bot", 0.09))
		var k: float = bumper_k(float(s.get("height", t + m + b)), sc, t, m, b)
		for mi in StripFit._meshes(node):
			var nm: String = String(mi.name)
			var x: Transform3D = Transform3D.IDENTITY
			if nm.contains("_MID_"):
				x = Transform3D(Basis.from_scale(Vector3(1, k, 1)), Vector3(0, t * (k - 1.0), 0))
			elif nm.contains("_BOT_"):
				x = Transform3D(Basis.IDENTITY, Vector3(0, m * (1.0 - k), 0))
			elif nm.contains("_CEN_"):
				x = Transform3D(Basis.IDENTITY, Vector3(0, m * (1.0 - k) * 0.5, 0))
			jobs.append([mi, [x]])
		node.set_meta("bumper_k", k)
	elif fit == "stay":
		var sc2: float = clampf(float(s.get("width", 2.3)) / float(entry.get("nominal_w", 2.3)), STAY_S.x, STAY_S.y)
		var hn: float = float((entry.get("vfit", {}) as Dictionary).get("nominal_h", 0.85))
		var k2: float = clampf(float(s.get("window_h", hn)) / hn, STAY_K.x, STAY_K.y)
		node.scale = Vector3(sx * sc2, k2, sc2)
		_set_fade(node, entry)
		return true
	elif fit == "ladder":
		node.scale = Vector3(sx, 1, 1)
		var st: Dictionary = entry.get("stretch", {})
		var head: float = float(st.get("head", 0.15))
		var mid: float = float(st.get("mid", 0.3))
		var tail: float = float(st.get("tail", 0.18))
		var body: float = maxf(float(s.get("height", 2.0)) - head - tail, mid * 0.5)
		var n: int = maxi(1, roundi(body / mid))
		var sz: float = body / (n * mid)
		var mods: Array[Transform3D] = []
		for i in n:
			mods.append(Transform3D(Basis.from_scale(Vector3(1, sz, 1)), Vector3(0, head * (1.0 - sz) + i * mid * sz, 0)))
		var top_x := Transform3D(Basis.IDENTITY, Vector3(0, n * mid * sz - mid, 0))
		for mi in StripFit._meshes(node):
			var nm2: String = String(mi.name)
			jobs.append([mi, mods if nm2.contains("_MID_") else ([top_x] if nm2.contains("_TOP_") else [Transform3D.IDENTITY])])
	else:                                   # runs (saia)
		var st2: Dictionary = entry.get("stretch", {})
		var hd: float = float(st2.get("head", 0.05))
		var md: float = float(st2.get("mid", 0.5))
		var tl: float = float(st2.get("tail", 0.05))
		var cx: float = clampf(float(s.get("depth", 0.06)) / float(entry.get("nominal_w", 0.055)), 0.6, 1.0)
		node.scale = Vector3(sx * cx, 1, 1)
		var heads: Array[Transform3D] = []
		var mids: Array[Transform3D] = []
		var tails: Array[Transform3D] = []
		for r in s.get("runs", []):
			var za: float = float(r[0])
			var zb: float = float(r[1])
			var body2: float = maxf(zb - za - hd - tl, 0.02)        # (trecho curto: o modulo encolhe)
			var n2: int = maxi(1, roundi(body2 / md))
			var sz2: float = body2 / (n2 * md)
			heads.append(Transform3D(Basis.IDENTITY, Vector3(0, 0, zb)))
			for i in n2:
				mids.append(Transform3D(Basis.from_scale(Vector3(1, 1, sz2)), Vector3(0, 0, zb + hd * sz2 - hd - i * md * sz2)))
			tails.append(Transform3D(Basis.IDENTITY, Vector3(0, 0, zb - (n2 * md * sz2 - md))))
		for mi in StripFit._meshes(node):
			var nm3: String = String(mi.name)
			jobs.append([mi, mids if nm3.contains("_MID_") else (tails if nm3.contains("_TAIL_") else heads)])
	StripFit._merge(node, jobs, pid)
	_set_fade(node, entry)
	return true


## Fator da faixa do meio do para-choque: tenta BUMPER_TARGET_H (ou a altura nominal, se maior) sem passar da altura
## livre `avail` do encaixe.
static func bumper_k(avail: float, sc: float, t: float, m: float, b: float) -> float:
	var target: float = minf(avail, maxf((t + m + b) * sc, BUMPER_TARGET_H))
	return clampf((target / sc - t - b) / m, BUMPER_K.x, BUMPER_K.y)


static func _set_fade(node: Node3D, entry: Dictionary) -> void:
	var fade: float = float(entry.get("fade_end", 0.0))
	if fade <= 0.0:
		return
	for mi in StripFit._meshes(node):
		mi.visibility_range_end = fade
		mi.visibility_range_end_margin = 10.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Regras de encaixe (cada vertice dentro das caixas do encaixe e fora das zonas protegidas): as mesmas do StripFit.
static func problems(model: Node3D, data: Dictionary, entry: Dictionary, node: Node3D, side: String) -> Array[String]:
	return StripFit.problems(model, data, entry, node, side)


# ----------------------------------------------------------------------------- espelho de fabrica

## Caixas dos espelhos de fabrica a esconder (as hastes montadas neste caminhao).
static func stock_boxes(data: Dictionary, sides: Array) -> Array[AABB]:
	var out: Array[AABB] = []
	for side in sides:
		var s: Dictionary = TruckSockets.socket(data, "mirror_stay_" + String(side))
		if s.get("hide") is Array:
			out.append(TruckSockets.aabb_of(s["hide"]))
	return out


## Esconde os triangulos de `model` (cabine, LODs) que ficam INTEIROS dentro de alguma caixa; caixas vazias = mostra
## tudo de novo. Nao mexe nas pecas (nos SOCKET_*/MOUNT_*). A malha original fica guardada no no (meta "stock_mesh").
static func hide_stock(model: Node3D, boxes: Array[AABB]) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi as MeshInstance3D
		if _in_part(m, model):
			continue
		var orig: Mesh = m.get_meta("stock_mesh") if m.has_meta("stock_mesh") else m.mesh
		if orig == null:
			continue
		var t: Transform3D = PartFit.rel_xform(m, model)
		var hit: Array[AABB] = []
		var wb: AABB = t * orig.get_aabb()
		for b in boxes:
			if wb.intersects(b):
				hit.append(b)
		if hit.is_empty():
			if m.has_meta("stock_mesh"):
				m.mesh = orig
				m.remove_meta("stock_mesh")
			continue
		var key: String = "%d|%s|%s" % [orig.get_rid().get_id(), str(t), str(hit)]
		if not _hidden_cache.has(key):
			_hidden_cache[key] = _without(orig, t, hit)
		m.set_meta("stock_mesh", orig)
		m.mesh = _hidden_cache[key]


static func _in_part(m: Node, model: Node3D) -> bool:
	var cur: Node = m.get_parent()
	while cur != null and cur != model:
		var n: String = String(cur.name)
		if n.begins_with("SOCKET_") or n.begins_with("MOUNT_") or n.begins_with("acc_"):
			return true
		cur = cur.get_parent()
	return false


static func _without(src: Mesh, t: Transform3D, boxes: Array[AABB]) -> ArrayMesh:
	var am := ArrayMesh.new()
	for si in src.get_surface_count():
		var arr: Array = src.surface_get_arrays(si)
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for k in verts.size():
				idx.append(k)
		var inside: PackedByteArray = PackedByteArray()
		inside.resize(verts.size())
		for k in verts.size():
			var w: Vector3 = t * verts[k]
			var f: int = 0
			for b in boxes:
				if b.has_point(w):
					f = 1
					break
			inside[k] = f
		var keep := PackedInt32Array()
		for k in range(0, idx.size(), 3):
			if inside[idx[k]] == 1 and inside[idx[k + 1]] == 1 and inside[idx[k + 2]] == 1:
				continue
			keep.append_array([idx[k], idx[k + 1], idx[k + 2]])
		arr[Mesh.ARRAY_INDEX] = keep
		if keep.is_empty():
			keep.append_array([0, 0, 0])               # (superficie vazia: um triangulo degenerado)
			arr[Mesh.ARRAY_INDEX] = keep
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, src.surface_get_material(si))
	return am


## A seta da frente vai para os pontos SIGNAL_L/R do para-choque da oficina (lista vazia = sem para-choque com seta).
## Devolve [transform esquerda, transform direita] no espaco de `truck`.
static func signal_spots(truck: Node3D, model: Node3D) -> Array:
	var fb: Node = model.find_child("SOCKET_front_bumper", true, false)
	if fb == null:
		return []
	var out: Array = []
	for nm in ["SIGNAL_L", "SIGNAL_R"]:
		var n: Node3D = fb.find_child(nm + "*", true, false) as Node3D     # (o Blender pode por sufixo: SIGNAL_L_006)
		if n == null or not n.is_visible_in_tree() and n.is_inside_tree():
			return []
		out.append(PartFit.rel_xform(n, truck))
	return out
