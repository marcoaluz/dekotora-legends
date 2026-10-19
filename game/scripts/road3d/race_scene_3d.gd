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
var _horns: Array[String] = []          # som de buzina de cada caminhao (peca instalada ou a basica)
var _was_hard_braking: bool = false
var _impact: ImpactFx                   # T-141: faiscas, pedacos, chacoalhada e tremor das batidas
var _rail: Railway3D                    # T-154: ferrovia e trens


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # recebe o botao de pausa mesmo pausado
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
	path = TrackPath.new(sim.track)
	var q: int = int(Settings.quality)
	get_viewport().scaling_3d_scale = [0.6, 0.8, 1.0][q]      # menos pixels no celular
	get_viewport().msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	tod = _resolve_time_of_day()
	var scenery: StringName = route.scenery if route != null else &"city"
	var world: Dictionary = WorldEnv.create(self, false, tod, scenery == &"mountain")
	var tunnels: Array[Vector2] = route.tunnels if route != null else ([] as Array[Vector2])
	var road := RoadMesh.new()
	add_child(road)
	road.build(path, scenery, tod, tunnels)
	var furniture := RoadFurniture.new()
	add_child(furniture)
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
	_tunnel = Tunnel3D.new()
	add_child(_tunnel)
	_tunnel.build(path, tunnels, scenery, world["sun"], world["env"])
	_tunnel.exited.connect(func() -> void:
		_cinema.tunnel_flash(tod.day_amount)
		_demo.queue_shot("saida_tunel", 0.12))
	_rail = Railway3D.new()                        # T-154: ferrovia ao lado da pista, viadutos e trens (so visual)
	add_child(_rail)
	_rail.build(path, String(route.id) if route != null else "", scenery, tod)
	var city := CityBuilder.new()
	city.keep_out = RailwayLayout.keep_out(_rail.lines)
	add_child(city)
	city.build(path, 21, scenery, tod)
	var side := Roadside3D.new()
	add_child(side)
	side.build(path, scenery, tod, tunnels)
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
	_cam.far = 900.0
	add_child(_cam)
	_cam.make_current()
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
	event_hud.alert_shown.connect(func(_kind: int) -> void:
		_audio.event_alert()
		Input.vibrate_handheld(60))
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_autoplay = "--autoplay" in args
	_debug_events = "--debug-events" in args
	_demo = RaceDemo.new(args)
	if not online:
		_demo.setup(sim)
		for k in sim.trucks.size():
			_prev[k] = Vector2(sim.trucks[k].z, sim.trucks[k].x)
	var v0: float = 30.0
	for a in args:
		if a.begins_with("--start-speed="):            # depuracao: velocidade inicial com --start (m/s)
			v0 = float(a.substr(14))
	if "--nohud" in args:
		layer.visible = false
	for a in args:
		if a.begins_with("--start="):
			var z0: float = float(a.substr(8))
			for k in sim.trucks.size():
				sim.trucks[k].z = z0 - float(k) * 14.0
				sim.trucks[k].speed = v0
				_prev[k] = Vector2(sim.trucks[k].z, sim.trucks[k].x)
			_countdown = 0.0
	if DisplayServer.is_touchscreen_available() or "--touch" in args or gs.profile.get("force_touch", false):
		var tc := TouchControls.new()
		tc.target = input
		layer.add_child(tc)
	_build_pause_menu()
	_fps_log = "--fps-log" in args
	if _fps_log:
		_print_surface_budget()
	if "--paused" in args:                       # depuracao: abre ja na tela de pausa (capturas)
		_toggle_pause.call_deferred()
	if _demo.mode.begins_with("result"):         # --demo=result|result_lose|result_timeout: so a tela (nao grava no perfil)
		_result_shown = true
		_open_result.call_deferred(ResultScreen.demo_result(_demo.mode), "res://scenes/menu/main_menu.tscn")
	_setup_audio()
	_update_visuals(0.0, 0.0)
	_snap_camera()
	var hidden: Vector3 = path.world_point(_player_z() + 22.0, _player_x(), -1.2)   # embaixo do asfalto, na frente da camera
	_impact.warmup(hidden)
	_brake_fx.warmup(hidden)
	DebugShot.arm(self, 4.0)            # --shot=ARQUIVO.png (capturas, T-138)


