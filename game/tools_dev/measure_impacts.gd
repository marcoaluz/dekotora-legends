extends SceneTree
## T-141: quanto as batidas acontecem numa corrida de 4 bots (sem eventos de pista), para ajustar a forca.
## Conta batidas entre caminhoes, empurroes de faixa, quicadas, batidas no transito, carros arremessados e o tempo
## medio de chegada dos bots dificeis.
## Uso: godot --headless --path game -s res://tools_dev/measure_impacts.gd [-- --seeds=4 --route=kanto_1_coast]

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
const DIFFS: Array[int] = [2, 2, 1, 0]


func _initialize() -> void:
	var seeds: int = 4
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
		var tot: Dictionary = {"truck": 0, "shove": 0, "bounce": 0, "traffic": 0, "thrown": 0, "time": 0.0, "n": 0}
		for s in seeds:
			_run(route, 1000 + s * 77, tot)
		print("== %s (%d sementes): por corrida -> batidas caminhao %.1f, empurroes %.1f, quicadas %.1f, transito %.1f, arremessados %.1f; chegada media dos dificeis %.1f s" % [
			r, seeds, tot["truck"] / float(seeds), tot["shove"] / float(seeds), tot["bounce"] / float(seeds), tot["traffic"] / float(seeds),
			tot["thrown"] / float(seeds), float(tot["time"]) / maxf(float(tot["n"]), 1.0)])
	quit(0)


func _run(route: RouteDef, traffic_seed: int, tot: Dictionary) -> void:
	var track: Track = route.build_track()
	track.events = TrackEvents.new()
	var sim := RaceSim.new(track, route.traffic, traffic_seed)
	var bots: Array[BotDriver] = []
	for k in 4:
		var idx: int = sim.add_truck(-float(k) * 14.0, Room.GRID_X[k])
		sim.trucks[idx].is_bot = true
		bots.append(BotDriver.new(DIFFS[k], 100 + k, Room.GRID_X[k]))
	while sim.time < 260.0 and not sim.is_over():
		for k in bots.size():
			sim.set_command(k, bots[k].command_for(sim, k, RaceSim.FIXED_DT))
		sim.step()
		for e in sim.drain_events():
			match String(e["type"]):
				"truck":
					tot["truck"] += 1
					if int(e.get("shoved", -1)) >= 0:
						tot["shove"] += 1
					if int(e.get("bounced", -1)) >= 0:
						tot["bounce"] += 1
				"traffic":
					tot["traffic"] += 1
					if bool(e.get("thrown", false)):
						tot["thrown"] += 1
	for k in 2:
		var ft: float = sim.trucks[k].finish_time
		tot["time"] += ft if ft > 0.0 else 260.0
		tot["n"] += 1
