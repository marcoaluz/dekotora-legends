extends TestCase
## T-219: sensacao de peso. O Resource de feel (data/feel/truck_feel.tres), a simulacao com inercia (aceleracao e
## troca de faixa com carga/pecas), o balanco visual da carroceria (TruckMotion), as rodas no chao, a vibracao
## (Haptics), o congelamento das batidas (RaceFeel) e a histerese do bot preso atras de um lento.

const DT: float = 1.0 / 30.0
const KMH100: float = 100.0 / 3.6


func _after() -> void:
	TruckFeel.use(null)


func _straight() -> Track:
	var tr := Track.new()
	tr.add_section(9000.0, 0.0)
	return tr


func _truck(cargo_kg: float = TruckSim.DEFAULT_CARGO, body: String = "base") -> TruckSim:
	var t := TruckSim.new()
	var d: Dictionary = TruckConfig.basic_descriptor()
	d["cargo_kg"] = cargo_kg
	d["body"] = body
	TruckConfig.apply(t, d)
	return t


func _zero_to_100(t: TruckSim) -> float:
	var tr: Track = _straight()
	var time: float = 0.0
	while t.speed < KMH100 and time < 120.0:
		t.step(DT, Commands.make(0.0, 1.0, 0.0), tr)
		time += DT
	return time


## Tempo (s) do 2o toque ate 90% do caminho para a faixa da direita, a 80 km/h.
func _lane_90(t: TruckSim) -> float:
	var tr: Track = _straight()
	t.speed = 80.0 / 3.6
	for n in 30:
		t.step(DT, Commands.make(0.0, 0.6, 0.0), tr)
	var x0: float = t.x
	var time: float = -1.0
	for n in 30 * 6:
		var held: bool = (n % 6) < 3 and n < 12
		t.step(DT, Commands.make(1.0 if held else 0.0, 0.6, 0.0), tr)
		if t.lane_changes > 0:
			time = maxf(time, 0.0) + DT
			if (t.x - x0) / (Lanes.X[t.lane] - x0) >= 0.9:
				return time
	return 99.0


func test_feel_resource_loads_with_sane_numbers() -> void:
	check(ResourceLoader.exists(TruckFeel.PATH), "existe " + TruckFeel.PATH)
	var f: TruckFeel = load(TruckFeel.PATH) as TruckFeel
	check(f != null, "o .tres e um TruckFeel")
	if f == null:
		return
	check(f.sim_traction_limit_n > 15000.0 and f.sim_traction_limit_n <= 40000.0, "tracao plausivel (%.0f)" % f.sim_traction_limit_n)
	check(f.sim_shift_time_s > 0.1 and f.sim_shift_time_s < 1.2, "troca de marcha plausivel")
	check(f.sim_steer_response > 0.5 and f.sim_lane_gain > 0.5 and f.sim_lane_max_vel > 0.3, "troca de faixa plausivel")
	check(f.sim_cargo_inertia >= 1.0 and f.sim_parts_inertia >= 1.0, "carga e pecas nunca pesam MENOS que a massa real")
	check(f.roll_max_deg > 0.0 and f.roll_max_deg < 10.0 and f.pitch_max_deg < 8.0, "balanco visual em graus pequenos")
	check(f.roll_damping > 0.05 and f.pitch_damping > 0.05, "molas com amortecimento (param de balancar)")
	check(f.hitstop_ms >= 0.0 and f.hitstop_ms <= 150.0, "congelamento curto (%.0f ms)" % f.hitstop_ms)
	check(f.reduced_shake_scale >= 0.0 and f.reduced_shake_scale < 1.0, "reduzir tremor reduz de verdade")
	check(TruckFeel.current() != null, "TruckFeel.current() sempre devolve um feel")


func test_legacy_feel_reproduces_the_old_numbers() -> void:
	TruckFeel.use(TruckFeel.legacy())
	var t: float = _zero_to_100(_truck())
	check_near(t, 22.6, 0.4, "0-100 de antes da T-219 (%.1f s)" % t)
	var l: float = _lane_90(_truck())
	check_near(l, 1.0, 0.08, "troca de faixa de antes (90%% em %.2f s)" % l)
	var t2 := _truck(12000.0)
	check_near(t2.inertia_mass(), t2.mass, 0.1, "antes: inercia = massa real")
	_after()


