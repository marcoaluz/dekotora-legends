extends SceneTree
## T-153: quanto o trecho de 2 faixas custa no tempo. Corrida inteira de cada rota com 4 bots (dificil, normal, facil,
## dificil) e transito da rota, com e sem o trecho, N sementes de transito; imprime a media do tempo de chegada.
## Uso: godot --headless --path game -s res://tools_dev/measure_section_times.gd -- [--seeds=4]

const DT: float = RaceSim.FIXED_DT


func _initialize() -> void:
	var seeds: int = 4
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.substr(8))
	for r in ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]:
		var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
		var with_s: float = 0.0
		var without: float = 0.0
		var hard_with: float = 0.0
		var hard_without: float = 0.0
		for s in seeds:
			var a: Array = _race(route, true, 500 + s)
			var b: Array = _race(route, false, 500 + s)
			with_s += float(a[0]) / seeds
			without += float(b[0]) / seeds
			hard_with += float(a[1]) / seeds
			hard_without += float(b[1]) / seeds
		print("%s: media dos 4 bots %.1f s com o trecho, %.1f s sem (%+.1f s); bot dificil %.1f vs %.1f (%+.1f s); prazo %.0f s" % [
			r, with_s, without, with_s - without, hard_with, hard_without, hard_with - hard_without, route.deadline()])
	quit(0)


## [media de chegada dos 4, chegada do bot dificil 0]
func _race(route: RouteDef, sections: bool, seed_: int) -> Array:
	var track: Track = route.build_track()
	if not sections:
		track.set_lane_sections([])
	track.events = TrackEvents.new()
	var sim := RaceSim.new(track, route.traffic, seed_)
	var bots: Array[BotDriver] = []
	var diffs: Array[int] = [2, 1, 0, 2]
	for k in 4:
		var idx: int = sim.add_truck(-float(k) * 14.0, Room.GRID_X[k])
		sim.trucks[idx].is_bot = true
		bots.append(BotDriver.new(diffs[k], 70 + k, Room.GRID_X[k], false, true))
	while not sim.is_over() and sim.time < 400.0:
		for k in bots.size():
			sim.set_command(k, bots[k].command_for(sim, k, DT))
		sim.step()
		sim.drain_events()
	var total: float = 0.0
	for t in sim.trucks:
		total += t.finish_time if t.finish_time > 0.0 else sim.time
	return [total / 4.0, sim.trucks[0].finish_time]
