extends TestCase
## Eventos de pista (T-139): acidente, obras e estreitamento 3 -> 2 faixas.

const DT: float = RaceSim.FIXED_DT
const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func _straight(length: float = 4000.0) -> Track:
	var t := Track.new()
	t.add_section(length, 0.0)
	return t


func _sim_with(ev: Dictionary, density: int = -1, length: float = 4000.0) -> RaceSim:
	var track := _straight(length)
	var evs := TrackEvents.new()
	evs.add(ev)
	track.events = evs
	return RaceSim.new(track, density, 77)


## Um toque: segura `dir` por 3 passos e solta por 3.
func _tap(sim: RaceSim, i: int, dir: float) -> void:
	for n in 3:
		sim.set_command(i, Commands.make(dir, 0.6, 0.0))
		sim.step()
	for n in 3:
		sim.set_command(i, Commands.make(0.0, 0.6, 0.0))
		sim.step()


func _count(events: Array[Dictionary], type: String, truck: int = -1) -> int:
	var n: int = 0
	for e in events:
		if String(e["type"]) == type and (truck < 0 or int(e["truck"]) == truck):
			n += 1
	return n


# ---------------------------------------------------------------- dados e sorteio
func test_routes_have_a_fixed_event_and_roll_is_deterministic() -> void:
	for r in ROUTES:
		var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
		var track: Track = route.build_track()
		check(route.events.size() >= 1, "%s tem evento fixo" % r)
		var randoms: int = 0
		var kinds: Dictionary = {}
		for seed_ in 120:
			var a: TrackEvents = route.build_events(track, seed_)
			var b: TrackEvents = route.build_events(track, seed_)
			check_eq(JSON.stringify(a.to_array()), JSON.stringify(b.to_array()), "%s semente %d: mesmo sorteio" % [r, seed_])
			check(a.list.size() >= route.events.size(), "%s: os fixos sempre entram" % r)
			for i in a.list.size():
				var ev: TrackEvents.Event = a.list[i]
				check(ev.hi - ev.lo <= 1, "%s: nunca fecha as 3 faixas" % r)
				check(ev.z > 300.0 and ev.reopen_end() < track.length_m - 100.0, "%s: evento dentro da pista (z=%.0f)" % [r, ev.z])
				var prev: TrackEvents.Event = a.list[i - 1] if i > 0 else null
				# T-153: the 2-lane sections are part of the road (fixed, may hold a tunnel): a fixed event may sit right
				# after one; a random event keeps SECTION_GAP_M of free road from its zone
				var with_section: bool = prev != null and (ev.kind == TrackEvents.Kind.SECTION or prev.kind == TrackEvents.Kind.SECTION)
				if prev != null and not with_section:
					check(ev.z - TrackEvents.WARN_M > prev.reopen_end(), "%s: eventos nao se sobrepoem" % r)
				elif with_section and not (ev.fixed and prev.fixed):
					check(ev.z - TrackEvents.SECTION_GAP_M >= prev.reopen_end() - 1.0, "%s: evento sorteado longe do trecho de 2 faixas" % r)
				for t in route.tunnels:
					if ev.kind != TrackEvents.Kind.SECTION:
						check(ev.reopen_end() < t.x or ev.z > t.x + t.y, "%s: evento fora do tunel" % r)
				if not ev.fixed:
					randoms += 1
					kinds[ev.kind] = true
		check(randoms > 15 and randoms < 100, "%s: sorteio com chance moderada (%d em 120)" % [r, randoms])
		check(kinds.size() >= 2, "%s: o sorteio varia o tipo" % r)


func test_invalid_events_are_rejected() -> void:
	var evs := TrackEvents.new()
	check(evs.add({"kind": "accident", "z": 500.0, "length": 100.0, "lanes": [1, 2, 3]}) == null, "3 faixas: recusado")
	check(evs.add({"kind": "works", "z": 500.0, "length": 100.0, "lanes": [1, 3]}) == null, "faixas separadas: recusado")
	check(evs.add({"kind": "narrow", "z": 500.0, "length": 300.0, "lanes": [2]}) == null, "estreitamento so numa faixa de fora")
	check(evs.add({"kind": "accident", "z": 500.0, "length": 100.0, "lanes": [2]}) != null, "acidente na faixa do meio vale")
	var d: Dictionary = RaceDemo.parse_event("accident:2-3@900+130")
	check_eq(String(d["kind"]), "accident", "--event: tipo")
	check_eq((d["lanes"] as Array).size(), 2, "--event: faixas 2-3")
	check_near(float(d["z"]), 900.0, 0.01, "--event: z")
	check_near(float(d["length"]), 130.0, 0.01, "--event: comprimento")


