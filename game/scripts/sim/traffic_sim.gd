class_name TrafficSim
extends RefCounted
## Carros comuns na pista: andam em faixas, mais devagar que os caminhoes, as vezes trocam de faixa.
## Determinístico (semente fixa) para rodar igual no servidor. Os carros que ficam para tras
## do ultimo caminhao reaparecem a frente do lider, entao a densidade fica sempre em volta do grupo.

enum Density { LIGHT, NORMAL, HEAVY }

const LANES: Array[float] = [-0.75, -0.25, 0.25, 0.75]
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


class Car:
	extends RefCounted
	var z: float = 0.0
	var x: float = 0.0
	var speed: float = 20.0
	var lane: int = 0
	var timer: float = 5.0
	var color_id: int = 0


var cars: Array[Car] = []
var density: int = Density.NORMAL
var hits: int = 0                          # contagem de batidas (debug / testes)
var _rng := RandomNumberGenerator.new()


func _init(seed_: int = 1234, density_: int = Density.NORMAL) -> void:
	_rng.seed = seed_
	density = density_
	var n: int = COUNT_BY_DENSITY[density]
	var z: float = 80.0
	for i in n:
		var c := Car.new()
		z += _rng.randf_range(35.0, 110.0)
		_place(c, z)
		cars.append(c)


func _place(c: Car, z: float) -> void:
	c.z = z
	c.lane = _rng.randi_range(0, LANES.size() - 1)
	c.x = LANES[c.lane]
	c.speed = _rng.randf_range(MIN_SPEED, MAX_SPEED)
	c.timer = _rng.randf_range(3.0, 10.0)
	c.color_id = _rng.randi_range(0, 5)


func _lane_free(lane: int, z: float, ignore: Car) -> bool:
	for o in cars:
		if o != ignore and o.lane == lane and absf(o.z - z) < 25.0:
			return false
	return true


func step(dt: float, leader_z: float, rear_z: float) -> void:
	for c in cars:
		c.z += c.speed * dt
		var target_x: float = LANES[c.lane]
		c.x = move_toward(c.x, target_x, LANE_CHANGE_RATE * dt)
		c.timer -= dt
		if c.timer <= 0.0:
			c.timer = _rng.randf_range(4.0, 12.0)
			var dir: int = -1 if _rng.randf() < 0.5 else 1
			var nl: int = c.lane + dir
			if nl >= 0 and nl < LANES.size() and _lane_free(nl, c.z, c):
				c.lane = nl
		if c.z < rear_z - DESPAWN_BEHIND:
			for attempt in 6:
				_place(c, leader_z + _rng.randf_range(SPAWN_AHEAD_MIN, SPAWN_AHEAD_MAX))
				if _lane_free(c.lane, c.z, c):
					break
