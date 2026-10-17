extends TestCase
## Fluxo da campanha sem tela: perfil -> rota -> corrida (4 caminhoes dirigidos por bots) -> resultado -> perfil.


func _run_route(route_id: String) -> Dictionary:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	var route: RouteDef = load("res://data/routes/%s.tres" % route_id) as RouteDef
	var sim := RaceSim.new(route.build_track(), route.traffic)
	sim.freight = route.freight
	var drivers: Array[BotDriver] = []
	var xs: Array[float] = Room.GRID_X
	for i in 4:
		sim.add_truck(-float(i) * 14.0, xs[i])
		var t: TruckSim = sim.trucks[i]
		if i == 0:
			gs.configure_truck(t)
		else:
			t.is_bot = true
			t.set_loadout([DamageModel.make_part("fb_basic", ["front"], 120.0, 80.0, 5)])
		drivers.append(BotDriver.new(BotDriver.Difficulty.NORMAL, 50 + i, xs[i]))
	var steps: int = 0
	while not sim.is_over() and steps < 30 * 400:
		for i in 4:
			if i == 0 or sim.trucks[i].is_bot:
				sim.set_command(i, drivers[i].command_for(sim, i, RaceSim.FIXED_DT))
		sim.step()
		sim.drain_events()
		steps += 1
	return {"sim": sim, "route": route, "steps": steps}


func test_route_1_can_be_finished_and_pays() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	var money0: int = gs.money()
	var r: Dictionary = _run_route("kanto_1_coast")
	var sim: RaceSim = r["sim"]
	check(sim.is_over(), "a corrida terminou (%d passos)" % int(r["steps"]))
	var res: Dictionary = sim.result_for(0)
	check(int(res["pay"]) >= int(float(sim.freight) * 0.4), "pagamento coerente (%d)" % int(res["pay"]))
	gs.apply_race_result(res, "kanto_1_coast", sim.trucks[0])
	check(gs.money() > money0, "dinheiro aumentou depois da entrega")
	check((gs.profile["routes_done"] as Dictionary).has("kanto_1_coast"), "progresso gravado")
	gs.new_profile()


func test_all_three_routes_are_driveable() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	for id in ["kanto_2_viaduct", "kanto_3_mountain"]:
		var r: Dictionary = _run_route(id)
		var sim: RaceSim = r["sim"]
		check(sim.trucks[0].finish_position > 0, "%s: o jogador (bot) chegou ao fim em %d passos" % [id, int(r["steps"])])
	gs.new_profile()
