extends TestCase
## Testes de colisao e dano por zona (P32), com os numeros do BALANCEAMENTO.


func _tank_loadout() -> Array[Dictionary]:
	return [
		DamageModel.make_part("fb_gold_wing", ["front"], 560.0, 300.0, 40),
		DamageModel.make_part("visor_basic", ["front"], 40.0, 40.0, 5),
		DamageModel.make_part("skirt_chrome", ["left", "right"], 300.0, 200.0, 15),
		DamageModel.make_part("rb_chrome", ["rear"], 260.0, 180.0, 12),
	]


func _truck_with(parts: Array[Dictionary]) -> TruckSim:
	var t := TruckSim.new()
	t.set_loadout(parts)
	return t


func test_impact_damage_formula() -> void:
	# k_dano = 4; dv = 10 m/s; massa do outro = 12000 kg -> 4*10*12000/1000 = 480
	check_near(DamageModel.impact_damage(10.0, 12000.0), 480.0, 0.01, "formula do dano")


func test_front_parts_absorb_first_then_leftover_to_systems() -> void:
	var t := _truck_with(_tank_loadout())
	var broken: Array[String] = DamageModel.apply_impact(t, "front", 100.0)
	check_eq(broken.size(), 0, "100 de dano nao quebra o para-choque (300)")
	check_near(float(t.loadout[0]["dur"]), 200.0, 0.01, "para-choque absorveu 100")
	check_near(float(t.systems["engine"]), 100.0, 0.01, "motor intacto enquanto a peca absorve")


func test_part_breaks_and_leftover_splits_engine_and_cargo() -> void:
	var t := _truck_with(_tank_loadout())
	var mass_before: float = t.mass
	# 300 (para-choque) + 40 (viseira) = 340 absorvido; sobra 160 -> 80 motor, 80 carga
	var broken: Array[String] = DamageModel.apply_impact(t, "front", 500.0)
	check("fb_gold_wing" in broken and "visor_basic" in broken, "as duas pecas da frente quebraram")
	check_near(float(t.systems["engine"]), 100.0 - 80.0 / DamageModel.POINTS_PER_HEALTH, 0.01, "50% da sobra no motor")
	check_near(float(t.systems["cargo"]), 100.0 - 80.0 / DamageModel.POINTS_PER_HEALTH, 0.01, "50% da sobra na carga")
	check_near(t.mass, mass_before - 600.0, 0.01, "pecas quebradas deixam de pesar")


func test_rear_hit_leftover_all_to_cargo() -> void:
	var t := _truck_with(_tank_loadout())
	DamageModel.apply_impact(t, "rear", 180.0 + 100.0)
	check_near(float(t.systems["cargo"]), 100.0 - 100.0 / DamageModel.POINTS_PER_HEALTH, 0.01, "traseira: sobra toda na carga")


func test_engine_damage_cuts_power_and_steering_pulls() -> void:
	var t := _truck_with([])
	t.systems["engine"] = 0.0
	t.systems["steering"] = 0.0
	t.refresh_damage_effects()
	check_near(t.engine.power_factor, 0.5, 0.001, "motor 0%: metade da potencia")
	check_near(t.steer_pull, 0.1, 0.001, "direcao 0%: puxa 0,1")


func test_rear_end_collision_damages_both_and_transfers_momentum() -> void:
	var track := Track.new()
	track.add_section(3000.0, 0.0)
	var sim := RaceSim.new(track)
	var a := sim.add_truck(0.0, 0.0)        # de tras, rapido
	var b := sim.add_truck(8.0, 0.0)        # na frente, lento (sobreposto em z)
	sim.trucks[a].set_loadout(_tank_loadout())
	sim.trucks[b].set_loadout(_tank_loadout())
	sim.trucks[a].speed = 30.0
	sim.trucks[b].speed = 15.0
	sim.step()
	var evs: Array[Dictionary] = sim.drain_events()
	check_eq(evs.size(), 1, "um evento de colisao")
	if evs.size() == 1:
		check_eq(String(evs[0]["zone_a"]), "front", "o de tras levou na frente")
		check_eq(String(evs[0]["zone_b"]), "rear", "o da frente levou na traseira")
	check(sim.trucks[a].speed < 30.0, "o de tras perdeu velocidade")
	check(sim.trucks[b].speed > 15.0, "o da frente ganhou velocidade")


func test_side_collision_pushes_lighter_truck_more() -> void:
	var track := Track.new()
	track.add_section(3000.0, 0.0)
	var sim := RaceSim.new(track)
	var light := sim.add_truck(0.0, -0.1)
	var heavy := sim.add_truck(0.0, 0.1)
	sim.trucks[heavy].set_loadout(_tank_loadout())     # mais pesado
	sim.trucks[heavy].mass += 3000.0
	sim.trucks[light].speed = 25.0
	sim.trucks[heavy].speed = 25.0
	sim.trucks[light].lateral_vel = 0.5
	var x_light: float = sim.trucks[light].x
	var x_heavy: float = sim.trucks[heavy].x
	sim.step()
	var moved_light: float = absf(sim.trucks[light].x - x_light)
	var moved_heavy: float = absf(sim.trucks[heavy].x - x_heavy)
	check(moved_light > moved_heavy, "o mais leve se desloca mais (%.3f > %.3f)" % [moved_light, moved_heavy])


func test_no_event_without_overlap() -> void:
	var sim := RaceSim.new(Track.make_test_track())
	sim.add_truck(0.0, -0.5)
	sim.add_truck(0.0, 0.5)
	sim.step()
	check_eq(sim.drain_events().size(), 0, "sem contato, sem evento")


func test_part_state_for_presentation() -> void:
	var p: Dictionary = DamageModel.make_part("x", ["front"], 10.0, 100.0)
	p["broken"] = false
	check_eq(DamageModel.part_state(p), "ok", "inteira")
	p["dur"] = 40.0
	check_eq(DamageModel.part_state(p), "dent", "amassada abaixo de 60%")
	p["dur"] = 0.0
	p["broken"] = true
	check_eq(DamageModel.part_state(p), "broken", "quebrada")
