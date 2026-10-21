extends TestCase
## T-183: carro do transito acidentado. Depois da batida ele para, fica no angulo em que parou, vira obstaculo
## (transito e bots desviam ou freiam), bater de novo empurra mas ele nao volta a andar, vai no snapshot e some
## a 300 m atras do ultimo caminhao. Tudo deterministico (servidor autoritativo).

const DT: float = 1.0 / 30.0


func _flat_track(length: float = 4000.0) -> Track:
	var track := Track.new()
	track.add_section(length, 0.0)
	return track


func _car(kind: int, z: float, lane: int, speed: float) -> TrafficSim.Car:
	var c := TrafficSim.Car.new()
	c.kind = kind
	c.length = TrafficSim.KIND_LEN[kind]
	c.width_x = TrafficSim.KIND_WIDTH_X[kind]
	c.mass = TrafficSim.KIND_MASS[kind]
	c.z = z
	c.lane = lane
	c.x = TrafficSim.LANES[lane]
	c.cruise = speed
	c.speed = speed
	c.timer = 999.0
	return c


## Carro ja acidentado e parado (z, x, giro em rad).
func _wreck(z: float, x: float, yaw: float) -> TrafficSim.Car:
	var c: TrafficSim.Car = _car(TrafficSim.Kind.CAR, z, 1, 0.0)
	c.x = x
	c.yaw = yaw
	Wreck.mark(c)
	return c


func _overlap(a: TrafficSim.Car, b: TrafficSim.Car) -> bool:
	return Wreck.footprint(a).intersects(Wreck.footprint(b))


func test_footprint_uses_the_draw_pivot() -> void:
	check_eq(Wreck.PIVOT, TrackPath.REAR_AXLE, "mesmo pivo do desenho (eixo traseiro)")
	var c: TrafficSim.Car = _car(TrafficSim.Kind.CAR, 100.0, 1, 0.0)
	var r: Rect2 = Wreck.footprint(c)
	check_near(r.position.x, 100.0, 0.001, "reto: traseira no z do carro")
	check_near(r.size.y, c.width_x, 0.0001, "reto: largura do carro")
	c.yaw = PI * 0.5
	r = Wreck.footprint(c)
	check_near(r.size.y * Track.ROAD_HALF_WIDTH_M, c.length, 0.01, "atravessado: ocupa o comprimento na largura")
	check_near(r.size.x, c.width_x * Track.ROAD_HALF_WIDTH_M, 0.01, "atravessado: ocupa a largura no comprimento")


func test_hit_car_stops_and_keeps_its_angle() -> void:
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	tr.cars.clear()
	tr.cars.append(_car(TrafficSim.Kind.CAR, 200.0, 1, 10.0))
	var truck := TruckSim.new()
	truck.z = 200.0 - 12.0 + 0.4
	truck.speed = 30.0
	var evs: Array[Dictionary] = Collision.new().resolve_traffic(truck, 0, tr)
	check(bool(evs[0]["thrown"]), "arremessado")
	var c: TrafficSim.Car = tr.cars[0]
	check(c.wrecked and tr.wrecks == 1, "virou carro acidentado na batida")
	for k in 30 * 12:
		tr.step(DT, 600.0, 0.0)
	check_eq(c.speed, 0.0, "parou de escorregar")
	check(c.vx == 0.0 and c.yaw_rate == 0.0, "parou de deslizar de lado e de girar")
	check(absf(c.yaw) > 0.05, "ficou torto (%.0f graus)" % rad_to_deg(c.yaw))
	var yaw: float = c.yaw
	var z: float = c.z
	var x: float = c.x
	for k in 30 * 20:
		tr.step(DT, 600.0, 0.0)
	check_eq(c.yaw, yaw, "nao endireita")
	check(c.z == z and c.x == x, "nao volta a andar")
	check(c.wrecked, "continua acidentado")
	check_near(c.crash_t, 32.0, 0.1, "tempo desde a batida (fumaca, triangulo)")


