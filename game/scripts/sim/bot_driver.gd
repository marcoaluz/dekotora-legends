class_name BotDriver
extends RefCounted
## IA dos rivais: gera Commands como se fosse um jogador (mesma entrada que o humano e a rede).
## Controle por faixas: escolhe a faixa alvo e "toca" duas vezes (seta, depois troca), como o jogador.
## Freia antes de curvas fortes e desvia do transito, mas DEMORA para tentar sair de tras de um carro lento
## (STUCK_DELAY): quem e rapido na reta trava no transito. Sem "borracha": a velocidade desejada nunca
## depende de quem esta na frente ou atras (so de curva, transito e do duelo). O rival (`rival = true`
## ou dificuldade >= NORMAL) emparelha ao lado do jogador, "espelha" a seta dele para fechar a faixa e
## empurra de lado (a batida lateral e o empurrao normais da simulacao). 3 dificuldades.

enum Difficulty { EASY, NORMAL, HARD }

const SPEED_FRACTION: Array[float] = [0.72, 0.86, 0.97]     # fracao da velocidade maxima
const CURVE_MARGIN: Array[float] = [0.85, 0.92, 1.0]        # fator sobre a velocidade segura da curva
const REACTION_M: Array[float] = [14.0, 10.0, 7.0]          # distancia de reacao base (m)
const TAP_WAIT: Array[float] = [0.3, 0.25, 0.12]            # s entre o toque da seta e o toque da troca
const STUCK_DELAY: Array[float] = [0.8, 1.0, 1.6]           # s freando atras do transito antes de tentar sair
const REACT_DELAY: Array[float] = [0.7, 0.35, 0.15]         # s para reagir a seta do jogador
const DUEL_CHANCE: Array[float] = [0.3, 0.5, 0.9]           # chance, por checagem (1 s), de abrir duelo estando ao lado
const DUEL_RANGE_M: float = 16.0                            # |dz| abaixo disto = lado a lado
const DUEL_SEEK_M: float = 70.0                             # distancia em que enxerga o jogador
const DUEL_TIME: Vector2 = Vector2(5.0, 9.0)                # s de duelo (emparelhado)
const PRESS_EVERY: Vector2 = Vector2(1.6, 3.2)              # s entre uma "fechada" e outra
const PRESS_TIME: float = 1.4                               # s mirando a faixa do jogador

var difficulty: int = Difficulty.NORMAL
var rival: bool = false                # duela com o jogador mesmo na dificuldade facil
var preferred_lane: int = Lanes.CENTER
var target_lane: int = Lanes.CENTER
var target_x: float:
	get:
		return Lanes.X[target_lane]
var duel_count: int = 0                # duelos iniciados (testes)
var press_count: int = 0               # vezes que mirou a faixa do jogador para empurrar (testes)
var mirror_count: int = 0              # vezes que fechou a faixa que o jogador sinalizou (testes)
var out_of_road_count: int = 0         # vezes em que saiu da pista (testes)
var _rng := RandomNumberGenerator.new()
var _lane_timer: float = 0.0
var _tap_timer: float = 0.0
var _last_dir: int = 0
var _closing_lane: int = -1            # faixa do jogador que ele quer fechar de proposito (ignora quem esta ao lado)
var _blocked_time: float = 0.0
var _duel_t: float = 0.0
var _duel_check: float = 0.0
var _press_t: float = 1.0
var _pressing_t: float = 0.0
var _react_t: float = 0.0
var _seen_signal: int = 0
var _was_off: bool = false


## `no_duel_`: o bot dirige um HUMANO (piloto automatico, cliente de teste) e nao deve duelar com outros humanos.
func _init(difficulty_: int = Difficulty.NORMAL, seed_: int = 1, preferred_x_: float = 0.0, rival_: bool = false, no_duel_: bool = false) -> void:
	difficulty = difficulty_
	rival = (rival_ or difficulty_ >= Difficulty.NORMAL) and not no_duel_
	_rng.seed = seed_
	preferred_lane = clampi(Lanes.nearest(preferred_x_), Lanes.FIRST, Lanes.LAST)
	target_lane = preferred_lane


func _safe_speed(curve: float, grip: float) -> float:
	return TruckSim.curve_safe_speed(curve, grip) * CURVE_MARGIN[difficulty]


## Menor gap (m) a frente em um corredor de x (carro ou caminhao). Devolve {gap, speed} ou {} se livre.
func _obstacle_ahead(sim: RaceSim, me: TruckSim, index: int, x: float, horizon: float) -> Dictionary:
	var best: Dictionary = {}
	var half: float = (TruckSim.WIDTH_X + 0.3) * 0.5
	var nose: float = me.z + me.length
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
			if absf(o.x - lx) < 0.45 and o.z < me.z + me.length + margin and o.z + o.length + margin > me.z:
				return false
	if sim.traffic != null:
		for c in sim.traffic.cars:
			if absf(c.x - lx) < 0.4 and c.z < me.z + me.length + margin and c.z + c.length + margin > me.z:
				return false
	return true


