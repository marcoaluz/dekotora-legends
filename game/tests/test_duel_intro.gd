extends TestCase
## T-156: abertura do duelo antes da largada, campanha 1 contra 1, grid lado a lado, comboio online.
## T-204: abertura nova (estudio preto, guardioes, titulo, raio com clarao seguro, arrancada).
## T-208: mais lenta (8,9 s de cena + 3 s de contagem), relogio a partir do 1o quadro liso, servidor espera todos.


func test_timeline_full_is_8_9_s_plus_countdown_and_short_is_3_s() -> void:
	check_near(DuelPlan.total_seconds(DuelPlan.FULL), 11.9, 0.001, "T-208: abertura cheia + contagem = 11,9 s")
	check_near(DuelPlan.intro_seconds(DuelPlan.FULL), 8.9, 0.001, "8,9 s de cena antes da contagem de 3 s")
	check_near(DuelPlan.total_seconds(DuelPlan.SHORT), 3.0, 0.001, "versao curta = so a contagem (3 s)")
	check_near(DuelPlan.intro_seconds(DuelPlan.NONE), 0.0, 0.001, "sem abertura")
	var names: Array[String] = []
	var t: float = 0.0
	while t < DuelPlan.intro_seconds(DuelPlan.FULL) + 0.5:
		var ph: String = String(DuelPlan.phase_at(t)[0])
		if names.is_empty() or names[-1] != ph:
			names.append(ph)
		t += 0.05
	check_eq(",".join(names), "enter,guard,title,bands,bolt,launch,count", "ordem: entrada, guardioes, titulo, faixas, raio, arrancada, contagem")
	check(DuelPlan.BOLT_AT >= DuelPlan.phase_start("bolt") and DuelPlan.BOLT_AT < DuelPlan.phase_start("launch"), "o raio cai na fase do raio")
	# T-208: cada etapa respira (tempo de leitura)
	check(DuelPlan.phase_len("enter") >= 2.4, "entrada dos caminhoes sem pressa")
	check(DuelPlan.phase_len("enter") * (1.0 - DuelShots.STOP_AT) >= 0.4, "uma pausa com os caminhoes parados antes dos guardioes")
	check(DuelPlan.phase_len("guard") >= DuelPlan.GUARD_RISE_S + 0.2, "guardioes sobem e ficam um instante sozinhos")
	check(DuelPlan.phase_len("title") >= 1.0, "titulo 対決 sozinho por pelo menos 1 s")
	var read_bands: float = DuelPlan.phase_start("launch") - DuelPlan.phase_start("bands") - DuelPlan.BANDS_SLIDE_S
	check(read_bands >= 2.2, "faixas dos pilotos paradas e legiveis por %.1f s" % read_bands)
	var read_title: float = DuelPlan.phase_start("launch") - DuelPlan.phase_start("title")
	check(read_title >= 3.5, "titulo na tela por %.1f s" % read_title)
	check(DuelPlan.BOLT_AT - DuelPlan.phase_start("bolt") >= 0.1 and DuelPlan.phase_start("launch") - DuelPlan.BOLT_AT >= 0.6, "raio com respiro antes e depois (trovao)")
	check(DuelPlan.phase_len("launch") >= 0.9, "arrancada inteira antes do corte")
	for st in DuelPlan.SHOT_TIMES:
		check(st < DuelPlan.intro_seconds(DuelPlan.FULL), "print %.2f s dentro da cena" % st)
	for st in DuelPlan.COUNT_SHOT_TIMES:
		check(st > DuelPlan.intro_seconds(DuelPlan.FULL) and st < DuelPlan.total_seconds(DuelPlan.FULL), "print %.2f s na contagem" % st)
	check(DuelPlan.ALIGN_S + RaceCinema.START_CUT_BEFORE <= Protocol.COUNTDOWN_SECONDS + 0.001, "alinhamento cabe antes do corte da largada")


