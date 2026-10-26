extends Node3D
## Corrida em 3D (plano B): liga a simulacao (a mesma do plano A) a uma apresentacao 3D com
## estrada em malha, caminhoes .glb PBR, transito, cidade e camera atras do jogador.
## Debug: -- --autoplay  --start=600 [--start-speed=20]  --touch  --shot (sem HUD de toque)

const FIELD_COLORS: Array[Color] = [Color("#e9eef5"), Color("#d1303f"), Color("#3a73d6"), Color("#3fb26f")]
## Cabine dos bots por posicao no grid (o 0 e o jogador). Antes da T-129: classica, aero, curta, chata;
## as cabines por codigo viraram a nova mais parecida (aero -> jac).
const RIVAL_CABS: Array[String] = ["chata", "jac", "curta", "chata"]
## Modelo de cada bot da corrida offline (indice = lugar no grid; o 0 e o jogador): baú leve, longo e a graneleira (T-145).
const RIVAL_BODIES: Array[String] = ["base", "leve", "longo", "graneleira"]

var sim: RaceSim
var path: TrackPath
var player: int = 0
var input := LocalInput.new()
var _acc: float = 0.0
var _prev: Array[Vector2] = []            # (z, x) do tick anterior, por caminhao
var _trucks: Array[TruckNode] = []
var _bots: Array[BotDriver] = []
var _cam: Camera3D
var _traffic3d: Traffic3D
var _plates: LicensePlates            # placas de todos os veiculos (uma chamada de desenho)
var _hud: RaceHud
var _fx: Fx3D
var _autoplay: bool = false
var _countdown: float = 3.0
var _steer_smooth: float = 0.0
var _cargo_notice: Array[String] = []
var _lights_state: bool = true
var _mural_glow_state: float = -1.0
var _cinema := RaceCinema.new()         # cortes de camera da largada/chegada e clarao do tunel
var _final_result: Dictionary = {}     # resultado fixado no instante em que a corrida acaba
const END_SCREEN_DELAY: float = 2.6    # tempo do corte e do banner de chegada antes da tela de resultado
var _hud_layer: CanvasLayer             # HUD + botoes de toque (some na pausa para o menu nao ficar por cima deles)
var _demo: RaceDemo                    # capturas/depuracao (--demo=, --shots=)
var _over_time: float = 0.0          # tempo desde que a corrida acabou (atrasa a tela de tempo esgotado)
const TIMEOUT_SCREEN_DELAY: float = 1.8
var _shake: float = 0.0
var _was_escaping: bool = false         # curva rapida demais (T-132): vibra uma vez ao escapar
var _was_warn_full: bool = false
var _result_shown: bool = false
var _fps_printed: bool = false
var _debug_events: bool = false
var gs: Node
var route: RouteDef
var _pause_layer: CanvasLayer
var _pause_root: Control
var _fps_log: bool = false
var _fps_t: float = 0.0
var _fps_n: int = 0
var _fps_max_calls: int = 0           # --fps-log: maior numero de chamadas de desenho no periodo (batidas, T-141)
var _fps_age: float = 0.0              # s desde o 1o quadro (--fps-log: picos so depois de carregar)
var _pause_first: Button
var _audio: RaceAudio
var _rival_audio: Array[EngineAudio] = []
var _prev_passing: bool = false
var online: bool = false
var sync: ClientSync
var _rival_idx: Array[int] = []
var _cmd_acc: float = 0.0
var _auto_driver: BotDriver
var tod: TimeOfDay
var _tunnel: Tunnel3D
var _speed_fx: SpeedFx
var _scrape_t: float = 0.0
var _brake_fx: BrakeFx                  # T-144: fumaca dos pneus e marcas no asfalto na freada forte
var _truck_sfx: Array[TruckSfx] = []    # T-144: buzina e freio de cada caminhao (os outros com volume pela distancia)
var _turn_audio: TurnSignalAudio         # T-170: som da seta do jogador
var _horns: Array[String] = []          # som de buzina de cada caminhao (peca instalada ou a basica)
var _sound_loadouts: Dictionary = {}    # T-173: indice -> descritor (motor/turbo/escape) dos outros jogadores online
var _was_hard_braking: bool = false
var _impact: ImpactFx                   # T-141: faiscas, pedacos, chacoalhada e tremor das batidas
var _rail: Railway3D                    # T-154: ferrovia e trens
var _speed_blur: SpeedBlur               # T-189: borrao de velocidade (Ultra, opcional; null = desligado)
var _life: RaceLife                      # T-189: vida do cenario (so visual; null = Settings.fx_life desligado)
var _rain_fx: RainFx                     # T-189: spray atras dos caminhoes, respingos e som da chuva (null = sem chuva)
var _intro: DuelIntro                   # T-156: abertura "frente a frente" (so apresentacao)
var _sun: DirectionalLight3D            # T-204: a abertura apaga o sol/lua enquanto o estudio esta na tela
var _nohud: bool = false
var _hud_demo: bool = false             # T-202: --hud-demo
var _net_racing: bool = false           # online: o servidor ja largou (s_state RACING)
var _freecam: Freecam                   # T-181: camera livre de exploracao (null = indisponivel; nunca online)
var _camv: RaceCamView                  # T-198: cameras da corrida (C) e retrovisor (R); so apresentacao, local
var _load_frames: int = 0               # T-208: quadros desde o fim do _ready (picos no log LOAD_T208)
var _headless: bool = DisplayServer.get_name() == "headless"
var _toll3d: TollPlaza3D                # T-207: praca de pedagio (cancelas e luz que segue o jogador)
var _drawn: Array[Vector2] = []         # T-198: (z, x) interpolados de cada caminhao no ultimo quadro (cameras sem tranco)
var _amb: RouteAmbience                 # T-217: outra pista, muros de pedra, marcos da rota (so visual)
var _vis_t: float = 0.0                 # T-217: relogio do cenario vivo (para na camera livre e na pausa)
var _exposure: ExposureAdapt            # T-217: adaptacao do olho na boca dos tuneis (PC Forward+; null = celular)
var _world_env: Environment


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # recebe o botao de pausa mesmo pausado
	LoadClock.mark("cena_carregada")            # T-208: cronometro do carregamento (LOAD_T208)
	gs = get_node("/root/GameState")
	RaceDemo.decorate_profile(gs, OS.get_cmdline_user_args())
	route = gs.pending_route
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route="):
			route = load("res://data/routes/%s.tres" % a.substr(8)) as RouteDef
	online = not Net.pending_setup.is_empty() and Net.online
	if online:
		route = load("res://data/routes/%s.tres" % Net.pending_setup["rules"]["route"]) as RouteDef
		sync = ClientSync.new()
		sync.setup(Net.pending_setup, Net.pending_truck)
		sim = sync.sim
		player = Net.pending_truck
	else:
		var track: Track = route.build_track() if route != null else Track.make_test_track()
		if "--no-sections" in OS.get_cmdline_user_args():  # T-153 depuracao: pista sem os trechos de 2 faixas (medir custo)
			track.set_lane_sections([])
		if "--no-toll" in OS.get_cmdline_user_args():     # T-207 depuracao: sem a praca de pedagio nova (comparar e medir)
			track.set_toll(-1.0)
		track.events = RaceDemo.track_events(OS.get_cmdline_user_args(), route, track)   # T-139 (--event=, --no-events)
		var density: int = route.traffic if route != null else TrafficSim.Density.NORMAL
		var fake: Dictionary = RaceDemo.fake_contract(OS.get_cmdline_user_args(), route)
		if not fake.is_empty():
			gs.pending_contract = fake
		sim = RaceSim.new(track, density)
		sim.freight = route.freight if route != null else 25000
		if not gs.pending_contract.is_empty():         # contrato do Mercado: o valor dele e o frete da corrida
			sim.freight = int(gs.pending_contract["reward"])
		sim.deadline = float(gs.pending_contract.get("deadline_s", 0.0))
		_cargo_notice = _build_cargo_notice(gs.pending_contract)
		if sim.deadline <= 0.0 and route != null:
			sim.deadline = route.deadline()
		if sim.deadline > 0.0:
			sim.deadline += track.events.time_allowance()     # T-139: o prazo estica com os eventos de pista
	path = TrackPath.new(sim.track, ArrivalLayout.runout(String(route.id) if route != null else ""))   # T-195: a estrada segue depois da chegada
	var q: int = int(Settings.quality)
	UltraLook.apply_viewport(get_viewport(), q)    # escala 3D e antisserrilhado (T-189: FSR2 nativo no Ultra)
	tod = _resolve_time_of_day()
	var scenery: StringName = route.scenery if route != null else &"city"
	var world: Dictionary = WorldEnv.create(self, false, tod, scenery == &"mountain")
	_sun = world.get("sun") as DirectionalLight3D
	var tunnels: Array[Vector2] = route.tunnels if route != null else ([] as Array[Vector2])
	var bridges: Array[Vector2] = route.bridges if route != null else ([] as Array[Vector2])   # T-153
	if sim.track.lane_sections.is_empty():
		bridges = []
	RouteAmbience.prepare(path, String(route.id) if route != null else "", scenery, tunnels, bridges)   # T-217
	var road := RoadMesh.new()
	add_child(road)
	road.bridges = bridges
	var zone: Vector2 = ScenicZone.zone(String(route.id) if route != null else "", path.track.length_m)   # T-188
	road.bare = zone
	if zone.y >= path.track.length_m - 1.0:
		road.bare = Vector2(zone.x, path.end_m() + 1.0)   # T-195: o TerrainPatch tambem cobre a continuacao
	road.soft_spec = not UltraLook.active(q)        # T-195: sem pontos brilhantes no asfalto molhado
	road.build(path, scenery, tod, tunnels)
	LoadClock.mark("ceu_e_estrada")
	if not bridges.is_empty():
		var structures := SectionStructures3D.new()  # T-153: pilares, longarinas e cabeceiras da ponte
		add_child(structures)
		structures.build(path, bridges, tod)
	var furniture := RoadFurniture.new()
	add_child(furniture)
	furniture.zone = zone
	furniture.build(path, scenery, tod, tunnels, route.places if route != null else PackedStringArray())
	var signs := RoadSigns.new()                  # T-130: limites, avisos, chevrons, km, saida, tunel, pedagio
	add_child(signs)
	signs.build(path, scenery, tod, tunnels, route.places if route != null else PackedStringArray(), String(route.id) if route != null else "")
	var kit := KitProps3D.new()                   # T-146: outdoors e muros listrados nas bocas dos tuneis
	add_child(kit)
	kit.build(path, scenery, tod, tunnels)
	var events3d := TrackEvents3D.new()           # T-139: acidente, obras, estreitamento (mesma lista da simulacao)
	add_child(events3d)
	events3d.build(path, tod)
	if TollPlaza3D.enabled(sim.track):             # T-207: praca de pedagio (ilha central, 2 passagens, luzes)
		_toll3d = TollPlaza3D.new()
		add_child(_toll3d)
		_toll3d.build(path, tod, q)
	_tunnel = Tunnel3D.new()
	_tunnel.glare_peak = lerpf(0.35, 1.6, tod.day_amount)   # T-217: brilho da saida visto de dentro
	_tunnel.tod = tod
	_world_env = world["env"] as Environment
	add_child(_tunnel)
	_tunnel.build(path, tunnels, scenery, world["sun"], world["env"])
	var lane_signals := TunnelSignals3D.new()      # T-164: seta verde / X vermelho por faixa, ligados aos eventos
	add_child(lane_signals)
	lane_signals.build(path, tunnels, tod)
	_tunnel.exited.connect(func() -> void:
		_cinema.tunnel_flash(tod.day_amount)
		_demo.queue_shot("saida_tunel", 0.12))
	_rail = Railway3D.new()                        # T-154: ferrovia ao lado da pista, viadutos e trens (so visual)
	add_child(_rail)
	_rail.build(path, String(route.id) if route != null else "", scenery, tod)
	var rid: String = String(route.id) if route != null else ""
	var over_out: Array = OverpassLayout.keep_out(path, rid) if Overpass3D.enabled() else []   # T-164
	var over := Overpass3D.new()                   # T-164: viaduto rodoviario cruzando por cima (Ponte A)
	add_child(over)
	over.build(path, rid, tod, -1.2 - RoadMesh.deck_height(scenery), _rail.lines)
	var uniq_z: float = -1.0                       # T-193: the "only one car" (parked once per race, scenery only)
	if UniqueCar.enabled():
		var busy: Array[Vector2] = []
		for t in tunnels + bridges:
			busy.append(Vector2(t.x, t.x + t.y))
		for o in OverpassLayout.for_route(rid):
			busy.append(Vector2(float(o["z"]), float(o["z"])))
		if CutLayout.of(path) != null:                 # T-217: not in a stone-wall cut
			busy.append_array(CutLayout.of(path).spans())
		uniq_z = UniqueCar.spot_z(sim.track, rid, busy)
		if DanchiLayout.of(path) != null:              # T-217: no apartment block on the unique car's lot
			DanchiLayout.of(path).clear_around(uniq_z, 30.0)
		var spot: Array = UniqueCar.SPOTS.get(rid, UniqueCar.DEFAULT_SPOT)
		over_out = over_out + UniqueCar.keep_out(path, uniq_z, float(spot[1]) * float(spot[2]))
	var city := CityBuilder.new()
	city.keep_out = RailwayLayout.keep_out(_rail.lines) + over_out
	var scenic := ScenicStretch.new()              # T-188: terreno, montanhas em camadas, quarteiroes, floresta
	add_child(scenic)
	scenic.build(path, rid, scenery, tod, zone, city.keep_out)
	city.zone = zone
	add_child(city)
	city.build(path, 21, scenery, tod)
	if scenery == &"city" and zone.y > zone.x:      # T-193: far block of towers (docs/Modelos/Cidade)
		CityModels.add_skyline(scenic, path, tod, city.keep_out)
	if uniq_z >= 0.0:
		var uniq := UniqueCar.new()
		add_child(uniq)
		uniq.build(path, rid, tod, uniq_z, scenic.field)
	var power := PowerLines3D.new()                # T-163: postes de energia com fios (montanha, litoral)
	add_child(power)
	power.keep_out = over_out
	power.build(path, rid, scenery, tod, tunnels)
	var side := Roadside3D.new()
	add_child(side)
	side.overpass_out = over_out
	side.bridges = bridges
	side.pole_runs = PowerLineLayout.corridors(power.poles)
	side.rails = _rail.lines                       # T-186: bosques fora da ferrovia, semente pela rota
	side.route_seed = rid.hash()
	side.field = scenic.field                      # T-188: arvores e pedras sobre o terreno novo
	if path.end_m() > path.track.length_m + 1.0:      # T-195: cidade destino depois da chegada (so visual)
		var arrival := ArrivalCity.new()
		add_child(arrival)
		arrival.build(path, rid, scenery, tod, city.keep_out, side)
	side.left_taken = signs._taken                 # T-217: the green signs that move left keep clear of these
	side.build(path, scenery, tod, tunnels)
	PeopleKit.populate(self, path, rid, tod)       # T-186: pessoas no pedagio e no viaduto
	_amb = RouteAmbience.new()                     # T-217: outra pista com transito, muros de pedra, marcos da rota
	add_child(_amb)
	_amb.build(path, rid, scenery, tod, q, scenic.field, func() -> float: return _vis_t, road.soft_spec,
		route.places if route != null else PackedStringArray(), tunnels)
	LoadClock.mark("cenario")
	if RaceLife.enabled():                         # T-189: vento, passaros, fumaca, insetos, sombras de nuvem
		_life = RaceLife.new()
		add_child(_life)
		_life.build(path, rid, scenery, tod, q, side, tunnels, bridges, scenic.field, zone, _rail)
	_fx = Fx3D.new()
	add_child(_fx)
	_brake_fx = BrakeFx.new()
	add_child(_brake_fx)
	_plates = LicensePlates.new()
	add_child(_plates)
	_plates.set_level(AtlasQuads.level_for(tod))
	_traffic3d = Traffic3D.new()
	add_child(_traffic3d)
	_traffic3d.setup(path, sim.traffic, _plates)
	if online:
		_spawn_field_online()
		_connect_net()
	else:
		_spawn_field()
	LoadClock.mark("caminhoes_e_transito")
	_impact = ImpactFx.new()
	add_child(_impact)
	var lens: Array[float] = []
	for t in sim.trucks:
		lens.append(t.length)
	_impact.setup(_fx, _trucks, lens, _traffic3d)
	_impact.sim = sim
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.2
	_cam.far = BackdropKit.CAMERA_FAR if BackdropKit.mountains_available() else 900.0   # T-179: montanhas a 1-6 km
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--view-far="):              # depuracao T-179: comparar o custo (antes era 900)
			_cam.far = float(a.substr(11))
	add_child(_cam)
	_cam.make_current()
	_freecam = Freecam.attach(self, path, _cam, route, tod, online)    # T-181: F1 / --freecam / botao da pausa
	_speed_blur = SpeedBlur.attach(_cam, q, Settings.fx_motion_blur)
	if _life != null:
		_life.attach_camera(_cam)
	if Settings.fx_rain:
		_rain_fx = RainFx.new()
		add_child(_rain_fx)
		_rain_fx.setup(_trucks, _cam, tod, q)
	_speed_fx = SpeedFx.new()
	add_child(_speed_fx)
	var streaks := LightStreaks.new()
	add_child(streaks)
	streaks.setup(path, tod, _trucks, player, _traffic3d, func(i: int) -> float: return sim.trucks[i].speed, _cam)
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.scale = Vector2(2, 2)          # HUD e toque desenhados em 480x270
	add_child(layer)
	_hud_layer = layer
	_cinema.build(self)
	_hud = RaceHud.new()
	_hud.bind(sim, player)
	layer.add_child(_hud)
	var event_hud := EventHud.new()                 # T-139: avisos de acidente / obras / estreitamento
	event_hud.bind(sim, player)
	layer.add_child(event_hud)
	_hud.event_hud = event_hud                      # T-202: the HUD layout places the warnings
	event_hud.alert_shown.connect(func(_kind: int) -> void:
		_audio.event_alert()
		Input.vibrate_handheld(60))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_autoplay = "--autoplay" in args
	_debug_events = "--debug-events" in args
	_demo = RaceDemo.new(args)
	if not online:
		_demo.setup(sim)
		_hud_demo = HudDemo.wanted(args)                # T-202: damaged truck + signal on (screenshots)
		if _hud_demo:
			HudDemo.damage(sim.trucks[player])
		for k in sim.trucks.size():
			_prev[k] = Vector2(sim.trucks[k].z, sim.trucks[k].x)
	var v0: float = 30.0
	for a in args:
		if a.begins_with("--start-speed="):            # depuracao: velocidade inicial com --start (m/s)
			v0 = float(a.substr(14))
	_nohud = "--nohud" in args
	if _nohud:
		layer.visible = false
	for a in args:
		if a.begins_with("--start="):
			var z0: float = float(a.substr(8))
			for k in sim.trucks.size():
				sim.trucks[k].z = z0 - float(k) * 14.0
				sim.trucks[k].speed = v0
				_prev[k] = Vector2(sim.trucks[k].z, sim.trucks[k].x)
			_countdown = 0.0
	var touch: bool = (DisplayServer.is_touchscreen_available() or "--touch" in args or gs.profile.get("force_touch", false)) \
			and not "--no-touch" in args              # T-202: --no-touch = PC layout in screenshots
	_hud.touch_layout = touch
	if touch:
		var tc := TouchControls.new()
		tc.target = input
		layer.add_child(tc)
	_camv = RaceCamView.new()
	add_child(_camv)
	_camv.anchor_node = _trucks[player]
	_camv.setup(path, sim.track.events, tunnels, String(route.id) if route != null else "", layer, self,
			HudLayout.M, q, touch, world["env"])     # T-202: mirror at the top centre (the clocks went to the right)
	_hud.cam_button = _camv.button
	_hud.mirror = _camv.mirror
	_camv.layout(get_viewport().get_visible_rect().size.x / 2.0)
	RearMirror.hide_from_mirror(_cam)              # chuva, folhas e borrao presos na camera nao aparecem no espelho
	get_viewport().size_changed.connect(func() -> void: _camv.layout(get_viewport().get_visible_rect().size.x / 2.0))
	_build_pause_menu()
	_fps_log = "--fps-log" in args
	if _fps_log:
		_print_surface_budget()
	if "--paused" in args:                       # depuracao: abre ja na tela de pausa (capturas)
		_toggle_pause.call_deferred()
	if _demo.mode.begins_with("result"):         # --demo=result|result_lose|result_timeout: so a tela (nao grava no perfil)
		_result_shown = true
		_open_result.call_deferred(ResultScreen.demo_result(_demo.mode), "res://scenes/menu/main_menu.tscn")
	LoadClock.mark("camera_hud_toque")
	_setup_audio()
	LoadClock.mark("audio")
	_update_visuals(0.0, 0.0)
	_snap_camera()
	_setup_intro(args)
	LoadClock.mark("abertura_montada")
	var hidden: Vector3 = path.world_point(_player_z() + 22.0, _player_x(), -1.2)   # embaixo do asfalto, na frente da camera
	_impact.warmup(hidden)
	_traffic3d.wreck_fx.warmup(hidden)            # T-183: pisca-alerta, fumaca e triangulo do carro acidentado
	_brake_fx.warmup(hidden)
	DebugShot.arm(self, 4.0)            # --shot=ARQUIVO.png (capturas, T-138)
	DebugShot.force_window(self)        # --window=2400x1080 (capturas T-202, maior que o monitor)
	LoadClock.mark("ready_fim")
	RenderingServer.frame_post_draw.connect(func() -> void:
		LoadClock.mark("1o_quadro_desenhado")
		if online and (_intro == null or _intro.kind != DuelPlan.FULL):
			Net.race_loaded(), CONNECT_ONE_SHOT)    # T-208: sem a abertura cheia, pronto no 1o quadro desenhado


