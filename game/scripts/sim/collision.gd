class_name Collision
extends RefCounted
## Contato entre caminhoes e entre caminhao e transito. Decide zona atingida, impulso (empurrao
## proporcional ao peso) e dano. So numeros: nenhum no, nenhum som. Os efeitos saem como eventos.
##
## Geometria: cada caminhao ocupa z .. z+length (z = traseira; LEN = 12 m do caminhao padrao, o Canter tem 7 m) e |x - x0| < WIDTH_X/2 (unidades de x).
## Se a penetracao longitudinal e menor que a lateral, e batida de frente/traseira; senao e lateral.
##
## Forca das batidas (T-141, no espirito de Art Truck Battle, docs/REFERENCIA_ART_TRUCK_BATTLE.md §2):
##  - caminhao x caminhao de lado: quem entra na faixa do outro com forca EMPURRA o outro para a faixa vizinha
##    (o mais pesado ganha; leve demais quica de volta). Pneus de quem foi empurrado soltam fumaca (shove_t).
##  - caminhao x carro: troca de momento com restituicao; acima de THROW_MIN_DV o carro e ARREMESSADO
##    (ThrownCar: sai da linha do caminhao girando, pode quicar); o caminhao perde so a parte do momento
##    que o carro leva (12 t contra 1,5 t: ~1,5 m/s numa batida de 10 m/s). Onibus (12 t) segura muito mais.
##  - T-152, penalidade ARCADE (vale no online: e a sim): a batida no transito tambem custa uma fracao da velocidade
##    do caminhao, que cresce com a forca: de frente na traseira do carro 25..40%, raspao lateral 8..15%, veiculo
##    pesado (onibus) x PEN_HEAVY_MULT. O resultado e o MENOR entre a fisica e a penalidade (nao soma). Depois vem o
##    TRANCO (TruckSim.jolt_t, JOLT_TIME s): acelerador sem efeito e o caminhao balanca. Enquanto dura o tranco, nova
##    batida nao cobra de novo (uma penalidade por batida, mesmo com contatos em ticks seguidos).

const LEN: float = 12.0
const RESTITUTION: float = 0.25
const MIN_EVENT_DV: float = 1.0           # abaixo disso e so encostar, sem dano
const M_X: float = Track.ROAD_HALF_WIDTH_M   # metros por unidade de x
const WIDTH_ALIGNED: float = 0.1         # |dx| abaixo disso = alinhados: batida de frente/traseira
const SEPARATION_PUSH: float = 2.0        # x/s empurrando os dois para longe enquanto sobrepostos
const EVENT_COOLDOWN: float = 0.8         # s: encostar de novo no mesmo par nao repete dano antes disto
# T-141: caminhao x carro
const CAR_RESTITUTION: float = 0.45
const THROW_MIN_DV: float = 3.0           # m/s: abaixo disto o carro so e empurrado
const THROW_SIDE_BASE: float = 0.9        # x/s de deslize para fora da linha do caminhao (batida de tras)
const THROW_SIDE_PER_DV: float = 0.05     # x/s por m/s de impacto
const THROW_SPIN_PER_DV: float = 0.28     # rad/s por m/s de impacto
const THROW_HOP_FROM_DV: float = 9.0      # m/s: acima disto o carro tira as rodas do chao
const THROW_HOP_PER_DV: float = 0.35      # m/s para cima por m/s acima do limite
const THROW_HOP_MAX: float = 3.5
const THROW_MAX_MASS: float = 3000.0      # mais pesado que isto (onibus) e empurrado, nao arremessado
const THROW_TIME: float = 1.3             # s fora de controle (+ THROW_TIME_PER_DV por m/s)
const THROW_TIME_PER_DV: float = 0.05
# T-141: caminhao x caminhao de lado
const SHOVE_DV: float = 2.5               # m/s laterais: batida assim empurra o outro para a faixa vizinha
const SHOVE_MASS_RATIO: float = 0.75      # quem empurra precisa de 75% da massa do outro; senao quica de volta
const SHOVE_SMOKE_S: float = 0.9          # s de fumaca nos pneus de quem foi empurrado
const BOUNCE_LAT_VEL: float = 0.35        # x/s de volta para quem quicou
# T-152: penalidade arcade do caminhao na batida com o transito (fracao da velocidade antes da batida)
const PEN_FRONT_MIN: float = 0.25         # de frente na traseira do carro, batida fraca
const PEN_FRONT_MAX: float = 0.40         # ... batida forte
const PEN_FRONT_DV_SOFT: float = 2.0      # m/s de diferenca: ate aqui vale a minima
const PEN_FRONT_DV_HARD: float = 12.0     # m/s: daqui para cima vale a maxima
const PEN_SIDE_MIN: float = 0.08          # raspao lateral fraco
const PEN_SIDE_MAX: float = 0.15          # ... forte
const PEN_SIDE_DV_SOFT: float = 1.5
const PEN_SIDE_DV_HARD: float = 6.0
const PEN_HEAVY_MASS: float = THROW_MAX_MASS   # acima disto (onibus, caminhoes do transito) a penalidade e maior
const PEN_HEAVY_MULT: float = 1.35        # onibus: de frente 34..54%, de lado 11..20%
const PEN_MAX: float = 0.6                # teto de seguranca da fracao
const JOLT_TIME: float = 0.6              # s de tranco: acelerador sem efeito, caminhao balanca

