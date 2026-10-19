extends TestCase
## Trechos com 2 faixas de verdade (T-153): a pista inteira estreita (mureta, acostamento, faixa da direita acaba).

const DT: float = RaceSim.FIXED_DT
const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
const SEC: Dictionary = {"start": 1000.0, "end": 1400.0, "lanes": 2, "taper": 150.0}
const EPS: float = 0.01


func _straight_with_section(length: float = 3000.0) -> Track:
	var t := Track.new()
	t.add_section(length, 0.0)
	t.set_lane_sections([SEC])
	return t


func _section(evs: TrackEvents) -> TrackEvents.Event:
	for ev in evs.list:
		if ev.kind == TrackEvents.Kind.SECTION:
			return ev
	return null


## "" if every truck and car is inside the barriers (and out of the lane that ended); else the first problem.
func _inside(sim: RaceSim) -> String:
	var evs: TrackEvents = sim.track.events
	var ev: TrackEvents.Event = _section(evs)
	for k in sim.trucks.size():
		var t: TruckSim = sim.trucks[k]
		var p: String = _body_ok(evs, ev, t.z, t.length, t.x, TruckSim.WIDTH_X * 0.5)
		if p != "":
			return "caminhao %d %s" % [k, p]
		var mid: float = t.z + t.length * 0.5
		if mid >= ev.full_z() and mid <= ev.end_z() and t.lane >= Lanes.LAST:
			return "caminhao %d ainda na faixa que acabou (faixa %d, z=%.0f)" % [k, t.lane, t.z]
	if sim.traffic != null:
		for i in sim.traffic.cars.size():
			var c: TrafficSim.Car = sim.traffic.cars[i]
			var p2: String = _body_ok(evs, ev, c.z, c.length, c.x, c.width_x * 0.5)
			if p2 != "":
				return "carro %d %s" % [i, p2]
			var mid2: float = c.z + c.length * 0.5
			if mid2 >= ev.full_z() and mid2 <= ev.end_z() and not sim.traffic.is_thrown(c) and c.lane == TrafficSim.LANES.size() - 1:
				return "carro %d na faixa que acabou (z=%.0f)" % [i, c.z]
	return ""


func _body_ok(evs: TrackEvents, ev: TrackEvents.Event, z: float, length: float, x: float, half: float) -> String:
	for zz in [z, z + length * 0.5, z + length]:
		var f: float = evs.closure(ev, zz)
		if f <= 0.0:
			continue
		if x + half > LaneSections.right_x(f) + EPS:
			return "atravessou a mureta da direita (z=%.0f x=%.3f mureta=%.3f)" % [zz, x, LaneSections.right_x(f)]
		if x - half < LaneSections.left_x(f) - EPS:
			return "atravessou a mureta da esquerda (z=%.0f x=%.3f mureta=%.3f)" % [zz, x, LaneSections.left_x(f)]
	return ""


# ---------------------------------------------------------------- dados
func test_each_route_has_a_two_lane_section() -> void:
	for r in ROUTES:
		var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
		check(route.lane_sections.size() >= 1, "%s tem trecho de 2 faixas" % r)
		var track: Track = route.build_track()
		var s: Dictionary = route.lane_sections[0]
		var mid: float = (float(s["start"]) + float(s["end"])) * 0.5
		check_eq(track.lanes_at(mid), 2, "%s: 2 faixas no meio do trecho" % r)
		check_eq(track.lanes_at(float(s["start"]) - float(s["taper"]) - 20.0), 3, "%s: 3 faixas antes" % r)
		check_eq(track.lanes_at(float(s["end"]) + float(s["taper"]) + 20.0), 3, "%s: 3 faixas depois" % r)
		check(float(s["end"]) + float(s["taper"]) < track.length_m - 100.0, "%s: o trecho reabre antes da chegada" % r)
	var coast: RouteDef = load("res://data/routes/kanto_1_coast.tres") as RouteDef
	check(coast.bridges.size() >= 1, "litoral: tem ponte")
	var mountain: RouteDef = load("res://data/routes/kanto_3_mountain.tres") as RouteDef
	var s3: Dictionary = mountain.lane_sections[0]
	var holds_tunnel: bool = false
	for t in mountain.tunnels:
		holds_tunnel = holds_tunnel or (t.x >= float(s3["start"]) and t.x + t.y <= float(s3["end"]))
	check(holds_tunnel, "montanha: o tunel antigo fica dentro do trecho de 2 faixas")


