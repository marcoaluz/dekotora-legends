class_name RailLine
extends RefCounted
## Uma linha de trem (via dupla) so visual (T-154): polilinha 3D do EIXO da via dupla com comprimento acumulado.
## - paralela: acompanha a pista a `offset` m do centro (lado `side`), de `z0` a `z1` (z da pista);
## - cruzamento: reta que passa por cima da pista em `z_cross`, formando `angle` com a pista, `height` m acima dela.
## As duas vias ficam a +-TRACK_SPACING/2 do eixo. Puro calculo (sem nos): testavel e usado pelo visual e pelos trens.

const TRACK_SPACING: float = 4.0
const STEP_M: float = 2.0

enum Kind { PARALLEL, CROSSING }

var kind: int = Kind.PARALLEL
var side: float = -1.0            # -1 esquerda da pista, +1 direita
var offset: float = 36.0          # paralela: distancia lateral do eixo (m)
var z0: float = 0.0
var z1: float = 0.0
var deck: float = 0.0             # altura do trilho acima da pista (viaduto da cidade: 0, o chao fica la embaixo)
var ground: float = 0.0           # quanto o chao fica abaixo da pista (cidade: 9 m)
var end_portals: Vector2i = Vector2i.ZERO   # boca de tunel no comeco (x) / no fim (y): 1 = sim
var z_cross: float = 0.0
var angle: float = 1.2            # rad entre a linha e a pista (cruzamento)
var half_len: float = 300.0
var pts: PackedVector3Array = PackedVector3Array()
var dirs: PackedVector3Array = PackedVector3Array()     # direcao (horizontal) em cada ponto
var cum: PackedFloat32Array = PackedFloat32Array()      # comprimento acumulado (m)
var road_z: PackedFloat32Array = PackedFloat32Array()   # z da pista mais perto de cada ponto


static func parallel(path: TrackPath, z0_: float, z1_: float, side_: float, offset_: float, deck_: float = 0.0,
		ground_: float = 0.0, portals: Vector2i = Vector2i.ZERO) -> RailLine:
	var l := RailLine.new()
	l.kind = Kind.PARALLEL
	l.z0 = z0_
	l.z1 = z1_
	l.side = side_
	l.offset = offset_
	l.deck = deck_
	l.ground = ground_
	l.end_portals = portals
	var z: float = z0_
	while true:
		l._push(path.world_point(z, side_ * offset_ / Track.ROAD_HALF_WIDTH_M, deck_), z)
		if z >= z1_:
			break
		z = minf(z + STEP_M, z1_)
	l._finish()
	return l


static func crossing(path: TrackPath, z_c: float, angle_: float, height: float, half_len_: float, ground_: float = 0.0,
		portals: Vector2i = Vector2i.ZERO) -> RailLine:
	var l := RailLine.new()
	l.kind = Kind.CROSSING
	l.z_cross = z_c
	l.angle = angle_
	l.half_len = half_len_
	l.deck = height
	l.ground = ground_
	l.end_portals = portals
	var c: Vector3 = path.center_at(z_c) + Vector3.UP * height
	var d: Vector3 = path.forward_at(z_c).rotated(Vector3.UP, -angle_)   # gira para a direita: vai da esquerda para a direita
	var s: float = -half_len_
	while s <= half_len_ + 0.001:
		var p: Vector3 = c + d * s
		l._push(p, l._nearest_z(path, p, z_c))
		s += STEP_M
	l._finish()
	return l


func _push(p: Vector3, z: float) -> void:
	pts.append(p)
	road_z.append(z)


func _finish() -> void:
	cum.resize(pts.size())
	dirs.resize(pts.size())
	var acc: float = 0.0
	for i in pts.size():
		if i > 0:
			acc += pts[i].distance_to(pts[i - 1])
		cum[i] = acc
		var a: Vector3 = pts[maxi(i - 1, 0)]
		var b: Vector3 = pts[mini(i + 1, pts.size() - 1)]
		var d: Vector3 = Vector3(b.x - a.x, 0.0, b.z - a.z)
		dirs[i] = d.normalized() if d.length_squared() > 1e-6 else Vector3.FORWARD


## z da pista mais perto do ponto (busca local a partir de `guess`).
func _nearest_z(path: TrackPath, p: Vector3, guess: float) -> float:
	var best: float = guess
	var bd: float = INF
	var z: float = maxf(guess - 400.0, 0.0)
	while z <= minf(guess + 400.0, path.track.length_m):
		var d: float = Vector2(p.x, p.z).distance_squared_to(Vector2(path.center_at(z).x, path.center_at(z).z))
		if d < bd:
			bd = d
			best = z
		z += 4.0
	return best


func length() -> float:
	return cum[cum.size() - 1] if cum.size() > 0 else 0.0


func _index(s: float) -> Vector2:
	var sc: float = clampf(s, 0.0, length())
	var lo: int = 0
	var hi: int = cum.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) >> 1
		if cum[mid] <= sc:
			lo = mid
		else:
			hi = mid
	var seg: float = cum[hi] - cum[lo]
	return Vector2(float(lo), (sc - cum[lo]) / seg if seg > 0.0 else 0.0)


## Ponto do eixo da via dupla no comprimento `s` (m), deslocado `lat` m para a direita da linha.
func point(s: float, lat: float = 0.0) -> Vector3:
	var k: Vector2 = _index(s)
	var i: int = int(k.x)
	var j: int = mini(i + 1, pts.size() - 1)
	var p: Vector3 = pts[i].lerp(pts[j], k.y)
	return p + right(s) * lat


func dir(s: float) -> Vector3:
	var k: Vector2 = _index(s)
	var i: int = int(k.x)
	var j: int = mini(i + 1, pts.size() - 1)
	return dirs[i].lerp(dirs[j], k.y).normalized()


func right(s: float) -> Vector3:
	var d: Vector3 = dir(s)
	return Vector3(-d.z, 0.0, d.x)


## z da pista ao lado do comprimento `s` (para a distancia ate o jogador).
func z_at(s: float) -> float:
	var k: Vector2 = _index(s)
	var i: int = int(k.x)
	var j: int = mini(i + 1, road_z.size() - 1)
	return lerpf(road_z[i], road_z[j], k.y)


## Comprimento `s` mais perto do z da pista (paralela: direto; cruzamento: ponto sobre a pista).
func s_at_z(z: float) -> float:
	if kind == Kind.CROSSING:
		return length() * 0.5
	var best: int = 0
	var bd: float = INF
	for i in road_z.size():
		var d: float = absf(road_z[i] - z)
		if d < bd:
			bd = d
			best = i
	return cum[best]


## Transform de um vagao de comprimento `car_len` cujo CENTRO esta em `s`, andando no sentido `dir_sign`
## (+1 = crescente em s) na via `track` (-1 ou +1: lado do eixo). Frente do modelo = -Z (Godot).
func car_transform(s: float, car_len: float, dir_sign: float, track: float) -> Transform3D:
	var lat: float = track * TRACK_SPACING * 0.5
	var a: Vector3 = point(s - dir_sign * car_len * 0.35, lat)
	var b: Vector3 = point(s + dir_sign * car_len * 0.35, lat)
	var f: Vector3 = b - a
	if f.length_squared() < 1e-6:
		f = dir(s) * dir_sign
	var basis := Basis.looking_at(f.normalized(), Vector3.UP)
	return Transform3D(basis, (a + b) * 0.5)