func test_new_feel_is_heavier_but_not_absurd() -> void:
	TruckFeel.use(TruckFeel.legacy())
	var old_acc: float = _zero_to_100(_truck())
	var old_lane: float = _lane_90(_truck())
	TruckFeel.use(null)
	var acc: float = _zero_to_100(_truck())
	var lane: float = _lane_90(_truck())
	print("T-219 padrao: 0-100 %.1f -> %.1f s, troca 90%% %.2f -> %.2f s" % [old_acc, acc, old_lane, lane])
	check(acc > old_acc and acc < old_acc * 1.25, "aceleracao mais longa, ate +25%% (%.1f -> %.1f s)" % [old_acc, acc])
	check(lane > old_lane and lane < 1.6, "troca de faixa mais demorada, ainda abaixo de 1,6 s (%.2f s)" % lane)


func test_full_box_and_heavy_parts_weigh_more() -> void:
	var std := _truck()
	var full := _truck(12000.0)
	check(full.inertia_mass() > full.mass, "bau cheio: inercia maior que a massa real (%.0f > %.0f)" % [full.inertia_mass(), full.mass])
	check_near(std.inertia_mass(), std.mass + (std.mass - std.base_mass - std.cargo_kg) * (TruckFeel.current().sim_parts_inertia - 1.0), 0.5,
		"carga padrao (4 t) nao pesa a mais")
	var l_std: float = _lane_90(_truck())
	var l_full: float = _lane_90(_truck(12000.0))
	check(l_full > l_std + 0.2, "bau cheio troca de faixa mais devagar (%.2f > %.2f s)" % [l_full, l_std])
	check(_zero_to_100(_truck(12000.0)) > _zero_to_100(_truck()) + 10.0, "bau cheio acelera bem mais devagar")
	var l_canter: float = _lane_90(_truck(TruckSim.DEFAULT_CARGO, "canter"))
	check(l_canter < l_std, "o Canter continua mais agil (%.2f < %.2f s)" % [l_canter, l_std])
	# peca pesada que cai: a inercia acompanha a massa real
	var t := TruckSim.new()
	t.set_loadout([DamageModel.make_part("fb_gold_wing", ["front"], 560.0, 300.0, 40)])
	var before: float = t.inertia_mass()
	t.mass -= 560.0
	check_near(before - t.inertia_mass(), 560.0 * TruckFeel.current().sim_parts_inertia, 0.5, "peca de 560 kg pesava %.0f kg na inercia" % (560.0 * TruckFeel.current().sim_parts_inertia))


func test_lane_change_rolls_out_and_swings_back() -> void:
	var f: TruckFeel = TruckFeel.current()
	var m := TruckMotion.new()
	var t := _truck()
	var tr: Track = _straight()
	t.speed = 80.0 / 3.6
	var min_roll: float = 0.0
	var max_after: float = 0.0
	var dt: float = 1.0 / 60.0
	var n_steps: int = 0
	for n in 30 * 4:
		var held: bool = (n % 6) < 3 and n < 12
		t.step(DT, Commands.make(1.0 if held else 0.0, 0.6, 0.0), tr)
		for k in 2:
			m.step(dt, f, t.speed, t.lateral_vel * Track.ROAD_HALF_WIDTH_M, 0.0, 0.0)
			n_steps += 1
			if n_steps < 60:
				min_roll = minf(min_roll, m.roll)
			else:
				max_after = maxf(max_after, m.roll)
	check(min_roll < -deg_to_rad(0.8), "indo para a direita o bau tomba para a ESQUERDA (roll %.2f graus)" % rad_to_deg(min_roll))
	check(max_after > deg_to_rad(0.3), "e balanca de volta para o outro lado (%.2f graus)" % rad_to_deg(max_after))
	check(absf(min_roll) <= deg_to_rad(f.roll_max_deg) * 1.41, "dentro do limite")
	for k in 600:
		m.step(dt, f, t.speed, 0.0, 0.0, 0.0)
	check(absf(m.roll) < deg_to_rad(0.05), "depois para (roll %.3f graus)" % rad_to_deg(m.roll))


