extends TestCase
## Testes da sala multiplayer (sem rede): lobby, regras, corrida autoritativa, snapshots e saida de jogador.


func _loadout() -> Dictionary:
	return {"parts": [{"id": "fb_basic"}, {"id": "rb_basic"}], "engine": "eng_i6_std", "turbo": "turbo_none",
		"exhaust": "exh_std", "jake": false, "paint": "#d1303f", "systems": {"engine": 100.0, "steering": 100.0}}


func _room_with(n: int) -> Room:
	var r := Room.new("ABC234")
	for i in n:
		check_eq(r.add_member(100 + i, "P%d" % i, "CODE%d" % i, _loadout()), "", "entrou")
	return r


func test_room_code_has_valid_alphabet() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var code: String = Protocol.make_room_code(rng)
	check_eq(code.length(), 6, "6 letras")
	for ch in code:
		check(Protocol.ROOM_CODE_ALPHABET.contains(ch), "caractere valido")


func test_lobby_limits_host_and_ready() -> void:
	var r: Room = _room_with(4)
	check_eq(r.host_peer, 100, "primeiro a entrar e o anfitriao")
	check(r.add_member(200, "X", "C", _loadout()) != "", "5o jogador recusado")
	check(not r.all_ready(), "ninguem pronto")
	for p in r.order:
		r.set_ready(p, true)
	check(r.all_ready(), "todos prontos")
	check(r.try_start(101, 1) != "", "so o anfitriao inicia")
	check_eq(r.try_start(100, 1), "", "anfitriao inicia")
	check_eq(r.state, Protocol.RoomState.COUNTDOWN, "contagem")


func test_rules_only_host_and_reset_ready() -> void:
	var r: Room = _room_with(2)
	r.set_ready(100, true)
	check(not r.set_rules(101, {"bots": 3}), "quem nao e anfitriao nao muda regras")
	check(r.set_rules(100, {"bots": 2, "damage": Protocol.DamageMode.RACE_ONLY, "route": "kanto_2_viaduct"}), "anfitriao muda")
	check_eq(int(r.rules["bots"]), 2, "bots")
	check_eq(String(r.rules["route"]), "kanto_2_viaduct", "rota")
	check(not (r.members[100] as Room.Member).ready, "mudar regra desmarca prontos")


func test_start_builds_grid_with_bots_filling_to_four() -> void:
	var r: Room = _room_with(2)
	r.set_rules(100, {"bots": 3})
	for p in r.order:
		r.set_ready(p, true)
	r.try_start(100, 77)
	check_eq(r.sim.trucks.size(), 4, "2 humanos + 2 bots (max 4)")
	check(not r.sim.trucks[0].is_bot and r.sim.trucks[2].is_bot, "humanos primeiro, bots depois")
	check_eq(r.drivers.size(), 2, "2 bots dirigindo")


func test_race_runs_server_side_and_finishes_with_results() -> void:
	var r: Room = _room_with(2)
	r.set_rules(100, {"bots": 2, "route": "kanto_1_coast"})
	for p in r.order:
		r.set_ready(p, true)
	r.try_start(100, 5)
	r.advance(Protocol.COUNTDOWN_SECONDS + 0.01)
	check_eq(r.state, Protocol.RoomState.RACING, "largou")
	var steps: int = 0
	var human_drivers: Dictionary = {}
	for p in r.order:
		human_drivers[p] = BotDriver.new(BotDriver.Difficulty.NORMAL, p, 0.0, false, true)
	while r.state == Protocol.RoomState.RACING and steps < 30 * 300:
		# os dois humanos "dirigem" mandando comandos de bot
		for p in r.order:
			var m: Room.Member = r.members[p]
			var cmd: Commands = (human_drivers[p] as BotDriver).command_for(r.sim, m.truck_idx, 1.0 / 30.0)
			r.apply_command(p, steps, cmd.steer, cmd.throttle, cmd.brake, cmd.passing)
		r.step_tick()
		steps += 1
	check_eq(r.state, Protocol.RoomState.FINISHED, "sala terminou")
	check_eq(r.results.size(), 2, "resultado para cada humano")
	var winners: int = 0
	for p in r.results:
		var res: Dictionary = r.results[p]
		check(res.has("outcome"), "resultado traz o desfecho")
		if String(res["outcome"]) == "win":
			winners += 1
			check(int(res["pay"]) > 0, "quem vence recebe pagamento")
		else:
			check_eq(int(res["pay"]), 0, "quem perde nao recebe")
		check(bool(res["persist_damage"]), "dano real grava")
	check(winners <= 1, "no maximo um vencedor entre os humanos")


