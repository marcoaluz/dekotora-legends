extends SceneTree
## Measures how well trucks follow their lane in curves (T-132).
## For each route: player holding full throttle without steering, and a bot (NORMAL/HARD).
## Reports max lane deviation (m), % of time with body yaw > 2 deg / 3 deg relative to the road,
## entry overspeed ratio (speed / safe speed) and finish time.
## Usage: godot --headless --path game -s res://tools_dev/measure_lane_following.gd

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func _initialize() -> void:
	for r in ROUTES:
		var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
		_run(route, "player", -1)
		_run(route, "canter", -2)
		_run(route, "v8_twin", -3)
		_run(route, "heavy_16t", -4)
		_run(route, "bot_normal", BotDriver.Difficulty.NORMAL)
		_run(route, "bot_hard", BotDriver.Difficulty.HARD)
	quit(0)


func _run(route: RouteDef, label: String, difficulty: int) -> void:
	var track: Track = route.build_track()
	var path := TrackPath.new(track)
	var sim := RaceSim.new(track)
	var i: int = sim.add_truck(0.0, 0.0)
	var t: TruckSim = sim.trucks[i]
	var desc: Dictionary = {}
	if difficulty == -2:
		desc = {"body": "canter"}
	elif difficulty == -3:
		desc = {"engine": "eng_v8", "turbo": "turbo_twin", "exhaust": "exh_straight"}
	elif difficulty == -4:
		desc = {"body": "longo", "engine": "eng_v8", "turbo": "turbo_twin", "exhaust": "exh_straight", "cargo_kg": 16000.0}
	TruckConfig.apply(t, desc)
	var bot: BotDriver = null
	if difficulty >= 0:
		bot = BotDriver.new(difficulty, 7, 0.0, false, true)
	var max_dev: float = 0.0
	var yaw2: int = 0
	var yaw3: int = 0
	var max_yaw: float = 0.0
	var max_ratio: float = 0.0
	var max_skid: float = 0.0
	var n: int = 0
	var off: int = 0
	while t.z < track.length_m and n < 30 * 400:
		var cmd: Commands = bot.command_for(sim, i, RaceSim.FIXED_DT) if bot != null else Commands.make(0.0, 1.0, 0.0)
		sim.set_command(i, cmd)
		sim.step()
		n += 1
		var dev: float = absf(t.x - Lanes.X[t.lane]) * Track.ROAD_HALF_WIDTH_M
		max_dev = maxf(max_dev, dev)
		var yaw_deg: float = rad_to_deg(_body_yaw_vs_road(path, t))
		max_yaw = maxf(max_yaw, absf(yaw_deg))
		if absf(yaw_deg) > 2.0:
			yaw2 += 1
		if absf(yaw_deg) > 3.0:
			yaw3 += 1
		if t.offroad:
			off += 1
		var safe: float = TruckSim.curve_safe_speed(track.curve_at(t.z), t.grip())
		max_ratio = maxf(max_ratio, t.speed / safe)
		max_skid = maxf(max_skid, _skid(t))
	print("%-17s %-11s dev_max=%5.2f m  yaw>2=%5.1f%%  yaw>3=%5.1f%%  yaw_max=%5.2f deg  offroad=%5.1f%%  v/safe_max=%4.2f  skid_max=%4.2f  time=%6.1f s  changes=%d" % [
		route.id, label, max_dev, 100.0 * yaw2 / n, 100.0 * yaw3 / n, max_yaw, 100.0 * off / n, max_ratio, max_skid, n * RaceSim.FIXED_DT, t.lane_changes])


## Angle between the drawn body and the road direction at the middle of the truck.
func _body_yaw_vs_road(path: TrackPath, t: TruckSim) -> float:
	var tf: Transform3D = _draw_transform(path, t)
	var fwd: Vector3 = -tf.basis.z
	var road: Vector3 = path.forward_at(t.z + t.length * 0.5)
	return Vector2(fwd.x, fwd.z).angle_to(Vector2(road.x, road.z))


## Same call as RaceScene3D._update_visuals.
func _draw_transform(path: TrackPath, t: TruckSim) -> Transform3D:
	return path.vehicle_transform(t.z, t.x, t.length, t.body_yaw(), t.lean() * 0.11)


func _skid(t: TruckSim) -> float:
	return t.skid