func test_curve_rolls_outward() -> void:
	var m := TruckMotion.new()
	for k in 240:
		m.step(1.0 / 60.0, TruckFeel.current(), 25.0, 0.0, 1.0 / 300.0, 0.0)    # curva para a esquerda, raio 300 m
	check(m.roll > deg_to_rad(0.5), "curva para a esquerda: o lado direito (de fora) desce (%.2f graus)" % rad_to_deg(m.roll))


func test_pitch_on_throttle_and_brake_and_heave_on_dips() -> void:
	var f: TruckFeel = TruckFeel.current()
	var m := TruckMotion.new()
	var v: float = 10.0
	var up: float = 0.0
	for k in 60:
		v += 1.5 / 60.0
		m.step(1.0 / 60.0, f, v, 0.0, 0.0, 0.0)
		up = maxf(up, m.pitch)
	check(up > deg_to_rad(0.5), "acelerando o nariz sobe (%.2f graus)" % rad_to_deg(up))
	var down: float = 0.0
	for k in 90:
		v = maxf(v - 6.0 / 60.0, 0.0)
		m.step(1.0 / 60.0, f, v, 0.0, 0.0, 0.0)
		down = minf(down, m.pitch)
	check(down < -deg_to_rad(1.5), "freando forte o nariz afunda (%.2f graus)" % rad_to_deg(down))
	check(down >= -deg_to_rad(f.pitch_max_deg) * 1.41, "sem passar do limite")
	var h := TruckMotion.new()
	var low: float = 0.0
	for k in 60:
		h.step(1.0 / 60.0, f, 25.0, 0.0, 0.0, 2.0)
		low = minf(low, h.heave)
	check(low < -0.03, "baixada comprime a suspensao (%.3f m)" % low)
	var j := TruckMotion.new()
	j.step(1.0 / 60.0, f, 25.0, 0.0, 0.0, 0.0, f.joint_kick_mps)
	var dip: float = 0.0
	for k in 30:
		j.step(1.0 / 60.0, f, 25.0, 0.0, 0.0, 0.0)
		dip = minf(dip, j.heave)
	check(dip < -0.005, "emenda do viaduto da um tranco para baixo (%.3f m)" % dip)


func test_body_tilt_keeps_wheels_on_the_ground() -> void:
	var model := Node3D.new()
	var w := Node3D.new()
	w.name = "wheel_rl"
	w.position = Vector3(-1.1, 0.5, -2.0)
	var axle := Node3D.new()
	axle.position = Vector3(0.0, 0.0, -9.0)
	var wf := Node3D.new()
	wf.name = "wheel_fr"
	wf.position = Vector3(1.1, 0.5, 0.0)
	model.add_child(w)
	model.add_child(axle)
	axle.add_child(wf)
	var wheels := TruckWheels.new()
	wheels.setup(model, 0.5)
	var body: Transform3D = TruckMotion.body_transform(deg_to_rad(4.0), deg_to_rad(-2.0), -0.08, 12.0)
	model.transform = body
	wheels.body = body
	wheels.animate(10.0, 0.1, 0.0)
	var p_rl: Vector3 = model.transform * w.transform.origin
	var p_fr: Vector3 = model.transform * (axle.transform * wf.transform.origin)
	check(p_rl.distance_to(Vector3(-1.1, 0.5, -2.0)) < 0.001, "roda traseira no mesmo lugar com o bau inclinado (%s)" % p_rl)
	check(p_fr.distance_to(Vector3(1.1, 0.5, -9.0)) < 0.001, "roda dianteira (filha de outro no) tambem (%s)" % p_fr)
	var tip: Vector3 = body * Vector3(1.2, 3.8, -6.0)
	check(tip.y < 3.8 - 0.05, "o topo do lado direito desceu (o bau inclinou de verdade)")
	model.free()


