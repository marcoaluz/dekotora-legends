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


func _ready() -> void:
	sim = RaceSim.new(Track.make_test_track(), TrafficSim.Density.NORMAL)
	path = TrackPath.new(sim.track)
	WorldEnv.create(self)
	var road := RoadMesh.new()
	add_child(road)
	road.build(path)
	var city := CityBuilder.new()
	add_child(city)
	city.build(path)
	var side := Roadside3D.new()
	add_child(side)
	side.build(path)
	_fx = Fx3D.new()
	add_child(_fx)
	_traffic3d = Traffic3D.new()
	add_child(_traffic3d)
	_traffic3d.setup(path, sim.traffic)
	var xs: Array[float] = [0.25, -0.75, -0.25, 0.75]
	var diffs: Array[int] = [-1, BotDriver.Difficulty.EASY, BotDriver.Difficulty.NORMAL, BotDriver.Difficulty.HARD]
	for i in 4:
		var idx: int = sim.add_truck(-float(i) * 14.0, xs[i])
		var t: TruckSim = sim.trucks[idx]
		t.is_bot = i != 0
		t.set_loadout(_default_loadout(i))
		var node := TruckNode.new()
		add_child(node)
		if i != 0:
			node.set_paint_color(FIELD_COLORS[i])
			_bots.append(BotDriver.new(diffs[i], 100 + i, xs[i]))
		_trucks.append(node)
		_prev.append(Vector2(t.z, t.x))
	_cam = Camera3D.new()
	_cam.fov = 62.0
	_cam.near = 0.2
	_cam.far = 900.0
	add_child(_cam)
	_cam.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 5
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
	if DisplayServer.is_touchscreen_available() or "--touch" in args:
		var tc := TouchControls.new()
		tc.target = input
		layer.add_child(tc)
	_update_visuals(0.0, 0.0)
	_snap_camera()


func _default_loadout(i: int) -> Array[Dictionary]:
	match i:
		0:   # jogador: build "Equilibrado" do BALANCEAMENTO
			return [
				DamageModel.make_part("fb_chrome_steps", ["front"], 420.0, 220.0, 25),
				DamageModel.make_part("skirt_light_bar", ["left", "right"], 180.0, 90.0, 25),
				DamageModel.make_part("andon_kanji", ["rear"], 60.0, 30.0, 15),
				DamageModel.make_part("roof_lights_row", ["roof"], 30.0, 20.0, 15),
			]
		_:
			return [DamageModel.make_part("fb_basic", ["front"], 120.0, 80.0, 5),
				DamageModel.make_part("rb_basic", ["rear"], 100.0, 80.0, 3)]


func _process(delta: float) -> void:
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
	if _autoplay and not _fps_printed and Time.get_ticks_msec() > 6000:
		_fps_printed = true
		print("FPS_MEDIDO: ", Engine.get_frames_per_second())
	if sim.is_over() and not _result_shown:
		_result_shown = true
		_show_result()


func _handle_events(events: Array[Dictionary]) -> void:
	for e in events:
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
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var screen := ResultScreen.new()
	layer.add_child(screen)
	screen.show_result(res)
	screen.continue_pressed.connect(func() -> void: get_tree().reload_current_scene())
