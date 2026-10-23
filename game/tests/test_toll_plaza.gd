extends TestCase
## T-207: praca de pedagio com ilha central (cabine) e duas passagens. Fisica na simulacao (TollPlaza + TollContact):
## bater na ilha e batida com dano; as duas passagens sao livres; acostamento acaba no funil; bots, rival e transito
## escolhem uma passagem e nunca atravessam a cabine; igual no servidor e no cliente.

const DT: float = RaceSim.FIXED_DT
const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]


func _straight(length: float = 2000.0) -> Track:
	var t := Track.new()
	t.add_section(length, 0.0)
	t.set_toll(TollPlaza.DEFAULT_Z)
	return t


func _count(events: Array[Dictionary], type: String, truck: int = -1, ev_id: String = "") -> int:
	var n: int = 0
	for e in events:
		if String(e["type"]) == type and (truck < 0 or int(e["truck"]) == truck) and (ev_id == "" or String(e.get("event", "")) == ev_id):
			n += 1
	return n


## Corpo [x - w, x + w] dentro da ilha (com folga de 1 cm) entre z e z + length?
func _inside_island(p: TollPlaza, z: float, length: float, x: float, half: float) -> bool:
	var ih: float = p.island_half_x() - 0.0015
	return z + length > p.nose_z() + 0.01 and z < p.tail_z() and x + half > -ih and x - half < ih


func _tap(sim: RaceSim, i: int, dir: float, throttle: float = 0.7) -> void:
	for n in 3:
		sim.set_command(i, Commands.make(dir, throttle, 0.0))
		sim.step()
	for n in 3:
		sim.set_command(i, Commands.make(0.0, throttle, 0.0))
		sim.step()


# ---------------------------------------------------------------- geometria
func test_geometry_two_passages_fit_and_middle_closes() -> void:
	var p := TollPlaza.new(150.0)
	var half: float = TruckSim.WIDTH_X * 0.5
	for lane in [Lanes.FIRST, Lanes.LAST]:
		check(not p.lane_blocked_between(lane, 0.0, 1000.0), "faixa %d (passagem) nunca fecha" % lane)
	for lane in [Lanes.SHOULDER_L, Lanes.CENTER, Lanes.SHOULDER_R]:
		check(p.lane_blocked_between(lane, 0.0, 1000.0), "faixa %d fecha no pedagio" % lane)
	check_near(p.block_z[Lanes.CENTER], p.nose_z(), 1.01, "o meio fecha no nariz da ilha")
	check_near(p.clear_z[Lanes.CENTER], p.tail_z(), 1.01, "e reabre no fim da ilha")
	check(p.block_z[Lanes.SHOULDER_L] < p.nose_z() and p.block_z[Lanes.SHOULDER_L] > p.zone_start(), "o acostamento acaba no funil")
	check_eq(p.block_z[Lanes.SHOULDER_L], p.block_z[Lanes.SHOULDER_R], "funil simetrico")
	# a passagem cabe o caminhao com folga dos dois lados
	var inner: float = (Lanes.X[Lanes.LAST] - half) * Track.ROAD_HALF_WIDTH_M - TollPlaza.ISLAND_HALF_M
	var outer: float = TollPlaza.OUTER_FACE_M - (Lanes.X[Lanes.LAST] + half) * Track.ROAD_HALF_WIDTH_M
	check(inner > 0.4 and outer > 0.4, "folga na passagem: ilha %.2f m, ilha de fora %.2f m" % [inner, outer])
	# funil sem degrau: a parede anda no maximo ~0,2 m por metro
	var prev: float = p.outer_face_m(p.zone_start() - 1.0)
	var zz: float = p.zone_start()
	while zz <= p.zone_end() + 1.0:
		var f: float = p.outer_face_m(zz)
		check(absf(f - prev) < 0.25, "funil suave em z=%.0f (%.2f -> %.2f)" % [zz, prev, f])
		prev = f
		zz += 1.0
	check_near(p.outer_face_m(p.zone_start() - 5.0), LaneSections.OPEN_WALL_M, 0.001, "antes do funil: mureta normal")
	check_near(p.outer_face_m(p.z), TollPlaza.OUTER_FACE_M, 0.001, "na cabine: ilha de fora")
	check(p.gore(p.nose_z() - 1.0) > 0.9 and p.gore(p.nose_z() - TollPlaza.GORE_M - 1.0) == 0.0, "zebra cresce ate o nariz")


