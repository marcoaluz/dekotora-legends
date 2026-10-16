extends TestCase
## Testes do perfil, garagem e reparo (P42/P43/P45). Usam o autoload GameState com um perfil novo em memoria.

var _saved: Dictionary


func _gs() -> Node:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	return gs


func _fresh() -> Node:
	var gs: Node = _gs()
	gs.new_profile()
	return gs


func test_new_profile_defaults() -> void:
	var gs: Node = _fresh()
	check_eq(gs.money(), 50000, "dinheiro inicial 50.000")
	check_eq(gs.fame(), 0, "Fama inicial 0")
	check_eq(gs.installed_id("front_bumper"), "fb_basic", "para-choque basico instalado")
	check(String(gs.profile["player_code"]).length() == 8, "codigo de jogador")


func test_buy_install_and_rules() -> void:
	var gs: Node = _fresh()
	var visor: PartDef = gs.part("visor_basic")
	check_eq(gs.can_buy(visor), "", "pode comprar viseira basica")
	check(gs.buy(visor), "comprou")
	check_eq(gs.money(), 45000, "pagou 5.000")
	check(gs.install("visor_basic"), "instalou")
	check_eq(gs.installed_id("visor"), "visor_basic", "slot ocupado")
	var gold: PartDef = gs.part("fb_gold_wing")
	check(gs.can_buy(gold) != "", "asa dourada: bloqueada (Fama/dinheiro)")
	check(not gs.buy(gold), "nao compra o que nao pode")


func test_loadout_and_mass_follow_installed_parts() -> void:
	var gs: Node = _fresh()
	var m0: float = gs.total_mass()
	gs.profile["money"] = 500000
	gs.profile["fame"] = 500
	check(gs.buy(gs.part("fb_gold_wing")), "comprou asa dourada")
	gs.install("fb_gold_wing")
	check(gs.total_mass() > m0 + 400.0, "peca pesada aumenta a massa (%.0f -> %.0f)" % [m0, gs.total_mass()])
	var lo: Array[Dictionary] = gs.build_sim_loadout()
	var ids: Array[String] = []
	for p in lo:
		ids.append(String(p["id"]))
	check("fb_gold_wing" in ids and "fb_basic" not in ids, "montagem usa a peca instalada no slot")


func test_repair_cost_formula_and_repair() -> void:
	var gs: Node = _fresh()
	# fb_basic: preco 8000, durabilidade 80. Metade do dano => 8000 x 0,5 x 0,5 = 2000
	gs.profile["owned"]["fb_basic"]["dur"] = 40.0
	check_eq(gs.part_repair_cost("fb_basic"), 2000, "custo de reparo da formula")
	var money0: int = gs.money()
	check(gs.repair_part("fb_basic"), "reparou")
	check_eq(gs.money(), money0 - 2000, "pagou o reparo")
	check_eq(gs.part_repair_cost("fb_basic"), 0, "agora esta novo")
	# peca quebrada: reparar custa 100% do fator (preco x 0,5)
	gs.profile["owned"]["rb_basic"]["broken"] = true
	gs.profile["owned"]["rb_basic"]["dur"] = 0.0
	check_eq(gs.part_repair_cost("rb_basic"), 3000, "quebrada: 6000 x 0,5")


func test_system_repair_and_repair_all() -> void:
	var gs: Node = _fresh()
	gs.profile["systems"]["engine"] = 50.0
	check_eq(gs.system_repair_cost("engine"), 15000, "motor 50%% = metade de 30.000")
	gs.profile["owned"]["fb_basic"]["dur"] = 0.0
	gs.profile["owned"]["fb_basic"]["broken"] = true
	var total: int = gs.total_repair_cost()
	check(total >= 15000 + 4000, "total soma pecas e sistemas (%d)" % total)
	var spent: int = gs.repair_all()
	check_eq(spent, total, "reparar tudo gastou o total")
	check_eq(gs.total_repair_cost(), 0, "nada mais a reparar")


func test_mural_repaint_cost() -> void:
	var gs: Node = _fresh()
	gs.profile["money"] = 200000
	gs.profile["fame"] = 100
	check(gs.buy(gs.part("mural_waves")), "comprou o mural")
	gs.profile["owned"]["mural_waves"]["scratch"] = 1.0
	check_eq(gs.part_repair_cost("mural_waves"), 6000, "repintar = 30%% de 20.000")


func test_race_result_persists_damage_and_pays() -> void:
	var gs: Node = _fresh()
	var t := TruckSim.new()
	gs.configure_truck(t)
	DamageModel.apply_impact(t, "front", 50.0)         # amassa o para-choque basico
	var res := {"pay": 30000, "fame": 12, "time": 95.0, "position": 1}
	gs.apply_race_result(res, "kanto_1_coast", t)
	check_eq(gs.money(), 80000, "recebeu o pagamento")
	check_eq(gs.fame(), 12, "ganhou Fama")
	check(float(gs.profile["owned"]["fb_basic"]["dur"]) < 80.0, "dano ficou salvo")
	check(gs.route_won("kanto_1_coast"), "trecho marcado como vencido")


func test_save_and_load_roundtrip() -> void:
	var gs: Node = _fresh()
	gs.profile["money"] = 12345
	gs.save_profile()
	gs.profile["money"] = 1
	gs.load_profile()
	check_eq(gs.money(), 12345, "perfil recarregado do disco")
	gs.new_profile()


func test_estimate_zero_to_100_depends_on_build() -> void:
	var gs: Node = _fresh()
	var base: float = gs.estimate_zero_to_100()
	gs.profile["engine"] = "eng_v8"
	gs.profile["turbo"] = "turbo_twin"
	var fast: float = gs.estimate_zero_to_100()
	check(fast < base, "V8 + turbo duplo acelera mais (%.1f < %.1f)" % [fast, base])
	gs.new_profile()
