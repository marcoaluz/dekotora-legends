extends TestCase
## Perda de carga proporcional (ATB-1): contato e batidas descontam 0-40% do premio; tipo de carga muda a fisica.


func _straight() -> RaceSim:
	var t := Track.new()
	t.add_section(6000.0, 0.0)
	return RaceSim.new(t)


func test_loss_is_zero_to_forty_percent() -> void:
	check_near(RaceRules.cargo_loss(1.0), 0.0, 0.0001, "carga intacta nao perde nada")
	check_near(RaceRules.cargo_loss(0.0), 0.4, 0.0001, "carga destruida perde 40%")
	check_near(RaceRules.cargo_loss(0.5), 0.2, 0.0001, "metade = 20%")
	check_eq(RaceRules.payment(10000, 0.0, 4, 0), 6000, "premio minimo = 60% do frete")


func test_touching_another_truck_costs_a_little() -> void:
	var sim := _straight()
	var a := sim.add_truck(0.0, 0.0)
	var b := sim.add_truck(0.0, 0.2)           # sobrepostos lado a lado
	sim.trucks[a].speed = 20.0
	sim.trucks[b].speed = 20.0
	for n in 10:
		sim.step()
	check(sim.trucks[a].cargo_penalty > 0.0, "encostar ja desconta do premio")
	check(sim.trucks[a].cargo_penalty < 0.02, "mas pouco (%.3f)" % sim.trucks[a].cargo_penalty)


func test_hard_hit_costs_more_than_touch_and_is_capped() -> void:
	var t := TruckSim.new()
	t.cargo_hit(5.0)
	var small: float = t.cargo_penalty
	t.cargo_hit(20.0)
	check(t.cargo_penalty > small * 3.0, "batida forte custa bem mais")
	for k in 20:
		t.cargo_hit(50.0)
	check_near(t.cargo_penalty, TruckSim.MAX_CARGO_LOSS, 0.0001, "nunca passa de 40%")
	check_near(t.cargo_integrity(), 0.0, 0.0001, "integridade zera junto")
	check_near(t.cargo_loss(), TruckSim.MAX_CARGO_LOSS, 0.0001, "perda = teto")


func test_fragile_cargo_loses_more_for_the_same_hit() -> void:
	var normal := TruckSim.new()
	var fragile := TruckSim.new()
	fragile.cargo_fragility = 2.0
	normal.cargo_hit(10.0)
	fragile.cargo_hit(10.0)
	check_near(fragile.cargo_penalty, normal.cargo_penalty * 2.0, 0.0001, "fragilidade 2,0 = perde o dobro")


func test_part_damage_still_applies_on_top() -> void:
	var t := TruckSim.new()
	t.set_loadout([DamageModel.make_part("fb", ["front"], 10.0, 20.0, 5)])
	var events: Array[String] = DamageModel.apply_impact(t, "front", 80.0)
	check(events.size() >= 1, "a peca quebra como antes")
	check(float(t.systems["cargo"]) < 100.0, "e a sobra ainda estraga motor/carga")
	var before: float = t.cargo_integrity()
	t.cargo_hit(10.0)
	check(t.cargo_integrity() < before, "a batida soma, nao substitui")


func test_heavy_cargo_accelerates_slower() -> void:
	var sim := _straight()
	var a := sim.add_truck()
	var b := sim.add_truck(0.0, 0.6)
	sim.trucks[b].cargo_trait = "heavy"
	for n in 30 * 6:
		sim.set_command(a, Commands.make(0.0, 1.0, 0.0))
		sim.set_command(b, Commands.make(0.0, 1.0, 0.0))
		sim.step()
	check(sim.trucks[a].speed > sim.trucks[b].speed, "carga pesada acelera menos (%.1f x %.1f)" % [sim.trucks[a].speed, sim.trucks[b].speed])


func test_cargo_types_have_traits_and_contracts_carry_them() -> void:
	var traits: Dictionary = {}
	for c in Contracts.all_cargos():
		traits[String(c.id)] = String(c.trait_kind)
	check_eq(traits["ceramica"], "fragile", "ceramica = fragil")
	check_eq(traits["aco"], "heavy", "aco = pesada")
	check_eq(traits["alimentos"], "perishable", "alimentos = pereciveis")
	var routes: Array[RouteDef] = [load("res://data/routes/kanto_1_coast.tres") as RouteDef]
	var seen_perishable: bool = false
	for s in range(1, 60):
		for c in Contracts.generate(s, routes, func(_r: RouteDef) -> bool: return true, "longo"):
			if String(c["trait"]) == "perishable":
				seen_perishable = true
				check_near(float(c["deadline_s"]), roundf(routes[0].deadline() * 0.8), 0.6, "pereciveis tem prazo 20% menor")
			else:
				check_near(float(c["deadline_s"]), routes[0].deadline(), 0.6, "prazo normal")
	check(seen_perishable, "o sorteio gera pereciveis")
	var f: Dictionary = Contracts.sim_fields({"weight_t": 5.0, "fragility": 2.2, "trait": "fragile"})
	check_eq(String(f["cargo_trait"]), "fragile", "a simulacao recebe o tipo")


func test_result_shows_the_loss_in_yen() -> void:
	var sim := _straight()
	sim.freight = 20000
	var i := sim.add_truck(5990.0, 0.0)
	sim.trucks[i].speed = 30.0
	sim.trucks[i].cargo_penalty = 0.1               # 25% da integridade
	for n in 30:
		sim.set_command(i, Commands.make(0.0, 0.5, 0.0))
		sim.step()
	var res: Dictionary = sim.result_for(i)
	check_eq(String(res["outcome"]), "win", "chegou")
	check_near(float(res["cargo_loss"]), 0.1, 0.001, "perda de 10% do premio")
	check_eq(int(res["cargo_loss_yen"]), 2000, "10% de 20000")