func test_traffic_behind_changes_lane_or_stops_never_drives_through() -> void:
	# (1) faixa vizinha livre: muda de faixa e passa
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	tr.cars.clear()
	var w: TrafficSim.Car = _wreck(400.0, 0.0, 1.3)            # atravessado na faixa do meio
	var b: TrafficSim.Car = _car(TrafficSim.Kind.CAR, 250.0, 1, 22.0)
	tr.cars.append(w)
	tr.cars.append(b)
	var crossed: bool = false
	for k in 30 * 20:
		tr.step(DT, 3000.0, 0.0)
		crossed = crossed or _overlap(w, b)
	check(not crossed, "nunca atravessa o acidentado")
	check(b.z > Wreck.footprint(w).end.x, "passou dele (z=%.0f)" % b.z)
	check(b.speed > 15.0, "passou andando (%.1f m/s)" % b.speed)
	# (2) as 3 faixas fechadas por acidentados: freia e fica atras
	var tr2 := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	tr2.cars.clear()
	var ws: Array[TrafficSim.Car] = [_wreck(410.0, -0.5, 0.0), _wreck(400.0, 0.0, 1.3), _wreck(410.0, 0.5, 0.0)]
	for wc in ws:
		tr2.cars.append(wc)
	var b2: TrafficSim.Car = _car(TrafficSim.Kind.CAR, 250.0, 1, 22.0)
	tr2.cars.append(b2)
	var crossed2: bool = false
	for k in 30 * 20:
		tr2.step(DT, 3000.0, 0.0)
		for wc in ws:
			crossed2 = crossed2 or _overlap(wc, b2)
	check(not crossed2, "sem saida: nao atravessa nenhum")
	check(b2.speed < 0.5, "freou e parou (%.1f m/s)" % b2.speed)
	check(b2.z + b2.length < 410.0, "parado atras dos acidentados (nariz em %.0f)" % (b2.z + b2.length))
	check_eq(tr2.wreck_bumps, 0, "freou a tempo (sem encostar)")


func test_car_that_cannot_brake_bumps_and_stays_behind() -> void:
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	tr.cars.clear()
	var w: TrafficSim.Car = _wreck(300.0, 0.0, 0.0)
	var b: TrafficSim.Car = _car(TrafficSim.Kind.CAR, 300.0 - 4.5 - 1.0, 1, 25.0)   # 1 m atras, a 90 km/h
	tr.cars.append(w)
	tr.cars.append(b)
	tr.cars.append(_car(TrafficSim.Kind.CAR, 300.0, 0, 25.0))   # faixas vizinhas ocupadas: nao da para desviar
	tr.cars.append(_car(TrafficSim.Kind.CAR, 300.0, 2, 25.0))
	for k in 10:
		tr.step(DT, 3000.0, 0.0)
		check(b.z + b.length <= Wreck.footprint(w).position.x + 0.001, "fica atras (tick %d)" % k)
	check(tr.wreck_bumps >= 1, "bateu nele")
	check(w.speed > 0.0 or w.z > 300.0, "a batida empurra o acidentado")
	check(w.wrecked, "e ele continua acidentado")


func test_bot_trucks_avoid_the_wreck() -> void:
	for diff in [BotDriver.Difficulty.EASY, BotDriver.Difficulty.NORMAL, BotDriver.Difficulty.HARD]:
		var sim := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT, 5)
		sim.traffic.cars.clear()
		sim.traffic.cars.append(_wreck(500.0, 0.0, 1.0))
		var i: int = sim.add_truck(200.0, 0.0)
		sim.trucks[i].is_bot = true
		sim.trucks[i].speed = 26.0
		var bot := BotDriver.new(diff, 3, 0.0, false, true)
		var hits: int = 0
		for k in 30 * 25:
			sim.set_command(i, bot.command_for(sim, i, DT))
			sim.step()
			for e in sim.drain_events():
				if String(e["type"]) == "traffic":
					hits += 1
		check_eq(hits, 0, "bot %d desviou sem bater" % diff)
		check(sim.trucks[i].z > 520.0, "bot %d passou o acidentado (z=%.0f)" % [diff, sim.trucks[i].z])


func test_second_hit_pushes_but_it_never_drives_again() -> void:
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	tr.cars.clear()
	var w: TrafficSim.Car = _wreck(300.0, 0.0, 1.2)
	tr.cars.append(w)
	var truck := TruckSim.new()
	truck.z = Wreck.footprint(w).position.x - 12.0 + 0.3
	truck.speed = 15.0
	var evs: Array[Dictionary] = Collision.new().resolve_traffic(truck, 0, tr)
	check_eq(evs.size(), 1, "bateu no acidentado")
	check(bool(evs[0]["wreck"]), "o evento sabe que era um acidentado")
	check(bool(evs[0]["thrown"]), "mesma fisica: 15 m/s arremessa de novo")
	check(w.speed > 5.0, "foi empurrado (%.1f m/s)" % w.speed)
	check(truck.speed < 15.0, "o caminhao perde velocidade")
	for k in 30 * 15:
		tr.step(DT, 3000.0, 0.0)
	check(w.z > 305.0, "andou com o empurrao (z=%.1f)" % w.z)
	check_eq(w.speed, 0.0, "e parou de novo")
	check(w.wrecked, "nao voltou a andar")
	check_eq(tr.wrecks, 0, "nao conta como carro novo acidentado (ja era)")


