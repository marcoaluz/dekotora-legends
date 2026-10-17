extends TestCase
## Testes de Passing, vacuo, ultrapassagem, chegada e pagamento (P33).


func _straight(len_m: float = 4000.0) -> Track:
	var t := Track.new()
	t.add_section(len_m, 0.0)
	return t


func test_payment_formula() -> void:
	# frete 20000, carga 80% (perda 0,4 x 20% = 8% = 1600), 1o lugar (+50% do frete), fama 10 -> 18400 + 10000 + 500
	check_eq(RaceRules.payment(20000, 0.8, 1, 10), 28900, "pagamento")
	check_eq(RaceRules.payment(20000, 1.0, 4, 0), 20000, "4o sem bonus")
	check_eq(RaceRules.position_bonus(30000, 2), 6000, "2o +20%")


func test_fame_gain_uses_position_factor_and_overtakes() -> void:
	check_eq(RaceRules.fame_gain(100.0, 1, 0), 100, "1o fator 1.0")
	check_eq(RaceRules.fame_gain(100.0, 3, 0), 60, "3o fator 0.6")
	check_eq(RaceRules.fame_gain(0.0, 2, 3), 6, "ultrapassagens")


func test_fame_only_counts_intact_parts() -> void:
	var t := TruckSim.new()
	t.set_loadout([DamageModel.make_part("a", ["front"], 10.0, 10.0, 25), DamageModel.make_part("b", ["rear"], 10.0, 10.0, 15)])
	check_near(RaceRules.intact_fame(t), 40.0, 0.001, "tudo inteiro")
	DamageModel.apply_impact(t, "front", 100.0)
	check_near(RaceRules.intact_fame(t), 15.0, 0.001, "peca quebrada nao conta Fama")


func test_draft_builds_behind_another_truck() -> void:
	var sim := RaceSim.new(_straight())
	var a := sim.add_truck(0.0, 0.0)
	var b := sim.add_truck(30.0, 0.0)       # 30 - 12 = 18 m a frente do nariz de a
	sim.trucks[a].speed = 30.0
	sim.trucks[b].speed = 30.0
	for n in 60:
		sim.set_command(a, Commands.make(0.0, 0.5, 0.0))
		sim.set_command(b, Commands.make(0.0, 0.5, 0.0))
		sim.step()
	check(sim.trucks[a].draft > 0.2, "vacuo ativo atras do outro (%.2f)" % sim.trucks[a].draft)
	check(sim.trucks[b].draft < 0.01, "o da frente nao tem vacuo")


func test_passing_bar_fills_at_speed_and_drains_when_used() -> void:
	var sim := RaceSim.new(_straight())
	var a := sim.add_truck()
	sim.trucks[a].speed = 36.0
	sim.set_command(a, Commands.make(0.0, 1.0, 0.0))
	for n in 30 * 10:
		sim.step()
	var charged: float = sim.trucks[a].passing_charge
	check(charged > 0.2, "barra enche em alta velocidade (%.2f)" % charged)
	sim.set_command(a, Commands.make(0.0, 1.0, 0.0, true))
	for n in 30:
		sim.step()
	check(sim.trucks[a].passing_charge < charged, "usar Passing gasta a barra")


func test_passing_scares_human_but_bots_yield() -> void:
	var sim := RaceSim.new(_straight())
	var me := sim.add_truck(0.0, 0.0)
	var human := sim.add_truck(20.0, 0.0)
	sim.trucks[me].passing_charge = 1.0
	sim.trucks[me].speed = 30.0
	sim.trucks[human].speed = 30.0
	sim.set_command(me, Commands.make(0.0, 1.0, 0.0, true))
	sim.step()
	var scared: bool = false
	for e in sim.drain_events():
		if String(e["type"]) == "passing_scare":
			scared = true
	check(scared, "contra humano gera evento de susto (tremor/som)")
	# bot a frente: abre espaco
	var sim2 := RaceSim.new(_straight())
	var p := sim2.add_truck(0.0, 0.0)
	var bi := sim2.add_truck(20.0, 0.0)
	sim2.trucks[bi].is_bot = true
	sim2.trucks[p].passing_charge = 1.0
	sim2.trucks[p].speed = 30.0
	sim2.trucks[bi].speed = 30.0
	sim2.set_command(p, Commands.make(0.0, 1.0, 0.0, true))
	sim2.step()
	var bot := BotDriver.new(BotDriver.Difficulty.NORMAL, 3, 0.0)
	bot.command_for(sim2, bi, RaceSim.FIXED_DT)
	check(absf(bot.target_x) > 0.3, "bot abre espaco (target_x=%.2f)" % bot.target_x)


func test_overtake_counted_once_and_finish_order() -> void:
	var sim := RaceSim.new(_straight(600.0))
	var slow := sim.add_truck(60.0, -0.5)
	var fast := sim.add_truck(0.0, 0.5)
	sim.trucks[slow].speed = 20.0
	sim.trucks[fast].speed = 38.0
	sim.trucks[slow].is_bot = true
	sim.trucks[fast].is_bot = false
	for n in 30 * 40:
		sim.set_command(slow, Commands.make(0.0, 0.4, 0.0))
		sim.set_command(fast, Commands.make(0.0, 1.0, 0.0))
		sim.step()
		if sim.is_over():
			break
	check_eq(sim.trucks[fast].overtakes, 1, "ultrapassou uma vez")
	check_eq(sim.trucks[fast].finish_position, 1, "chegou em 1o")
	check(sim.is_over(), "corrida acaba quando o humano chega")
	var res: Dictionary = sim.result_for(fast)
	check_eq(int(res["position"]), 1, "resultado: posicao")
	check(int(res["pay"]) >= 20000, "pagou pelo menos o frete")
