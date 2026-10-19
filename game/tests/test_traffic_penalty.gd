extends TestCase
## T-152: batida no transito custa velocidade (penalidade arcade na simulacao) + tranco de ~0,6 s (acelerador sem
## efeito, freio funciona). Valores em docs/BALANCEAMENTO.md ("Batida no transito: penalidade e tranco").

const DT: float = 1.0 / 30.0


func _flat_track() -> Track:
	var track := Track.new()
	track.add_section(4000.0, 0.0)
	return track


## Transito so com um veiculo do tipo `kind` em z (faixa do transito `lane`, velocidade `speed`).
func _one(kind: int, z: float, lane: int, speed: float) -> TrafficSim:
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	tr.cars.clear()
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
	tr.cars.append(c)
	return tr


## Batida de frente na traseira: caminhao a `v_truck`, veiculo a `v_car`, ja encostando. Devolve [fracao perdida, evento].
func _front_hit(kind: int, v_truck: float, v_car: float) -> Array:
	var tr: TrafficSim = _one(kind, 200.0, 1, v_car)
	var truck := TruckSim.new()
	truck.z = 200.0 - truck.length + 0.3
	truck.speed = v_truck
	var evs: Array[Dictionary] = Collision.new().resolve_traffic(truck, 0, tr)
	return [(v_truck - truck.speed) / v_truck, evs[0] if not evs.is_empty() else {}, truck]


## Raspao lateral: caminhao entrando na faixa da direita com `lat` x/s em cima do veiculo. Devolve [fracao, evento].
func _side_hit(kind: int, lat: float, v: float = 26.0) -> Array:
	var tr: TrafficSim = _one(kind, 104.0, 2, v - 1.0)
	var truck := TruckSim.new()
	truck.z = 100.0
	truck.speed = v
	truck.x = 0.5 - (TruckSim.WIDTH_X + tr.cars[0].width_x) * 0.5 + 0.03
	truck.lateral_vel = lat
	var evs: Array[Dictionary] = Collision.new().resolve_traffic(truck, 0, tr)
	return [(v - truck.speed) / v, evs[0] if not evs.is_empty() else {}, truck]


func test_weak_front_hit_costs_about_25_percent() -> void:
	var r: Array = _front_hit(TrafficSim.Kind.CAR, 22.0, 19.5)          # 2,5 m/s de diferenca
	var lost: float = r[0]
	check(lost >= 0.25 - 0.001 and lost <= 0.30, "batida de frente fraca: perde ~25%% (%.1f%%)" % (lost * 100.0))
	check_near(float((r[1] as Dictionary)["penalty"]), lost, 0.001, "o evento diz a penalidade aplicada")
	check(bool((r[2] as TruckSim).jolted()), "comeca o tranco")


func test_strong_front_hit_costs_40_percent_and_still_throws_car() -> void:
	var r: Array = _front_hit(TrafficSim.Kind.CAR, 32.0, 10.0)          # 22 m/s de diferenca
	var lost: float = r[0]
	check(lost >= 0.40 - 0.001 and lost <= 0.40 + 0.001, "batida de frente forte: perde 40%% (%.1f%%)" % (lost * 100.0))
	check(bool((r[1] as Dictionary)["thrown"]), "o carro continua sendo arremessado")
	var mid: Array = _front_hit(TrafficSim.Kind.CAR, 27.0, 20.0)        # 7 m/s: no meio da faixa
	check(float(mid[0]) > 0.27 and float(mid[0]) < 0.38, "batida media fica entre as duas (%.1f%%)" % (float(mid[0]) * 100.0))


func test_front_penalty_grows_with_force_within_range() -> void:
	var prev: float = 0.0
	for dv in [1.5, 3.0, 6.0, 9.0, 12.0, 20.0]:
		var p: float = Collision.penalty_fraction(true, dv, 1500.0)
		check(p >= Collision.PEN_FRONT_MIN and p <= Collision.PEN_FRONT_MAX, "de frente %.1f m/s dentro de 25-40%% (%.1f%%)" % [dv, p * 100.0])
		check(p >= prev, "cresce com a forca")
		prev = p