func test_wreck_is_deterministic() -> void:
	var states: Array[String] = []
	var wrecks: int = 0
	for run in 2:
		var sim := RaceSim.new(_flat_track(), TrafficSim.Density.HEAVY, 77)
		var i: int = sim.add_truck(60.0, 0.0)
		var j: int = sim.add_truck(40.0, 0.5)
		sim.trucks[i].speed = 36.0
		sim.trucks[j].is_bot = true
		var bot := BotDriver.new(BotDriver.Difficulty.HARD, 5, 0.5, false, true)
		for k in 30 * 50:
			sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
			sim.set_command(j, bot.command_for(sim, j, DT))
			sim.step()
		var s: String = "%d|%d|%d|" % [sim.traffic.throws, sim.traffic.wrecks, sim.traffic.wreck_bumps]
		for c in sim.traffic.cars:
			s += "%.4f,%.4f,%.4f,%.4f,%s,%.3f;" % [c.z, c.x, c.yaw, c.speed, str(c.wrecked), c.crash_t]
		for t in sim.trucks:
			s += "T%.4f,%.4f;" % [t.z, t.x]
		states.append(s)
		wrecks = sim.traffic.wrecks
	check(wrecks >= 1, "houve carro acidentado no teste (%d)" % wrecks)
	check_eq(states[0], states[1], "mesma semente e comandos = mesmos acidentados (servidor e clientes)")


func test_snapshot_round_trip_and_client_interpolation() -> void:
	var sim := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	sim.add_truck(0.0, 0.0)
	var c2: TrafficSim.Car = sim.traffic.cars[2]
	c2.wrecked = true
	c2.crash_t = 4.23
	c2.yaw = 1.1
	sim.traffic.cars[4].wrecked = true
	sim.traffic.cars[4].crash_t = 100.0
	var data: PackedByteArray = Snapshot.pack(sim, [0])
	var snap: Dictionary = Snapshot.unpack(data)
	var mirror := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	mirror.add_truck(0.0, 0.0)
	Snapshot.apply_to(mirror, snap)
	check(mirror.traffic.cars[2].wrecked, "acidentado chega no cliente")
	check_near(mirror.traffic.cars[2].crash_t, 4.2, 0.051, "tempo desde a batida (decimos de s)")
	check_near(mirror.traffic.cars[2].yaw, 1.1, 0.002, "com o giro")
	check(not mirror.traffic.cars[3].wrecked, "carro normal continua normal")
	check_near(mirror.traffic.cars[4].crash_t, 25.4, 0.001, "tempo satura em 25,4 s (1 byte)")
	check_eq(Protocol.VERSION, 8, "protocolo 8 (formato do snapshot mudou)")
	# cliente: interpolacao entre dois snapshots (desenhado ~100 ms atras)
	var cs := ClientSync.new()
	cs.sim = mirror
	c2.crash_t = 5.0
	cs.on_snapshot(Snapshot.pack(sim, [0]), 1000)
	c2.crash_t = 5.2
	cs.on_snapshot(Snapshot.pack(sim, [0]), 1050)
	mirror.traffic.cars[2].wrecked = false
	cs.interpolate(1125, 0.016)
	check(mirror.traffic.cars[2].wrecked, "interpolacao mantem o acidentado")
	check_near(mirror.traffic.cars[2].crash_t, 5.1, 0.02, "tempo interpolado")


func test_wreck_goes_away_300m_behind_last_truck() -> void:
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	tr.cars.clear()
	var w: TrafficSim.Car = _wreck(500.0, 0.0, 0.8)
	tr.cars.append(w)
	tr.step(DT, 900.0, 500.0 + Wreck.DESPAWN_BEHIND - 1.0)
	check(w.wrecked and w.z == 500.0, "a 299 m atras continua la")
	tr.step(DT, 900.0, 500.0 + Wreck.DESPAWN_BEHIND + 1.0)
	check(not w.wrecked, "a 301 m atras some")
	check(w.z > 900.0 and w.yaw == 0.0 and w.crash_t == 0.0, "e volta como carro novo a frente do lider (z=%.0f)" % w.z)
	check(w.speed > 10.0, "andando")
