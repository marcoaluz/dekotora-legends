extends TestCase
## Controle por faixas (ATB-1): seta no 1o toque, troca no 2o, troca em ~0,7 s, empurrao em faixa ocupada.

const DT: float = RaceSim.FIXED_DT


func _straight() -> RaceSim:
	var t := Track.new()
	t.add_section(6000.0, 0.0)
	return RaceSim.new(t)


## Um toque: segura `dir` por 3 passos e solta por 3.
func _tap(sim: RaceSim, i: int, dir: float, throttle: float = 0.5) -> void:
	for n in 3:
		sim.set_command(i, Commands.make(dir, throttle, 0.0))
		sim.step()
	for n in 3:
		sim.set_command(i, Commands.make(0.0, throttle, 0.0))
		sim.step()


func _rolling(speed: float = 25.0) -> Array:
	var sim := _straight()
	var i := sim.add_truck(0.0, 0.0)
	sim.trucks[i].speed = speed
	return [sim, i]


func test_first_tap_only_turns_signal_on() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	var t: TruckSim = sim.trucks[r[1]]
	_tap(sim, r[1], 1.0)
	check_eq(t.signal_dir, 1, "1o toque liga a seta da direita")
	check_eq(t.lane, Lanes.CENTER, "1o toque nao troca de faixa")
	for n in 60:
		sim.set_command(r[1], Commands.make(0.0, 0.5, 0.0))
		sim.step()
	check(absf(t.x) < 0.01, "o caminhao continua na faixa, x=%.2f" % t.x)


func test_second_tap_same_side_changes_lane_in_about_0_7s() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	var t: TruckSim = sim.trucks[r[1]]
	_tap(sim, r[1], 1.0)
	_tap(sim, r[1], 1.0)
	check_eq(t.lane, Lanes.CENTER + 1, "2o toque executa a troca para a direita")
	check_eq(t.signal_dir, 0, "a seta apaga ao trocar")
	var steps: int = 0
	while absf(t.x - Lanes.X[t.lane]) > 0.05 and steps < 90:
		sim.set_command(r[1], Commands.make(0.0, 0.5, 0.0))
		sim.step()
		steps += 1
	var secs: float = float(steps + 3) * DT          # + os 3 passos que sobram do 2o toque
	check(secs > 0.8 and secs < 1.6, "troca pesada leva ~1 s (levou %.2f s)" % secs)


func test_second_tap_after_window_only_rearms_signal() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	var t: TruckSim = sim.trucks[r[1]]
	_tap(sim, r[1], -1.0)
	for n in int(TruckSim.LANE_SIGNAL_WINDOW / DT) + 5:
		sim.set_command(r[1], Commands.make(0.0, 0.5, 0.0))
		sim.step()
	check_eq(t.signal_dir, 0, "a seta apagou depois de 1,5 s")
	_tap(sim, r[1], -1.0)
	check_eq(t.lane, Lanes.CENTER, "toque tardio nao troca")
	check_eq(t.signal_dir, -1, "toque tardio liga a seta de novo")


func test_opposite_tap_switches_signal_side() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	var t: TruckSim = sim.trucks[r[1]]
	_tap(sim, r[1], 1.0)
	_tap(sim, r[1], -1.0)
	check_eq(t.signal_dir, -1, "toque no lado oposto troca a seta")
	check_eq(t.lane, Lanes.CENTER, "e nao troca de faixa")


func test_holding_the_key_is_one_tap() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	var t: TruckSim = sim.trucks[r[1]]
	for n in 60:
		sim.set_command(r[1], Commands.make(1.0, 0.5, 0.0))
		sim.step()
	check_eq(t.lane, Lanes.CENTER, "segurar o botao e um toque so (seta), sem trocar")
	check_eq(t.lane_changes, 0, "nenhuma troca")


func test_lane_limits_and_shoulder() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	var t: TruckSim = sim.trucks[r[1]]
	for k in 6:
		_tap(sim, r[1], 1.0)
		_tap(sim, r[1], 1.0)
	check_eq(t.lane, Lanes.SHOULDER_R, "ultima faixa e o acostamento direito")
	for n in 90:
		sim.set_command(r[1], Commands.make(0.0, 0.5, 0.0))
		sim.step()
	check(t.offroad, "acostamento conta como fora da pista")


func test_standing_truck_does_not_slide() -> void:
	var sim := _straight()
	var i := sim.add_truck(0.0, 0.0)
	_tap(sim, i, 1.0, 0.0)
	_tap(sim, i, 1.0, 0.0)
	for n in 60:
		sim.set_command(i, Commands.make(0.0, 0.0, 0.0))
		sim.step()
	check(absf(sim.trucks[i].x) < 0.05, "parado nao anda de lado, x=%.2f" % sim.trucks[i].x)


func test_changing_into_occupied_lane_pushes_and_hits() -> void:
	var sim := _straight()
	var a := sim.add_truck(0.0, 0.0)           # troca para a direita
	var b := sim.add_truck(0.0, 0.5)           # ocupa a faixa da direita, ao lado
	sim.trucks[a].speed = 25.0
	sim.trucks[b].speed = 25.0
	sim.trucks[b].set_mass(6000.0)             # mais leve
	_tap(sim, a, 1.0)
	_tap(sim, a, 1.0)
	var hits: int = 0
	for n in 90:
		sim.set_command(a, Commands.make(0.0, 0.5, 0.0))
		sim.set_command(b, Commands.make(0.0, 0.5, 0.0))
		sim.step()
		for e in sim.drain_events():
			if String(e["type"]) == "truck":
				hits += 1
	check(hits >= 1, "fechar o rival gera batida lateral (%d)" % hits)
	check(absf(sim.trucks[a].x - sim.trucks[b].x) > TruckSim.WIDTH_X - 0.05, "nunca ficam sobrepostos")


func test_bot_changes_lane_with_two_taps() -> void:
	var sim := _straight()
	var i := sim.add_truck(0.0, 0.0)
	sim.trucks[i].speed = 25.0
	var bot := BotDriver.new(BotDriver.Difficulty.NORMAL, 3, 0.6)   # prefere a faixa da direita
	var taps: int = 0
	var prev: float = 0.0
	for n in 120:
		var c: Commands = bot.command_for(sim, i, DT)
		if c.steer != 0.0 and prev == 0.0:
			taps += 1
		prev = c.steer
		sim.set_command(i, c)
		sim.step()
	check_eq(sim.trucks[i].lane, Lanes.LAST, "o bot chegou a faixa que prefere")
	check_eq(taps, 2, "usando exatamente 2 toques")


func test_snapshot_carries_lane_state() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	_tap(sim, r[1], 1.0)
	var t: TruckSim = sim.trucks[r[1]]
	var data: PackedByteArray = Snapshot.pack(sim, [0])
	var snap: Dictionary = Snapshot.unpack(data)
	var d: Dictionary = (snap["trucks"] as Array)[0]
	check_eq(int(d["lane"]), t.lane, "faixa no snapshot")
	check_eq(int(d["signal_dir"]), 1, "seta no snapshot")
	check_near(float(d["signal_time"]), t.signal_time, 0.02, "tempo da seta no snapshot")
	check_eq(int(d["tap_prev"]), t.tap_prev, "toque anterior no snapshot")