func test_side_swipe_costs_8_to_15_percent() -> void:
	var weak: Array = _side_hit(TrafficSim.Kind.CAR, 0.3)
	var strong: Array = _side_hit(TrafficSim.Kind.CAR, 0.9)
	check(not (weak[1] as Dictionary).is_empty() and String((weak[1] as Dictionary)["zone"]) == "right", "raspao fraco na lateral direita")
	for r in [weak, strong]:
		var lost: float = r[0]
		check(lost >= 0.08 - 0.001 and lost <= 0.15 + 0.001, "raspao lateral: perde 8-15%% (%.1f%%)" % (lost * 100.0))
	check(float(strong[0]) > float(weak[0]), "raspao mais forte custa mais (%.1f%% > %.1f%%)" % [float(strong[0]) * 100.0, float(weak[0]) * 100.0])
	check_eq((strong[2] as TruckSim).jolt_side, 1, "tranco do lado direito (para o balanco)")


func test_bus_costs_more_than_car() -> void:
	var car_f: float = _front_hit(TrafficSim.Kind.CAR, 25.0, 15.0)[0]
	var bus_f: float = _front_hit(TrafficSim.Kind.BUS, 25.0, 15.0)[0]
	check(bus_f > car_f + 0.05, "de frente: onibus %.0f%% > carro %.0f%%" % [bus_f * 100.0, car_f * 100.0])
	var car_s: float = _side_hit(TrafficSim.Kind.CAR, 0.6)[0]
	var bus_s: float = _side_hit(TrafficSim.Kind.BUS, 0.6)[0]
	check(bus_s > car_s + 0.02, "de lado: onibus %.0f%% > carro %.0f%%" % [bus_s * 100.0, car_s * 100.0])
	var sport_f: float = _front_hit(TrafficSim.Kind.SPORT, 25.0, 15.0)[0]
	check_near(sport_f, car_f, 0.01, "esportivo (leve) custa como carro")


func test_jolt_blocks_throttle_for_06_s_but_brake_works() -> void:
	var track: Track = _flat_track()
	var full := Commands.make(0.0, 1.0, 0.0)
	# tranco: acelerador cheio nao faz o caminhao ganhar velocidade
	var t := TruckSim.new()
	t.speed = 18.0
	for n in 120:                                 # acelerando ha 4 s: marcha certa, sem troca no meio do teste
		t.step(DT, full, track)
	t.jolt_t = Collision.JOLT_TIME
	var v0: float = t.speed
	var blocked: int = 0
	var gained: bool = false
	for n in 30:
		var before: float = t.speed
		t.step(DT, full, track)
		if t.engine.throttle_now == 0.0:
			blocked += 1
			gained = gained or t.speed > before
	check(not gained, "no tranco o acelerador nao tem efeito (o caminhao nao ganha velocidade)")
	check(blocked == 18, "dura 0,6 s (%d ticks de 1/30 s)" % blocked)
	check(not t.jolted() and t.engine.throttle_now == 1.0, "depois do tranco o acelerador volta")
	var v_end: float = t.speed
	for n in 30:
		t.step(DT, full, track)
	check(t.speed > v_end + 0.1, "e o caminhao volta a ganhar velocidade (%.2f -> %.2f m/s; antes do tranco %.2f)" % [v_end, t.speed, v0])
	# o freio funciona durante o tranco
	var a := TruckSim.new()
	var b := TruckSim.new()
	for tt in [a, b]:
		tt.speed = 25.0
		tt.jolt_t = Collision.JOLT_TIME
	for n in 15:
		a.step(DT, Commands.make(0.0, 1.0, 0.0), track)
		b.step(DT, Commands.make(0.0, 1.0, 1.0), track)
	check(b.speed < a.speed - 1.5, "freio no tranco: %.1f m/s contra %.1f sem freio" % [b.speed, a.speed])


