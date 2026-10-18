extends TestCase
## T-132: com controle por faixas o caminhao SEGUE A FAIXA sozinho nas curvas.
## Repete a medicao do Marco (acelerar sem tocar no controle nas 3 rotas: desvio < 0,6 m e corpo torto < 3 graus)
## para jogador, Canter, bots e cliente com predicao; +10% da velocidade segura so raspa o pneu, +35% escapa
## (com aviso antes); a troca de faixa gira o corpo no maximo 3 graus, suave, em torno do eixo traseiro.

const DT: float = RaceSim.FIXED_DT
const ROUTES: Array[String] = ["kanto_1_coast", "kanto_2_viaduct", "kanto_3_mountain"]
const MAX_DEV_M: float = 0.6
const MAX_YAW_DEG: float = 3.0


func _track(route_id: String) -> Track:
	return (load("res://data/routes/%s.tres" % route_id) as RouteDef).build_track()


## Angulo (graus) entre o corpo desenhado (mesma chamada da RaceScene3D) e a direcao da pista no meio do caminhao.
func _yaw_vs_road_deg(path: TrackPath, t: TruckSim, z: float, x: float) -> float:
	var tf: Transform3D = path.vehicle_transform(z, x, t.length, t.body_yaw(), t.lean() * 0.11)
	var fwd: Vector3 = -tf.basis.z
	var road: Vector3 = path.forward_at(z + t.length * 0.5)
	return absf(rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(road.x, road.z))))


func _dev_m(t: TruckSim, x: float) -> float:
	return absf(x - Lanes.X[t.lane]) * Track.ROAD_HALF_WIDTH_M


## Corre a rota inteira: acelerador no fundo sem tocar no controle (bot = null) ou dirigido pelo bot.
## Devolve {dev, yaw, time}.
func _drive_route(route_id: String, desc: Dictionary, bot: BotDriver = null) -> Dictionary:
	var track: Track = _track(route_id)
	var path := TrackPath.new(track)
	var sim := RaceSim.new(track)
	var i: int = sim.add_truck(0.0, 0.0)
	var t: TruckSim = sim.trucks[i]
	TruckConfig.apply(t, desc)
	var dev: float = 0.0
	var yaw: float = 0.0
	var n: int = 0
	while t.z < track.length_m and n < 30 * 300:
		sim.set_command(i, bot.command_for(sim, i, DT) if bot != null else Commands.make(0.0, 1.0, 0.0))
		sim.step()
		n += 1
		dev = maxf(dev, _dev_m(t, t.x))
		yaw = maxf(yaw, _yaw_vs_road_deg(path, t, t.z, t.x))
	return {"dev": dev, "yaw": yaw, "time": n * DT}


func test_player_full_throttle_follows_lane_on_all_routes() -> void:
	for r in ROUTES:
		for desc in [{}, {"body": "canter"}]:
			var m: Dictionary = _drive_route(r, desc)
			var who: String = "Canter" if desc.has("body") else "padrao"
			check(float(m["dev"]) < MAX_DEV_M, "%s %s: desvio maximo %.2f m (< %.1f)" % [r, who, float(m["dev"]), MAX_DEV_M])
			check(float(m["yaw"]) < MAX_YAW_DEG, "%s %s: corpo torto %.2f graus (< 3)" % [r, who, float(m["yaw"])])


func test_bots_follow_lane_on_all_routes() -> void:
	for r in ROUTES:
		for d in [BotDriver.Difficulty.EASY, BotDriver.Difficulty.HARD]:
			var m: Dictionary = _drive_route(r, TruckConfig.basic_descriptor(), BotDriver.new(d, 7, 0.0, false, true))
			check(float(m["dev"]) < MAX_DEV_M, "%s bot %d: desvio maximo %.2f m" % [r, d, float(m["dev"])])
			check(float(m["yaw"]) < MAX_YAW_DEG, "%s bot %d: corpo torto %.2f graus" % [r, d, float(m["yaw"])])


