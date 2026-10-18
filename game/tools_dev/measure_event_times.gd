extends SceneTree
## T-139: route time of HARD bots with and without the track events (balance of the deadlines).
## For each route: grid of 4 bots (HARD, HARD, NORMAL, EASY) with the route traffic; no events, fixed events only,
## and fixed + random events for 6 seeds. Prints finish time of the best and of each HARD bot, obstacle/cone hits.
## Usage: godot --headless --path game -s res://tools_dev/measure_event_times.gd

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
const DIFFS: Array[int] = [2, 2, 1, 0]


func _initialize() -> void:
	for r in ROUTES:
		var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
		print("== %s (prazo %.0f s)" % [r, route.deadline()])
		_run(route, "sem eventos", -2)
		_run(route, "so fixos", -1)
		for s in 6:
			_run(route, "fixos+sorteio %d" % s, s)
	quit(0)


func _run(route: RouteDef, label: String, seed_: int) -> void:
	var track: Track = route.build_track()
	if seed_ == -1:
		track.events = TrackEvents.roll(route.events, track, 0, 0, 0.0)
	elif seed_ >= 0:
		track.events = route.build_events(track, seed_)
	var sim := RaceSim.new(track, route.traffic)
	var bots: Array[BotDriver] = []
	for k in 4:
		var idx: int = sim.add_truck(-float(k) * 14.0, Room.GRID_X[k])
		sim.trucks[idx].is_bot = true
		bots.append(BotDriver.new(DIFFS[k], 100 + k, Room.GRID_X[k]))
	var hits: int = 0
	var cones: int = 0
	var t: float = 0.0
	while t < 260.0 and not sim.is_over():
		for k in bots.size():
			sim.set_command(k, bots[k].command_for(sim, k, RaceSim.FIXED_DT))
		sim.step()
		for e in sim.drain_events():
			if String(e["type"]) == "event_obstacle":
				hits += 1
			elif String(e["type"]) == "event_cone":
				cones += 1
		t += RaceSim.FIXED_DT
	var times: Array[String] = []
	for k in 4:
		var ft: float = sim.trucks[k].finish_time
		times.append("%.1f" % ft if ft > 0.0 else "--")
	var desc: Array[String] = []
	for ev in track.events.list:
		desc.append("%s%s@%.0f" % [TrackEvents.KIND_IDS[ev.kind], "*" if not ev.fixed else "", ev.z])
	print("  %-18s dificil %s / %s  normal %s  facil %s   batidas %d cones %d   %s" % [label, times[0], times[1], times[2], times[3], hits, cones, ", ".join(desc)])