func test_one_penalty_per_hit_even_with_contacts_in_following_ticks() -> void:
	var tr: TrafficSim = _one(TrafficSim.Kind.CAR, 200.0, 1, 12.0)
	var truck := TruckSim.new()
	truck.z = 200.0 - truck.length + 0.3
	truck.speed = 28.0
	var col := Collision.new()
	var first: Array[Dictionary] = col.resolve_traffic(truck, 0, tr)
	var after_first: float = truck.speed
	check(float(first[0]["penalty"]) > 0.0, "1a batida cobra")
	# o carro volta a encostar nos ticks seguintes (contato some e volta): nao cobra de novo durante o tranco
	var extra: int = 0
	var events: int = 0
	var track: Track = _flat_track()
	for n in 6:
		var c: TrafficSim.Car = tr.cars[0]
		c.z = truck.z + truck.length + 30.0       # longe: o contato acaba
		col.resolve_traffic(truck, 0, tr)
		c.z = truck.z + truck.length - 0.2        # encosta de novo no tick seguinte: contato "novo", com evento
		c.speed = truck.speed - 1.5
		for e in col.resolve_traffic(truck, 0, tr):
			events += 1
			if float(e["penalty"]) > 0.0:
				extra += 1
		truck.step(DT, Commands.make(0.0, 1.0, 0.0), track)
	check(events >= 5, "os contatos seguintes viram eventos (%d)" % events)
	check_eq(extra, 0, "uma penalidade por batida")
	check_eq(truck.jolts, 1, "um tranco so")
	check(truck.speed > after_first * 0.75, "nao empilhou a penalidade (%.1f m/s depois de %.1f)" % [truck.speed, after_first])


func test_race_rear_hit_once_and_hud_speed_drops() -> void:
	var sim := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	var i: int = sim.add_truck(100.0, 0.0)
	var t: TruckSim = sim.trucks[i]
	sim.traffic.cars = _one(TrafficSim.Kind.CAR, 100.0 + 12.0 + 20.0, 1, 12.0).cars
	t.speed = 30.0
	var pens: int = 0
	var min_speed: float = 99.0
	for n in 90:
		sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
		sim.step()
		min_speed = minf(min_speed, t.speed)
		for e in sim.drain_events():
			if String(e["type"]) == "traffic" and float(e["penalty"]) > 0.0:
				pens += 1
				check(float(e["speed_after"]) < float(e["speed_before"]) * 0.76, "o velocimetro cai ao menos 25%% (%.0f -> %.0f km/h)" % [
					float(e["speed_before"]) * 3.6, float(e["speed_after"]) * 3.6])
	check_eq(pens, 1, "uma batida, uma penalidade")
	check(min_speed < 30.0 * 0.76, "velocidade caiu (%.1f m/s)" % min_speed)


func test_penalty_and_jolt_are_deterministic() -> void:
	var states: Array[String] = []
	for run in 2:
		var sim := RaceSim.new(_flat_track(), TrafficSim.Density.HEAVY, 91)
		var i: int = sim.add_truck(60.0, 0.0)
		sim.trucks[i].speed = 34.0
		for k in 4:                               # carros lentos na faixa do caminhao (como o --demo=crash)
			var c: TrafficSim.Car = sim.traffic.cars[k]
			c.z = 60.0 + 12.0 + 80.0 + k * 150.0
			c.lane = 1
			c.x = TrafficSim.LANES[1]
			c.cruise = 9.0
			c.speed = 9.0
			c.timer = 999.0
		var bot := BotDriver.new(BotDriver.Difficulty.HARD, 5, 0.0, false, true)
		var s: String = ""
		for k in 30 * 45:
			sim.set_command(i, Commands.make(0.0, 1.0, 0.0) if k % 120 < 90 else bot.command_for(sim, i, DT))
			sim.step()
			for e in sim.drain_events():
				if String(e["type"]) == "traffic":
					s += "%d:%.5f:%.5f;" % [sim.tick, float(e["penalty"]), float(e["speed_after"])]
		s += "|%d|%.5f|%.5f" % [sim.trucks[i].jolts, sim.trucks[i].speed, sim.trucks[i].z]
		states.append(s)
	check(states[0].count(";") >= 1, "houve batida no teste (%d)" % states[0].count(";"))
	check_eq(states[0], states[1], "mesma semente e comandos = mesmas penalidades (servidor e clientes)")


