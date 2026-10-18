extends SceneTree
## T-139: how much time each track event costs (balance of the deadlines).
## For each route and each traffic seed: grid of 4 bots (HARD, HARD, NORMAL, EASY) with the route traffic, once without
## events and once per event case (the fixed one of the route and one of each kind forced at the same z).
## Prints the mean finish time of the HARD and NORMAL bots, the mean loss against "no events", the worst loss,
## obstacle and cone hits.
## Usage: godot --headless --path game -s res://tools_dev/measure_event_times.gd [-- --seeds=6 --route=kanto_2_viaduct]

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
const DIFFS: Array[int] = [2, 2, 1, 0]


func _initialize() -> void:
	var seeds: int = 6
	var only: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.substr(8))
		elif a.begins_with("--route="):
			only = a.substr(8)
	for r in ROUTES:
		if only != "" and r != only:
			continue
		var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
		var z: float = float(route.events[0]["z"]) if not route.events.is_empty() else 1500.0
		var cases: Array = [["sem eventos", []], ["fixo da rota", route.events]]
		for d in [{"kind": "accident", "lanes": [3]}, {"kind": "accident", "lanes": [2, 3]}, {"kind": "works", "lanes": [3]},
				{"kind": "works", "lanes": [1]}, {"kind": "narrow", "lanes": [3]}]:
			var ev: Dictionary = d.duplicate()
			ev["z"] = z
			ev["length"] = {"accident": 110.0, "works": 170.0, "narrow": 420.0}[d["kind"]]
			cases.append(["%s %s" % [d["kind"], d["lanes"]], [ev]])
		print("== %s (prazo %.0f s, eventos em z=%.0f, %d sementes de transito)" % [r, route.deadline(), z, seeds])
		var base: Array[float] = []
		for c in cases:
			var hard: Array[float] = []
			var normal: Array[float] = []
			var hits: int = 0
			var cones: int = 0
			for s in seeds:
				var res: Array = _run(route, c[1], 1000 + s * 77)
				hard.append(res[0])
				hard.append(res[1])
				normal.append(res[2])
				hits += int(res[4])
				cones += int(res[5])
			var mh: float = _mean(hard)
			if base.is_empty():
				base = hard.duplicate()
			var worst: float = 0.0
			for i in hard.size():
				worst = maxf(worst, hard[i] - base[i])
			print("  %-18s dificil %.1f (%+.1f, pior %+.1f)  normal %.1f   batidas %d cones %d" % [c[0], mh, mh - _mean(base), worst, _mean(normal), hits, cones])
	quit(0)


func _mean(a: Array[float]) -> float:
	var s: float = 0.0
	for v in a:
		s += v
	return s / maxf(float(a.size()), 1.0)


## [hard0, hard1, normal, easy, obstacle hits, cones] finish times (260 = did not finish).
func _run(route: RouteDef, events: Array, traffic_seed: int) -> Array:
	var track: Track = route.build_track()
	var fixed: Array[Dictionary] = []
	fixed.assign(events)
	track.events = TrackEvents.roll(fixed, track, 0, 0, 0.0)
	var sim := RaceSim.new(track, route.traffic, traffic_seed)
	var bots: Array[BotDriver] = []
	for k in 4:
		var idx: int = sim.add_truck(-float(k) * 14.0, Room.GRID_X[k])
		sim.trucks[idx].is_bot = true
		bots.append(BotDriver.new(DIFFS[k], 100 + k, Room.GRID_X[k]))
	var hits: int = 0
	var cones: int = 0
	while sim.time < 260.0 and not sim.is_over():
		for k in bots.size():
			sim.set_command(k, bots[k].command_for(sim, k, RaceSim.FIXED_DT))
		sim.step()
		for e in sim.drain_events():
			if String(e["type"]) == "event_obstacle":
				hits += 1
			elif String(e["type"]) == "event_cone":
				cones += 1
	var out: Array = []
	for k in 4:
		var ft: float = sim.trucks[k].finish_time
		out.append(ft if ft > 0.0 else 260.0)
	out.append(hits)
	out.append(cones)
	return out