func test_sections_survive_any_event_list_and_are_not_sent_as_events() -> void:
	var track := _straight_with_section()
	check_eq(track.lanes_at(1200.0), 2, "trecho na pista")
	track.events = TrackEvents.new()                 # --no-events / regra events = false
	check_eq(track.lanes_at(1200.0), 2, "lista nova de eventos mantem o trecho")
	check(track.events.only_sections(), "so o trecho")
	check_eq(track.events.to_array().size(), 0, "o trecho nao vai em `events` (vai em lane_sections)")
	var evs := TrackEvents.new()
	evs.add({"kind": "works", "z": 2000.0, "length": 170.0, "lanes": [3]})
	track.events = evs
	check_eq(track.events.list.size(), 2, "evento + trecho")
	check_eq(track.events.to_array().size(), 1, "so a obra vai em `events`")
	check(TrackEvents.new().add({"kind": "section", "z": 500.0, "length": 300.0, "lanes": [1]}) == null, "trecho so tira a faixa da direita")
	check(LaneSections.to_event({"start": 500.0, "end": 900.0, "lanes": 1}).is_empty(), "nunca 1 faixa so")
	check(LaneSections.to_event({"start": 500.0, "end": 520.0, "lanes": 2}).is_empty(), "trecho curto demais: recusado")
	check_near(track.events.time_allowance(), TrackEvents.ALLOWANCE_S[TrackEvents.Kind.WORKS], 0.001, "o trecho nao estica o prazo")


func test_transition_is_smooth_and_the_line_runs_ahead_of_the_barrier() -> void:
	var track := _straight_with_section()
	var ev: TrackEvents.Event = _section(track.events)
	check_near(ev.z, 850.0, 0.01, "afunila 150 m antes do inicio")
	check_near(ev.reopen_end(), 1550.0, 0.01, "alarga 150 m depois do fim")
	var prev: Vector3 = LaneSections.profile(track.events, ev.z - 1.0)
	check_near(prev.y, LaneSections.OPEN_WALL_M, 0.001, "mureta normal antes")
	var max_step: float = 0.0
	var line_ahead: bool = true
	var zz: float = ev.z
	while zz <= ev.reopen_end() + 1.0:
		var p: Vector3 = LaneSections.profile(track.events, zz)
		max_step = maxf(max_step, maxf(absf(p.y - prev.y), maxf(absf(p.x - prev.x), absf(p.z - prev.z))))
		if p.y < LaneSections.OPEN_WALL_M - 0.5 and p.z > p.y - 0.4:
			line_ahead = false
		prev = p
		zz += 1.0
	check(max_step < 0.12, "sem degrau: no maximo %.3f m por metro" % max_step)
	check(line_ahead, "a linha pintada sempre por dentro da mureta")
	var full: Vector3 = LaneSections.profile(track.events, 1200.0)
	check_near(full.y, LaneSections.RIGHT_WALL_M, 0.001, "mureta da direita no trecho")
	check_near(full.x, LaneSections.LEFT_WALL_M, 0.001, "mureta da esquerda no trecho")
	check_near(full.z, LaneSections.NARROW_LINE_M, 0.001, "linha de borda nova")
	check(ev.block_z[Lanes.LAST] > ev.z + 50.0 and ev.block_z[Lanes.LAST] < ev.full_z(), "faixa da direita fecha dentro do afunilamento (%.0f)" % ev.block_z[Lanes.LAST])
	check(ev.block_z[Lanes.SHOULDER_R] < ev.block_z[Lanes.LAST], "o acostamento da direita fecha antes")
	check(ev.block_z[Lanes.CENTER] == INF and ev.block_z[Lanes.SHOULDER_L] == INF, "faixa do meio e acostamento da esquerda continuam")