func test_routes_have_the_plaza_outside_the_event_list() -> void:
	for r in ROUTES:
		var route: RouteDef = load("res://data/routes/%s.tres" % r) as RouteDef
		var track: Track = route.build_track()
		check(track.toll != null and is_equal_approx(track.toll.z, 150.0), "%s: pedagio em 150 m" % r)
		var evs: TrackEvents = route.build_events(track, 5)
		track.events = evs
		check(track.events.toll == track.toll, "%s: a lista de eventos recebe o pedagio" % r)
		for e in track.events.to_array():
			check(String(e["kind"]) != "toll", "%s: o pedagio nao vai em `events`" % r)
		track.events = TrackEvents.new()                       # --no-events / regra events = false
		check(track.events.toll == track.toll and not track.events.is_empty(), "%s: sem eventos o pedagio continua" % r)
		check(track.lanes_at(150.0) == 3, "%s: o pedagio nao vira trecho de 2 faixas" % r)


# ---------------------------------------------------------------- caminhao
func test_middle_lane_crashes_into_island_with_damage() -> void:
	var sim := RaceSim.new(_straight())
	var i: int = sim.add_truck(30.0, 0.0)
	var t: TruckSim = sim.trucks[i]
	t.set_loadout([DamageModel.make_part("bumper", ["front"], 50.0, 60.0)])
	var p: TollPlaza = sim.track.toll
	var evs: Array[Dictionary] = []
	var speed_at_hit: float = 0.0
	for n in int(30.0 / DT):
		var before: float = t.speed
		sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
		sim.step()
		var got: Array[Dictionary] = sim.drain_events()
		if _count(got, "event_obstacle") > 0 and speed_at_hit == 0.0:
			speed_at_hit = before
		evs.append_array(got)
		check(not _inside_island(p, t.z, t.length, t.x, TruckSim.WIDTH_X * 0.5), "nao atravessa a ilha (z=%.1f x=%.3f)" % [t.z, t.x])
	var hits: int = _count(evs, "event_obstacle", i, "toll")
	check(hits >= 1 and hits <= 2, "bateu na ilha (%d)" % hits)
	var dmg: float = 0.0
	var broken: int = 0
	for e in evs:
		if String(e["type"]) == "event_obstacle":
			dmg += float(e["damage"])
			broken += (e["broken"] as Array).size()
			check_eq(String(e["zone"]), "front", "de frente")
	check(speed_at_hit > 12.0, "chegou rapido no nariz (%.1f m/s)" % speed_at_hit)
	check_near(dmg, DamageModel.impact_damage(speed_at_hit, EventContact.OBSTACLE_MASS), 0.5 + speed_at_hit, "dano como o dos obstaculos (%.0f)" % dmg)
	check(broken >= 1, "o para-choque quebrou")
	check(t.cargo_loss() > 0.02, "perdeu carga (%.3f)" % t.cargo_loss())
	check_eq(t.lane, Lanes.FIRST, "saiu para a passagem da esquerda (x = 0: mantem a esquerda)")
	check(t.z > p.zone_end(), "seguiu depois de bater (z=%.0f)" % t.z)


func test_both_passages_are_free() -> void:
	for lane in [Lanes.FIRST, Lanes.LAST]:
		var sim := RaceSim.new(_straight())
		var i: int = sim.add_truck(30.0, Lanes.X[lane])
		var t: TruckSim = sim.trucks[i]
		var evs: Array[Dictionary] = []
		for n in int(20.0 / DT):
			sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
			sim.step()
			evs.append_array(sim.drain_events())
		check(evs.filter(func(e: Dictionary) -> bool: return String(e["type"]).begins_with("event_")).is_empty(), "faixa %d: passou sem encostar" % lane)
		check(t.z > sim.track.toll.zone_end() and t.lane == lane, "faixa %d: seguiu na mesma faixa" % lane)
		check(t.speed > 20.0, "faixa %d: sem perder velocidade (%.1f m/s)" % [lane, t.speed])


func test_shoulder_ends_at_the_funnel_and_merges() -> void:
	for lane in [Lanes.SHOULDER_L, Lanes.SHOULDER_R]:
		var sim := RaceSim.new(_straight())
		var i: int = sim.add_truck(20.0, Lanes.X[lane])
		var t: TruckSim = sim.trucks[i]
		var p: TollPlaza = sim.track.toll
		var evs: Array[Dictionary] = []
		for n in int(20.0 / DT):
			sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
			sim.step()
			evs.append_array(sim.drain_events())
			var lim: float = p.outer_limit_x(t.z, t.length)
			check(absf(t.x) + TruckSim.WIDTH_X * 0.5 <= lim + 0.05, "acostamento %d: nao atravessa a ilha de fora (z=%.0f)" % [lane, t.z])
		check_eq(_count(evs, "event_obstacle"), 0, "acostamento %d: o funil raspa, nao bate" % lane)
		check_eq(t.lane, Lanes.FIRST if lane == Lanes.SHOULDER_L else Lanes.LAST, "acostamento %d: entrou na passagem" % lane)
		check(t.z > p.zone_end(), "acostamento %d: seguiu" % lane)