## Cliente online com predicao (RTT 150 ms): o caminhao desenhado segue a faixa e bate com o servidor.
func test_client_prediction_follows_lane_like_server() -> void:
	for r in ["kanto_2_viaduct", "kanto_3_mountain"]:
		var room := Room.new("T132AA")
		room.add_member(100, "A", "AAAAAAAA", TruckConfig.basic_descriptor())
		room.set_rules(100, {"bots": 0, "traffic": 0, "route": r})
		room.set_ready(100, true)
		room.try_start(100, 11)
		room.advance(4.0)
		var sync := ClientSync.new()
		sync.setup(room.race_setup(), (room.members[100] as Room.Member).truck_idx)
		var path := TrackPath.new(sync.sim.track)
		var to_server: Array[Dictionary] = []
		var to_client: Array[Dictionary] = []
		var now: int = 0
		var dev: float = 0.0
		var yaw: float = 0.0
		var gap: float = 0.0
		for n in int(70.0 / DT):
			now += 33
			var cmd := Commands.make(0.0, 1.0, 0.0)
			to_server.append({"due": now + 75, "tick": sync.local_step(cmd), "cmd": cmd})
			for d in to_server:
				if int(d["due"]) <= now:
					room.apply_command(100, int(d["tick"]), 0.0, 1.0, 0.0, false)
			to_server = to_server.filter(func(d: Dictionary) -> bool: return int(d["due"]) > now)
			room.step_tick()
			if n % 3 != 2:
				to_client.append({"due": now + 75, "bytes": room.snapshot()})
			for d in to_client:
				if int(d["due"]) <= now:
					sync.on_snapshot(d["bytes"], now)
			to_client = to_client.filter(func(d: Dictionary) -> bool: return int(d["due"]) > now)
			sync.interpolate(now, DT)
			var me: TruckSim = sync.my_truck()
			dev = maxf(dev, _dev_m(me, sync.my_draw_x()))
			yaw = maxf(yaw, _yaw_vs_road_deg(path, me, sync.my_draw_z(), sync.my_draw_x()))
			gap = maxf(gap, absf(me.x - room.sim.trucks[sync.me].x) * Track.ROAD_HALF_WIDTH_M)
		check(dev < MAX_DEV_M, "%s cliente: desvio desenhado %.2f m" % [r, dev])
		check(yaw < MAX_YAW_DEG, "%s cliente: corpo torto %.2f graus" % [r, yaw])
		check(gap < 1.0, "%s cliente: x previsto perto do servidor (%.2f m)" % [r, gap])


## Pista com uma curva constante (sem transicao) e um caminhao a `ratio` x velocidade segura, acelerando.
func _overspeed(ratio: float, throttle: float = 1.0, seconds: float = 4.0) -> Dictionary:
	var t := Track.new()
	t.add_section(3000.0, 1.0, 0.0, 0.0)
	var sim := RaceSim.new(t)
	var i: int = sim.add_truck(0.0, 0.0)
	var tr: TruckSim = sim.trucks[i]
	var v0: float = TruckSim.curve_safe_speed(1.0, tr.grip()) * ratio
	tr.speed = v0
	var dev: float = 0.0
	var skid: float = 0.0
	var escaped: bool = false
	for n in int(seconds / DT):
		sim.set_command(i, Commands.make(0.0, throttle, 0.0))
		sim.step()
		dev = maxf(dev, _dev_m(tr, tr.x))
		skid = maxf(skid, tr.skid)
		escaped = escaped or tr.escaping
	return {"dev": dev, "skid": skid, "escaped": escaped, "lost": v0 - tr.speed}


func test_ten_percent_over_only_scrubs_thirty_five_escapes() -> void:
	var safe: Dictionary = _overspeed(0.98, 0.0)          # sem acelerar, fica abaixo da segura
	check(float(safe["skid"]) == 0.0 and float(safe["dev"]) < 0.01, "abaixo da segura: nem canta pneu, nem sai (%.3f m)" % float(safe["dev"]))
	var slow: Dictionary = _overspeed(1.1)
	check(not bool(slow["escaped"]), "+10%: nao escapa")
	check(float(slow["dev"]) < MAX_DEV_M, "+10%%: desliza no maximo ~0,5 m (%.2f m)" % float(slow["dev"]))
	check(float(slow["skid"]) > 0.2, "+10%%: pneu cantando (%.2f)" % float(slow["skid"]))
	check(float(slow["lost"]) > 0.5, "+10%%: o atrito custa velocidade mesmo acelerando (%.2f m/s)" % float(slow["lost"]))
	var fast: Dictionary = _overspeed(1.35)
	check(bool(fast["escaped"]), "+35%: escapa")
	check(float(fast["dev"]) > 1.8, "+35%%: sai da faixa de verdade (%.2f m)" % float(fast["dev"]))


