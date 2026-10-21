extends TestCase
## Seta / pisca (T-170): ritmo do pisca (SignalBlink), tique-taque e clique da alavanca (TurnSignalAudio),
## sem nos novos por tique, e a simulacao continua sem saber de nada disso.

const DT: float = RaceSim.FIXED_DT


func _rolling() -> Array:
	var tr := Track.new()
	tr.add_section(6000.0, 0.0)
	var sim := RaceSim.new(tr)
	var i := sim.add_truck(0.0, 0.0)
	sim.trucks[i].speed = 25.0
	return [sim, i]


func _audio() -> TurnSignalAudio:
	var a := TurnSignalAudio.new()
	a.setup(Node.new(), null, null)          # fora da arvore: so conta, nao toca
	return a


## Avanca `steps` passos com `dir` segurado, alimentando o som com o relogio da simulacao.
func _run(sim: RaceSim, i: int, a: TurnSignalAudio, dir: float, steps: int) -> void:
	for n in steps:
		sim.set_command(i, Commands.make(dir, 0.5, 0.0))
		sim.step()
		var t: TruckSim = sim.trucks[i]
		a.step(t.signal_dir, t.tap_prev, sim.time)


func test_blink_starts_lit_and_runs_at_about_1_5_hz() -> void:
	var b := SignalBlink.new()
	check_eq(b.update(1, 10.0), SignalBlink.Edge.LIT, "liga a seta: acende na hora")
	check(b.lit, "aceso no toque")
	check_eq(b.update(1, 10.0 + SignalBlink.HALF_S * 0.5), SignalBlink.Edge.NONE, "continua aceso")
	check_eq(b.update(1, 10.0 + SignalBlink.HALF_S + 0.01), SignalBlink.Edge.DARK, "apaga depois de HALF_S")
	check_eq(b.update(1, 10.0 + SignalBlink.HALF_S * 2.0 + 0.01), SignalBlink.Edge.LIT, "acende de novo")
	var hz: float = 1.0 / (SignalBlink.HALF_S * 2.0)
	check(hz > 1.3 and hz < 1.7, "~1,5 Hz (%.2f)" % hz)
	check_eq(b.update(0, 10.8), SignalBlink.Edge.DARK, "desligar com a lampada acesa apaga")
	check_eq(b.update(0, 11.0), SignalBlink.Edge.NONE, "desligada fica quieta")


func test_switching_side_restarts_cycle_lit() -> void:
	var b := SignalBlink.new()
	b.update(-1, 0.0)
	b.update(-1, SignalBlink.HALF_S + 0.05)
	check(not b.lit, "esquerda no meio do apagado")
	check_eq(b.update(1, SignalBlink.HALF_S + 0.06), SignalBlink.Edge.LIT, "trocar para a direita acende na hora")
	check_eq(b.dir, 1, "lado novo")


func test_first_tap_clicks_once_and_ticks_until_signal_expires() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	var a := _audio()
	_run(sim, r[1], a, 1.0, 3)
	check_eq(a.clicks, 1, "um clique da alavanca no toque")
	check_eq(a.ticks, 1, "tique na hora em que a seta acende")
	check(a.lit(), "seta acesa logo depois do toque")
	_run(sim, r[1], a, 0.0, int(TruckSim.LANE_SIGNAL_WINDOW / DT) + 10)
	check_eq(sim.trucks[r[1]].signal_dir, 0, "a seta apagou (janela de 1,5 s)")
	check_eq(a.clicks, 1, "segurar/soltar nao repete o clique")
	check_eq(a.ticks, 3, "1,5 s a 1,5 Hz = 3 acendidas (teve %d)" % a.ticks)
	check_eq(a.tocks, 3, "e 3 apagadas, a ultima quando a seta desliga (teve %d)" % a.tocks)
	check(not a.lit(), "nada acende depois")
	var before: int = a.ticks + a.tocks
	_run(sim, r[1], a, 0.0, 60)
	check_eq(a.ticks + a.tocks, before, "seta apagada: sem tique-taque")


func test_second_tap_changes_lane_with_click_and_stops_ticking() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	var a := _audio()
	_run(sim, r[1], a, 1.0, 3)
	_run(sim, r[1], a, 0.0, 3)
	_run(sim, r[1], a, 1.0, 3)
	check_eq(sim.trucks[r[1]].lane, Lanes.CENTER + 1, "2o toque trocou de faixa")
	check_eq(a.clicks, 2, "dois toques = dois cliques")
	check(not a.lit(), "a seta apaga ao trocar de faixa")
	var before: int = a.ticks + a.tocks
	_run(sim, r[1], a, 0.0, 60)
	check_eq(a.ticks + a.tocks, before, "depois da troca o tique-taque para")


func test_opposite_tap_clicks_again() -> void:
	var r := _rolling()
	var sim: RaceSim = r[0]
	var a := _audio()
	_run(sim, r[1], a, 1.0, 3)
	_run(sim, r[1], a, -1.0, 3)
	check_eq(a.clicks, 2, "trocar de lado e outro clique")
	check_eq(sim.trucks[r[1]].signal_dir, -1, "seta da esquerda")


func test_no_new_nodes_per_tick() -> void:
	if AudioServer.get_bus_index("SFX") < 0:  # no executor de testes o _ready do AudioBus pode ainda nao ter rodado
		Engine.get_main_loop().root.get_node("AudioBus").call("_setup_buses")
	var r := _rolling()
	var sim: RaceSim = r[0]
	var a := _audio()
	check_eq(a.get_child_count(), 2, "dois players fixos (tique e alavanca)")
	for k in 6:
		_run(sim, r[1], a, 1.0 if k % 2 == 0 else -1.0, 3)
		_run(sim, r[1], a, 0.0, 20)
	check_eq(a.get_child_count(), 2, "nenhum no novo depois de varios toques")
	for p in a.get_children():
		check_eq((p as AudioStreamPlayer).bus, &"SFX", "barramento SFX (volume e mudo das Opcoes)")
	a.get_parent().free()


func test_sound_files_exist_and_are_one_shots() -> void:
	for n in [TurnSignalAudio.TICK, TurnSignalAudio.SWITCH]:
		check(RaceAudio.has_sound(n), "som gerado: %s" % n)
		var s: AudioStream = Engine.get_main_loop().root.get_node("AudioBus").stream(n)
		if s is AudioStreamMP3:
			check(not (s as AudioStreamMP3).loop, "%s toca uma vez (o ritmo vem do SignalBlink)" % n)


func test_simulation_does_not_know_the_signal_presentation() -> void:
	var dir := DirAccess.open("res://scripts/sim/")
	for f in dir.get_files():
		if not f.ends_with(".gd"):
			continue
		var src: String = FileAccess.get_file_as_string("res://scripts/sim/" + f)
		check(not src.contains("SignalBlink") and not src.contains("TurnSignalAudio"), "sim/%s sem apresentacao da seta" % f)
