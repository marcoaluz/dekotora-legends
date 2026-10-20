extends TestCase
## T-156: abertura "frente a frente" antes da largada, campanha 1 contra 1, grid lado a lado, comboio online.


func test_timeline_full_is_8_to_10_s_and_short_is_3_s() -> void:
	var full: float = DuelPlan.total_seconds(DuelPlan.FULL)
	check(full >= 8.0 and full <= 10.0, "abertura cheia + contagem entre 8 e 10 s (%.1f)" % full)
	check_near(DuelPlan.total_seconds(DuelPlan.SHORT), 3.0, 0.001, "versao curta = so a contagem (3 s)")
	check_near(DuelPlan.intro_seconds(DuelPlan.NONE), 0.0, 0.001, "sem abertura")
	var names: Array[String] = []
	var t: float = 0.0
	while t < DuelPlan.intro_seconds(DuelPlan.FULL) + 0.5:
		var ph: String = String(DuelPlan.phase_at(t)[0])
		if names.is_empty() or names[-1] != ph:
			names.append(ph)
		t += 0.05
	check_eq(",".join(names), "face,player,rival,vs,count", "ordem: frente a frente, jogador, rival, VS, contagem")
	var details: Array[String] = []
	for p in [0.1, 0.45, 0.8]:
		details.append(String(DuelPlan.detail_at("player", p)[0]))
	check_eq(",".join(details), "bumper,visor,mural", "detalhes do jogador: para-choque, viseira (andon), mural")
	check(DuelPlan.ALIGN_S + RaceCinema.START_CUT_BEFORE <= Protocol.COUNTDOWN_SECONDS + 0.001, "alinhamento cabe antes do corte da largada")


func test_offline_full_first_short_on_rematch_and_quick_race() -> void:
	check_eq(DuelPlan.pick_offline(true, 2, false), DuelPlan.FULL, "campanha 1x1: cena cheia")
	check_eq(DuelPlan.pick_offline(true, 2, true), DuelPlan.SHORT, "revanche: versao curta")
	check_eq(DuelPlan.pick_offline(false, 4, false), DuelPlan.SHORT, "corrida rapida (4 caminhoes): versao curta")
	check_eq(DuelPlan.pick_offline(true, 2, false, "none"), DuelPlan.NONE, "--intro=none desliga")


func test_online_two_players_full_three_four_short() -> void:
	check_eq(DuelPlan.pick_online(2, 2, false), DuelPlan.FULL, "2 jogadores: a mesma cena")
	check_eq(DuelPlan.pick_online(2, 3, false), DuelPlan.FULL, "2 jogadores + bot: a cena e dos dois humanos")
	check_eq(DuelPlan.pick_online(3, 3, false), DuelPlan.SHORT, "3 jogadores: curta")
	check_eq(DuelPlan.pick_online(4, 4, false), DuelPlan.SHORT, "4 jogadores: curta")
	check_eq(DuelPlan.pick_online(1, 2, false), DuelPlan.FULL, "1 jogador x 1 bot: duelo")
	check_eq(DuelPlan.pick_online(2, 2, true), DuelPlan.SHORT, "revanche online: curta")
	var grid: Array = [{"idx": 0, "bot": false}, {"idx": 1, "bot": true}, {"idx": 2, "bot": false}]
	check_eq(DuelPlan.online_pair(grid, 2), [2, 0] as Array[int], "o outro humano e o rival da cena")
	check_eq(DuelPlan.convoy_traffic(1, 3), 0, "comboio: transito um nivel mais leve")
	check_eq(DuelPlan.convoy_traffic(2, 2), 2, "2 jogadores: transito da regra")


## Dois clientes com chegada do setup e ping diferentes calculam o MESMO instante do servidor.
func test_online_clock_is_the_same_for_every_client() -> void:
	var total: float = DuelPlan.total_seconds(DuelPlan.FULL)
	# servidor manda o setup em T0 = 10.000 ms (relogio comum do teste); A recebe com 20 ms, B com 100 ms
	var a_recv: int = 10020
	var b_recv: int = 10100
	for now in [10500, 13000, 19000]:
		var ea: float = DuelPlan.online_elapsed(total, total, a_recv, now, 40)     # ping 40 ms (ida 20)
		var eb: float = DuelPlan.online_elapsed(total, total, b_recv, now, 200)    # ping 200 ms (ida 100)
		check_near(ea, eb, 0.001, "mesmo relogio em %d ms" % now)
		check_near(ea, float(now - 10000) / 1000.0, 0.001, "igual ao do servidor")


