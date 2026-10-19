extends TestCase
## T-141 + T-144: freada forte, buzina (abre caminho, vai pela rede), forca das batidas (empurrao de faixa entre
## caminhoes, carro do transito arremessado) e o snapshot com os campos novos.

const DT: float = 1.0 / 30.0


func _flat_track() -> Track:
	var track := Track.new()
	track.add_section(4000.0, 0.0)
	return track


## Transito controlado: so os carros dados [tipo, z, faixa do transito (0..2), velocidade].
func _cars(t: TrafficSim, specs: Array) -> void:
	t.cars.clear()
	for sp in specs:
		var c := TrafficSim.Car.new()
		c.kind = int(sp[0])
		c.length = TrafficSim.KIND_LEN[c.kind]
		c.width_x = TrafficSim.KIND_WIDTH_X[c.kind]
		c.mass = TrafficSim.KIND_MASS[c.kind]
		c.z = float(sp[1])
		c.lane = int(sp[2])
		c.x = TrafficSim.LANES[c.lane]
		c.cruise = float(sp[3])
		c.speed = c.cruise
		c.timer = 999.0
		t.cars.append(c)


func _events_of(sim: RaceSim, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in sim.drain_events():
		if String(e["type"]) == type:
			out.append(e)
	return out


# ---------------------------------------------------------------- T-144: freada forte

func test_hard_brake_at_speed_starts_and_ends_with_events() -> void:
	var sim := RaceSim.new(_flat_track())
	var i: int = sim.add_truck(100.0, 0.0)
	var t: TruckSim = sim.trucks[i]
	t.speed = 100.0 / 3.6
	sim.set_command(i, Commands.make(0.0, 0.0, 1.0))
	sim.step()
	check(t.hard_braking, "freio total a 100 km/h = freada forte")
	check(t.brake_intensity > 0.2, "intensidade para o som e a fumaca (%.2f)" % t.brake_intensity)
	check_eq(_events_of(sim, "hard_brake").size(), 1, "evento de inicio")
	for k in 30:
		sim.step()
	check(t.hard_braking, "continua enquanto segura o freio")
	sim.drain_events()
	sim.set_command(i, Commands.make(0.0, 0.5, 0.0))
	sim.step()
	check(not t.hard_braking, "soltou o freio: acabou")
	var rel: Array[Dictionary] = _events_of(sim, "brake_release")
	check_eq(rel.size(), 1, "evento de soltar (o 'pssh' do freio a ar)")
	check(float(rel[0]["lost"]) > 4.0, "perdeu velocidade na freada (%.1f m/s)" % float(rel[0]["lost"]))


func test_no_hard_brake_when_slow_or_light_pedal() -> void:
	var sim := RaceSim.new(_flat_track())
	var i: int = sim.add_truck(100.0, 0.0)
	var t: TruckSim = sim.trucks[i]
	t.speed = 40.0 / 3.6
	sim.set_command(i, Commands.make(0.0, 0.0, 1.0))
	for k in 10:
		sim.step()
	check(not t.hard_braking, "a 40 km/h nao e freada forte")
	t.speed = 110.0 / 3.6
	t.brake_held = false
	sim.set_command(i, Commands.make(0.0, 0.0, 0.4))
	for k in 10:
		sim.step()
	check(not t.hard_braking, "freio leve nao conta")


# ---------------------------------------------------------------- T-144: buzina

func test_horn_makes_car_ahead_give_way() -> void:
	for honk in [false, true]:
		var sim := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
		var i: int = sim.add_truck(100.0, 0.0)              # faixa do meio (x = 0)
		_cars(sim.traffic, [[TrafficSim.Kind.CAR, 100.0 + 12.0 + 35.0, 1, 22.0]])
		sim.trucks[i].speed = 22.0
		sim.set_command(i, Commands.make(0.0, 0.3, 0.0, false, honk))
		for k in 30:
			sim.step()
		check_eq(sim.trucks[i].horn, honk, "o estado da buzina vem do comando")
		var c: TrafficSim.Car = sim.traffic.cars[0]
		if honk:
			check(c.lane != 1, "buzinando: o carro da frente sai da faixa")
			check(sim.traffic.honk_yields >= 1, "contou a saida pela buzina")
		else:
			check_eq(c.lane, 1, "sem buzina: o carro (mesma velocidade) segue na faixa")


func test_horn_too_far_does_nothing() -> void:
	var sim := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	var i: int = sim.add_truck(100.0, 0.0)
	_cars(sim.traffic, [[TrafficSim.Kind.CAR, 100.0 + 12.0 + TrafficSim.HORN_RANGE + 40.0, 1, 30.0]])
	sim.trucks[i].speed = 20.0
	sim.set_command(i, Commands.make(0.0, 0.0, 0.0, false, true))
	for k in 15:
		sim.step()
	check_eq(sim.traffic.cars[0].lane, 1, "longe demais da buzina")


func test_horn_goes_through_room_command() -> void:
	var r := Room.new("ABC234")
	r.add_member(100, "P0", "CODE0", {"parts": [], "engine": "eng_i6_std", "turbo": "turbo_none", "exhaust": "exh_std",
		"jake": false, "paint": "#ffffff", "systems": {"engine": 100.0, "steering": 100.0}})
	r.set_rules(100, {"bots": 0, "traffic": 0, "events": false})
	r.set_ready(100, true)
	r.try_start(100, 3)
	r.advance(Protocol.COUNTDOWN_SECONDS + 0.01)
	r.apply_command(100, 1, 0.0, 1.0, 0.0, false, true)
	r.step_tick()
	var idx: int = (r.members[100] as Room.Member).truck_idx
	check(r.sim.trucks[idx].horn, "o servidor aplica a buzina do comando")
	var snap: Dictionary = Snapshot.unpack(Snapshot.pack(r.sim, [1]))
	check(bool(snap["trucks"][0]["horn"]), "a buzina vai no snapshot")


# ---------------------------------------------------------------- T-141: carro arremessado

func test_rear_hit_throws_the_car_out_of_the_truck_line() -> void:
	var sim := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	var i: int = sim.add_truck(100.0, 0.02)
	var t: TruckSim = sim.trucks[i]
	_cars(sim.traffic, [[TrafficSim.Kind.CAR, 100.0 + 12.0 - 0.3, 1, 20.0]])
	t.speed = 30.0
	sim.set_command(i, Commands.make(0.0, 1.0, 0.0))
	sim.step()
	var hits: Array[Dictionary] = _events_of(sim, "traffic")
	check_eq(hits.size(), 1, "uma batida")
	check(bool(hits[0]["thrown"]), "10 m/s de diferenca arremessa o carro")
	var c: TrafficSim.Car = sim.traffic.cars[0]
	check(sim.traffic.is_thrown(c) and c.out_t > 1.0, "carro fora de controle")
	check(c.speed > t.speed, "o carro sai mais rapido que o caminhao")
	check(t.speed > 30.0 - 3.0 and t.speed < 30.0 - 0.5, "o caminhao de 12 t perde pouco (%.2f m/s)" % (30.0 - t.speed))
	check(c.vx < 0.0, "sai para o lado oposto ao do caminhao (o caminhao esta a direita)")
	check(c.yaw_rate != 0.0, "gira")
	for k in 30:
		sim.set_command(i, Commands.make(0.0, 0.0, 0.0))
		sim.step()
	check(absf(c.x - t.x) > (TruckSim.WIDTH_X + c.width_x) * 0.5, "em 1 s saiu da linha do caminhao")
	check(absf(c.yaw) > 0.2, "ficou de lado (%.2f rad)" % c.yaw)


func test_strong_hit_hops_and_car_recovers_later() -> void:
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	_cars(tr, [[TrafficSim.Kind.CAR, 200.0, 1, 10.0]])
	var truck := TruckSim.new()
	truck.z = 200.0 - 12.0 + 0.4
	truck.speed = 32.0
	var col := Collision.new()
	var evs: Array[Dictionary] = col.resolve_traffic(truck, 0, tr)
	check(bool(evs[0]["thrown"]), "arremessado")
	var c: TrafficSim.Car = tr.cars[0]
	var max_y: float = 0.0
	for k in 30 * 12:
		tr.step(DT, 400.0, 0.0)
		max_y = maxf(max_y, c.y)
	check(max_y > 0.15, "batida de 22 m/s tira o carro do chao (%.2f m)" % max_y)
	check(not tr.is_thrown(c), "o arremesso acaba")
	check_near(c.yaw, 0.0, 0.001, "o motorista endireita o carro")
	check(c.speed > 8.0, "e volta a andar (%.1f m/s)" % c.speed)
	check(absf(c.x) <= 0.55, "numa faixa de rolagem")


func test_light_touch_only_nudges_and_bus_is_not_thrown() -> void:
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	_cars(tr, [[TrafficSim.Kind.CAR, 200.0, 1, 20.0]])
	var truck := TruckSim.new()
	truck.z = 200.0 - 12.0 + 0.2
	truck.speed = 22.0
	var evs: Array[Dictionary] = Collision.new().resolve_traffic(truck, 0, tr)
	check(evs.is_empty() or not bool(evs[0]["thrown"]), "2 m/s: so empurra")
	check(not tr.is_thrown(tr.cars[0]) and tr.cars[0].speed >= 20.0, "o carro e empurrado para a frente")
	# onibus de 12 t: segura o caminhao e nao e arremessado
	var trb := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	_cars(trb, [[TrafficSim.Kind.BUS, 200.0, 1, 15.0]])
	var tb := TruckSim.new()
	tb.z = 200.0 - 12.0 + 0.3
	tb.speed = 25.0
	var evb: Array[Dictionary] = Collision.new().resolve_traffic(tb, 0, trb)
	check(not bool(evb[0]["thrown"]) and not trb.is_thrown(trb.cars[0]), "onibus e empurrado, nao voa")
	check(tb.speed < 25.0 - 5.0, "onibus segura muito mais o caminhao (%.1f m/s)" % tb.speed)


func test_side_swipe_throws_car_sideways() -> void:
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	_cars(tr, [[TrafficSim.Kind.CAR, 104.0, 2, 25.0]])       # carro na faixa da direita (x = 0,5)
	var truck := TruckSim.new()
	truck.z = 100.0
	truck.speed = 26.0
	truck.x = 0.5 - (TruckSim.WIDTH_X + tr.cars[0].width_x) * 0.5 + 0.03
	truck.lateral_vel = 0.9                                     # trocando de faixa para cima do carro
	var evs: Array[Dictionary] = Collision.new().resolve_traffic(truck, 0, tr)
	check_eq(String(evs[0]["zone"]), "right", "batida na lateral direita do caminhao")
	check(bool(evs[0]["thrown"]), "a fechada arremessa o carro")
	check(tr.cars[0].vx > 0.3, "o carro vai para a direita (%.2f x/s)" % tr.cars[0].vx)
	check(truck.lateral_vel < 0.9, "o caminhao perde um pouco do embalo lateral")


func test_thrown_car_is_deterministic() -> void:
	var states: Array[String] = []
	for run in 2:
		var sim := RaceSim.new(_flat_track(), TrafficSim.Density.HEAVY, 77)
		var i: int = sim.add_truck(60.0, 0.0)
		sim.trucks[i].speed = 36.0
		var bot := BotDriver.new(BotDriver.Difficulty.HARD, 5, 0.0, false, true)
		for k in 30 * 40:
			sim.set_command(i, Commands.make(0.0, 1.0, 0.0) if k % 90 < 60 else bot.command_for(sim, i, DT))
			sim.step()
		var s: String = "%d|" % sim.traffic.throws
		for c in sim.traffic.cars:
			s += "%.4f,%.4f,%.4f,%.4f;" % [c.z, c.x, c.yaw, c.y]
		states.append(s)
	check_eq(states[0], states[1], "mesma semente e comandos = mesmo transito (servidor e clientes)")


# ---------------------------------------------------------------- T-141: empurrao entre caminhoes

func _side_pair(mass_a: float, mass_b: float, lane_b: int) -> RaceSim:
	var sim := RaceSim.new(_flat_track())
	var a: int = sim.add_truck(200.0, Lanes.X[lane_b - 1])
	var b: int = sim.add_truck(200.0, Lanes.X[lane_b])
	sim.trucks[a].mass = mass_a
	sim.trucks[b].mass = mass_b
	for t in sim.trucks:
		t.speed = 25.0
	# a entrou na faixa de b com tudo: ja esta encostando
	sim.trucks[a].lane = lane_b
	sim.trucks[a].x = Lanes.X[lane_b] - TruckSim.WIDTH_X + 0.03
	sim.trucks[a].lateral_vel = 0.9
	return sim


func test_side_hit_shoves_the_other_truck_into_next_lane() -> void:
	var sim: RaceSim = _side_pair(12000.0, 12000.0, 2)
	var evs: Array[Dictionary] = sim.collision.resolve_trucks(sim.trucks, DT, sim.track)
	check_eq(evs.size(), 1, "batida lateral")
	check_eq(int(evs[0]["shoved"]), 1, "o caminhao de la foi empurrado")
	check_eq(sim.trucks[1].lane, 3, "para a faixa vizinha (2 -> 3)")
	check(sim.trucks[1].shove_t > 0.0, "fumaca nos pneus de quem foi empurrado")
	check_eq(sim.trucks[1].shoved, 1, "contou")
	# o empurrado vai mesmo para a outra faixa
	for k in 45:
		sim.set_command(0, Commands.make(0.0, 0.5, 0.0))
		sim.set_command(1, Commands.make(0.0, 0.5, 0.0))
		sim.step()
	check(sim.trucks[1].x > Lanes.X[2] + 0.3, "andou para a faixa da direita (x = %.2f)" % sim.trucks[1].x)


func test_light_truck_bounces_off_heavy_one() -> void:
	var sim: RaceSim = _side_pair(7500.0, 16000.0, 2)          # Canter carregado contra caminhao pesado
	var evs: Array[Dictionary] = sim.collision.resolve_trucks(sim.trucks, DT, sim.track)
	check_eq(int(evs[0]["shoved"]), -1, "leve demais para empurrar")
	check_eq(int(evs[0]["bounced"]), 0, "quem tentou entrar quicou")
	check_eq(sim.trucks[1].lane, 2, "o pesado fica na faixa")
	check_eq(sim.trucks[0].lane, 1, "o leve volta para a faixa dele")
	check(sim.trucks[0].lateral_vel < 0.0, "volta com embalo para o lado dele")


func test_truck_against_the_wall_is_not_shoved() -> void:
	var sim: RaceSim = _side_pair(12000.0, 12000.0, Lanes.SHOULDER_R)
	var evs: Array[Dictionary] = sim.collision.resolve_trucks(sim.trucks, DT, sim.track)
	check_eq(int(evs[0]["shoved"]), -1, "no acostamento, encostado na mureta, nao tem para onde ir")
	check_eq(int(evs[0]["bounced"]), 0, "quem bateu quica")


func test_gentle_side_touch_does_not_shove() -> void:
	var sim: RaceSim = _side_pair(12000.0, 12000.0, 2)
	sim.trucks[0].lateral_vel = 0.2
	sim.collision.resolve_trucks(sim.trucks, DT, sim.track)
	check_eq(sim.trucks[1].lane, 2, "encostada leve nao muda a faixa do outro")


# ---------------------------------------------------------------- rede

func test_snapshot_carries_new_flags_and_thrown_cars() -> void:
	var sim := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	var i: int = sim.add_truck(0.0, 0.0)
	var t: TruckSim = sim.trucks[i]
	t.horn = true
	t.hard_braking = true
	t.shove_t = 0.5
	var c: TrafficSim.Car = sim.traffic.cars[2]
	c.yaw = 1.234
	c.y = 0.62
	var snap: Dictionary = Snapshot.unpack(Snapshot.pack(sim, [0]))
	var st: Dictionary = snap["trucks"][0]
	check(bool(st["horn"]) and bool(st["hard_braking"]) and bool(st["shoved"]), "buzina, freada e empurrao no snapshot")
	var mirror := RaceSim.new(_flat_track(), TrafficSim.Density.LIGHT)
	mirror.add_truck(0.0, 0.0)
	Snapshot.apply_to(mirror, snap)
	check_near(mirror.traffic.cars[2].yaw, 1.234, 0.002, "giro do carro arremessado chega no cliente")
	check_near(mirror.traffic.cars[2].y, 0.62, 0.02, "altura do pulo chega no cliente")
	check(mirror.trucks[0].shove_t > 0.0 and mirror.trucks[0].horn, "o cliente desenha a fumaca e toca a buzina")
