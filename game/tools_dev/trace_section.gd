extends SceneTree
## T-153: passa 4 bots + transito pelo trecho de 2 faixas de uma rota e imprime o que aconteceu (sem tela).
## Uso: godot --headless --path game -s res://tools_dev/trace_section.gd -- [--route=kanto_3_mountain] [--density=2]
##      [--human]  (o caminhao 0 fica parado na faixa da direita, sem tocar: e obrigado a entrar na fila)

const DT: float = RaceSim.FIXED_DT


func _initialize() -> void:
	var route_id: String = "kanto_3_mountain"
	var density: int = TrafficSim.Density.HEAVY
	var human: bool = false
	var log_: bool = "--log" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route="):
			route_id = a.substr(8)
		elif a.begins_with("--density="):
			density = int(a.substr(10))
		elif a == "--human":
			human = true
	var route: RouteDef = load("res://data/routes/%s.tres" % route_id) as RouteDef
	var track: Track = route.build_track()
	track.events = TrackEvents.new()
	var s: Dictionary = route.lane_sections[0]
	var ev: TrackEvents.Event = null
	for e in track.events.list:
		if e.kind == TrackEvents.Kind.SECTION:
			ev = e
	print("trecho %s: afunila %.0f, 2 faixas %.0f..%.0f, alarga ate %.0f; faixa 3 fecha em %.0f, acostamento em %.0f" % [route_id,
		ev.z, ev.full_z(), ev.end_z(), ev.reopen_end(), ev.block_z[Lanes.LAST], ev.block_z[Lanes.SHOULDER_R]])
	var sim := RaceSim.new(track, density, 1234)
	var bots: Array[BotDriver] = []
	var z0: float = float(s["start"]) - float(s["taper"]) - 250.0
	for k in 4:
		var lane_x: float = Lanes.X[Lanes.LAST] if k % 2 == 0 else Lanes.X[Lanes.CENTER]
		var idx: int = sim.add_truck(z0 - float(k) * 16.0, lane_x)
		sim.trucks[idx].is_bot = not (human and k == 0)
		sim.trucks[idx].speed = 20.0
		bots.append(BotDriver.new(k % 3, 40 + k, lane_x, false, true))
	var merged: Array[float] = [-1.0, -1.0, -1.0, -1.0]
	var min_gap_r: float = INF
	var min_gap_l: float = INF
	var counts: Dictionary = {}
	var t_in: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var t_out: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for n in int(90.0 / DT):
		for k in bots.size():
			if human and k == 0:
				sim.set_command(0, Commands.make(0.0, 0.8, 0.0))
			else:
				sim.set_command(k, bots[k].command_for(sim, k, DT))
		sim.step()
		for e in sim.drain_events():
			var ty: String = String(e["type"])
			counts[ty] = int(counts.get(ty, 0)) + 1
		if log_ and n % 15 == 0 and sim.trucks[0].z > ev.z - 150.0 and sim.trucks[0].z < ev.reopen_end():
			var line: String = "t=%.1f" % sim.time
			for t in sim.trucks:
				line += "  [z=%.0f x=%.2f faixa %d v=%.0f toques %d]" % [t.z, t.x, t.lane, t.speed * 3.6, t.cargo_touches]
			print(line)
		for k in sim.trucks.size():
			var t: TruckSim = sim.trucks[k]
			if merged[k] < 0.0 and t.lane < Lanes.LAST and t.z > ev.z - 300.0 and Lanes.nearest(t.x) < Lanes.LAST:
				merged[k] = t.z + t.length
			if t.z + t.length >= ev.z and t_in[k] == 0.0:
				t_in[k] = sim.time
			if t.z >= ev.reopen_end() and t_out[k] == 0.0:
				t_out[k] = sim.time
			for zz in [t.z, t.z + t.length]:
				var f: float = track.events.closure(ev, zz)
				if f > 0.5:
					min_gap_r = minf(min_gap_r, (LaneSections.right_x(f) - (t.x + TruckSim.WIDTH_X * 0.5)) * Track.ROAD_HALF_WIDTH_M)
					min_gap_l = minf(min_gap_l, ((t.x - TruckSim.WIDTH_X * 0.5) - LaneSections.left_x(f)) * Track.ROAD_HALF_WIDTH_M)
	for k in sim.trucks.size():
		var t: TruckSim = sim.trucks[k]
		print("caminhao %d: z=%.0f faixa %d, entrou na fila com o nariz em %.0f, trecho em %.1f s, trocas %d, raspadas %d" % [k, t.z,
			t.lane, merged[k], t_out[k] - t_in[k], t.lane_changes, t.cargo_touches])
	print("menor folga ate a mureta: direita %.2f m, esquerda %.2f m" % [min_gap_r, min_gap_l])
	print("eventos: ", counts)
	quit(0)
