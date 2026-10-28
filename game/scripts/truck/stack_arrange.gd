class_name StackArrange
extends RefCounted
## Arranjo "canhoes embaixo, caixa em cima" do deque de 2 niveis (T-216, pedido do Marco: os canhoes direto embaixo da
## caixa pareciam falsos). Como num Dekotora de verdade, os canhoes ficam um pouco A FRENTE da caixa (a lente aparece na
## frente do deque) e a caixa se apoia em dois lugares visiveis: na frente, em cima dos canhoes; atras, em dois pes
## cromados que descem ate o teto (com sapata). Nada flutua: cada canhao desce de novo ate o teto no lugar novo e cada pe
## e medido na grade do teto (SocketSeat). A conta de "cabe" (StackFit) usa o arranjo pronto.

const AHEAD: float = 0.24         # m (na escala da peca): quanto os canhoes avancam a frente da caixa
const AHEAD_MIN: float = 0.10    # m: menos que isto ja nao parece "a frente"
const VISOR_GAP: float = 0.012    # m: folga ate o lugar da viseira
const POST_W: float = 0.07        # m: espessura do pe de tras
const FOOT_W: float = 0.16        # m: sapata do pe
const POST_INSET_X: float = 0.12  # m: pe para dentro da quina da caixa (de lado)
const POST_INSET_Z: float = 0.10  # m: pe para dentro da traseira da caixa
const PREFIX := "SEAT_post_"      # (SEAT_: o teste separa o apoio da peca)


## Aplica o arranjo quando a de baixo e de canhoes e a de cima e caixa; devolve a altura (y local da de baixo) do apoio
## da caixa, ou NAN quando nao se aplica.
static func arrange(upper: Node3D, lower: Node3D, lower_entry: Dictionary, upper_entry: Dictionary) -> float:
	if String(SocketSeat.stack_info(lower_entry).get("kind", "")) != "pods":
		return NAN
	if String(SocketSeat.stack_info(upper_entry).get("kind", "")) != "box":
		return NAN
	var mount: Node3D = lower.get_parent() as Node3D
	var data: Dictionary = mount.get_meta("sockets", {}) if mount != null else {}
	var surf: Dictionary = SocketSeat.surfaces(data)
	var anchor: Vector3 = mount.position if mount != null else Vector3.ZERO
	var pods: Array[Node3D] = []
	for pod in SocketSeat._pods(lower):
		if not upper.is_ancestor_of(pod):
			pods.append(pod)
	var ahead: float = _ahead(lower, pods, data, anchor)
	# o que nao der para avancar os canhoes (viseira logo embaixo) a caixa recua, se o teto deixa
	var sk: Dictionary = TruckSockets.socket(data, "andon")
	var sc: float = maxf(lower.scale.x, 0.01)
	var room_back: float = float(sk.get("roof_end_z", anchor.z)) - 0.01 - (anchor.z + lower.position.z + 0.02 * sc)
	var back: float = clampf(room_back / sc, 0.0, AHEAD - ahead)
	upper.set_meta("stack_back", back)
	upper.set_meta("stack_offset", ahead + back)
	var hi: float = -INF
	for pod in pods:
		var parent_xf: Transform3D = PartFit.rel_xform(pod.get_parent() as Node3D, lower)
		pod.position += parent_xf.basis.inverse() * Vector3(0.0, 0.0, -ahead)     # frente = -z
		if not surf.is_empty():
			SocketSeat._drop_pod(lower, pod, anchor, surf)                         # desce (ou sobe) ate o teto de novo
		var box: AABB = PartFit.rel_xform(pod, lower) * SocketSeat._local_aabb(pod)
		hi = maxf(hi, box.end.y)
	if hi == -INF:
		return NAN
	return hi


