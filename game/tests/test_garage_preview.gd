extends TestCase
## T-171: previa da garagem (ver a peca no caminhao antes de comprar) e pneus apoiados SOBRE a plataforma do galpao.
## A previa nunca mexe no perfil nem no dinheiro; sair do cartao/encaixe/aba volta ao que esta equipado.

const IN_TREE := true          # monta a garagem de verdade (garage.tscn) no 1o quadro


func _gs() -> Node:
	return Engine.get_main_loop().root.get_node("GameState")


func _ids(defs: Array[PartDef]) -> Array:
	var out: Array = []
	for d in defs:
		out.append(String(d.id))
	out.sort()
	return out


## Pecas montadas de verdade no TruckNode (ids), para comparar com o perfil.
func _shown(t: TruckNode) -> Array:
	var out: Array = []
	for id in t._acc_nodes:
		var alive: bool = false
		for n in t._acc_nodes[id]:
			if is_instance_valid(n) and not n.is_queued_for_deletion():
				alive = true
		if alive:
			out.append(String(id))
	out.sort()
	return out


func _fresh_profile() -> Node:
	var gs: Node = _gs()
	gs.new_profile()
	gs.profile["money"] = 200000
	gs.profile["fame"] = 0
	gs.profile["paint"] = "#e9eef5"
	if gs.buy(gs.part("fb_basic")):
		gs.install("fb_basic")
	return gs


func test_preview_state_never_touches_profile() -> void:
	var gs: Node = _fresh_profile()
	var before: String = JSON.stringify(gs.profile)
	var pv := GaragePreview.new()
	check(not pv.active(), "comeca sem previa")
	pv.set_part("fb_gold_wing")
	check(pv.active() and pv.slot(gs) == "front_bumper", "previa do para-choque")
	var ids: Array = _ids(pv.loadout(gs))
	check("fb_gold_wing" in ids and not ("fb_basic" in ids), "a peca da previa substitui a do mesmo encaixe")
	check_eq(ids.size(), gs.installed_part_defs().size(), "as outras pecas continuam")
	pv.set_paint("#F0B83A")
	check(pv.part_id == "" and pv.paint(gs).is_equal_approx(Color("#f0b83a")), "uma previa por vez (cor tira a peca)")
	pv.clear()
	check_eq(_ids(pv.loadout(gs)), _ids(gs.installed_part_defs()), "clear: volta ao equipado")
	check(pv.paint(gs).is_equal_approx(Color("#e9eef5")), "clear: volta a cor do perfil")
	check_eq(JSON.stringify(gs.profile), before, "o perfil (dinheiro, pecas, cor) nao mudou com a previa")
	pv.set_part("fb_basic")
	check(pv.settle(gs) and not pv.active(), "previa de peca ja instalada acaba sozinha")


func test_garage_preview_reverts_and_buy_installs() -> void:
	var gs: Node = _fresh_profile()
	var scene: Node = (load("res://scenes/garage/garage.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(scene)
	var stage: GarageStage = scene.stage
	var money0: int = gs.money()
	var prof0: String = JSON.stringify(gs.profile)
	var equipped: Array = _ids(gs.installed_part_defs())
	var with_wing: Array = equipped.duplicate()
	with_wing.erase("fb_basic")
	with_wing.append("fb_gold_wing")
	with_wing.sort()
	check_eq(_shown(stage.truck), equipped, "garagem mostra o equipado")
	scene._set_tab("parts")
	scene._slot = "front_bumper"
	scene._refresh()
	scene.preview_part("fb_gold_wing")
	check_eq(_shown(stage.truck), with_wing, "previa: a peca aparece no caminhao (no lugar da instalada)")
	check_eq(stage.view, "front", "previa do para-choque leva a camera para a frente")
	check(scene._banner.visible and scene._tag.visible, "faixa e etiqueta PREVIA aparecem")
	check_eq(gs.money(), money0, "previa nao gasta dinheiro")
	check_eq(JSON.stringify(gs.profile), prof0, "previa nao muda o perfil")
	scene.preview_part("hub_gold")
	check_eq(stage.view, "wheel", "previa de calota leva a vista da roda")
	check(stage.wheel_spin, "... e as rodas giram para ver a calota")
	scene._set_tab("mech")                                  # trocar de aba = sair da previa
	check(not scene.preview.active(), "trocar de aba encerra a previa")
	check_eq(_shown(stage.truck), equipped, "voltou ao que estava equipado")
	check_eq(JSON.stringify(gs.profile), prof0, "perfil igual depois de sair da previa")
	scene._set_tab("parts")
	scene.preview_paint("#f0b83a")
	check(stage.truck.tint.is_equal_approx(Color("#f0b83a")), "cor travada aparece no caminhao")
	check_eq(String(gs.profile["paint"]), "#e9eef5", "... mas a cor do perfil nao muda")
	scene.end_preview()
	check(stage.truck.tint.is_equal_approx(Color("#e9eef5")), "VOLTAR AO ATUAL devolve a cor")
	gs.profile["fame"] = 500                                # calota dourada pede 30 de Fama
	scene.preview_part("hub_gold")
	scene._preview_buy_install()                            # COMPRAR E EQUIPAR
	check(gs.owns("hub_gold") and gs.installed_id("hubcaps") == "hub_gold", "comprar e equipar instala a peca")
	check_eq(gs.money(), money0 - gs.part("hub_gold").price, "... e cobra o preco uma vez")
	check(not scene.preview.active(), "depois de equipar a previa acaba (virou o caminhao de verdade)")
	scene.queue_free()


## Pneus sobre a plataforma: em todos os modelos e cabines o ponto mais baixo dos pneus fica no topo da plataforma
## giratoria do galpao (antes afundava 10 cm).
func test_wheels_rest_on_platform() -> void:
	var gs: Node = _gs()
	gs.new_profile()
	var stage := GarageStage.new()
	Engine.get_main_loop().root.add_child(stage)
	check_near(stage.floor_y, 0.1, 0.02, "topo da plataforma do galpao (garage_hall.glb)")
	var combos: Array = [["canter", "chata"]]
	for body in ["leve", "base", "longo", "graneleira"]:
		for cab in CabCatalog.IDS:
			combos.append([body, cab])
	for c in combos:
		stage.set_body(String(c[0]))
		stage.set_cab(String(c[1]))
		var t: TruckNode = stage.truck
		var low: float = t.position.y + TruckGround.wheel_bottom(t.model)
		check_near(low, stage.floor_y, 0.005, "%s/%s: pneu apoiado na plataforma" % [c[0], c[1]])
	stage.queue_free()
	gs.new_profile()


## A corrida nao muda: o TruckNode continua com o pneu em y = 0 (chao da pista) nos .glb.
func test_truck_models_touch_ground_at_zero() -> void:
	for body in ["leve", "base", "canter"]:
		var t := TruckNode.new()
		t.body_kind = body
		t._ready()
		check_near(TruckGround.wheel_bottom(t.model), 0.0, 0.005, "%s: pneu no chao (y = 0)" % body)
		check_near(t.position.y, 0.0, 0.0001, "%s: TruckNode sem deslocamento fora da garagem" % body)
		t.free()
