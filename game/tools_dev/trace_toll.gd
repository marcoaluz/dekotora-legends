extends SceneTree
## T-207: o que cada caminhao faz no pedagio (sem tela). Grid da corrida, bots, transito normal.
## godot --headless --path game -s res://tools_dev/trace_toll.gd -- [--route=kanto_1_coast] [--seed=3] [--n=4] [--every=10]
## Imprime a cada `every` ticks (z de 40 a 260 m): caminhao, faixa alvo, x (m), z, velocidade, seta; e cada contato com
## o pedagio (event_obstacle / event_scrape com event = toll).
## `--sweep[=N]`: N sementes (padrao 30) x 3 rotas x 2 e 4 caminhoes; conta batidas e raspadas no pedagio e quem ficou
## dentro da ilha (deve ser 0) e o tempo ate passar o pedagio. Com `--no-toll`: a mesma corrida sem a praca (antes).

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sweep"):
			_sweep(int(a.substr(8)) if a.length() > 8 else 30)
			quit()
			return
	var route_id: String = "kanto_1_coast"
	var seed_: int = 3
	var n: int = 4
	var every: int = 10
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route="):
			route_id = a.substr(8)
		elif a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--n="):
			n = int(a.substr(4))
		elif a.begins_with("--every="):
			every = int(a.substr(8))
	var route: RouteDef = load("res://data/routes/%s.tres" % route_id) as RouteDef
	var track: Track = route.build_track()
	track.events = route.build_events(track, seed_)
	var sim := RaceSim.new(track, 1, seed_)
	var bots: Array = []
	for k in n:
		var s: Vector2 = StartGrid.slot(k, n)
		sim.add_truck(s.x, s.y)
		var d: int = [0, 1, 2][(k + seed_) % 3]
		bots.append(BotDriver.new(d, seed_ * 10 + k, StartGrid.lane_x(k) if n > 2 else s.y, k == 1, false))
		sim.trucks[k].is_bot = true
	var p: TollPlaza = track.toll
	print("TOLL nariz=%.0f fim=%.0f funil=%.0f..%.0f" % [p.nose_z(), p.tail_z(), p.zone_start(), p.zone_end()])
	for tick in int(40.0 / RaceSim.FIXED_DT):
		for k in n:
			sim.set_command(k, bots[k].command_for(sim, k, RaceSim.FIXED_DT))
		sim.step()
		for e in sim.drain_events():
			if String(e.get("event", "")) == "toll":
				var t: TruckSim = sim.trucks[int(e["truck"])]
				print("  CONTATO t=%.2f caminhao %d %s %s dv=%.1f z=%.1f x=%.2f faixa=%d" % [sim.time, int(e["truck"]),
					String(e["type"]), String(e["zone"]), float(e["force"]), t.z, t.x * Track.ROAD_HALF_WIDTH_M, t.lane])
		if tick % every == 0:
			var line: String = "t=%5.2f" % sim.time
			var any: bool = false
			for k in n:
				var t2: TruckSim = sim.trucks[k]
				if t2.z + t2.length > 40.0 and t2.z < 260.0:
					any = true
				line += "  [%d f%d x=%5.2f z=%6.1f v=%4.1f s=%d]" % [k, t2.lane, t2.x * Track.ROAD_HALF_WIDTH_M, t2.z, t2.speed, t2.signal_dir]
			if any:
				print(line)
	quit()


func _sweep(seeds: int) -> void:
	for route_id in ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]:
		var route: RouteDef = load("res://data/routes/%s.tres" % route_id) as RouteDef
		for n in [2, 4]:
			var hits: int = 0
			var scrapes: int = 0
			var inside: int = 0
			var t_pass: float = 0.0
			for seed_ in range(1, seeds + 1):
				var track: Track = route.build_track()
				track.events = route.build_events(track, seed_)
				var ref: TollPlaza = track.toll
				if "--no-toll" in OS.get_cmdline_user_args():      # antes: mesma conta sem a praca (o tempo ate z = fim do funil)
					track.set_toll(-1.0)
				var sim := RaceSim.new(track, route.traffic, seed_)
				var bots: Array = []
				for k in n:
					var s: Vector2 = StartGrid.slot(k, n)
					sim.add_truck(s.x, s.y)
					bots.append(BotDriver.new([0, 1, 2][(k + seed_) % 3], seed_ * 10 + k, StartGrid.lane_x(k) if n > 2 else s.y, k == 1, false))
					sim.trucks[k].is_bot = true
				var p: TollPlaza = ref
				var done: bool = false
				for tick in int(40.0 / RaceSim.FIXED_DT):
					for k in n:
						sim.set_command(k, bots[k].command_for(sim, k, RaceSim.FIXED_DT))
					sim.step()
					for e in sim.drain_events():
						if String(e.get("event", "")) == "toll":
							if String(e["type"]) == "event_obstacle":
								hits += 1
							else:
								scrapes += 1
					var all_past: bool = true
					for t in sim.trucks:
						var ih: float = p.island_half_x()
						if track.toll != null and t.z + t.length > p.nose_z() + 0.01 and t.z < p.tail_z() and absf(t.x) - TruckSim.WIDTH_X * 0.5 < ih - 0.002:
							inside += 1
						all_past = all_past and t.z > p.zone_end()
					if all_past and not done:
						done = true
						t_pass += sim.time
			print("SWEEP %s %d caminhoes, %d sementes: batidas=%d raspadas=%d dentro_da_ilha=%d tempo_medio_ate_passar=%.1f s" % [
				route_id, n, seeds, hits, scrapes, inside, t_pass / float(seeds)])
