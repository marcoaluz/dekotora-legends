class_name TrafficSim
extends RefCounted
## Carros comuns na pista: andam em faixas, mais devagar que os caminhoes, as vezes trocam de faixa.
## Determinístico (semente fixa) para rodar igual no servidor. Os carros que ficam para tras
## do ultimo caminhao reaparecem a frente do lider, entao a densidade fica sempre em volta do grupo.
##
## Tipos (T-124): carro comum, onibus (longo, lento, pesado) e esportivo (raro, rapido). O tipo de cada
## veiculo sai so do indice dele (Kind fixo a corrida toda), entao servidor e clientes concordam sem
## mandar nada pela rede. Quem alcanca um veiculo mais lento na mesma faixa tenta trocar de faixa e,
## se nao der, segue atras dele (ninguem atravessa o onibus).

enum Density { LIGHT, NORMAL, HEAVY }
enum Kind { CAR, BUS, SPORT }

const LANES: Array[float] = [-0.5, 0.0, 0.5]       # = Lanes.ROAD: as 3 faixas de rolagem
const CAR_LEN: float = 4.5
const CAR_WIDTH_X: float = 0.27          # 1,9 m em unidades de x
const TRUCK_LEN: float = 12.0
const COUNT_BY_DENSITY: Array[int] = [8, 14, 22]
const MIN_SPEED: float = 15.0
const MAX_SPEED: float = 26.0
const LANE_CHANGE_RATE: float = 0.7      # x/s ao trocar de faixa
const SPAWN_AHEAD_MIN: float = 300.0
const SPAWN_AHEAD_MAX: float = 700.0
const DESPAWN_BEHIND: float = 150.0
const LANE_GAP: float = 20.5             # m livres entre carrocerias para entrar numa faixa
# por tipo (indice = Kind): comprimento (m), largura (unidades de x), velocidade (m/s) e massa (kg)
const KIND_LEN: Array[float] = [4.5, 13.3, 4.5]
const KIND_WIDTH_X: Array[float] = [0.27, 0.36, 0.28]
const KIND_SPEED_MIN: Array[float] = [15.0, 13.0, 29.0]
const KIND_SPEED_MAX: Array[float] = [26.0, 17.0, 34.0]
const KIND_MASS: Array[float] = [1500.0, 12000.0, 1400.0]
# um onibus a cada BUS_EVERY veiculos (a partir do 6o) e um esportivo a cada SPORT_EVERY (a partir do 5o)
const BUS_EVERY: int = 11
const SPORT_EVERY: int = 9
const FOLLOW_GAP: float = 8.0            # m de folga minima atras de um mais lento
const LOOK_AHEAD: float = 60.0           # m: ate onde enxerga quem esta a frente
const ACCEL: float = 3.0                 # m/s^2 para voltar a velocidade de cruzeiro
const BRAKE: float = 7.0                 # m/s^2 ao alcancar um mais lento


class Car:
	extends RefCounted
	var z: float = 0.0
	var x: float = 0.0
	var speed: float = 20.0
	var cruise: float = -1.0             # velocidade desejada (sorteada ao nascer; < 0 = usar `speed`)
	var lane: int = 0
	var timer: float = 5.0
	var color_id: int = 0
	var kind: int = Kind.CAR
	var length: float = CAR_LEN
	var width_x: float = CAR_WIDTH_X
	var mass: float = 1500.0


var cars: Array[Car] = []
var density: int = Density.NORMAL
var hits: int = 0                          # contagem de batidas (debug / testes)
var _rng := RandomNumberGenerator.new()


## Tipo do veiculo de indice `i` (fixo: so depende do indice).
static func kind_for_index(i: int) -> int:
	if i % BUS_EVERY == 5:
		return Kind.BUS
	if i % SPORT_EVERY == 4:
		return Kind.SPORT
	return Kind.CAR


func _init(seed_: int = 1234, density_: int = Density.NORMAL) -> void:
	_rng.seed = seed_
	density = density_
	var n: int = COUNT_BY_DENSITY[density]
	var z: float = 80.0
	for i in n:
		var c := Car.new()
		c.kind = kind_for_index(i)
		c.length = KIND_LEN[c.kind]
		c.width_x = KIND_WIDTH_X[c.kind]
		c.mass = KIND_MASS[c.kind]
		z += _rng.randf_range(35.0, 110.0)
		_place(c, z)
		cars.append(c)


