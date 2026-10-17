extends TestCase
## Testes da predicao e interpolacao (P61/P62): sala em processo + ClientSync com latencia simulada.

const TICK: float = 1.0 / 30.0


func _loadout() -> Dictionary:
	return {"parts": [{"id": "fb_basic"}, {"id": "rb_basic"}], "engine": "eng_i6_std", "turbo": "turbo_none",
		"exhaust": "exh_std", "jake": false, "paint": "#ffffff", "systems": {"engine": 100.0, "steering": 100.0}}


## Roda uma partida simulada: servidor (Room) e um cliente com latencia de ida e volta `rtt_ms`.
## Devolve {max_error, mean_error, sync, room} medidos entre o que o cliente DESENHA e a verdade do servidor.
func _simulate(predict: bool, rtt_ms: int, loss: float = 0.0, seconds: float = 25.0) -> Dictionary:
	var room := Room.new("TEST22")
	room.add_member(100, "A", "AAAAAAAA", _loadout())
	room.add_member(101, "B", "BBBBBBBB", _loadout())
	room.set_rules(100, {"bots": 0, "traffic": 0, "route": "kanto_1_coast"})
	room.set_ready(100, true)
	room.set_ready(101, true)
	room.try_start(100, 11)
	room.advance(4.0)
	var sync := ClientSync.new()
	sync.predict = predict
	sync.setup(room.race_setup(), (room.members[100] as Room.Member).truck_idx)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var half: int = rtt_ms / 2
	var to_server: Array[Dictionary] = []         # comandos em voo
	var to_client: Array[Dictionary] = []         # snapshots em voo
	var now: int = 0
	var errors: Array[float] = []
	var mismatch: Array[float] = []             # erro de predicao medido a cada reconciliacao
	var steps: int = int(seconds / TICK)
	var driver := BotDriver.new(BotDriver.Difficulty.NORMAL, 4, 0.25)
	var driver2 := BotDriver.new(BotDriver.Difficulty.NORMAL, 5, -0.25)
	for n in steps:
		now += 33
		# cliente: comando a 30/s
		var cmd: Commands = driver.command_for(sync.sim, sync.me, TICK)
		var tk: int = sync.local_step(cmd)
		if rng.randf() >= loss:
			to_server.append({"due": now + half, "tick": tk, "cmd": cmd})
		# o outro humano (101) dirige por conta propria
		var m2: Room.Member = room.members[101]
		var c2: Commands = driver2.command_for(room.sim, m2.truck_idx, TICK)
		room.apply_command(101, n + 1, c2.steer, c2.throttle, c2.brake, c2.passing)
		# entrega comandos que chegaram
		for d in to_server:
			if int(d["due"]) <= now:
				var c: Commands = d["cmd"]
				room.apply_command(100, int(d["tick"]), c.steer, c.throttle, c.brake, c.passing)
		to_server = to_server.filter(func(d: Dictionary) -> bool: return int(d["due"]) > now)
		room.step_tick()
		# servidor manda snapshot a cada 1,5 tick (~20/s)
		if n % 3 != 2 and rng.randf() >= loss:
			to_client.append({"due": now + half, "bytes": room.snapshot()})
		for d in to_client:
			if int(d["due"]) <= now:
				sync.on_snapshot(d["bytes"], now)
				if n > 60:
					mismatch.append(absf(sync.last_error.x))
		to_client = to_client.filter(func(d: Dictionary) -> bool: return int(d["due"]) > now)
		sync.interpolate(now, TICK)
		if n > 60:
			var truth: TruckSim = room.sim.trucks[sync.me]
			errors.append(absf(sync.my_draw_z() - truth.z))
	var max_e: float = 0.0
	var sum_e: float = 0.0
	for e in errors:
		max_e = maxf(max_e, e)
		sum_e += e
	var mm: float = 0.0
	for e in mismatch:
		mm += e
	return {"max": max_e, "mean": sum_e / maxf(float(errors.size()), 1.0), "mismatch": mm / maxf(float(mismatch.size()), 1.0), "sync": sync, "room": room}


func test_snapshots_reach_mirror_and_others_interpolate() -> void:
	var r: Dictionary = _simulate(true, 80)
	var sync: ClientSync = r["sync"]
	var room: Room = r["room"]
	check(sync.snapshots_received > 100, "snapshots recebidos (%d)" % sync.snapshots_received)
	# o outro humano (101) aparece no espelho perto de onde esta no servidor (~100 ms de atraso de renderizacao)
	var other: int = (room.members[101] as Room.Member).truck_idx
	var d: float = absf(sync.sim.trucks[other].z - room.sim.trucks[other].z)
	check(d < 14.0, "caminhao do outro jogador interpolado perto do servidor (%.1f m)" % d)


func test_prediction_matches_server_and_beats_no_prediction() -> void:
	var with_p: Dictionary = _simulate(true, 150)
	var without_p: Dictionary = _simulate(false, 150)
	print("RTT 150 ms: erro de predicao %.3f m; posicao desenhada vs servidor: com predicao %.2f m, sem %.2f m" % [with_p["mismatch"], with_p["mean"], without_p["mean"]])
	check(float(with_p["mismatch"]) < 0.6, "a predicao concorda com o servidor (erro %.3f m por snapshot)" % with_p["mismatch"])
	# sem predicao o caminhao aparece sempre para tras (lag ~ velocidade x meio RTT); com predicao ele fica "no presente"
	check(float(without_p["mean"]) > 1.5 and float(without_p["mean"]) > float(with_p["mean"]) * 1.5, "sem predicao o caminhao desenhado atrasa vs servidor (%.2f m)" % without_p["mean"])


func test_prediction_survives_packet_loss() -> void:
	var r: Dictionary = _simulate(true, 150, 0.02)
	check(float(r["mismatch"]) < 1.2, "com 150 ms e 2%% de perda o erro de predicao segue pequeno (%.2f m)" % r["mismatch"])


func test_damage_update_applies_to_mirror() -> void:
	var r: Dictionary = _simulate(true, 60, 0.0, 3.0)
	var sync: ClientSync = r["sync"]
	sync.apply_damage({"idx": sync.me, "parts": [["fb_basic", 10.0, false], ["rb_basic", 0.0, true]], "systems": {"engine": 40.0, "steering": 100.0, "cargo": 90.0}, "mass": 12200.0})
	var t: TruckSim = sync.sim.trucks[sync.me]
	check_near(float(t.loadout[0]["dur"]), 10.0, 0.001, "durabilidade atualizada")
	check(bool(t.loadout[1]["broken"]), "peca marcada como quebrada")
	check_near(t.engine.power_factor, 0.7, 0.001, "motor ferido reduz potencia")
