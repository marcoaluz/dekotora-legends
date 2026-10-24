class_name SocketSeat
extends RefCounted
## Assento das pecas do teto e da viseira na superficie REAL de cada cabine (T-214). O Blender mede por raios o teto e a
## testa de cada .glb (`blender/scripts/build_sockets.py` -> sockets/<modelo>.surf.json: grades de altura do teto e de
## "z da frente" da testa) e aqui cada peca e assentada:
##  - deque: inclina junto com o teto (ate 20 graus), desce ate encostar no ponto mais alto embaixo dela (entra no
##    maximo EMBED) e ganha um ASSENTO (saia fina na cor do painel) que fecha a folga do teto abaulado nas bordas;
##  - canhoes (nos POD*): cada um desce sozinho ate encostar no teto (sem base);
##  - viseira: as costas inclinam junto com o para-brisa (cisalhamento, a aba continua reta), encostam no ponto mais a
##    frente da testa e um ENCHIMENTO na cor da peca vai das costas ate a testa (nada de vao visto de lado);
##  - 2o nivel (T-215): a peca de cima e filha da de baixo e apoia na face de cima dela (`stack` do catalogo).
## As mesmas grades sao usadas pelo teste de encaixe (`tests/test_part_fit.gd`), que confere o contato com raios na
## malha real do caminhao (TriangleMesh), independente daqui.

const MISS: float = -99.0
const JUMP: float = 0.15          # degrau entre vizinhos da grade = borda (nao interpola atraves dela)
const EMBED: float = 0.004        # m que a peca entra na superficie (sem fresta de luz)
const PITCH_MAX: float = 0.35     # rad (20 graus): inclinacao maxima do deque
const FILL_MAX: float = 0.55      # m: fundo maximo do enchimento atras da viseira
const SKIRT_MIN: float = 0.006    # m: folga menor que isto nao ganha assento
const SKIRT_MAX: float = 0.50     # m: o assento nunca desce mais que isto abaixo da peca (testa da americana: 0,41)
const LOW_SPAN: float = 0.50      # m: roof_h_low aceita vizinhos ate isto abaixo do mais alto
const CREST: float = 0.10         # m: fileiras do teto mais baixas que o topo - CREST nao entram na inclinacao
const SEAT_PREFIX := "SEAT_"      # nos criados aqui (o teste separa da peca)

static var _surf_cache: Dictionary = {}


## Grades de apoio do modelo (vazio se nao houver).
static func surfaces(data: Dictionary) -> Dictionary:
	var f: String = String(data.get("surfaces", ""))
	if f == "":
		return {}
	if _surf_cache.has(f):
		return _surf_cache[f]
	var out: Dictionary = {}
	var path: String = TruckSockets.DIR + f
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			out = parsed
	_surf_cache[f] = out
	return out


## Altura do teto em (x, z) do modelo (numa borda vale o vizinho mais alto). MISS fora da grade.
static func roof_h(surf: Dictionary, x: float, z: float) -> float:
	var g: Dictionary = surf.get("roof", {})
	if g.is_empty():
		return MISS
	return _bilinear(g["h"], float(g["x0"]), float(g["dx"]), int(g["nx"]), float(g["z0"]), float(g["dz"]), int(g["nz"]), x, z, true)


## Altura do teto interpolada SEMPRE (sem a regra da borda): na quina arredondada do teto fica um pouco abaixo da
## lataria (o canhao entra uns milimetros), em vez de ficar no vizinho alto e boiar.
static func roof_h_pure(surf: Dictionary, x: float, z: float) -> float:
	var g: Dictionary = surf.get("roof", {})
	if g.is_empty():
		return MISS
	return _bilinear(g["h"], float(g["x0"]), float(g["dx"]), int(g["nx"]), float(g["z0"]), float(g["dz"]), int(g["nz"]), x, z, true,
			MISS + 1.0, true)


