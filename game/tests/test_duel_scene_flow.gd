extends TestCase
## T-156: a corrida de verdade (race3d.tscn, sem tela): campanha 1 contra 1 com a abertura cheia, toque pula para a
## contagem, revanche = versao curta, corrida rapida = 4 caminhoes com a versao curta.

const IN_TREE := true          # roda no 1o quadro (run_tests.gd): a cena precisa do _ready e de /root/...


func _race(route_id: String) -> Node:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.pending_route = load("res://data/routes/%s.tres" % route_id) as RouteDef if route_id != "" else null
	gs.pending_contract = {}
	var scene: Node = (load("res://scenes/race/race3d.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	return scene


func test_campaign_is_one_on_one_with_full_intro_skip_and_short_rematch() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.last_duel_key = ""
	var race: Node = _race("kanto_1_coast")
	check(race.sim != null and race._intro != null, "a corrida montou")
	if race.sim == null or race._intro == null:
		return
	var sim: RaceSim = race.sim
	check_eq(sim.trucks.size(), 2, "campanha: jogador + rival da rota (1 contra 1)")
	check(sim.trucks[1].is_bot and not sim.trucks[0].is_bot, "o 2o caminhao e o rival")
	check_near(sim.trucks[0].z, sim.trucks[1].z, 0.001, "largam lado a lado")
	var intro: DuelIntro = race._intro
	check_eq(intro.kind, DuelPlan.FULL, "1a vez contra o rival: abertura cheia")
	check(intro.running() and not race._hud_layer.visible, "durante a abertura o HUD some")
	var z0: float = sim.trucks[0].z
	for n in 10:
		race._process(0.1)
	check(intro.running() and intro.t > 0.9, "a abertura anda (%.1f s)" % intro.t)
	check_near(sim.trucks[0].z, z0, 0.001, "a simulacao espera na largada")
	check(intro.stage != null and race._trucks[0].global_position.y < -300.0, "os caminhoes de verdade estao no cenario do duelo")
	intro.skip()
	check(not intro.running(), "um toque pula a abertura")
	check_near(race._countdown, Protocol.COUNTDOWN_SECONDS, 0.001, "... e vai para a contagem de 3 s")
	check(race._hud_layer.visible, "HUD volta")
	check(race._trucks[0].global_position.y > -50.0, "caminhoes de volta na pista")
	race.free()
	var again: Node = _race("kanto_1_coast")
	check_eq((again._intro as DuelIntro).kind, DuelPlan.SHORT, "revanche (mesma rota e rival): versao curta")
	check(not (again._intro as DuelIntro).running(), "a curta e so a contagem com o alinhamento")
	again.free()
	gs.last_duel_key = ""
	gs.pending_route = null
	gs.new_profile()


func test_quick_race_keeps_four_trucks_with_short_intro() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	var race: Node = _race("")
	check(race.sim != null and race._intro != null, "a corrida montou")
	if race.sim == null or race._intro == null:
		return
	check_eq((race.sim as RaceSim).trucks.size(), StartGrid.QUICK_TRUCKS, "corrida rapida: jogador + 3 bots")
	check_eq((race._intro as DuelIntro).kind, DuelPlan.SHORT, "sem rival da rota: versao curta")
	race.free()
	gs.new_profile()