# ---------------------------------------------------------------- caminhao
func test_truck_cannot_change_into_closed_lane() -> void:
	var sim := _sim_with({"kind": "works", "z": 300.0, "length": 170.0, "lanes": [3]})
	var i: int = sim.add_truck(270.0, 0.0)
	var t: TruckSim = sim.trucks[i]
	t.speed = 20.0
	_tap(sim, i, 1.0)
	_tap(sim, i, 1.0)
	check_eq(t.lane, Lanes.CENTER, "troca para a faixa fechada recusada")
	check_eq(t.lane_refusals, 1, "a recusa foi contada")
	check(t.lane_refused_t > 0.0, "o HUD mostra o aviso")
	check_eq(t.signal_dir, 1, "a seta continua piscando")
	for n in 400:
		sim.set_command(i, Commands.make(0.0, 0.6, 0.0))
		sim.step()
		check(t.x + TruckSim.WIDTH_X * 0.5 < 0.25 + 0.001 or t.z > 470.0, "nunca entrou na faixa fechada")
	# longe do bloqueio a troca para a mesma faixa vale
	var sim2 := _sim_with({"kind": "works", "z": 1500.0, "length": 170.0, "lanes": [3]})
	var j: int = sim2.add_truck(100.0, 0.0)
	sim2.trucks[j].speed = 20.0
	_tap(sim2, j, 1.0)
	_tap(sim2, j, 1.0)
	check_eq(sim2.trucks[j].lane, Lanes.LAST, "faixa que so fecha bem mais a frente: troca aceita")


func test_closed_lane_cones_cost_cargo_and_vehicle_is_a_crash() -> void:
	for kind in ["accident", "works"]:
		var sim := _sim_with({"kind": kind, "z": 400.0, "length": 140.0, "lanes": [3]})
		var i: int = sim.add_truck(250.0, Lanes.X[Lanes.LAST])
		var t: TruckSim = sim.trucks[i]
		t.speed = 22.0
		var ev: TrackEvents.Event = sim.track.events.list[0]
		var evs: Array[Dictionary] = []
		for n in int(30.0 / DT):
			sim.set_command(i, Commands.make(0.0, 0.7, 0.0))
			sim.step()
			evs.append_array(sim.drain_events())
			var inside: bool = t.x + TruckSim.WIDTH_X * 0.5 > 0.25 and t.z + t.length > ev.full_z() + 0.01 and t.z < ev.end_z()
			check(not inside, "%s: nao atravessa o veiculo parado (z=%.1f x=%.2f)" % [kind, t.z, t.x])
			if inside:
				break
		check(_count(evs, "event_cone") >= 3, "%s: passou pelos cones (%d)" % [kind, _count(evs, "event_cone")])
		var hits: int = _count(evs, "event_obstacle")
		check(hits >= 1 and hits <= 2, "%s: bateu no veiculo parado (%d)" % [kind, hits])
		var dmg: float = 0.0
		for e in evs:
			if String(e["type"]) == "event_obstacle":
				dmg += float(e["damage"])
		check(dmg > 20.0, "%s: batida com dano (%.0f)" % [kind, dmg])
		check(t.cargo_loss() > 0.02, "%s: perdeu carga (%.3f)" % [kind, t.cargo_loss()])
		check(t.lane != Lanes.LAST and t.z > ev.end_z(), "%s: saiu para a faixa aberta e seguiu (faixa %d, z=%.0f)" % [kind, t.lane, t.z])