var _contacts: Dictionary = {}            # "i:j" -> true enquanto encostados
var _clock: float = 0.0
var _last_event: Dictionary = {}          # "i:j" -> instante do ultimo dano


## Resolve todos os pares de caminhoes. Devolve a lista de eventos novos. `track` (opcional) recusa empurrar
## alguem para dentro de uma faixa fechada por evento de pista.
func resolve_trucks(trucks: Array[TruckSim], dt: float, track: Track = null) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_clock += dt
	for i in trucks.size():
		for j in range(i + 1, trucks.size()):
			var key: String = "%d:%d" % [i, j]
			var ev: Dictionary = _pair(trucks[i], trucks[j], i, j, key, dt, track)
			if not ev.is_empty():
				events.append(ev)
	return events


func _pair(a: TruckSim, b: TruckSim, ia: int, ib: int, key: String, dt: float, track: Track) -> Dictionary:
	var dx: float = b.x - a.x
	var pen_x: float = (TruckSim.WIDTH_X - absf(dx)) * M_X
	var pen_z: float = minf(a.z + a.length, b.z + b.length) - maxf(a.z, b.z)
	if pen_x <= 0.0 or pen_z <= 0.0:
		_contacts.erase(key)
		return {}
	var longitudinal: bool = pen_z < pen_x or absf(dx) < WIDTH_ALIGNED
	var started: bool = not _contacts.has(key)
	_contacts[key] = true
	if started and _clock - float(_last_event.get(key, -99.0)) < EVENT_COOLDOWN:
		started = false                   # mesmo par encostando de novo logo depois: so empurra, sem novo dano
	if started:
		a.cargo_touch()                   # qualquer encostao ja custa um pouco do premio
		b.cargo_touch()
	var ev: Dictionary = {}
	if longitudinal:
		var back: TruckSim = a if a.z < b.z else b       # o de tras bate com a frente
		var front: TruckSim = b if back == a else a
		var dv: float = back.speed - front.speed
		if started and dv > MIN_EVENT_DV:
			ev = _event(a, b, ia, ib, "front" if back == a else "rear", "rear" if back == a else "front", dv)
		# trocas de momento (colisao parcialmente elastica)
		if dv > 0.0:
			var m1: float = back.mass
			var m2: float = front.mass
			var v1: float = back.speed
			var v2: float = front.speed
			back.speed = maxf((m1 * v1 + m2 * v2 - m2 * RESTITUTION * (v1 - v2)) / (m1 + m2), 0.0)
			front.speed = maxf((m1 * v1 + m2 * v2 + m1 * RESTITUTION * (v1 - v2)) / (m1 + m2), 0.0)
		# separa para nao ficarem presos: o mais leve se move mais
		var total_m: float = back.mass + front.mass
		back.z -= pen_z * front.mass / total_m
		front.z += pen_z * back.mass / total_m
	else:
		var left: TruckSim = a if a.x < b.x else b       # o de menor x tem o outro a sua direita
		var right: TruckSim = b if left == a else a
		var dv_lat: float = absf(left.lateral_vel - right.lateral_vel) + 0.15 * absf(left.speed - right.speed)
		if started and dv_lat * M_X > MIN_EVENT_DV:
			ev = _event(a, b, ia, ib, "right" if left == a else "left", "left" if left == a else "right", dv_lat * M_X)
			if dv_lat * M_X > SHOVE_DV:
				var res: Array = _shove(left, right, track)
				var pushed: TruckSim = res[0]
				var bounced: TruckSim = res[1]
				ev["shoved"] = (ia if pushed == a else ib) if pushed != null else -1
				ev["bounced"] = (ia if bounced == a else ib) if bounced != null else -1
		# empurrao lateral proporcional ao peso do OUTRO: o mais leve vai mais longe
		var total: float = left.mass + right.mass
		var push: float = pen_x / M_X
		left.x -= push * (right.mass / total)
		right.x += push * (left.mass / total)
		var imp: float = SEPARATION_PUSH * (1.0 + minf(dv_lat, 2.0))
		left.lateral_vel -= imp * (right.mass / total) * dt * 4.0
		right.lateral_vel += imp * (left.mass / total) * dt * 4.0
	return ev