## Reta de 300 m e curva 1,0: entrando a 35 m/s (+39%), o aviso chega ao maximo bem antes de escapar.
func test_warning_comes_before_escape() -> void:
	var t := Track.new()
	t.add_section(300.0, 0.0)
	t.add_section(600.0, 1.0)
	var sim := RaceSim.new(t)
	var i: int = sim.add_truck(0.0, 0.0)
	var tr: TruckSim = sim.trucks[i]
	tr.speed = 35.0
	var warn_at: float = -1.0
	var escape_at: float = -1.0
	for n in int(14.0 / DT):
		sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
		sim.step()
		if warn_at < 0.0 and tr.curve_warning(t) >= 1.0:
			warn_at = sim.time
		if escape_at < 0.0 and tr.escaping:
			escape_at = sim.time
	check(escape_at > 0.0, "entrando a +39% escapa")
	check(warn_at >= 0.0 and escape_at - warn_at > 1.0, "aviso %.2f s antes de escapar (> 1 s)" % (escape_at - warn_at))


## Troca de faixa na curva: giro do corpo <= 3 graus, suave, em torno do eixo traseiro (o eixo fica na linha do x).
func test_lane_change_turns_body_at_most_3_deg_around_rear_axle() -> void:
	var t := Track.new()
	t.add_section(200.0, 0.0)
	t.add_section(1500.0, 0.8)
	var path := TrackPath.new(t)
	var sim := RaceSim.new(t)
	var i: int = sim.add_truck(250.0, 0.0)
	var tr: TruckSim = sim.trucks[i]
	tr.speed = 20.0
	var taps: Array[float] = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0]
	var max_yaw: float = 0.0
	var max_step: float = 0.0
	var prev: float = 0.0
	var axle_err: float = 0.0
	var follow_err: float = 0.0
	for n in 120:
		sim.set_command(i, Commands.make(taps[n] if n < taps.size() else 0.0, 0.3, 0.0))
		sim.step()
		var yaw: float = rad_to_deg(tr.body_yaw())
		max_yaw = maxf(max_yaw, absf(yaw))
		max_step = maxf(max_step, absf(yaw - prev))
		prev = yaw
		var tf: Transform3D = path.vehicle_transform(tr.z, tr.x, tr.length, tr.body_yaw())
		var axle: Vector3 = tf * Vector3(0, 0, -tr.length * TrackPath.REAR_AXLE)
		axle_err = maxf(axle_err, axle.distance_to(path.world_point(tr.z + tr.length * TrackPath.REAR_AXLE, tr.x)))
		follow_err = maxf(follow_err, absf(_yaw_vs_road_deg(path, tr, tr.z, tr.x) - absf(yaw)))
	check_eq(tr.lane, Lanes.CENTER + 1, "trocou de faixa na curva")
	check(max_yaw <= MAX_YAW_DEG + 0.01 and max_yaw > 1.5, "giro maximo %.2f graus (visivel e <= 3)" % max_yaw)
	check(max_step < 0.5, "giro suave: no maximo %.2f graus por passo" % max_step)
	check(axle_err < 0.01, "o eixo traseiro fica na linha do x (%.3f m)" % axle_err)
	check(follow_err < 0.3, "fora o giro da troca, o corpo acompanha a pista (%.2f graus)" % follow_err)


## Carreta de 17,5 m na faixa de fora de uma curva 1,5: sem giro, o corpo fica alinhado com a pista.
func test_long_body_aligned_in_tight_curve() -> void:
	var t := Track.new()
	t.add_section(1000.0, 1.5, 0.0, 0.0)
	var path := TrackPath.new(t)
	for x in [-0.5, 0.0, 0.5]:
		var tf: Transform3D = path.vehicle_transform(300.0, x, 17.5)
		var fwd: Vector3 = -tf.basis.z
		var road: Vector3 = path.forward_at(300.0 + 17.5 * 0.5)
		var err: float = absf(rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(road.x, road.z))))
		check(err < 0.3, "carreta em x=%.1f alinhada com a pista (%.2f graus)" % [x, err])


## Transito: sem giro na faixa (inclusive nas curvas), giro <= 3 graus e suave na troca de faixa.
func test_traffic_body_yaw_only_on_lane_change() -> void:
	var tr := TrafficSim.new(5, TrafficSim.Density.HEAVY)
	var max_yaw: float = 0.0
	var in_lane_yaw: float = 0.0
	for n in int(30.0 / DT):
		tr.step(DT, 400.0, 0.0)
		for c in tr.cars:
			var y: float = absf(rad_to_deg(TrafficSim.body_yaw(c)))
			max_yaw = maxf(max_yaw, y)
			if absf(c.x - TrafficSim.LANES[c.lane]) < 0.001:
				in_lane_yaw = maxf(in_lane_yaw, y)
	check(max_yaw <= MAX_YAW_DEG + 0.01 and max_yaw > 1.0, "transito: giro maximo na troca %.2f graus" % max_yaw)
	check(in_lane_yaw == 0.0, "transito: na faixa nao gira")
