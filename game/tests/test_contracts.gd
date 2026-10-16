extends TestCase
## Mercado de fretes: geracao dos contratos, capacidade do bau, valor e efeito da carga na simulacao.


func _gs() -> Node:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	return gs


func test_generate_is_deterministic_and_fits_capacity() -> void:
	var routes: Array[RouteDef] = FreightMarket.all_routes()
	var all := func(_r: RouteDef) -> bool: return true
	var a: Array[Dictionary] = Contracts.generate(1234, routes, all, "leve")
	var b: Array[Dictionary] = Contracts.generate(1234, routes, all, "leve")
	check_eq(a.size(), routes.size() * Contracts.PER_ROUTE, "2 contratos por trecho liberado")
	check_eq(JSON.stringify(a), JSON.stringify(b), "mesma semente = mesmo quadro")
	for r in routes:                                  # o primeiro de cada trecho cabe no bau leve (6 t)
		var first: Dictionary = {}
		for c in a:
			if String(c["route"]) == String(r.id):
				first = c
				break
		check(float(first["weight_t"]) <= 6.0, "primeiro contrato de %s cabe no bau leve" % r.id)
		check(String(first["origin"]) != String(first["destination"]), "origem diferente do destino")
		check(String(first["origin"]) in r.places, "origem e uma cidade do trecho")


func test_locked_routes_have_no_contracts() -> void:
	var gs: Node = _gs()
	for c in gs.contract_board():
		var r: RouteDef = load("res://data/routes/%s.tres" % c["route"]) as RouteDef
		check(gs.route_unlocked(r), "so trechos liberados (Fama 0 = so o trecho 1)")


func test_reward_grows_with_weight_and_cargo() -> void:
	var r: RouteDef = load("res://data/routes/kanto_1_coast.tres") as RouteDef
	var steel: CargoDef = load("res://data/cargo/aco.tres") as CargoDef
	var light: int = Contracts.reward(r, steel, steel.weight_min_t)
	var heavy: int = Contracts.reward(r, steel, steel.weight_max_t)
	check(heavy > light, "carga mais pesada paga mais")
	check_eq(light % 50, 0, "valor arredondado de 50 em 50")


func test_capacity_blocks_heavy_contract() -> void:
	var gs: Node = _gs()
	gs.profile["body"] = "leve"
	check_eq(gs.contract_block_reason({"weight_t": 9.0}), "BAÚ PEQUENO", "9 t nao cabe no bau leve")
	gs.profile["body"] = "longo"
	check_eq(gs.contract_block_reason({"weight_t": 15.0}), "", "15 t cabe no bau longo")


func test_contract_cargo_changes_mass_and_fragility() -> void:
	var gs: Node = _gs()
	var t0 := TruckSim.new()
	gs.configure_truck(t0)
	gs.pending_contract = {"weight_t": 14.0, "fragility": 2.0, "reward": 30000, "route": "kanto_1_coast"}
	var t1 := TruckSim.new()
	gs.configure_truck(t1)
	check_near(t1.mass - t0.mass, 14000.0 - TruckSim.DEFAULT_CARGO, 0.01, "carga do contrato entra na massa")
	check_near(t1.cargo_fragility, 2.0, 0.001, "fragilidade da carga")
	var tn := TruckSim.new()
	DamageModel._hurt_system(t0, "cargo", 100.0)
	DamageModel._hurt_system(t1, "cargo", 100.0)
	check(float(t1.systems["cargo"]) < float(t0.systems["cargo"]), "carga fragil estraga mais com o mesmo impacto")
	check_near(tn.cargo_fragility, 1.0, 0.001, "sem contrato = fragilidade normal")
	gs.pending_contract = {}


func test_completing_contract_records_history_and_new_board() -> void:
	var gs: Node = _gs()
	var board: Array = gs.contract_board()
	var c: Dictionary = board[0]
	var old_seed: int = int(gs.contracts_state()["seed"])
	gs.accept_contract(c)
	check(gs.pending_route != null, "aceitar define o trecho")
	var t := TruckSim.new()
	gs.configure_truck(t)
	gs.apply_race_result({"pay": int(c["reward"]), "fame": 5, "time": 120.0, "position": 1}, String(c["route"]), t)
	var st: Dictionary = gs.contracts_state()
	check_eq((st["done"] as Array).size(), 1, "historico guarda o frete concluido")
	check(int(st["seed"]) != old_seed, "quadro novo depois de concluir")
	check(gs.pending_contract.is_empty(), "contrato pendente limpo")
	gs.pending_route = null