## T-204: fotossensibilidade. Um unico clarao branco de ~0,15 s (nunca mais de 1 por segundo); com "reduzir
## claroes" nenhuma tela branca, so um brilho violeta suave e lento.
func test_single_short_flash_and_reduced_mode() -> void:
	var dt: float = 1.0 / 240.0
	var rises: int = 0
	var lit: float = 0.0
	var was: bool = false
	var max_soft: float = 0.0
	var reduced_white: float = 0.0
	var extra_soft: float = 0.0
	var t: float = 0.0
	while t < DuelPlan.total_seconds(DuelPlan.FULL):
		var a: float = DuelPlan.flash_alpha(t, false)
		if a > 0.0 and not was:
			rises += 1
		if a > 0.0:
			lit += dt
		was = a > 0.0
		reduced_white = maxf(reduced_white, DuelPlan.flash_alpha(t, true))
		max_soft = maxf(max_soft, DuelPlan.soft_alpha(t, true))
		extra_soft = maxf(extra_soft, DuelPlan.soft_alpha(t, false))
		t += dt
	check_eq(rises, 1, "um clarao so")
	check(lit <= 0.16 and lit >= 0.1, "clarao curto (%.3f s)" % lit)
	check(DuelPlan.FLASH_PEAK < 1.0, "pico abaixo do branco total")
	check_eq(reduced_white, 0.0, "reduzir claroes: nenhuma tela branca")
	check(max_soft > 0.05 and max_soft <= 0.25, "reduzir claroes: brilho suave (%.2f)" % max_soft)
	check_eq(extra_soft, 0.0, "sem o modo reduzido nao ha brilho violeta extra")
	var bright: int = 0
	var on: bool = false
	t = 0.0
	while t < DuelPlan.total_seconds(DuelPlan.FULL):                 # o raio aparece uma vez (sem re-piscar)
		var b: bool = DuelPlan.bolt_state(t, false).y > 0.0
		if b and not on:
			bright += 1
		on = b
		t += dt
	check_eq(bright, 1, "um raio so")
	check(DuelPlan.bolt_state(DuelPlan.BOLT_AT + 0.05, true).y < DuelPlan.bolt_state(DuelPlan.BOLT_AT + 0.05, false).y, "raio mais fraco no modo reduzido")


func test_overlay_curves() -> void:
	check_near(DuelPlan.black_alpha(0.0), 1.0, 0.001, "comeca na tela preta")
	check_near(DuelPlan.black_alpha(1.0), 0.0, 0.001, "a cena aparece")
	check_near(DuelPlan.black_alpha(DuelPlan.intro_seconds(DuelPlan.FULL) - 0.001), 1.0, 0.02, "corte seco para a pista")
	var title0: float = DuelPlan.phase_start("title")
	check_eq(DuelPlan.title_state(title0 - 0.05).y, 0.0, "titulo antes do tambor: escondido")
	check_near(DuelPlan.title_state(title0 + 0.3).x, 1.0, 0.001, "titulo assentado depois da batida")
	check_near(DuelPlan.title_state(title0 + 0.3).y, 1.0, 0.001, "titulo visivel")
	check(DuelPlan.title_state(title0 + 0.02).x > 1.5, "titulo entra grande (batida)")
	check_eq(DuelPlan.bands_in(title0 + 0.6), 0.0, "T-208: o titulo entra sozinho (faixas depois)")
	check_near(DuelPlan.bands_in(DuelPlan.phase_start("bands") + 0.5), 1.0, 0.001, "faixas dos dois pilotos embaixo")
	check_near(DuelPlan.bands_in(DuelPlan.phase_start("launch") + 0.3), 0.0, 0.001, "faixas saem na arrancada")
	check_eq(DuelPlan.guard_in(DuelPlan.phase_start("guard") - 0.01), 0.0, "guardioes so depois da entrada")
	check_near(DuelPlan.guard_in(title0), 1.0, 0.001, "guardioes inteiros no titulo")


## Os caminhoes entram pelos lados em angulo, param lado a lado de frente para a camera e arrancam para ela.
func test_truck_moves_enter_stop_side_by_side_and_launch() -> void:
	for n in 2:
		var side: float = -1.0 if n == 0 else 1.0
		var a: Dictionary = DuelShots.truck_pose(n, 0.0)
		var nose: Vector3 = a["nose"]
		var dir: Vector3 = a["dir"]
		check(nose.x * side > 25.0 and nose.z < -20.0, "%d: vem de longe, pelo lado da tela (%.1f, %.1f)" % [n, nose.x, nose.z])
		check(dir.x * side < -0.4 and dir.z > 0.3, "%d: entra em angulo, para dentro e para a camera" % n)
		var parked: Dictionary = DuelShots.truck_pose(n, DuelPlan.phase_start("guard"))
		check(Vector3(parked["nose"]).distance_to(Vector3(side * DuelShots.SIDE_X, 0, 0)) < 0.001, "%d: parado no lugar" % n)
		check(Vector3(parked["dir"]).distance_to(Vector3(0, 0, 1)) < 0.001, "%d: de frente para a camera" % n)
		check_eq(float(parked["speed"]), 0.0, "%d: parado" % n)
		var last: float = 999.0
		var t: float = 0.0
		var braking: bool = true
		while t < DuelPlan.phase_len("enter") * DuelShots.STOP_AT:
			var sp: float = float(DuelShots.truck_pose(n, t)["speed"])
			braking = braking and sp <= last + 0.001
			last = sp
			t += 0.1
		check(braking, "%d: so freia na entrada" % n)
		check(float(a["speed"]) < 40.0, "%d: entrada sem velocidade absurda (%.0f m/s)" % [n, float(a["speed"])])
		var go: Dictionary = DuelShots.truck_pose(n, DuelPlan.intro_seconds(DuelPlan.FULL) - 0.01)
		check(Vector3(go["nose"]).z > 5.0 and float(go["speed"]) > 15.0, "%d: arranca para a camera" % n)
	check(Vector3(DuelShots.truck_pose(0, 3.0)["nose"]).x < 0.0, "jogador na esquerda da tela, rival na direita")
	var xf: Transform3D = DuelShots.truck_xform({"nose": Vector3(1, 0, 2), "dir": Vector3(0, 0, 1), "speed": 0.0}, 11.4)
	check((xf.basis * Vector3(0, 0, -1)).distance_to(Vector3(0, 0, 1)) < 0.001, "frente do TruckNode (-Z) aponta para a camera")
	check(xf.origin.distance_to(Vector3(1, 0, 2 - 11.4)) < 0.001, "traseira atras do nariz")