## Como roof_h, mas numa borda vale o vizinho mais BAIXO que ainda e teto (ate LOW_SPAN abaixo do mais alto): o
## assento desce ate a quina arredondada do teto sem cair no chassi atras da cabine.
static func roof_h_low(surf: Dictionary, x: float, z: float) -> float:
	var g: Dictionary = surf.get("roof", {})
	if g.is_empty():
		return MISS
	var hi: float = roof_h(surf, x, z)
	var lo: float = _bilinear(g["h"], float(g["x0"]), float(g["dx"]), int(g["nx"]), float(g["z0"]), float(g["dz"]), int(g["nz"]), x, z, false,
			hi - LOW_SPAN)
	return lo if lo > MISS + 1.0 else hi


## z da superficie da frente (vidro, testa, viseira de fabrica) em (x, y). Numa borda vale o vizinho mais a frente.
static func front_z(surf: Dictionary, x: float, y: float) -> float:
	var g: Dictionary = surf.get("front", {})
	if g.is_empty():
		return MISS
	return _bilinear(g["z"], float(g["x0"]), float(g["dx"]), int(g["nx"]), float(g["y0"]), float(g["dy"]), int(g["ny"]), x, y, false)


static func _bilinear(vals: Array, x0: float, dx: float, nx: int, r0: float, dr: float, nr: int, x: float, r: float,
		pick_max: bool, floor_v: float = MISS + 1.0, pure: bool = false) -> float:
	var fx: float = (x - x0) / dx
	var fr: float = (r - r0) / dr
	if fx < 0.0 or fr < 0.0 or fx > nx - 1 or fr > nr - 1:
		return MISS
	var i: int = mini(int(fx), nx - 2)
	var j: int = mini(int(fr), nr - 2)
	var tx: float = fx - i
	var tr: float = fr - j
	var v: Array[float] = [float(vals[j * nx + i]), float(vals[j * nx + i + 1]), float(vals[(j + 1) * nx + i]), float(vals[(j + 1) * nx + i + 1])]
	var good: Array[float] = []
	for q in v:
		if q > MISS + 1.0 and q >= floor_v:
			good.append(q)
	if good.is_empty():
		return MISS
	if good.size() < 4 or (not pure and good.max() - good.min() > JUMP):
		return good.max() if pick_max else good.min()
	return (v[0] * (1.0 - tx) + v[1] * tx) * (1.0 - tr) + (v[2] * (1.0 - tx) + v[3] * tx) * tr


## Bounds locais (Godot) da peca no catalogo: [[x0,y0,z0],[x1,y1,z1]] -> AABB.
static func bounds(entry: Dictionary) -> AABB:
	var b: Array = entry.get("bounds_godot", [[-1, 0, -1], [1, 1, 0]])
	return TruckSockets.aabb_of(b)


## Assenta `node` (filho do no SOCKET_<encaixe>, ja com a escala) na superficie do caminhao. Sem grade: nao mexe.
static func seat(node: Node3D, mount: Node3D, data: Dictionary, entry: Dictionary) -> void:
	var slot: String = String(entry.get("socket", ""))
	var s: Dictionary = TruckSockets.socket(data, slot)
	if String(s.get("fit", "")) != "seat":
		return
	var surf: Dictionary = surfaces(data)
	if surf.is_empty():
		return
	var sc: float = node.scale.x
	var anchor: Vector3 = mount.position
	if slot == "andon":
		var floor_y: float = float(s["box"][0][1]) + 0.005 if s.has("box") else -INF
		_seat_deck(node, anchor, surf, entry, sc, floor_y)
	elif slot == "visor":
		_seat_visor(node, anchor, surf, s, entry, sc)


# ------------------------------------------------------------------------------------------------ deque

