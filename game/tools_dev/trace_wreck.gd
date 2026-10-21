extends SceneTree
## T-183: trace of the --demo=crash scene without a window. The player truck drives straight into slow traffic
## (same setup as RaceDemo "crash"); after the first hit it prints the state of the car that was hit every 0.5 s,
## plus who drives near it (traffic cars and a bot truck that starts behind). Works on old and new code
## (new fields are read with get(), so "before/after" can be compared).
## godot --headless --path game -s res://tools_dev/trace_wreck.gd -- [--route=kanto_1_coast --seconds=30 --tseed=1234 --no-bot]

const DT: float = 1.0 / 30.0


func _initialize() -> void:
	var rid: String = "kanto_1_coast"
	var seconds: float = 30.0
	var tseed: int = 1234
	var with_bot: bool = true
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route="):
			rid = a.substr(8)
		elif a.begins_with("--seconds="):
			seconds = float(a.substr(10))
		elif a.begins_with("--tseed="):
			tseed = int(a.substr(8))
		elif a == "--no-bot":
			with_bot = false
	var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	var track: Track = route.build_track()
	track.events = TrackEvents.new()
	var sim := RaceSim.new(track, route.traffic, tseed)
	var p: int = sim.add_truck(300.0, 0.0)
	sim.trucks[p].speed = 28.0
	var bot: BotDriver = null
	if with_bot:
		var b: int = sim.add_truck(150.0, 0.0)
		sim.trucks[b].is_bot = true
		sim.trucks[b].speed = 28.0
		bot = BotDriver.new(BotDriver.Difficulty.HARD, 7, 0.0, false, true)
	# same as RaceDemo.setup("crash"): 3 slow cars in the player's lane
	var lane_t: int = clampi(sim.trucks[p].lane - 1, 0, 2)
	for k in 3:
		var c: TrafficSim.Car = sim.traffic.cars[k]
		c.z = sim.trucks[p].z + sim.trucks[p].length + 70.0 + k * 140.0
		c.lane = lane_t
		c.x = TrafficSim.LANES[lane_t]
		c.cruise = 9.0 if k != 1 else 6.0
		c.speed = c.cruise
		c.timer = 999.0
	var hit_car: int = -1
	var hit_time: float = 0.0
	var next_print: float = 0.0
	var min_gap_bot: float = 1e9
	var passed: Dictionary = {}           # car index -> true once it got past the hit car
	var overlaps: int = 0
	var prev_z: float = 0.0
	while sim.time < seconds:
		sim.set_command(p, Commands.make(0.0, 0.85, 0.0) if hit_car < 0 or sim.time - hit_time < 1.5 else Commands.make(0.0, 0.0, 0.6))
		if bot != null:
			sim.set_command(1, bot.command_for(sim, 1, DT))
		sim.step()
		for e in sim.drain_events():
			if String(e["type"]) == "traffic":
				print("BATIDA t=%.2f caminhao=%d carro=%d zona=%s forca=%.1f m/s arremessado=%s" % [sim.time, int(e["truck"]),
					int(e["car"]), String(e["zone"]), float(e["force"]), str(e["thrown"])])
				if hit_car < 0 and bool(e["thrown"]):
					hit_car = int(e["car"])
					hit_time = sim.time
					prev_z = sim.traffic.cars[hit_car].z
		if hit_car < 0:
			continue
		var w: TrafficSim.Car = sim.traffic.cars[hit_car]
		for k in sim.traffic.cars.size():
			if k == hit_car:
				continue
			var o: TrafficSim.Car = sim.traffic.cars[k]
			if o.z > w.z + w.length and o.z < w.z + w.length + 40.0 and not passed.has(k):
				passed[k] = true
			if absf(o.z - w.z) < (o.length + w.length) * 0.5 and absf(o.x - w.x) < (o.width_x + w.width_x) * 0.5:
				overlaps += 1
		if bot != null:
			var bt: TruckSim = sim.trucks[1]
			if absf(bt.x - w.x) < (TruckSim.WIDTH_X + w.width_x) * 0.5:
				min_gap_bot = minf(min_gap_bot, w.z - (bt.z + bt.length))
		if sim.time >= next_print:
			next_print = sim.time + 0.5
			var near: String = ""
			var best: float = 1e9
			for k in sim.traffic.cars.size():
				var o2: TrafficSim.Car = sim.traffic.cars[k]
				var d: float = w.z - (o2.z + o2.length)
				if k != hit_car and d > -5.0 and d < 120.0 and d < best:
					best = d
					near = " | carro%d atras d=%.0f v=%.1f x=%.2f" % [k, d, o2.speed, o2.x]
			var wr: Variant = w.get("wrecked")
			print("t=%5.2f carro%d z=%7.1f x=%5.2f giro=%6.1f graus v=%5.1f m/s fora=%.2f s acidentado=%s%s | bot z-rel=%.0f x=%.2f" % [
				sim.time - hit_time, hit_car, w.z, w.x, rad_to_deg(w.yaw), w.speed, w.out_t, str(wr) if wr != null else "(nao existe)",
				near, (sim.trucks[1].z - w.z) if bot != null else 0.0, sim.trucks[1].x if bot != null else 0.0])
		if w.z - prev_z > 100.0:
			print("carro%d saiu da cena (reaparece a frente) em t=%.1f, %.0f m atras do ultimo caminhao" % [hit_car,
				sim.time - hit_time, minf(sim.trucks[0].z, sim.trucks[sim.trucks.size() - 1].z) - prev_z])
			break
		prev_z = w.z
	print("RESUMO: carros que passaram o batido=%d, quadros com carro sobreposto ao batido=%d, menor folga do bot na linha dele=%.1f m" % [
		passed.size(), overlaps, min_gap_bot])
	quit(0)
