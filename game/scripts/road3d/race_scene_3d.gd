extends Node3D
## Corrida em 3D (plano B): liga a simulacao (a mesma do plano A) a uma apresentacao 3D com
## estrada em malha, caminhoes .glb PBR, transito, cidade e camera atras do jogador.
## Debug: -- --autoplay  --start=600  --touch  --shot (sem HUD de toque)

const FIELD_COLORS: Array[Color] = [Color("#e9eef5"), Color("#d1303f"), Color("#3a73d6"), Color("#3fb26f")]

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
var _hud: RaceHud
var _fx: Fx3D
var _autoplay: bool = false
var _countdown: float = 3.0
var _steer_smooth: float = 0.0
var _shake: float = 0.0
var _result_shown: bool = false
var _fps_printed: bool = false
var _debug_events: bool = false
var gs: Node
var route: RouteDef
var _pause_layer: CanvasLayer
var _pause_root: Control
var _pause_first: Button
var _audio: RaceAudio
var _rival_audio: Array[EngineAudio] = []
var _prev_passing: bool = false
var online: bool = false
var sync: ClientSync
var _rival_idx: Array[int] = []
var _cmd_acc: float = 0.0
var _auto_driver: BotDriver


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # recebe o botao de pausa mesmo pausado
	gs = get_node("/root/GameState")
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
		var density: int = route.traffic if route != null else TrafficSim.Density.NORMAL
		sim = RaceSim.new(track, density)
		sim.freight = route.freight if route != null else 25000
	path = TrackPath.new(sim.track)
	var q: int = int(Settings.quality)
	get_viewport().scaling_3d_scale = [0.6, 0.8, 1.0][q]      # menos pixels no celular
	get_viewport().msaa_3d = Viewport.MSAA_2X if q >= 2 else Viewport.MSAA_DISABLED
	WorldEnv.create(self)
	var road := RoadMesh.new()
	add_child(road)
	road.build(path)
	var city := CityBuilder.new()
	add_child(city)
	city.build(path, 21, route.scenery if route != null else &"city")
	var side := Roadside3D.new()
	add_child(side)
	side.build(path)
	_fx = Fx3D.new()
	add_child(_fx)
	_traffic3d = Traffic3D.new()
	add_child(_traffic3d)
	_traffic3d.setup(path, sim.traffic)
	if online:
		_spawn_field_online()
		_connect_net()
	else:
		_spawn_field()
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.2
	_cam.far = 900.0
	add_child(_cam)
	_cam.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 5
	layer.scale = Vector2(2, 2)          # HUD e toque desenhados em 480x270
	add_child(layer)
	_hud = RaceHud.new()
	_hud.bind(sim, player)
	layer.add_child(_hud)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_autoplay = "--autoplay" in args
	_debug_events = "--debug-events" in args
	for a in args:
		if a.begins_with("--start="):
			var z0: float = float(a.substr(8))
			for k in sim.trucks.size():
				sim.trucks[k].z = z0 - float(k) * 14.0
				sim.trucks[k].speed = 30.0
				_prev[k] = Vector2(sim.trucks[k].z, sim.trucks[k].x)
			_countdown = 0.0
	if DisplayServer.is_touchscreen_available() or "--touch" in args or gs.profile.get("force_touch", false):
		var tc := TouchControls.new()
		tc.target = input
		layer.add_child(tc)
	_build_pause_menu()
	if "--paused" in args:                       # depuracao: abre ja na tela de pausa (capturas)
		_toggle_pause.call_deferred()
	_setup_audio()
	_update_visuals(0.0, 0.0)
	_snap_camera()