static func _seat_deck(node: Node3D, anchor: Vector3, surf: Dictionary, entry: Dictionary, sc: float, floor_y: float) -> void:
	var b: AABB = bounds(entry)
	# inclinacao: reta pela "crista" do teto (maior altura de cada fileira) embaixo da peca
	var zs: Array[float] = []
	var hs: Array[float] = []
	for t in 9:
		var zl: float = lerpf(b.end.z, b.position.z, t / 8.0) * sc
		var top: float = MISS
		for q in 9:
			top = maxf(top, roof_h(surf, lerpf(b.position.x, b.end.x, q / 8.0) * sc, anchor.z + zl))
		if top > MISS + 1.0:
			zs.append(anchor.z + zl)
			hs.append(top)
	# so a parte "de cima" do teto conta (a testa que cai na frente do teto curto da americana nao inclina a peca)
	var top_all: float = hs.max() if not hs.is_empty() else 0.0
	var zf: Array[float] = []
	var hf: Array[float] = []
	for i in hs.size():
		if hs[i] >= top_all - CREST:
			zf.append(zs[i])
			hf.append(hs[i])
	var slope: float = _fit_slope(zf, hf)
	var ang: float = clampf(-atan(slope), -PITCH_MAX, PITCH_MAX)
	node.transform.basis = Basis(Vector3.RIGHT, ang).scaled(Vector3.ONE * sc)
	node.position = Vector3.ZERO
	# inclinada, a quina de tras de cima sai para tras do ponto do encaixe: avanca a peca ate as costas ficarem nele
	var back: float = -INF
	for cx in [b.position.x, b.end.x]:
		for cy in [b.position.y, b.end.y]:
			for cz in [b.position.z, b.end.z]:
				back = maxf(back, (node.transform.basis * Vector3(cx, cy, cz)).z)
	if back > 0.0:
		node.position.z = -back
	# altura: encosta no ponto mais alto embaixo da peca (o resto da folga fica para o assento)
	var lift: float = -INF
	for p in _footprint(node, b, 9):
		var h: float = roof_h(surf, anchor.x + p.x, anchor.z + p.z)
		if h > MISS + 1.0:
			lift = maxf(lift, h - (anchor.y + p.y))
	if lift == -INF:
		return
	node.position = Vector3(0.0, lift - EMBED, node.position.z)
	var pods: Array[Node3D] = _pods(node)
	if not pods.is_empty():
		for pod in pods:                               # cada canhao desce sozinho ate o teto
			_drop_pod(node, pod, anchor, surf)
		return
	_add_skirt(node, b, anchor, surf, floor_y)


static func _fit_slope(xs: Array[float], ys: Array[float]) -> float:
	var n: int = xs.size()
	if n < 2:
		return 0.0
	var mx: float = 0.0
	var my: float = 0.0
	for i in n:
		mx += xs[i]
		my += ys[i]
	mx /= n
	my /= n
	var num: float = 0.0
	var den: float = 0.0
	for i in n:
		num += (xs[i] - mx) * (ys[i] - my)
		den += (xs[i] - mx) * (xs[i] - mx)
	return num / den if den > 1e-6 else 0.0