## Hora do dia: a da rota, ou --time=night|dusk|day (depuracao/capturas).
func _resolve_time_of_day() -> TimeOfDay:
	var tid: StringName = route.time_of_day if route != null else &"night"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--time="):
			tid = StringName(a.substr(7))
	var t: TimeOfDay = AtmosTune.tune(TimeOfDay.by_id(tid))       # T-188: perspectiva aerea, luar, ceu novo (copia do preset)
	return UltraLook.tune_tod(t, int(Settings.quality), Settings.fx_rain)   # T-189: pista molhada


func _setup_audio() -> void:
	_audio = RaceAudio.new()
	_audio.sim = sim                             # T-141: volume das batidas dos outros pela distancia
	add_child(_audio)
	var music: String = "race_night_synthwave"
	if route != null:
		var rv: RivalDef = load("res://data/rivals/%s.tres" % route.rival_id) as RivalDef
		if rv != null and rv.boss:
			music = "boss_enka_rock"
		elif not tod.headlights:
			music = "race_day_rock"
	_audio.setup(sim.trucks[player], EngineSounds.from_descriptor(gs.truck_descriptor()), music)
	for k in range(_trucks.size()):
		if k != player:
			if not online:
				_rival_idx.append(k)
			# T-173: online = motor/turbo/escape do descritor do outro jogador; offline = sorteio so de som
			var lo: Dictionary = _sound_loadouts.get(k, EngineSounds.rival_loadout(_sound_seed(k)))
			_rival_audio.append(_audio.make_rival_engine(_trucks[k], EngineSounds.from_descriptor(lo), not online))
		var sfx := TruckSfx.new()
		var horn: String = gs.installed_horn() if k == player and not online else (_horns[k] if k < _horns.size() else "")
		sfx.setup(self if k == player else _trucks[k], k == player, horn)
		_truck_sfx.append(sfx)
	_turn_audio = TurnSignalAudio.new()          # T-170: tique-taque da seta e clique da alavanca (so do jogador)
	_turn_audio.setup_from_bus(self, sim.trucks[player])