## Quanto avancar os canhoes (na escala da peca): AHEAD, ou menos onde a viseira fica logo abaixo da frente do teto
## (cabines curta e JAC: o teto fica colado no vidro). O resto a caixa recua (arrange); a soma tem de dar AHEAD_MIN
## (StackFit confere).
static func _ahead(lower: Node3D, pods: Array[Node3D], data: Dictionary, anchor: Vector3) -> float:
	var sc: float = maxf(lower.scale.x, 0.01)
	var vs: Dictionary = TruckSockets.socket(data, "visor")
	if not vs.has("box") or pods.is_empty():
		return AHEAD
	var vb: AABB = TruckSockets.aabb_of(vs["box"])
	var front: float = INF
	var bottom: float = INF
	for pod in pods:
		var b: AABB = lower.transform * PartFit.rel_xform(pod, lower) * SocketSeat._local_aabb(pod)
		front = minf(front, anchor.z + b.position.z)
		bottom = minf(bottom, anchor.y + b.position.y)
	var room: float = INF
	if bottom <= vb.end.y + 0.005:
		room = front - (vb.end.z + VISOR_GAP)                # quanto da para avancar sem entrar no lugar da viseira
	for hk in ["horn_r", "horn_l"]:                       # T-234/T-256: nem no lugar da buzina (pontas da viseira)
		var hs: Dictionary = TruckSockets.socket(data, hk)
		if not hs.has("box"):
			continue
		var hb: AABB = TruckSockets.aabb_of(hs["box"])
		if bottom <= hb.end.y - 0.002 and _x_overlap(lower, pods, anchor, hb):
			room = minf(room, front - (hb.end.z + VISOR_GAP))
	if room == INF:
		return AHEAD
	return clampf(room / sc, 0.0, AHEAD)


## Algum canhao cruza a faixa x da caixa `hb` (a buzina fica so nas pontas da viseira)?
static func _x_overlap(lower: Node3D, pods: Array[Node3D], anchor: Vector3, hb: AABB) -> bool:
	for pod in pods:
		var b: AABB = lower.transform * PartFit.rel_xform(pod, lower) * SocketSeat._local_aabb(pod)
		var x0: float = anchor.x + b.position.x
		if minf(x0 + b.size.x, hb.end.x) - maxf(x0, hb.position.x) > 0.001:
			return true
	return false


## Pes de tras da caixa (filhos da caixa `upper`, ja posicionada): do fundo da caixa ate o teto, um de cada lado.
static func add_posts(upper: Node3D, lower: Node3D, upper_entry: Dictionary) -> void:
	var mount: Node3D = lower.get_parent() as Node3D
	var data: Dictionary = mount.get_meta("sockets", {}) if mount != null else {}
	var surf: Dictionary = SocketSeat.surfaces(data)
	if surf.is_empty():
		return
	var anchor: Vector3 = mount.position
	var b: AABB = SocketSeat.bounds(upper_entry)
	var sc: float = lower.scale.x
	var to_socket: Transform3D = lower.transform * upper.transform
	var inv: Transform3D = to_socket.affine_inverse()
	for side in [-1.0, 1.0]:
		var x: float = (b.end.x - POST_INSET_X / sc) if side > 0.0 else (b.position.x + POST_INSET_X / sc)
		var z: float = b.end.z - POST_INSET_Z / sc
		var top_s: Vector3 = to_socket * Vector3(x, b.position.y + 0.01, z)              # fundo da caixa, no socket
		var h: float = SocketSeat.roof_h(surf, anchor.x + top_s.x, anchor.z + top_s.z)
		if h <= SocketSeat.MISS + 1.0:
			continue
		var bot_s := Vector3(top_s.x, h - anchor.y - SocketSeat.EMBED, top_s.z)
		var top_l: Vector3 = inv * top_s
		var bot_l: Vector3 = inv * bot_s
		var len_l: float = top_l.distance_to(bot_l)
		if len_l < 0.02:
			continue
		var mid: Vector3 = (top_l + bot_l) * 0.5
		upper.add_child(_box_mi(PREFIX + ("r" if side > 0.0 else "l"), Vector3(POST_W / sc, len_l, POST_W / sc), mid))
		upper.add_child(_box_mi(PREFIX + "foot_" + ("r" if side > 0.0 else "l"), Vector3(FOOT_W / sc, 0.02 / sc, FOOT_W / sc),
				bot_l + Vector3(0.0, 0.01 / sc, 0.0)))


static func _box_mi(name: String, size: Vector3, center: Vector3) -> MeshInstance3D:
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.resource_name = "chrome"                       # o ChromeMatcap troca pelo cromo do caminhao
	mat.metallic = 1.0
	mat.roughness = 0.1
	bm.material = mat
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = bm
	mi.position = center
	return mi