## Pontos da base da peca (y = fundo dos bounds) em coordenadas do SOCKET (relativas ao ponto do encaixe).
static func _footprint(node: Node3D, b: AABB, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n:
		for j in n:
			var lp := Vector3(lerpf(b.position.x, b.end.x, i / float(n - 1)), b.position.y, lerpf(b.position.z, b.end.z, j / float(n - 1)))
			out.append(node.transform * lp)
	return out


static func _pods(node: Node3D) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for c in node.find_children("*POD*", "Node3D", true, false):
		if not String((c as Node).get_parent().name).contains("POD"):
			out.append(c as Node3D)
	return out


static func _local_aabb(n: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var meshes: Array = [n] if n is MeshInstance3D else []
	meshes.append_array(n.find_children("*", "MeshInstance3D", true, false))
	for mi in meshes:
		var m: MeshInstance3D = mi as MeshInstance3D
		if m.mesh == null:
			continue
		var t: Transform3D = PartFit.rel_xform(m, n) if m != n else Transform3D.IDENTITY
		var box: AABB = t * m.mesh.get_aabb()
		out = box if first else out.merge(box)
		first = false
	return out


static func _drop_pod(node: Node3D, pod: Node3D, anchor: Vector3, surf: Dictionary) -> void:
	var pb: AABB = _local_aabb(pod)
	var to_node: Transform3D = PartFit.rel_xform(pod, node)
	var gap: float = INF
	for i in 5:
		for j in 7:
			# so o meio da largura: no tubo sextavado a face chata de baixo e a metade do meio (as quinas sobem)
			var lp := Vector3(lerpf(lerpf(pb.position.x, pb.end.x, 0.3), lerpf(pb.position.x, pb.end.x, 0.7), i / 4.0), pb.position.y,
					lerpf(pb.position.z + 0.02, pb.end.z - 0.02, j / 6.0))
			var p: Vector3 = node.transform * (to_node * lp)
			var h: float = roof_h_pure(surf, anchor.x + p.x, anchor.z + p.z)
			if h > MISS + 1.0:
				gap = minf(gap, anchor.y + p.y - h)
	if gap == INF or gap <= 0.0:
		return
	# desce `gap` (em y do socket), convertido para o espaco do pai do canhao
	var parent_xf: Transform3D = node.transform * PartFit.rel_xform(pod.get_parent() as Node3D, node)
	pod.position += parent_xf.basis.inverse() * Vector3(0.0, -(gap - EMBED), 0.0)


## Saia fina (cor do painel) em volta da base do deque, do fundo da peca ate o teto (entra 1 cm no teto).
static func _add_skirt(node: Node3D, b: AABB, anchor: Vector3, surf: Dictionary, floor_y: float = -INF) -> void:
	var inset: float = 0.004
	var ma: AABB = _local_aabb(node)                 # malha real: frisos/rebites passam um pouco dos bounds do catalogo
	var x0: float = minf(b.position.x, ma.position.x) + inset
	var x1: float = maxf(b.end.x, ma.end.x) - inset
	var z0: float = b.position.z + inset             # (frente: so a caixa; enfeites da frente nao ganham saia)
	var z1: float = maxf(b.end.z, ma.end.z) - inset
	var corners: Array[Vector3] = [Vector3(x0, 0, z1), Vector3(x1, 0, z1), Vector3(x1, 0, z0), Vector3(x0, 0, z0)]
	var pts: Array[Vector3] = []
	for k in 4:
		var a: Vector3 = corners[k]
		var c: Vector3 = corners[(k + 1) % 4]
		var n: int = maxi(2, int(ceil(a.distance_to(c) * node.scale.x / 0.05)))
		for i in n:
			pts.append(a.lerp(c, i / float(n)))
	var inv: Transform3D = node.transform.affine_inverse()
	var top_y: float = b.position.y + 0.02 / node.scale.x
	var tops: Array[Vector3] = []
	var bots: Array[Vector3] = []
	var gaps: Array[float] = []
	for lp in pts:
		var t: Vector3 = Vector3(lp.x, top_y, lp.z)
		var p: Vector3 = node.transform * Vector3(lp.x, b.position.y, lp.z)
		var h: float = minf(roof_h_low(surf, anchor.x + p.x, anchor.z + p.z), roof_h_pure(surf, anchor.x + p.x, anchor.z + p.z))
		if h > MISS + 1.0:
			h = maxf(h, floor_y)                               # nunca abaixo da caixa do encaixe
		if h > MISS + 1.0 and anchor.y + p.y - h > SKIRT_MAX:     # borda fora do teto (atras da cabine): nao desce ao chassi
			h = anchor.y + p.y - SKIRT_MAX
		var gap: float = (anchor.y + p.y - h) if h > MISS + 1.0 else 0.0
		gaps.append(gap)
		tops.append(t)
		bots.append(inv * Vector3(p.x, h - anchor.y - 0.01, p.z) if h > MISS + 1.0 else t)
	var center: Vector3 = Vector3((x0 + x1) * 0.5, top_y, (z0 + z1) * 0.5)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var quads: int = 0
	for i in pts.size():
		var k: int = (i + 1) % pts.size()
		if gaps[i] < SKIRT_MIN and gaps[k] < SKIRT_MIN:
			continue
		var out: Vector3 = ((tops[i] + tops[k]) * 0.5 - center) * Vector3(1, 0, 1)
		_quad(st, tops[i], tops[k], bots[k], bots[i], out.normalized())
		quads += 1
	if quads == 0:
		return
	_add_mesh(node, st, "deco_trim", SEAT_PREFIX + "skirt")


# ------------------------------------------------------------------------------------------------ viseira

static func _seat_visor(node: Node3D, anchor: Vector3, surf: Dictionary, s: Dictionary, entry: Dictionary, sc: float) -> void:
	var b: AABB = bounds(entry)
	var k: float = float(s.get("lean", 0.0))
	var hs: float = b.end.y * sc
	# costas no plano do vidro: cisalha (a aba continua reta, so as costas e a frente inclinam com o vidro)
	node.transform.basis = Basis(Vector3(sc, 0, 0), Vector3(0, sc, sc * k), Vector3(0, 0, sc))
	var zmin: float = INF
	for i in 11:
		var x: float = lerpf(b.position.x, b.end.x, i / 10.0) * sc * 0.95
		for j in 7:
			var yy: float = hs * j / 6.0
			var zf: float = front_z(surf, anchor.x + x, anchor.y + yy)
			if zf > MISS + 1.0:
				zmin = minf(zmin, zf - k * yy)
	if zmin == INF:
		return
	var z0: float = zmin + EMBED                              # costas encostadas (entram EMBED) no ponto mais a frente
	node.position = Vector3(0.0, 0.0, z0 - anchor.z)
	var fill_lim: float = float(s.get("fill_max_z", INF))
	if s.has("box"):                                         # nunca alem da caixa do encaixe (as linhas de baixo da testa recuam)
		fill_lim = minf(fill_lim, float(s["box"][1][2]) - 0.008)
	_add_filler(node, b, anchor, surf, k, hs, z0, fill_lim, sc)


## Enchimento (cor da peca) das costas da viseira ate a testa, na altura da viseira. Colunas onde a testa fica longe
## demais (quina arredondada) ficam de fora.
static func _add_filler(node: Node3D, b: AABB, anchor: Vector3, surf: Dictionary, k: float, hs: float, z0: float,
		fill_max_z: float, sc: float) -> void:
	var half: float = minf(-b.position.x, b.end.x) * sc - 0.01
	var nrow: int = maxi(3, int(ceil(hs / 0.02)))
	var rows: Array[float] = []
	for j in nrow + 1:
		rows.append(hs * j / nrow)
	# colunas validas: do centro para fora enquanto a testa esta perto
	var xs: Array[float] = [0.0]
	for side in [1.0, -1.0]:
		var x: float = 0.05 * side
		while absf(x) <= half + 0.001:
			var zf: float = front_z(surf, anchor.x + x, anchor.y + hs)
			if zf <= MISS + 1.0 or zf - (z0 + k * hs) > FILL_MAX:
				break
			if side > 0:
				xs.append(x)
			else:
				xs.push_front(x)
			x += 0.05 * side
	if xs.size() < 3:
		return
	var inv: Transform3D = node.transform.affine_inverse()
	var off := Vector3(anchor.x, anchor.y, anchor.z)
	# profundidade de cada (coluna, linha): ate a testa + 8 mm, limitada por FILL_MAX e pela frente do deque
	var front_pts: Array = []
	var back_pts: Array = []
	var clamped: Array = []
	for x in xs:
		var fr: Array[Vector3] = []
		var bk: Array[Vector3] = []
		var cl: Array[bool] = []
		for yy in rows:
			var zp: float = z0 + k * yy
			var zf: float = front_z(surf, anchor.x + x, anchor.y + yy)
			var want: float = (zf - zp + 0.008) if zf > MISS + 1.0 else 0.0
			var lim: float = minf(FILL_MAX, fill_max_z - zp)
			var d: float = clampf(want, 0.0, maxf(lim, 0.0))
			fr.append(inv * (Vector3(anchor.x + x, anchor.y + yy, zp - 0.006) - off))
			bk.append(inv * (Vector3(anchor.x + x, anchor.y + yy, zp + d) - off))
			cl.append(want > lim + 0.004)
		front_pts.append(fr)
		back_pts.append(bk)
		clamped.append(cl)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: int = rows.size() - 1
	var up: Vector3 = Vector3.UP
	for c in xs.size() - 1:                                   # tampo
		_quad(st, front_pts[c][top], front_pts[c + 1][top], back_pts[c + 1][top], back_pts[c][top], up)
		if (back_pts[c][0] as Vector3).distance_to(front_pts[c][0]) > 0.01:      # fundo (se a testa recua ja embaixo)
			_quad(st, front_pts[c][0], front_pts[c + 1][0], back_pts[c + 1][0], back_pts[c][0], Vector3.DOWN)
		for r in top:                                         # parede de tras onde o enchimento foi cortado
			if clamped[c][r] or clamped[c + 1][r]:
				_quad(st, back_pts[c][r], back_pts[c + 1][r], back_pts[c + 1][r + 1], back_pts[c][r + 1], Vector3.BACK)
	for e in [[0, Vector3.LEFT], [xs.size() - 1, Vector3.RIGHT]]:   # tampas das pontas
		var c: int = int(e[0])
		for r in top:
			_quad(st, front_pts[c][r], front_pts[c][r + 1], back_pts[c][r + 1], back_pts[c][r], e[1])
	_add_mesh(node, st, "deco_body", SEAT_PREFIX + "filler")


# ------------------------------------------------------------------------------------------------ 2o nivel (T-215)

## Dados de empilhamento da peca ({"kind": "box"|"pods", "base": bool, "top_y", "top_rect"}) ou vazio.
static func stack_info(entry: Dictionary) -> Dictionary:
	var s: Variant = entry.get("stack", null)
	return s if s is Dictionary else {}


## A combinacao (de baixo, de cima) e valida pelo formato? Caixa em cima de canhoes ou canhoes em cima de caixa.
static func stack_pair_ok(lower: Dictionary, upper: Dictionary) -> bool:
	var a: Dictionary = stack_info(lower)
	var b: Dictionary = stack_info(upper)
	if a.is_empty() or b.is_empty() or not bool(a.get("base", false)):
		return false
	return String(a["kind"]) != String(b["kind"])


## Cabe no caminhao? Topo da pilha (escala da de baixo) <= `stack_max_y` do encaixe. `lower_scale` = escala da peca.
static func stack_fits(data: Dictionary, lower: Dictionary, upper: Dictionary, lower_scale: float) -> bool:
	if not stack_pair_ok(lower, upper):
		return false
	var s: Dictionary = TruckSockets.socket(data, "andon")
	if not s.has("stack_max_y"):
		return false
	var top: float = float(s["anchor"][1]) + (float(stack_info(lower)["top_y"]) + bounds(upper).end.y) * lower_scale
	return top <= float(s["stack_max_y"]) + 0.001


## Poe `upper` (ja instanciada) em cima de `lower`: filha dela, apoiada na face de cima, alinhada pelas costas.
## Embaixo canhoes: apoia no canhao mais alto depois de cada um descer ate o teto (a caixa e rigida).
static func place_upper(upper: Node3D, lower: Node3D, lower_entry: Dictionary) -> void:
	var info: Dictionary = stack_info(lower_entry)
	var y: float = float(info.get("top_y", 0.0))
	var pods: Array[Node3D] = _pods(lower)
	if not pods.is_empty():
		var hi: float = -INF
		for pod in pods:
			if upper.is_ancestor_of(pod):
				continue
			var box: AABB = PartFit.rel_xform(pod, lower) * _local_aabb(pod)
			hi = maxf(hi, box.end.y)
		if hi > -INF:
			y = hi
	upper.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, y - EMBED, 0.0))


# ------------------------------------------------------------------------------------------------ malha

## Quadrilatero a-b-c-d virado para `out` (normal explicita; a ordem dos vertices segue a frente do Godot).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	var n: Vector3 = (b - a).cross(c - a)
	var tri: Array[Vector3] = [a, b, c, a, c, d]
	if n.dot(out) > 0.0:                                      # Godot: frente = sentido horario visto de fora
		tri = [a, c, b, a, d, c]
	for v in tri:
		st.set_normal(out)
		st.set_uv(Vector2(v.x + v.z, v.y) * 2.0)
		st.add_vertex(v)


static func _add_mesh(node: Node3D, st: SurfaceTool, mat_name: String, name: String) -> void:
	var mat := StandardMaterial3D.new()
	mat.resource_name = mat_name                             # o DecoStyle troca pela cor da peca
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = st.commit()
	node.add_child(mi)
