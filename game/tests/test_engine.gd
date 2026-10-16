extends TestCase
## Testes do motor (P44): 0-100 km/h por combinacao, turbo com atraso, "pssh", freio-motor, dano.

const KMH100: float = 100.0 / 3.6


func _build(engine_id: String, turbo_id: String, exhaust_id: String = "exh_std", jake: bool = false, parts_kg: float = 0.0) -> TruckSim:
	var t := TruckSim.new()
	t.set_mass(parts_kg)
	t.engine.configure(load("res://data/engines/%s.tres" % engine_id), load("res://data/engines/%s.tres" % turbo_id),
		load("res://data/engines/%s.tres" % exhaust_id), jake)
	return t


func _zero_to_100(t: TruckSim) -> float:
	var track := Track.new()
	track.add_section(8000.0, 0.0)
	var cmd := Commands.make(0.0, 1.0, 0.0)
	var time: float = 0.0
	while t.speed < KMH100 and time < 120.0:
		t.step(1.0 / 30.0, cmd, track)
		time += 1.0 / 30.0
	return time


func test_zero_to_100_is_sane_and_ordered() -> void:
	var std: float = _zero_to_100(_build("eng_i6_std", "turbo_none"))
	var mid: float = _zero_to_100(_build("eng_i6_tuned", "turbo_single", "exh_straight", false, 80.0))
	var top: float = _zero_to_100(_build("eng_v8", "turbo_twin", "exh_straight", false, 300.0))
	print("0-100 km/h: padrao %.1f s, preparado+turbo %.1f s, V8+turbo duplo %.1f s" % [std, mid, top])
	check(std > 6.0 and std < 45.0, "0-100 padrao em tempo plausivel (%.1f s)" % std)
	check(mid < std, "6cil preparado + turbo simples e mais rapido que o padrao (%.1f < %.1f)" % [mid, std])
	check(top < mid, "V8 + turbo duplo e mais rapido que o preparado (%.1f < %.1f)" % [top, mid])


func test_automatic_gears_reach_sixth() -> void:
	var t := _build("eng_i6_std", "turbo_none")
	var track := Track.new()
	track.add_section(8000.0, 0.0)
	var seen: Array[int] = []
	for n in 30 * 80:
		t.step(1.0 / 30.0, Commands.make(0.0, 1.0, 0.0), track)
		if t.gear not in seen:
			seen.append(t.gear)
	check(6 in seen and 1 in seen and seen.size() >= 5, "passou pelas marchas %s" % [seen])
	check(t.rpm <= t.engine.redline_rpm * 1.1, "rpm limitado perto do corte (%.0f)" % t.rpm)


func test_turbo_has_lag_and_blowoff() -> void:
	var e := EngineModel.new()
	e.configure(null, load("res://data/engines/turbo_single.tres"))
	var time: float = 0.0
	var speed: float = 7.5          # rotacao ~1800 rpm na marcha 2 (acima do minimo do turbo)
	e.gear = 2
	var reached: float = -1.0
	while time < 3.0:
		e.step(1.0 / 30.0, 1.0, speed)
		time += 1.0 / 30.0
		if reached < 0.0 and e.boost > 0.7:
			reached = time
	check(reached > 0.3, "turbo demora para encher (%.2f s)" % reached)
	check(e.boost > 0.7, "turbo enche (%.2f)" % e.boost)
	var pop: bool = false
	for n in 3:
		e.step(1.0 / 30.0, 0.0, speed)
		pop = pop or e.blowoff
	check(pop, "soltar o acelerador com turbo cheio da o pssh")


func test_engine_brake_and_jake() -> void:
	var a := EngineModel.new()
	var b := EngineModel.new()
	b.has_jake = true
	a.gear = 4
	b.gear = 4
	var fa: float = 0.0
	var fb: float = 0.0
	for n in 20:
		fa = a.step(1.0 / 30.0, 0.0, 30.0)
		fb = b.step(1.0 / 30.0, 0.0, 30.0)
	check(fa < 0.0, "freio-motor padrao freia ao soltar o acelerador")
	check_near(fb / fa, 1.35, 0.01, "jake brake +35%")


func test_power_loss_by_damage() -> void:
	var good := _build("eng_i6_std", "turbo_none")
	var bad := _build("eng_i6_std", "turbo_none")
	bad.systems["engine"] = 0.0
	bad.refresh_damage_effects()
	check(_zero_to_100(bad) > _zero_to_100(good), "motor ferido acelera pior")


func test_torque_curve_peaks_midrange() -> void:
	var e := EngineModel.new()
	check(e.torque_fraction(1600.0) >= e.torque_fraction(700.0), "torque maximo no meio")
	check(e.torque_fraction(2500.0) < e.torque_fraction(1600.0), "cai perto do corte")
