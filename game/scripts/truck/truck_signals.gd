class_name TruckSignals
extends RefCounted
## T-239: setas do caminhao EM CIMA da lampada certa (antes eram 4 caixas ambar soltas no ar). Sem luz real: a seta e
## uma copia da propria lampada (mesmos triangulos, 4 mm na frente) com material ambar aceso, filha da malha da lampada
## (acompanha balanco, peca torta, escala). Onde fica:
##   frente  com para-choque da oficina: pontos SIGNAL_L/R da peca (lente da seta, T-233);
##           sem: a lanterna ambar da quina da cabine (perto do farol, medida pelos encaixes);
##   tras    com para-choque da oficina: a lanterna mais de fora de cada lado da peca (lamp_tail);
##           sem: a lanterna ambar do para-choque de fabrica (a mais de fora); caminhao sem ela ganha a lanterna de
##           fabrica do jogo (StockRearLamps).
## Ordem dos lados: 0 frente-esq., 1 frente-dir., 2 traseira-esq., 3 traseira-dir. (esquerda = -x).

const PUSH: float = 0.004                  # m na frente da lampada (sem brigar com ela no z-buffer)
const TIE_X: float = 0.03                  # lampadas a menos disto em |x| contam como "igualmente de fora": vale a de cima
const BOX_SIZE := Vector3(0.34, 0.2, 0.14) # caixa antiga (ponto SIGNAL e reserva sem lampada nenhuma)
## Halo: brilho redondo aditivo (sempre virado para a camera) no centro da lampada, um pouco para fora da lataria. Sem
## ele a lampada de 6-15 cm some na tela do celular a 10 m. Tamanho fixo em metros (o billboard ignora a escala).
const HALO_SIZE: float = 0.5
const HALO_OUT: float = 0.12

var slots: Array = [[], [], [], []]        # nos acesos de cada lado
var spots: Array[String] = ["", "", "", ""]  # de onde veio (testes): "bumper", "cab", "part", "stock", "factory", "box"
var _mat: StandardMaterial3D
var _box: BoxMesh
var _halo: QuadMesh


func _init() -> void:
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(1.0, 0.62, 0.05)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.55, 0.0)
	_mat.emission_energy_multiplier = 5.0
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box = BoxMesh.new()
	_box.size = BOX_SIZE
	_box.material = _mat
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.62, 0.12, 0.85))
	g.set_color(1, Color(1.0, 0.45, 0.0, 0.0))
	g.add_point(0.25, Color(1.0, 0.55, 0.05, 0.45))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.albedo_texture = tex
	hm.disable_receive_shadows = true
	_halo = QuadMesh.new()
	_halo.size = Vector2(HALO_SIZE, HALO_SIZE)
	_halo.material = hm


## Refaz as 4 setas (chame depois de montar/trocar pecas). `truck` = o TruckNode; `model` = o .glb dele.
func rebuild(truck: Node3D, model: Node3D, data: Dictionary, front_z: float, lit: Array[bool]) -> void:
	for list in slots:
		for n in list:
			if is_instance_valid(n):
				(n as Node).queue_free()
	slots = [[], [], [], []]
	var meas: Dictionary = data.get("measure", {})
	for i in 4:
		var side: int = -1 if i % 2 == 0 else 1
		var made: Array = []
		if i < 2:
			made = _front_bumper(model, side)
			spots[i] = "bumper"
			if made.is_empty():
				made = _overlay(_front_factory(model, meas, side), model, -1.0)
				spots[i] = "cab"
		else:
			var rb: Node = model.find_child("SOCKET_rear_bumper", true, false)
			made = _overlay(_outermost(_rear_part(rb, model), side), model, 1.0)
			spots[i] = "part"
			if made.is_empty():
				made = _overlay(_outermost(_rear_factory(model, meas, side), side), model, 1.0)
				spots[i] = "factory"
		if made.is_empty():                       # reserva: a caixa de sempre (nunca deveria acontecer)
			var m := MeshInstance3D.new()
			m.mesh = _box
			m.position = Vector3(side * 1.22, 0.95 if i < 2 else 1.05, front_z if i < 2 else 0.12)
			truck.add_child(m)
			made = [m]
			spots[i] = "box"
		made.append(_make_halo(model, made, -1.0 if i < 2 else 1.0))
		for n in made:
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			(n as Node3D).visible = lit[i] if i < lit.size() else false
		slots[i] = made


func set_visible(i: int, on: bool) -> void:
	for n in slots[i]:
		if is_instance_valid(n):
			(n as Node3D).visible = on


func _make_halo(model: Node3D, made: Array, facing: float) -> MeshInstance3D:
	var c: Vector3 = _merged(made, model).get_center()
	var h := MeshInstance3D.new()
	h.mesh = _halo
	h.name = "signal_halo"
	h.set_meta("halo", true)
	h.position = c + Vector3(0.0, 0.0, facing * HALO_OUT)
	model.add_child(h)
	return h


