extends TestCase
## Rival de verdade (ATB-1): trava atras do transito, anda colado ao lado, espelha a seta e empurra, sem borracha.

const DT: float = RaceSim.FIXED_DT


func _straight(len_m: float = 8000.0, traffic: int = -1) -> RaceSim:
	var t := Track.new()
	t.add_section(len_m, 0.0)
	return RaceSim.new(t, traffic, 77)


## Caminhao "humano" parado numa faixa, a 30 m/s constantes.
func _human(sim: RaceSim, z: float, lane: int, speed: float = 30.0) -> int:
	var h := sim.add_truck(z, Lanes.X[lane])
	sim.trucks[h].speed = speed
	return h


func _hold(sim: RaceSim, h: int, speed: float) -> void:
	var t: TruckSim = sim.trucks[h]
	sim.set_command(h, Commands.make(0.0, 0.7 if t.speed < speed else 0.0, 0.0))


func test_no_rubber_band_speed_is_independent_of_the_player() -> void:
	var speeds: Array[float] = []
	for player_z in [600.0, -600.0]:
		var sim := _straight()
		var bot := sim.add_truck(0.0, 0.0)
		sim.trucks[bot].is_bot = true
		_human(sim, player_z, 1, 20.0)
		var drv := BotDriver.new(BotDriver.Difficulty.HARD, 5, 0.0)
		for n in 30 * 25:
			sim.set_command(bot, drv.command_for(sim, bot, DT))
			sim.set_command(1, Commands.make(0.0, 0.4, 0.0))
			sim.step()
		speeds.append(sim.trucks[bot].speed)
	check_near(speeds[0], speeds[1], 0.01, "o bot nao muda de ritmo por estar na frente ou atras do jogador")
	var vmax: float = EngineModel.MAX_SPEED * BotDriver.SPEED_FRACTION[BotDriver.Difficulty.HARD]
	check(speeds[0] <= vmax + 0.6, "e nunca passa do teto da propria dificuldade (%.1f <= %.1f)" % [speeds[0], vmax])


func test_fast_rival_gets_stuck_behind_traffic() -> void:
	# carro lento fechando as 3 faixas a frente: o rival freia ate a velocidade dos carros e demora a sair
	var sim := _straight(8000.0, TrafficSim.Density.LIGHT)
	sim.traffic.cars.clear()
	for k in 3:
		var c := TrafficSim.Car.new()
		c.z = 160.0
		c.lane = k
		c.x = TrafficSim.LANES[k]
		c.speed = 16.0
		c.timer = 999.0
		sim.traffic.cars.append(c)
	var bot := sim.add_truck(0.0, 0.0)
	sim.trucks[bot].speed = 30.0
	var drv := BotDriver.new(BotDriver.Difficulty.HARD, 5, 0.0)
	var slowest: float = 99.0
	for n in 30 * 12:
		sim.set_command(bot, drv.command_for(sim, bot, DT))
		sim.step()
		if sim.trucks[bot].z > 100.0:
			slowest = minf(slowest, sim.trucks[bot].speed)
	check(slowest < 20.0, "trava atras do transito: caiu para %.1f m/s" % slowest)


func test_rival_rides_alongside_and_pushes() -> void:
	var sim := _straight()
	var h := _human(sim, 0.0, Lanes.CENTER, 30.0)
	var bot := sim.add_truck(-6.0, Lanes.X[Lanes.FIRST])
	sim.trucks[bot].is_bot = true
	sim.trucks[bot].speed = 30.0
	var drv := BotDriver.new(BotDriver.Difficulty.HARD, 11, Lanes.X[Lanes.FIRST])
	var near_frames: int = 0
	var frames: int = 30 * 25
	var side_hits: int = 0
	for n in frames:
		_hold(sim, h, 30.0)
		sim.set_command(bot, drv.command_for(sim, bot, DT))
		sim.step()
		if absf(sim.trucks[bot].z - sim.trucks[h].z) < 20.0:
			near_frames += 1
		for e in sim.drain_events():
			if String(e["type"]) == "truck":
				side_hits += 1
	check(drv.duel_count >= 1, "abriu duelo (%d)" % drv.duel_count)
	check(near_frames > frames * 0.6, "anda colado ao lado do jogador (%d/%d quadros)" % [near_frames, frames])
	check(drv.press_count >= 1, "mirou a faixa do jogador para empurrar (%d)" % drv.press_count)
	check(side_hits >= 1, "o empurrao vira batida lateral (%d)" % side_hits)


func test_rival_mirrors_the_players_turn_signal() -> void:
	var sim := _straight()
	var h := _human(sim, 20.0, Lanes.FIRST, 30.0)
	var bot := sim.add_truck(0.0, Lanes.X[Lanes.LAST])      # 20 m atras (ainda fora do duelo, ja dentro do alcance da seta)
	sim.trucks[bot].is_bot = true
	sim.trucks[bot].speed = 30.0
	var drv := BotDriver.new(BotDriver.Difficulty.HARD, 3, Lanes.X[Lanes.LAST])
	# o jogador liga a seta para a direita (quer a faixa do meio, onde o rival vai entrar)
	for n in 3:
		sim.set_command(h, Commands.make(1.0, 0.5, 0.0))
		sim.set_command(bot, drv.command_for(sim, bot, DT))
		sim.step()
	for n in 3:
		sim.set_command(h, Commands.make(0.0, 0.5, 0.0))
		sim.set_command(bot, drv.command_for(sim, bot, DT))
		sim.step()
	check_eq(sim.trucks[h].signal_dir, 1, "a seta do jogador esta ligada")
	for n in 30:
		sim.set_command(h, Commands.make(0.0, 0.5, 0.0))
		sim.set_command(bot, drv.command_for(sim, bot, DT))
		sim.step()
	check(drv.mirror_count >= 1, "o rival reagiu a seta (%d)" % drv.mirror_count)
	check_eq(sim.trucks[bot].lane, Lanes.CENTER, "e foi para a faixa que o jogador queria, fechando-a")


func test_easy_non_rival_does_not_duel() -> void:
	var sim := _straight()
	var h := _human(sim, 0.0, Lanes.CENTER, 25.0)
	var bot := sim.add_truck(0.0, Lanes.X[Lanes.FIRST])
	sim.trucks[bot].is_bot = true
	sim.trucks[bot].speed = 25.0
	var drv := BotDriver.new(BotDriver.Difficulty.EASY, 2, Lanes.X[Lanes.FIRST])
	check(not drv.rival, "facil comum nao e rival")
	for n in 30 * 15:
		_hold(sim, h, 25.0)
		sim.set_command(bot, drv.command_for(sim, bot, DT))
		sim.step()
	check_eq(drv.duel_count, 0, "nao duela")
	var rival_easy := BotDriver.new(BotDriver.Difficulty.EASY, 2, 0.0, true)
	check(rival_easy.rival, "mas o rival da rota duela mesmo no facil")
