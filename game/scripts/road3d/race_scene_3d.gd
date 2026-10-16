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
var _audio: RaceAudio
var _rival_audio: Array[EngineAudio] = []
var _prev_passing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS     # recebe o botao de pausa mesmo pausado
	gs = get_node("/root/GameState")
	route = gs.pending_route
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route="):
			route = load("res://data/routes/%s.tres" % a.substr(8)) as RouteDef
	var track: Track = route.build_track() if route != null else Track.make_test_track()
	var density: int = route.traffic if route != null else TrafficSim.Density.NORMAL
	sim = RaceSim.new(track, density)
	sim.freight = route.freight if route != null else 25000
	path = TrackPath.new(sim.track)
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
	for k in range(1, _trucks.size()):
		_rival_audio.append(_audio.make_rival_engine(_trucks[k], "i6_std"))


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
	var box := VBoxContainer.new()
	box.position = Vector2(340, 170)
	box.custom_minimum_size = Vector2(280, 0)
	root.add_child(box)
	box.add_child(UiTheme.label(Tr.t("race.paused"), 36, UiTheme.PINK))
	var resume: Button = UiTheme.button(Tr.t("race.resume"))
	resume.pressed.connect(_toggle_pause)
	box.add_child(resume)
	var leave: Button = UiTheme.button(Tr.t("race.exit"))
	leave.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	box.add_child(leave)


func _toggle_pause() -> void:
	if _result_shown:
		return
	get_tree().paused = not get_tree().paused
	_pause_layer.visible = get_tree().paused


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	var dt: float = minf(delta, 0.1)
	if _countdown > 0.0:
		_countdown -= dt
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
		print("FPS_MEDIDO: ", Engine.get_frames_per_second())
	if sim.is_over() and not _result_shown:
		_result_shown = true
		_show_result()


func _update_audio(dt: float) -> void:
	var t: TruckSim = sim.trucks[player]
	_audio.update(dt, t, _countdown)
	for k in _rival_audio.size():
		var rt: TruckSim = sim.trucks[k + 1]
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
					_hud.show_banner("ULTRAPASSAGEM!")
			"finish":
				if int(e["truck"]) == player:
					_hud.show_banner("CHEGADA! %do LUGAR" % int(e["position"]), 3.0)
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
		var node: TruckNode = _trucks[k]
		node.transform = path.vehicle_transform(z, x, 12.0, -t.lateral_vel * 0.12, t.lateral_vel * 0.02)
		node.animate(t.speed, dt, clampf(t.lateral_vel / 1.6, -1.0, 1.0))
	_traffic3d.refresh()


func _cam_target(z: float, x: float) -> Array[Vector3]:
	var pos: Vector3 = path.world_point(z - 11.5, x * 0.85, 4.4)
	var look: Vector3 = path.world_point(z + 16.0, x * 0.45, 1.5)
	return [pos, look]


func _snap_camera() -> void:
	var t: TruckSim = sim.trucks[player]
	var c: Array[Vector3] = _cam_target(t.z, t.x)
	_cam.global_position = c[0]
	_cam.look_at(c[1], Vector3.UP)


func _update_camera(dt: float) -> void:
	var t: TruckSim = sim.trucks[player]
	var c: Array[Vector3] = _cam_target(t.z + t.speed * 0.02, t.x)
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
	screen.continue_pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
