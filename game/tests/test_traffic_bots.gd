extends TestCase
## Testes de transito (P30) e bots (P31).


func test_traffic_cars_slower_than_trucks_and_in_lanes() -> void:
	var t := TrafficSim.new(42, TrafficSim.Density.NORMAL)
	check_eq(t.cars.size(), TrafficSim.COUNT_BY_DENSITY[TrafficSim.Density.NORMAL], "quantidade pela densidade")
	for c in t.cars:
		check(c.speed < EngineModel.MAX_SPEED, "carro mais lento que o caminhao")
		check(c.lane >= 0 and c.lane < TrafficSim.LANES.size(), "faixa valida")


func test_traffic_density_levels() -> void:
	var l := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	var h := TrafficSim.new(1, TrafficSim.Density.HEAVY)
	check(h.cars.size() > l.cars.size(), "pesada tem mais carros que leve")


func test_traffic_deterministic() -> void:
	var a := TrafficSim.new(7)
	var b := TrafficSim.new(7)
	for i in 600:
		a.step(1.0 / 30.0, 100.0, 100.0)
		b.step(1.0 / 30.0, 100.0, 100.0)
	for i in a.cars.size():
		check_near(a.cars[i].z, b.cars[i].z, 0.0001, "mesma semente, mesmo resultado")


func test_traffic_respawns_ahead() -> void:
	var t := TrafficSim.new(3)
	for i in 30 * 40:
		t.step(1.0 / 30.0, 2000.0, 2000.0)
	for c in t.cars:
		check(c.z > 2000.0 - TrafficSim.DESPAWN_BEHIND - 30.0, "carros nao ficam muito para tras do grupo")


func test_truck_hits_slow_car() -> void:
	var track := Track.new()
	track.add_section(2000.0, 0.0)
	var sim := RaceSim.new(track, TrafficSim.Density.LIGHT)
	var i := sim.add_truck(0.0, 0.0)
	var car: TrafficSim.Car = sim.traffic.cars[0]
	car.z = 8.0
	car.x = 0.0
	car.lane = 1
	car.speed = 10.0
	sim.trucks[i].speed = 30.0
	sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
	sim.step()
	check(sim.traffic.hits >= 1, "bateu no carro")
	check(sim.trucks[i].speed < 30.0, "perdeu velocidade na batida")
	check(car.speed > 10.0, "o carro foi acelerado pelo empurrao")


func test_three_bots_finish_track_staying_on_road() -> void:
	var sim := RaceSim.new(Track.make_test_track(), TrafficSim.Density.NORMAL)
	var bots: Array[BotDriver] = []
	var diffs: Array[int] = [BotDriver.Difficulty.EASY, BotDriver.Difficulty.NORMAL, BotDriver.Difficulty.HARD]
	var xs: Array[float] = [-0.75, -0.25, 0.25]
	for k in 3:
		sim.add_truck(0.0, xs[k])
		bots.append(BotDriver.new(diffs[k], 10 + k, xs[k]))
	var steps: int = 0
	while steps < 30 * 200:
		var done: bool = true
		for k in 3:
			if not sim.finished(k):
				done = false
			sim.set_command(k, bots[k].command_for(sim, k, RaceSim.FIXED_DT))
		if done:
			break
		sim.step()
		steps += 1
	for k in 3:
		check(sim.finished(k), "bot %d terminou a pista (z=%.0f)" % [k, sim.trucks[k].z])
		check(bots[k].out_of_road_count <= 2, "bot %d saiu da pista %d vezes (max 2)" % [k, bots[k].out_of_road_count])