func _setup_audio() -> void:
	_audio = RaceAudio.new()
	add_child(_audio)
	var sets: Dictionary = {"eng_i6_std": "i6_std", "eng_i6_tuned": "i6_tuned", "eng_v8": "v8"}
	var eng_id: String = String(gs.profile["engine"])
	var music: String = "race_night_synthwave"
	if route != null:
		var rv: RivalDef = load("res://data/rivals/%s.tres" % route.rival_id) as RivalDef
		if rv != null and rv.boss:
			music = "boss_enka_rock"
		elif not route.night:
			music = "race_day_rock"
	_audio.setup(sim.trucks[player], String(sets.get(eng_id, "i6_std")), String(gs.profile["turbo"]),
		String(gs.profile["exhaust"]) == "exh_straight", music)
	for k in range(_trucks.size()):
		if k != player:
			if not online:
				_rival_idx.append(k)
			_rival_audio.append(_audio.make_rival_engine(_trucks[k], "i6_std"))


## Corrida online: monta os caminhoes do grid recebido do servidor (pecas, tinta, bots).
func _spawn_field_online() -> void:
	var grid: Array = Net.pending_setup["grid"]
	for entry in grid:
		var i: int = int(entry["idx"])
		var node := TruckNode.new()
		add_child(node)
		var defs: Array[PartDef] = []
		for p in entry["loadout"]["parts"]:
			var d: PartDef = gs.part(String(p["id"]))
			if d != null:
				defs.append(d)
		node.apply_loadout(defs)
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
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.scale = Vector2(2, 2)
	add_child(layer)
	var screen := ResultScreen.new()
	layer.add_child(screen)
	screen.show_result(result)
	screen.continue_pressed.connect(func() -> void: SceneFader.go(get_tree(), "res://scenes/lobby/lobby.tscn"))


## Grid de largada: jogador + rival da rota + 2 bots; cada um com pecas e acessorios proprios.
func _spawn_field() -> void:
	var xs: Array[float] = [0.25, -0.75, -0.25, 0.75]
	var rival: RivalDef = null
	if route != null:
		rival = load("res://data/rivals/%s.tres" % route.rival_id) as RivalDef
	var base_diff: int = rival.difficulty if rival != null else BotDriver.Difficulty.NORMAL
	for i in 4:
		var idx: int = sim.add_truck(-float(i) * 14.0, xs[i])
		var t: TruckSim = sim.trucks[idx]
		t.is_bot = i != 0
		var node := TruckNode.new()
		node.body_kind = String(gs.profile.get("body", "base")) if i == 0 else ["base", "leve", "longo"][i % 3]
		node.cab_kind = String(gs.profile.get("cab", "padrao")) if i == 0 else ["classica", "aero", "alta"][i % 3]
		add_child(node)
		if i == 0:
			gs.configure_truck(t)
			node.apply_loadout(gs.installed_part_defs())
			node.set_paint_color(Color(String(gs.profile.get("paint", "#e9eef5"))))
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
			_bots.append(BotDriver.new(diff, 100 + i, xs[i]))
		_trucks.append(node)
		_prev.append(Vector2(t.z, t.x))


