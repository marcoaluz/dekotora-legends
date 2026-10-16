class_name BotDriver
extends RefCounted
## IA dos rivais: gera Commands como se fosse um jogador (mesma entrada que o humano e a rede).
## Segue a pista, freia antes de curvas fortes, desvia do transito e de caminhoes lentos, tenta
## ultrapassar e, as vezes, fecha o jogador. 3 dificuldades.

enum Difficulty { EASY, NORMAL, HARD }

const SPEED_FRACTION: Array[float] = [0.72, 0.86, 0.97]     # fracao da velocidade maxima
const CURVE_MARGIN: Array[float] = [0.45, 0.6, 0.78]        # quanto da autoridade de direcao aceita usar
const REACTION_M: Array[float] = [14.0, 10.0, 7.0]          # distancia de reacao base (m)
const BLOCK_CHANCE: Array[float] = [0.0, 0.15, 0.4]         # chance, por segundo, de fechar o jogador

var difficulty: int = Difficulty.NORMAL
var preferred_x: float = 0.25
var target_x: float = 0.25
var aggression_target: int = -1        # indice do caminhao que ele tenta fechar
var _rng := RandomNumberGenerator.new()
var _lane_timer: float = 0.0
var _block_timer: float = 0.0
var out_of_road_count: int = 0         # vezes em que saiu da pista (testes)
var _was_off: bool = false


func _init(difficulty_: int = Difficulty.NORMAL, seed_: int = 1, preferred_x_: float = 0.25) -> void:
	difficulty = difficulty_
	_rng.seed = seed_
	preferred_x = preferred_x_
	target_x = preferred_x_


func _safe_speed(curve: float, grip: float) -> float:
	var c: float = absf(curve)
	if c < 0.05:
		return EngineModel.MAX_SPEED
	var authority: float = TruckSim.STEER_SPEED * grip * CURVE_MARGIN[difficulty]
	return sqrt(authority / (c * TruckSim.CURVE_PUSH))


## Menor gap (m) a frente em um corredor de x (carro ou caminhao). Devolve {gap, speed} ou {} se livre.
func _obstacle_ahead(sim: RaceSim, me: TruckSim, index: int, x: float, horizon: float) -> Dictionary:
	var best: Dictionary = {}
	var half: float = (TruckSim.WIDTH_X + 0.3) * 0.5
	var nose: float = me.z + TrafficSim.TRUCK_LEN
	if sim.traffic != null:
		for c in sim.traffic.cars:
			var gap: float = c.z - nose
			if gap > -2.0 and gap < horizon and absf(c.x - x) < half + 0.05:
				if best.is_empty() or gap < float(best["gap"]):
					best = {"gap": gap, "speed": c.speed, "truck": -1}
	for j in sim.trucks.size():
		if j == index:
			continue
		var o: TruckSim = sim.trucks[j]
		var gap2: float = o.z - nose
		if gap2 > -2.0 and gap2 < horizon and absf(o.x - x) < half + 0.1:
			if best.is_empty() or gap2 < float(best["gap"]):
				best = {"gap": gap2, "speed": o.speed, "truck": j}
	return best


func command_for(sim: RaceSim, index: int, dt: float) -> Commands:
	var me: TruckSim = sim.trucks[index]
	var track: Track = sim.track
	var speed: float = me.speed
	var look: float = 30.0 + speed * 1.6
	var vmax: float = EngineModel.MAX_SPEED * SPEED_FRACTION[difficulty]
	# velocidade segura para a curva mais forte a frente
	var safe: float = vmax
	var probe: float = 10.0
	while probe <= look + 40.0:
		safe = minf(safe, _safe_speed(track.curve_at(me.z + probe), me.grip()) + probe * 0.04)
		probe += 12.0
	var desired: float = minf(vmax, safe)
	# obstaculo na faixa atual / desejada
	var horizon: float = REACTION_M[difficulty] + speed * 1.3
	var obstacle: Dictionary = _obstacle_ahead(sim, me, index, target_x, horizon)
	var passing: bool = false
	_lane_timer -= dt
	if not obstacle.is_empty():
		# tenta desviar para outra faixa livre
		var options: Array[float] = []
		for lane_x in TrafficSim.LANES:
			if absf(lane_x - target_x) > 0.1 and absf(lane_x - target_x) < 0.8 \
					and _obstacle_ahead(sim, me, index, lane_x, horizon * 1.2).is_empty():
				options.append(lane_x)
		if not options.is_empty() and _lane_timer <= 0.0:
			options.sort_custom(func(a: float, b: float) -> bool: return absf(a - target_x) < absf(b - target_x))
			target_x = options[0]
			_lane_timer = 1.0
			passing = int(obstacle["truck"]) >= 0
		else:
			desired = minf(desired, float(obstacle["speed"]) * 0.95)
			if float(obstacle["gap"]) < 6.0:
				desired = minf(desired, float(obstacle["speed"]) * 0.7)
	elif _lane_timer <= 0.0 and absf(target_x - preferred_x) > 0.05:
		if _obstacle_ahead(sim, me, index, preferred_x, horizon * 1.4).is_empty():
			target_x = preferred_x
	# as vezes fecha o jogador (indice 0) se estiver ao lado/atras proximo
	if BLOCK_CHANCE[difficulty] > 0.0 and index != 0 and not sim.trucks.is_empty():
		_block_timer -= dt
		var p: TruckSim = sim.trucks[0]
		var dz: float = me.z - p.z
		if _block_timer <= 0.0:
			_block_timer = 1.0
			if dz > 0.0 and dz < 40.0 and _rng.randf() < BLOCK_CHANCE[difficulty]:
				target_x = clampf(p.x, -0.8, 0.8)
				_lane_timer = 1.5
	# direcao: PD para target_x + compensacao da curva
	var curve_now: float = track.curve_at(me.z + 6.0)
	var authority: float = maxf(TruckSim.STEER_SPEED * me.grip() * minf(speed / 8.0, 1.0), 0.2)
	var ff: float = curve_now * speed * speed * TruckSim.CURVE_PUSH / authority
	var steer: float = clampf((target_x - me.x) * 2.2 - me.lateral_vel * 0.35 + ff, -1.0, 1.0)
	# acelerador/freio para a velocidade desejada
	var throttle: float = 0.0
	var brake: float = 0.0
	if speed < desired - 0.5:
		throttle = 1.0
	elif speed < desired + 0.5:
		throttle = 0.3
	else:
		brake = clampf((speed - desired) * 0.25, 0.0, 1.0)
	var off: bool = absf(me.x) > 1.0
	if off and not _was_off:
		out_of_road_count += 1
	_was_off = off
	return Commands.make(steer, throttle, brake, passing)