## Corrida online: monta os caminhoes do grid recebido do servidor (pecas, tinta, bots).
func _spawn_field_online() -> void:
	var grid: Array = Net.pending_setup["grid"]
	for entry in grid:
		var i: int = int(entry["idx"])
		var node := TruckNode.new()
		node.chrome_mode = "day" if tod.day_amount > 0.5 else "night"
		node.set_mural_glow(tod.mural_glow)                                   # T-155: mural aceso a noite
		node.body_kind = String(entry["loadout"].get("body", "base"))      # o Canter tem outro tamanho na simulacao
		node.cab_kind = CabCatalog.normalize(entry["loadout"].get("cab", ""))   # descritor antigo/sem cabine -> padrao
		node.plates = _plates
		add_child(node)
		var defs: Array[PartDef] = []
		var styles: Dictionary = {}
		for p in entry["loadout"]["parts"]:
			var d: PartDef = gs.part(String(p["id"]))
			if d != null:
				defs.append(d)
				if p.has("style"):                                         # T-211: cor L/R e letreiro do outro jogador
					styles[String(p["id"])] = p["style"]
		node.apply_loadout(defs, styles)
		# T-173: buzina escolhida pelo outro jogador (descritor "horn"); servidor antigo/sem campo = a da peca
		_horns.append(HornCatalog.resolve(String(entry["loadout"].get("horn", "")), _horn_of(defs)))
		if not bool(entry["bot"]):
			_sound_loadouts[i] = entry["loadout"]
		var paint: String = String(entry.get("paint", "#e9eef5"))
		if bool(entry["bot"]):
			paint = FIELD_COLORS[i % FIELD_COLORS.size()].to_html(false)
			paint = "#" + paint if not paint.begins_with("#") else paint
		node.set_paint_color(Color(paint))
		_trucks.append(node)
		var t: TruckSim = sim.trucks[i]
		_prev.append(Vector2(t.z, t.x))
		if i != player:
			_rival_idx.append(i)