## Hora do dia: a da rota, ou --time=night|dusk|day (depuracao/capturas).
func _resolve_time_of_day() -> TimeOfDay:
	var tid: StringName = route.time_of_day if route != null else &"night"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--time="):
			tid = StringName(a.substr(7))
	return TimeOfDay.by_id(tid)


func _setup_audio() -> void:
	_audio = RaceAudio.new()
	_audio.sim = sim                             # T-141: volume das batidas dos outros pela distancia
	add_child(_audio)
	var sets: Dictionary = {"eng_i6_std": "i6_std", "eng_i6_tuned": "i6_tuned", "eng_v8": "v8"}
	var eng_id: String = String(gs.profile["engine"])
	var music: String = "race_night_synthwave"
	if route != null:
		var rv: RivalDef = load("res://data/rivals/%s.tres" % route.rival_id) as RivalDef
		if rv != null and rv.boss:
			music = "boss_enka_rock"
		elif not tod.headlights:
			music = "race_day_rock"
	_audio.setup(sim.trucks[player], String(sets.get(eng_id, "i6_std")), String(gs.profile["turbo"]),
		String(gs.profile["exhaust"]) == "exh_straight", music)
	for k in range(_trucks.size()):
		if k != player:
			if not online:
				_rival_idx.append(k)
			_rival_audio.append(_audio.make_rival_engine(_trucks[k], "i6_std"))
		var sfx := TruckSfx.new()
		var horn: String = gs.installed_horn() if k == player and not online else (_horns[k] if k < _horns.size() else "")
		sfx.setup(self if k == player else _trucks[k], k == player, horn)
		_truck_sfx.append(sfx)


## Corrida online: monta os caminhoes do grid recebido do servidor (pecas, tinta, bots).
func _spawn_field_online() -> void:
	var grid: Array = Net.pending_setup["grid"]
	for entry in grid:
		var i: int = int(entry["idx"])
		var node := TruckNode.new()
		node.chrome_mode = "day" if tod.day_amount > 0.5 else "night"
		node.body_kind = String(entry["loadout"].get("body", "base"))      # o Canter tem outro tamanho na simulacao
		node.cab_kind = CabCatalog.normalize(entry["loadout"].get("cab", ""))   # descritor antigo/sem cabine -> padrao
		node.plates = _plates
		add_child(node)
		var defs: Array[PartDef] = []
		for p in entry["loadout"]["parts"]:
			var d: PartDef = gs.part(String(p["id"]))
			if d != null:
				defs.append(d)
		node.apply_loadout(defs)
		_horns.append(_horn_of(defs))
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
			_countdown = 0.0)
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


## Grid de largada: jogador + rival da rota + 2 bots; cada um com pecas e acessorios proprios.
func _spawn_field() -> void:
	var xs: Array[float] = Room.GRID_X
	var rival: RivalDef = null
	if route != null:
		rival = load("res://data/rivals/%s.tres" % route.rival_id) as RivalDef
	var base_diff: int = rival.difficulty if rival != null else BotDriver.Difficulty.NORMAL
	for i in 4:
		var idx: int = sim.add_truck(-float(i) * 14.0, xs[i])
		var t: TruckSim = sim.trucks[idx]
		t.is_bot = i != 0
		var node := TruckNode.new()
		node.body_kind = String(gs.profile.get("body", "base")) if i == 0 else RIVAL_BODIES[i % RIVAL_BODIES.size()]
		node.cab_kind = CabCatalog.normalize(gs.profile.get("cab", "")) if i == 0 else RIVAL_CABS[i % RIVAL_CABS.size()]
		node.chrome_mode = "day" if tod.day_amount > 0.5 else "night"
		node.plates = _plates
		if i == 0:                                       # gancho: placa escolhida pelo jogador (ainda sem tela)
			node.plate_cell = int(gs.profile.get("plate_cell", -1))
		add_child(node)
		if i == 0:
			gs.configure_truck(t)
			node.apply_loadout(gs.installed_part_defs())
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
			_horns[i] = _horn_of(defs)
			_bots.append(BotDriver.new(diff, 100 + i, xs[i], i == 1 and rival != null))
		node.set_headlights(tod.headlights)
		node.set_light_pattern(String(gs.profile.get("light_pattern", "steady")) if i == 0 else LightPatterns.IDS[i % LightPatterns.IDS.size()])
		_trucks.append(node)
		_prev.append(Vector2(t.z, t.x))


