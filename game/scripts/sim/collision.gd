class_name Collision
extends RefCounted
## Contato entre caminhoes e entre caminhao e transito. Decide zona atingida, impulso (empurrao
## proporcional ao peso) e dano. So numeros: nenhum no, nenhum som. Os efeitos saem como eventos.
##
## Geometria: cada caminhao ocupa z .. z+LEN (z = traseira) e |x - x0| < WIDTH_X/2 (unidades de x).
## Se a penetracao longitudinal e menor que a lateral, e batida de frente/traseira; senao e lateral.

const LEN: float = 12.0
const RESTITUTION: float = 0.25
const MIN_EVENT_DV: float = 1.0           # abaixo disso e so encostar, sem dano
const M_X: float = Track.ROAD_HALF_WIDTH_M   # metros por unidade de x
const WIDTH_ALIGNED: float = 0.1         # |dx| abaixo disso = alinhados: batida de frente/traseira
const SEPARATION_PUSH: float = 2.0        # x/s empurrando os dois para longe enquanto sobrepostos

const EVENT_COOLDOWN: float = 0.8         # s: encostar de novo no mesmo par nao repete dano antes disto

var _contacts: Dictionary = {}            # "i:j" -> true enquanto encostados
var _clock: float = 0.0
var _last_event: Dictionary = {}          # "i:j" -> instante do ultimo dano


## Resolve todos os pares de caminhoes. Devolve a lista de eventos novos.
func resolve_trucks(trucks: Array[TruckSim], dt: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	_clock += dt
	for i in trucks.size():
		for j in range(i + 1, trucks.size()):
			var key: String = "%d:%d" % [i, j]
			var ev: Dictionary = _pair(trucks[i], trucks[j], i, j, key, dt)
			if not ev.is_empty():
				events.append(ev)
	return events


func _pair(a: TruckSim, b: TruckSim, ia: int, ib: int, key: String, dt: float) -> Dictionary:
	var dx: float = b.x - a.x
	var pen_x: float = (TruckSim.WIDTH_X - absf(dx)) * M_X
	var pen_z: float = minf(a.z + LEN, b.z + LEN) - maxf(a.z, b.z)
	if pen_x <= 0.0 or pen_z <= 0.0:
		_contacts.erase(key)
		return {}
	var longitudinal: bool = pen_z < pen_x or absf(dx) < WIDTH_ALIGNED
	var started: bool = not _contacts.has(key)
	_contacts[key] = true
	if started and _clock - float(_last_event.get(key, -99.0)) < EVENT_COOLDOWN:
		started = false                   # mesmo par encostando de novo logo depois: so empurra, sem novo dano
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
		# empurrao lateral proporcional ao peso do OUTRO: o mais leve vai mais longe
		var total: float = left.mass + right.mass
		var push: float = pen_x / M_X
		left.x -= push * (right.mass / total)
		right.x += push * (left.mass / total)
		var imp: float = SEPARATION_PUSH * (1.0 + minf(dv_lat, 2.0))
		left.lateral_vel -= imp * (right.mass / total) * dt * 4.0
		right.lateral_vel += imp * (left.mass / total) * dt * 4.0
	return ev


func _event(a: TruckSim, b: TruckSim, ia: int, ib: int, zone_a: String, zone_b: String, dv: float) -> Dictionary:
	_last_event["%d:%d" % [ia, ib]] = _clock
	var dmg_a: float = DamageModel.impact_damage(dv, b.mass)
	var dmg_b: float = DamageModel.impact_damage(dv, a.mass)
	var broken_a: Array[String] = DamageModel.apply_impact(a, zone_a, dmg_a)
	var broken_b: Array[String] = DamageModel.apply_impact(b, zone_b, dmg_b)
	return {"type": "truck", "a": ia, "b": ib, "zone_a": zone_a, "zone_b": zone_b, "force": dv,
		"damage_a": dmg_a, "damage_b": dmg_b, "broken_a": broken_a, "broken_b": broken_b}


## Caminhao contra carro do transito. Carro: 1500 kg. O carro e empurrado/acelerado e some do
## caminho; o caminhao leva dano na frente (ou na lateral).
func resolve_traffic(truck: TruckSim, truck_id: int, traffic: TrafficSim) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var car_mass: float = 1500.0
	var half: float = (TruckSim.WIDTH_X + TrafficSim.CAR_WIDTH_X) * 0.5
	for i in traffic.cars.size():
		var c: TrafficSim.Car = traffic.cars[i]
		var key: String = "t%d:c%d" % [truck_id, i]
		var pen_x: float = (half - absf(c.x - truck.x)) * M_X
		var pen_z: float = minf(truck.z + LEN, c.z + TrafficSim.CAR_LEN) - maxf(truck.z, c.z)
		if pen_x <= 0.0 or pen_z <= 0.0:
			_contacts.erase(key)
			continue
		var started: bool = not _contacts.has(key)
		_contacts[key] = true
		var rear_hit: bool = (pen_z < pen_x or absf(c.x - truck.x) < WIDTH_ALIGNED) and truck.z < c.z
		var dv: float = maxf(truck.speed - c.speed, 0.0) if rear_hit else absf(truck.lateral_vel) * M_X + 0.2 * absf(truck.speed - c.speed)
		if started and dv > MIN_EVENT_DV:
			var zone: String = "front" if rear_hit else ("right" if c.x > truck.x else "left")
			var dmg: float = DamageModel.impact_damage(dv, car_mass)
			var broken: Array[String] = DamageModel.apply_impact(truck, zone, dmg)
			traffic.hits += 1
			events.append({"type": "traffic", "truck": truck_id, "car": i, "zone": zone, "force": dv,
				"damage": dmg, "broken": broken})
		if rear_hit:
			var m: float = truck.mass
			var v: float = (m * truck.speed + car_mass * c.speed) / (m + car_mass)
			truck.speed = minf(truck.speed, maxf(v, c.speed * 0.9))
			c.speed = maxf(c.speed, v + 2.0)
		else:
			var side: float = 1.0 if c.x > truck.x else -1.0
			c.x += side * pen_x / M_X * 0.8
			truck.x -= side * pen_x / M_X * 0.2
	return events
