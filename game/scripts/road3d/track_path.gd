class_name TrackPath
extends RefCounted
## Converte a pista da simulacao (curva e inclinacao por segmento) em uma linha central 3D.
## Godot: frente = -Z, direita = +X. yaw > 0 vira para a ESQUERDA (rotacao positiva em Y).
## curva positiva da pista = vira a direita => yaw diminui.
## Puro calculo (sem nos): usado pela cena 3D, pelos objetos de beira de estrada e pela camera.

const YAW_PER_CURVE_PER_M: float = 0.0016   # rad por metro por unidade de curva (curva 1 = raio ~625 m)
const HILL_SCALE: float = 1.8               # exagero visual das subidas
const REAR_AXLE: float = 0.2                # fracao do comprimento: traseira -> eixo traseiro (pivo do giro)
const FRONT_AXLE: float = 0.85              # fracao do comprimento: traseira -> eixo dianteiro

var track: Track
var pos: PackedVector3Array = PackedVector3Array()   # posicao do INICIO de cada segmento (centro da pista)
var yaw: PackedFloat32Array = PackedFloat32Array()
var pitch: PackedFloat32Array = PackedFloat32Array()


func _init(track_: Track) -> void:
	track = track_
	var n: int = track.segment_count()
	pos.resize(n + 1)
	yaw.resize(n + 1)
	pitch.resize(n + 1)
	var p := Vector3.ZERO
	var a: float = 0.0
	for i in n:
		pos[i] = p
		yaw[i] = a
		var slope: float = track.hills[i] * HILL_SCALE
		pitch[i] = atan(slope)
		var f := Vector3(-sin(a), 0.0, -cos(a))
		p += f * Track.SEG_LEN * cos(pitch[i]) + Vector3.UP * slope * Track.SEG_LEN
		a -= track.curves[i] * YAW_PER_CURVE_PER_M * Track.SEG_LEN
	pos[n] = p
	yaw[n] = a
	pitch[n] = pitch[maxi(n - 1, 0)]


func _locate(z: float) -> Vector2:
	var s: float = clampf(z, 0.0, track.length_m - 0.001) / Track.SEG_LEN
	var i: int = int(s)
	return Vector2(float(i), s - float(i))


func center_at(z: float) -> Vector3:
	var l: Vector2 = _locate(z)
	var i: int = int(l.x)
	return pos[i].lerp(pos[i + 1], l.y)


func yaw_at(z: float) -> float:
	var l: Vector2 = _locate(z)
	var i: int = int(l.x)
	return lerp_angle(yaw[i], yaw[i + 1], l.y)


func pitch_at(z: float) -> float:
	var l: Vector2 = _locate(z)
	var i: int = int(l.x)
	return lerpf(pitch[i], pitch[i + 1], l.y)


func forward_at(z: float) -> Vector3:
	var a: float = yaw_at(z)
	return Vector3(-sin(a), 0.0, -cos(a))


func right_at(z: float) -> Vector3:
	var a: float = yaw_at(z)
	return Vector3(cos(a), 0.0, -sin(a))


## Ponto do mundo para (z, x em unidades -1..+1, altura em metros acima da pista).
func world_point(z: float, x_units: float, h: float = 0.0) -> Vector3:
	return center_at(z) + right_at(z) * (x_units * Track.ROAD_HALF_WIDTH_M) + Vector3.UP * h


## Base (orientacao) da pista em z: yaw + inclinacao.
func basis_at(z: float) -> Basis:
	return Basis(Vector3.UP, yaw_at(z)) * Basis(Vector3.RIGHT, pitch_at(z))


## Transform para um veiculo cujo ponto de referencia e a TRASEIRA em z e que mede `length` m, na linha x da faixa.
## Direcao = corda do eixo traseiro ao dianteiro sobre a propria linha da faixa: na curva o corpo acompanha a pista
## (sem ficar de lado, mesmo nos caminhoes de 7 a 17 m). `body_yaw` (rad, > 0 = esquerda) gira o corpo em torno do
## EIXO TRASEIRO (troca de faixa, TruckSim.body_yaw); `roll` inclina a cabine.
func vehicle_transform(z: float, x_units: float, length: float, body_yaw: float = 0.0, roll: float = 0.0) -> Transform3D:
	var rear_axle_m: float = length * REAR_AXLE
	var a: Vector3 = world_point(z + rear_axle_m, x_units)
	var fwd: Vector3 = world_point(z + length * FRONT_AXLE, x_units) - a
	if fwd.length_squared() < 0.0001:                 # antes da largada / depois do fim da pista (z limitado)
		fwd = forward_at(z + rear_axle_m)
	var b: Basis = Basis(Vector3.UP, body_yaw) * Basis.looking_at(fwd.normalized(), Vector3.UP) * Basis(Vector3.FORWARD, roll)
	var rear: Vector3 = a + b * Vector3(0, 0, rear_axle_m)   # +Z local = para tras
	return Transform3D(b, rear)