func _place(c: Car, z: float) -> void:
	c.z = z
	c.lane = _rng.randi_range(0, LANES.size() - 1)
	c.x = LANES[c.lane]
	# mesmo sorteio de antes (a sequencia da semente nao muda); a faixa de velocidade e a do tipo
	var t: float = inverse_lerp(MIN_SPEED, MAX_SPEED, _rng.randf_range(MIN_SPEED, MAX_SPEED))
	c.cruise = lerpf(KIND_SPEED_MIN[c.kind], KIND_SPEED_MAX[c.kind], t)
	c.speed = c.cruise
	c.timer = _rng.randf_range(3.0, 10.0)
	c.color_id = _rng.randi_range(0, 5)


## Faixa `lane` livre para o carro `ignore` ocupar a partir de `z`: nenhuma carroceria a menos de LANE_GAP.
func _lane_free(lane: int, z: float, ignore: Car) -> bool:
	var length: float = ignore.length if ignore != null else CAR_LEN
	for o in cars:
		if o != ignore and o.lane == lane:
			var gap: float = maxf(o.z - (z + length), z - (o.z + o.length))
			if gap < LANE_GAP:
				return false
	return true


## Veiculo (carro ou caminhao) mais lento logo a frente de `c` na mesma linha, perto o bastante para
## precisar frear (distancia de frenagem + FOLLOW_GAP). {} se livre.
func _blocker(c: Car, trucks: Array) -> Dictionary:
	var best: Dictionary = {}
	var nose: float = c.z + c.length
	for o in cars:
		if o != c and absf(o.x - c.x) < (o.width_x + c.width_x) * 0.5:
			best = _closer(best, o.z - nose, o.speed, c.speed)
	for t in trucks:
		var tr: TruckSim = t
		if absf(tr.x - c.x) < (TruckSim.WIDTH_X + c.width_x) * 0.5:
			best = _closer(best, tr.z - nose, tr.speed, c.speed)
	return best


func _closer(best: Dictionary, gap: float, other_speed: float, my_speed: float) -> Dictionary:
	if gap <= -1.0 or gap > LOOK_AHEAD or other_speed >= my_speed + 0.5 and gap > FOLLOW_GAP:
		return best
	var dv: float = maxf(my_speed - other_speed, 0.0)
	if gap > dv * dv / (2.0 * BRAKE) + FOLLOW_GAP:
		return best
	if best.is_empty() or gap < float(best["gap"]):
		return {"gap": gap, "speed": other_speed}
	return best


## Algum caminhao ocupa a faixa `lane` ao lado de `c` (com folga de 6 m na frente e atras)?
func _truck_beside(lane: int, c: Car, trucks: Array) -> bool:
	for t in trucks:
		var tr: TruckSim = t
		var beside_x: bool = absf(tr.x - LANES[lane]) < (TruckSim.WIDTH_X + c.width_x) * 0.5
		if beside_x and tr.z < c.z + c.length + 6.0 and tr.z + tr.length + 6.0 > c.z:
			return true
	return false


func step(dt: float, leader_z: float, rear_z: float, trucks: Array = []) -> void:
	for c in cars:
		if c.cruise < 0.0:
			c.cruise = c.speed
		var target_speed: float = c.cruise
		var blk: Dictionary = _blocker(c, trucks)
		if not blk.is_empty() and float(blk["speed"]) < c.cruise:
			# alcancou alguem mais lento: tenta a faixa da esquerda, depois a da direita; senao, segue atras
			var moved: bool = false
			if absf(c.x - LANES[c.lane]) < 0.05:
				for nl in [c.lane - 1, c.lane + 1]:
					if nl >= 0 and nl < LANES.size() and _lane_free(nl, c.z, c) and not _truck_beside(nl, c, trucks):
						c.lane = nl
						moved = true
						break
			if not moved:
				target_speed = minf(c.cruise, float(blk["speed"]))
		c.speed = move_toward(c.speed, target_speed, (ACCEL if target_speed > c.speed else BRAKE) * dt)
		c.z += c.speed * dt
		var target_x: float = LANES[c.lane]
		c.x = move_toward(c.x, target_x, LANE_CHANGE_RATE * dt)
		c.timer -= dt
		if c.timer <= 0.0:
			c.timer = _rng.randf_range(4.0, 12.0)
			var dir: int = -1 if _rng.randf() < 0.5 else 1
			var nl2: int = c.lane + dir
			if nl2 >= 0 and nl2 < LANES.size() and _lane_free(nl2, c.z, c):
				c.lane = nl2
		if c.z < rear_z - DESPAWN_BEHIND:
			for attempt in 6:
				_place(c, leader_z + _rng.randf_range(SPAWN_AHEAD_MIN, SPAWN_AHEAD_MAX))
				if _lane_free(c.lane, c.z, c):
					break