# ---------------------------------------------------------------- caminhoes
func test_lane_ending_truck_must_merge_and_nobody_crosses_the_barrier() -> void:
	var sim := RaceSim.new(_straight_with_section(2400.0), TrafficSim.Density.HEAVY, 91)
	var me: int = sim.add_truck(600.0, Lanes.X[Lanes.LAST])       # "humano" na faixa que acaba, sem tocar em nada
	var o: int = sim.add_truck(596.0, Lanes.X[Lanes.CENTER])      # bot ao lado: disputa a vez
	var sh: int = sim.add_truck(560.0, Lanes.X[Lanes.SHOULDER_R]) # no acostamento da direita
	for k in [me, o, sh]:
		sim.trucks[k].speed = 24.0
	sim.trucks[o].is_bot = true
	var bot := BotDriver.new(BotDriver.Difficulty.HARD, 5, 0.0, false, true)
	var problem: String = ""
	var merged_at: float = -1.0
	for n in int(60.0 / DT):
		sim.set_command(me, Commands.make(0.0, 0.8, 0.0))
		sim.set_command(sh, Commands.make(0.0, 0.8, 0.0))
		sim.set_command(o, bot.command_for(sim, o, DT))
		sim.step()
		sim.drain_events()
		if problem == "":
			problem = _inside(sim)
		if merged_at < 0.0 and sim.trucks[me].lane != Lanes.LAST:
			merged_at = sim.trucks[me].z + sim.trucks[me].length
	check_eq(problem, "", "ninguem atravessa a mureta nem fica na faixa que acabou")
	var ev: TrackEvents.Event = _section(sim.track.events)
	check(merged_at > 0.0 and merged_at < ev.full_z(), "quem estava na faixa que acaba entrou na fila antes do trecho (nariz em %.0f)" % merged_at)
	check(sim.trucks[me].z > ev.reopen_end(), "e seguiu viagem (z=%.0f)" % sim.trucks[me].z)
	check(sim.trucks[sh].z > ev.reopen_end(), "o do acostamento tambem (z=%.0f)" % sim.trucks[sh].z)


func test_truck_cannot_change_into_the_lane_that_ended() -> void:
	var sim := RaceSim.new(_straight_with_section(), -1, 3)
	var i: int = sim.add_truck(1100.0, Lanes.X[Lanes.CENTER])
	var t: TruckSim = sim.trucks[i]
	t.speed = 20.0
	for n in 2:
		for k in 3:
			sim.set_command(i, Commands.make(1.0, 0.6, 0.0))
			sim.step()
		for k in 3:
			sim.set_command(i, Commands.make(0.0, 0.6, 0.0))
			sim.step()
	check_eq(t.lane, Lanes.CENTER, "troca para a faixa da direita recusada dentro do trecho")
	check(t.lane_refusals >= 1, "recusa contada (HUD: FAIXA FECHADA)")
	t.x = -1.4                                         # empurrado para a esquerda (batida): a mureta nova segura
	for n in 10:
		sim.set_command(i, Commands.make(0.0, 0.6, 0.0))
		sim.step()
	check(t.x - TruckSim.WIDTH_X * 0.5 >= LaneSections.left_x(1.0) - EPS, "mureta da esquerda segura o caminhao (x=%.3f)" % t.x)