func _build_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 30
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_layer.visible = false
	add_child(_pause_layer)
	var root := Control.new()
	root.theme = UiTheme.make()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	# tela de pausa: titulo + 4 blocos com icone (continuar, opcoes, menu, sair do jogo)
	var col := VBoxContainer.new()
	col.position = Vector2(150, 140)
	col.custom_minimum_size = Vector2(660, 0)
	col.add_theme_constant_override("separation", 18)
	root.add_child(col)
	var ic := TextureRect.new()
	ic.texture = UiKit.icon("pause")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(0, 40)
	col.add_child(ic)
	var title: Label = UiKit.heading(Tr.t("race.paused"), 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	col.add_child(row)
	var tiles: Array = [
		[Tr.t("race.resume"), "play", _toggle_pause],
		[Tr.t("menu.settings"), "settings", _pause_options],
		[Tr.t("race.exit"), "house", func() -> void:
			get_tree().paused = false
			SceneFader.go(get_tree(), "res://scenes/menu/main_menu.tscn")],
		[Tr.t("race.quit_game"), "log-out", func() -> void: get_tree().quit()],
	]
	_pause_first = null
	for t in tiles:
		var b: Button = UiTheme.button(String(t[0]), Vector2(150, 120))
		b.icon = UiKit.icon(String(t[1]))
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.add_theme_constant_override("icon_max_width", 40)
		b.add_theme_font_size_override("font_size", 17)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(t[2])
		row.add_child(b)
		if _pause_first == null:
			_pause_first = b
			b.add_theme_stylebox_override("normal", UiTheme.box(Color(1, 0.18, 0.53, 0.22), UiTheme.PINK, 1, 10, 10))
	_pause_root = root


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
	if _pause_layer.visible and _pause_first != null:
		_pause_first.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var dt: float = minf(delta, 0.1)
	if _countdown > 0.0:
		_countdown -= dt
	if online:
		_process_online(dt)
		return
	var racing: bool = _countdown <= 0.0 and not sim.is_over()
	if racing:
		var cmd: Commands = input.poll()
		if _autoplay:
			cmd = Commands.make(0.0, 1.0, 0.0)
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
	for k in sim.trucks.size():
		_trucks[k].sync_damage(sim.trucks[k].loadout)
	if _autoplay and not _fps_printed and Time.get_ticks_msec() > 6000:
		_fps_printed = true
		print("FPS_MEDIDO: ", Engine.get_frames_per_second(), "  draw_calls=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), "  tris=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), "  mem_MB=", OS.get_static_memory_usage() / 1048576)
	if sim.is_over() and not _result_shown:
		_result_shown = true
		_show_result()


func _process_online(dt: float) -> void:
	if _countdown > 0.0:
		pass
	elif not _result_shown:
		var cmd: Commands = input.poll()
		if _autoplay:
			if _auto_driver == null:
				_auto_driver = BotDriver.new(BotDriver.Difficulty.NORMAL, 31, 0.25)
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
	for k in sim.trucks.size():
		_trucks[k].sync_damage(sim.trucks[k].loadout)


func _player_z() -> float:
	return sync.my_draw_z() if online else sim.trucks[player].z


func _player_x() -> float:
	return sync.my_draw_x() if online else sim.trucks[player].x


func _update_audio(dt: float) -> void:
	var t: TruckSim = sim.trucks[player]
	_audio.update(dt, t, _countdown)
	for k in _rival_audio.size():
		var rt: TruckSim = sim.trucks[_rival_idx[k]]
		var r01: float = clampf((rt.rpm - EngineModel.IDLE_RPM) / (rt.engine.redline_rpm - EngineModel.IDLE_RPM), 0.0, 1.0)
		_rival_audio[k].update(dt, r01, rt.engine.throttle_now, rt.boost, 1.0, rt.speed)
	if t.passing_active and not _prev_passing:
		_audio.passing_pressed(gs.installed_horn())
	_prev_passing = t.passing_active


func _handle_events(events: Array[Dictionary]) -> void:
	for e in events:
		_audio.on_event(e, player)
		if _debug_events:
			print("EVENTO frame=%d %s" % [Engine.get_frames_drawn(), e])
		match String(e["type"]):
			"overtake":
				if int(e["truck"]) == player:
					_hud.show_banner(Tr.t("hud.overtake"))
			"finish":
				if int(e["truck"]) == player:
					_hud.show_banner(Tr.t("hud.finish", [int(e["position"])]), 3.0)
			"truck":
				var f: float = float(e["force"])
				var ia: int = int(e["a"])
				var ib: int = int(e["b"])
				_fx.sparks(_fx.zone_point(_trucks[ia], String(e["zone_a"])), f)
				_fx.sparks(_fx.zone_point(_trucks[ib], String(e["zone_b"])), f)
				_spawn_debris(ia, e["broken_a"], String(e["zone_a"]))
				_spawn_debris(ib, e["broken_b"], String(e["zone_b"]))
				if ia == player or ib == player:
					_shake = maxf(_shake, clampf(f / 12.0, 0.15, 1.0))
			"traffic":
				var ti: int = int(e["truck"])
				_fx.sparks(_fx.zone_point(_trucks[ti], String(e["zone"])), float(e["force"]))
				_spawn_debris(ti, e["broken"], String(e["zone"]))
				if ti == player:
					_shake = maxf(_shake, clampf(float(e["force"]) / 12.0, 0.15, 1.0))
			"passing_scare":
				if int(e["to"]) == player:
					_shake = maxf(_shake, 0.4)