func _connect_net() -> void:
	Net.snapshot_received.connect(func(d: PackedByteArray) -> void: sync.on_snapshot(d, Time.get_ticks_msec()))
	Net.damage_received.connect(func(d: Dictionary) -> void: sync.apply_damage(d))
	Net.events_received.connect(func(evs: Array) -> void:
		var typed: Array[Dictionary] = []
		typed.assign(evs)
		_handle_events(typed))
	Net.race_state_changed.connect(func(st: int) -> void:
		if st == Protocol.RoomState.RACING:
			_net_racing = true
			if _intro != null and _intro.running():      # T-156: atrasado em relacao ao servidor: larga junto
				_intro.finish_now()
			_countdown = 0.0)
	_net_racing = Net.room_state == Protocol.RoomState.RACING
	Net.race_ended.connect(_on_net_end)
	Net.disconnected_from_server.connect(func() -> void: SceneFader.go(get_tree(), "res://scenes/menu/main_menu.tscn"))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--latency="):
			Net.debug_latency_ms = int(a.substr(10))
		elif a.begins_with("--loss="):
			Net.debug_loss = float(a.substr(7))
		elif a == "--nopredict":
			sync.predict = false


func _on_net_end(result: Dictionary) -> void:
	if _result_shown:
		return
	_result_shown = true
	Net.pending_setup = {}
	_audio.finish_race(int(result["position"]) == 1)
	_open_result(result, "res://scenes/lobby/lobby.tscn")


## Grid de largada, lado a lado (StartGrid). Campanha (rota com rival) = SEMPRE 1 contra 1: jogador + rival da rota
## (decisao do Marco, T-156). Corrida rapida (sem rota) = jogador + 3 bots. Cada um com pecas e acessorios proprios.
func _spawn_field() -> void:
	var rival: RivalDef = _route_rival()
	var base_diff: int = rival.difficulty if rival != null else BotDriver.Difficulty.NORMAL
	var n: int = StartGrid.CAMPAIGN_TRUCKS if rival != null else StartGrid.QUICK_TRUCKS
	for i in n:
		var g: Vector2 = StartGrid.slot(i, n)
		var idx: int = sim.add_truck(g.x, g.y)
		var t: TruckSim = sim.trucks[idx]
		t.is_bot = i != 0
		var node := TruckNode.new()
		node.body_kind = String(gs.profile.get("body", "base")) if i == 0 else RIVAL_BODIES[i % RIVAL_BODIES.size()]
		node.cab_kind = CabCatalog.normalize(gs.profile.get("cab", "")) if i == 0 else RIVAL_CABS[i % RIVAL_CABS.size()]
		node.chrome_mode = "day" if tod.day_amount > 0.5 else "night"
		node.set_mural_glow(tod.mural_glow)                                   # T-155: mural aceso a noite
		node.plates = _plates
		if i == 0:                                      # gancho: placa escolhida pelo jogador (ainda sem tela)
			node.plate_cell = int(gs.profile.get("plate_cell", -1))
		add_child(node)
		if i == 0:
			gs.configure_truck(t)
			node.apply_loadout(gs.installed_part_defs(), gs.part_styles())
			node.set_paint_color(Color(String(gs.profile.get("paint", "#e9eef5"))))
			node.apply_decals(gs.profile.get("decals", []) as Array)
		else:
			var defs: Array[PartDef] = []
			var paint: Color = FIELD_COLORS[i]
			var diff: int = clampi(base_diff + (i - 2), 0, 2)
			if i == 1 and rival != null:
				for pid in rival.part_ids:
					var d: PartDef = gs.part(String(pid))
					if d != null:
						defs.append(d)
				paint = rival.paint
				diff = rival.difficulty
			else:
				for pid in ["fb_basic", "rb_basic"]:
					defs.append(gs.part(pid))
			var parts: Array[Dictionary] = []
			for d in defs:
				parts.append(d.to_sim_part())
			t.set_loadout(parts)
			node.apply_loadout(defs)
			node.set_paint_color(paint)
			_horns.resize(i + 1)
			var ph: String = _horn_of(defs, "")
			_horns[i] = ph if ph != "" else HornCatalog.rival_horn(_sound_seed(i))   # T-173: sem buzina na peca = sorteio
			_bots.append(BotDriver.new(diff, 100 + i, g.y, i == 1 and rival != null))
		node.set_headlights(tod.headlights)
		node.set_light_pattern(String(gs.profile.get("light_pattern", "steady")) if i == 0 else LightPatterns.IDS[i % LightPatterns.IDS.size()])
		_trucks.append(node)
		_prev.append(Vector2(t.z, t.x))


## Buzina que a lista de pecas traz (PartDef.horn) ou a basica (T-144).
static func _horn_of(defs: Array[PartDef], fallback: String = "horn_air_basic") -> String:
	for d in defs:
		if d != null and d.horn != "":
			return d.horn
	return fallback


## Semente do sorteio de som dos rivais offline (T-173): a mesma rota e lugar no grid = o mesmo motor e buzina.
func _sound_seed(i: int) -> int:
	return hash((String(route.id) if route != null else "quick") + ":%d" % i)


