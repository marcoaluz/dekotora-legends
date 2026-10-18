class_name TruckWheels
extends RefCounted
## Rodas de um caminhao (T-133): acha os nos "wheel_*" do .glb, gira cada uma pela velocidade / raio DELA
## (o Canter e a frente da JAC/americana tem raio diferente), estérça as dianteiras e hospeda as pecas de roda
## (calotas e rodas da loja) como FILHAS de cada roda externa visivel, para girarem e esterçarem junto com o pneu.
## As pecas de roda do catalogo usam os pontos MOUNT_WHEEL_*_FACE_* so como referencia de encaixe (posicao,
## escala e lado em relacao a roda); o ponto em si fica parado no modelo.

const STEER_MAX: float = 0.35          # rad de esterçamento com steer = 1
const FACE_FRONT: String = "MOUNT_WHEEL_FRONT_FACE_"
const FACE_REAR: String = "MOUNT_WHEEL_REAR_FACE_"

var wheels: Array[Node3D] = []
var rest: Array[Basis] = []            # rotacao original de cada roda no .glb (eixo do pneu em X)
var radii: PackedFloat32Array = []     # raio de cada roda (m), medido na malha
var angles: PackedFloat32Array = []    # giro acumulado de cada roda (rad)
var steer_yaw: float = 0.0             # ultimo esterçamento aplicado (rad)
var _model: Node3D


## Le as rodas do modelo. `fallback_radius` vale para rodas sem malha propria.
func setup(model: Node3D, fallback_radius: float) -> void:
	_model = model
	for n in model.find_children("wheel_*", "Node3D", true, false):
		var w: Node3D = n as Node3D
		wheels.append(w)
		rest.append(w.transform.basis)
		radii.append(_measure_radius(w, fallback_radius))
		angles.append(0.0)


static func is_front(w: Node) -> bool:
	return String(w.name).begins_with("wheel_f")


## Raio pela caixa da malha do pneu nos eixos do modelo (altura/comprimento; a largura fica em X).
static func _measure_radius(w: Node3D, fallback: float) -> float:
	if w is MeshInstance3D and (w as MeshInstance3D).mesh != null:
		var box: AABB = Transform3D(w.transform.basis, Vector3.ZERO) * (w as MeshInstance3D).mesh.get_aabb()
		var r: float = maxf(box.size.y, box.size.z) * 0.5
		if r > 0.15:
			return r
	return fallback


## Gira as rodas: cada uma anda `speed * dt` metros no chao (angulo = distancia / raio dela). `steer` em -1..1.
func animate(speed: float, dt: float, steer: float) -> void:
	steer_yaw = -steer * STEER_MAX
	for i in wheels.size():
		angles[i] = fmod(angles[i] + speed / radii[i] * dt, TAU)     # fmod: sem perder precisao em corridas longas
		var yaw: float = steer_yaw if is_front(wheels[i]) else 0.0
		# ordem: rotacao original do modelo -> giro no eixo X -> esterçamento no eixo vertical
		wheels[i].transform.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -angles[i]) * rest[i]


## Rodas que aparecem de fora: as duas dianteiras e, em cada eixo traseiro e lado, a mais externa (no rodado duplo
## a de dentro fica escondida atras da de fora).
func outer_wheels() -> Array[Node3D]:
	var best: Dictionary = {}                      # "lado:eixo" -> roda mais externa
	var out: Array[Node3D] = []
	for w in wheels:
		if is_front(w):
			out.append(w)
			continue
		var key: String = "%d:%d" % [signi(int(signf(w.position.x))), roundi(w.position.z * 100.0)]
		if not best.has(key) or absf(w.position.x) > absf((best[key] as Node3D).position.x):
			best[key] = w
	for k in best:
		out.append(best[k])
	return out


## Transform local (no espaco da roda `w`, em repouso) da peca de roda: copia o encaixe do ponto FACE do mesmo lado
## (frente ou traseira) e desloca para o eixo de `w`. Lado esquerdo espelhado em X, como no catalogo.
func part_transform(w: Node3D) -> Transform3D:
	var left: bool = w.position.x < 0.0
	var side: String = "L" if left else "R"
	var mount: Node3D = _model.find_child((FACE_FRONT if is_front(w) else FACE_REAR) + side, true, false) as Node3D
	if mount == null:
		mount = _model.find_child(FACE_FRONT + side, true, false) as Node3D
	var i: int = wheels.find(w)
	var w_rest: Transform3D = _rel(w.get_parent()) * Transform3D(rest[i] if i >= 0 else w.transform.basis, w.position)
	var target: Transform3D
	if mount == null:                                  # sem ponto: encosta a peca na face externa do pneu
		target = Transform3D(Basis.IDENTITY, w_rest.origin + Vector3(signf(w_rest.origin.x) * 0.17, 0.0, 0.0))
	else:
		var m: Transform3D = _rel(mount)
		var ref: Node3D = _nearest_wheel(m.origin, is_front(w))
		# deslocamento do ponto em relacao a roda que ele enfeita (frente: a propria; tras: a externa do 1o eixo),
		# repetido no eixo de `w` (todos os eixos traseiros tem a mesma roda)
		var off: Vector3 = m.origin - (_rel(ref).origin if ref != null else w_rest.origin)
		target = Transform3D(m.basis, w_rest.origin + off)
	if left:
		target.basis = target.basis * Basis.from_scale(Vector3(-1, 1, 1))
	return w_rest.affine_inverse() * target


## Instancia a peca de roda `id` em todas as rodas externas (filha de cada roda). Devolve os nos criados.
func attach_part(catalog: AccessoryCatalog, id: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for w in outer_wheels():
		var n: Node3D = catalog.instantiate(id)
		if n == null:
			break
		n.name = "acc_%s_%s" % [id, w.name]
		n.set_meta("wheel_part", true)
		w.add_child(n)
		n.transform = part_transform(w)
		out.append(n)
	return out


## Peca que encaixa na roda (calota/roda da loja): o ponto de montagem do catalogo e um MOUNT_WHEEL_*.
static func is_wheel_part(entry: Dictionary) -> bool:
	return String(entry.get("mount_point", "")).begins_with("MOUNT_WHEEL_")


func _nearest_wheel(p: Vector3, front: bool) -> Node3D:
	var best: Node3D = null
	var d: float = INF
	for w in wheels:
		if is_front(w) != front:
			continue
		var dd: float = (_rel(w).origin - p).length()
		if dd < d:
			d = dd
			best = w
	return best


## Transform do no em relacao a raiz do modelo (sem depender da arvore de cena).
func _rel(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != null and n != _model and n is Node3D:
		t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