func test_works_steel_plates_shake_cargo_above_limit() -> void:
	var ev: Dictionary = {"kind": "works", "z": 300.0, "length": 200.0, "lanes": [3]}
	for v in [30.0, 16.0]:
		var sim := _sim_with(ev)
		var i: int = sim.add_truck(200.0, Lanes.X[Lanes.FIRST])
		var t: TruckSim = sim.trucks[i]
		t.speed = v
		var evs: Array[Dictionary] = []
		while t.z < 560.0 and sim.time < 60.0:
			t.speed = v                                    # velocidade fixa (o teste e da regra, nao do motor)
			sim.set_command(i, Commands.make(0.0, 0.0, 0.0))
			sim.step()
			evs.append_array(sim.drain_events())
		var n: int = _count(evs, "event_plates")
		if v > 20.0:
			check(n >= 6, "a 108 km/h as chapas sacodem a carga (%d)" % n)
			check(t.cargo_loss() > 0.03, "perdeu carga nas chapas (%.3f)" % t.cargo_loss())
			check_near(float(t.systems["engine"]) + float(t.systems["steering"]) + float(t.systems["cargo"]), 300.0, 0.001, "chapas nao danificam o caminhao")
		else:
			check_eq(n, 0, "a 58 km/h nada acontece")
			check_near(t.cargo_loss(), 0.0, 0.0001, "sem perda de carga dentro do limite")
	var evs2 := TrackEvents.new()
	evs2.add(ev)
	check(is_inf(evs2.limit_at(0.0, 340.0)), "limite so ao lado da obra (nao no afunilamento)")
	check_near(evs2.limit_at(380.0, 395.0), TrackEvents.WORKS_LIMIT_KMH / 3.6, 0.001, "limite ao lado da obra")


func test_deadline_stretches_with_events_same_on_server_and_client() -> void:
	var evs := TrackEvents.new()
	evs.add({"kind": "accident", "z": 900.0, "length": 110.0, "lanes": [2, 3]})
	evs.add({"kind": "works", "z": 1500.0, "length": 170.0, "lanes": [3]})
	evs.add({"kind": "narrow", "z": 2300.0, "length": 420.0, "lanes": [1]})
	check_near(evs.time_allowance(), TrackEvents.ALLOWANCE_TWO_LANES_S + TrackEvents.ALLOWANCE_S[1] + TrackEvents.ALLOWANCE_S[2], 0.001, "folga somada por evento")
	var room := Room.new("EVT141")
	room.add_member(100, "A", "AAAAAAAA", TruckConfig.basic_descriptor())
	room.set_rules(100, {"bots": 1, "traffic": 1, "route": "kanto_2_viaduct"})
	room.set_ready(100, true)
	check_eq(room.try_start(100, 4242), "", "corrida iniciada")
	var route: RouteDef = load("res://data/routes/kanto_2_viaduct.tres") as RouteDef
	check_near(room.sim.deadline, route.deadline() + room.sim.track.events.time_allowance(), 0.001, "servidor: prazo + folga dos eventos")
	check(room.sim.deadline > route.deadline(), "o evento fixo estica o prazo")
	var sync := ClientSync.new()
	sync.setup(JSON.parse_string(JSON.stringify(room.race_setup())), 0)
	check_near(sync.sim.deadline, room.sim.deadline, 0.001, "cliente tem o mesmo prazo")


func test_open_lane_truck_only_grazes_the_block_edge() -> void:
	var sim := _sim_with({"kind": "works", "z": 300.0, "length": 170.0, "lanes": [1]})
	var i: int = sim.add_truck(330.0, -0.09)                  # faixa do meio, escorregou 0,65 m para a esquerda (curva)
	var t: TruckSim = sim.trucks[i]
	t.lane = Lanes.CENTER
	t.speed = 22.0
	var evs: Array[Dictionary] = []
	for n in int(4.0 / DT):
		t.x = minf(t.x, -0.09) if t.z < 362.0 else t.x       # mantem a escorregada ate a barreira
		sim.set_command(i, Commands.make(0.0, 0.6, 0.0))
		sim.step()
		evs.append_array(sim.drain_events())
	check_eq(_count(evs, "event_obstacle"), 0, "faixa aberta encostando na beirada: sem batida")
	check(_count(evs, "event_scrape") >= 1, "raspou na barreira (%d)" % _count(evs, "event_scrape"))
	check(t.speed > 15.0 and t.z > 380.0, "seguiu viagem (v=%.1f z=%.0f)" % [t.speed, t.z])
	check(t.x - TruckSim.WIDTH_X * 0.5 >= -0.25 - 0.02, "empurrado de volta para a faixa aberta (x=%.2f)" % t.x)