func _build_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 30
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.visible = false
	add_child(_pause_layer)
	var menu := PauseMenu.new()                  # pausa SEM escurecer a corrida (ATB-1), centralizada (T-138)
	menu.freecam_enabled = _freecam != null
	menu.freecam_pressed.connect(func() -> void:
		_toggle_pause()
		_freecam.activate())
	_pause_layer.add_child(menu)
	menu.resume_pressed.connect(_toggle_pause)
	menu.rematch_pressed.connect(_rematch)
	menu.giveup_pressed.connect(_give_up)
	menu.options_pressed.connect(_pause_options)
	_pause_first = menu.first_button
	_pause_root = menu


## Revanche: recomeca a mesma corrida (mesma rota e contrato); o dano so entra no perfil ao terminar, entao volta ao estado de antes.
func _rematch() -> void:
	get_tree().paused = false
	SceneFader.go(get_tree(), "res://scenes/race/race3d.tscn")


## Desistir: sai para o menu sem resultado (nada e pago e o contrato continua no quadro).
func _give_up() -> void:
	get_tree().paused = false
	SceneFader.go(get_tree(), "res://scenes/menu/main_menu.tscn")


## Opcoes durante a pausa (mesma tela do menu; volume e controles valem na hora).
func _pause_options() -> void:
	var op := OptionsPanel.new()
	op.back_pressed.connect(func() -> void:
		op.queue_free()
		_pause_first.grab_focus())
	_pause_root.add_child(op)


func _toggle_pause() -> void:
	if _result_shown or online or (_freecam != null and _freecam.active):
		return
	get_tree().paused = not get_tree().paused
	_pause_layer.visible = get_tree().paused
	_hud_layer.visible = not get_tree().paused and not _nohud and not (_intro != null and _intro.running() and _intro.kind == DuelPlan.FULL)
	if _pause_layer.visible and _pause_first != null:
		_pause_first.grab_focus()
	if _pause_layer.visible and _demo.shot_dir != "":
		get_tree().create_timer(0.8, true).timeout.connect(func() -> void: _demo.snap(get_viewport(), "pausa"))


## T-217: adaptacao do olho na entrada/saida dos tuneis (so no PC com Forward+).
func _adapt_exposure(dt: float) -> void:
	if _exposure == null:
		if not ExposureAdapt.enabled() or _world_env == null:
			return
		_exposure = ExposureAdapt.new(_world_env, tod.day_amount, Settings.fx_reduce_flash)
	_exposure.step(dt, _tunnel.amount)


func _exit_tree() -> void:
	RouteAmbience.release()                          # T-217: as tabelas da rota nao vazam para outra cena/teste


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()