## Batida lateral forte: quem vinha entrando na faixa do outro (mais momento lateral) empurra o outro uma faixa
## para o lado; se for leve demais, ou o outro estiver encostado na mureta / numa faixa fechada, quica de volta.
## Devolve [empurrado ou null, quicou ou null].
func _shove(left: TruckSim, right: TruckSim, track: Track) -> Array:
	var att_l: float = maxf(left.lateral_vel, 0.0) * left.mass
	var att_r: float = maxf(-right.lateral_vel, 0.0) * right.mass
	if att_l <= 0.0 and att_r <= 0.0:
		return [null, null]
	var pusher: TruckSim = left if att_l >= att_r else right
	var pushed: TruckSim = right if pusher == left else left
	var dir: int = 1 if pusher == left else -1      # para onde o empurrado vai
	if pusher.mass >= SHOVE_MASS_RATIO * pushed.mass:
		var nl: int = pushed.lane + dir
		var ok: bool = nl >= Lanes.SHOULDER_L and nl <= Lanes.SHOULDER_R
		if ok and track != null and pushed.lane_closed_ahead(nl, track):
			ok = false
		if ok:
			pushed.lane = nl
			pushed.lane_change_time = TruckSim.LANE_CHANGE_TIME
			pushed.signal_dir = 0
			pushed.signal_time = 0.0
			pushed.shove_t = SHOVE_SMOKE_S
			pushed.shoved += 1
			return [pushed, null]
	pusher.lane = Lanes.nearest(pusher.x - dir * 0.2)     # volta para a faixa do proprio lado
	pusher.lateral_vel = -dir * BOUNCE_LAT_VEL
	pusher.shove_t = SHOVE_SMOKE_S * 0.6
	return [null, pusher]


func _event(a: TruckSim, b: TruckSim, ia: int, ib: int, zone_a: String, zone_b: String, dv: float) -> Dictionary:
	a.cargo_hit(dv)
	b.cargo_hit(dv)
	_last_event["%d:%d" % [ia, ib]] = _clock
	var dmg_a: float = DamageModel.impact_damage(dv, b.mass)
	var dmg_b: float = DamageModel.impact_damage(dv, a.mass)
	var broken_a: Array[String] = DamageModel.apply_impact(a, zone_a, dmg_a)
	var broken_b: Array[String] = DamageModel.apply_impact(b, zone_b, dmg_b)
	return {"type": "truck", "a": ia, "b": ib, "zone_a": zone_a, "zone_b": zone_b, "force": dv,
		"damage_a": dmg_a, "damage_b": dmg_b, "broken_a": broken_a, "broken_b": broken_b}