func _spawn_debris(truck_index: int, broken: Array, zone: String) -> void:
	for id in broken:
		var node: TruckNode = _trucks[truck_index]
		var side: float = -1.0 if zone == "left" else (1.0 if zone == "right" else 0.0)
		var vel: Vector3 = node.global_transform.basis * Vector3(side * 3.0, 0.0, -2.0)
		_fx.debris(_fx.zone_point(node, zone), vel)


func _update_visuals(alpha: float, dt: float) -> void:
	for k in sim.trucks.size():
		var t: TruckSim = sim.trucks[k]
		var z: float = lerpf(_prev[k].x, t.z, alpha)
		var x: float = lerpf(_prev[k].y, t.x, alpha)
		if online:
			z = _player_z() if k == player else t.z
			x = _player_x() if k == player else t.x
		var node: TruckNode = _trucks[k]
		node.transform = path.vehicle_transform(z, x, 12.0, -t.lateral_vel * 0.12, t.lateral_vel * 0.02)
		node.animate(t.speed, dt, clampf(t.lateral_vel / 1.6, -1.0, 1.0))
	_traffic3d.refresh()


func _cam_target(z: float, x: float) -> Array[Vector3]:
	var pos: Vector3 = path.world_point(z - 14.5, x * 0.85, 5.6)
	var look: Vector3 = path.world_point(z + 14.0, x * 0.45, 1.8)
	return [pos, look]


func _snap_camera() -> void:
	var t: TruckSim = sim.trucks[player]
	var c: Array[Vector3] = _cam_target(_player_z(), _player_x())
	_cam.global_position = c[0]
	_cam.look_at(c[1], Vector3.UP)


func _update_camera(dt: float) -> void:
	var t: TruckSim = sim.trucks[player]
	var c: Array[Vector3] = _cam_target(_player_z() + t.speed * 0.02, _player_x())
	var k: float = 1.0 - exp(-14.0 * dt)
	_cam.global_position = _cam.global_position.lerp(c[0], k)
	var look: Vector3 = c[1]
	_shake = maxf(_shake - dt * 2.5, 0.0)
	var s: float = _shake * 0.25
	if s > 0.0:
		_cam.global_position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
	_cam.look_at(look, Vector3.UP)
	_cam.fov = lerpf(_cam.fov, 58.0 + t.speed * 0.25 + t.draft * 6.0, minf(3.0 * dt, 1.0))


func _update_hud() -> void:
	_hud.countdown = _countdown
	for k in sim.trucks.size():
		var eng: float = float(sim.trucks[k].systems["engine"])
		_fx.set_smoke(k, _trucks[k], clampf((60.0 - eng) / 60.0, 0.0, 1.0))


func _show_result() -> void:
	var res: Dictionary = sim.result_for(player)
	print("RESULTADO: ", res)
	_audio.finish_race(int(res["position"]) == 1)
	gs.apply_race_result(res, String(route.id) if route != null else "", sim.trucks[player])
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.scale = Vector2(2, 2)
	add_child(layer)
	var screen := ResultScreen.new()
	layer.add_child(screen)
	screen.show_result(res)
	screen.continue_pressed.connect(func() -> void: SceneFader.go(get_tree(), "res://scenes/menu/main_menu.tscn"))
