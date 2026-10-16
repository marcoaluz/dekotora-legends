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


func test_curve_without_steering_pushes_out() -> void:
	var t := Track.new()
	t.add_section(3000.0, 1.0, 0.0, 0.0)
	var sim := RaceSim.new(t)
	var i := sim.add_truck()
	sim.trucks[i].speed = 30.0
	sim.set_command(i, Commands.make(0.0, 0.6, 0.0))
	for n in 90:
		sim.step()
	check(sim.trucks[i].x < -1.0, "curva a direita sem virar empurra para fora (esquerda), x=%.2f" % sim.trucks[i].x)


func test_steering_compensates_curve() -> void:
	var t := Track.new()
	t.add_section(3000.0, 0.8, 0.0, 0.0)
	var sim := RaceSim.new(t)
	var i := sim.add_truck()
	sim.trucks[i].speed = 25.0
	sim.set_command(i, Commands.make(0.0, 0.5, 0.0))
	# controlador simples: vira contra o desvio
	for n in 150:
		var tr: TruckSim = sim.trucks[i]
		var s: float = clampf(-tr.x * 3.0 + 0.7, -1.0, 1.0)
		sim.set_command(i, Commands.make(s, 0.5, 0.0))
		sim.step()
	check(absf(sim.trucks[i].x) < 1.0, "com direção o caminhao fica na pista, x=%.2f" % sim.trucks[i].x)


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