## Buzina que a lista de pecas traz (PartDef.horn) ou a basica (T-144).
static func _horn_of(defs: Array[PartDef]) -> String:
	for d in defs:
		if d != null and d.horn != "":
			return d.horn
	return "horn_air_basic"


func _build_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 30
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.visible = false
	add_child(_pause_layer)
	var menu := PauseMenu.new()                  # pausa SEM escurecer a corrida (ATB-1), centralizada (T-138)
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
	if _result_shown or online:
		return
	get_tree().paused = not get_tree().paused
	_pause_layer.visible = get_tree().paused
	_hud_layer.visible = not get_tree().paused
	if _pause_layer.visible and _pause_first != null:
		_pause_first.grab_focus()
	if _pause_layer.visible and _demo.shot_dir != "":
		get_tree().create_timer(0.8, true).timeout.connect(func() -> void: _demo.snap(get_viewport(), "pausa"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	if _fps_log:                                 # depuracao: media de FPS a cada 5 s no terminal
		_fps_t += delta
		_fps_n += 1
		_fps_age += delta
		if delta > 0.05 and _fps_age > 1.5:
			print("PICO: quadro de %.0f ms (t=%.1f s)" % [delta * 1000.0, sim.time])
		_fps_max_calls = maxi(_fps_max_calls, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if _fps_t >= 5.0:
			print("FPS medio: %.1f  (desenhos: %d, max %d no periodo; triangulos: %d, texturas: %.1f MB, video: %.1f MB)" % [_fps_n / _fps_t, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), _fps_max_calls, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
			_fps_t = 0.0
			_fps_n = 0
			_fps_max_calls = 0
	var dt: float = minf(delta, 0.1)
	if _countdown > 0.0:
		var before: float = _countdown
		_countdown -= dt
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
		node.transform = _impact.jolt(k, path.vehicle_transform(z, x, t.length, t.body_yaw(), t.lean() * 0.11))
		node.animate(t.speed, dt, t.lean())
		node.set_signal(t.signal_dir)
		if _cam != null:
			_brake_fx.update_truck(k, node, t, _cam.global_position, dt, tod.headlights)
	_traffic3d.refresh()
	if _cam != null:
		_rail.update(dt, _player_z(), sim.trucks[player].speed, _cam.global_position)


func _cam_target(z: float, x: float) -> Array[Vector3]:
	var k: float = sim.trucks[player].length / Collision.LEN       # Canter (7 m): camera um pouco mais perto e baixa
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
	if _demo.camera(_cam, path, _player_z(), _player_x(), t.length):
		return
	if _cinema.apply_cut(dt, _cam, _trucks[player]):
		_speed_fx.update(t.speed, dt)
		return
	var z: float = _player_z()
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
	_cam.global_position += _cam.global_basis * (ex[2] as Vector3)
	_cam.global_position += _cam.global_basis * _impact.sway_camera(player)     # T-152: a camera sente o tranco
	_cam.fov = lerpf(_cam.fov, 56.0 + _speed_fx.fov_extra(t.speed) + t.draft * 6.0, minf(3.0 * dt, 1.0))
	_speed_fx.update(t.speed, dt)
	_scrape_sparks(t, dt)


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
	var on: bool = tod.headlights or _tunnel.amount > 0.3
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


## Depuracao (--fps-log): quantas superficies (≈ chamadas de desenho) cada parte da cena tem.
func _print_surface_budget() -> void:
	var out: Dictionary = {}
	for c in get_children():
		var key: String = c.get_class() if c.get_script() == null else String(c.get_script().get_global_name())
		var n: int = 0
		for m in c.find_children("*", "GeometryInstance3D", true, false) + ([c] if c is GeometryInstance3D else []):
			if m is MeshInstance3D and (m as MeshInstance3D).mesh != null:
				n += (m as MeshInstance3D).mesh.get_surface_count()
			elif m is MultiMeshInstance3D and (m as MultiMeshInstance3D).multimesh.mesh != null:
				n += (m as MultiMeshInstance3D).multimesh.mesh.get_surface_count()
		out[key] = int(out.get(key, 0)) + n
	print("SUPERFICIES: ", out)