func test_haptics_respects_option_and_strength() -> void:
	var f := TruckFeel.new()
	f.haptic_strength = 1.5
	check_eq(Haptics.duration(100.0, false, f), 0, "vibracao desligada nas opcoes = nada")
	check_eq(Haptics.duration(100.0, true, f), 150, "forca 1,5 = 50% mais longa")
	f.haptic_strength = 0.0
	check_eq(Haptics.duration(100.0, true, f), 0, "forca 0 = nada")


func test_hitstop_only_on_big_player_hits_and_off_with_reduced_shake() -> void:
	var root: Node = (Engine.get_main_loop() as SceneTree).root
	var s: Node = root.get_node_or_null("Settings")
	var old_reduce: bool = bool(s.get("fx_reduce_shake")) if s != null else false
	if s != null:
		s.set("fx_reduce_shake", false)
	var rf := RaceFeel.new()
	root.add_child(rf)
	rf.feel = TruckFeel.current()
	rf.player = 0
	rf.on_event({"type": "traffic", "truck": 1, "force": 20.0, "zone": "front", "broken": []})
	check_eq(rf.hitstops, 0, "batida dos outros nao congela")
	rf.on_event({"type": "traffic", "truck": 0, "force": rf.feel.hitstop_min_force * 0.5, "zone": "front", "broken": []})
	check_eq(rf.hitstops, 0, "batida pequena nao congela")
	rf.on_event({"type": "traffic", "truck": 0, "force": 19.8, "zone": "front", "broken": []})
	check_eq(rf.hitstops, 1, "batida grande do jogador congela")
	check_near(rf.hitstop_left, rf.feel.hitstop_ms / 1000.0, 0.001, "pelo tempo do feel")
	var frames: int = 0
	while rf.consume_hitstop(1.0 / 60.0):
		frames += 1
	check(frames >= 3 and frames <= 6, "60-90 ms = 4 ou 5 quadros a 60 fps (%d)" % frames)
	if s != null:
		s.set("fx_reduce_shake", true)
		rf.on_event({"type": "truck", "a": 0, "b": 1, "force": 25.0, "zone_a": "left", "zone_b": "right", "broken_a": [], "broken_b": []})
		check_eq(rf.hitstops, 1, "com Reduzir tremor nao congela")
		check_near(rf.shake_scale(), rf.feel.reduced_shake_scale, 0.001, "e o tremor cai")
		s.set("fx_reduce_shake", old_reduce)
	rf.queue_free()


func test_bot_does_not_get_stuck_trailing_a_bus() -> void:
	var sim := RaceSim.new(_straight())
	var i: int = sim.add_truck(0.0, Lanes.X[Lanes.LAST])
	var t: TruckSim = sim.trucks[i]
	t.lane = Lanes.LAST
	t.speed = 15.3
	var tr := TrafficSim.new(1, TrafficSim.Density.LIGHT)
	tr.cars.clear()
	var c := TrafficSim.Car.new()
	c.kind = TrafficSim.Kind.BUS
	c.length = TrafficSim.KIND_LEN[c.kind]
	c.width_x = TrafficSim.KIND_WIDTH_X[c.kind]
	c.mass = TrafficSim.KIND_MASS[c.kind]
	c.z = t.length + 27.0
	c.lane = 2
	c.x = TrafficSim.LANES[2]
	c.cruise = 15.3
	c.speed = 15.3
	c.timer = 999.0
	tr.cars.append(c)
	sim.traffic = tr
	var bot := BotDriver.new(BotDriver.Difficulty.HARD, 50, Lanes.X[Lanes.LAST], false, true)
	var passed: float = -1.0
	for n in 30 * 30:
		sim.set_command(i, bot.command_for(sim, i, DT))
		sim.step()
		sim.drain_events()
		if passed < 0.0 and t.z > c.z + c.length:
			passed = n * DT
	check(passed > 0.0 and passed < 20.0, "o bot dificil ultrapassa o onibus lento (em %.1f s)" % passed)


func test_protocol_bumped_for_the_new_sim() -> void:
	check(Protocol.VERSION >= 15, "protocolo 15 (T-219: a simulacao mudou; cliente antigo preveria errado)")