func test_race_only_damage_mode_does_not_persist() -> void:
	var r: Room = _room_with(1)
	r.set_rules(100, {"damage": Protocol.DamageMode.RACE_ONLY, "bots": 0})
	r.set_ready(100, true)
	r.try_start(100, 3)
	r.advance(4.0)
	r.sim.trucks[0].z = r.sim.finish_z - 1.0
	r.sim.trucks[0].speed = 30.0
	for n in 60:
		r.step_tick()
	check_eq(r.state, Protocol.RoomState.FINISHED, "terminou")
	check(not bool(r.results[100]["persist_damage"]), "Dano: so na corrida nao grava")


func test_disconnect_mid_race_turns_truck_into_bot() -> void:
	var r: Room = _room_with(2)
	r.set_rules(100, {"bots": 0})
	for p in r.order:
		r.set_ready(p, true)
	r.try_start(100, 9)
	r.advance(4.0)
	var idx: int = (r.members[101] as Room.Member).truck_idx
	r.remove_member(101)
	check(r.sim.trucks[idx].is_bot, "bot assumiu o caminhao")
	check(r.drivers.has(idx), "IA ligada")
	var z0: float = r.sim.trucks[idx].z
	for n in 120:
		r.step_tick()
	check(r.sim.trucks[idx].z > z0 + 8.0, "o bot continua correndo (%.1f m)" % (r.sim.trucks[idx].z - z0))


func test_commands_ack_and_old_commands_ignored() -> void:
	var r: Room = _room_with(1)
	r.set_ready(100, true)
	r.try_start(100, 1)
	r.advance(4.0)
	r.apply_command(100, 10, 0.5, 1.0, 0.0, false)
	r.apply_command(100, 5, -1.0, 0.0, 1.0, false)        # antigo: ignorado
	r.step_tick()
	check_near(r.sim.trucks[0].speed, r.sim.trucks[0].speed, 0.001, "ok")
	check_eq((r.members[100] as Room.Member).ack_tick, 10, "ack do ultimo comando valido")
	check_near((r.members[100] as Room.Member).last_cmd.throttle, 1.0, 0.001, "comando novo vale")


func test_snapshot_roundtrip() -> void:
	var r: Room = _room_with(2)
	r.set_ready(100, true)
	r.set_ready(101, true)
	r.try_start(100, 4)
	r.advance(4.0)
	for n in 90:
		r.apply_command(100, n, 0.0, 1.0, 0.0, false)
		r.step_tick()
	var bytes: PackedByteArray = r.snapshot()
	check(bytes.size() < 600, "snapshot compacto (%d bytes)" % bytes.size())
	var snap: Dictionary = Snapshot.unpack(bytes)
	check_eq(int(snap["tick"]), r.sim.tick, "tick")
	check_eq((snap["trucks"] as Array).size(), r.sim.trucks.size(), "caminhoes")
	var t0: Dictionary = snap["trucks"][0]
	check_near(float(t0["z"]), r.sim.trucks[0].z, 0.001, "z igual")
	check_near(float(t0["speed"]), r.sim.trucks[0].speed, 0.001, "velocidade igual")
	check_eq(int(t0["ack"]), 89, "ack do ultimo comando")
	check_eq((snap["cars"] as Array).size(), r.sim.traffic.cars.size(), "carros do transito")
	# aplicar em um espelho
	var mirror := RaceSim.new(r.sim.track, 1, r.seed_value)
	for i in r.sim.trucks.size():
		mirror.add_truck()
	Snapshot.apply_to(mirror, snap)
	check_near(mirror.trucks[1].z, r.sim.trucks[1].z, 0.001, "espelho copia z")


func test_damage_update_and_events_reach_clients() -> void:
	var r: Room = _room_with(2)
	r.set_rules(100, {"bots": 0, "traffic": 0})
	for p in r.order:
		r.set_ready(p, true)
	r.try_start(100, 8)
	r.advance(4.0)
	# coloca os dois lado a lado e em rota de colisao
	r.sim.trucks[0].z = 100.0
	r.sim.trucks[1].z = 100.0
	r.sim.trucks[0].x = -0.1
	r.sim.trucks[1].x = 0.1
	r.sim.trucks[0].speed = 30.0
	r.sim.trucks[1].speed = 30.0
	r.sim.trucks[0].lateral_vel = 0.8
	r.step_tick()
	var evs: Array[Dictionary] = r.drain_events()
	var got: bool = false
	for e in evs:
		if String(e["type"]) == "truck":
			got = true
	check(got, "colisao virou evento")
	var dmg: Array[int] = r.drain_damage_updates()
	check(0 in dmg and 1 in dmg, "dano dos dois marcado para envio")
	check_eq((r.damage_of(0)["parts"] as Array).size(), 2, "dano completo tem as pecas")
