extends SceneTree
## T-156: campanha 1 contra 1. Compara o duelo do rival da rota contra um "jogador" automatico em 3 grids:
##   antigo  = jogador + rival 14 m atras + 2 bots (como era ate a T-155)
##   1x1_old = so jogador + rival, rival 14 m atras do jogador (grid antigo, sem os 2 bots)
##   1x1     = so jogador + rival, LADO A LADO a 30 m do comeco da pista (StartGrid, o de agora)
## Imprime, por rota: chegada media do jogador e do rival, quantas vezes o jogador venceu (1o e no prazo) e quantas
## vezes alguem nao chegou no prazo. O "jogador" e um BotDriver dificil sem duelo (anda bem, nao fecha ninguem).
## Uso: godot --headless --path game -s res://tools_dev/measure_duel.gd [-- --seeds=6 --route=kanto_1_coast --player=2]

const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
const MODES: Array[String] = ["antigo", "1x1_old", "1x1"]


func _initialize() -> void:
	var seeds: int = 6
	var only: String = ""
	var pdiff: int = BotDriver.Difficulty.HARD
	var modes: PackedStringArray = PackedStringArray(MODES)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = int(a.substr(8))
		elif a.begins_with("--route="):
			only = a.substr(8)
		elif a.begins_with("--player="):
			pdiff = int(a.substr(9))
		elif a == "--feel=legacy":                  # T-219: numeros da simulacao de antes (comparacao)
			TruckFeel.use(TruckFeel.legacy())
		elif a.begins_with("--feel-set="):           # T-219: --feel-set=campo=valor,campo=valor (sobre o feel em uso)
			var f: TruckFeel = TruckFeel.current().duplicate() as TruckFeel
			for kv in a.substr(11).split(","):
				f.set(kv.get_slice("=", 0), float(kv.get_slice("=", 1)))
			TruckFeel.use(f)
		elif a == "--no-hysteresis":                # T-219: bot sem a histerese do "preso atras" (comparacao)
			BotDriver.blocked_hysteresis = 1.0
		elif a.begins_with("--modes="):
			modes = a.substr(8).split(",")
	for r in ROUTES:
		if only != "" and r != only:
			continue
		var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
		var rv: RivalDef = load("res://data/rivals/%s.tres" % route.rival_id) as RivalDef
		for mode in modes:
			var acc: Dictionary = {"p": 0.0, "r": 0.0, "win": 0, "late": 0, "touch": 0}
			for s in seeds:
				_run(route, rv, mode, 2000 + s * 131, pdiff, acc)
			print("%-17s %-8s jogador %.1f s | rival %.1f s | jogador venceu %d/%d | fora do prazo %d | batidas jogador x rival %.1f" % [
				r, mode, float(acc["p"]) / seeds, float(acc["r"]) / seeds, int(acc["win"]), seeds, int(acc["late"]), float(acc["touch"]) / seeds])
	quit(0)


func _run(route: RouteDef, rv: RivalDef, mode: String, seed_: int, pdiff: int, acc: Dictionary) -> void:
	var track: Track = route.build_track()
	track.events = route.build_events(track, seed_)
	var sim := RaceSim.new(track, route.traffic, seed_)
	sim.deadline = route.deadline() + track.events.time_allowance()
	var n: int = 4 if mode == "antigo" else 2
	var drivers: Array[BotDriver] = []
	for i in n:
		var g: Vector2 = StartGrid.slot(i, n) if mode == "1x1" else Vector2(-float(i) * 14.0, Room.GRID_X[i])
		sim.add_truck(g.x, g.y)
		var t: TruckSim = sim.trucks[i]
		t.is_bot = i != 0
		var diff: int = pdiff
		if i == 1:
			diff = rv.difficulty
			var parts: Array[Dictionary] = []
			for pid in rv.part_ids:
				var d: PartDef = (root.get_node("GameState")).part(String(pid))
				if d != null:
					parts.append(d.to_sim_part())
			t.set_loadout(parts)
		elif i > 1:
			diff = clampi(rv.difficulty + (i - 2), 0, 2)
		drivers.append(BotDriver.new(diff, 100 + i, g.y, i == 1, i == 0))
	while not sim.is_over() and sim.time < 400.0:
		for i in n:
			sim.set_command(i, drivers[i].command_for(sim, i, RaceSim.FIXED_DT))
		sim.step()
		for e in sim.drain_events():
			if String(e["type"]) == "truck" and ((int(e["a"]) == 0 and int(e["b"]) == 1) or (int(e["a"]) == 1 and int(e["b"]) == 0)):
				acc["touch"] += 1
		if sim.trucks[0].finish_position > 0 and sim.trucks[1].finish_position > 0:
			break
	var p: TruckSim = sim.trucks[0]
	var r: TruckSim = sim.trucks[1]
	acc["p"] += p.finish_time if p.finish_time > 0.0 else sim.time
	acc["r"] += r.finish_time if r.finish_time > 0.0 else sim.time
	if p.finish_position == 1 and not p.timed_out:
		acc["win"] += 1
	if p.timed_out or p.finish_position == 0:
		acc["late"] += 1