func test_launch_lens_between_the_trucks() -> void:
	var end_t: float = DuelPlan.intro_seconds(DuelPlan.FULL) - 0.01
	var v: Array = DuelShots.studio_view(end_t, false)
	var cam: Vector3 = v[0]
	check(absf(cam.x) < 0.5 and cam.y < 1.5, "camera baixa no meio")
	check(DuelShots.SIDE_X - 1.3 > absf(cam.x) + 0.8, "os caminhoes passam dos lados, sem atravessar a camera")
	check(Vector3(DuelShots.truck_pose(0, end_t)["nose"]).z < cam.z - 1.0, "o nariz nao passa da lente")
	var shake: Array = DuelShots.studio_view(DuelPlan.BOLT_AT + 0.05, false)
	var calm: Array = DuelShots.studio_view(DuelPlan.BOLT_AT + 0.05, true)
	check(Vector3(shake[0]).distance_to(Vector3(calm[0])) > 0.001, "tremor da camera no raio (so no modo normal)")
	var before: Array = DuelShots.studio_view(DuelPlan.BOLT_AT - 0.001, true)
	check(Vector3(calm[0]).distance_to(Vector3(before[0])) < 0.05, "modo reduzido: camera sem tranco")


func test_bolt_is_seeded_and_grows_from_the_sky() -> void:
	var p1: Array[PackedVector2Array] = DuelBolt.paths(Vector2(250, -10), Vector2(240, 200))
	var p2: Array[PackedVector2Array] = DuelBolt.paths(Vector2(250, -10), Vector2(240, 200))
	check_eq(p1.size(), p2.size(), "mesmo numero de galhos")
	check(p1[0] == p2[0], "mesmo raio em todos os clientes")
	check(p1[0][0] == Vector2(250, -10) and p1[0][p1[0].size() - 1] == Vector2(240, 200), "do ceu ao chao entre os caminhoes")
	var half: PackedVector2Array = DuelBolt.grown(p1[0], 0.5)
	check(half.size() < p1[0].size() and half[half.size() - 1].y < 150.0, "o raio desce do ceu")


func test_reduce_flash_option_saved_and_assets() -> void:
	var st: Node = Engine.get_main_loop().root.get_node("Settings")
	var was: bool = st.fx_reduce_flash
	var path: String = "user://test_t204_settings.cfg"
	st.fx_reduce_flash = true
	st.save_settings(path)
	st.fx_reduce_flash = false
	st.load_settings(path)
	check(st.fx_reduce_flash, "opcao reduzir claroes gravada")
	st.fx_reduce_flash = was
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	check(ResourceLoader.exists("res://assets/textures/duel/raijin.png") and ResourceLoader.exists("res://assets/textures/duel/fujin.png"), "arte dos guardioes")
	check(ResourceLoader.exists("res://assets/textures/duel/title_taiketsu.png"), "titulo 対決")
	check(RaceAudio.has_sound("duel_thunder") and RaceAudio.has_sound("vs_taiko_hit"), "trovao e taiko")
	check(Protocol.VERSION >= 11, "protocolo 11 (T-208: abertura de 11,9 s e o servidor espera todos montarem a corrida)")


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
	# T-208: a sala espera os dois montarem a corrida (um celular lento nao perde a abertura)
	check(r.loading, "depois do setup: esperando os jogadores montarem a corrida")
	r.mark_loaded(100)
	for i in 50:
		r.advance(0.1)
	check(r.loading and r.state == Protocol.RoomState.COUNTDOWN, "um montou, o outro ainda nao: o relogio nao anda")
	check_near(r.countdown, DuelPlan.total_seconds(DuelPlan.FULL), 0.001, "a contagem continua cheia")
	r.mark_loaded(101)
	r.advance(0.1)
	check(not r.loading, "os dois prontos: o relogio comum comeca")
	check_near(r.countdown, DuelPlan.total_seconds(DuelPlan.FULL), 0.001, "o quadro do aviso nao conta")
	r.advance(DuelPlan.total_seconds(DuelPlan.FULL) - 0.2)
	check_eq(r.state, Protocol.RoomState.COUNTDOWN, "ainda na abertura")
	r.advance(0.3)
	check_eq(r.state, Protocol.RoomState.RACING, "largou no fim da contagem")
	var c := ClientSync.new()
	c.setup(setup, 1)
	for i in r.sim.trucks.size():
		check_near(c.sim.trucks[i].z, r.sim.trucks[i].z, 0.001, "cliente monta o mesmo grid (z) %d" % i)
		check_near(c.sim.trucks[i].x, r.sim.trucks[i].x, 0.001, "cliente monta o mesmo grid (x) %d" % i)


