class_name BotDriver
extends RefCounted
## IA dos rivais: gera Commands como se fosse um jogador (mesma entrada que o humano e a rede).
## Controle por faixas: escolhe a faixa alvo e "toca" duas vezes (seta, depois troca), como o jogador.
## Freia antes de curvas fortes, desvia do transito e de caminhoes lentos, tenta ultrapassar e,
## as vezes, fecha o jogador. 3 dificuldades.

enum Difficulty { EASY, NORMAL, HARD }

const SPEED_FRACTION: Array[float] = [0.72, 0.86, 0.97]     # fracao da velocidade maxima
const CURVE_MARGIN: Array[float] = [0.85, 0.92, 1.0]         # fator sobre a velocidade segura da curva
const REACTION_M: Array[float] = [14.0, 10.0, 7.0]          # distancia de reacao base (m)
const BLOCK_CHANCE: Array[float] = [0.0, 0.15, 0.4]         # chance, por segundo, de fechar o jogador
const TAP_WAIT: float = 0.25                                # s entre o toque da seta e o toque da troca

var difficulty: int = Difficulty.NORMAL
var preferred_lane: int = Lanes.CENTER
var target_lane: int = Lanes.CENTER
var target_x: float:
	get:
		return Lanes.X[target_lane]
var aggression_target: int = -1        # indice do caminhao que ele tenta fechar
var _rng := RandomNumberGenerator.new()
var _lane_timer: float = 0.0
var _block_timer: float = 0.0
var _tap_timer: float = 0.0
var _closing_lane: int = -1            # faixa do jogador que ele quer fechar de proposito (ignora quem esta ao lado)
var _last_dir: int = 0
var out_of_road_count: int = 0         # vezes em que saiu da pista (testes)
var _was_off: bool = false


func _init(difficulty_: int = Difficulty.NORMAL, seed_: int = 1, preferred_x_: float = 0.0) -> void:
	difficulty = difficulty_
	_rng.seed = seed_
	preferred_lane = clampi(Lanes.nearest(preferred_x_), Lanes.FIRST, Lanes.LAST)
	target_lane = preferred_lane


func _safe_speed(curve: float, grip: float) -> float:
	return TruckSim.curve_safe_speed(curve, grip) * CURVE_MARGIN[difficulty]


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


func _lane_free(sim: RaceSim, me: TruckSim, index: int, lane: int, horizon: float) -> bool:
	return Lanes.is_road_lane(lane) and _obstacle_ahead(sim, me, index, Lanes.X[lane], horizon).is_empty() \
			and _lane_side_clear(sim, me, index, lane)


## Ninguem ao lado (caminhao ou carro sobreposto em z) na faixa `lane`: trocar para ela nao bate de lado.
func _lane_side_clear(sim: RaceSim, me: TruckSim, index: int, lane: int) -> bool:
	var lx: float = Lanes.X[lane]
	var margin: float = 4.0
	for j in sim.trucks.size():
		if j != index:
			var o: TruckSim = sim.trucks[j]
			if absf(o.x - lx) < 0.45 and o.z < me.z + TrafficSim.TRUCK_LEN + margin and o.z + TrafficSim.TRUCK_LEN + margin > me.z:
				return false
	if sim.traffic != null:
		for c in sim.traffic.cars:
			if absf(c.x - lx) < 0.4 and c.z < me.z + TrafficSim.TRUCK_LEN + margin and c.z + TrafficSim.CAR_LEN + margin > me.z:
				return false
	return true


## Traduz "quero ir para target_lane" em toques: seta, espera, troca. Devolve a direcao (-1/0/+1) deste tick.
func _lane_tap(sim: RaceSim, me: TruckSim, index: int, dt: float) -> int:
	var want: int = signi(target_lane - me.lane)
	if want != 0 and me.signal_dir == want and target_lane != _closing_lane and not _lane_side_clear(sim, me, index, me.lane + want):
		target_lane = me.lane                   # apareceu alguem ao lado depois da seta: desiste
		want = 0
	var out: int = 0
	if want == 0:
		_tap_timer = 0.0
	elif me.signal_dir != want:
		if _last_dir == 0:
			out = want                  # 1o toque: liga a seta
		_tap_timer = TAP_WAIT
	else:
		_tap_timer -= dt
		if _tap_timer <= 0.0 and _last_dir == 0:
			out = want                  # 2o toque: executa a troca
	_last_dir = out
	return out


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
		safe = minf(safe, _safe_speed(track.curve_at(me.z + probe), me.grip()) + probe * 0.02)
		probe += 12.0
	var desired: float = minf(vmax, safe)
	# obstaculo na faixa atual / desejada
	var horizon: float = REACTION_M[difficulty] + speed * 1.3
	var obstacle: Dictionary = _obstacle_ahead(sim, me, index, Lanes.X[target_lane], horizon)
	var passing: bool = false
	_lane_timer -= dt
	if not obstacle.is_empty():
		# tenta desviar para uma faixa vizinha livre
		var options: Array[int] = []
		for step_ in [-1, 1]:
			var nl: int = target_lane + int(step_)
			if _lane_free(sim, me, index, nl, horizon * 1.2):
				options.append(nl)
		if not options.is_empty() and _lane_timer <= 0.0:
			target_lane = options[_rng.randi_range(0, options.size() - 1)] if options.size() > 1 else options[0]
			_lane_timer = 1.0
			passing = int(obstacle["truck"]) >= 0
		else:
			desired = minf(desired, float(obstacle["speed"]) * 0.95)
			if float(obstacle["gap"]) < 6.0:
				desired = minf(desired, float(obstacle["speed"]) * 0.7)
	elif _lane_timer <= 0.0 and target_lane != preferred_lane:
		var back: int = target_lane + signi(preferred_lane - target_lane)
		if _lane_free(sim, me, index, back, horizon * 1.4):
			target_lane = back
	# abre espaco para quem usa Passing logo atras
	for j in sim.trucks.size():
		var o: TruckSim = sim.trucks[j]
		if j != index and o.passing_active and me.z - o.z > 0.0 and me.z - o.z < 35.0 and absf(me.x - o.x) < 0.3:
			var dir: int = 1 if me.x >= o.x else -1
			target_lane = clampi(me.lane + dir, Lanes.FIRST, Lanes.LAST)
			_lane_timer = 1.5
	# as vezes fecha o jogador (indice 0) se estiver ao lado/atras proximo
	if BLOCK_CHANCE[difficulty] > 0.0 and index != 0 and not sim.trucks.is_empty():
		_block_timer -= dt
		var p: TruckSim = sim.trucks[0]
		var dz: float = me.z - p.z
		if _block_timer <= 0.0:
			_block_timer = 1.0
			if dz > 0.0 and dz < 40.0 and _rng.randf() < BLOCK_CHANCE[difficulty]:
				target_lane = clampi(p.lane, Lanes.FIRST, Lanes.LAST)
				_closing_lane = target_lane
				_lane_timer = 1.5
	# fora da pista (acostamento): volta para a faixa mais proxima
	if not Lanes.is_road_lane(me.lane) and target_lane == me.lane:
		target_lane = clampi(me.lane, Lanes.FIRST, Lanes.LAST)
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
	return Commands.make(float(_lane_tap(sim, me, index, dt)), throttle, brake, passing)
