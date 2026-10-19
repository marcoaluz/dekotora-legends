extends SceneTree
## T-141: quanto as batidas acontecem numa corrida de 4 bots (sem eventos de pista), para ajustar a forca.
## Conta batidas entre caminhoes, empurroes de faixa, quicadas, batidas no transito, carros arremessados e o tempo
## medio de chegada dos bots dificeis.
## T-152: tambem o tempo de chegada de cada bot (dificil, dificil, medio, facil), quantas batidas no transito
## custaram velocidade (penalidade arcade + tranco) e quanto custaram em media (% e m/s).
## Uso: godot --headless --path game -s res://tools_dev/measure_impacts.gd [-- --seeds=4 --route=kanto_1_coast]

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
const DIFFS: Array[int] = [2, 2, 1, 0]
const MAX_TIME: float = 260.0


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
		var tot: Dictionary = {"truck": 0, "shove": 0, "bounce": 0, "traffic": 0, "thrown": 0, "time": 0.0, "n": 0,
			"pen": 0, "pen_frac": 0.0, "pen_ms": 0.0, "bot_time": [0.0, 0.0, 0.0, 0.0], "dnf": 0}
		for s in seeds:
			_run(route, 1000 + s * 77, tot)
		print("== %s (%d sementes): por corrida -> batidas caminhao %.1f, empurroes %.1f, quicadas %.1f, transito %.1f, arremessados %.1f; chegada media dos dificeis %.1f s" % [
			r, seeds, tot["truck"] / float(seeds), tot["shove"] / float(seeds), tot["bounce"] / float(seeds), tot["traffic"] / float(seeds),
			tot["thrown"] / float(seeds), float(tot["time"]) / maxf(float(tot["n"]), 1.0)])
		var bt: Array = tot["bot_time"]
		var pn: int = int(tot["pen"])
		print("   chegada por bot (dificil, dificil, medio, facil): %.1f / %.1f / %.1f / %.1f s; sem chegar em %d s: %d; batidas com penalidade %.1f por corrida, perda media %.0f%% (%.1f m/s)" % [
			float(bt[0]) / seeds, float(bt[1]) / seeds, float(bt[2]) / seeds, float(bt[3]) / seeds, int(MAX_TIME), int(tot["dnf"]),
			pn / float(seeds), 100.0 * float(tot["pen_frac"]) / maxf(pn, 1.0), float(tot["pen_ms"]) / maxf(pn, 1.0)])
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
	while sim.time < MAX_TIME and not sim.is_over():
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
					if float(e.get("penalty", 0.0)) > 0.0:
						tot["pen"] += 1
						tot["pen_frac"] += float(e["penalty"])
						tot["pen_ms"] += float(e["speed_before"]) - float(e["speed_after"])
	for k in 2:
		var ft: float = sim.trucks[k].finish_time
		tot["time"] += ft if ft > 0.0 else MAX_TIME
		tot["n"] += 1
	for k in 4:
		var ft2: float = sim.trucks[k].finish_time
		(tot["bot_time"] as Array)[k] = float((tot["bot_time"] as Array)[k]) + (ft2 if ft2 > 0.0 else MAX_TIME)
		if ft2 <= 0.0:
			tot["dnf"] += 1
