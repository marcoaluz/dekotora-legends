extends TestCase
## Tipos de veiculo do transito (T-124): onibus longo/lento/pesado, esportivo raro/rapido, fila atras
## de quem e mais lento e hitbox pelo tamanho do tipo.


func test_kinds_fixed_by_index_and_present() -> void:
	var h := TrafficSim.new(3, TrafficSim.Density.HEAVY)
	var buses: int = 0
	var sports: int = 0
	for i in h.cars.size():
		var c: TrafficSim.Car = h.cars[i]
		check_eq(c.kind, TrafficSim.kind_for_index(i), "tipo so depende do indice")
		check_near(c.length, TrafficSim.KIND_LEN[c.kind], 0.001, "comprimento do tipo")
		buses += 1 if c.kind == TrafficSim.Kind.BUS else 0
		sports += 1 if c.kind == TrafficSim.Kind.SPORT else 0
	check(buses >= 1 and buses <= 2, "transito pesado tem 1 ou 2 onibus (%d)" % buses)
	check(sports >= 1 and sports <= 3, "transito pesado tem poucos esportivos (%d)" % sports)
	var l := TrafficSim.new(3, TrafficSim.Density.LIGHT)
	check_eq(l.cars[5].kind, TrafficSim.Kind.BUS, "ate o transito leve tem um onibus")


func test_speed_ranges_by_kind() -> void:
	for seed_ in [1, 2, 3, 4, 5]:
		var t := TrafficSim.new(seed_, TrafficSim.Density.HEAVY)
		for c in t.cars:
			check(c.cruise >= TrafficSim.KIND_SPEED_MIN[c.kind] - 0.001 and c.cruise <= TrafficSim.KIND_SPEED_MAX[c.kind] + 0.001,
				"velocidade dentro da faixa do tipo")
			check(c.cruise < EngineModel.MAX_SPEED, "todo o transito e mais lento que o caminhao no limite")
	check(TrafficSim.KIND_SPEED_MAX[TrafficSim.Kind.BUS] < TrafficSim.KIND_SPEED_MAX[TrafficSim.Kind.CAR], "onibus e lento")
	check(TrafficSim.KIND_SPEED_MIN[TrafficSim.Kind.SPORT] > TrafficSim.KIND_SPEED_MAX[TrafficSim.Kind.CAR], "esportivo e o mais rapido")


## Monta um transito controlado: so os carros dados, em z/faixa/velocidade fixos.
func _setup(t: TrafficSim, specs: Array) -> void:
	t.cars.clear()
	for sp in specs:
		var c := TrafficSim.Car.new()
		c.kind = int(sp[0])
		c.length = TrafficSim.KIND_LEN[c.kind]
		c.width_x = TrafficSim.KIND_WIDTH_X[c.kind]
		c.mass = TrafficSim.KIND_MASS[c.kind]
		c.z = float(sp[1])
		c.lane = int(sp[2])
		c.x = TrafficSim.LANES[c.lane]
		c.cruise = float(sp[3])
		c.speed = c.cruise
		c.timer = 999.0
		t.cars.append(c)


func test_car_queues_behind_slow_bus_when_boxed_in() -> void:
	var t := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	# onibus a frente na faixa do meio, carro rapido atras; as outras faixas ocupadas ao lado
	_setup(t, [[TrafficSim.Kind.BUS, 100.0, 1, 14.0], [TrafficSim.Kind.CAR, 80.0, 1, 25.0],
		[TrafficSim.Kind.BUS, 80.0, 0, 14.0], [TrafficSim.Kind.BUS, 80.0, 2, 14.0]])
	var bus: TrafficSim.Car = t.cars[0]
	var car: TrafficSim.Car = t.cars[1]
	for k in 30 * 10:
		t.step(1.0 / 30.0, 200.0, 0.0)
		check(car.z + car.length <= bus.z + 0.5, "o carro nao atravessa o onibus")
	check_eq(car.lane, 1, "sem faixa livre, segue na mesma")
	check_near(car.speed, bus.speed, 0.5, "anda na velocidade do onibus")


func test_car_overtakes_slow_bus_when_lane_free() -> void:
	var t := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	_setup(t, [[TrafficSim.Kind.BUS, 100.0, 1, 14.0], [TrafficSim.Kind.CAR, 80.0, 1, 25.0]])
	var car: TrafficSim.Car = t.cars[1]
	for k in 30 * 10:
		t.step(1.0 / 30.0, 200.0, 0.0)
	check(car.lane != 1, "trocou de faixa para passar o onibus")
	check(car.z > t.cars[0].z + t.cars[0].length, "passou o onibus")


func test_bus_hitbox_is_long_and_heavy() -> void:
	var track := Track.new()
	track.add_section(2000.0, 0.0)
	var results: Array[float] = []
	for kind in [TrafficSim.Kind.CAR, TrafficSim.Kind.BUS]:
		var sim := RaceSim.new(track, TrafficSim.Density.LIGHT)
		var i := sim.add_truck(0.0, 0.0)
		_setup(sim.traffic, [[kind, 11.0, 1, 10.0]])
		sim.trucks[i].speed = 30.0
		sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
		sim.step()
		check(sim.traffic.hits >= 1, "bateu na traseira (tipo %d)" % kind)
		results.append(sim.trucks[i].speed)
	check(results[1] < results[0], "o onibus pesado segura mais o caminhao (%.1f < %.1f)" % [results[1], results[0]])
	# a traseira de um onibus a 2 m da frente do caminhao, mas a frente do onibus passa do caminhao: so com 13 m
	var sim2 := RaceSim.new(track, TrafficSim.Density.LIGHT)
	var j := sim2.add_truck(20.0, 0.0)
	_setup(sim2.traffic, [[TrafficSim.Kind.BUS, 8.0, 1, 30.0]])
	sim2.trucks[j].speed = 30.0
	sim2.collision.resolve_traffic(sim2.trucks[j], j, sim2.traffic)
	check(sim2.trucks[j].cargo_penalty > 0.0, "onibus de 13 m encosta num caminhao 12 m a frente da traseira dele")
	var sim3 := RaceSim.new(track, TrafficSim.Density.LIGHT)
	var k3 := sim3.add_truck(20.0, 0.0)
	_setup(sim3.traffic, [[TrafficSim.Kind.CAR, 8.0, 1, 30.0]])
	sim3.collision.resolve_traffic(sim3.trucks[k3], k3, sim3.traffic)
	check_near(sim3.trucks[k3].cargo_penalty, 0.0, 0.0001, "um carro de 4,5 m no mesmo lugar nao encosta")
