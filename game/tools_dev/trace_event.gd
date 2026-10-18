extends SceneTree
## T-139: trace of one bot passing a track event (z, speed, lane, target, nearest car ahead).
## godot --headless --path game -s res://tools_dev/trace_event.gd -- --route=kanto_2_viaduct --seed=-1 --bot=0 [--from=1700 --to=2300]
##   --tseed=N traffic seed; --event=accident:2-3@900+110 forces an event
##   --seed=-2 no events, -1 fixed only, N fixed + random by seed N

const DIFFS: Array[int] = [2, 2, 1, 0]


func _initialize() -> void:
	var rid: String = "kanto_2_viaduct"
	var seed_: int = -1
	var who: int = 0
	var z_from: float = -1.0
	var z_to: float = -1.0
	var tseed: int = 1234
	var forced: Array[Dictionary] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tseed="):
			tseed = int(a.substr(8))
		elif a.begins_with("--event="):
			forced.append(RaceDemo.parse_event(a.substr(8)))
		if a.begins_with("--route="):
			rid = a.substr(8)
		elif a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--bot="):
			who = int(a.substr(6))
		elif a.begins_with("--from="):
			z_from = float(a.substr(7))
		elif a.begins_with("--to="):
			z_to = float(a.substr(5))
	var route: RouteDef = load("res://data/routes/%s.tres" % rid) as RouteDef
	var track: Track = route.build_track()
	if not forced.is_empty():
		track.events = TrackEvents.roll(forced, track, 0, 0, 0.0)
	elif seed_ == -1:
		track.events = TrackEvents.roll(route.events, track, 0, 0, 0.0)
	elif seed_ >= 0:
		track.events = route.build_events(track, seed_)
	for ev in track.events.list:
		print("evento %s z=%.0f len=%.0f faixas %d-%d full=%.0f end=%.0f" % [TrackEvents.KIND_IDS[ev.kind], ev.z, ev.length, ev.lo, ev.hi, ev.full_z(), ev.end_z()])
		if z_from < 0.0:
			z_from = ev.z - 450.0
			z_to = ev.reopen_end() + 100.0
	var sim := RaceSim.new(track, route.traffic, tseed)
	var bots: Array[BotDriver] = []
	for k in 4:
		var idx: int = sim.add_truck(-float(k) * 14.0, Room.GRID_X[k])
		sim.trucks[idx].is_bot = true
		bots.append(BotDriver.new(DIFFS[k], 100 + k, Room.GRID_X[k]))
	var next_print: float = 0.0
	while sim.time < 260.0 and not sim.is_over():
		for k in bots.size():
			sim.set_command(k, bots[k].command_for(sim, k, RaceSim.FIXED_DT))
		sim.step()
		for e in sim.drain_events():
			if int(e.get("truck", -1)) == who or int(e.get("a", -1)) == who or int(e.get("b", -1)) == who:
				if String(e["type"]) != "overtake":
					print("   evt t=%.1f %s" % [sim.time, e])
		var t: TruckSim = sim.trucks[who]
		if t.z >= z_from and t.z <= z_to and sim.time >= next_print:
			next_print = sim.time + 0.5
			var ahead: String = ""
			var best: float = 1e9
			for c in sim.traffic.cars:
				var d: float = c.z - (t.z + t.length)
				if d > -2.0 and d < 80.0 and absf(c.x - t.x) < 0.3 and d < best:
					best = d
					ahead = "carro d=%.0f v=%.1f x=%.2f" % [d, c.speed, c.x]
			for j in sim.trucks.size():
				var o: TruckSim = sim.trucks[j]
				var d2: float = o.z - (t.z + t.length)
				if j != who and d2 > -2.0 and d2 < 80.0 and absf(o.x - t.x) < 0.3 and d2 < best:
					best = d2
					ahead = "caminhao%d d=%.0f v=%.1f" % [j, d2, o.speed]
			var why: String = ""
			var b: BotDriver = bots[who]
			for nl in [t.lane - 1, t.lane + 1]:
				if Lanes.is_road_lane(nl):
					var hz: float = BotDriver.REACTION_M[b.difficulty] + t.speed * 1.3
					why += " [f%d aberta=%s obst=%s lado=%s]" % [nl, b._open(sim, t, nl, BotDriver.OVERTAKE_LOOK),
						str(b._obstacle_ahead(sim, t, who, Lanes.X[nl], hz * 1.2)), b._lane_side_clear(sim, t, who, nl)]
			print("t=%5.1f z=%6.0f v=%4.1f faixa=%d alvo=%d x=%.2f %s%s" % [sim.time, t.z, t.speed, t.lane, bots[who].target_lane, t.x, ahead, why])
	print("chegada: ", sim.trucks[who].finish_time)
	quit(0)