func test_snapshot_carries_jolt_and_client_prediction_agrees() -> void:
	var sim := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	sim.add_truck(0.0, 0.0)
	sim.trucks[0].jolt_t = 11.0 * DT
	sim.trucks[0].jolt_side = -1
	var snap: Dictionary = Snapshot.unpack(Snapshot.pack(sim, [0]))
	var mirror := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	mirror.add_truck(0.0, 0.0)
	Snapshot.apply_to(mirror, snap)
	check_near(mirror.trucks[0].jolt_t, 11.0 * DT, 0.0001, "tranco chega no cliente (em ticks)")
	check_eq(mirror.trucks[0].jolt_side, -1, "lado do tranco chega no cliente")
	# servidor e cliente andando juntos (o cliente so recebe o snapshot): mesmo numero de ticks sem acelerador
	var server := TruckSim.new()
	server.speed = 20.0
	server.jolt_t = Collision.JOLT_TIME
	var client := TruckSim.new()
	var st := RaceSim.new(_flat_track())
	st.trucks.append(server)
	st.commands.append(Commands.new())
	var s0: Dictionary = (Snapshot.unpack(Snapshot.pack(st, [0]))["trucks"] as Array)[0]
	client.z = float(s0["z"])
	client.speed = float(s0["speed"])
	Snapshot._apply_lane(client, s0)
	var track: Track = _flat_track()
	var max_dv: float = 0.0
	for n in 30:
		server.step(DT, Commands.make(0.0, 1.0, 0.0), track)
		client.step(DT, Commands.make(0.0, 1.0, 0.0), track)
		max_dv = maxf(max_dv, absf(server.speed - client.speed))
		check_eq(client.jolted(), server.jolted(), "tick %d: cliente e servidor no mesmo estado de tranco" % n)
	check(max_dv < 0.01, "predicao igual ao servidor durante e depois do tranco (%.4f m/s)" % max_dv)


## O cliente nao ve a batida (so o servidor): no 1o snapshot com o tranco a correcao de ~3 m e suave (parece a
## freada da batida); o mesmo erro sem tranco continua teleportando (regra antiga, SNAP_THRESHOLD_Z).
func test_client_smooths_the_jump_back_of_a_new_hit() -> void:
	for jolt in [true, false]:
		var sync := ClientSync.new()
		sync.sim = RaceSim.new(_flat_track())
		sync.me = sync.sim.add_truck(100.0, 0.0)
		sync.sim.trucks[0].speed = 25.0
		for n in 3:
			sync.local_step(Commands.make(0.0, 1.0, 0.0))
		var server := RaceSim.new(_flat_track())
		server.add_truck(sync.sim.trucks[0].z - 3.0, 0.0)
		server.trucks[0].speed = 16.0
		server.trucks[0].jolt_t = Collision.JOLT_TIME if jolt else 0.0
		sync.on_snapshot(Snapshot.pack(server, [3]), 0)
		if jolt:
			check(sync.correction.x > 2.5, "batida nova: correcao suave (%.2f m)" % sync.correction.x)
			check(sync.my_truck().jolted(), "o caminhao previsto entra no tranco")
		else:
			check_near(sync.correction.x, 0.0, 0.001, "sem batida: erro de 3 m teleporta como antes")
