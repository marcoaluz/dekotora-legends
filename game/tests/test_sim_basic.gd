extends TestCase
## Testes da simulacao basica (P20): aceleracao, curva sem virar e freio.


func _straight_race() -> RaceSim:
	var t := Track.new()
	t.add_section(5000.0, 0.0)
	return RaceSim.new(t)


func test_accelerate_10s_on_straight() -> void:
	var sim := _straight_race()
	var i := sim.add_truck()
	sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
	for n in 300:
		sim.step()
	var v: float = sim.trucks[i].speed
	check(v > 12.0 and v < 25.0, "velocidade apos 10 s deve ser coerente (12-25 m/s), foi %.1f" % v)
	check(sim.trucks[i].z > 80.0, "deve ter percorrido mais de 80 m")


func test_reaches_top_speed_but_not_beyond() -> void:
	var sim := _straight_race()
	var i := sim.add_truck()
	sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
	for n in 30 * 90:
		sim.step()
	var v: float = sim.trucks[i].speed
	check(v > 35.0 and v <= EngineModel.MAX_SPEED + 0.01, "velocidade maxima ~38.9 m/s, foi %.1f" % v)


## T-132: so escapa MUITO acima da segura (+30%); 36 m/s na curva 1,0 = +43%. Ate +30% so raspa (test_lane_following).
func test_curve_too_fast_pushes_out_of_lane() -> void:
	var t := Track.new()
	t.add_section(3000.0, 1.0, 0.0, 0.0)
	var sim := RaceSim.new(t)
	var i := sim.add_truck()
	sim.trucks[i].speed = 36.0
	sim.set_command(i, Commands.make(0.0, 0.6, 0.0))
	var min_x: float = 0.0
	for n in 90:
		sim.step()
		min_x = minf(min_x, sim.trucks[i].x)
	check(min_x < -0.9, "curva a direita rapido demais empurra para fora da pista (esquerda), x minimo=%.2f" % min_x)


func test_truck_follows_lane_in_curve_at_safe_speed() -> void:
	var t := Track.new()
	t.add_section(3000.0, 0.8, 0.0, 0.0)
	var sim := RaceSim.new(t)
	var i := sim.add_truck()
	sim.trucks[i].speed = 22.0
	sim.set_command(i, Commands.make(0.0, 0.3, 0.0))
	for n in 150:
		sim.step()
	check(absf(sim.trucks[i].x) < 0.05, "abaixo da velocidade segura o caminhao segue a faixa sozinho, x=%.2f" % sim.trucks[i].x)


func test_brake_stops_truck() -> void:
	var sim := _straight_race()
	var i := sim.add_truck()
	sim.trucks[i].speed = 30.0
	sim.set_command(i, Commands.make(0.0, 0.0, 1.0))
	for n in 30 * 12:
		sim.step()
	check_near(sim.trucks[i].speed, 0.0, 0.01, "freio para o caminhao")


func test_offroad_slows_down() -> void:
	var sim := _straight_race()
	var i := sim.add_truck(0.0, 1.3)
	sim.trucks[i].speed = 30.0
	sim.set_command(i, Commands.make(0.0, 0.0, 0.0))
	for n in 90:
		sim.step()
	check(sim.trucks[i].speed < 20.0, "acostamento reduz a velocidade, foi %.1f" % sim.trucks[i].speed)


func test_heavier_truck_accelerates_slower() -> void:
	var sim := _straight_race()
	var a := sim.add_truck()
	var b := sim.add_truck()
	sim.trucks[b].set_mass(1500.0)
	sim.set_command(a, Commands.make(0.0, 1.0, 0.0))
	sim.set_command(b, Commands.make(0.0, 1.0, 0.0))
	for n in 150:
		sim.step()
	check(sim.trucks[a].speed > sim.trucks[b].speed, "peso reduz aceleracao")