# ---------------------------------------------------------------- rotas reais: bots e transito
func test_bots_and_traffic_respect_the_section_on_every_route() -> void:
	for r in ROUTES:
		var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
		var track: Track = route.build_track()
		track.events = TrackEvents.new()                # so o trecho (os eventos tem teste proprio)
		var s: Dictionary = route.lane_sections[0]
		var z0: float = float(s["start"]) - float(s["taper"]) - 250.0
		var sim := RaceSim.new(track, TrafficSim.Density.HEAVY, 1234)
		var bots: Array[BotDriver] = []
		for k in 4:
			var lane_x: float = Lanes.X[Lanes.LAST] if k % 2 == 0 else Lanes.X[Lanes.CENTER]   # metade prefere a direita
			var idx: int = sim.add_truck(z0 - float(k) * 16.0, lane_x)
			sim.trucks[idx].is_bot = true
			sim.trucks[idx].speed = 20.0
			bots.append(BotDriver.new(k % 3, 40 + k, lane_x, false, true))
		var problem: String = ""
		var end_z: float = float(s["end"]) + float(s["taper"]) + 60.0
		var obstacles: int = 0
		for n in int(70.0 / DT):
			for k in bots.size():
				sim.set_command(k, bots[k].command_for(sim, k, DT))
			sim.step()
			for e in sim.drain_events():
				if String(e["type"]) == "event_obstacle":
					obstacles += 1
			if problem == "":
				problem = _inside(sim)
			var all_past: bool = true
			for t in sim.trucks:
				all_past = all_past and t.z > end_z
			if all_past:
				break
		check_eq(problem, "", "%s: ninguem atravessa a mureta nem fica na faixa que acabou" % r)
		check_eq(obstacles, 0, "%s: sem batida de frente" % r)
		for k in sim.trucks.size():
			check(sim.trucks[k].z > end_z, "%s: bot %d passou pelo trecho (z=%.0f)" % [r, k, sim.trucks[k].z])


# ---------------------------------------------------------------- rede e determinismo
func test_online_setup_carries_the_sections_and_the_server_wins() -> void:
	var room := Room.new("SEC153")
	room.add_member(100, "A", "AAAAAAAA", TruckConfig.basic_descriptor())
	room.set_rules(100, {"bots": 1, "traffic": 1, "route": "kanto_3_mountain"})
	room.set_ready(100, true)
	check_eq(room.try_start(100, 777), "", "corrida iniciada")
	var setup: Dictionary = JSON.parse_string(JSON.stringify(room.race_setup()))   # como chega pela rede
	check(setup.has("lane_sections") and (setup["lane_sections"] as Array).size() == 1, "o setup leva o trecho de 2 faixas")
	var sync := ClientSync.new()
	sync.setup(setup, 0)
	for z in [1000.0, 1100.0, 1300.0, 1500.0, 1700.0]:
		check_eq(sync.sim.track.lanes_at(z), room.sim.track.lanes_at(z), "cliente e servidor: mesmas faixas em %.0f m" % z)
	check_eq(JSON.stringify(sync.sim.track.events.to_array()), JSON.stringify(room.sim.track.events.to_array()), "mesmos eventos")
	setup["lane_sections"] = []                       # o servidor manda: sem trecho no setup = pista do servidor sem trecho
	var sync2 := ClientSync.new()
	sync2.setup(setup, 0)
	check_eq(sync2.sim.track.lanes_at(1300.0), 3, "a lista do servidor substitui a da rota")


func test_section_race_is_deterministic() -> void:
	var states: Array[String] = []
	for run in 2:
		var sim := RaceSim.new(_straight_with_section(2200.0), TrafficSim.Density.NORMAL, 55)
		var bots: Array[BotDriver] = []
		for k in 3:
			var idx: int = sim.add_truck(700.0 - float(k) * 14.0, Lanes.X[Lanes.FIRST + k])
			sim.trucks[idx].is_bot = true
			sim.trucks[idx].speed = 22.0
			bots.append(BotDriver.new(k % 3, 9 + k, Lanes.X[Lanes.FIRST + k], false, true))
		for n in int(40.0 / DT):
			for k in bots.size():
				sim.set_command(k, bots[k].command_for(sim, k, DT))
			sim.step()
			sim.drain_events()
		var s: String = ""
		for t in sim.trucks:
			s += "%.4f,%.4f,%d;" % [t.z, t.x, t.lane]
		for c in sim.traffic.cars:
			s += "%.3f,%.3f;" % [c.z, c.x]
		states.append(s)
	check_eq(states[0], states[1], "mesma semente, mesmo resultado")