func test_start_grid_side_by_side_no_negative_z() -> void:
	var a: Vector2 = StartGrid.slot(0, 2)
	var b: Vector2 = StartGrid.slot(1, 2)
	check_near(a.x, b.x, 0.001, "1x1: lado a lado (mesmo z)")
	check(absf(a.y - b.y) >= 0.49, "1x1: faixas vizinhas")
	check(a.x >= 15.0, "espaco de asfalto atras para a camera (z=%.0f)" % a.x)
	var zs: Array[float] = []
	for i in 4:
		var g: Vector2 = StartGrid.slot(i, 4)
		check(g.x >= 0.0, "ninguem antes do comeco da pista")
		zs.append(g.x)
	check(zs[0] == zs[1] and zs[1] == zs[2] and zs[3] < zs[0], "4: tres lado a lado e um atras")
	check_eq(StartGrid.CAMPAIGN_TRUCKS, 2, "campanha = 1 contra 1")


func _room(humans: int) -> Room:
	var r := Room.new("DUELO1")
	for i in humans:
		r.add_member(100 + i, "P%d" % i, "CODE%d" % i, TruckConfig.basic_descriptor())
	r.set_rules(100, {"bots": 0, "traffic": 1, "events": false})
	for p in r.order:
		r.set_ready(p, true)
	return r


func test_room_two_players_waits_the_whole_intro_then_races() -> void:
	var r: Room = _room(2)
	r.try_start(100, 5)
	var setup: Dictionary = r.race_setup()
	check_eq(String(setup["intro"]), DuelPlan.FULL, "2 jogadores: abertura cheia no setup")
	check_near(float(setup["countdown_total"]), DuelPlan.total_seconds(DuelPlan.FULL), 0.001, "contagem do servidor = abertura + 3 s")
	r.advance(DuelPlan.total_seconds(DuelPlan.FULL) - 0.2)
	check_eq(r.state, Protocol.RoomState.COUNTDOWN, "ainda na abertura")
	r.advance(0.3)
	check_eq(r.state, Protocol.RoomState.RACING, "largou no fim da contagem")
	var c := ClientSync.new()
	c.setup(setup, 1)
	for i in r.sim.trucks.size():
		check_near(c.sim.trucks[i].z, r.sim.trucks[i].z, 0.001, "cliente monta o mesmo grid (z) %d" % i)
		check_near(c.sim.trucks[i].x, r.sim.trucks[i].x, 0.001, "cliente monta o mesmo grid (x) %d" % i)


func test_room_convoy_three_players_short_and_lighter_traffic_then_rematch() -> void:
	var r: Room = _room(3)
	r.try_start(100, 6)
	var setup: Dictionary = r.race_setup()
	check_eq(String(setup["intro"]), DuelPlan.SHORT, "3 jogadores: versao curta")
	check_eq(int(setup["rules"]["traffic"]), 0, "comboio: transito mais leve (1 -> 0)")
	check(bool(setup["rules"]["convoy"]), "setup marca o comboio")
	check_eq(int(r.rules["traffic"]), 1, "a regra da sala nao muda")
	var r2: Room = _room(2)
	r2.try_start(100, 7)
	check_eq(r2.intro, DuelPlan.FULL, "1a corrida da dupla: cheia")
	r2.state = Protocol.RoomState.LOBBY            # volta ao lobby (como depois do resultado)
	for p in r2.order:
		r2.set_ready(p, true)
	r2.try_start(100, 8)
	check_eq(r2.intro, DuelPlan.SHORT, "mesma dupla e mesma rota de novo: revanche curta")


func test_cards_use_real_data() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	var p: Dictionary = DuelCards.player(gs, 3)
	check(String(p["driver"]) != "" and String(p["line"]) != "" and not String(p["line"]).begins_with("intro."), "faixa do jogador com nome e fala")
	check_eq(int(p["destaque"]), int(gs.destaque()), "destaque do jogador = o da garagem")
	for id in ["rival_coast", "rival_urban", "rival_mountain", "boss_kanto"]:
		var rv: RivalDef = load("res://data/rivals/%s.tres" % id) as RivalDef
		var t := TruckSim.new()
		var parts: Array[Dictionary] = []
		for pid in rv.part_ids:
			var d: PartDef = gs.part(String(pid))
			if d != null:
				parts.append(d.to_sim_part())
		t.set_loadout(parts)
		var c: Dictionary = DuelCards.rival(rv, t)
		check(rv.crest != "" and String(c["truck"]) != "" and not String(c["truck"]).begins_with("rival."), "%s: brasao e nome do caminhao" % id)
		check(String(c["line"]) != "" and not String(c["line"]).begins_with("rival."), "%s: fala de provocacao" % id)
		check(int(c["destaque"]) > 0, "%s: destaque das pecas (%d)" % [id, int(c["destaque"])])
	gs.new_profile()
