extends TestCase
## Prazo de entrega e regra de vitoria (ATB-1): vence quem chega primeiro E dentro do prazo.


func _track(len_m: float) -> Track:
	var t := Track.new()
	t.add_section(len_m, 0.0)
	return t


func _drive(sim: RaceSim, seconds: float, throttles: Array) -> void:
	for n in int(seconds / RaceSim.FIXED_DT):
		for i in sim.trucks.size():
			sim.set_command(i, Commands.make(0.0, float(throttles[i]), 0.0))
		sim.step()


func test_route_deadline_comes_from_length() -> void:
	var r: RouteDef = load("res://data/routes/kanto_1_coast.tres") as RouteDef
	check_near(r.length_m(), 3000.0, 0.1, "comprimento do trecho")
	check_near(r.deadline(), roundf(3000.0 / RouteDef.DEADLINE_REF_SPEED * RouteDef.DEADLINE_SLACK), 0.1, "prazo calculado")
	r.deadline_s = 99.0
	check_near(r.deadline(), 99.0, 0.01, "prazo explicito tem prioridade")


func test_contracts_carry_the_deadline() -> void:
	var routes: Array[RouteDef] = [load("res://data/routes/kanto_1_coast.tres") as RouteDef]
	var board: Array[Dictionary] = Contracts.generate(5, routes, func(_r: RouteDef) -> bool: return true, "base")
	check(not board.is_empty(), "quadro gerado")
	var k: float = Contracts.PERISHABLE_DEADLINE if String(board[0]["trait"]) == "perishable" else 1.0   # a carga sorteada pode ser perecivel
	check_near(float(board[0]["deadline_s"]), roundf(routes[0].deadline() * k), 0.01, "o contrato traz o prazo do trecho")


func test_time_left_counts_down() -> void:
	var sim := RaceSim.new(_track(5000.0))
	sim.deadline = 20.0
	sim.add_truck()
	check_near(sim.time_left(), 20.0, 0.01, "prazo cheio na largada")
	_drive(sim, 5.0, [0.5])
	check_near(sim.time_left(), 15.0, 0.1, "5 s depois sobram 15 s")
	check(INF == RaceSim.new(_track(100.0)).time_left(), "sem prazo = sem limite")


func test_timeout_is_defeat_and_pays_nothing() -> void:
	var sim := RaceSim.new(_track(5000.0))
	sim.deadline = 10.0
	var i := sim.add_truck()
	var timeouts: int = 0
	for n in 30 * 12:
		sim.set_command(i, Commands.make(0.0, 0.5, 0.0))
		sim.step()
		for e in sim.drain_events():
			if String(e["type"]) == "timeout":
				timeouts += 1
	check(sim.is_over(), "a corrida acaba no prazo")
	check_eq(timeouts, 1, "um evento de tempo esgotado")
	var res: Dictionary = sim.result_for(i)
	check_eq(String(res["outcome"]), "timeout", "desfecho")
	check_eq(int(res["pay"]), 0, "tempo esgotado nao paga")
	check_eq(int(res["fame"]), 0, "nem Fama")
	check_near(float(res["time"]), 10.0, 0.1, "tempo mostrado = prazo")


func test_arriving_first_in_time_wins() -> void:
	var sim := RaceSim.new(_track(400.0))
	sim.deadline = 60.0
	var a := sim.add_truck(0.0, 0.0)
	var b := sim.add_truck(0.0, 0.6)
	sim.trucks[a].speed = 30.0
	sim.trucks[b].speed = 20.0
	for n in 30 * 40:
		sim.set_command(a, Commands.make(0.0, 1.0, 0.0))
		sim.set_command(b, Commands.make(0.0, 0.4, 0.0))
		sim.step()
		if sim.finish_order.size() == 2:
			break
	var ra: Dictionary = sim.result_for(a)
	check_eq(String(ra["outcome"]), "win", "primeiro e no prazo vence")
	check(int(ra["pay"]) > 0, "paga")
	check(float(ra["time_left"]) > 0.0, "sobra tempo")


func test_arriving_after_rival_is_defeat_even_in_time() -> void:
	var sim := RaceSim.new(_track(400.0))
	sim.deadline = 120.0
	var a := sim.add_truck(0.0, 0.0)
	var b := sim.add_truck(0.0, 0.6)
	sim.trucks[a].speed = 20.0
	sim.trucks[b].speed = 30.0
	for n in 30 * 60:
		sim.set_command(a, Commands.make(0.0, 0.4, 0.0))
		sim.set_command(b, Commands.make(0.0, 1.0, 0.0))
		sim.step()
		if sim.finish_order.size() == 2:
			break
	var ra: Dictionary = sim.result_for(a)
	check_eq(int(ra["position"]), 2, "chegou em segundo")
	check_eq(String(ra["outcome"]), "lose_rival", "chegar depois do rival e derrota")
	check_eq(int(ra["pay"]), 0, "derrota nao paga")
	check_eq(String(sim.result_for(b)["outcome"]), "win", "o rival vence")


func test_nobody_finishes_after_the_deadline() -> void:
	var sim := RaceSim.new(_track(5000.0))
	sim.deadline = 5.0
	var a := sim.add_truck(4950.0, 0.0)
	sim.trucks[a].speed = 3.0
	for n in 30 * 8:
		sim.set_command(a, Commands.make(0.0, 0.1, 0.0))
		sim.step()
	check(sim.trucks[a].timed_out, "marcado como tempo esgotado")
	check_eq(sim.trucks[a].finish_position, 0, "nao conta chegada depois do prazo")