func test_cannot_change_into_the_island_and_pushes_stay_out() -> void:
	var sim := RaceSim.new(_straight())
	var i: int = sim.add_truck(95.0, Lanes.X[Lanes.FIRST])
	var t: TruckSim = sim.trucks[i]
	t.speed = 15.0
	_tap(sim, i, 1.0)
	_tap(sim, i, 1.0)
	check_eq(t.lane, Lanes.FIRST, "troca para o meio perto da ilha: recusada")
	check(t.lane_refusals >= 1, "recusa contada (HUD mostra)")
	# empurrado de lado contra a ilha: volta para a passagem, raspa ou bate de lado, nunca entra
	var sim2 := RaceSim.new(_straight())
	var j: int = sim2.add_truck(140.0, Lanes.X[Lanes.FIRST])
	var t2: TruckSim = sim2.trucks[j]
	t2.speed = 20.0
	var evs: Array[Dictionary] = []
	for n in 30:
		t2.lateral_vel = 0.9                              # jogado para a direita a cada passo (como um empurrao)
		sim2.set_command(j, Commands.make(0.0, 0.6, 0.0))
		sim2.step()
		evs.append_array(sim2.drain_events())
		check(not _inside_island(sim2.track.toll, t2.z, t2.length, t2.x, TruckSim.WIDTH_X * 0.5), "empurrado: fora da ilha (x=%.3f)" % t2.x)
	check(_count(evs, "event_obstacle") + _count(evs, "event_scrape") >= 1, "encostou na ilha de lado")
	for e in evs:
		if String(e["type"]) == "event_obstacle":
			check_eq(String(e["zone"]), "right", "batida de lado: a ilha esta a direita")


func test_two_trucks_shoving_beside_the_island() -> void:
	var sim := RaceSim.new(_straight())
	var a: int = sim.add_truck(100.0, Lanes.X[Lanes.FIRST])
	var b: int = sim.add_truck(100.0, Lanes.X[Lanes.SHOULDER_L])
	for t in sim.trucks:
		t.speed = 18.0
	for n in int(8.0 / DT):
		sim.set_command(a, Commands.make(0.0, 0.8, 0.0))
		sim.set_command(b, Commands.make(1.0 if n % 6 < 3 else 0.0, 0.8, 0.0))   # tenta entrar na faixa 1 o tempo todo
		sim.step()
		for t in sim.trucks:
			check(not _inside_island(sim.track.toll, t.z, t.length, t.x, TruckSim.WIDTH_X * 0.5), "ninguem e empurrado para dentro da ilha")
			check(absf(t.x) + TruckSim.WIDTH_X * 0.5 <= sim.track.toll.outer_limit_x(t.z, t.length) + 0.05, "nem para dentro da ilha de fora")


# ---------------------------------------------------------------- bots, rival e transito
func _race(route_id: String, seed_: int, n: int, density: int) -> Dictionary:
	var route: RouteDef = load("res://data/routes/%s.tres" % route_id) as RouteDef
	var track: Track = route.build_track()
	track.events = route.build_events(track, seed_)
	var sim := RaceSim.new(track, density, seed_)
	var bots: Array[BotDriver] = []
	for k in n:
		var s: Vector2 = StartGrid.slot(k, n)
		sim.add_truck(s.x, s.y)
		var d: int = [BotDriver.Difficulty.EASY, BotDriver.Difficulty.NORMAL, BotDriver.Difficulty.HARD][(k + seed_) % 3]
		bots.append(BotDriver.new(d, seed_ * 10 + k, StartGrid.lane_x(k) if n > 2 else s.y, k == 1, false))
		sim.trucks[k].is_bot = true
	var p: TollPlaza = track.toll
	var evs: Array[Dictionary] = []
	var inside: int = 0
	var car_inside: int = 0
	for step_ in int(45.0 / DT):
		for k in n:
			sim.set_command(k, bots[k].command_for(sim, k, DT))
		sim.step()
		evs.append_array(sim.drain_events())
		for t in sim.trucks:
			if _inside_island(p, t.z, t.length, t.x, TruckSim.WIDTH_X * 0.5):
				inside += 1
		if sim.traffic != null:
			for c in sim.traffic.cars:
				if _inside_island(p, c.z, c.length, c.x, c.width_x * 0.5):
					car_inside += 1
	var passed: int = 0
	for t in sim.trucks:
		if t.z > p.zone_end():
			passed += 1
	return {"evs": evs, "inside": inside, "car_inside": car_inside, "passed": passed, "sim": sim}