# ---------------------------------------------------------------- bots e transito
func _race_with_bots(ev: Dictionary, density: int, seconds: float = 150.0) -> Dictionary:
	var sim := _sim_with(ev, density, 3200.0)
	var bots: Array[BotDriver] = []
	for k in 4:
		var idx: int = sim.add_truck(-float(k) * 14.0, Room.GRID_X[k])
		sim.trucks[idx].is_bot = true
		bots.append(BotDriver.new(2 - (k % 3), 50 + k, Room.GRID_X[k], false, true))
	var evs: Array[Dictionary] = []
	var wall_ok: bool = true
	for n in int(seconds / DT):
		for k in bots.size():
			sim.set_command(k, bots[k].command_for(sim, k, DT))
		sim.step()
		evs.append_array(sim.drain_events())
		wall_ok = wall_ok and _behind_lane_end(sim)
		if sim.is_over():
			break
	return {"sim": sim, "events": evs, "bots": bots, "wall_ok": wall_ok}


## Ninguem (caminhao ou carro) alem do fim da faixa no estreitamento.
func _behind_lane_end(sim: RaceSim) -> bool:
	var ok: bool = true
	for ev in sim.track.events.list:
		if ev.kind != TrackEvents.Kind.NARROW:
			continue
		var s: int = ev.side()
		var bodies: Array = []
		for t in sim.trucks:
			bodies.append([t.z, t.length, t.x, TruckSim.WIDTH_X * 0.5])
		if sim.traffic != null:
			for c in sim.traffic.cars:
				bodies.append([c.z, c.length, c.x, c.width_x * 0.5])
		for b in bodies:
			var z: float = float(b[0]) + float(b[1]) * 0.5
			if z < ev.full_z() or z > ev.end_z():
				continue
			var iv: Vector2 = sim.track.events.interval(ev, z)
			var edge: float = float(b[2]) + float(b[3]) * float(s)
			if (s > 0 and edge > iv.x + 0.005) or (s < 0 and edge < iv.y - 0.005):
				ok = false
	return ok


func test_bots_avoid_closures_early() -> void:
	var cases: Array = [
		{"kind": "accident", "z": 1300.0, "length": 110.0, "lanes": [2, 3]},
		{"kind": "accident", "z": 1300.0, "length": 110.0, "lanes": [2]},
		{"kind": "works", "z": 1300.0, "length": 170.0, "lanes": [1]},
		{"kind": "narrow", "z": 1300.0, "length": 420.0, "lanes": [3]},
	]
	for ev in cases:
		var r: Dictionary = _race_with_bots(ev, TrafficSim.Density.NORMAL)
		var sim: RaceSim = r["sim"]
		var evs: Array[Dictionary] = r["events"]
		var name: String = "%s %s" % [ev["kind"], ev["lanes"]]
		check_eq(_count(evs, "event_obstacle"), 0, "%s: nenhum bot bateu no bloqueio" % name)
		check(_count(evs, "event_cone") <= 2, "%s: bots quase nao tocam cones (%d)" % [name, _count(evs, "event_cone")])
		check_eq(_count(evs, "event_plates"), 0, "%s: bots passam pelas obras no limite (carga nao sacode)" % name)
		var moves: int = 0
		for b in (r["bots"] as Array):
			moves += (b as BotDriver).closure_moves
		check(moves >= 1, "%s: bots mudaram de faixa por causa do bloqueio (%d)" % [name, moves])
		for k in sim.trucks.size():
			check(sim.trucks[k].finish_position > 0, "%s: bot %d chegou (z=%.0f)" % [name, k, sim.trucks[k].z])
		check(bool(r["wall_ok"]), "%s: ninguem passou do fim da faixa" % name)


