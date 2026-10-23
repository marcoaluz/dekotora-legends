extends TestCase
## T-202: o HUD novo montado na corrida de verdade (sem janela): pecas criadas, posicionadas pelo layout (inclusive o
## icone da camera, o retrovisor e os avisos de evento), modo celular, e nada disso mexe na simulacao.

const IN_TREE := true


func _snapshot(sim: RaceSim) -> Array:
	var out: Array = [sim.time]
	for t in sim.trucks:
		out.append_array([t.z, t.x, t.speed, t.rpm, t.gear, t.signal_dir, t.lane])
	return out


func test_hud_is_built_placed_and_read_only() -> void:
	var gs: Node = Engine.get_main_loop().root.get_node("GameState")
	gs.new_profile()
	gs.last_duel_key = ""
	gs.pending_route = load("res://data/routes/kanto_1_coast.tres") as RouteDef
	gs.pending_contract = {}
	var race: Node = (load("res://scenes/race/race3d.tscn") as PackedScene).instantiate()
	Engine.get_main_loop().root.add_child(race)
	var hud: RaceHud = race._hud
	check(hud != null and hud.gauge != null and hud.strip != null and hud.segments != null, "velocimetro, luzes e segmentos")
	check(hud != null and hud.clocks != null and hud.radar != null, "relogios e radar")
	if hud == null or race.sim == null or hud.gauge == null:
		race.free()
		return
	(race._intro as DuelIntro).skip()
	race._countdown = 0.0
	var sim: RaceSim = race.sim
	var before: Array = _snapshot(sim)
	for n in 5:
		race._update_hud()
		hud._process(1.0 / 60.0)
	check_eq(_snapshot(sim), before, "o HUD so le a simulacao")
	check(hud.event_hud != null and hud.event_hud.alert_top >= hud.layout.mirror_top + HudLayout.MIRROR.y,
			"avisos de evento abaixo do retrovisor")
	if hud.cam_button != null:
		check_eq(hud.cam_button.position, hud.layout.cam_at.round(), "icone da camera posto pelo layout")
	check_eq(hud.segments.truck, sim.trucks[race.player], "segmentos leem o caminhao do jogador")
	# modo celular na mesma corrida: o layout refaz e o painel fica longe dos botoes
	hud.touch_layout = true
	hud._apply_layout()
	for r in hud.layout.cluster_rects():
		check(hud.layout._clear(r), "celular: %s longe dos botoes" % r)
	check_eq(hud.gauge.position, hud.layout.gauge_at.round(), "velocimetro reposicionado")
	race.free()
	gs.last_duel_key = ""
	gs.pending_route = null
	gs.new_profile()