static func _merged(list: Array, root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n in list:
		var m: MeshInstance3D = n
		var b: AABB = PartFit.rel_xform(m, root) * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Caixa (espaco de `root`) do que acende no lado `i`, sem o halo (testes).
func box_of(i: int, root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for n in slots[i]:
		if (n as Node).has_meta("halo"):
			continue
		var m: MeshInstance3D = n
		var b: AABB = PartFit.rel_xform(m, root) * m.mesh.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


# ----------------------------------------------------------------------------- frente

func _front_bumper(model: Node3D, side: int) -> Array:
	var fb: Node = model.find_child("SOCKET_front_bumper", true, false)
	if fb == null:
		return []
	var n: Node3D = fb.find_child("SIGNAL_" + ("L" if side < 0 else "R") + "*", true, false) as Node3D  # (SIGNAL_L_006)
	if n == null or (n.is_inside_tree() and not n.is_visible_in_tree()) or n.is_queued_for_deletion():
		return []
	var m := MeshInstance3D.new()
	m.mesh = _box
	m.scale = Vector3(1.0 / BOX_SIZE.x, 1.0 / BOX_SIZE.y, 1.0 / BOX_SIZE.z)   # o ponto ja traz o tamanho da lente
	n.add_child(m)
	return [m]


## Lanterna ambar da quina da cabine: perto do farol (do fundo dele ate 12 cm acima), na frente da cabine, do lado.
func _front_factory(model: Node3D, meas: Dictionary, side: int) -> Array[LampMesh.Piece]:
	var hl_d: Dictionary = meas.get("headlights", {})
	var key: String = "l" if side < 0 else "r"
	if not hl_d.has(key):
		return []
	var hl: AABB = TruckSockets.aabb_of(hl_d[key])
	var cab_front: float = float((meas.get("cab", {}) as Dictionary).get("front_z", hl.position.z))
	var out: Array[LampMesh.Piece] = []
	for p in LampMesh.lamp_pieces(model, model, ["lamp_amber"], true):
		var c: Vector3 = p.box.get_center()
		if c.x * side < 0.5 or c.z < cab_front - 0.1 or c.z > cab_front + 0.45:
			continue
		if p.box.end.y < hl.position.y or p.box.position.y > hl.end.y + 0.12:
			continue
		out.append(p)
	return out


# ----------------------------------------------------------------------------- traseira

func _rear_part(rb: Node, model: Node3D) -> Array[LampMesh.Piece]:
	if rb == null:
		return []
	var out: Array[LampMesh.Piece] = []
	for p in LampMesh.lamp_pieces(rb, model, ["lamp_tail"], false):
		if not p.mesh.is_queued_for_deletion() and _alive(p.mesh, model):
			out.append(p)
	return out


func _alive(n: Node, model: Node3D) -> bool:
	var cur: Node = n
	while cur != null and cur != model:
		if cur.is_queued_for_deletion():
			return false
		cur = cur.get_parent()
	return true


## Lanternas ambar do para-choque de fabrica (abaixo do bau, viradas para tras). Inclui a lanterna de fabrica do jogo.
static func _rear_factory(model: Node3D, meas: Dictionary, side: int) -> Array[LampMesh.Piece]:
	var box: Dictionary = meas.get("box", {})
	var bottom: float = float(box.get("bottom_y", 1.0))
	var rear: float = float(box.get("rear_z", 0.0))
	var out: Array[LampMesh.Piece] = []
	for p in LampMesh.lamp_pieces(model, model, ["lamp_amber"], true):
		var c: Vector3 = p.box.get_center()
		if c.x * side > 0.2 and c.y < bottom and p.box.end.z > rear - 0.1 and p.box.size.x > 0.02:
			out.append(p)
	return out


## So a lampada mais de fora do lado (empate em |x|: a de cima).
static func _outermost(list: Array[LampMesh.Piece], side: int) -> Array[LampMesh.Piece]:
	var best: LampMesh.Piece = null
	for p in list:
		var c: Vector3 = p.box.get_center()
		if c.x * side <= 0.0:
			continue
		if best == null:
			best = p
			continue
		var bc: Vector3 = best.box.get_center()
		var dx: float = absf(c.x) - absf(bc.x)
		if dx > TIE_X or (absf(dx) <= TIE_X and c.y > bc.y):
			best = p
	var out: Array[LampMesh.Piece] = []
	if best != null:
		out.append(best)
	return out


# ----------------------------------------------------------------------------- copia acesa da lampada

## Uma copia acesa de cada peca, filha da malha dela. `facing` = -1 frente (-z), +1 traseira (+z); peca virada de lado
## (quina) e empurrada para fora em x.
func _overlay(list: Array[LampMesh.Piece], model: Node3D, facing: float) -> Array:
	var out: Array = []
	for p in list:
		var model_xf: Transform3D = PartFit.rel_xform(p.mesh, model)
		var dir := Vector3(0.0, 0.0, facing)
		if p.box.size.x < 0.012:
			dir = Vector3(signf(p.box.get_center().x), 0.0, 0.0)
		var local_push: Vector3 = model_xf.basis.inverse() * (dir * PUSH)
		var m := MeshInstance3D.new()
		var one: Array[LampMesh.Piece] = [p]
		m.mesh = LampMesh.piece_mesh(one, local_push, _mat)
		p.mesh.add_child(m)
		out.append(m)
	return out