## Caminhao humano mais proximo (em z) dentro de DUEL_SEEK_M. -1 se nao ha.
func _find_prey(sim: RaceSim, me: TruckSim, index: int) -> int:
	var best: int = -1
	var best_d: float = DUEL_SEEK_M
	for j in sim.trucks.size():
		var o: TruckSim = sim.trucks[j]
		if j == index or o.is_bot or o.finish_position > 0:
			continue
		var d: float = absf(o.z - me.z)
		if d < best_d:
			best_d = d
			best = j
	return best


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
		_tap_timer = TAP_WAIT[difficulty]
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
	if obstacle.is_empty():
		_blocked_time = 0.0
	else:
		_blocked_time += dt
		# tenta desviar para uma faixa vizinha livre, mas so depois de ficar STUCK_DELAY preso atras (trava no transito)
		var options: Array[int] = []
		for step_ in [-1, 1]:
			var nl: int = target_lane + int(step_)
			if _lane_free(sim, me, index, nl, horizon * 1.2):
				options.append(nl)
		if not options.is_empty() and _lane_timer <= 0.0 and _blocked_time >= STUCK_DELAY[difficulty]:
			target_lane = options[_rng.randi_range(0, options.size() - 1)] if options.size() > 1 else options[0]
			_lane_timer = 1.0
			passing = int(obstacle["truck"]) >= 0
		else:
			desired = minf(desired, float(obstacle["speed"]) * 0.95)
			if float(obstacle["gap"]) < 6.0:
				desired = minf(desired, float(obstacle["speed"]) * 0.7)
	if obstacle.is_empty() and _lane_timer <= 0.0 and target_lane != preferred_lane and _duel_t <= 0.0:
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
	# duelo com o jogador: emparelha, espelha a seta e empurra
	if rival:
		desired = _duel(sim, me, index, dt, desired, obstacle)
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
	var off: bool = absf(me.x) > 1.0               # saiu de verdade da pista (alem do acostamento)
	if off and not _was_off:
		out_of_road_count += 1
	_was_off = off
	return Commands.make(float(_lane_tap(sim, me, index, dt)), throttle, brake, passing)


## Logica do duelo. Devolve a velocidade desejada (so o duelo pode reduzi-la para ficar ao lado; nunca passa de `desired`).
func _duel(sim: RaceSim, me: TruckSim, index: int, dt: float, desired: float, obstacle: Dictionary) -> float:
	var pi: int = _find_prey(sim, me, index)
	if pi < 0:
		_duel_t = 0.0
		_seen_signal = 0
		return desired
	var prey: TruckSim = sim.trucks[pi]
	var dz: float = prey.z - me.z                    # > 0: o jogador esta a frente
	# 1) espelha a seta do jogador: vai para a faixa que ele quer, depois do tempo de reacao
	if prey.signal_dir != 0 and absf(dz) < DUEL_RANGE_M * 1.5:
		if _seen_signal != prey.signal_dir:
			_seen_signal = prey.signal_dir
			_react_t = REACT_DELAY[difficulty]
		_react_t -= dt
		var wanted: int = prey.lane + prey.signal_dir
		if _react_t <= 0.0 and Lanes.is_road_lane(wanted) and wanted != me.lane and absf(me.lane - wanted) <= 1:
			target_lane = wanted
			_closing_lane = wanted
			_lane_timer = 1.0
			mirror_count += 1
			_react_t = 9.0                            # uma reacao por seta
	else:
		_seen_signal = 0
	# 2) abre duelo quando esta ao lado
	_duel_check -= dt
	if _duel_t <= 0.0 and _duel_check <= 0.0 and absf(dz) < DUEL_RANGE_M:
		_duel_check = 1.0
		if _rng.randf() < DUEL_CHANCE[difficulty]:
			_duel_t = _rng.randf_range(DUEL_TIME.x, DUEL_TIME.y)
			_press_t = _rng.randf_range(PRESS_EVERY.x, PRESS_EVERY.y)
			duel_count += 1
	if _duel_t <= 0.0:
		return desired
	_duel_t -= dt
	if absf(dz) > DUEL_RANGE_M * 2.5:
		_duel_t = 0.0                                # perdeu o jogador de vista
		return desired
	# 3) fica ao lado: mesma velocidade, ajustada pela diferenca de posicao
	var v_keep: float = prey.speed + clampf(dz * 0.3, -6.0, 6.0)
	var out: float = minf(desired, maxf(v_keep, 0.0))
	# 4) faixa: vizinha do jogador; de vez em quando mira a faixa dele para empurrar
	if _pressing_t > 0.0:
		_pressing_t -= dt
		var lane_p: int = clampi(prey.lane, Lanes.FIRST, Lanes.LAST)
		if lane_p != target_lane:
			target_lane = lane_p
		_closing_lane = lane_p
		if _pressing_t <= 0.0:
			_closing_lane = -1
	else:
		_press_t -= dt
		if _press_t <= 0.0 and (obstacle.is_empty() or float(obstacle["gap"]) > 12.0):
			_press_t = _rng.randf_range(PRESS_EVERY.x, PRESS_EVERY.y)
			_pressing_t = PRESS_TIME
			press_count += 1
		elif _lane_timer <= 0.0:
			var side: int = 1 if me.x >= prey.x else -1
			var next_to: int = prey.lane + side
			if not Lanes.is_road_lane(next_to):
				next_to = prey.lane - side
			if Lanes.is_road_lane(next_to) and next_to != target_lane and _lane_free(sim, me, index, next_to, 10.0):
				target_lane = next_to
				_lane_timer = 1.0
	return out