## Caminhao contra carro do transito. Massa, comprimento e largura vem do tipo do veiculo (TrafficSim.Kind).
## Batida forte arremessa o carro (ThrownCar); o caminhao leva dano na frente (ou na lateral).
func resolve_traffic(truck: TruckSim, truck_id: int, traffic: TrafficSim) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for i in traffic.cars.size():
		var c: TrafficSim.Car = traffic.cars[i]
		var cz: float = c.z                 # rear (m), length (m), center x and width (x units) of the car body
		var clen: float = c.length
		var cx: float = c.x
		var cw: float = c.width_x
		if c.wrecked:                       # T-183: the crashed car (turned) uses its real footprint on the road
			var fp: Rect2 = Wreck.footprint(c)
			cz = fp.position.x
			clen = fp.size.x
			cx = fp.get_center().y
			cw = fp.size.y
		var half: float = (TruckSim.WIDTH_X + cw) * 0.5
		var key: String = "t%d:c%d" % [truck_id, i]
		var pen_x: float = (half - absf(cx - truck.x)) * M_X
		var pen_z: float = minf(truck.z + truck.length, cz + clen) - maxf(truck.z, cz)
		if pen_x <= 0.0 or pen_z <= 0.0 or c.y > 1.2:     # pulando por cima da altura do para-choque: passa
			_contacts.erase(key)
			continue
		var started: bool = not _contacts.has(key)
		_contacts[key] = true
		if started:
			truck.cargo_touch()
		var rear_hit: bool = (pen_z < pen_x or absf(cx - truck.x) < WIDTH_ALIGNED) and truck.z < cz
		var side: float = signf(cx - truck.x)
		if side == 0.0:
			side = 1.0 if i % 2 == 0 else -1.0             # alinhados: lado fixo pelo indice (deterministico)
		var toward: float = maxf(truck.lateral_vel * side, 0.0)   # x/s do caminhao entrando no carro
		var dv: float = maxf(truck.speed - c.speed, 0.0) if rear_hit else toward * M_X + 0.2 * absf(truck.speed - c.speed)
		var thrown: bool = false
		var speed_before: float = truck.speed
		var pen: float = 0.0
		var ev: Dictionary = {}
		if started and dv > MIN_EVENT_DV:
			var zone: String = "front" if rear_hit else ("right" if cx > truck.x else "left")
			var dmg: float = DamageModel.impact_damage(dv, c.mass)
			var broken: Array[String] = DamageModel.apply_impact(truck, zone, dmg)
			truck.cargo_hit(dv)
			traffic.hits += 1
			thrown = dv >= THROW_MIN_DV and c.mass <= THROW_MAX_MASS
			if not truck.jolted():                      # T-152: uma penalidade por batida (o tranco e a recarga)
				pen = penalty_fraction(rear_hit, dv, c.mass)
				truck.jolt_t = JOLT_TIME
				truck.jolt_side = 0 if rear_hit else (1 if cx > truck.x else -1)
				truck.jolts += 1
			ev = {"type": "traffic", "truck": truck_id, "car": i, "zone": zone, "force": dv, "wreck": c.wrecked,
				"damage": dmg, "broken": broken, "thrown": thrown, "car_kind": c.kind, "penalty": pen,
				"speed_before": speed_before, "speed_after": speed_before}
			events.append(ev)
		var share_car: float = truck.mass / (truck.mass + c.mass)    # quanto do impulso fica no carro
		var share_truck: float = c.mass / (truck.mass + c.mass)
		if rear_hit:
			var dvv: float = truck.speed - c.speed
			if dvv > 0.0:
				truck.speed = maxf(truck.speed - (1.0 + CAR_RESTITUTION) * share_truck * dvv, 0.0)
				var new_car: float = c.speed + (1.0 + CAR_RESTITUTION) * share_car * dvv
				if thrown:
					var lat: float = side * (THROW_SIDE_BASE + THROW_SIDE_PER_DV * dvv) * share_car
					traffic.throw_car(c, new_car, lat, -side * THROW_SPIN_PER_DV * dvv * share_car, _hop(dvv, c.mass, share_car),
						THROW_TIME + THROW_TIME_PER_DV * dvv)
				else:
					c.speed = maxf(c.speed, new_car)
			c.z += maxf(truck.z + truck.length - cz, 0.0)        # nunca fica dentro da frente do caminhao
		else:
			if thrown:
				var lever: float = clampf(((truck.z + truck.length * 0.5) - (cz + clen * 0.5)) / maxf(c.length, 1.0), -1.0, 1.0)
				var lat2: float = side * (toward * (1.0 + CAR_RESTITUTION) * share_car + 0.25)
				traffic.throw_car(c, c.speed, lat2, -side * lever * THROW_SPIN_PER_DV * dv * 1.5 * share_car,
					_hop(dv, c.mass, share_car) * 0.5, THROW_TIME + THROW_TIME_PER_DV * dv)
				truck.lateral_vel -= side * toward * (1.0 + CAR_RESTITUTION) * share_truck
			c.x += side * pen_x / M_X * 0.8
			truck.x -= side * pen_x / M_X * 0.2
		if pen > 0.0:                                   # T-152: o menor entre a fisica e a penalidade arcade
			truck.speed = minf(truck.speed, speed_before * (1.0 - pen))
		if not ev.is_empty():
			ev["speed_after"] = truck.speed
	return events


## T-152: fracao da velocidade que o caminhao perde na batida com um veiculo do transito de massa `car_mass`.
## `front` = de frente na traseira dele (senao, raspao lateral); cresce com a forca `dv` (m/s) entre as faixas.
static func penalty_fraction(front: bool, dv: float, car_mass: float) -> float:
	var p: float
	if front:
		p = lerpf(PEN_FRONT_MIN, PEN_FRONT_MAX, clampf(inverse_lerp(PEN_FRONT_DV_SOFT, PEN_FRONT_DV_HARD, dv), 0.0, 1.0))
	else:
		p = lerpf(PEN_SIDE_MIN, PEN_SIDE_MAX, clampf(inverse_lerp(PEN_SIDE_DV_SOFT, PEN_SIDE_DV_HARD, dv), 0.0, 1.0))
	if car_mass > PEN_HEAVY_MASS:
		p *= PEN_HEAVY_MULT
	return minf(p, PEN_MAX)


## Pulo do carro arremessado (m/s para cima): so batida forte e veiculo leve.
static func _hop(dv: float, car_mass: float, share_car: float) -> float:
	if car_mass > THROW_MAX_MASS:
		return 0.0
	return clampf((dv - THROW_HOP_FROM_DV) * THROW_HOP_PER_DV, 0.0, THROW_HOP_MAX) * share_car
