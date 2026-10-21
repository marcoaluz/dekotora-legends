class_name TrafficLook
extends RefCounted
## O que um carro do transito enxerga em volta (TrafficSim): faixa livre para entrar, quem esta a frente mais lento,
## buzina de caminhao logo atras e caminhao ao lado. So leitura (nao muda nada). Separado da TrafficSim (T-183).
## Carro acidentado (Wreck) conta pelo corpo girado inteiro (Wreck.footprint), nao pela faixa em que estava.


## Faixa `lane` livre para o carro `ignore` ocupar a partir de `z`: nenhuma carroceria a menos de TrafficSim.LANE_GAP.
static func lane_free(cars: Array[TrafficSim.Car], lane: int, z: float, ignore: TrafficSim.Car) -> bool:
	var length: float = ignore.length if ignore != null else TrafficSim.CAR_LEN
	var half: float = (ignore.width_x if ignore != null else TrafficSim.CAR_WIDTH_X) * 0.5
	for o in cars:
		if o == ignore:
			continue
		if o.wrecked:                    # T-183: acidentado ocupa as faixas que o corpo (girado) cobre
			var r: Rect2 = Wreck.footprint(o)
			if Wreck.overlaps_x(r, TrafficSim.LANES[lane], half) and maxf(r.position.x - (z + length), z - r.end.x) < TrafficSim.LANE_GAP:
				return false
		elif o.lane == lane:
			var gap: float = maxf(o.z - (z + length), z - (o.z + o.length))
			if gap < TrafficSim.LANE_GAP:
				return false
	return true


## Veiculo (carro ou caminhao) mais lento logo a frente de `c` na mesma linha, perto o bastante para
## precisar frear (distancia de frenagem + TrafficSim.FOLLOW_GAP). {} se livre.
static func blocker(cars: Array[TrafficSim.Car], c: TrafficSim.Car, trucks: Array) -> Dictionary:
	var best: Dictionary = {}
	var nose: float = c.z + c.length
	for o in cars:
		if o == c:
			continue
		if o.wrecked:                    # T-183: parado e girado; o corpo inteiro conta
			var r: Rect2 = Wreck.footprint(o)
			if Wreck.overlaps_x(r, c.x, c.width_x * 0.5):
				best = _closer(best, r.position.x - nose, o.speed, c.speed)
		elif absf(o.x - c.x) < (o.width_x + c.width_x) * 0.5:
			best = _closer(best, o.z - nose, o.speed, c.speed)
	for t in trucks:
		var tr: TruckSim = t
		if absf(tr.x - c.x) < (TruckSim.WIDTH_X + c.width_x) * 0.5:
			best = _closer(best, tr.z - nose, tr.speed, c.speed)
	return best


static func _closer(best: Dictionary, gap: float, other_speed: float, my_speed: float) -> Dictionary:
	if gap <= -1.0 or gap > TrafficSim.LOOK_AHEAD or other_speed >= my_speed + 0.5 and gap > TrafficSim.FOLLOW_GAP:
		return best
	var dv: float = maxf(my_speed - other_speed, 0.0)
	if gap > dv * dv / (2.0 * TrafficSim.BRAKE) + TrafficSim.FOLLOW_GAP:
		return best
	if best.is_empty() or gap < float(best["gap"]):
		return {"gap": gap, "speed": other_speed}
	return best


## Algum caminhao buzinando logo atras de `c`, na mesma linha (ate TrafficSim.HORN_RANGE da traseira do carro ao nariz dele)?
static func honked(c: TrafficSim.Car, trucks: Array) -> bool:
	for t in trucks:
		var tr: TruckSim = t
		if tr.horn and absf(tr.x - c.x) < (TruckSim.WIDTH_X + c.width_x) * 0.5:
			var gap: float = c.z - (tr.z + tr.length)
			if gap > -1.0 and gap < TrafficSim.HORN_RANGE:
				return true
	return false


## Algum caminhao ocupa a faixa `lane` ao lado de `c` (com folga de 6 m na frente e atras)?
static func truck_beside(lane: int, c: TrafficSim.Car, trucks: Array) -> bool:
	for t in trucks:
		var tr: TruckSim = t
		var beside_x: bool = absf(tr.x - TrafficSim.LANES[lane]) < (TruckSim.WIDTH_X + c.width_x) * 0.5
		if beside_x and tr.z < c.z + c.length + 6.0 and tr.z + tr.length + 6.0 > c.z:
			return true
	return false