func test_narrowing_nobody_crosses_lane_end_and_lane_ending_truck_merges() -> void:
	for lane in [Lanes.FIRST, Lanes.LAST]:
		var sim := _sim_with({"kind": "narrow", "z": 500.0, "length": 420.0, "lanes": [lane]}, TrafficSim.Density.HEAVY, 1600.0)
		var me: int = sim.add_truck(300.0, Lanes.X[lane])          # humano parado na faixa que acaba, sem tocar
		var o: int = sim.add_truck(296.0, Lanes.X[Lanes.CENTER])   # bot ao lado: disputa a vez
		sim.trucks[me].speed = 22.0
		sim.trucks[o].speed = 22.0
		sim.trucks[o].is_bot = true
		var bot := BotDriver.new(BotDriver.Difficulty.HARD, 5, 0.0, false, true)
		var ok: bool = true
		for n in int(60.0 / DT):
			sim.set_command(me, Commands.make(0.0, 0.8, 0.0))
			sim.set_command(o, bot.command_for(sim, o, DT))
			sim.step()
			sim.drain_events()
			ok = ok and _behind_lane_end(sim)
		check(ok, "faixa %d: ninguem atravessou o fim da faixa" % lane)
		var t: TruckSim = sim.trucks[me]
		check(t.lane != lane and t.z > 1000.0, "faixa %d: quem estava na faixa que acaba entrou na outra (faixa %d, z=%.0f)" % [lane, t.lane, t.z])


func test_traffic_moves_out_of_closed_lane() -> void:
	var sim := _sim_with({"kind": "accident", "z": 900.0, "length": 110.0, "lanes": [2, 3]}, TrafficSim.Density.HEAVY, 3000.0)
	var i: int = sim.add_truck(0.0, Lanes.X[Lanes.FIRST])
	var bot := BotDriver.new(BotDriver.Difficulty.NORMAL, 3, Lanes.X[Lanes.FIRST], false, true)
	var ev: TrackEvents.Event = sim.track.events.list[0]
	var passed_open: int = 0
	var prev: Array[float] = []
	for c in sim.traffic.cars:
		prev.append(c.z)
	for n in int(90.0 / DT):
		sim.set_command(i, bot.command_for(sim, i, DT))
		sim.step()
		sim.drain_events()
		for k in sim.traffic.cars.size():
			var c: TrafficSim.Car = sim.traffic.cars[k]
			if prev[k] + c.length <= ev.full_z() and c.z + c.length > ev.full_z() and c.z - prev[k] < 50.0:
				check(c.x + c.width_x * 0.5 <= -0.25 + 0.001, "carro %d passou pelo bloqueio fora da faixa aberta (x=%.2f)" % [k, c.x])
				passed_open += 1
			prev[k] = c.z
	check(passed_open >= 3, "carros passaram pelo acidente na faixa aberta (%d)" % passed_open)


# ---------------------------------------------------------------- online
func test_online_events_come_from_server_and_are_equal_for_all() -> void:
	var room := Room.new("EVT139")
	room.add_member(100, "A", "AAAAAAAA", TruckConfig.basic_descriptor())
	room.add_member(200, "B", "BBBBBBBB", TruckConfig.basic_descriptor())
	room.set_rules(100, {"bots": 1, "traffic": 1, "route": "kanto_2_viaduct"})
	room.set_ready(100, true)
	room.set_ready(200, true)
	check_eq(room.try_start(100, 4242), "", "corrida iniciada")
	var setup: Dictionary = room.race_setup()
	check(setup.has("events"), "o setup leva os eventos")
	var server_json: String = JSON.stringify(room.sim.track.events.to_array())
	check(room.sim.track.events.list.size() >= 1, "o servidor tem pelo menos o evento fixo")
	for peer in [100, 200]:
		var sync := ClientSync.new()
		sync.setup(JSON.parse_string(JSON.stringify(setup)), (room.members[peer] as Room.Member).truck_idx)   # como chega pela rede
		check_eq(JSON.stringify(sync.sim.track.events.to_array()), server_json, "cliente %d tem os mesmos eventos" % peer)
		check(sync.sim.traffic.events != null, "o transito do cliente ve os eventos")
	var other := Room.new("EVT140")
	other.add_member(100, "A", "AAAAAAAA", TruckConfig.basic_descriptor())
	other.set_rules(100, {"route": "kanto_2_viaduct", "events": false})
	other.set_ready(100, true)
	other.try_start(100, 4242)
	check(other.sim.track.events.only_sections(), "regra events = false: pista livre (so os trechos de 2 faixas, T-153)")
	check(other.sim.track.lanes_at(2400.0) == 2, "regra events = false: o trecho de 2 faixas continua")