## T-208: quem nunca avisa (celular travado) nao segura a sala para sempre; desconectado nao conta.
func test_room_load_wait_has_a_limit_and_ignores_disconnected() -> void:
	var r: Room = _room(2)
	r.try_start(100, 9)
	r.mark_loaded(100)
	var t: float = 0.0
	while r.loading and t < Protocol.LOAD_WAIT_MAX + 1.0:
		r.advance(0.5)
		t += 0.5
	check(not r.loading, "limite de espera (%.0f s)" % Protocol.LOAD_WAIT_MAX)
	check(t >= Protocol.LOAD_WAIT_MAX - 0.01, "esperou o limite inteiro (%.1f s)" % t)
	var r2: Room = _room(2)
	r2.try_start(100, 10)
	r2.mark_loaded(100)
	(r2.members[101] as Room.Member).connected = false
	r2.advance(0.1)
	check(not r2.loading, "o outro caiu: comeca com quem ficou")


## T-208: no cliente o relogio comum fica parado em 0 ate o servidor avisar (s_state COUNTDOWN) e entao conta daquele instante.
func test_client_clock_waits_for_the_server_start() -> void:
	var was_setup: Dictionary = Net.pending_setup
	var was_msec: int = Net.pending_setup_msec
	var was_started: bool = Net.race_clock_started
	var was_state: int = Net.room_state
	var was_truck: int = Net.pending_truck
	Net.s_race_setup({"countdown": 11.9, "countdown_total": 11.9, "intro": DuelPlan.FULL}, 0)
	check(not Net.race_clock_started, "setup chegou: relogio parado")
	Net.pending_setup["countdown"] = 5.0                          # o setup antigo nao importa mais
	Net.s_state(Protocol.RoomState.COUNTDOWN)
	check(Net.race_clock_started, "servidor avisou: relogio andando")
	check_near(float(Net.pending_setup["countdown"]), 11.9, 0.001, "conta a abertura inteira a partir do aviso")
	check(absi(Net.pending_setup_msec - Time.get_ticks_msec()) < 50, "a partir de agora")
	Net.pending_setup = was_setup
	Net.pending_setup_msec = was_msec
	Net.race_clock_started = was_started
	Net.room_state = was_state
	Net.pending_truck = was_truck


## T-208: a preparacao (tela preta + neblina) segura o relogio em 0; offline comeca sozinho quando os quadros ficam
## lisos, online so com o relogio do servidor; tocar nao pula a preparacao online.
func test_preparation_holds_the_clock_until_smooth() -> void:
	var intro := DuelIntro.new()
	intro.band = DuelBand.new()
	intro.kind = DuelPlan.FULL
	intro.preparing = true
	intro.clock_started = false
	intro.online = true
	var cam := Camera3D.new()
	intro.stage = DuelStage.new()
	intro.stage.build(1)
	for i in 8:
		intro.update_to(5.0, 0.016, cam)
	check(intro.preparing and intro.t == 0.0, "online sem o relogio do servidor: continua preparando, t = 0")
	check(intro.ready_local, "mas ja esta pronto aqui (avisa o servidor)")
	check(intro.band.prep and intro.band.waiting != "", "tela preta com neblina e 'aguardando'")
	intro.skip()
	check(not intro.skipped, "online: tocar nao pula a preparacao")
	intro.clock_started = true
	intro.update_to(0.0, 0.016, cam)
	check(not intro.preparing and not intro.band.prep, "relogio do servidor comecou: a cena comeca")
	intro.update_to(0.5, 0.016, cam)
	check_near(intro.t, 0.5, 0.001, "e segue o relogio")
	var st: DuelStage = intro.stage
	intro._leave_studio()
	st.free()
	intro.band.free()
	cam.free()
	intro.free()


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