func _process(delta: float) -> void:
	if get_tree().paused or (_freecam != null and _freecam.active):   # T-181: camera livre congela a corrida
		return
	if _fps_log:                                 # depuracao: media de FPS a cada 5 s no terminal
		_fps_t += delta
		_fps_n += 1
		_fps_age += delta
		if delta > 0.05 and _fps_age > 1.5:
			print("PICO: quadro de %.0f ms (t=%.1f s)" % [delta * 1000.0, sim.time])
		_fps_max_calls = maxi(_fps_max_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		var in_intro: bool = _intro != null and _intro.running()      # T-156: periodos de 2 s durante a abertura
		if _fps_t >= (2.0 if in_intro else 5.0):
			print(("[abertura %s] " % _intro.band.phase if in_intro else "") + "FPS medio: %.1f  (desenhos: %d, max %d no periodo; triangulos: %d, texturas: %.1f MB, video: %.1f MB)" % [_fps_n / _fps_t, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), _fps_max_calls, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
			_fps_t = 0.0
			_fps_n = 0
			_fps_max_calls = 0
	var dt: float = minf(delta, 0.1)
	_vis_t += dt                                     # T-217: relogio do cenario vivo (transito da outra pista)
	if _load_frames < 400 and not _headless:         # T-208: picos dos primeiros quadros (shaders compilando)
		_load_frames += 1
		if delta > 0.05:
			print("LOAD_T208 pico quadro %d: %.0f ms (abertura t=%.2f, %s)" % [_load_frames, delta * 1000.0,
					_intro.t if _intro != null else -1.0, _intro.band.phase if _intro != null else ""])
	if online and _intro != null:                    # T-208: o relogio comum so anda quando todos montaram a corrida
		_intro.clock_started = Net.race_clock_started
		if _intro.kind != DuelPlan.FULL:
			_intro.band.waiting = "" if Net.race_clock_started or _net_racing else Tr.t("intro.wait_players")
	if _intro != null and _intro.running():          # T-156: abertura frente a frente (a corrida espera na largada)
		_intro.update_to(_net_elapsed() if online else _intro.t + dt, dt, _cam)
		if _intro.running():
			_intro_frame(dt)
			return
	if _countdown > 0.0:
		var before: float = _countdown
		_countdown -= dt
		if online and float(Net.pending_setup.get("countdown_total", 0.0)) > 0.0 and not _net_racing:
			var left: float = float(Net.pending_setup["countdown_total"]) - _net_elapsed()   # mesmo relogio do servidor
			_countdown = maxf(left, 0.0001) if left > -0.4 else 0.0     # espera o "largou" do servidor (ou 0,4 s a mais)
		_intro_count_shots(before)
		if before > RaceCinema.START_CUT_BEFORE and _countdown <= RaceCinema.START_CUT_BEFORE:
			_cinema.start_cut("start", RaceCinema.START_CUT_S, _cut_side())      # corte lateral na largada
		if before > 0.0 and _countdown <= 0.0:
			_hud.show_banner(Tr.t("hud.go"), 1.3)
	_cinema.update_flash(dt)
	if online:
		_process_online(dt)
		return
	var racing: bool = _countdown <= 0.0 and (not sim.is_over() or _over_time < _end_delay())
	if racing:
		var cmd: Commands = input.poll()
		if _autoplay:
			cmd = Commands.make(0.0, 1.0, 0.0)
		if _demo.active():
			cmd = _demo.command(sim.time)
		if sim.is_over():
			cmd = Commands.make(0.0, 0.0, 0.35)          # passou da linha: deixa o caminhao frear sozinho
		sim.set_command(player, cmd)
		_steer_smooth = lerpf(_steer_smooth, cmd.steer, minf(8.0 * dt, 1.0))
		_acc += dt
		while _acc >= RaceSim.FIXED_DT:
			for k in _prev.size():
				_prev[k] = Vector2(sim.trucks[k].z, sim.trucks[k].x)
			for b in _bots.size():
				sim.set_command(b + 1, _bots[b].command_for(sim, b + 1, RaceSim.FIXED_DT))
			sim.step()
			_handle_events(sim.drain_events())
			_acc -= RaceSim.FIXED_DT
	var alpha: float = clampf(_acc / RaceSim.FIXED_DT, 0.0, 1.0)
	_update_visuals(alpha, dt)
	_update_camera(dt)
	_update_hud()
	_update_audio(dt)
	_demo.update(get_viewport(), sim.trucks[player], dt)
	_tunnel.track_player(_player_z(), _trucks[player].global_position)
	_adapt_exposure(dt)
	if _toll3d != null:
		_toll3d.update(sim, _player_z(), sim.trucks[player].x, dt)
	for k in sim.trucks.size():
		_trucks[k].sync_damage(sim.trucks[k].loadout)
	if _autoplay and not _fps_printed and Time.get_ticks_msec() > 6000:
		_fps_printed = true
		print("FPS_MEDIDO: ", Engine.get_frames_per_second(), "  draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "  tris=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "  mem_MB=", OS.get_static_memory_usage() / 1048576)
	if sim.is_over() and not _result_shown:
		if _final_result.is_empty():
			_final_result = sim.result_for(player)          # fixa o resultado: o que acontece depois da linha nao conta
		_over_time += dt
		if _over_time >= _end_delay():
			_result_shown = true
			_show_result()


func _process_online(dt: float) -> void:
	if _countdown > 0.0:
		pass
	elif not _result_shown:
		var cmd: Commands = input.poll()
		if _autoplay:
			if _auto_driver == null:
				_auto_driver = BotDriver.new(BotDriver.Difficulty.NORMAL, 31, 0.0, false, true)
			cmd = _auto_driver.command_for(sim, player, dt)
		_steer_smooth = lerpf(_steer_smooth, cmd.steer, minf(8.0 * dt, 1.0))
		_cmd_acc += dt
		while _cmd_acc >= RaceSim.FIXED_DT:
			_cmd_acc -= RaceSim.FIXED_DT
			var tk: int = sync.local_step(cmd)
			Net.send_commands(tk, cmd)
		sync.interpolate(Time.get_ticks_msec(), dt)
	_update_visuals(1.0, dt)
	_update_camera(dt)
	_update_hud()
	_update_audio(dt)
	_tunnel.track_player(_player_z(), _trucks[player].global_position)
	_adapt_exposure(dt)
	if _toll3d != null:
		_toll3d.update(sim, _player_z(), sim.trucks[player].x, dt)
	for k in sim.trucks.size():
		_trucks[k].sync_damage(sim.trucks[k].loadout)


func _player_z() -> float:
	return sync.my_draw_z() if online else sim.trucks[player].z


func _player_x() -> float:
	return sync.my_draw_x() if online else sim.trucks[player].x


func _update_audio(dt: float) -> void:
	var t: TruckSim = sim.trucks[player]
	_audio.update(dt, t, _countdown)
	_audio.update_events(sim.track.events, t.z + t.length * 0.5)
	for k in _truck_sfx.size():
		_truck_sfx[k].update(sim.trucks[k], dt)
	_turn_audio.update(t)
	for k in _rival_audio.size():
		var rt: TruckSim = sim.trucks[_rival_idx[k]]
		var r01: float = clampf((rt.rpm - EngineModel.IDLE_RPM) / (rt.engine.redline_rpm - EngineModel.IDLE_RPM), 0.0, 1.0)
		_rival_audio[k].update(dt, r01, rt.engine.throttle_now, rt.boost, 1.0, rt.speed)
	if t.passing_active and not _prev_passing:
		_audio.passing_pressed(gs.installed_horn())
		_speed_fx.passing_flash()
	_prev_passing = t.passing_active


func _handle_events(events: Array[Dictionary]) -> void:
	for e in events:
		_audio.on_event(e, player)
		_demo.on_event(e, player, sim.time)
		if _debug_events:
			print("EVENTO frame=%d %s" % [Engine.get_frames_drawn(), e])
		match String(e["type"]):
			"overtake":
				if int(e["truck"]) == player:
					_hud.show_banner(Tr.t("hud.overtake"))
			"finish":
				if int(e["truck"]) == player:
					_hud.show_banner(Tr.t("hud.finish", [int(e["position"])]), 3.0)
					_cinema.start_cut("finish", RaceCinema.FINISH_CUT_S, _cut_side())      # corte lateral na chegada
			"timeout":
				if int(e["truck"]) == player:
					_hud.show_banner(Tr.t("hud.timeout"), 3.0)
			"truck":                                      # T-141: faiscas, pedacos e chacoalhada no ImpactFx
				_impact.on_event(e, player)
				_spawn_debris(int(e["a"]), e["broken_a"], String(e["zone_a"]))
				_spawn_debris(int(e["b"]), e["broken_b"], String(e["zone_b"]))
				if int(e["a"]) == player or int(e["b"]) == player:
					Input.vibrate_handheld(int(clampf(40.0 + float(e["force"]) * 10.0, 40.0, 160.0)))
			"traffic", "event_obstacle":
				_impact.on_event(e, player)
				_spawn_debris(int(e["truck"]), e["broken"], String(e["zone"]))
				if int(e["truck"]) == player:
					Input.vibrate_handheld(int(clampf(30.0 + float(e["force"]) * 8.0, 30.0, 140.0)))
			"passing_scare":
				if int(e["to"]) == player:
					_shake = maxf(_shake, 0.4)


func _spawn_debris(truck_index: int, broken: Array, zone: String) -> void:
	if not _impact.enabled:
		return
	for id in broken:
		var node: TruckNode = _trucks[truck_index]
		var side: float = -1.0 if zone == "left" else (1.0 if zone == "right" else 0.0)
		var vel: Vector3 = node.global_transform.basis * Vector3(side * 3.0, 0.0, -2.0)
		_fx.debris(_impact.zone_point(truck_index, zone), vel)


func _update_visuals(alpha: float, dt: float) -> void:
	for k in sim.trucks.size():
		var t: TruckSim = sim.trucks[k]
		var z: float = lerpf(_prev[k].x, t.z, alpha)
		var x: float = lerpf(_prev[k].y, t.x, alpha)
		if online:
			z = _player_z() if k == player else t.z
			x = _player_x() if k == player else t.x
		var node: TruckNode = _trucks[k]
		if _drawn.size() != sim.trucks.size():
			_drawn.resize(sim.trucks.size())
		_drawn[k] = Vector2(z, x)
		var al: Vector2 = Vector2.ZERO                  # T-156: manobra de alinhamento no comeco da contagem
		if _intro != null and _intro.kind == DuelPlan.SHORT and _countdown > 0.0:   # T-204: depois da cheia ja estao no grid
			al = DuelShots.align_offset(t.x, DuelShots.align_progress(_countdown))
		node.transform = _impact.jolt(k, path.vehicle_transform(z, x + al.x, t.length, t.body_yaw() + al.y, t.lean() * 0.11))
		node.animate(t.speed, dt, t.lean())
		var hz: bool = t.signal_dir == 0 and HudStatus.hazard(t, sim.time, _countdown <= 0.0)
		node.set_signal(2 if hz else t.signal_dir)       # T-202: 2 = hazard (both sides)
		if _cam != null:
			_brake_fx.update_truck(k, node, t, _cam.global_position, dt, tod.headlights)
	_traffic3d.refresh()
	if _cam != null:
		_rail.update(dt, _player_z(), sim.trucks[player].speed, _cam.global_position)
	if _speed_blur != null:
		_speed_blur.update(sim.trucks[player].speed)
	if _rain_fx != null:
		var speeds: Array[float] = []
		for t in sim.trucks:
			speeds.append(t.speed)
		_rain_fx.update(speeds)
	if _life != null and _cam != null:
		_life.update(dt, _player_z(), _cam.global_position, _tunnel.amount, sim.trucks[player].speed)


func _cam_target(z: float, x: float) -> Array[Vector3]:
	var k: float = sim.trucks[player].length / Collision.LEN       # Canter (7 m): camera um pouco mais perto e baixa
	if _camv != null:
		return _camv.rig.chase_target(z, x, k)                      # T-198: perto / padrao / longe (padrao = a de baixo)
	var pos: Vector3 = path.world_point(z - (10.0 + 4.5 * k), x * 0.85, 4.6 + 1.0 * k)
	var look: Vector3 = path.world_point(z + 14.0, x * 0.45, 1.8)
	return [pos, look]


func _snap_camera() -> void:
	var t: TruckSim = sim.trucks[player]
	var c: Array[Vector3] = _cam_target(_player_z(), _player_x())
	_cam.global_position = c[0]
	_cam.look_at(c[1], Vector3.UP)


func _update_camera(dt: float) -> void:
	var t: TruckSim = sim.trucks[player]
	var racing: bool = _countdown <= 0.0 and not _result_shown
	var ext: bool = _demo.cam_mode != "" or _cinema.active()
	_update_cam_view(dt, racing, ext)
	if _demo.camera(_cam, path, _player_z(), _player_x(), t.length):
		return
	if _align_camera():
		return
	if _cinema.apply_cut(dt, _cam, _trucks[player]):
		_speed_fx.update(t.speed, dt)
		return
	var z: float = _player_z()
	var me: Vector2 = _drawn[player] if _drawn.size() > player else Vector2(z, _player_x())
	if racing and _camv.apply_free(dt, _cam, Vector3(me.x, me.y * Track.ROAD_HALF_WIDTH_M, t.length), t.speed,
			_cam_rival()):                                        # T-198: cinema / orbita
		_speed_fx.update(t.speed, dt)
		_scrape_sparks(t, dt)
		return
	var ex: Array = _speed_fx.camera_extra(t.speed, sim.track.curve_at(z + 30.0), dt)   # atraso na curva + tremor
	var c: Array[Vector3] = _cam_target(z + t.speed * 0.02, _player_x())
	var right: Vector3 = path.right_at(z) * Track.ROAD_HALF_WIDTH_M
	var k: float = 1.0 - exp(-14.0 * dt)
	_cam.global_position = _cam.global_position.lerp(c[0] + right * float(ex[0]), k)
	var look: Vector3 = c[1] + right * float(ex[1])
	_shake = maxf(_shake - dt * 2.5, 0.0)
	_shake = maxf(_shake, _impact.take_shake())
	var s: float = _shake * 0.25
	if s > 0.0:
		_cam.global_position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	_cam.look_at(look, Vector3.UP)
	_cam.global_position += _cam.global_basis * ((ex[2] as Vector3) * _camv.rig.fx_scale())
	_cam.global_position += _cam.global_basis * _impact.sway_camera(player)     # T-152: a camera sente o tranco
	var fov: float = _camv.rig.chase_fov() + (_speed_fx.fov_extra(t.speed) + t.draft * 6.0) * _camv.rig.fx_scale()
	_cam.fov = lerpf(_cam.fov, fov, minf(3.0 * dt, 1.0))
	if _camv.rig.blending():                                     # T-198: troca de camera suave
		var b: Array = _camv.rig.blend(_cam.global_position, look, fov, _trucks[player].global_position, dt)
		_cam.global_position = b[0]
		_cam.look_at(b[1], Vector3.UP)
		_cam.fov = b[2]
	_speed_fx.update(t.speed, dt)
	_scrape_sparks(t, dt)


## T-198: letterbox, retrovisor (com o caminhao mais perto atras) e estado das cameras.
func _update_cam_view(dt: float, racing: bool, external_cut: bool) -> void:
	var pz: float = _player_z()
	var gap: float = INF
	var is_rival: bool = false
	for k in sim.trucks.size():
		if k == player or sim.trucks[k].z >= pz:
			continue
		var g: float = maxf(pz - (sim.trucks[k].z + sim.trucks[k].length), 0.0)
		if g < gap:
			gap = g
			is_rival = k in _rival_idx
	var me: Vector2 = _drawn[player] if _drawn.size() > player else Vector2(pz, _player_x())
	_camv.update(dt, racing, external_cut, path, me.x, me.y, gap, is_rival)


## Rival da camera cinema: o da rota, ou o caminhao mais perto (corrida rapida). Vector3(z, lateral m, comprimento).
func _cam_rival() -> Vector3:
	var best: int = _rival_idx[0] if not _rival_idx.is_empty() else -1
	if best < 0:
		var d: float = INF
		for k in sim.trucks.size():
			if k != player and absf(sim.trucks[k].z - _player_z()) < d:
				d = absf(sim.trucks[k].z - _player_z())
				best = k
	if best < 0:
		return Vector3(NAN, 0.0, 0.0)
	var r: TruckSim = sim.trucks[best]
	var d2: Vector2 = _drawn[best] if _drawn.size() > best else Vector2(r.z, r.x)
	return Vector3(d2.x, d2.y * Track.ROAD_HALF_WIDTH_M, r.length)


## Faiscas ao raspar na mureta (a sim prende o caminhao no limite lateral |x| = 1,6).
func _scrape_sparks(t: TruckSim, dt: float) -> void:
	_scrape_t -= dt
	if absf(t.x) < 1.58 or t.speed < 8.0 or _scrape_t > 0.0:
		return
	_scrape_t = 0.06
	if _impact.enabled:
		_fx.sparks(_impact.zone_point(player, "left" if t.x < 0.0 else "right"), 6.0, _impact.amount)


func _update_hud() -> void:
	_update_truck_lights()
	_hud.countdown = _countdown
	_hud.rival_idx = _rival_idx[0] if not _rival_idx.is_empty() else -1
	_hud.cargo_notice = _cargo_notice
	_hud.amber = maxf(1.0 - tod.day_amount, _tunnel.amount)     # T-202: gauge backlight (amber at night / tunnel)
	_hud.tunnel = _tunnel.amount
	_hud.headlights = tod.headlights or _tunnel.amount > 0.3
	if _hud_demo:
		HudDemo.hold_signal(sim.trucks[player])
		_hud.segments.pin(0)
	_curve_feedback(sim.trucks[player])
	for k in sim.trucks.size():
		var eng: float = float(sim.trucks[k].systems["engine"])
		_fx.set_smoke(k, _trucks[k], clampf((60.0 - eng) / 60.0, 0.0, 1.0))


## Curva rapida demais (T-132): vibra ao chegar no limite e ao escapar e treme a camera; o aviso escrito e do RaceHud.
func _curve_feedback(t: TruckSim) -> void:
	var warn_full: bool = _countdown <= 0.0 and t.curve_warning(sim.track) >= 1.0
	if (t.escaping and not _was_escaping) or (warn_full and not _was_warn_full):
		Input.vibrate_handheld(220 if t.escaping else 70)
	if t.escaping:
		_shake = maxf(_shake, 0.25)
	if t.hard_braking:                         # T-144: freada forte treme de leve (e vibra no comeco)
		if _impact.enabled:
			_shake = maxf(_shake, 0.1 + 0.18 * t.brake_intensity)
		if not _was_hard_braking:
			Input.vibrate_handheld(int(30.0 + 50.0 * t.brake_intensity))
	_was_hard_braking = t.hard_braking
	_was_escaping = t.escaping
	_was_warn_full = warn_full


## Luzinhas e farois: acesos de noite/fim de tarde e quando o jogador esta num tunel (de dia ficam fracos).
func _update_truck_lights() -> void:
	var inside: bool = _tunnel.amount > 0.3
	var glow: float = maxf(tod.mural_glow, MuralGlow.TUNNEL) if inside else tod.mural_glow   # T-155: mural no tunel
	if glow != _mural_glow_state:
		_mural_glow_state = glow
		for k in _trucks.size():
			_trucks[k].set_mural_glow(glow)
	var on: bool = tod.headlights or inside
	if on == _lights_state:
		return
	_lights_state = on
	for k in _trucks.size():
		_trucks[k].set_lights_on(on)
		_trucks[k].set_headlights(on)


## Linhas do aviso de carga mostrado na contagem regressiva (contrato do Mercado).
func _build_cargo_notice(c: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if c.is_empty() or not c.has("cargo"):
		return out
	out.append("%s · %.1f t" % [Tr.t("cargo." + String(c["cargo"])), float(c["weight_t"])])
	out.append(Tr.t("cargo.trait." + String(c.get("trait", "normal"))))
	return out


## Lado da camera do corte: o lado com menos caminhoes perto (+1 = direita do jogador, -1 = esquerda).
func _cut_side() -> float:
	var me: TruckSim = sim.trucks[player]
	var bias: float = 0.0
	for k in sim.trucks.size():
		if k != player and absf(sim.trucks[k].z - me.z) < 40.0:
			bias += signf(sim.trucks[k].x - me.x)
	return -1.0 if bias > 0.0 else 1.0


## Quanto espera (corte de chegada + banner) antes da tela de resultado.
func _end_delay() -> float:
	return TIMEOUT_SCREEN_DELAY if sim.trucks[player].timed_out else END_SCREEN_DELAY


func _show_result() -> void:
	var res: Dictionary = _final_result if not _final_result.is_empty() else sim.result_for(player)
	print("RESULTADO: ", res)
	_audio.finish_race(int(res["position"]) == 1)
	gs.apply_race_result(res, String(route.id) if route != null else "", sim.trucks[player])
	_open_result(res, "res://scenes/menu/main_menu.tscn")


## Tela de resultado numa camada propria SEM escala (layout por containers, T-138). `next_scene` = para onde o CONTINUAR leva.
func _open_result(res: Dictionary, next_scene: String) -> void:
	_hud_layer.visible = false                   # HUD e toque somem: a tela de resultado fica limpa
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var screen := ResultScreen.new()
	layer.add_child(screen)
	screen.show_result(res)
	screen.continue_pressed.connect(func() -> void: SceneFader.go(get_tree(), next_scene))


func _route_rival() -> RivalDef:
	if route == null or String(route.rival_id) == "":
		return null
	return load("res://data/rivals/%s.tres" % route.rival_id) as RivalDef


# ---------------------------------------------------------------- T-156: abertura "frente a frente"

## Decide a versao (cheia, curta, nenhuma) e monta a abertura. Depuracao: --intro=full|short|none, --no-intro;
## --start= e --demo= desligam (as capturas e medicoes antigas continuam iguais).
func _setup_intro(args: PackedStringArray) -> void:
	var forced: String = ""
	for a in args:
		if a.begins_with("--intro="):
			forced = a.substr(8)
	var pair: Array[int] = [player, -1]
	var cards: Array[Dictionary] = []
	var kind: String = DuelPlan.NONE
	if online:
		kind = String(Net.pending_setup.get("intro", DuelPlan.NONE)) if forced == "" else forced
		pair = DuelPlan.online_pair(Net.pending_setup["grid"], player)
		for k in pair:
			for e in Net.pending_setup["grid"]:
				if int(e["idx"]) == k:
					cards.append(DuelCards.online(e, sim.trucks[k], int(Net.pending_setup["seed"])))
		if _net_racing:
			kind = DuelPlan.NONE
	else:
		var rv: RivalDef = _route_rival()
		var key: String = "%s:%s" % [route.id, rv.id] if rv != null else ""
		var rematch: bool = key != "" and String(gs.last_duel_key) == key
		if rv != null:
			pair = [player, 1]
			cards = [DuelCards.player(gs, hash(key)), DuelCards.rival(rv, sim.trucks[1])]
		var debug_off: bool = _countdown <= 0.0 or _demo.active() or "--no-intro" in args
		kind = DuelPlan.pick_offline(rv != null, sim.trucks.size(), rematch, forced if forced != "" else (DuelPlan.NONE if debug_off else ""))
		if kind != DuelPlan.NONE:
			gs.last_duel_key = key
	if kind == DuelPlan.FULL and (pair[1] < 0 or cards.size() < 2):
		kind = DuelPlan.SHORT
	_intro = DuelIntro.new()
	add_child(_intro)
	_intro.online = online
	_intro.demo = _demo
	_intro.audio = _audio
	_intro.sun = _sun
	if pair[1] >= 0:
		var j: int = pair[1] if pair[1] < player else pair[1] - 1        # _rival_audio: os outros caminhoes em ordem
		_intro.rival_engine = _rival_audio[j] if j < _rival_audio.size() else null
		var h: String = _horns[pair[1]] if pair[1] < _horns.size() else ""
		_intro.rival_horn = h if h.begins_with("horn_musical") else "horn_musical_1"
	_intro.finished.connect(_on_intro_finished)
	_intro.prepared.connect(func() -> void:          # T-208: abertura preparada (shaders aquecidos)
		LoadClock.mark("abertura_preparada")
		if online:
			Net.race_loaded())
	_intro.setup(kind, tod, _trucks, pair, cards, DuelCards.place_of(route))
	if _intro.running():
		_cam.attributes = UltraLook.intro_attributes(int(Settings.quality))   # T-189: profundidade de campo (Ultra)
		_hud_layer.visible = false
		print("ABERTURA: %s (%.1f s antes da contagem)" % [kind, DuelPlan.intro_seconds(kind)])


func _on_intro_finished() -> void:
	_cam.attributes = null
	_hud_layer.visible = not _nohud and not get_tree().paused
	_lights_state = not (tod.headlights or _tunnel.amount > 0.3)    # reaplica as luzes da hora do dia
	_update_truck_lights()
	if not online:
		_countdown = Protocol.COUNTDOWN_SECONDS
	_update_visuals(1.0, 0.0)
	_snap_camera()


## Quadro da abertura: a simulacao nao anda; o resto do mundo segue vivo (transito parado, trens, capturas).
func _intro_frame(dt: float) -> void:
	_cinema.update_flash(dt)
	_traffic3d.refresh()
	if _life != null:                      # T-189: passaros e fumaca seguem vivos na abertura
		_life.update(dt, _player_z(), _cam.global_position, _tunnel.amount, sim.trucks[player].speed)
	_demo.update(get_viewport(), sim.trucks[player], dt)
	if _intro.skipped:                     # online depois de pular: espera na largada, na tomada do alinhamento
		_update_visuals(1.0, dt)
		_align_camera()


## Online: segundos desde que o servidor comecou a contagem (setup + ping; igual em todos os clientes).
func _net_elapsed() -> float:
	if not Net.race_clock_started:                  # T-208: o servidor ainda espera alguem montar a corrida
		return 0.0
	var total: float = float(Net.pending_setup.get("countdown_total", Protocol.COUNTDOWN_SECONDS))
	return DuelPlan.online_elapsed(total, float(Net.pending_setup.get("countdown", total)), Net.pending_setup_msec,
		Time.get_ticks_msec(), Net.ping_ms)


## Tomada do alinhamento (comeco da contagem): alto atras do grid, descendo ate a camera da corrida.
func _align_camera() -> bool:
	if _intro == null or _intro.kind == DuelPlan.NONE or _countdown <= 0.0:
		return false
	var pr: float = DuelShots.align_progress(_countdown)
	if pr < 0.0:
		return false
	var zf: float = -INF
	var xm: float = 0.0
	for t in sim.trucks:
		zf = maxf(zf, t.z)
		xm += t.x
	var c: Array[Vector3] = _cam_target(_player_z(), _player_x())
	DuelShots.align_camera(_cam, path, zf, xm / float(sim.trucks.size()), pr, c[0], c[1])
	return true


## Capturas (--shots=) do alinhamento e da contagem.
func _intro_count_shots(before: float) -> void:
	if _intro == null or _intro.kind == DuelPlan.NONE:
		return
	if before > 2.4 and _countdown <= 2.4:
		_demo.queue_shot("duelo_5_alinhamento", 0.0)
	if before > 1.0 and _countdown <= 1.0:
		_demo.queue_shot("duelo_6_contagem", 0.0)
	if _intro.kind == DuelPlan.FULL:                 # T-204: prints da contagem no relogio da abertura (5,5 / 6,5 / 7,5 s)
		var total: float = DuelPlan.total_seconds(DuelPlan.FULL)
		for st in DuelPlan.COUNT_SHOT_TIMES:
			var left: float = total - st
			if before > left and _countdown <= left:
				_demo.queue_shot("abertura_%05.2fs" % st, 0.0)


## Depuracao (--fps-log): quantas superficies (≈ chamadas de desenho) cada parte da cena tem.
func _print_surface_budget() -> void:
	var out: Dictionary = {}
	for c in get_children():
		var key: String = c.get_class() if c.get_script() == null else String(c.get_script().get_global_name())
		var n: int = 0
		for m in c.find_children("*", "GeometryInstance3D", true, false) + ([c] if c is GeometryInstance3D else []):
			if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
				n += (m as MeshInstance3D).mesh.get_surface_count()
			elif m is MultiMeshInstance3D and (m as MultiMeshInstance3D).multimesh != null and (m as MultiMeshInstance3D).multimesh.mesh != null:
				n += (m as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
		out[key] = int(out.get(key, 0)) + n
	print("SUPERFICIES: ", out)
