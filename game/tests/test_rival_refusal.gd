extends TestCase
## Rivais que recusam (ATB-2): cada rival exige Fama e destaque minimos e responde com uma fala curta.


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func test_every_rival_has_requirements_and_a_line() -> void:
	for id in ["rival_coast", "rival_urban", "rival_mountain", "boss_kanto"]:
		var rv: RivalDef = load("res://data/rivals/%s.tres" % id) as RivalDef
		check(rv.refuse_key != "", id + " tem fala de recusa")
		check(Tr.t(rv.refuse_key) != rv.refuse_key, id + ": a fala esta traduzida")
	var boss: RivalDef = load("res://data/rivals/boss_kanto.tres") as RivalDef
	var coast: RivalDef = load("res://data/rivals/rival_coast.tres") as RivalDef
	check(boss.min_fame > coast.min_fame and boss.min_destaque > coast.min_destaque, "o chefe exige mais que o primeiro rival")


func test_first_rival_always_accepts_a_new_player() -> void:
	var gs: Node = _gs()
	gs.new_profile()
	check(bool(gs.rival_refusal("kanto_1_coast")["ok"]), "o primeiro rival aceita quem esta comecando")


func test_rival_refuses_without_fame_or_destaque_then_accepts() -> void:
	var gs: Node = _gs()
	gs.new_profile()
	var r: Dictionary = gs.rival_refusal("kanto_3_mountain")
	check(not bool(r["ok"]), "o chefe recusa o novato")
	check(String(r["line"]) != "" and String(r["name"]) != "", "mostra nome e fala curta (%s)" % String(r["line"]))
	gs.profile["fame"] = 200
	check(not bool(gs.rival_refusal("kanto_3_mountain")["ok"]), "so Fama nao basta: falta destaque")
	gs.profile["paint"] = "#f0b83a"
	gs.profile["decals"] = [DecalCatalog.make("raio", "rear"), DecalCatalog.make("sol", "cab"), DecalCatalog.make("estrela", "side_l"), DecalCatalog.make("ondas", "side_r")]
	var need: int = int(r["min_destaque"])
	gs.profile["owned"]["fb_basic"]["dur"] = 1.0
	# destaque das pecas + 14 (dourado) + 24 (4 adesivos) ainda pode nao chegar a 140; completa com pecas caras
	for id in ["fb_gold_wing", "visor_gold_lights", "deck_led_box", "skirt_light_bar", "rb_chrome", "mural_lightning", "hub_gold"]:
		var d: PartDef = gs.part(id)
		if d != null:
			gs.add_owned(d)
			gs.profile["installed"][String(d.slot)] = id
	check(gs.destaque() >= need, "montagem decorada passa do minimo (%d >= %d)" % [gs.destaque(), need])
	check(bool(gs.rival_refusal("kanto_3_mountain")["ok"]), "com Fama e destaque o chefe aceita")
	gs.new_profile()


func test_refusal_blocks_the_contract() -> void:
	var gs: Node = _gs()
	gs.new_profile()
	gs.profile["fame"] = 100                       # libera o trecho (Fama) mas o destaque ainda e baixo
	var c: Dictionary = {"route": "kanto_3_mountain", "weight_t": 1.0}
	check_eq(gs.contract_block_reason(c), "RIVAL RECUSA", "contrato do trecho do chefe fica bloqueado")
	c["route"] = "kanto_1_coast"
	check_eq(gs.contract_block_reason(c), "", "o primeiro trecho continua livre")
	gs.new_profile()