func test_bots_and_rival_pick_a_passage_and_never_cross_the_booth() -> void:
	for r in ROUTES:
		for seed_ in [3, 8]:
			for n in [2, 4]:
				var res: Dictionary = _race(r, seed_, n, TrafficSim.Density.NORMAL)
				var tag: String = "%s semente %d, %d caminhoes" % [r, seed_, n]
				check_eq(int(res["inside"]), 0, "%s: ninguem dentro da cabine" % tag)
				check_eq(int(res["car_inside"]), 0, "%s: carro do transito nunca na ilha" % tag)
				check_eq(_count(res["evs"], "event_obstacle", -1, "toll"), 0, "%s: bot nenhum bate na ilha" % tag)
				check_eq(int(res["passed"]), n, "%s: todos passaram pelo pedagio" % tag)


func test_traffic_avoids_the_island() -> void:
	var sim := RaceSim.new(_straight(3000.0), TrafficSim.Density.HEAVY, 21)
	var i: int = sim.add_truck(20.0, Lanes.X[Lanes.FIRST])
	var p: TollPlaza = sim.track.toll
	for c in sim.traffic.cars:
		check(not (c.lane == 1 and c.z > p.nose_z() - 60.0 and c.z < p.tail_z()), "nenhum carro nasce no meio perto da ilha")
	for n in int(20.0 / DT):
		sim.set_command(i, Commands.make(0.0, 0.3, 0.0))
		sim.step()
		for c in sim.traffic.cars:
			check(not _inside_island(p, c.z, c.length, c.x, c.width_x * 0.5), "carro fora da ilha (z=%.0f x=%.2f)" % [c.z, c.x])


# ---------------------------------------------------------------- rede e determinismo
func test_same_plaza_on_server_and_client_and_deterministic() -> void:
	var a: Dictionary = _race("kanto_2_viaduct", 4, 4, TrafficSim.Density.NORMAL)
	var b: Dictionary = _race("kanto_2_viaduct", 4, 4, TrafficSim.Density.NORMAL)
	var sa: RaceSim = a["sim"]
	var sb: RaceSim = b["sim"]
	for k in sa.trucks.size():
		check_eq(sa.trucks[k].z, sb.trucks[k].z, "caminhao %d: mesmo z" % k)
		check_eq(sa.trucks[k].x, sb.trucks[k].x, "caminhao %d: mesmo x" % k)
	var room := Room.new("T207AA")
	room.add_member(100, "A", "AAAAAAAA", TruckConfig.basic_descriptor())
	room.set_rules(100, {"bots": 1, "traffic": 1, "route": "kanto_1_coast", "events": false})
	room.set_ready(100, true)
	room.try_start(100, 9)
	var sync := ClientSync.new()
	sync.setup(room.race_setup(), (room.members[100] as Room.Member).truck_idx)
	check(room.sim.track.toll != null and sync.sim.track.toll != null, "servidor e cliente com o pedagio")
	check_eq(sync.sim.track.toll.z, room.sim.track.toll.z, "no mesmo lugar")
	check(not sync.sim.track.events.is_empty(), "cliente: eventos com o pedagio (contato ligado)")
	check(Protocol.VERSION >= 10, "protocolo 10 (a simulacao mudou com o pedagio)")


func test_radar_shows_the_island() -> void:
	var sim := RaceSim.new(_straight())
	sim.add_truck(30.0, Lanes.X[Lanes.LAST])
	var kinds: Array = []
	var middle: bool = false
	for b in RadarModel.blips(sim, 0):
		kinds.append(int(b["kind"]))
		if int(b["kind"]) == RadarModel.Kind.TOLL and float(b["x0"]) < 0.0 and float(b["x1"]) > 0.0:
			middle = true
	check_eq(kinds.count(RadarModel.Kind.TOLL), 3, "o radar mostra a ilha e as 2 ilhas de fora")
	check(middle, "a ilha da cabine fica no meio do radar")
